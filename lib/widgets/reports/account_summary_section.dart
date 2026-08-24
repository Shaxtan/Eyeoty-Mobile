import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../models/account_summary_node.dart';
import '../../repositories/reports_repository.dart';
import '../../widgets/kpi_card.dart';
import '../../widgets/loading_view.dart';
import '../../theme/app_colors.dart';

String _fmtSeconds(num s) {
  if (s <= 0) return '0m';
  final totalSec = s.toInt();
  final h = totalSec ~/ 3600;
  final m = (totalSec % 3600) ~/ 60;
  return h > 0 ? '${h}h ${m}m' : '${m}m';
}

const _pieColors = [
  Color(0xFF1A73E8),
  Color(0xFF00897B),
  Color(0xFFF59E0B),
  Color(0xFFE11D48),
  Color(0xFF7C3AED),
  Color(0xFF0EA5E9),
  Color(0xFF10B981),
  Color(0xFFF97316),
  Color(0xFF6366F1),
  Color(0xFFEC4899),
];

/// Ported from HourlyReportPage.jsx's AccountSummarySection - the
/// embedded mini-dashboard below the report results (4 KPIs, top-10
/// ranked list, fleet donut, sortable sub-account list). "Top 10 by
/// Distance" is a ranked list with proportional bars (same pattern as
/// Dashboard's TopDistanceCard / Overspeed's top-offenders) rather than
/// a true horizontal fl_chart bar, for consistency across the app. The
/// donut IS a real fl_chart PieChart, since "distribution across many
/// accounts" is a genuinely different visualization a list can't convey
/// as well. Sub-account rows are cards, not a horizontal-scroll table -
/// mobile-width adaptation of the desktop's <table>.
class AccountSummarySection extends StatefulWidget {
  final String accountId;
  const AccountSummarySection({super.key, required this.accountId});

  @override
  State<AccountSummarySection> createState() => _AccountSummarySectionState();
}

class _AccountSummarySectionState extends State<AccountSummarySection> {
  AccountSummaryNode? _data;
  bool _loading = false;
  String _search = '';
  int _page = 0;
  String _sortBy = 'totalDistance';
  bool _sortAsc = false;
  static const _perPage = 10;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didUpdateWidget(covariant AccountSummarySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accountId != widget.accountId) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final now = DateTime.now();
    final yest = now.subtract(const Duration(days: 1));
    String fmt(DateTime d) {
      String two(int n) => n.toString().padLeft(2, '0');
      return '${two(d.day)}/${two(d.month)}/${d.year}';
    }

    try {
      final result = await context.read<ReportsRepository>().getAccountSummary(
            accountId: widget.accountId,
            startDate: fmt(yest),
            endDate: fmt(now),
          );
      if (!mounted) return;
      setState(() {
        _data = result;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _handleSort(String col) {
    setState(() {
      if (_sortBy == col) {
        _sortAsc = !_sortAsc;
      } else {
        _sortBy = col;
        _sortAsc = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Padding(padding: EdgeInsets.symmetric(vertical: 30), child: LoadingView());
    final data = _data;
    if (data == null) return const SizedBox.shrink();

    final children = data.childAccounts;
    final flatData = flattenAccountSummary(children);

    final term = _search.toLowerCase();
    final filtered = children.where((a) => term.isEmpty || a.accountName.toLowerCase().contains(term) || a.accountId.contains(term)).toList()
      ..sort((a, b) {
        num av = _sortBy == 'deviceCount' ? a.deviceCount : (_sortBy == 'totalRunTime' ? a.totalRunTime : a.totalDistance);
        num bv = _sortBy == 'deviceCount' ? b.deviceCount : (_sortBy == 'totalRunTime' ? b.totalRunTime : b.totalDistance);
        final cmp = av.compareTo(bv);
        return _sortAsc ? cmp : -cmp;
      });
    final paginated = filtered.skip(_page * _perPage).take(_perPage).toList();

    final maxDist = children.fold<num>(1, (p, e) => e.totalDistance > p ? e.totalDistance : p);
    final maxTime = children.fold<num>(1, (p, e) => e.totalRunTime > p ? e.totalRunTime : p);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Row(
          children: [
            const Icon(Icons.insights_outlined, size: 15, color: AppColors.primary),
            const SizedBox(width: 6),
            const Text('Account Summary Dashboard', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(999)),
              child: const Text('Last 24 hrs', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.primary)),
            ),
            const Spacer(),
            Flexible(child: Text(data.accountName, style: TextStyle(fontSize: 10, color: Colors.grey.shade500), overflow: TextOverflow.ellipsis)),
          ],
        ),
        const SizedBox(height: 12),
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
              label: 'Total Devices',
              value: '${data.deviceCount}',
            ),
            KpiCard(
              icon: Icons.map_outlined,
              iconColor: const Color(0xFF00897B),
              iconBg: const Color(0xFFECFDF5),
              label: 'Total Distance',
              value: '${data.totalDistance} km',
            ),
            KpiCard(
              icon: Icons.access_time,
              iconColor: const Color(0xFFF59E0B),
              iconBg: const Color(0xFFFFFBEB),
              label: 'Total Run Time',
              value: _fmtSeconds(data.totalRunTime),
            ),
            KpiCard(
              icon: Icons.hub_outlined,
              iconColor: const Color(0xFF8E24AA),
              iconBg: const Color(0xFFF5F3FF),
              label: 'Sub-Accounts',
              value: '${children.length}',
            ),
          ],
        ),
        if (flatData.isNotEmpty) ...[
          const SizedBox(height: 16),
          _TopPerformersList(data: flatData),
          const SizedBox(height: 16),
          _FleetDonut(data: flatData),
        ],
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Sub-Account Breakdown', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(999)),
                      child: Text('${filtered.length}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  onChanged: (v) => setState(() {
                    _search = v;
                    _page = 0;
                  }),
                  decoration: const InputDecoration(hintText: 'Search accounts\u2026', prefixIcon: Icon(Icons.search, size: 16), isDense: true),
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Sort:', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    const SizedBox(width: 6),
                    _sortChip('Devices', 'deviceCount'),
                    const SizedBox(width: 4),
                    _sortChip('Distance', 'totalDistance'),
                    const SizedBox(width: 4),
                    _sortChip('Run Time', 'totalRunTime'),
                  ],
                ),
                const SizedBox(height: 8),
                if (paginated.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: Text('No accounts match your search.', style: TextStyle(fontSize: 12, color: Colors.grey.shade500))),
                  )
                else
                  ...paginated.map((acc) {
                    final distPct = (acc.totalDistance / maxDist).clamp(0, 1).toDouble();
                    final timePct = (acc.totalRunTime / maxTime).clamp(0, 1).toDouble();
                    final isActive = acc.totalDistance > 0 || acc.totalRunTime > 0;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(10)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(acc.accountName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: isActive ? const Color(0xFFECFDF5) : Colors.grey.shade100, borderRadius: BorderRadius.circular(999)),
                                child: Text(
                                  isActive ? 'Active' : 'Idle',
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: isActive ? const Color(0xFF047857) : Colors.grey.shade500),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              SizedBox(
                                width: 44,
                                child: Text('${acc.deviceCount}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                              ),
                              const Text('devices', style: TextStyle(fontSize: 9, color: Colors.grey)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              SizedBox(width: 56, child: Text('${acc.totalDistance} km', style: const TextStyle(fontSize: 10))),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: LinearProgressIndicator(value: distPct, minHeight: 5, backgroundColor: Colors.grey.shade100, color: const Color(0xFF14B8A6)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              SizedBox(width: 56, child: Text(_fmtSeconds(acc.totalRunTime), style: const TextStyle(fontSize: 10))),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: LinearProgressIndicator(value: timePct, minHeight: 5, backgroundColor: Colors.grey.shade100, color: const Color(0xFFFBBF24)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                if (filtered.length > _perPage)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_page * _perPage + 1}\u2013${(_page * _perPage + _perPage).clamp(0, filtered.length)} of ${filtered.length}',
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                      ),
                      Row(
                        children: [
                          TextButton(onPressed: _page == 0 ? null : () => setState(() => _page--), child: const Text('Prev', style: TextStyle(fontSize: 11))),
                          TextButton(
                            onPressed: (_page + 1) * _perPage >= filtered.length ? null : () => setState(() => _page++),
                            child: const Text('Next', style: TextStyle(fontSize: 11)),
                          ),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _sortChip(String label, String col) {
    final active = _sortBy == col;
    return InkWell(
      onTap: () => _handleSort(col),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active ? AppColors.primarySoft : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '$label${active ? (_sortAsc ? ' \u2191' : ' \u2193') : ''}',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: active ? AppColors.primary : Colors.grey.shade600),
        ),
      ),
    );
  }
}

class _TopPerformersList extends StatelessWidget {
  final List<AccountSummaryNode> data;
  const _TopPerformersList({required this.data});

  @override
  Widget build(BuildContext context) {
    final top = data.where((a) => a.totalDistance > 0).toList()..sort((a, b) => b.totalDistance.compareTo(a.totalDistance));
    final top10 = top.take(10).toList();
    final max = top10.isNotEmpty ? top10.first.totalDistance : 1;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.trending_up, size: 14, color: AppColors.primary),
              SizedBox(width: 6),
              Text('Top 10 by Distance', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 10),
            if (top10.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text('No distance data yet.', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              )
            else
              ...top10.map((a) {
                final ratio = (a.totalDistance / max).clamp(0, 1).toDouble();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                              child: Text(a.accountName,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          Text('${a.totalDistance} km', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 6,
                          backgroundColor: Colors.grey.shade100,
                          color: AppColors.primary.withValues(alpha: 0.35 + 0.65 * ratio),
                        ),
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

class _FleetDonut extends StatefulWidget {
  final List<AccountSummaryNode> data;
  const _FleetDonut({required this.data});

  @override
  State<_FleetDonut> createState() => _FleetDonutState();
}

class _FleetDonutState extends State<_FleetDonut> {
  int _activeIdx = 0;

  @override
  Widget build(BuildContext context) {
    final sorted = widget.data.where((a) => a.deviceCount > 0).toList()..sort((a, b) => b.deviceCount.compareTo(a.deviceCount));
    final top = sorted.take(14).toList();
    final rest = sorted.skip(14).toList();
    final slices = <MapEntry<String, int>>[
      for (final a in top) MapEntry(a.accountName, a.deviceCount),
      if (rest.isNotEmpty) MapEntry('Others (${rest.length})', rest.fold<int>(0, (s, a) => s + a.deviceCount)),
    ];

    if (slices.isEmpty) return const SizedBox.shrink();
    final safeIdx = _activeIdx.clamp(0, slices.length - 1);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.people_outline, size: 14, color: AppColors.primary),
              SizedBox(width: 6),
              Text('Fleet Distribution', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 10),
            SizedBox(
              height: 220,
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        PieChart(
                          PieChartData(
                            sections: [
                              for (int i = 0; i < slices.length; i++)
                                PieChartSectionData(
                                  value: slices[i].value.toDouble(),
                                  color: _pieColors[i % _pieColors.length].withValues(alpha: i == safeIdx ? 1 : 0.55),
                                  radius: i == safeIdx ? 34 : 28,
                                  showTitle: false,
                                ),
                            ],
                            centerSpaceRadius: 44,
                            sectionsSpace: 2,
                            pieTouchData: PieTouchData(
                              touchCallback: (event, response) {
                                final idx = response?.touchedSection?.touchedSectionIndex;
                                if (idx != null && idx >= 0) setState(() => _activeIdx = idx);
                              },
                            ),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${slices[safeIdx].value}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                            Text('devices', style: TextStyle(fontSize: 9, color: Colors.grey.shade500)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 5,
                    child: ListView.builder(
                      itemCount: slices.length,
                      itemBuilder: (context, i) {
                        final active = i == safeIdx;
                        return InkWell(
                          onTap: () => setState(() => _activeIdx = i),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            color: active ? const Color(0xFFEFF6FF) : null,
                            child: Row(children: [
                              Container(width: 8, height: 8, decoration: BoxDecoration(color: _pieColors[i % _pieColors.length], shape: BoxShape.circle)),
                              const SizedBox(width: 6),
                              Expanded(child: Text(slices[i].key, style: const TextStyle(fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis)),
                              Text('${slices[i].value}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primary)),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}