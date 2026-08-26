import 'package:flutter/material.dart';
import '../../models/alert_model.dart';
import '../../core/alerts/alert_status_meta.dart';

/// Ported from ResponseStatusCard.jsx - component source not shared,
/// built from its props (alerts, getStatus, loading).
class ResponseStatusCard extends StatelessWidget {
  final List<FleetAlert> alerts;
  final String Function(String alertId) getStatus;
  final bool loading;
  const ResponseStatusCard({super.key, required this.alerts, required this.getStatus, required this.loading});

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) {
      return Center(
        child: Text(loading ? 'Loading\u2026' : 'No alerts in this period.', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
      );
    }
    final counts = <String, int>{'open': 0, 'acknowledged': 0, 'resolved': 0};
    for (final a in alerts) {
      final s = getStatus(a.id);
      counts[s] = (counts[s] ?? 0) + 1;
    }
    final total = alerts.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final key in ['open', 'acknowledged', 'resolved'])
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: kAlertStatusMeta[key]!.color, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Expanded(child: Text(kAlertStatusMeta[key]!.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                    Text('${counts[key]}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: kAlertStatusMeta[key]!.color)),
                    const SizedBox(width: 6),
                    Text(
                      '(${total > 0 ? ((counts[key]! / total) * 100).toStringAsFixed(0) : 0}%)',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: total > 0 ? counts[key]! / total : 0,
                    minHeight: 6,
                    backgroundColor: Colors.grey.shade100,
                    color: kAlertStatusMeta[key]!.color,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}