import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/imei_option.dart';
import '../../models/load_cell_reading.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/reports_repository.dart';
import '../../repositories/loadcell_repository.dart';
import '../../widgets/imei_select_field.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/load_cell_charts.dart';

const _quickOptions = ['Today', 'Yesterday', 'Last 3 Days'];

/// Ported from LoadCellReportPage.jsx. ChatbotWidget NOT ported - it's a
/// fully local demo with canned responses and no real backend behavior
/// (selecting an option just prints "conversation complete", nothing
/// actually happens). Export not included (same deferred pattern as
/// other reports).
class LoadCellReportScreen extends StatefulWidget {
  const LoadCellReportScreen({super.key});

  @override
  State<LoadCellReportScreen> createState() => _LoadCellReportScreenState();
}

class _LoadCellReportScreenState extends State<LoadCellReportScreen> {
  List<ImeiOption> _imeiList = [];
  bool _imeiLoading = false;
  String? _imei;

  DateTime _from = DateTime.now();
  DateTime _to = DateTime.now();
  String? _quick;

  bool _showAvg = true;
  bool _showData = true;

  List<LoadCellReading> _chartData = [];
  bool _loading = false;
  bool _searched = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadImeis());
  }

  Future<void> _loadImeis() async {
    setState(() {
      _imeiLoading = true;
      _imei = null;
      _imeiList = [];
    });
    final accountId = context.read<AuthProvider>().user?.accountId ?? '1';
    try {
      final list = await context.read<ReportsRepository>().getImeiDropdown(accountId);
      if (!mounted) return;
      setState(() {
        _imeiList = list;
        _imeiLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _imeiLoading = false);
    }
  }

  void _applyQuick(String key) {
    final now = DateTime.now();
    setState(() {
      _quick = key;
      if (key == 'Today') {
        _from = DateTime(now.year, now.month, now.day);
        _to = DateTime(now.year, now.month, now.day, 23, 59);
      } else if (key == 'Yesterday') {
        final y = now.subtract(const Duration(days: 1));
        _from = DateTime(y.year, y.month, y.day);
        _to = DateTime(y.year, y.month, y.day, 23, 59);
      } else {
        final s = now.subtract(const Duration(days: 3));
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
      setState(() => _error = 'Please select an IMEI.');
      return;
    }
    if (_from.isAfter(_to)) {
      setState(() => _error = 'From date cannot be after To date.');
      return;
    }
    final diffDays = _to.difference(_from).inHours / 24;
    if (diffDays > 3) {
      setState(() => _error = 'Date range cannot exceed 3 days.');
      return;
    }

    setState(() {
      _loading = true;
      _searched = true;
    });
    try {
      final data = await context.read<LoadCellRepository>().getHistoricalData(imei: _imei!, from: _from, to: _to);
      setState(() {
        _chartData = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load load cell data.';
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
    final avgCfg = avgConfigFor(_chartData, _showAvg);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Load Cell Report', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Search and analyse load cell sensor data for any IMEI across a date range.',
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
                ImeiSelectField(options: _imeiList, value: _imei, loading: _imeiLoading, onChanged: (o) => setState(() => _imei = o.imei)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _pickDateTime(true),
                        child: Text('From: ${_fmtShort(_from)}', style: const TextStyle(fontSize: 11)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _pickDateTime(false),
                        child: Text('To: ${_fmtShort(_to)}', style: const TextStyle(fontSize: 11)),
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
                Wrap(
                  spacing: 12,
                  children: [
                    FilterChip(label: const Text('Average', style: TextStyle(fontSize: 11)), selected: _showAvg, onSelected: (v) => setState(() => _showAvg = v)),
                    FilterChip(label: const Text('Data', style: TextStyle(fontSize: 11)), selected: _showData, onSelected: (v) => setState(() => _showData = v)),
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
                    label: Text(_loading ? 'Searching\u2026' : 'Search'),
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
        if (_loading)
          const Padding(padding: EdgeInsets.symmetric(vertical: 30), child: LoadingView())
        else if (_searched && _chartData.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Text('No data found for the selected IMEI and date range.', style: TextStyle(fontSize: 12, color: Colors.grey.shade500))),
            ),
          )
        else if (_chartData.isNotEmpty) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Load Cell Graph with Averages', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                  if (avgCfg != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: avgCfg.badgeBg, borderRadius: BorderRadius.circular(999)),
                          child: Text(avgCfg.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: avgCfg.badgeFg)),
                        ),
                        const SizedBox(width: 8),
                        Text('Avg: ${_chartData.last.average.toStringAsFixed(2)} tons', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  LoadCellSeriesChart(data: _chartData, showData: _showData, avgColor: avgCfg?.stroke),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Load Percentage (%)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: const Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(999)),
                        child: Text('Latest: ${_chartData.last.loadPercent.toStringAsFixed(1)}%',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF6D28D9))),
                      ),
                      const SizedBox(width: 8),
                      Text('Range: 0% \u2013 100%', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  LoadPercentSeriesChart(data: _chartData),
                ],
              ),
            ),
          ),
        ] else
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Text('Select an IMEI and date range, then Search.', style: TextStyle(fontSize: 12, color: Colors.grey.shade500))),
            ),
          ),
      ],
    );
  }
}