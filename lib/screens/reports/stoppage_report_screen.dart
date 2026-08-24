import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/imei_option.dart';
import '../../models/track_point.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/reports_repository.dart';
import '../../widgets/imei_select_field.dart';
import '../../widgets/kpi_card.dart';
import '../../widgets/loading_view.dart';
import '../../theme/app_colors.dart';

class StoppageCluster {
  final String start;
  final String end;
  final int durationMs;
  final double? lat;
  final double? lng;
  StoppageCluster({required this.start, required this.end, required this.durationMs, this.lat, this.lng});
}

const _minDurationOptions = [1, 2, 5, 10, 15, 30];

/// Ported 1:1 from StoppageReportPage.jsx's detectStoppages(): walks the
/// time-sorted points, clusters consecutive STOP points, closes a
/// cluster on any non-STOP point (or end of array), keeps only clusters
/// >= minDurationMs (filters brief traffic-light / sensor-jitter stops).
List<StoppageCluster> _detectStoppages(List<TrackPoint> points, int minDurationMs) {
  if (points.length < 2) return [];
  final sorted = [...points]..sort((a, b) => (a.ts ?? '').compareTo(b.ts ?? ''));

  final clusters = <StoppageCluster>[];
  TrackPoint? clusterStart;
  TrackPoint? clusterEnd;

  void closeCluster() {
    if (clusterStart == null || clusterEnd == null) return;
    final s = DateTime.tryParse((clusterStart!.ts ?? '').replaceFirst(' ', 'T'));
    final e = DateTime.tryParse((clusterEnd!.ts ?? '').replaceFirst(' ', 'T'));
    if (s != null && e != null) {
      final duration = e.difference(s).inMilliseconds;
      if (duration >= minDurationMs) {
        clusters.add(StoppageCluster(
          start: clusterStart!.ts!,
          end: clusterEnd!.ts!,
          durationMs: duration,
          lat: clusterStart!.lat,
          lng: clusterStart!.lng,
        ));
      }
    }
    clusterStart = null;
    clusterEnd = null;
  }

  for (final pt in sorted) {
    if (pt.status == 'STOP') {
      clusterStart ??= pt;
      clusterEnd = pt;
    } else {
      closeCluster();
    }
  }
  closeCluster(); // flush last cluster

  return clusters;
}

String _fmtTs(String? s) {
  if (s == null) return '\u2014';
  final d = DateTime.tryParse(s.replaceFirst(' ', 'T'));
  if (d == null) return s;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
}

String _fmtDuration(int ms) {
  if (ms <= 0) return '0s';
  final totalSec = ms ~/ 1000;
  final h = totalSec ~/ 3600;
  final m = (totalSec % 3600) ~/ 60;
  final s = totalSec % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  if (h > 0) return '${h}h ${two(m)}m ${two(s)}s';
  if (m > 0) return '${m}m ${two(s)}s';
  return '${s}s';
}

/// Ported from StoppageReportPage.jsx. Export not included (same
/// deferred pattern as other reports).
class StoppageReportScreen extends StatefulWidget {
  const StoppageReportScreen({super.key});

  @override
  State<StoppageReportScreen> createState() => _StoppageReportScreenState();
}

class _StoppageReportScreenState extends State<StoppageReportScreen> {
  List<ImeiOption> _imeiList = [];
  bool _imeiLoading = false;
  String? _imei;

  DateTime _from = DateTime.now();
  DateTime _to = DateTime.now();
  String? _quick = 'Today';
  int _minDurMinutes = 2;

  List<StoppageCluster> _stoppages = [];
  bool _loading = false;
  bool _fetched = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadImeis());
  }

  Future<void> _loadImeis() async {
    setState(() => _imeiLoading = true);
    final accountId = context.read<AuthProvider>().user?.accountId ?? '1';
    try {
      final list = await context.read<ReportsRepository>().getImeiDropdown(accountId);
      setState(() {
        _imeiList = list;
        if (list.isNotEmpty) _imei = list.first.imei;
        _imeiLoading = false;
      });
    } catch (_) {
      setState(() => _imeiLoading = false);
    }
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

  Future<void> _search() async {
    setState(() => _error = null);
    if (_imei == null) {
      setState(() => _error = 'Please select a vehicle / IMEI.');
      return;
    }
    if (_from.isAfter(_to)) {
      setState(() => _error = 'Start date cannot be after end date.');
      return;
    }
    setState(() {
      _loading = true;
      _fetched = true;
      _stoppages = [];
    });
    try {
      final points = await context.read<ReportsRepository>().getTrackPlayHistory(
            imei: _imei!,
            startTime: _from.toUtc().toIso8601String(),
            endTime: _to.toUtc().toIso8601String(),
          );
      final result = _detectStoppages(points, _minDurMinutes * 60 * 1000);
      setState(() {
        _stoppages = result;
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
    final totalStops = _stoppages.length;
    final totalMs = _stoppages.fold<int>(0, (sum, s) => sum + s.durationMs);
    final longestMs = _stoppages.isEmpty ? 0 : _stoppages.map((s) => s.durationMs).reduce((a, b) => a > b ? a : b);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Stoppage Report', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Detects where a vehicle stopped, for how long, and maps each stop location.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Vehicle / IMEI', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                ImeiSelectField(
                  options: _imeiList,
                  value: _imei,
                  loading: _imeiLoading,
                  onChanged: (o) => setState(() => _imei = o.imei),
                ),
                const SizedBox(height: 12),
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
                    const Text('Min duration:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    DropdownButton<int>(
                      value: _minDurMinutes,
                      isDense: true,
                      style: const TextStyle(fontSize: 11, color: Colors.black87),
                      items: _minDurationOptions.map((m) => DropdownMenuItem(value: m, child: Text('$m min'))).toList(),
                      onChanged: (v) => setState(() => _minDurMinutes = v ?? 2),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _loading || _imei == null ? null : _search,
                    icon: _loading
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.search, size: 16),
                    label: Text(_loading ? 'Detecting\u2026' : 'Find Stoppages'),
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
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.95,
          children: [
            KpiCard(
              icon: Icons.local_parking_outlined,
              iconColor: AppColors.primary,
              iconBg: AppColors.primarySoft,
              label: 'Total Stops',
              value: _fetched ? '$totalStops' : '\u2014',
            ),
            KpiCard(
              icon: Icons.access_time,
              iconColor: const Color(0xFFF97316),
              iconBg: const Color(0xFFFFF7ED),
              label: 'Total Stopped',
              value: _fetched ? _fmtDuration(totalMs) : '\u2014',
            ),
            KpiCard(
              icon: Icons.timer_outlined,
              iconColor: const Color(0xFFA21CAF),
              iconBg: const Color(0xFFFDF2F8),
              label: 'Longest Stop',
              value: _fetched ? _fmtDuration(longestMs) : '\u2014',
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
                Text('Stoppage Events (${_stoppages.length})', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                if (_loading)
                  const Padding(padding: EdgeInsets.symmetric(vertical: 30), child: LoadingView())
                else if (!_fetched)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 30),
                    child: Center(
                        child: Text('Select a vehicle and date range, then Find Stoppages.',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500))),
                  )
                else if (_stoppages.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 30),
                    child: Center(
                        child: Text('No stoppages found for this period.',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500))),
                  )
                else
                  ..._stoppages.asMap().entries.map((entry) {
                    final i = entry.key;
                    final s = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.grey.shade100,
                            child: Text('${i + 1}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.black87)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${_fmtTs(s.start)} \u2192 ${_fmtTs(s.end)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 3),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(999)),
                                  child: Text(_fmtDuration(s.durationMs), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFB45309))),
                                ),
                              ],
                            ),
                          ),
                          if (s.lat != null && s.lng != null)
                            IconButton(
                              icon: const Icon(Icons.map_outlined, size: 18, color: AppColors.primary),
                              onPressed: () => launchUrl(
                                Uri.parse('https://www.google.com/maps?q=${s.lat},${s.lng}'),
                                mode: LaunchMode.externalApplication,
                              ),
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