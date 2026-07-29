import 'package:flutter_test/flutter_test.dart';
import 'package:xta/tweet/video_playback_policy.dart';

bool _button({
  bool autoPlayPref = false,
  bool alwaysPlay = false,
  bool userRequestedPlay = false,
  bool alreadyCached = false,
}) => showsPlayButton(
  autoPlayPref: autoPlayPref,
  alwaysPlay: alwaysPlay,
  userRequestedPlay: userRequestedPlay,
  alreadyCached: alreadyCached,
);

bool _create({
  bool autoPlayPref = false,
  bool alwaysPlay = false,
  bool userRequestedPlay = false,
  bool alreadyCached = false,
  bool hasBeenVisible = false,
}) => shouldCreatePlayer(
  autoPlayPref: autoPlayPref,
  alwaysPlay: alwaysPlay,
  userRequestedPlay: userRequestedPlay,
  alreadyCached: alreadyCached,
  hasBeenVisible: hasBeenVisible,
);

void main() {
  group('showsPlayButton', () {
    test('a plain video waits for a tap', () {
      expect(_button(), isTrue);
    });

    test('autoplay, GIFs, a tap and a cached player all skip it', () {
      expect(_button(autoPlayPref: true), isFalse);
      expect(_button(alwaysPlay: true), isFalse);
      expect(_button(userRequestedPlay: true), isFalse);
      expect(_button(alreadyCached: true), isFalse);
    });
  });

  group('shouldCreatePlayer', () {
    // The regression that forced the feed's cacheExtent back down: a looping
    // GIF below the fold allocated libmpv purely by being built.
    test('an off-screen GIF allocates nothing', () {
      expect(_create(alwaysPlay: true, hasBeenVisible: false), isFalse);
    });

    test('an off-screen autoplay video allocates nothing', () {
      expect(_create(autoPlayPref: true, hasBeenVisible: false), isFalse);
    });

    test('the same GIF allocates once it has been on screen', () {
      expect(_create(alwaysPlay: true, hasBeenVisible: true), isTrue);
    });

    test('a tap creates the player as soon as it is on screen', () {
      expect(_create(userRequestedPlay: true, hasBeenVisible: true), isTrue);
    });

    // Reattaching to a pooled player costs nothing, and waiting would flash the
    // poster again every time the reader scrolls back.
    test('an already pooled player reattaches without waiting for visibility', () {
      expect(_create(alreadyCached: true, hasBeenVisible: false), isTrue);
    });

    test('a video still showing its play button never allocates, visible or not', () {
      expect(_create(hasBeenVisible: true), isFalse);
      expect(_create(hasBeenVisible: false), isFalse);
    });
  });
}
