import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart' as mk;

/// An inline player for a podcast post's episode.
///
/// Deliberately its own small player rather than the video stack: there is no
/// picture to render, so no texture and no controller pool — just libmpv
/// playing a file, scoped to the reader screen that shows it.
class SubstackAudioPlayer extends StatefulWidget {
  final String url;
  final String title;

  const SubstackAudioPlayer({super.key, required this.url, required this.title});

  @override
  State<SubstackAudioPlayer> createState() => _SubstackAudioPlayerState();
}

class _SubstackAudioPlayerState extends State<SubstackAudioPlayer> {
  late final mk.Player _player = mk.Player();
  final List<StreamSubscription> _subscriptions = [];
  var _playing = false;
  var _opened = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _subscriptions.add(_player.stream.playing.listen((playing) {
      if (mounted) setState(() => _playing = playing);
    }));
    _subscriptions.add(_player.stream.position.listen((position) {
      if (mounted) setState(() => _position = position);
    }));
    _subscriptions.add(_player.stream.duration.listen((duration) {
      if (mounted) setState(() => _duration = duration);
    }));
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    // Opened on the first tap, not on mount: most readers of a podcast page
    // are skimming the show notes, and the file is long.
    if (!_opened) {
      _opened = true;
      await _player.open(mk.Media(widget.url));
      return;
    }
    await _player.playOrPause();
  }

  String _clock(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$minutes:$seconds' : '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasLength = _duration > Duration.zero;

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            IconButton(
              icon: Icon(_playing ? Icons.pause_circle : Icons.play_circle, size: 34),
              color: theme.colorScheme.primary,
              onPressed: _toggle,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: hasLength
                  ? Slider(
                      value: _position.inMilliseconds.clamp(0, _duration.inMilliseconds).toDouble(),
                      max: _duration.inMilliseconds.toDouble(),
                      onChanged: (value) => _player.seek(Duration(milliseconds: value.round())),
                    )
                  : Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
            ),
            if (hasLength)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text('${_clock(_position)} / ${_clock(_duration)}', style: theme.textTheme.bodySmall),
              ),
          ],
        ),
      ),
    );
  }
}
