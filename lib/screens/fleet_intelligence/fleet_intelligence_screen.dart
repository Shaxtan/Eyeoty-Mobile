import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/utils/load_status.dart';
import '../../core/fleet_intelligence/agent_meta.dart';
import '../../providers/fleet_intelligence_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/fleet_scan_result.dart';
import '../../widgets/fleet_intelligence/score_ring.dart';
import '../../widgets/fleet_intelligence/stat_tile.dart';
import '../../widgets/fleet_intelligence/agent_card.dart';
import '../../widgets/fleet_intelligence/finding_card.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/error_view.dart';
import '../../widgets/empty_view.dart';

const _severityFilters = ['all', 'critical', 'warning', 'info'];

class FleetIntelligenceScreen extends StatefulWidget {
  const FleetIntelligenceScreen({super.key});

  @override
  State<FleetIntelligenceScreen> createState() => _FleetIntelligenceScreenState();
}

class _FleetIntelligenceScreenState extends State<FleetIntelligenceScreen> {
  final _findingsKey = GlobalKey();
  final _searchCtrl = TextEditingController();

  String _sevFilter = 'all';
  String _agentFilter = 'all';
  String? _codeFilter;
  String _search = '';

  void _runScan({bool isRefetch = false}) {
    final accountId = context.read<AuthProvider>().user?.accountId ?? '1';
    context.read<FleetIntelligenceProvider>().runScan(accountId, isRefetch: isRefetch);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runScan());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _scrollToFindings() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _findingsKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
      }
    });
  }

  void _focusFindings({String severity = 'all', String agent = 'all', String? code}) {
    setState(() {
      _sevFilter = severity;
      _agentFilter = agent;
      _codeFilter = code;
      _search = '';
      _searchCtrl.clear();
    });
    _scrollToFindings();
  }

  void _clearFilters() {
    setState(() {
      _sevFilter = 'all';
      _agentFilter = 'all';
      _codeFilter = null;
      _search = '';
      _searchCtrl.clear();
    });
  }

  List<FleetFinding> _filtered(List<FleetFinding> findings) {
    final term = _search.toLowerCase();
    return findings.where((f) {
      if (_sevFilter != 'all' && f.severity != _sevFilter) return false;
      if (_agentFilter != 'all' && f.agent != _agentFilter) return false;
      if (_codeFilter != null && f.code != _codeFilter) return false;
      if (term.isNotEmpty) {
        final matches = f.title.toLowerCase().contains(term) ||
            f.detail.toLowerCase().contains(term) ||
            (f.vehnum ?? '').toLowerCase().contains(term) ||
            (f.imei ?? '').toLowerCase().contains(term);
        if (!matches) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final fi = context.watch<FleetIntelligenceProvider>();
    final scan = fi.scan;
    final findings = scan?.findings ?? [];
    final filtered = _filtered(findings);
    final hasActiveFilter = _sevFilter != 'all' || _agentFilter != 'all' || _codeFilter != null || _search.isNotEmpty;

    return RefreshIndicator(
      onRefresh: () async => _runScan(isRefetch: true),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'AI agents continuously scan your fleet data for quality, health, and priority issues.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: fi.isRefetching ? null : () => _runScan(isRefetch: true),
                icon: fi.isRefetching
                    ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh, size: 14),
                label: Text(fi.isRefetching ? 'Scanning' : 'Re-scan', style: const TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (fi.status == LoadStatus.loading && scan == null)
            const Padding(padding: EdgeInsets.only(top: 40), child: LoadingView())
          else if (fi.status == LoadStatus.error && scan == null)
            ErrorView(message: fi.errorMessage ?? 'Fleet Intelligence scan failed.', onRetry: _runScan)
          else if (scan != null) ...[
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.5,
              children: [
                SummaryStatCard(
                  leading: ScoreRing(score: scan.summary.dataQualityScore),
                  onTap: () => _focusFindings(agent: 'data-quality'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Data Quality Score',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${scan.summary.devicesScanned} devices scanned',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                ),
                SummaryStatCard(
                  leading: const SummaryStatIcon(
                    icon: Icons.warning_amber_rounded,
                    color: Color(0xFFE11D48),
                    bg: Color(0xFFFFF1F2),
                  ),
                  onTap: () => _focusFindings(severity: 'critical'),
                  content: SummaryStatText(title: 'Critical', value: '${scan.summary.critical}'),
                ),
                SummaryStatCard(
                  leading: const SummaryStatIcon(
                    icon: Icons.bolt_rounded,
                    color: Color(0xFFF59E0B),
                    bg: Color(0xFFFFFBEB),
                  ),
                  onTap: () => _focusFindings(severity: 'warning'),
                  content: SummaryStatText(title: 'Warnings', value: '${scan.summary.warning}'),
                ),
                SummaryStatCard(
                  leading: const SummaryStatIcon(
                    icon: Icons.shield_outlined,
                    color: Color(0xFF2563EB),
                    bg: Color(0xFFEFF6FF),
                  ),
                  onTap: () => _focusFindings(),
                  content: SummaryStatText(title: 'Total Findings', value: '${scan.summary.totalFindings}'),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Per-agent cards
            AgentCard(
              agentKey: 'data-quality',
              loading: false,
              onAgentTap: () => _focusFindings(agent: 'data-quality'),
              onStatTap: (code) => _focusFindings(agent: 'data-quality', code: code),
              stats: [
                AgentStatRow('Corrupt timestamps', '${scan.qualityStats.corruptTimestamp}', code: 'CORRUPT_TIMESTAMP'),
                AgentStatRow('Ignition mismatches', '${scan.qualityStats.ignContradiction}', code: 'IGN_CONTRADICTION'),
                AgentStatRow('Invalid coords', '${scan.qualityStats.invalidCoords}', code: 'INVALID_COORDS'),
                AgentStatRow('Duplicates', '${scan.qualityStats.duplicates}', code: 'DUPLICATE'),
              ],
            ),
            const SizedBox(height: 10),
            AgentCard(
              agentKey: 'device-health',
              loading: false,
              onAgentTap: () => _focusFindings(agent: 'device-health'),
              stats: [
                AgentStatRow('Healthy', '${scan.healthStats.healthy}'),
                AgentStatRow('Degraded', '${scan.healthStats.degraded}'),
                AgentStatRow('Critical', '${scan.healthStats.critical}'),
              ],
            ),
            const SizedBox(height: 10),
            AgentCard(
              agentKey: 'alert-priority',
              loading: false,
              onAgentTap: () => _focusFindings(agent: 'alert-priority'),
              stats: [
                AgentStatRow('Raw alerts', '${scan.priorityStats.rawAlerts}'),
                AgentStatRow('Bursts', '${scan.priorityStats.bursts}'),
                AgentStatRow('Noise removed', '${scan.priorityStats.collapsed}'),
                AgentStatRow('High urgency', '${scan.priorityStats.high + scan.priorityStats.critical}'),
              ],
            ),

            const SizedBox(height: 16),

            // Findings
            Container(key: _findingsKey),
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    children: [
                      Text('Findings (${filtered.length})', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                      if (_agentFilter != 'all')
                        _chip(agentMetaFor(_agentFilter).label, const Color(0xFFEFF6FF), const Color(0xFF2563EB)),
                      if (_codeFilter != null)
                        _chip(_codeFilter!.replaceAll('_', ' ').toLowerCase(), Colors.grey.shade100, Colors.grey.shade700),
                      if (hasActiveFilter)
                        TextButton.icon(
                          onPressed: _clearFilters,
                          icon: const Icon(Icons.close, size: 12),
                          label: const Text('clear', style: TextStyle(fontSize: 11)),
                          style: TextButton.styleFrom(foregroundColor: Colors.grey.shade400, padding: EdgeInsets.zero, minimumSize: Size.zero),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _severityFilters.map((s) {
                  final active = _sevFilter == s;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(s[0].toUpperCase() + s.substring(1)),
                      selected: active,
                      onSelected: (_) => setState(() => _sevFilter = s),
                      labelStyle: const TextStyle(fontSize: 11),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _search = v),
              decoration: const InputDecoration(
                hintText: 'Search vehicle, IMEI\u2026',
                prefixIcon: Icon(Icons.search, size: 18),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),

            if (filtered.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 20),
                child: EmptyView(message: 'No findings \u2014 fleet data looks clean.', icon: Icons.verified_outlined),
              )
            else
              ...filtered.take(200).map(
                    (f) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: FindingCard(
                        finding: f,
                        onTap: f.imei != null ? () => context.go('/tracking?imei=${f.imei}') : null,
                      ),
                    ),
                  ),
          ],
        ],
      ),
    );
  }

  Widget _chip(String label, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
      );
}