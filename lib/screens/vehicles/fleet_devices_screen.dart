import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/load_status.dart';
import '../../models/device_item.dart';
import '../../models/unreachable_device.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/error_view.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/account_status_dialog.dart';
import '../../widgets/vehicle_detail_sheet.dart';

const _statusFilters = ['all', 'motion', 'idle', 'stopped', 'offline'];

/// Real screen replacing the /vehicles PendingScreen — mobile equivalent
/// of FleetTableCard.jsx's two tabs (Live Vehicles / Unreachable),
/// rebuilt as a searchable, filterable card list rather than a dense
/// desktop table (Desktop table -> mobile-friendly list/card layout,
/// per conversion guidelines).
///
/// NOTE: CSV/Excel/PDF export from the original table is intentionally
/// NOT included in this pass — flagged as a separate follow-up rather
/// than faked. See project README.
class FleetDevicesScreen extends StatefulWidget {
  const FleetDevicesScreen({super.key});

  @override
  State<FleetDevicesScreen> createState() => _FleetDevicesScreenState();
}

class _FleetDevicesScreenState extends State<FleetDevicesScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String _search = '';
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final accountId = context.read<AuthProvider>().user?.accountId ?? '1';
      final dash = context.read<DashboardProvider>();
      if (dash.summaryStatus == LoadStatus.idle) dash.loadAll(accountId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<DeviceItem> _filteredVts(List<DeviceItem> all) {
    final term = _search.toLowerCase();
    return all.where((d) {
      final matchesStatus = _statusFilter == 'all' || d.status == _statusFilter;
      final matchesSearch = term.isEmpty ||
          d.displayName.toLowerCase().contains(term) ||
          d.imei.toLowerCase().contains(term) ||
          (d.accountName ?? '').toLowerCase().contains(term);
      return matchesStatus && matchesSearch;
    }).toList();
  }

  List<UnreachableDevice> _filteredUnreachable(List<UnreachableDevice> all) {
    final term = _search.toLowerCase();
    if (term.isEmpty) return all;
    return all.where((d) {
      return d.displayName.toLowerCase().contains(term) ||
          d.imei.toLowerCase().contains(term) ||
          (d.accountName ?? '').toLowerCase().contains(term);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final dash = context.watch<DashboardProvider>();
    final vtsAll = dash.vtsDevices;
    final unreachableAll = dash.unreachableDevices;
    final vts = _filteredVts(vtsAll);
    final unreachable = _filteredUnreachable(unreachableAll);

    final counts = {
      for (final f in _statusFilters)
        f: f == 'all' ? vtsAll.length : vtsAll.where((d) => d.status == f).length,
    };

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: const InputDecoration(
              hintText: 'Search vehicle / IMEI / account\u2026',
              prefixIcon: Icon(Icons.search, size: 18),
              isDense: true,
            ),
          ),
        ),
        TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Live (${vtsAll.length})'),
            Tab(text: 'Unreachable (${unreachableAll.length})'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildVtsTab(dash, vts, counts),
              _buildUnreachableTab(dash, unreachable),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVtsTab(DashboardProvider dash, List<DeviceItem> vts, Map<String, int> counts) {
    if (dash.summaryStatus == LoadStatus.loading && dash.vtsDevices.isEmpty) {
      return const LoadingView();
    }
    if (dash.summaryStatus == LoadStatus.error) {
      return ErrorView(
        message: dash.summaryError ?? 'Failed to load vehicles.',
        onRetry: () => dash.loadAll(context.read<AuthProvider>().user?.accountId ?? '1'),
      );
    }
    return Column(
      children: [
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            children: _statusFilters.map((f) {
              final active = _statusFilter == f;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text('${f[0].toUpperCase()}${f.substring(1)} (${counts[f] ?? 0})'),
                  selected: active,
                  onSelected: (_) => setState(() => _statusFilter = f),
                  labelStyle: const TextStyle(fontSize: 11),
                ),
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: vts.isEmpty
              ? const EmptyView(message: 'No vehicles match your filter.', icon: Icons.local_shipping_outlined)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  itemCount: vts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final d = vts[i];
                    return Card(
                      child: ListTile(
                        onTap: () => VehicleDetailSheet.show(context, d),
                        title: Text(d.displayName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 2),
                            if (d.accountName != null)
                              GestureDetector(
                                onTap: () => AccountStatusDialog.show(context, d.accountName!),
                                child: Text(d.accountName!,
                                    style: const TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.w600)),
                              ),
                            Text('${d.speed} km/h \u00b7 ${d.imei}',
                                style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                          ],
                        ),
                        trailing: StatusBadge(status: d.status),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildUnreachableTab(DashboardProvider dash, List<UnreachableDevice> unreachable) {
    if (dash.unreachableStatus == LoadStatus.loading && dash.unreachableDevices.isEmpty) {
      return const LoadingView();
    }
    if (dash.unreachableStatus == LoadStatus.error) {
      return ErrorView(
        message: dash.unreachableError ?? 'Failed to load unreachable devices.',
        onRetry: () => dash.loadAll(context.read<AuthProvider>().user?.accountId ?? '1'),
      );
    }
    if (unreachable.isEmpty) {
      return const EmptyView(message: 'No unreachable devices found.', icon: Icons.location_off_outlined);
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      itemCount: unreachable.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final d = unreachable[i];
        return Card(
          child: ListTile(
            title: Text(d.displayName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                if (d.accountName != null)
                  GestureDetector(
                    onTap: () => AccountStatusDialog.show(context, d.accountName!),
                    child: Text(d.accountName!,
                        style: const TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.w600)),
                  ),
                Text('${d.deviceType ?? '\u2014'} \u00b7 ${d.imei}', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
              ],
            ),
            trailing: Text(d.createdOn ?? '', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}
