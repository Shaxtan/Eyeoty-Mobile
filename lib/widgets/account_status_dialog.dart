import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/account_status.dart';
import '../providers/accounts_provider.dart';

/// Mobile equivalent of FleetTableCard.jsx's AccountPopup — a tap dialog
/// instead of a hover-anchored popup (Desktop hover -> tap, per
/// conversion guidelines). Resolves the account name to an ID via the
/// cached dropdown, then fetches fresh status, matching the web
/// behaviour exactly.
class AccountStatusDialog extends StatefulWidget {
  final String accountName;
  const AccountStatusDialog({super.key, required this.accountName});

  static Future<void> show(BuildContext context, String accountName) {
    return showDialog(context: context, builder: (_) => AccountStatusDialog(accountName: accountName));
  }

  @override
  State<AccountStatusDialog> createState() => _AccountStatusDialogState();
}

class _AccountStatusDialogState extends State<AccountStatusDialog> {
  bool _loading = true;
  AccountStatus? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final accountsProvider = context.read<AccountsProvider>();
    await accountsProvider.ensureLoaded();
    final id = accountsProvider.resolveIdByName(widget.accountName);
    if (id == null) {
      setState(() {
        _loading = false;
        _error = 'Account "${widget.accountName}" not found in dropdown.';
      });
      return;
    }
    try {
      final status = await accountsProvider.fetchStatus(id);
      setState(() {
        _data = status;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: SizedBox(
          width: 260,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.apartment, size: 15),
                  const SizedBox(width: 6),
                  const Text('Account Info', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Row(children: [
                    SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 10),
                    Text('Fetching\u2026', style: TextStyle(fontSize: 12)),
                  ]),
                )
              else if (_error != null)
                Text(_error!, style: const TextStyle(fontSize: 12, color: Colors.redAccent))
              else if (_data != null) ...[
                _row('Name', _data!.name ?? '\u2014'),
                _row('ID', _data!.id ?? '\u2014'),
                _row('Type', _data!.type ?? '\u2014'),
                _row('Parent', _data!.parentAccountId ?? '\u2014'),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Status', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _data!.isActive ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _data!.statusLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _data!.isActive ? Colors.green.shade700 : Colors.red.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
