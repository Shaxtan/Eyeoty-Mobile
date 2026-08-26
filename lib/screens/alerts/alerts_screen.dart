import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/utils/load_status.dart';
import '../../core/alerts/alert_type_meta.dart';
import '../../core/alerts/alert_status_meta.dart';
import '../../models/alert_model.dart';
import '../../models/account_model.dart';
import '../../providers/alerts_provider.dart';
import '../../providers/alert_triage_provider.dart';
import '../../providers/selected_account_provider.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/error_view.dart';
import '../../widgets/severity_badge.dart';
import '../../widgets/alerts/alert_live_map_card.dart';
import '../../widgets/alerts/alert_severity_donut_card.dart';
import '../../widgets/alerts/alert_categories_card.dart';
import '../../widgets/alerts/alert_performance_card.dart';
import '../../widgets/alerts/response_status_card.dart';
import '../../widgets/alerts/critical_alerts_list_card.dart';

const _quickOptions = ['Today', 'Yesterday', 'Last 7 Days'];
const _pageSizes = [10, 25, 50];

// Threshold-based, not a contractual SLA - "open longer than N minutes",
// ported exactly from AlertsPage.jsx's own SLA_BREACH_MINUTES.
const _slaBreachMinutes = 30;

/// Ported from AlertsPage.jsx ("Alert Dashboard"). Five sub-components
/// (AlertLiveMap, AlertSeverityDonut, AlertCategoriesChart,
/// ResponseStatusCard, CriticalAlertsListCard) and the severity
/// classification file (utils/alertSeverity.js) were not shared as
/// source - see each widget's own header comment and FleetAlert.severity
/// for what's a faithful port vs a reasonable reconstruction from props/
/// usage. useAlertTriage's LOCAL (not server-synced) triage behavior IS
/// fully specified in the original's comments and is faithfully ported
/// as AlertTriageProvider. The desktop's 12-column grid layout (map/
/// donut/performance side-by-side, categories/response/critical
/// side-by-side) is stacked into a single column here, matching every
/// other multi-panel report in this app. Export (CSV/Excel/PDF) is not
/// included, matching the deferred pattern used everywhere else.
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  String? _accountId;
  DateTime _fromDate = DateTime.now().subtract(const Duration(hours: 24));
  DateTime _toDate = DateTime.now();
  String? _quick;
  String _imeiFilter = '';
  String? _error;
  bool _searched = false;

  String _statusTab = 'all'; // all | open | acknowledged | resolved
  int _page = 1;
  int _pageSize = 10;
  bool _mapExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SelectedAccountProvider>().loadAccounts();
    });
  }

  void _ensureAccountDefault(SelectedAccountProvider sel) {
    if (_accountId == null && sel.accounts.isNotEmpty) {
      _accountId = sel.selectedAccount?.id ?? sel.accounts.first.id;
    }
  }

  void _applyQuick(String key) {
    final now = DateTime.now();
    setState(() {
      _quick = key;
      if (key == 'Today') {
        _fromDate = DateTime(now.year, now.month, now.day);
        _toDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
      } else if (key == 'Yesterday') {
        final y = now.subtract(const Duration(days: 1));
        _fromDate = DateTime(y.year, y.month, y.day);
        _toDate = DateTime(y.year, y.month, y.day, 23, 59, 59);
      } else {
        _fromDate = now.subtract(const Duration(days: 7));
        _toDate = now;
      }
    });
  }

  Future<void> _pickDateTime(bool isFrom) async {
    final base = isFrom ? _fromDate : _toDate;
    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(base));
    if (time == null) return;
    setState(() {
      _quick = null;
      final combined = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      if (isFrom) {
        _fromDate = combined;
      } else {
        _toDate = combined;
      }
    });
  }

  Future<void> _search() async {
    setState(() => _error = null);
    if (_accountId == null) {
      setState(() => _error = 'Please select an account and both dates.');
      return;
    }
    setState(() {
      _searched = true;
      _page = 1;
    });
    context.read<AlertTriageProvider>().setAccount(_accountId!);
    await context.read<AlertsProvider>().load(accountId: _accountId!, start: _fromDate, end: _toDate);
  }

  String _fmtDate(String? raw) {
    if (raw == null) return '\u2014';
    final d = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    if (d == null) return raw;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final sel = context.watch<SelectedAccountProvider>();
    final alertsProv = context.watch<AlertsProvider>();
    final triage = context.watch<AlertTriageProvider>();
    _ensureAccountDefault(sel);

    final term = _imeiFilter.trim().toLowerCase();
    final filtered = term.isEmpty
        ? alertsProv.alerts
        : alertsProv.alerts.where((a) => a.imei.toLowerCase().contains(term) || (a.vehicleNumber ?? '').toLowerCase().contains(term)).toList();
    final sorted = [...filtered]..sort((a, b) => b.createdOn.compareTo(a.createdOn));

    final total = sorted.length;
    final ackCount = sorted.where((a) => triage.getStatus(a.id) == 'acknowledged').length;
    final resolvedCount = sorted.where((a) => triage.getStatus(a.id) == 'resolved').length;

    final byVehicle = <String, int>{};
    for (final a in sorted) {
      final key = a.vehicleNumber ?? a.imei;
      byVehicle[key] = (byVehicle[key] ?? 0) + 1;
    }
    final repeatVehicles = byVehicle.values.where((c) => c >= 2).length;

    final criticalOpenCount = sorted.where((a) => a.severity == AlertSeverity.critical && triage.getStatus(a.id) == 'open').length;

    final now = DateTime.now();
    final slaBreachedCount = sorted.where((a) {
      if (triage.getStatus(a.id) != 'open') return false;
      final created = DateTime.tryParse(a.createdOn.replaceFirst(' ', 'T'));
      if (created == null) return false;
      return now.difference(created).inMinutes > _slaBreachMinutes;
    }).length;

    double pctOf(int n) => total > 0 ? (n / total) * 100 : 0;
    final ackRate = pctOf(ackCount);
    final resolvedRate = pctOf(resolvedCount);
    final repeatRate = pctOf(repeatVehicles);
    final slaBreachRate = pctOf(slaBreachedCount);

    final dailyBuckets = <String, int>{};
    for (final a in sorted) {
      final d = DateTime.tryParse(a.createdOn.replaceFirst(' ', 'T'));
      if (d == null) continue;
      final key = '${d.year}-${d.month}-${d.day}';
      dailyBuckets[key] = (dailyBuckets[key] ?? 0) + 1;
    }
    final dailyVolume = dailyBuckets.values.toList();

    final tableRows = _statusTab == 'all' ? sorted : sorted.where((a) => triage.getStatus(a.id) == _statusTab).toList();
    final totalPages = (tableRows.length / _pageSize).ceil().clamp(1, 1 << 30);
    final pageStart = (_page - 1) * _pageSize;
    final pageRows = tableRows.skip(pageStart).take(_pageSize).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Alert Dashboard', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Monitor, prioritize, and review fleet alerts in real time.', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Filter Alert Logs', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                const Text('Account', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                _AccountDropdown(
                  accounts: sel.accounts,
                  loading: sel.loading,
                  value: _accountId,
                  onChanged: (id) => setState(() => _accountId = id),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _pickDateTime(true),
                        child: Text('From: ${_fmtDate('${_fromDate.toIso8601String()}')}', style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _pickDateTime(false),
                        child: Text('To: ${_fmtDate('${_toDate.toIso8601String()}')}', style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  children: _quickOptions
                      .map((q) => ChoiceChip(label: Text(q, style: const TextStyle(fontSize: 11)), selected: _quick == q, onSelected: (_) => _applyQuick(q)))
                      .toList(),
                ),
                const SizedBox(height: 10),
                TextField(
                  onChanged: (v) => setState(() => _imeiFilter = v),
                  decoration: const InputDecoration(hintText: 'Filter by IMEI / Vehicle No\u2026', prefixIcon: Icon(Icons.search, size: 16), isDense: true),
                  style: const TextStyle(fontSize: 12),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFFFFF1F2), borderRadius: BorderRadius.circular(10)),
                    child: Text(_error!, style: const TextStyle(color: Color(0xFFE11D48), fontSize: 12)),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: alertsProv.status == LoadStatus.loading ? null : _search,
                    icon: alertsProv.status == LoadStatus.loading
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.search, size: 16),
                    label: Text(alertsProv.status == LoadStatus.loading ? 'Searching\u2026' : 'Search Logs'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (!_searched)
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.notifications_none_rounded, size: 28, color: Colors.grey.shade300),
                    const SizedBox(height: 8),
                    Text('Choose an account and date range, then search.', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  ],
                ),
              ),
            ),
          )
        else if (alertsProv.status == LoadStatus.error)
          ErrorView(message: alertsProv.errorMessage ?? 'Failed to load alerts.', onRetry: _search)
        else ...[
          // KPI row
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.5,
            children: [
              _kpi(Icons.notifications_none_rounded, const Color(0xFF2563EB), const Color(0xFFEFF6FF), 'Total Alerts', '$total'),
              _kpi(Icons.warning_amber_rounded, const Color(0xFFE11D48), const Color(0xFFFFE4E6), 'Critical Open', '$criticalOpenCount'),
              _kpi(Icons.check_circle_outline, const Color(0xFF2563EB), const Color(0xFFDBEAFE), 'Acknowledged', '$ackCount'),
              _kpi(Icons.verified_user_outlined, const Color(0xFF16A34A), const Color(0xFFDCFCE7), 'Resolved', '$resolvedCount'),
              _kpi(Icons.error_outline_rounded, const Color(0xFFE11D48), const Color(0xFFFEE2E2), 'SLA Breached', '$slaBreachedCount'),
            ],
          ),
          const SizedBox(height: 16),

          // Live map (expandable)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Live Alert Map', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                      ),
                      IconButton(
                        icon: Icon(_mapExpanded ? Icons.close_fullscreen_rounded : Icons.open_in_full_rounded, size: 16),
                        onPressed: () => setState(() => _mapExpanded = !_mapExpanded),
                      ),
                    ],
                  ),
                  Text('All located alerts in the selected period', style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500)),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: _mapExpanded ? 420 : 220,
                    child: AlertLiveMapCard(alerts: sorted, loading: alertsProv.status == LoadStatus.loading),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Alert Severity Distribution', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                  Text('Breakdown by severity level', style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500)),
                  const SizedBox(height: 10),
                  SizedBox(height: 180, child: AlertSeverityDonutCard(alerts: sorted, loading: alertsProv.status == LoadStatus.loading)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Alert Performance', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                  Text(_quick ?? 'Selected period', style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500)),
                  const SizedBox(height: 10),
                  AlertPerformanceCard(
                    ackRate: ackRate,
                    resolvedRate: resolvedRate,
                    repeatRate: repeatRate,
                    slaBreachRate: slaBreachRate,
                    dailyVolume: dailyVolume,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Alert Categories', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  AlertCategoriesCard(alerts: sorted, loading: alertsProv.status == LoadStatus.loading),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Response Status', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  ResponseStatusCard(alerts: sorted, getStatus: triage.getStatus, loading: alertsProv.status == LoadStatus.loading),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          Card(
            key: const ValueKey('critical-alerts-card'),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: CriticalAlertsListCard(
                alerts: sorted,
                loading: alertsProv.status == LoadStatus.loading,
                getStatus: triage.getStatus,
                onViewAll: () => setState(() => _statusTab = 'all'),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // All Alerts
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('All Alerts', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _statusTabChip('all', 'All Alerts', total, const Color(0xFF475569)),
                      _statusTabChip('open', 'Open', sorted.where((a) => triage.getStatus(a.id) == 'open').length, kAlertStatusMeta['open']!.color),
                      _statusTabChip('acknowledged', 'Acknowledged', ackCount, kAlertStatusMeta['acknowledged']!.color),
                      _statusTabChip('resolved', 'Resolved', resolvedCount, kAlertStatusMeta['resolved']!.color),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (alertsProv.status == LoadStatus.loading)
                    const Padding(padding: EdgeInsets.symmetric(vertical: 30), child: LoadingView())
                  else if (pageRows.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 30),
                      child: Center(child: Text('No alerts match this filter.', style: TextStyle(fontSize: 12, color: Colors.grey.shade500))),
                    )
                  else ...[
                    ...pageRows.map((a) => _AlertRow(
                          alert: a,
                          status: triage.getStatus(a.id),
                          onAcknowledge: () => triage.acknowledge(a.id),
                          onResolve: () => triage.resolve(a.id),
                          onReopen: () => triage.reopen(a.id),
                          onTrack: (a.lat != null && a.lng != null) ? () => context.go('/tracking?imei=${a.imei}') : null,
                          fmtDate: _fmtDate,
                        )),
                    if (tableRows.length > _pageSize)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${pageStart + 1}\u2013${(pageStart + _pageSize).clamp(0, tableRows.length)} of ${tableRows.length}',
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                            ),
                            Row(
                              children: [
                                DropdownButton<int>(
                                  value: _pageSize,
                                  isDense: true,
                                  style: const TextStyle(fontSize: 11, color: Colors.black87),
                                  items: _pageSizes.map((n) => DropdownMenuItem(value: n, child: Text('$n / page'))).toList(),
                                  onChanged: (v) => setState(() {
                                    _pageSize = v ?? 10;
                                    _page = 1;
                                  }),
                                ),
                                TextButton(onPressed: _page == 1 ? null : () => setState(() => _page--), child: const Text('Prev', style: TextStyle(fontSize: 11))),
                                TextButton(
                                  onPressed: _page >= totalPages ? null : () => setState(() => _page++),
                                  child: const Text('Next', style: TextStyle(fontSize: 11)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _kpi(IconData icon, Color color, Color bg, String label, String value) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade100)),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 32, height: 32, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9)), child: Icon(icon, color: color, size: 16)),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(label.toUpperCase(), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9, color: Colors.grey.shade500, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
        ],
      ),
    );
  }

  Widget _statusTabChip(String key, String label, int count, Color color) {
    final active = _statusTab == key;
    return InkWell(
      onTap: () => setState(() {
        _statusTab = key;
        _page = 1;
      }),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.1) : Colors.white,
          border: Border.all(color: active ? Colors.transparent : Colors.grey.shade200),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: active ? color : Colors.grey.shade600)),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(color: active ? Colors.white : Colors.grey.shade100, borderRadius: BorderRadius.circular(999)),
              child: Text('$count', style: TextStyle(fontSize: 9.5, color: active ? color : Colors.grey.shade500, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountDropdown extends StatelessWidget {
  final List<Account> accounts;
  final bool loading;
  final String? value;
  final ValueChanged<String> onChanged;
  const _AccountDropdown({required this.accounts, required this.loading, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    if (loading && accounts.isEmpty) {
      return const InputDecorator(decoration: InputDecoration(isDense: true), child: Text('Loading\u2026', style: TextStyle(fontSize: 12, color: Colors.grey)));
    }
    return InputDecorator(
      decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 2)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: accounts.any((a) => a.id == value) ? value : null,
          hint: const Text('Select account', style: TextStyle(fontSize: 12)),
          style: const TextStyle(fontSize: 12, color: Colors.black87),
          items: accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.label, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  final FleetAlert alert;
  final String status;
  final VoidCallback onAcknowledge;
  final VoidCallback onResolve;
  final VoidCallback onReopen;
  final VoidCallback? onTrack;
  final String Function(String?) fmtDate;

  const _AlertRow({
    required this.alert,
    required this.status,
    required this.onAcknowledge,
    required this.onResolve,
    required this.onReopen,
    required this.onTrack,
    required this.fmtDate,
  });

  @override
  Widget build(BuildContext context) {
    final meta = alertTypeMetaFor(alert.type);
    final statusMeta = kAlertStatusMeta[status]!;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(meta.icon, size: 14, color: meta.color),
              const SizedBox(width: 6),
              Expanded(child: Text(meta.label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700))),
              SeverityBadge(severity: alert.severity),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(alert.vehicleNumber ?? 'N/A', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF2563EB))),
              const SizedBox(width: 6),
              Expanded(child: Text(alert.imei, style: TextStyle(fontSize: 10, color: Colors.grey.shade400), overflow: TextOverflow.ellipsis)),
            ],
          ),
          if (alert.address != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.place_outlined, size: 11, color: Colors.grey.shade400),
                const SizedBox(width: 3),
                Expanded(child: Text(alert.address!, style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ],
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.access_time, size: 11, color: Colors.grey.shade400),
              const SizedBox(width: 3),
              Text(fmtDate(alert.deviceTime ?? alert.createdOn), style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: statusMeta.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
                child: Text(statusMeta.label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: statusMeta.color)),
              ),
              const Spacer(),
              if (onTrack != null)
                IconButton(
                  icon: const Icon(Icons.my_location_rounded, size: 16),
                  tooltip: 'Track vehicle',
                  onPressed: onTrack,
                  color: Colors.grey.shade500,
                  visualDensity: VisualDensity.compact,
                ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, size: 16, color: Colors.grey.shade500),
                onSelected: (v) {
                  if (v == 'ack') onAcknowledge();
                  if (v == 'resolve') onResolve();
                  if (v == 'reopen') onReopen();
                },
                itemBuilder: (context) => [
                  if (status == 'open')
                    const PopupMenuItem(value: 'ack', child: Text('Acknowledge', style: TextStyle(fontSize: 12))),
                  if (status == 'acknowledged')
                    const PopupMenuItem(value: 'resolve', child: Text('Resolve', style: TextStyle(fontSize: 12))),
                  if (status != 'open')
                    const PopupMenuItem(value: 'reopen', child: Text('Reopen', style: TextStyle(fontSize: 12))),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}