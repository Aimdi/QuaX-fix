import 'package:flutter/material.dart';

/// Shared timeline chrome for tweet tiles (matches twitter-ui-redesign).
const double kTweetMediaRadius = 16;
const double kTweetDividerThickness = 0.5;

ShapeBorder get kTweetCardShape => const RoundedRectangleBorder(borderRadius: BorderRadius.zero);

Color tweetDividerColor(BuildContext context) =>
    Theme.of(context).colorScheme.surfaceBright.withAlpha(150);

/// Edge-to-edge, elevation-free surface used by standalone tiles and thread wrappers.
Widget tweetFlatCard({
  required Color? color,
  required Widget child,
  Clip clipBehavior = Clip.antiAlias,
}) {
  return Card(
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: kTweetCardShape,
    clipBehavior: clipBehavior,
    color: color,
    child: child,
  );
}

Widget tweetHairlineDivider(BuildContext context) {
  return Divider(
    height: 0,
    thickness: kTweetDividerThickness,
    color: tweetDividerColor(context),
  );
}
