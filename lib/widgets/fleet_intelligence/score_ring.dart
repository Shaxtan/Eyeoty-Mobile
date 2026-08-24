import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Ported from FleetIntelligencePage.jsx's ScoreRing (raw SVG circle +
/// stroke-dasharray) using CustomPainter — same proportions (68px
/// diameter, r=26, strokeWidth=7) and same colour thresholds.
class ScoreRing extends StatelessWidget {
  final int score;
  const ScoreRing({super.key, required this.score});

  Color get _color {
    if (score >= 80) return const Color(0xFF10B981);
    if (score >= 50) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 68,
      height: 68,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(68, 68),
            painter: _ScoreRingPainter(score: score, color: _color),
          ),
          Text('$score', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
        ],
      ),
    );
  }
}

class _ScoreRingPainter extends CustomPainter {
  final int score;
  final Color color;
  _ScoreRingPainter({required this.score, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 7.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final bgPaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweep = 2 * math.pi * (score.clamp(0, 100) / 100);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // start at top, matches SVG's rotate(-90deg)
      sweep,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScoreRingPainter oldDelegate) =>
      oldDelegate.score != score || oldDelegate.color != color;
}