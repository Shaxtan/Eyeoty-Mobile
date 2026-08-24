import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_mode_provider.dart';

// Same role gate as the web app's SettingsPage.jsx (Super Admin and
// Administrator both get the full admin console; everyone else gets
// the basic personal-settings section only).
const _fullAccessRoles = ['Super Admin', 'Administrator'];

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeModeProvider>();
    final user = auth.user;
    final hasFullAccess = _fullAccessRoles.contains(user?.role);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionCard(
          title: 'Profile',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoRow('Name', user?.name ?? '\u2014'),
              _infoRow('Email', user?.email ?? '\u2014'),
              _infoRow('Role', user?.role ?? '\u2014'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Preferences',
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Dark Mode'),
            subtitle: const Text('Switch to dark theme', style: TextStyle(fontSize: 12)),
            value: themeProvider.mode == ThemeMode.dark,
            onChanged: (v) => themeProvider.toggle(v),
          ),
        ),
        if (hasFullAccess) ...[
          const SizedBox(height: 12),
          _SectionCard(
            title: 'User & Role Settings',
            subtitle: "Mirrors the web app's admin console \u2014 management actions not yet ported",
            child: Column(
              children: [
                _infoRow('Users', '156'),
                _infoRow('Roles & Permissions', '12'),
                _infoRow('User Groups', '8'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Security Settings',
            child: Column(
              children: [
                _infoRow('Two-Factor Authentication', 'On'),
                _infoRow('Password Policy', 'Configured'),
                _infoRow('Session Timeout', '30 Minutes'),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () => auth.logout(),
          icon: const Icon(Icons.logout, color: Colors.redAccent),
          label: const Text('Log Out', style: TextStyle(color: Colors.redAccent)),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 13))),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ],
        ),
      );
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  const _SectionCard({required this.title, this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 8),
                child: Text(subtitle!, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              )
            else
              const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}
