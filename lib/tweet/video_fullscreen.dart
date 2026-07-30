import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:xta/tweet/_video_controls.dart';
import 'package:xta/tweet/video_controller_pool.dart';

/// Inherited marker so controls know they are already on the fullscreen route
/// and should pop instead of pushing again.
class TweetVideoFullscreenScope extends InheritedWidget {
  const TweetVideoFullscreenScope({super.key, required super.child});

  static bool activeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TweetVideoFullscreenScope>() != null;

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) => false;
}

/// Picks orientation from the video's shape so a portrait video isn't forced
/// into landscape like media_kit's `defaultEnterNativeFullscreen` does.
Future<void> enterTweetVideoFullscreenUi(double aspectRatio) async {
  if (!Platform.isAndroid && !Platform.isIOS) {
    return defaultEnterNativeFullscreen();
  }
  try {
    final portrait = aspectRatio < 1.0;
    await Future.wait([
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky, overlays: []),
      SystemChrome.setPreferredOrientations(
        portrait
            ? [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]
            : [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight],
      ),
    ]);
  } catch (_) {}
}

/// Self-contained fullscreen route that owns its own [Video] / notifiers.
///
/// media_kit's built-in `enterFullscreen` reuses the inline tile's [VideoState]
/// and `VideoViewParameters` notifier. Off-screen reclaim (and list recycle on
/// orientation change) disposes that parent [Video], which leaves the route
/// holding disposed notifiers — controls vanish and there is no way to exit.
/// Pushing an independent [Video] on the same [VideoController] survives that.
Future<void> pushTweetVideoFullscreen({
  required NavigatorState navigator,
  required PooledVideo pooled,
  required String username,
  required Color accentColor,
  required bool subtitlesEnabled,
  required VoidCallback onToggleSubtitles,
  required bool pauseUponEnteringBackgroundMode,
}) {
  return navigator.push<void>(
    PageRouteBuilder<void>(
      pageBuilder: (_, _, _) => TweetVideoFullscreenScope(
        child: _TweetVideoFullscreenPage(
          pooled: pooled,
          username: username,
          accentColor: accentColor,
          subtitlesEnabled: subtitlesEnabled,
          onToggleSubtitles: onToggleSubtitles,
          pauseUponEnteringBackgroundMode: pauseUponEnteringBackgroundMode,
        ),
      ),
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    ),
  );
}

class _TweetVideoFullscreenPage extends StatefulWidget {
  final PooledVideo pooled;
  final String username;
  final Color accentColor;
  final bool subtitlesEnabled;
  final VoidCallback onToggleSubtitles;
  final bool pauseUponEnteringBackgroundMode;

  const _TweetVideoFullscreenPage({
    required this.pooled,
    required this.username,
    required this.accentColor,
    required this.subtitlesEnabled,
    required this.onToggleSubtitles,
    required this.pauseUponEnteringBackgroundMode,
  });

  @override
  State<_TweetVideoFullscreenPage> createState() => _TweetVideoFullscreenPageState();
}

class _TweetVideoFullscreenPageState extends State<_TweetVideoFullscreenPage> {
  late bool _subtitlesEnabled = widget.subtitlesEnabled;

  void _toggleSubtitles() {
    widget.onToggleSubtitles();
    setState(() => _subtitlesEnabled = !_subtitlesEnabled);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Video(
        controller: widget.pooled.videoController,
        // Own notifiers — do not inherit the inline tile's VideoState.
        fit: BoxFit.contain,
        controls: (_) => XtaControls(
          pooled: widget.pooled,
          username: widget.username,
          allowMuting: true,
          accentColor: widget.accentColor,
          subtitlesEnabled: _subtitlesEnabled,
          onToggleSubtitles: _toggleSubtitles,
          onToggleFullscreen: () => Navigator.of(context, rootNavigator: true).maybePop(),
        ),
        wakelock: true,
        pauseUponEnteringBackgroundMode: widget.pauseUponEnteringBackgroundMode,
        subtitleViewConfiguration: SubtitleViewConfiguration(visible: _subtitlesEnabled),
      ),
    );
  }
}
