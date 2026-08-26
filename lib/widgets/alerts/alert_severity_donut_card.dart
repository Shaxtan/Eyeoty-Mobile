import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/alert_model.dart';
import '../../core/alerts/alert_severity_meta.dart';

/// Ported from AlertSeverityDonut.jsx - component source not shared,
/// built from its props (alerts, loading). Same fl_chart PieChart
/// pattern used by AccountSummarySection's Fleet Distribution donut.
class AlertSeverityDonutCard extends StatefulWidget {
  final List<FleetAlert> alerts;
  final bool loading;
  const AlertSeverityDonutCard({super.key, required this.alerts, required this.loading});

  @override
  State<AlertSeverityDonutCard> createState() => _AlertSeverityDonutCardState();
}

class _AlertSeverityDonutCardState extends State<AlertSeverityDonutCard> {
  int _activeIdx = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.alerts.isEmpty) {
      return Center(
        child: Text(
          widget.loading ? 'Loading\u2026' : 'No alerts in this period.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
        ),
      );
    }

    final counts = <AlertSeverity, int>{for (final s in AlertSeverity.values) s: 0};
    for (final a in widget.alerts) {
      counts[a.severity] = (counts[a.severity] ?? 0) + 1;
    }
    final entries = AlertSeverity.values.where((s) => counts[s]! > 0).toList();
    if (entries.isEmpty) return const SizedBox.shrink();
    final safeIdx = _activeIdx.clamp(0, entries.length - 1);

    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sections: [
                    for (var i = 0; i < entries.length; i++)
                      PieChartSectionData(
                        value: counts[entries[i]]!.toDouble(),
                        color: severityColor(entries[i]).withValues(alpha: i == safeIdx ? 1 : 0.55),
                        radius: i == safeIdx ? 32 : 26,
                        showTitle: false,
                      ),
                  ],
                  centerSpaceRadius: 38,
                  sectionsSpace: 2,
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) {
                      final idx = response?.touchedSection?.touchedSectionIndex;
                      if (idx != null && idx >= 0) setState(() => _activeIdx = idx);
                    },
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${counts[entries[safeIdx]]}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  Text(severityLabel(entries[safeIdx]), style: TextStyle(fontSize: 9, color: Colors.grey.shade500)),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          flex: 5,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < entries.length; i++)
                InkWell(
                  onTap: () => setState(() => _activeIdx = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                    color: i == safeIdx ? const Color(0xFFEFF6FF) : null,
                    child: Row(children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: severityColor(entries[i]), shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Expanded(child: Text(severityLabel(entries[i]), style: const TextStyle(fontSize: 11))),
                      Text('${counts[entries[i]]}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                    ]),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}