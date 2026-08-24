import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'logo.dart';
import 'account_selector_button.dart';
import '../providers/selected_account_provider.dart';

/// Responsive navigation shell wrapping every authenticated route.
///
/// - Narrow widths (phone) -> BottomNavigationBar + Drawer for the rest.
/// - Wide widths (tablet / Chrome desktop) -> NavigationRail + a "More"
///   list alongside the content, mirroring the existing web app's
///   persistent left sidebar WITHOUT simply stretching the mobile
///   layout across the screen.
///
/// This is the ONLY Scaffold in the authenticated part of the app —
/// individual screens (DashboardScreen, AlertsScreen, etc.) return
/// plain body content, not their own Scaffold/AppBar, so this shell's
/// single AppBar + Drawer + BottomNavigationBar work correctly together.
///
/// Converted from Stateless -> Stateful in this pass: this is the one
/// place guaranteed to build only once a user is authenticated (it's
/// the ShellRoute wrapper for every logged-in route), so it's the
/// natural, one-time trigger point for SelectedAccountProvider's
/// fetch-once loadAccounts() - matching where the web app's account
/// store gets initialized.
class AppNavShell extends StatefulWidget {
  final Widget child;
  final String currentPath;

  const AppNavShell(
      {super.key, required this.child, required this.currentPath});

  @override
  State<AppNavShell> createState() => _AppNavShellState();
}

class _AppNavShellState extends State<AppNavShell> {
  static const _primaryDestinations = [
    _NavItem('/dashboard', Icons.dashboard_outlined, 'Dashboard'),
    _NavItem('/tracking', Icons.near_me_outlined, 'Tracking'),
    _NavItem('/alerts', Icons.notifications_outlined, 'Alerts'),
    _NavItem('/settings', Icons.settings_outlined, 'Settings'),
  ];

  // Everything else from the original sidebar. Reachable via the
  // Drawer/"More" list on every width, satisfying "no dead-end screens"
  // even though most of these route to an honest PendingScreen for now.
  static const _moreDestinations = [
    _NavItem('/fleet-intelligence', Icons.auto_awesome_outlined,
        'Fleet Intelligence'),
    _NavItem('/map-view', Icons.map_outlined, 'Map View'),
    _NavItem('/vehicles', Icons.local_shipping_outlined, 'Vehicles'),
    _NavItem('/trips', Icons.alt_route_outlined, 'Trips'),
    _NavItem('/geofence', Icons.fence_outlined, 'Geofence'),
    _NavItem('/reports', Icons.description_outlined, 'Reports'),
    _NavItem('/analytics', Icons.bar_chart_outlined, 'Analytics'),
    _NavItem('/iot-sensors', Icons.sensors_outlined, 'IoT Sensors'),
    _NavItem('/load-cell', Icons.scale_outlined, 'Load Cell Report'),
    _NavItem('/live-load', Icons.show_chart_outlined, 'Live Load Graph'),
  ];

  static final List<_NavItem> _all = [
    ..._primaryDestinations,
    ..._moreDestinations
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SelectedAccountProvider>().loadAccounts();
    });
  }

  int _selectedPrimaryIndex() {
    final i = _primaryDestinations
        .indexWhere((d) => widget.currentPath.startsWith(d.path));
    return i;
  }

  String _titleFor(String path) {
    final match = _all.where((d) => path.startsWith(d.path));
    return match.isNotEmpty ? match.first.label : 'Eyeoty';
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
            NavigationRail(
              selectedIndex: selected == -1 ? 0 : selected,
              onDestinationSelected: (i) =>
                  context.go(_primaryDestinations[i].path),
              labelType: NavigationRailLabelType.all,
              destinations: _primaryDestinations
                  .map((d) => NavigationRailDestination(
                      icon: Icon(d.icon), label: Text(d.label)))
                  .toList(),
            ),
            const VerticalDivider(width: 1),
            SizedBox(
              width: 220,
              child: ListView(
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text('MORE',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey)),
                  ),
                  for (final d in _moreDestinations)
                    ListTile(
                      dense: true,
                      leading: Icon(d.icon, size: 20),
                      title:
                          Text(d.label, style: const TextStyle(fontSize: 13)),
                      selected: widget.currentPath.startsWith(d.path),
                      onTap: () => context.go(d.path),
                    ),
                ],
              ),
            ),
            const VerticalDivider(width: 1),
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
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              width: double.infinity,
              color: const Color(0xFF0E1A30),
              child: const SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 18, 20, 18),
                  child: Logo(size: 20),
                ),
              ),
            ),
            for (final d in _moreDestinations)
              ListTile(
                leading: Icon(d.icon),
                title: Text(d.label),
                selected: widget.currentPath.startsWith(d.path),
                onTap: () {
                  Navigator.pop(context);
                  context.go(d.path);
                },
              ),
          ],
        ),
      ),
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected == -1 ? 0 : selected,
        onDestinationSelected: (i) => context.go(_primaryDestinations[i].path),
        destinations: _primaryDestinations
            .map((d) =>
                NavigationDestination(icon: Icon(d.icon), label: d.label))
            .toList(),
      ),
    );
  }
}

class _NavItem {
  final String path;
  final IconData icon;
  final String label;
  const _NavItem(this.path, this.icon, this.label);
}
