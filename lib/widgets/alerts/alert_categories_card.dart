import 'package:flutter/material.dart';
import '../../models/alert_model.dart';
import '../../core/alerts/alert_type_meta.dart';

/// Ported from AlertCategoriesChart.jsx - component source not shared,
/// built from its props (alerts, loading). Ranked-bar-list pattern,
/// same as Dashboard's TopDistanceCard / AccountSummarySection.
class AlertCategoriesCard extends StatelessWidget {
  final List<FleetAlert> alerts;
  final bool loading;
  const AlertCategoriesCard({super.key, required this.alerts, required this.loading});

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) {
      return Center(
        child: Text(loading ? 'Loading\u2026' : 'No alerts in this period.', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
      );
    }
    final counts = <String, int>{};
    for (final a in alerts) {
      counts[a.type] = (counts[a.type] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final max = sorted.isNotEmpty ? sorted.first.value : 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sorted.map((e) {
        final meta = alertTypeMetaFor(e.key);
        final ratio = (e.value / max).clamp(0, 1).toDouble();
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(meta.icon, size: 13, color: meta.color),
                  const SizedBox(width: 6),
                  Expanded(child: Text(meta.label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700))),
                  Text('${e.value}', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: meta.color)),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(value: ratio, minHeight: 6, backgroundColor: Colors.grey.shade100, color: meta.color),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}