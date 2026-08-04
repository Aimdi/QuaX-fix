import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:quax/generated/l10n.dart';

/// The line cap a post has to break before it is worth collapsing.
///
/// A classic post is 280 characters, which already wraps past eight lines in
/// the width a post card leaves for text — so the old cap of eight collapsed
/// ordinary posts, and "show more" appeared on almost everything. Sixteen
/// reaches roughly twice that, which is long-form territory.
const int kTweetTextMaxLines = 16;

class ExpandableTweetText extends StatefulWidget {
  final List<InlineSpan> textSpans;
  final VoidCallback? onTap;
  final int? maxLines;

  const ExpandableTweetText({
    super.key,
    required this.textSpans,
    this.onTap,
    this.maxLines = kTweetTextMaxLines,
  });

  @override
  ExpandableTweetTextState createState() => ExpandableTweetTextState();
}

/// Everything a line count depends on.
///
/// Two of these being equal means the text would shape and wrap identically,
/// so the answer from last time still holds. The spans are compared by value
/// because the parent rebuilds the list on every build — but a recycled tile
/// carrying a different post, or the same post translated, produces different
/// spans and so a different measurement.
class _TextMeasure {
  final List<InlineSpan> spans;
  final double maxWidth;
  final TextStyle style;
  final TextScaler scaler;
  final TextDirection direction;
  final int maxLines;

  const _TextMeasure({
    required this.spans,
    required this.maxWidth,
    required this.style,
    required this.scaler,
    required this.direction,
    required this.maxLines,
  });

  bool sameAs(_TextMeasure other) =>
      maxWidth == other.maxWidth &&
      maxLines == other.maxLines &&
      direction == other.direction &&
      scaler == other.scaler &&
      style == other.style &&
      listEquals(spans, other.spans);

  bool run() {
    final painter = TextPainter(
      text: TextSpan(style: style, children: spans),
      textDirection: direction,
      textScaler: scaler,
      // One line past the cap is all it takes to know the text overflows.
      maxLines: maxLines + 1,
    );
    painter.layout(maxWidth: maxWidth);
    final truncated = painter.computeLineMetrics().length > maxLines;
    painter.dispose();

    return truncated;
  }
}

class ExpandableTweetTextState extends State<ExpandableTweetText> {
  bool _isExpanded = false;

  _TextMeasure? _measure;
  bool _measured = false;

  /// Whether the text needs more than [ExpandableTweetText.maxLines] at the
  /// width it is actually painted at, in the style it is actually painted in.
  ///
  /// Measuring against the screen width mis-counts lines: tweet text sits
  /// inside horizontal padding, and a thread body is indented further still.
  /// Measuring without the rendered style compounds it, because the spans
  /// inherit their size from [DefaultTextStyle] rather than carrying it.
  ///
  /// The count is kept until something it depends on changes: laying the text
  /// out is the most expensive thing a post does, and this runs at layout time
  /// alongside the [SelectableText.rich] that shapes the very same text again.
  bool _isTruncated(BuildContext context, double maxWidth, TextStyle style) {
    final maxLines = widget.maxLines;
    if (maxLines == null || !maxWidth.isFinite || maxWidth <= 0) {
      return false;
    }

    final measure = _TextMeasure(
      spans: widget.textSpans,
      maxWidth: maxWidth,
      style: style,
      scaler: MediaQuery.textScalerOf(context),
      direction: Directionality.of(context),
      maxLines: maxLines,
    );

    final previous = _measure;
    if (previous != null && previous.sameAs(measure)) {
      return _measured;
    }

    _measure = measure;
    _measured = measure.run();

    return _measured;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final style = DefaultTextStyle.of(context).style;
        final clipped = !_isExpanded && _isTruncated(context, constraints.maxWidth, style);

        final text = SelectableText.rich(
          TextSpan(children: widget.textSpans),
          scrollPhysics: const NeverScrollableScrollPhysics(),
          maxLines: clipped ? widget.maxLines : null,
          style: style,
          onTap: widget.onTap,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (clipped)
              ShaderMask(
                shaderCallback: (bounds) {
                  return const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black,
                      Colors.black,
                      Colors.black,
                      Colors.transparent,
                    ],
                    stops: [0.0, 0.6, 0.8, 1.0],
                  ).createShader(bounds);
                },
                blendMode: BlendMode.dstIn,
                child: text,
              )
            else
              text,
            if (clipped)
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _isExpanded = true;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8, left: 2),
                    child: Text(
                      L10n.of(context).clickToShowMore,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
