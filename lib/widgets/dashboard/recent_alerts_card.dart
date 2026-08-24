import 'package:flutter/material.dart';
import '../../core/alerts/alert_type_meta.dart';
import '../../models/db_alert.dart';
import '../alert_type_list_sheet.dart';

/// Compact "Recent Alerts" list, matching RecentAlertsListCard.jsx —
/// icon + title + subtitle + right-aligned time, most recent 5 first.
/// "View All" opens AlertTypeListSheet (mobile equivalent of AlertsModal).
class RecentAlertsCard extends StatelessWidget {
  final List<DbAlert> alerts;
  final bool loading;

  const RecentAlertsCard({super.key, required this.alerts, required this.loading});

  String _subtitle(DbAlert a) {
    if (a.type == 'OVS') {
      return 'Truck ${a.vehicleNumber ?? a.imei} exceeded ${a.speed ?? '\u2014'} km/h';
    }
    if (a.type == 'GEO') return 'Truck ${a.vehicleNumber ?? a.imei} exited zone';
    if (a.type == 'BAT') return 'Device ${a.imei} battery at ${a.battery ?? '\u2014'}V';
    return a.message ?? a.address ?? '${alertTypeLabel(a.type)} alert';
  }

  @override
  Widget build(BuildContext context) {
    final recent = [...alerts]
      ..sort((a, b) => (b.createdOn ?? '').compareTo(a.createdOn ?? ''));
    final top5 = recent.take(5).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Recent Alerts', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                const Spacer(),
                TextButton(
                  onPressed: () => AlertTypeListSheet.show(context, type: 'ALL', alerts: alerts),
                  child: const Text('View All', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            if (loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (top5.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('No recent alerts.', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                ),
              )
            else
              ...top5.map((a) {
                final meta = alertTypeMetaFor(a.type);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(color: meta.color.withValues(alpha: 0.12), shape: BoxShape.circle),
                        child: Icon(meta.icon, size: 15, color: meta.color),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(meta.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(
                              _subtitle(a),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        a.createdOn ?? '',
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
