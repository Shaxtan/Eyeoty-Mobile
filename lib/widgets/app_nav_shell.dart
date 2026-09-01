import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'account_selector_button.dart';
import '../providers/selected_account_provider.dart';
import '../theme/app_colors.dart';


class AppNavShell extends StatefulWidget {
  final Widget child;
  final String currentPath;

  const AppNavShell({super.key, required this.child, required this.currentPath});

  @override
  State<AppNavShell> createState() => _AppNavShellState();
}

class _AppNavShellState extends State<AppNavShell> {
  static const _primaryDestinations = [
    _NavItem('/tracking', Icons.near_me_outlined, 'Tracking'),
    _NavItem('/reports', Icons.description_outlined, 'Reports'),
    _NavItem('/dashboard', Icons.dashboard_outlined, 'Dashboard'),
    _NavItem('/alerts', Icons.notifications_outlined, 'Alerts'),
    _NavItem('/settings', Icons.settings_outlined, 'Settings'),
  ];

  // Everything else from the original sidebar, grouped into sections
  // for scannability. Reachable via the Drawer/sidebar on every width,
  // satisfying "no dead-end screens" even though most of these route
  // to an honest PendingScreen for now.
  static const _moreSections = [
    _NavSection('FLEET', [
      _NavItem('/fleet-intelligence', Icons.auto_awesome_outlined, 'Fleet Intelligence'),
      _NavItem('/map-view', Icons.map_outlined, 'Map View'),
      _NavItem('/vehicles', Icons.local_shipping_outlined, 'Vehicles'),
      _NavItem('/trips', Icons.alt_route_outlined, 'Trips'),
      _NavItem('/geofence', Icons.fence_outlined, 'Geofence'),
      _NavItem('/analytics', Icons.bar_chart_outlined, 'Analytics'),
    ]),
    _NavSection('IOT & SENSORS', [
      _NavItem('/iot-sensors', Icons.sensors_outlined, 'IoT Sensors'),
      _NavItem('/load-cell', Icons.scale_outlined, 'Load Cell Report'),
      _NavItem('/live-load', Icons.show_chart_outlined, 'Live Load Graph'),
    ]),
  ];

  static final List<_NavItem> _allMore = [for (final s in _moreSections) ...s.items];
  static final List<_NavItem> _all = [..._primaryDestinations, ..._allMore];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SelectedAccountProvider>().loadAccounts();
    });
  }

  int _selectedPrimaryIndex() {
    return _primaryDestinations.indexWhere((d) => widget.currentPath.startsWith(d.path));
  }

  String _titleFor(String path) {
    final match = _all.where((d) => path.startsWith(d.path));
    return match.isNotEmpty ? match.first.label : 'Eyeoty';
  }

  Widget _sectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.sidebarMuted, letterSpacing: 0.8),
      ),
    );
  }

  List<Widget> _sidebarContent({required bool includePrimary, required void Function(String path) onTap}) {
    return [
      if (includePrimary) ...[
        for (final d in _primaryDestinations)
          _SidebarItem(icon: d.icon, label: d.label, active: widget.currentPath.startsWith(d.path), onTap: () => onTap(d.path)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Divider(color: AppColors.sidebarLine, height: 1),
        ),
      ],
      for (final section in _moreSections) ...[
        _sectionHeader(section.title),
        for (final d in section.items)
          _SidebarItem(icon: d.icon, label: d.label, active: widget.currentPath.startsWith(d.path), onTap: () => onTap(d.path)),
      ],
      const SizedBox(height: 12),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 900;
    final selected = _selectedPrimaryIndex();
    final body = SafeArea(child: widget.child);

    if (isWide) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_titleFor(widget.currentPath)),
          actions: const [AccountSelectorButton()],
        ),
        body: Row(
          children: [
            Container(
              width: 240,
              color: AppColors.sidebar,
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: _sidebarContent(includePrimary: true, onTap: (path) => context.go(path)),
              ),
            ),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_titleFor(widget.currentPath)),
        actions: const [AccountSelectorButton()],
      ),
      drawer: Drawer(
        backgroundColor: AppColors.sidebar,
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: _sidebarContent(
              includePrimary: false,
              onTap: (path) {
                Navigator.pop(context);
                context.go(path);
              },
            ),
          ),
        ),
      ),
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected == -1 ? 0 : selected,
        onDestinationSelected: (i) => context.go(_primaryDestinations[i].path),
        destinations: _primaryDestinations
            .map((d) => NavigationDestination(icon: Icon(d.icon), label: d.label))
            .toList(),
      ),
    );
  }
}

/// Shared nav-row styling for both the wide sidebar and the narrow
/// drawer: a left accent bar + soft tinted background on the active
/// item, muted label otherwise - the standard dark-sidebar pattern.
class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _SidebarItem({required this.icon, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.white.withValues(alpha: 0.06),
        highlightColor: Colors.white.withValues(alpha: 0.03),
        child: Container(
          decoration: BoxDecoration(
            color: active ? AppColors.sidebarSoft : Colors.transparent,
            border: Border(left: BorderSide(color: active ? AppColors.brandGold : Colors.transparent, width: 3)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 19, color: active ? Colors.white : AppColors.sidebarText),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active ? Colors.white : AppColors.sidebarText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavSection {
  final String title;
  final List<_NavItem> items;
  const _NavSection(this.title, this.items);
}

class _NavItem {
  final String path;
  final IconData icon;
  final String label;
  const _NavItem(this.path, this.icon, this.label);
}