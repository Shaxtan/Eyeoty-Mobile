import 'package:flutter/material.dart';
import '../../models/alert_model.dart';
import '../../core/alerts/alert_type_meta.dart';

/// Ported from CriticalAlertsListCard.jsx - component source not
/// shared, built from its props (alerts, loading, onViewAll).
class CriticalAlertsListCard extends StatelessWidget {
  final List<FleetAlert> alerts;
  final bool loading;
  final String Function(String alertId) getStatus;
  final VoidCallback onViewAll;

  const CriticalAlertsListCard({
    super.key,
    required this.alerts,
    required this.loading,
    required this.getStatus,
    required this.onViewAll,
  });

  String _fmtDate(String? raw) {
    if (raw == null) return '\u2014';
    final d = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    if (d == null) return raw;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final critical = alerts.where((a) => a.severity == AlertSeverity.critical && getStatus(a.id) == 'open').toList()
      ..sort((a, b) => b.createdOn.compareTo(a.createdOn));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Critical Alerts', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            const Spacer(),
            TextButton(onPressed: onViewAll, child: const Text('View All', style: TextStyle(fontSize: 11))),
          ],
        ),
        if (critical.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(loading ? 'Loading\u2026' : 'No open critical alerts.', style: TextStyle(fontSize: 11.5, color: Colors.grey.shade400)),
            ),
          )
        else
          ...critical.take(8).map((a) {
            final meta = alertTypeMetaFor(a.type);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(color: meta.color.withValues(alpha: 0.12), shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Icon(meta.icon, size: 14, color: meta.color),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.vehicleNumber ?? a.imei, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                        Text('${meta.label} \u00b7 ${_fmtDate(a.deviceTime ?? a.createdOn)}', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}