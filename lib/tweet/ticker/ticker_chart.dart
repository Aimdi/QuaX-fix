import 'package:flutter/material.dart';
import 'package:quax/tweet/ticker/ticker_quote.dart';

/// The price line for a symbol, drawn rather than embedded.
///
/// A plain polyline with a soft fill beneath it: enough to read the shape of a
/// month at a glance, which is what a ticker in a post is worth. No axes and no
/// gridlines — at this size they would cost more room than they explain.
class TickerChart extends StatelessWidget {
  final TickerQuote quote;
  final double height;

  const TickerChart({super.key, required this.quote, this.height = 160});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final up = quote.isUp ?? true;
    final colour = up ? const Color(0xFF00BA7C) : const Color(0xFFF4212E);

    return SizedBox(
      height: height,
      width: double.infinity,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _TickerChartPainter(
            closes: quote.points.map((p) => p.close).toList(growable: false),
            baseline: quote.previousClose,
            line: colour,
            baselineColour: theme.colorScheme.outline,
          ),
        ),
      ),
    );
  }
}

class _TickerChartPainter extends CustomPainter {
  final List<double> closes;
  final double? baseline;
  final Color line;
  final Color baselineColour;

  _TickerChartPainter({
    required this.closes,
    required this.baseline,
    required this.line,
    required this.baselineColour,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (closes.length < 2 || size.width <= 0 || size.height <= 0) {
      return;
    }

    var low = closes.reduce((a, b) => a < b ? a : b);
    var high = closes.reduce((a, b) => a > b ? a : b);
    // The previous close belongs inside the range, or the reference line it
    // draws would sit off the top or bottom of the chart.
    final base = baseline;
    if (base != null) {
      low = low < base ? low : base;
      high = high > base ? high : base;
    }

    // A symbol that did not move at all would divide by zero; give it a flat
    // line through the middle instead.
    final span = high - low;
    double yFor(double value) => span == 0 ? size.height / 2 : size.height - ((value - low) / span) * size.height;
    double xFor(int i) => size.width * (i / (closes.length - 1));

    final path = Path()..moveTo(xFor(0), yFor(closes.first));
    for (var i = 1; i < closes.length; i++) {
      path.lineTo(xFor(i), yFor(closes[i]));
    }

    if (base != null) {
      final y = yFor(base);
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..color = baselineColour
          ..strokeWidth = 1,
      );
    }

    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [line.withValues(alpha: 0.22), line.withValues(alpha: 0.0)],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _TickerChartPainter old) =>
      old.closes != closes || old.baseline != baseline || old.line != line;
}
