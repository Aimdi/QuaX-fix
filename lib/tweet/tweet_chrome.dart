import 'package:flutter/material.dart';
import 'package:xta/ui/contrast.dart';
import 'package:xta/ui/x_look_theme.dart';

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

/// Nudges [surface] a few percent towards [toward] — the flat-design
/// equivalent of elevation, so a nested card separates without a shadow.
Color _lift(Color surface, Color toward) => Color.alphaBlend(toward.withValues(alpha: 0.06), surface);

/// Chrome for a quoted tweet nested inside another tweet.
///
/// The nested card has to read as nested on every theme, including the pure
/// black ones where a translucent surface tint disappears entirely, so the
/// border comes from an outline token and the fill is lifted off the parent
/// card rather than matching it.
BoxDecoration quoteCardDecoration(BuildContext context) {
  final tokens = XLookTokens.maybeOf(context);
  final scheme = Theme.of(context).colorScheme;
  final onSurface = tokens?.onBackground ?? scheme.onSurface;
  final fill = _lift(tokens?.card ?? scheme.surface, onSurface);

  // X's own hairline (#EFF3F4 light, #38444D dim) barely registers against the
  // card it outlines, which is what made quotes indistinguishable from separate
  // posts. Correct it against the fill it is drawn on instead of picking a
  // colour per theme.
  final border = ensureContrast(tokens?.border ?? scheme.outline, fill, minRatio: 1.5);

  return BoxDecoration(
    color: fill,
    border: Border.all(color: border),
    borderRadius: BorderRadius.circular(tweetMediaRadiusOf(context)),
  );
}

Widget tweetHairlineDivider(BuildContext context) {
  return Divider(
    height: 0,
    thickness: kTweetDividerThickness,
    color: tweetDividerColor(context),
  );
}
