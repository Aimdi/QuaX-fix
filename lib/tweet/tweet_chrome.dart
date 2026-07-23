import 'package:flutter/material.dart';
import 'package:quax/ui/x_look_theme.dart';

/// Shared timeline chrome for tweet tiles (matches twitter-ui-redesign / X-look).
const double kTweetMediaRadius = 16;
const double kTweetDividerThickness = 0.5;

ShapeBorder get kTweetCardShape => const RoundedRectangleBorder(borderRadius: BorderRadius.zero);

Color tweetDividerColor(BuildContext context) {
  final tokens = XLookTokens.maybeOf(context);
  if (tokens != null) return tokens.divider;
  return Theme.of(context).colorScheme.surfaceBright.withAlpha(150);
}

double tweetMediaRadiusOf(BuildContext context) =>
    XLookTokens.maybeOf(context)?.mediaRadius ?? kTweetMediaRadius;

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
