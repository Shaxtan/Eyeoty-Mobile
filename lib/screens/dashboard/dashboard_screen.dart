import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/utils/load_status.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/top_distance_item.dart';
import '../../widgets/kpi_card.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/error_view.dart';
import '../../widgets/dashboard/recent_alerts_card.dart';
import '../../widgets/dashboard/fleet_utilization_card.dart';
import '../../widgets/dashboard/top_distance_card.dart';
import '../../widgets/dashboard/fleet_devices_summary_card.dart';
import '../../theme/app_colors.dart';

/// Redesigned Dashboard - Live Map removed per request. Structure:
/// a navy gradient greeting header (time-of-day + first name, both real,
/// not placeholder text), uppercase section labels ("Overview", "Alerts",
/// "Utilization", "Performance", "Fleet") ahead of each card group, and a
/// refreshed KpiCard style laid out 3-per-row. All data logic
/// (DashboardProvider, each card's own loading/error state) is
/// untouched - this is a layout/visual pass only.
///
/// NOTE: lib/widgets/dashboard/live_map_card.dart is no longer imported
/// here and is now unused - left in the project since deleting files
/// wasn't asked for. Safe to delete manually if you don't need it
/// elsewhere.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  void _loadAll() {
    final accountId = context.read<AuthProvider>().user?.accountId ?? '1';
    context.read<DashboardProvider>().loadAll(accountId);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final dash = context.watch<DashboardProvider>();
    final user = context.watch<AuthProvider>().user;
    final firstName = user != null && user.name.trim().isNotEmpty ? user.name.trim().split(' ').first : 'there';

    return RefreshIndicator(
      onRefresh: () async => _loadAll(),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Greeting header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.sidebar, AppColors.sidebarSoft],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_greeting()}, $firstName',
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Here's what's happening with your fleet today.",
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Overview (KPI grid)
                if (dash.summaryStatus == LoadStatus.loading && dash.summary == null)
                  const Padding(padding: EdgeInsets.only(top: 20), child: LoadingView())
                else if (dash.summaryStatus == LoadStatus.error)
                  ErrorView(message: dash.summaryError ?? 'Failed to load dashboard.', onRetry: _loadAll)
                else if (dash.summary != null) ...[
                  const _SectionLabel('Overview'),
                  const SizedBox(height: 10),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.95,
                    children: [
                      KpiCard(
                        icon: Icons.local_shipping_outlined,
                        iconColor: AppColors.primary,
                        iconBg: AppColors.primarySoft,
                        label: 'Total Vehicles',
                        value: '${dash.summary!.totalVehicles}',
                      ),
                      KpiCard(
                        icon: Icons.speed,
                        iconColor: AppColors.statusMoving,
                        iconBg: AppColors.statusMoving.withValues(alpha: 0.1),
                        label: 'Moving',
                        value: '${dash.summary!.moving}',
                      ),
                      KpiCard(
                        icon: Icons.error_outline,
                        iconColor: AppColors.brandRed,
                        iconBg: AppColors.brandRed.withValues(alpha: 0.1),
                        label: 'Stopped',
                        value: '${dash.summary!.stopped}',
                      ),
                      KpiCard(
                        icon: Icons.hourglass_bottom,
                        iconColor: AppColors.statusIdle,
                        iconBg: AppColors.statusIdle.withValues(alpha: 0.1),
                        label: 'Idle',
                        value: '${dash.summary!.idle}',
                      ),
                      KpiCard(
                        icon: Icons.wifi_off,
                        iconColor: Colors.deepPurple,
                        iconBg: Colors.deepPurple.withValues(alpha: 0.08),
                        label: 'Offline',
                        value: '${dash.summary!.offline}',
                      ),
                      KpiCard(
                        icon: Icons.location_off_outlined,
                        iconColor: Colors.grey,
                        iconBg: Colors.grey.withValues(alpha: 0.12),
                        label: 'Unreachable',
                        value: '${dash.summary!.unreachable}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],

                // Alerts
                const _SectionLabel('Alerts'),
                const SizedBox(height: 10),
                RecentAlertsCard(
                  alerts: dash.dbAlerts?.alerts ?? [],
                  loading: dash.dbAlertsStatus == LoadStatus.loading && dash.dbAlerts == null,
                ),
                const SizedBox(height: 24),

                // Utilization
                const _SectionLabel('Utilization'),
                const SizedBox(height: 10),
                FleetUtilizationCard(
                  data: dash.utilization,
                  loading: dash.utilizationStatus == LoadStatus.loading && dash.utilization == null,
                ),
                const SizedBox(height: 24),

                // Performance
                const _SectionLabel('Performance'),
                const SizedBox(height: 10),
                TopDistanceCard(
                  data: dash.topDistance,
                  loading: dash.topDistanceStatus == LoadStatus.loading && dash.topDistance.isEmpty,
                  onTapItem: (TopDistanceItem d) {
                    if (d.imei != null) context.go('/tracking?imei=${d.imei}');
                  },
                  onViewFullReport: () => context.go('/reports'),
                ),
                const SizedBox(height: 24),

                // Fleet
                const _SectionLabel('Fleet'),
                const SizedBox(height: 10),
                FleetDevicesSummaryCard(
                  liveCount: dash.vtsDevices.length,
                  unreachableCount: dash.unreachableDevices.length,
                  loading: dash.summaryStatus == LoadStatus.loading && dash.vtsDevices.isEmpty,
                  onViewAll: () => context.go('/vehicles'),
                ),

                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
        color: Colors.grey.shade500,
      ),
    );
  }
}