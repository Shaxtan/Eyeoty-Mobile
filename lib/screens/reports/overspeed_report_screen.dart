import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/alert_model.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/alerts_repository.dart';
import '../../widgets/kpi_card.dart';
import '../../widgets/loading_view.dart';
import '../../theme/app_colors.dart';

class _VehicleAgg {
  final String imei;
  final String vehicle;
  int incidents = 0;
  num maxSpeed = 0;
  num totalSpeed = 0;
  String? lastTs;
  String? lastAddress;
  _VehicleAgg({required this.imei, required this.vehicle});
  num get avgSpeed => incidents > 0 ? (totalSpeed / incidents) : 0;
}

/// Ported 1:1 from OverspeedReportPage.jsx's aggregateByVehicle(): groups
/// alerts by imei, tracks incident count / max speed / running total for
/// average / most recent event, sorted by incident count descending.
List<_VehicleAgg> _aggregateByVehicle(List<FleetAlert> events) {
  final map = <String, _VehicleAgg>{};
  for (final e in events) {
    final key = e.imei.isNotEmpty ? e.imei : (e.vehicleNumber ?? 'Unknown');
    final agg = map.putIfAbsent(key, () => _VehicleAgg(imei: e.imei.isEmpty ? '\u2014' : e.imei, vehicle: e.vehicleNumber ?? e.imei));
    final sp = e.speed ?? 0;
    agg.incidents++;
    agg.totalSpeed += sp;
    if (sp > agg.maxSpeed) agg.maxSpeed = sp;
    final ts = e.deviceTime ?? e.createdOn;
    if (agg.lastTs == null || (DateTime.tryParse(ts) ?? DateTime(1970)).isAfter(DateTime.tryParse(agg.lastTs!) ?? DateTime(1970))) {
      agg.lastTs = ts;
      agg.lastAddress = e.address;
    }
  }
  final list = map.values.toList()..sort((a, b) => b.incidents.compareTo(a.incidents));
  return list;
}

String _fmtTs(String? s) {
  if (s == null || s.isEmpty) return '\u2014';
  final d = DateTime.tryParse(s.replaceFirst(' ', 'T'));
  if (d == null) return s;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
}

/// Ported from OverspeedReportPage.jsx. Reuses AlertsRepository (same
/// POST /usage/alerts/by-account endpoint already wired for
/// AlertsScreen), filtering client-side for type == 'OVS', matching the
/// original's own client-side filter. "Top offenders" is a ranked list
/// with proportional bars (same pattern as Dashboard's TopDistanceCard)
/// rather than a true horizontal fl_chart bar, for consistency with the
/// rest of the app. Export not included (same deferred pattern as other
/// reports). Account selection uses the logged-in user's own account,
/// matching every other screen in this app, rather than the web app's
/// switchable account dropdown.
class OverspeedReportScreen extends StatefulWidget {
  const OverspeedReportScreen({super.key});

  @override
  State<OverspeedReportScreen> createState() => _OverspeedReportScreenState();
}

class _OverspeedReportScreenState extends State<OverspeedReportScreen> {
  DateTime _from = DateTime.now();
  DateTime _to = DateTime.now();
  String? _quick = 'Today';
  num _threshold = 60;
  String _search = '';
  String _view = 'summary'; // 'summary' | 'incidents'

  List<FleetAlert> _rawAlerts = [];
  bool _loading = false;
  bool _fetched = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _applyQuick('Today');
  }

  void _applyQuick(String key) {
    final now = DateTime.now();
    setState(() {
      _quick = key;
      if (key == 'Today') {
        _from = DateTime(now.year, now.month, now.day);
        _to = DateTime(now.year, now.month, now.day, 23, 59, 59);
      } else if (key == 'Yesterday') {
        final y = now.subtract(const Duration(days: 1));
        _from = DateTime(y.year, y.month, y.day);
        _to = DateTime(y.year, y.month, y.day, 23, 59, 59);
      } else {
        final s = now.subtract(const Duration(days: 7));
        _from = DateTime(s.year, s.month, s.day);
        _to = now;
      }
    });
  }

  Future<void> _pickDateTime(bool isFrom) async {
    final base = isFrom ? _from : _to;
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
        _from = combined;
      } else {
        _to = combined;
      }
    });
  }

  Future<void> _search_() async {
    setState(() => _error = null);
    if (_from.isAfter(_to)) {
      setState(() => _error = 'Start date cannot be after end date.');
      return;
    }
    setState(() {
      _loading = true;
      _fetched = true;
    });
    final accountId = context.read<AuthProvider>().user?.accountId ?? '1';
    try {
      final all = await context.read<AlertsRepository>().getAlerts(accountId: accountId, start: _from, end: _to);
      setState(() {
        _rawAlerts = all.where((a) => a.type.toUpperCase() == 'OVS').toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _fmtShort(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final term = _search.toLowerCase();
    final incidents = (term.isEmpty
        ? _rawAlerts
        : _rawAlerts.where((a) => (a.vehicleNumber ?? '').toLowerCase().contains(term) || a.imei.toLowerCase().contains(term)).toList())
      ..sort((a, b) => (DateTime.tryParse(b.createdOn) ?? DateTime(1970)).compareTo(DateTime.tryParse(a.createdOn) ?? DateTime(1970)));

    final summaryAll = _aggregateByVehicle(incidents);
    final summary =
        term.isEmpty ? summaryAll : summaryAll.where((r) => r.vehicle.toLowerCase().contains(term) || r.imei.toLowerCase().contains(term)).toList();

    final totalIncidents = incidents.length;
    final vehiclesAffected = summary.length;
    final maxSpeed = incidents.isEmpty ? 0 : incidents.map((a) => a.speed ?? 0).reduce((a, b) => a > b ? a : b);
    final topOffender = summary.isNotEmpty ? summary.first : null;
    final topIncidentsMax = summaryAll.isNotEmpty ? summaryAll.first.incidents : 1;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Overspeed Report', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Overspeed incidents per vehicle \u2014 frequency, peak speeds, and locations.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                        child: OutlinedButton(
                            onPressed: () => _pickDateTime(true),
                            child: Text('From: ${_fmtShort(_from)}', style: const TextStyle(fontSize: 11)))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: OutlinedButton(
                            onPressed: () => _pickDateTime(false),
                            child: Text('To: ${_fmtShort(_to)}', style: const TextStyle(fontSize: 11)))),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ...['Today', 'Yesterday', 'Last 7 Days'].map((q) => ChoiceChip(
                          label: Text(q, style: const TextStyle(fontSize: 11)),
                          selected: _quick == q,
                          onSelected: (_) => _applyQuick(q),
                        )),
                    const SizedBox(width: 4),
                    const Text('Highlight \u2265', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    SizedBox(
                      width: 56,
                      child: TextFormField(
                        initialValue: '$_threshold',
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 11),
                        decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
                        onChanged: (v) => _threshold = num.tryParse(v) ?? _threshold,
                      ),
                    ),
                    const Text('km/h', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _search_,
                    icon: _loading
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.search, size: 16),
                    label: Text(_loading ? 'Fetching\u2026' : 'Search'),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFFFFF1F2), borderRadius: BorderRadius.circular(10)),
                    child: Text(_error!, style: const TextStyle(color: Color(0xFFE11D48), fontSize: 12)),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.6,
          children: [
            KpiCard(
              icon: Icons.warning_amber_rounded,
              iconColor: const Color(0xFFF43F5E),
              iconBg: const Color(0xFFFFF1F2),
              label: 'Total Incidents',
              value: _fetched ? '$totalIncidents' : '\u2014',
            ),
            KpiCard(
              icon: Icons.local_shipping_outlined,
              iconColor: AppColors.primary,
              iconBg: AppColors.primarySoft,
              label: 'Vehicles Affected',
              value: _fetched ? '$vehiclesAffected' : '\u2014',
            ),
            KpiCard(
              icon: Icons.bolt,
              iconColor: const Color(0xFF8B5CF6),
              iconBg: const Color(0xFFF5F3FF),
              label: 'Max Speed',
              value: _fetched ? '$maxSpeed km/h' : '\u2014',
            ),
            KpiCard(
              icon: Icons.speed,
              iconColor: const Color(0xFFF97316),
              iconBg: const Color(0xFFFFF7ED),
              label: 'Top Offender',
              value: _fetched ? (topOffender?.vehicle ?? 'None') : '\u2014',
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _view == 'summary' ? 'Vehicle Summary (${summary.length})' : 'All Incidents (${incidents.length})',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                      ),
                    ),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'summary', label: Text('Summary', style: TextStyle(fontSize: 11))),
                        ButtonSegment(value: 'incidents', label: Text('Incidents', style: TextStyle(fontSize: 11))),
                      ],
                      selected: {_view},
                      onSelectionChanged: (s) => setState(() => _view = s.first),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_fetched)
                  TextField(
                    onChanged: (v) => setState(() => _search = v),
                    decoration: const InputDecoration(hintText: 'Search vehicle / IMEI\u2026', prefixIcon: Icon(Icons.search, size: 16), isDense: true),
                    style: const TextStyle(fontSize: 12),
                  ),
                const SizedBox(height: 10),
                if (_loading)
                  const Padding(padding: EdgeInsets.symmetric(vertical: 30), child: LoadingView())
                else if (!_fetched)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 30),
                    child: Center(
                        child: Text('Select a date range, then Search.', style: TextStyle(fontSize: 12, color: Colors.grey.shade500))),
                  )
                else if (incidents.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 30),
                    child: Center(
                        child: Text('No overspeed events found.', style: TextStyle(fontSize: 12, color: Colors.grey.shade500))),
                  )
                else if (_view == 'summary')
                  ...summary.asMap().entries.map((entry) {
                    final i = entry.key;
                    final r = entry.value;
                    final over = r.maxSpeed >= _threshold;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        border: Border.all(color: over ? const Color(0xFFFECDD3) : Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 11,
                                backgroundColor: i == 0 ? const Color(0xFFEF4444) : (i <= 2 ? const Color(0xFFF59E0B) : Colors.grey.shade400),
                                child: Text('${i + 1}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text(r.vehicle, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary))),
                              Text('${r.incidents} incidents', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: (r.incidents / topIncidentsMax).clamp(0, 1).toDouble(),
                              minHeight: 5,
                              backgroundColor: Colors.grey.shade100,
                              color: i == 0 ? const Color(0xFFEF4444) : (i <= 2 ? const Color(0xFFF59E0B) : const Color(0xFF8B5CF6)),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text('Max ${r.maxSpeed} km/h', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                              const SizedBox(width: 10),
                              Text('Avg ${r.avgSpeed.round()} km/h', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                              const Spacer(),
                              Text(_fmtTs(r.lastTs), style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                            ],
                          ),
                        ],
                      ),
                    );
                  })
                else
                  ...incidents.map((a) {
                    final sp = a.speed ?? 0;
                    final over = sp >= _threshold;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: over ? const Color(0xFFFFF1F2) : null,
                        border: Border.all(color: over ? const Color(0xFFFECDD3) : Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(a.vehicleNumber ?? a.imei, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary)),
                                const SizedBox(height: 2),
                                Text(_fmtTs(a.deviceTime ?? a.createdOn), style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                                if (a.address != null) ...[
                                  const SizedBox(height: 2),
                                  Text(a.address!, style: TextStyle(fontSize: 10, color: Colors.grey.shade400), maxLines: 1, overflow: TextOverflow.ellipsis),
                                ],
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: over ? const Color(0xFFFFE4E6) : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text('$sp km/h', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: over ? const Color(0xFFE11D48) : Colors.black87)),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ],
    );
  }
}