import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/account_model.dart';
import '../providers/selected_account_provider.dart';
import '../theme/app_colors.dart';

/// Ported from Topbar.jsx's AccountSelector - the app-wide account
/// switcher. Desktop adaptation: the anchored dropdown panel becomes a
/// bottom sheet (same pattern as ImeiSelectField/AccountSelectField),
/// and it lives in the AppBar's actions (right side), matching the
/// original's right-aligned placement in the topbar.
class AccountSelectorButton extends StatelessWidget {
  const AccountSelectorButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SelectedAccountProvider>(
      builder: (context, prov, _) {
        if (prov.loading || prov.selectedAccount == null) {
          return const Padding(
            padding: EdgeInsets.only(right: 16),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () async {
              final picked = await showModalBottomSheet<Account>(
                context: context,
                isScrollControlled: true,
                builder: (_) => _AccountPickerSheet(
                  accounts: prov.accounts,
                  selectedId: prov.selectedAccount?.id,
                ),
              );
              if (picked != null) prov.setAccount(picked.id);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              constraints: const BoxConstraints(maxWidth: 160),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.business_outlined, size: 14, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      prov.selectedAccount!.label,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.expand_more, size: 14, color: Colors.grey),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AccountPickerSheet extends StatefulWidget {
  final List<Account> accounts;
  final String? selectedId;
  const _AccountPickerSheet({required this.accounts, required this.selectedId});

  @override
  State<_AccountPickerSheet> createState() => _AccountPickerSheetState();
}

class _AccountPickerSheetState extends State<_AccountPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.accounts.where((a) => a.label.toLowerCase().contains(_query.toLowerCase())).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
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
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Icon(Icons.business_outlined, size: 16, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text('Switch Account', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  autofocus: true,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    hintText: 'Search accounts\u2026',
                    prefixIcon: Icon(Icons.search, size: 18),
                    isDense: true,
                  ),
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('No accounts found', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          final a = filtered[i];
                          final active = a.id == widget.selectedId;
                          return ListTile(
                            leading: CircleAvatar(
                              radius: 14,
                              backgroundColor: active ? AppColors.primary : Colors.grey.shade200,
                              child: Text(
                                a.label.isNotEmpty ? a.label[0].toUpperCase() : '?',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: active ? Colors.white : Colors.black87),
                              ),
                            ),
                            title: Text(
                              a.label,
                              style: TextStyle(fontSize: 13, fontWeight: active ? FontWeight.w800 : FontWeight.w500, color: active ? AppColors.primary : Colors.black87),
                            ),
                            subtitle: Text('${a.vehicles} vehicles', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                            trailing: active ? const Icon(Icons.check, size: 16, color: AppColors.primary) : null,
                            onTap: () => Navigator.pop(context, a),
                          );
                        },
                      ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(color: Colors.grey.shade50, border: Border(top: BorderSide(color: Colors.grey.shade100))),
                child: Row(
                  children: [
                    Text('${widget.accounts.length} accounts', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}