import 'package:flutter/material.dart';
import '../core/alerts/alert_type_meta.dart';
import '../models/db_alert.dart';

/// Mobile equivalent of AlertsModal.jsx — a full-height bottom sheet
/// (rather than a centred desktop modal) listing db-alerts, optionally
/// pre-filtered to one type. Data is passed in (already fetched by the
/// dashboard), matching AlertsModal's own `alerts` prop pattern rather
/// than fetching itself.
class AlertTypeListSheet extends StatefulWidget {
  final String type; // 'ALL' or a short type code
  final List<DbAlert> alerts;

  const AlertTypeListSheet(
      {super.key, required this.type, required this.alerts});

  static Future<void> show(BuildContext context,
      {required String type, required List<DbAlert> alerts}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AlertTypeListSheet(type: type, alerts: alerts),
    );
  }

  @override
  State<AlertTypeListSheet> createState() => _AlertTypeListSheetState();
}

class _AlertTypeListSheetState extends State<AlertTypeListSheet> {
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var filtered = widget.type == 'ALL'
        ? widget.alerts
        : widget.alerts.where((a) => a.type == widget.type).toList();

    if (_search.isNotEmpty) {
      final term = _search.toLowerCase();
      filtered = filtered.where((a) {
        return (a.vehicleNumber ?? '').toLowerCase().contains(term) ||
            (a.imei ?? '').toLowerCase().contains(term) ||
            (a.address ?? '').toLowerCase().contains(term) ||
            (a.message ?? '').toLowerCase().contains(term);
      }).toList();
    }

    filtered = [...filtered]
      ..sort((a, b) => (b.createdOn ?? '').compareTo(a.createdOn ?? ''));

    final title = widget.type == 'ALL'
        ? 'All Alerts'
        : '${alertTypeLabel(widget.type)} Alerts';

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$title (${filtered.length})',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _search = v),
                  decoration: const InputDecoration(
                    hintText: 'Search vehicle, IMEI, address...',
                    prefixIcon: Icon(Icons.search, size: 18),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(
                        child: Text('No alerts found.',
                            style: TextStyle(color: Colors.grey)))
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final a = filtered[i];
                          final meta = alertMetaFromMessage(a.message, a.type);
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor:
                                  meta.color.withValues(alpha: 0.12),
                              child:
                                  Icon(meta.icon, color: meta.color, size: 18),
                            ),
                            title: Text(a.vehicleNumber ?? a.imei ?? '\u2014',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 13)),
                            subtitle: Text(
                              a.message ?? a.address ?? '${meta.label} alert',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: Text(
                              a.createdOn ?? '',
                              style: TextStyle(
                                  fontSize: 10, color: Colors.grey.shade500),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
