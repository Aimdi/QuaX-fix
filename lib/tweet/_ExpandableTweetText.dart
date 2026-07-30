import 'package:flutter/material.dart';
import 'package:xta/generated/l10n.dart';

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

  /// Whether the text can be selected. Off in the feed: SelectableText builds
  /// the whole editable-text stack — focus node, selection overlay, caret
  /// ticker — per tile, which is an order of magnitude more work than Text
  /// and is only ever used on a post the reader has actually opened.
  final bool selectable;

  const ExpandableTweetText({
    super.key,
    required this.textSpans,
    this.onTap,
    this.maxLines = kTweetTextMaxLines,
    this.selectable = false,
  });

  @override
  ExpandableTweetTextState createState() => ExpandableTweetTextState();
}

class ExpandableTweetTextState extends State<ExpandableTweetText> {
  bool _isExpanded = false;

  // The truncation answer, remembered per (spans, width, scale): laying the
  // paragraph out to count its lines costs as much as painting it, and
  // LayoutBuilder re-runs this on every relayout of the tile.
  List<InlineSpan>? _memoSpans;
  double? _memoWidth;
  TextScaler? _memoScaler;
  bool _memoTruncated = false;

  /// Whether the text needs more than [ExpandableTweetText.maxLines] at the
  /// width it is actually painted at, in the style it is actually painted in.
  ///
  /// Measuring against the screen width mis-counts lines: tweet text sits
  /// inside horizontal padding, and a thread body is indented further still.
  /// Measuring without the rendered style compounds it, because the spans
  /// inherit their size from [DefaultTextStyle] rather than carrying it.
  bool _isTruncated(BuildContext context, double maxWidth, TextStyle style) {
    final maxLines = widget.maxLines;
    if (maxLines == null || !maxWidth.isFinite || maxWidth <= 0) {
      return false;
    }

    final scaler = MediaQuery.textScalerOf(context);
    if (identical(_memoSpans, widget.textSpans) && _memoWidth == maxWidth && _memoScaler == scaler) {
      return _memoTruncated;
    }

    final painter = TextPainter(
      text: TextSpan(style: style, children: widget.textSpans),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      // One line past the cap is all it takes to know the text overflows.
      maxLines: maxLines + 1,
    );
    painter.layout(maxWidth: maxWidth);
    final truncated = painter.computeLineMetrics().length > maxLines;
    painter.dispose();

    _memoSpans = widget.textSpans;
    _memoWidth = maxWidth;
    _memoScaler = scaler;
    _memoTruncated = truncated;
    return truncated;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final style = DefaultTextStyle.of(context).style;
        final clipped = !_isExpanded && _isTruncated(context, constraints.maxWidth, style);

        final Widget text = widget.selectable
            ? SelectableText.rich(
                TextSpan(children: widget.textSpans),
                scrollPhysics: const NeverScrollableScrollPhysics(),
                maxLines: clipped ? widget.maxLines : null,
                style: style,
                onTap: widget.onTap,
              )
            : GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: widget.onTap,
                child: Text.rich(
                  TextSpan(children: widget.textSpans),
                  maxLines: clipped ? widget.maxLines : null,
                  overflow: clipped ? TextOverflow.clip : null,
                  style: style,
                ),
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
