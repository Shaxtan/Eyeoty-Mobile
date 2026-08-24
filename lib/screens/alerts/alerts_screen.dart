import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/load_status.dart';
import '../../providers/alerts_provider.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/error_view.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/severity_badge.dart';
import 'alert_detail_sheet.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    final now = DateTime.now();
    context.read<AlertsProvider>().load(
          accountId: '1', // see dashboard_screen.dart note on account defaulting
          start: now.subtract(const Duration(days: 1)),
          end: now,
        );
  }

  @override
  Widget build(BuildContext context) {
    final alerts = context.watch<AlertsProvider>();

    return RefreshIndicator(
      onRefresh: () async => _load(),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Alerts \u2014 last 24 hours',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          Expanded(
            child: Builder(builder: (context) {
              if (alerts.status == LoadStatus.loading && alerts.alerts.isEmpty) {
                return const LoadingView();
              }
              if (alerts.status == LoadStatus.error) {
                return ErrorView(message: alerts.errorMessage ?? 'Failed to load alerts.', onRetry: _load);
              }
              if (alerts.alerts.isEmpty) {
                return const EmptyView(message: 'No alerts in this period.', icon: Icons.notifications_off_outlined);
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: alerts.alerts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final a = alerts.alerts[i];
                  return Card(
                    child: ListTile(
                      onTap: () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => AlertDetailSheet(alert: a),
                      ),
                      title: Text(a.type, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      subtitle: Text(
                        a.vehicleNumber ?? a.imei,
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                      ),
                      trailing: SeverityBadge(severity: a.severity),
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}
