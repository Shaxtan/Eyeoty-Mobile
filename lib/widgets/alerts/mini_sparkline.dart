import 'package:flutter/material.dart';

/// Small self-contained sparkline (no chart-lib dependency), matching
/// AlertsPage.jsx's own inline Sparkline component (an SVG polyline) -
/// same approach here, just via CustomPaint instead of SVG.
class MiniSparkline extends StatelessWidget {
  final List<int> data;
  final Color color;
  final double height;
  const MiniSparkline({super.key, required this.data, this.color = const Color(0xFF2563EB), this.height = 22});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(child: Text('\u2014', style: TextStyle(fontSize: 9, color: Colors.grey.shade300))),
      );
    }
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _SparklinePainter(data, color)),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<int> data;
  final Color color;
  _SparklinePainter(this.data, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final maxV = data.reduce((a, b) => a > b ? a : b).clamp(1, 1 << 30);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    final step = data.length > 1 ? size.width / (data.length - 1) : 0.0;
    for (var i = 0; i < data.length; i++) {
      final x = i * step;
      final y = size.height - (data[i] / maxV) * (size.height - 4) - 2;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) => oldDelegate.data != data || oldDelegate.color != color;
}