  import 'package:flutter/material.dart';
  import 'package:go_router/go_router.dart';
  import 'package:provider/provider.dart';

  import 'providers/auth_provider.dart';
  import 'providers/dashboard_provider.dart';
  import 'providers/alerts_provider.dart';
  import 'providers/tracking_provider.dart';
  import 'providers/accounts_provider.dart';
  import 'providers/fleet_intelligence_provider.dart';
  import 'providers/map_view_provider.dart';
  import 'providers/theme_mode_provider.dart';
  import 'repositories/auth_repository.dart';
  import 'repositories/dashboard_repository.dart';
  import 'repositories/alerts_repository.dart';
  import 'repositories/tracking_repository.dart';
  import 'repositories/accounts_repository.dart';
  import 'repositories/fleet_intelligence_repository.dart';
  import 'repositories/reports_repository.dart';
  import 'services/auth_service.dart';
  import 'services/api_client.dart';
  import 'services/dashboard_service.dart';
  import 'services/alerts_service.dart';
  import 'services/tracking_service.dart';
  import 'services/accounts_service.dart';
  import 'services/fleet_intelligence_service.dart';
  import 'services/reports_service.dart';
  import 'routes/app_router.dart';
  import 'theme/app_theme.dart';

  void main() {
    runApp(const EyeotyApp());
  }

  class EyeotyApp extends StatefulWidget {
    const EyeotyApp({super.key});

    @override
    State<EyeotyApp> createState() => _EyeotyAppState();
  }

  class _EyeotyAppState extends State<EyeotyApp> {
    late final AuthProvider _authProvider;
    late final DashboardProvider _dashboardProvider;
    late final AlertsProvider _alertsProvider;
    late final TrackingProvider _trackingProvider;
    late final AccountsProvider _accountsProvider;
    late final FleetIntelligenceProvider _fleetIntelligenceProvider;
    late final MapViewProvider _mapViewProvider;
    late final ThemeModeProvider _themeModeProvider;
    late final AlertsRepository _alertsRepository;
    late final ReportsRepository _reportsRepository;
    late final AccountsRepository _accountsRepository;
    late final GoRouter _router;

    @override
    void initState() {
      super.initState();

      final authService = AuthService();
      final apiClient = ApiClient(authService);
      final dashboardRepository = DashboardRepository(DashboardService(apiClient));

      _alertsRepository = AlertsRepository(AlertsService(apiClient));
      _reportsRepository = ReportsRepository(ReportsService(apiClient));
      _accountsRepository = AccountsRepository(AccountsService(apiClient));

      _authProvider = AuthProvider(AuthRepository(authService))..bootstrap();
      _dashboardProvider = DashboardProvider(dashboardRepository);
      _alertsProvider = AlertsProvider(_alertsRepository);
      _trackingProvider = TrackingProvider(TrackingRepository(TrackingService(apiClient)));
      _accountsProvider = AccountsProvider(_accountsRepository);
      _fleetIntelligenceProvider = FleetIntelligenceProvider(FleetIntelligenceRepository(FleetIntelligenceService(apiClient)));
      // Reuses the same DashboardRepository instance as _dashboardProvider —
      // same underlying endpoint (getMapViewData), just a separate provider
      // for Map View's own 3-minute auto-refresh lifecycle.
      _mapViewProvider = MapViewProvider(dashboardRepository);
      _themeModeProvider = ThemeModeProvider();

      // Built ONCE — GoRouter's own `refreshListenable` (see
      // routes/app_router.dart) reacts to auth state changes and
      // re-evaluates redirects without the router itself being recreated.
      _router = buildRouter(_authProvider);
    }

    @override
    Widget build(BuildContext context) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: _authProvider),
          ChangeNotifierProvider.value(value: _dashboardProvider),
          ChangeNotifierProvider.value(value: _alertsProvider),
          ChangeNotifierProvider.value(value: _trackingProvider),
          ChangeNotifierProvider.value(value: _accountsProvider),
          ChangeNotifierProvider.value(value: _fleetIntelligenceProvider),
          ChangeNotifierProvider.value(value: _mapViewProvider),
          ChangeNotifierProvider.value(value: _themeModeProvider),
          // Plain (non-ChangeNotifier) providers — the report screens
          // that use these manage their own local State rather than a
          // shared app-wide store, since each report is a one-off
          // "load on search" flow, not reactive shared data.
          Provider<AlertsRepository>.value(value: _alertsRepository),
          Provider<ReportsRepository>.value(value: _reportsRepository),
          // Reuses the same AccountsRepository instance as _accountsProvider
          // - Working Hour Report's Account dropdown just needs the plain
          // repository call, not the ChangeNotifier wrapper.
          Provider<AccountsRepository>.value(value: _accountsRepository),
        ],
        child: Consumer<ThemeModeProvider>(
          builder: (context, themeModeProvider, _) {
            return MaterialApp.router(
              title: 'Eyeoty',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              themeMode: themeModeProvider.mode,
              routerConfig: _router,
            );
          },
        ),
      );
    }
  }