import 'package:flutter/material.dart';
import 'mini_sparkline.dart';

/// Ported from AlertPerformanceContent (defined inline in AlertsPage.jsx
/// - full source available, ported directly): 4 real, computable rate
/// metrics + a daily-volume sparkline per row. No fabricated historical
/// data, matching the original's own stated intent.
class AlertPerformanceCard extends StatelessWidget {
  final double ackRate;
  final double resolvedRate;
  final double repeatRate;
  final double slaBreachRate;
  final List<int> dailyVolume;

  const AlertPerformanceCard({
    super.key,
    required this.ackRate,
    required this.resolvedRate,
    required this.repeatRate,
    required this.slaBreachRate,
    required this.dailyVolume,
  });

  @override
  Widget build(BuildContext context) {
    final rows = [
      (Icons.check_circle_outline, const Color(0xFF2563EB), 'Acknowledgement Rate', '${ackRate.toStringAsFixed(1)}%'),
      (Icons.verified_user_outlined, const Color(0xFF16A34A), 'Resolution Rate', '${resolvedRate.toStringAsFixed(1)}%'),
      (Icons.repeat_rounded, const Color(0xFFD97706), 'Repeat Alert Rate', '${repeatRate.toStringAsFixed(1)}%'),
      (Icons.warning_amber_rounded, const Color(0xFFE11D48), 'SLA Breach Rate', '${slaBreachRate.toStringAsFixed(1)}%'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: r.$2.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(9)),
                  alignment: Alignment.center,
                  child: Icon(r.$1, size: 15, color: r.$2),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.$3, style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500)),
                      Text(r.$4, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                SizedBox(width: 60, child: MiniSparkline(data: dailyVolume, color: r.$2)),
              ],
            ),
          ),
        const Divider(height: 1),
        const SizedBox(height: 8),
        Text(
          'Rates computed from alerts in the selected period. Sparkline shows daily alert volume.',
          style: TextStyle(fontSize: 9.5, color: Colors.grey.shade400, height: 1.3),
        ),
      ],
    );
  }
}