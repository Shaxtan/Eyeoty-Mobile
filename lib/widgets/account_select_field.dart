import 'package:flutter/material.dart';
import '../models/account_model.dart';

/// Same bottom-sheet-search pattern as ImeiSelectField, for the
/// Account dropdown used by Working Hour Report.
class AccountSelectField extends StatelessWidget {
  final List<Account> options;
  final String? value;
  final bool loading;
  final String placeholder;
  final ValueChanged<Account> onChanged;

  const AccountSelectField({
    super.key,
    required this.options,
    required this.value,
    required this.loading,
    required this.onChanged,
    this.placeholder = 'Select account\u2026',
  });

  Account? get _selected {
    for (final o in options) {
      if (o.id == value) return o;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: loading
          ? null
          : () async {
              final picked = await showModalBottomSheet<Account>(
                context: context,
                isScrollControlled: true,
                builder: (_) => _AccountSearchSheet(options: options),
              );
              if (picked != null) onChanged(picked);
            },
      child: InputDecorator(
        decoration: const InputDecoration(isDense: true),
        child: Row(
          children: [
            Expanded(
              child: Text(
                loading ? 'Loading\u2026' : (_selected?.label ?? placeholder),
                style: TextStyle(
                  color: _selected != null ? Colors.black87 : Colors.grey.shade500,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.expand_more, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class _AccountSearchSheet extends StatefulWidget {
  final List<Account> options;
  const _AccountSearchSheet({required this.options});

  @override
  State<_AccountSearchSheet> createState() => _AccountSearchSheetState();
}

class _AccountSearchSheetState extends State<_AccountSearchSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.options.where((o) => o.label.toLowerCase().contains(_query.toLowerCase())).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  autofocus: true,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    hintText: 'Search\u2026',
                    prefixIcon: Icon(Icons.search, size: 18),
                    isDense: true,
                  ),
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('No matches', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          final o = filtered[i];
                          return ListTile(
                            title: Text(o.label, style: const TextStyle(fontSize: 13)),
                            onTap: () => Navigator.pop(context, o),
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