import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/alerts/alerts_screen.dart';
import '../screens/tracking/tracking_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/vehicles/fleet_devices_screen.dart';
import '../screens/fleet_intelligence/fleet_intelligence_screen.dart';
import '../screens/map_view/map_view_screen.dart';
import '../screens/reports/reports_screen.dart';
import '../screens/reports/distance_report_screen.dart';
import '../screens/reports/stoppage_report_screen.dart';
import '../screens/reports/overspeed_report_screen.dart';
import '../screens/reports/track_play_screen.dart';
import '../screens/reports/working_hour_report_screen.dart';
import '../screens/load_cell/load_cell_report_screen.dart';
import '../screens/load_cell/live_load_screen.dart';
import '../widgets/app_nav_shell.dart';
import '../widgets/pending_screen.dart';

GoRouter buildRouter(AuthProvider authProvider) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: authProvider,
    redirect: (context, state) {
      final loggingIn = state.matchedLocation == '/login';
      final atSplash = state.matchedLocation == '/';

      if (authProvider.status == AuthStatus.unknown) {
        return atSplash ? null : '/';
      }

      final loggedIn = authProvider.status == AuthStatus.authenticated;

      if (!loggedIn && !loggingIn) return '/login';
      if (loggedIn && (loggingIn || atSplash)) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      ShellRoute(
        builder: (context, state, child) {
          return AppNavShell(currentPath: state.matchedLocation, child: child);
        },
        routes: [
          GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
          GoRoute(
            path: '/tracking',
            builder: (context, state) =>
                TrackingScreen(initialImei: state.uri.queryParameters['imei']),
          ),
          GoRoute(path: '/alerts', builder: (_, __) => const AlertsScreen()),
          GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),

          // Real screen — replaces the old PendingScreen now that
          // FleetTableCard.jsx / dashboard.service.js have been ported.
          GoRoute(path: '/vehicles', builder: (_, __) => const FleetDevicesScreen()),

          // Real screen — UI fully ported from FleetIntelligencePage.jsx.
          // Data layer is intentionally NOT wired (useFleetScan.js source
          // wasn't available) — see FleetIntelligenceService for details.
          GoRoute(path: '/fleet-intelligence', builder: (_, __) => const FleetIntelligenceScreen()),

          // Real screen — ported from MapPage.jsx.
          GoRoute(path: '/map-view', builder: (_, __) => const MapViewScreen()),

          // Real — ported from ReportsPage.jsx + 3 of its 6 sub-reports.
          // Distance / Stoppage / Overspeed are fully wired; Hourly,
          // Track Play, and Fuel Theft are deliberately deferred (see
          // the batch notes) and route to an honest PendingScreen below
          // rather than a dead end.
          GoRoute(path: '/reports', builder: (_, __) => const ReportsScreen()),
          GoRoute(path: '/reports/distance', builder: (_, __) => const DistanceReportScreen()),
          GoRoute(path: '/reports/stoppage', builder: (_, __) => const StoppageReportScreen()),
          GoRoute(path: '/reports/overspeed', builder: (_, __) => const OverspeedReportScreen()),
          GoRoute(path: '/reports/trackplay', builder: (_, __) => const TrackPlayScreen()),
          GoRoute(path: '/reports/hourly', builder: (_, __) => const WorkingHourReportScreen()),
          GoRoute(path: '/reports/fuel-theft', builder: (_, __) => const PendingScreen(title: 'Fuel Theft Report')),

          // Real screens — ported from LoadCellReportPage.jsx /
          // LiveLoadPage.jsx. ChatbotWidget intentionally not ported on
          // either (fully local demo, no real backend behavior).
          GoRoute(path: '/load-cell', builder: (_, __) => const LoadCellReportScreen()),
          GoRoute(path: '/live-load', builder: (_, __) => const LiveLoadScreen()),

          // Screens present in the original web app's sidebar but not
          // ported yet — see README.md "Screens not yet ported".
          GoRoute(path: '/trips', builder: (_, __) => const PendingScreen(title: 'Trips')),
          GoRoute(path: '/geofence', builder: (_, __) => const PendingScreen(title: 'Geofence')),
          GoRoute(path: '/analytics', builder: (_, __) => const PendingScreen(title: 'Analytics')),
          GoRoute(path: '/iot-sensors', builder: (_, __) => const PendingScreen(title: 'IoT Sensors')),
        ],
      ),
    ],
  );
}