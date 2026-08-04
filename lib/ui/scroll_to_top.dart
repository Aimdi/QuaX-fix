import 'package:flutter/material.dart';
import 'package:pref/pref.dart';
import 'package:xta/constants.dart';

/// How long the jump back to the top takes.
///
/// Short enough to feel like a jump rather than a journey — a second of
/// easing through a long timeline reads as the app being slow.
const Duration kScrollToTopDuration = Duration(milliseconds: 350);

/// Returns a list to its top, if it has one to return to.
///
/// A controller with no clients is the normal case for a tab that has never
/// been built, so it is nothing to report — it simply has no scroll position
/// to move.
Future<void> scrollToTop(BuildContext context, ScrollController? controller) async {
  if (controller == null || !controller.hasClients) {
    return;
  }

  final disableAnimations = PrefService.of(context, listen: false).get(optionDisableAnimations) == true;
  await controller.animateTo(
    0,
    duration: disableAnimations ? Duration.zero : kScrollToTopDuration,
    curve: Curves.easeInOut,
  );
}
