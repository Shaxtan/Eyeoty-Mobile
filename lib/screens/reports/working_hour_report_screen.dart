import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/account_model.dart';
import '../../models/imei_option.dart';
import '../../models/working_hour_record.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/accounts_repository.dart';
import '../../repositories/reports_repository.dart';
import '../../widgets/account_select_field.dart';
import '../../widgets/imei_select_field.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/reports/account_summary_section.dart';
import 'session_detail_screen.dart';

const _quickOptions = ['Today', 'Yesterday', 'Last 7 Days'];

String _fmtDuration(dynamic v) {
  if (v == null) return '\u2014';
  if (v is String && v.contains(':')) return v;
  final mins = int.tryParse('$v') ?? 0;
  final h = mins ~/ 60;
  final m = mins % 60;
  return h > 0 ? '${h}h ${m}m' : '${m}m';
}

/// Ported from HourlyReportPage.jsx. Session detail (with map playback)
/// is a separate pushed screen (session_detail_screen.dart) rather than
/// a centered modal overlay - see that file's header comment. Export
/// not included (same deferred pattern as other reports).
class WorkingHourReportScreen extends StatefulWidget {
  const WorkingHourReportScreen({super.key});

  @override
  State<WorkingHourReportScreen> createState() => _WorkingHourReportScreenState();
}

class _WorkingHourReportScreenState extends State<WorkingHourReportScreen> {
  List<Account> _accountList = [];
  bool _accountLoading = false;
  String? _selectedAccountId;

  List<ImeiOption> _imeiList = [];
  bool _imeiLoading = false;
  String? _imei;

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  String? _quick = 'Today';

  List<WorkingHourRecord> _records = [];
  bool _loading = false;
  bool _fetched = false;
  String? _error;
  String _search = '';
  int _page = 0;
  int _rowsPerPage = 10;

  String _defaultAccountId = '1';

  @override
  void initState() {
    super.initState();
    _defaultAccountId = context.read<AuthProvider>().user?.accountId ?? '1';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAccounts();
      _loadImeis();
    });
  }

  String get _resolvedAccountId => _selectedAccountId ?? _defaultAccountId;

  Future<void> _loadAccounts() async {
    setState(() => _accountLoading = true);
    try {
      final list = await context.read<AccountsRepository>().getAccountDropdown();
      if (!mounted) return;
      setState(() {
        _accountList = list;
        _accountLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _accountLoading = false);
    }
  }

  Future<void> _loadImeis() async {
    setState(() {
      _imeiLoading = true;
      _imei = null;
      _imeiList = [];
    });
    try {
      final list = await context.read<ReportsRepository>().getImeiDropdown(_resolvedAccountId);
      if (!mounted) return;
      setState(() {
        _imeiList = list;
        if (list.isNotEmpty) _imei = list.first.imei;
        _imeiLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _imeiLoading = false);
    }
  }

  void _onAccountChanged(Account a) {
    setState(() => _selectedAccountId = a.id);
    _loadImeis();
  }

  void _clearAccount() {
    setState(() => _selectedAccountId = null);
    _loadImeis();
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

  String _toApiDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.day}/${two(d.month)}/${d.year}';
  }

  Future<void> _fetch() async {
    setState(() => _error = null);
    if (_imei == null) {
      setState(() => _error = 'Please select a vehicle / IMEI.');
      return;
    }
    setState(() {
      _loading = true;
      _fetched = true;
    });
    try {
      final data = await context.read<ReportsRepository>().getWorkingHourReport(
            imei: _imei!,
            startDate: _toApiDate(_startDate),
            endDate: _toApiDate(_endDate),
          );
      setState(() {
        _records = data;
        _loading = false;
        _page = 0;
        if (data.isEmpty) _error = 'No data found for the selected filters.';
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to fetch report. Please try again.';
        _loading = false;
      });
    }
  }

  List<WorkingHourRecord> get _filtered {
    if (_search.isEmpty) return _records;
    final term = _search.toLowerCase();
    return _records
        .where((r) => r.imei.toLowerCase().contains(term) || (r.vehNum ?? '').toLowerCase().contains(term) || (r.repDate ?? '').contains(term))
        .toList();
  }

  String? _accountNameFor(String? id) {
    if (id == null) return null;
    for (final a in _accountList) {
      if (a.id == id) return a.label;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final paginated = filtered.skip(_page * _rowsPerPage).take(_rowsPerPage).toList();
    final selectedAccountName = _accountNameFor(_selectedAccountId);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Working Hour Report', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Session-level trip data with playback and account-wide analytics.', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Account', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                AccountSelectField(options: _accountList, value: _selectedAccountId, loading: _accountLoading, onChanged: _onAccountChanged),
                const SizedBox(height: 12),
                const Text('Vehicle / IMEI', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                ImeiSelectField(options: _imeiList, value: _imei, loading: _imeiLoading, onChanged: (o) => setState(() => _imei = o.imei)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _pickDate(true),
                        child: Text('From: ${_startDate.day}/${_startDate.month}/${_startDate.year}', style: const TextStyle(fontSize: 11)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _pickDate(false),
                        child: Text('To: ${_endDate.day}/${_endDate.month}/${_endDate.year}', style: const TextStyle(fontSize: 11)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  children: _quickOptions.map((q) {
                    return ChoiceChip(label: Text(q, style: const TextStyle(fontSize: 11)), selected: _quick == q, onSelected: (_) => _applyQuick(q));
                  }).toList(),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _loading || _imei == null ? null : _fetch,
                    icon: _loading
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.search, size: 16),
                    label: Text(_loading ? 'Fetching\u2026' : 'Get Report'),
                  ),
                ),
                if (selectedAccountName != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.insights_outlined, size: 12, color: Color(0xFF2563EB)),
                        const SizedBox(width: 6),
                        Flexible(child: Text('Summary for: $selectedAccountName', style: const TextStyle(fontSize: 11, color: Color(0xFF2563EB)))),
                        const SizedBox(width: 6),
                        InkWell(onTap: _clearAccount, child: const Icon(Icons.close, size: 12, color: Color(0xFF2563EB))),
                      ],
                    ),
                  ),
                ],
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
        if (_fetched || _records.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Report Results', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                      const SizedBox(width: 6),
                      Text('${filtered.length} record(s)', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    onChanged: (v) => setState(() {
                      _search = v;
                      _page = 0;
                    }),
                    decoration: const InputDecoration(hintText: 'Search IMEI, vehicle, date\u2026', prefixIcon: Icon(Icons.search, size: 16), isDense: true),
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  if (_loading)
                    const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: LoadingView())
                  else if (filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: Text('No data found for the selected filters.', style: TextStyle(fontSize: 12, color: Colors.grey.shade500))),
                    )
                  else ...[
                    ...paginated.map((r) {
                      final complete = r.sessions.isNotEmpty && r.sessions.every((s) => s.status == 'COMPLETE');
                      return InkWell(
                        onTap: r.sessions.isEmpty
                            ? null
                            : () => Navigator.push(context, MaterialPageRoute(builder: (_) => SessionDetailScreen(record: r))),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(10)),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(r.vehNum ?? r.imei,
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF2563EB)),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: complete ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            complete ? 'Complete' : 'Partial',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w700,
                                              color: complete ? const Color(0xFF047857) : const Color(0xFFB45309),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(r.repDate?.split('T').first ?? '\u2014', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(999)),
                                          child: Text('${r.sessions.length} sessions', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF2563EB))),
                                        ),
                                        const SizedBox(width: 8),
                                        Text('${r.totalDistance} km', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                                        const SizedBox(width: 8),
                                        Text(_fmtDuration(r.totalDuration), style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (r.sessions.isNotEmpty) Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade400),
                            ],
                          ),
                        ),
                      );
                    }),
                    if (filtered.length > _rowsPerPage)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_page * _rowsPerPage + 1}\u2013${(_page * _rowsPerPage + _rowsPerPage).clamp(0, filtered.length)} of ${filtered.length}',
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                          ),
                          Row(
                            children: [
                              DropdownButton<int>(
                                value: _rowsPerPage,
                                isDense: true,
                                style: const TextStyle(fontSize: 11, color: Colors.black87),
                                items: [10, 25, 50].map((n) => DropdownMenuItem(value: n, child: Text('$n / page'))).toList(),
                                onChanged: (v) => setState(() {
                                  _rowsPerPage = v ?? 10;
                                  _page = 0;
                                }),
                              ),
                              TextButton(onPressed: _page == 0 ? null : () => setState(() => _page--), child: const Text('Prev', style: TextStyle(fontSize: 11))),
                              TextButton(
                                onPressed: (_page + 1) * _rowsPerPage >= filtered.length ? null : () => setState(() => _page++),
                                child: const Text('Next', style: TextStyle(fontSize: 11)),
                              ),
                            ],
                          ),
                        ],
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
        AccountSummarySection(accountId: _resolvedAccountId),
      ],
    );
  }
}