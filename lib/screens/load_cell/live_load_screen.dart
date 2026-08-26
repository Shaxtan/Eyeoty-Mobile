import 'dart:async';
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

const _refreshInterval = Duration(seconds: 30);

/// Ported from LiveLoadPage.jsx. ChatbotWidget NOT ported (see
/// LoadCellReportScreen's header comment for why). Export not included.
class LiveLoadScreen extends StatefulWidget {
  const LiveLoadScreen({super.key});

  @override
  State<LiveLoadScreen> createState() => _LiveLoadScreenState();
}

class _LiveLoadScreenState extends State<LiveLoadScreen> {
  List<ImeiOption> _imeiList = [];
  bool _imeiLoading = false;
  String? _imei;

  bool _showAvg = true;
  bool _showData = true;
  bool _autoRefresh = true;

  List<LoadCellReading> _chartData = [];
  bool _loading = false;
  DateTime? _lastRefresh;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadImeis());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
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
      // Auto-select + fetch the first IMEI, matching the original's
      // own "auto-select first IMEI and fetch immediately" useEffect.
      if (list.isNotEmpty) {
        setState(() => _imei = list.first.imei);
        _fetchLive(list.first.imei);
      }
    } catch (_) {
      if (mounted) setState(() => _imeiLoading = false);
    }
  }

  Future<void> _fetchLive(String imei) async {
    setState(() => _loading = true);
    try {
      final data = await context.read<LoadCellRepository>().getLiveData(imei);
      if (!mounted) return;
      setState(() {
        _chartData = data;
        _lastRefresh = DateTime.now();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
    _restartTimer();
  }

  void _restartTimer() {
    _timer?.cancel();
    if (_imei == null || !_autoRefresh) return;
    _timer = Timer.periodic(_refreshInterval, (_) {
      if (_imei != null) _fetchLive(_imei!);
    });
  }

  void _onImeiChanged(ImeiOption o) {
    setState(() => _imei = o.imei);
    _fetchLive(o.imei);
  }

  void _onAutoRefreshChanged(bool v) {
    setState(() => _autoRefresh = v);
    _restartTimer();
  }

  String _fmtClock(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
  }

  @override
  Widget build(BuildContext context) {
    final avgCfg = avgConfigFor(_chartData, _showAvg);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Expanded(child: Text('Live Load Graph', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _autoRefresh ? const Color(0xFFECFDF5) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(color: _autoRefresh ? const Color(0xFF10B981) : Colors.grey, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 4),
                  Text(_autoRefresh ? 'Live' : 'Paused',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _autoRefresh ? const Color(0xFF047857) : Colors.grey.shade600)),
                ],
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: (_imei == null || _loading) ? null : () => _fetchLive(_imei!),
            ),
          ],
        ),
        Text('Real-time load cell readings \u2014 auto-refreshes every 30 seconds.', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Vehicle / IMEI', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                ImeiSelectField(options: _imeiList, value: _imei, loading: _imeiLoading, onChanged: _onImeiChanged),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  children: [
                    FilterChip(label: const Text('Average', style: TextStyle(fontSize: 11)), selected: _showAvg, onSelected: (v) => setState(() => _showAvg = v)),
                    FilterChip(label: const Text('Data', style: TextStyle(fontSize: 11)), selected: _showData, onSelected: (v) => setState(() => _showData = v)),
                    FilterChip(label: const Text('Auto-refresh', style: TextStyle(fontSize: 11)), selected: _autoRefresh, onSelected: _onAutoRefreshChanged),
                  ],
                ),
                if (_lastRefresh != null) ...[
                  const SizedBox(height: 8),
                  Text('Last updated: ${_fmtClock(_lastRefresh!)}', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_loading && _chartData.isEmpty)
          const Padding(padding: EdgeInsets.symmetric(vertical: 30), child: LoadingView())
        else if (_imei == null)
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Text('Select an IMEI above to start streaming live data.', style: TextStyle(fontSize: 12, color: Colors.grey.shade500))),
            ),
          )
        else if (_chartData.isNotEmpty) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Live Load Cell Graph', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
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
                  const Text('Live Load Percentage (%)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
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
                      Text('Range: 0%\u2013100%', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  LoadPercentSeriesChart(data: _chartData),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}