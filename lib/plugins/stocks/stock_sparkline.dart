import 'package:flutter/material.dart';

/// The price line and nothing else.
///
/// `TickerChart` reserves room for two labelled axes, which is more than a
/// watchlist card is tall — so the shape is drawn again here rather than making
/// the real chart pretend it has no labels. Where there is room for it, the
/// previous close is dashed across as a reference, which is the whole reason a
/// line without numbers still says something.
class StockSparkline extends StatelessWidget {
  final List<double> closes;

  /// Drawn as a dashed rule when given, and folded into the vertical range so
  /// it cannot sit off the top or bottom.
  final double? baseline;

  final Color colour;
  final double strokeWidth;

  /// Filled under the line, as the full chart does. Off on a small card, where
  /// the gradient is more noise than shape.
  final bool filled;

  const StockSparkline({
    super.key,
    required this.closes,
    required this.colour,
    this.baseline,
    this.strokeWidth = 1.5,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    if (closes.length < 2) {
      return Center(child: Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant));
    }

    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: _SparklinePainter(
          closes: closes,
          baseline: baseline,
          line: colour,
          grid: Theme.of(context).colorScheme.outlineVariant,
          strokeWidth: strokeWidth,
          filled: filled,
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> closes;
  final double? baseline;
  final Color line;
  final Color grid;
  final double strokeWidth;
  final bool filled;

  _SparklinePainter({
    required this.closes,
    required this.baseline,
    required this.line,
    required this.grid,
    required this.strokeWidth,
    required this.filled,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (closes.length < 2 || size.width <= 0 || size.height <= strokeWidth) {
      return;
    }

    var low = closes.reduce((a, b) => a < b ? a : b);
    var high = closes.reduce((a, b) => a > b ? a : b);
    final base = baseline;
    if (base != null) {
      low = low < base ? low : base;
      high = high > base ? high : base;
    }

    final span = high - low;

    // The extremes sit on the very edge of the box, where half the stroke would
    // be clipped away, so the plot is inset by that half.
    final top = strokeWidth / 2;
    final plotHeight = size.height - strokeWidth;

    double yFor(double value) => span == 0 ? size.height / 2 : top + (1 - (value - low) / span) * plotHeight;
    double xFor(int i) => size.width * (i / (closes.length - 1));

    final path = Path()..moveTo(xFor(0), yFor(closes.first));
    for (var i = 1; i < closes.length; i++) {
      path.lineTo(xFor(i), yFor(closes[i]));
    }

    if (base != null) {
      _paintBaseline(canvas, size, yFor(base));
    }

    if (filled) {
      canvas.drawPath(
        Path.from(path)
          ..lineTo(size.width, size.height)
          ..lineTo(0, size.height)
          ..close(),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [line.withValues(alpha: 0.22), line.withValues(alpha: 0.0)],
          ).createShader(Offset.zero & size),
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintBaseline(Canvas canvas, Size size, double y) {
    final paint = Paint()
      ..color = grid
      ..strokeWidth = 1;

    for (var x = 0.0; x < size.width; x += 8) {
      canvas.drawLine(Offset(x, y), Offset((x + 4).clamp(0.0, size.width), y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.closes != closes || old.baseline != baseline || old.line != line || old.filled != filled;
}
