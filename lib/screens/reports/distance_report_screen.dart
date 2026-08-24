import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../providers/selected_account_provider.dart';
import '../../models/imei_option.dart';
import '../../models/distance_report_result.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/reports_repository.dart';
import '../../widgets/imei_select_field.dart';
import '../../widgets/kpi_card.dart';
import '../../widgets/loading_view.dart';
import '../../theme/app_colors.dart';

const _quickOptions = ['Today', 'Yesterday', 'Last 7 Days'];

/// Ported from DistanceReportPage.jsx. Export (CSV/Excel/PDF) is NOT
/// included - same deferred-feature pattern as FleetDevicesScreen.
class DistanceReportScreen extends StatefulWidget {
  const DistanceReportScreen({super.key});

  @override
  State<DistanceReportScreen> createState() => _DistanceReportScreenState();
}

class _DistanceReportScreenState extends State<DistanceReportScreen> {
  List<ImeiOption> _imeiList = [];
  bool _imeiLoading = false;
  String? _imei;

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  String? _quick = 'Today';

  DistanceReportResult? _report;
  bool _loading = false;
  String? _error;
  DateTime? _committedStart;
  DateTime? _committedEnd;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadImeis());
  }

  Future<void> _loadImeis() async {
    setState(() => _imeiLoading = true);
    final accountId =
        context.read<SelectedAccountProvider>().selectedAccount?.id ??
            context.read<AuthProvider>().user?.accountId ??
            '1';
    try {
      final list =
          await context.read<ReportsRepository>().getImeiDropdown(accountId);
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
        _startDate = now;
        _endDate = now;
      } else if (key == 'Yesterday') {
        final y = now.subtract(const Duration(days: 1));
        _startDate = y;
        _endDate = y;
      } else {
        _startDate = now.subtract(const Duration(days: 7));
        _endDate = now;
      }
    });
  }

  // yyyy-mm-dd -> d/MM/yyyy, matching the web app's toApiDate() exactly
  // (day NOT zero-padded, month/year are).
  String _toApiDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.day}/${two(d.month)}/${d.year}';
  }

  Future<void> _fetchReport() async {
    setState(() => _error = null);
    if (_imei == null) {
      setState(() => _error = 'Please select a vehicle / IMEI.');
      return;
    }
    if (_startDate.isAfter(_endDate)) {
      setState(() => _error = 'Start date cannot be after end date.');
      return;
    }
    setState(() {
      _loading = true;
      _committedStart = _startDate;
      _committedEnd = _endDate;
    });
    try {
      final result = await context.read<ReportsRepository>().getDistanceReport(
            imei: _imei!,
            startDate: _toApiDate(_startDate),
            endDate: _toApiDate(_endDate),
          );
      setState(() {
        _report = result;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _report = null;
        _loading = false;
      });
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _quick = null;
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  bool get _isSingleDay =>
      _committedStart != null &&
      _committedEnd != null &&
      _committedStart!.year == _committedEnd!.year &&
      _committedStart!.month == _committedEnd!.month &&
      _committedStart!.day == _committedEnd!.day;

  double _chartMaxY(List<DistanceRecord> records) {
    var max = 1.0;
    for (final r in records) {
      if (r.distance.toDouble() > max) max = r.distance.toDouble();
      if (r.speed.toDouble() > max) max = r.speed.toDouble();
    }
    return max * 1.2;
  }

  String _shortDate(String? iso) {
    if (iso == null) return '';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${d.day} ${months[d.month - 1]}';
  }

  Widget _legendDot(Color color, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final chartRecords = (_report?.vehicleDistances ?? []).where((r) {
      return _isSingleDay
          ? r.hr != null
          : (r.repDate != null && r.repDate!.isNotEmpty);
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Distance Report',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(
            'Daily or hourly distance travelled and average speed per vehicle.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Vehicle / IMEI',
                    style:
                        TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
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
                        onPressed: () => _pickDate(true),
                        child: Text(
                            'From: ${_startDate.day}/${_startDate.month}/${_startDate.year}',
                            style: const TextStyle(fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _pickDate(false),
                        child: Text(
                            'To: ${_endDate.day}/${_endDate.month}/${_endDate.year}',
                            style: const TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  children: _quickOptions.map((q) {
                    return ChoiceChip(
                      label: Text(q, style: const TextStyle(fontSize: 11)),
                      selected: _quick == q,
                      onSelected: (_) => _applyQuick(q),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _loading || _imei == null ? null : _fetchReport,
                    icon: _loading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.search, size: 16),
                    label: Text(_loading ? 'Searching\u2026' : 'Search'),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F2),
                        borderRadius: BorderRadius.circular(10)),
                    child: Text(_error!,
                        style: const TextStyle(
                            color: Color(0xFFE11D48), fontSize: 12)),
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
              icon: Icons.local_shipping_outlined,
              iconColor: AppColors.primary,
              iconBg: AppColors.primarySoft,
              label: 'Vehicle Number',
              value: _report?.vehNum ?? '\u2014',
            ),
            KpiCard(
              icon: Icons.tag,
              iconColor: const Color(0xFF16A34A),
              iconBg: const Color(0xFFECFDF5),
              label: 'IMEI',
              value: _report?.imei ?? _imei ?? '\u2014',
            ),
            KpiCard(
              icon: Icons.map_outlined,
              iconColor: const Color(0xFF4F46E5),
              iconBg: const Color(0xFFEEF2FF),
              label: 'Total Distance',
              value:
                  _report != null ? '${_report!.totalDistanceKm} km' : '\u2014',
            ),
            KpiCard(
              icon: Icons.speed,
              iconColor: const Color(0xFFF97316),
              iconBg: const Color(0xFFFFF7ED),
              label: 'Avg Speed',
              value: _report != null ? '${_report!.avgSpeed} km/h' : '\u2014',
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
                Text(
                    _isSingleDay
                        ? 'Hourly Distance & Speed'
                        : 'Daily Distance & Speed',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                if (_loading)
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 30),
                      child: LoadingView())
                else if (_report == null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 30),
                    child: Center(
                        child: Text(
                            'Select a vehicle and date range, then Search.',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade500))),
                  )
                else if (chartRecords.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 30),
                    child: Center(
                        child: Text('No data found for the selected range.',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade500))),
                  )
                else
                  SizedBox(
                    height: 240,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: _chartMaxY(chartRecords),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 32,
                              getTitlesWidget: (v, m) => Text('${v.toInt()}',
                                  style: TextStyle(
                                      fontSize: 9,
                                      color: Colors.grey.shade400)),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 26,
                              getTitlesWidget: (v, m) {
                                final i = v.toInt();
                                if (i < 0 || i >= chartRecords.length)
                                  return const SizedBox.shrink();
                                final r = chartRecords[i];
                                final label = _isSingleDay
                                    ? '${r.hr}h'
                                    : _shortDate(r.repDate);
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(label,
                                      style: TextStyle(
                                          fontSize: 8,
                                          color: Colors.grey.shade400)),
                                );
                              },
                            ),
                          ),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (v) => FlLine(
                              color: Colors.grey.shade100, strokeWidth: 1),
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: [
                          for (int i = 0; i < chartRecords.length; i++)
                            BarChartGroupData(x: i, barRods: [
                              BarChartRodData(
                                toY: chartRecords[i].distance.toDouble(),
                                color: const Color(0xFF0EA5E9),
                                width: 6,
                                borderRadius: BorderRadius.circular(2),
                              ),
                              BarChartRodData(
                                toY: chartRecords[i].speed.toDouble(),
                                color: const Color(0xFFF97316),
                                width: 6,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ]),
                        ],
                      ),
                    ),
                  ),
                if (chartRecords.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _legendDot(const Color(0xFF0EA5E9), 'Distance (km)'),
                      const SizedBox(width: 12),
                      _legendDot(const Color(0xFFF97316), 'Speed (km/h)'),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
