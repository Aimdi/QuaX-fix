import 'dart:async';

import 'package:flutter_triple/flutter_triple.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:xta/media/xta_audio_handler.dart';

/// What is playing, for the reader screen's controls and anything else that
/// wants to show it.
class PodcastPlayback {
  final String? url;
  final String title;
  final bool playing;
  final Duration position;
  final Duration duration;

  const PodcastPlayback({
    this.url,
    this.title = '',
    this.playing = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
  });

  bool get active => url != null;

  PodcastPlayback copyWith({bool? playing, Duration? position, Duration? duration}) => PodcastPlayback(
        url: url,
        title: title,
        playing: playing ?? this.playing,
        position: position ?? this.position,
        duration: duration ?? this.duration,
      );
}

/// One podcast at a time, app-wide.
///
/// The player used to live inside the reader screen, so leaving the article
/// stopped the episode — the opposite of what a podcast is for. It lives here
/// now: screens bind to it, the media session carries its controls, and
/// closing the article changes nothing about what you are hearing.
class PodcastStore extends Store<PodcastPlayback> {
  final mk.Player _player = mk.Player();
  final List<StreamSubscription> _subscriptions = [];

  PodcastStore() : super(const PodcastPlayback()) {
    _subscriptions.add(_player.stream.playing.listen((playing) {
      if (!state.active) return;
      update(state.copyWith(playing: playing));
      audioHandler?.updateSession(playing: playing, position: state.position, duration: state.duration);
    }));
    _subscriptions.add(_player.stream.position.listen((position) {
      if (!state.active) return;
      update(state.copyWith(position: position));
    }));
    _subscriptions.add(_player.stream.duration.listen((duration) {
      if (!state.active) return;
      update(state.copyWith(duration: duration));
      audioHandler?.updateSession(playing: state.playing, position: state.position, duration: duration);
    }));
    _subscriptions.add(_player.stream.completed.listen((completed) {
      if (completed) stop();
    }));
  }

  /// Starts [url] if it is not the current episode, else toggles pause.
  Future<void> toggle({required String url, required String title}) async {
    if (state.url != url) {
      update(PodcastPlayback(url: url, title: title));
      audioHandler?.bindSession(
        title: title,
        binding: (
          onPlay: _player.play,
          onPause: _player.pause,
          onStop: () => stop(),
          onSeek: (position) => _player.seek(position),
        ),
      );
      await _player.open(mk.Media(url));
      return;
    }
    await _player.playOrPause();
  }

  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> stop() async {
    await _player.stop();
    update(const PodcastPlayback());
    audioHandler?.clearSession();
  }

  @override
  Future<void> destroy() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _player.dispose();
    return super.destroy();
  }
}
