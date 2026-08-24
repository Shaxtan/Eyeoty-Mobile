# Eyeoty Mobile

A Flutter (Android / iOS / Web) companion app for the Eyeoty fleet IoT
platform, converted from an existing React/Vite web application.

## Read this first — what's real and what isn't

This project was generated in a sandboxed environment with **no Flutter/Dart
SDK installed and no network access to pub.dev** (both were checked directly,
not assumed — `flutter` is not on PATH, and `pub.dev` / `storage.googleapis.com`
returned `403 host_not_allowed`). That means:

- `flutter pub get`, `flutter analyze`, `flutter run -d chrome`, `flutter test`,
  and `flutter build apk` were **never actually executed**. The code below was
  written carefully against known-stable Flutter/Dart/package APIs, but it has
  **not been compiled or run**. Run the commands in "Getting started" yourself
  and fix anything that surfaces — treat this as a strong first draft, not a
  verified build.
- The `android/`, `ios/`, and `web/` platform folders are **intentionally not
  included**. Hand-writing native Gradle/Xcode/web-manifest files without a
  toolchain to validate them is more likely to produce silently-broken
  platform config than no config at all. Generate them correctly with one
  real command — see step 1 below.
- This conversation contained real, confirmed source for a subset of the
  original web app (Dashboard, Alerts, Live Tracking, Map View, Settings'
  role-gating, the design token colors, and a few confirmed API endpoints).
  It did **not** contain the complete original project. Screens the source
  for which was never shared are included in navigation (no dead ends) but
  render an honest "not yet ported" screen instead of a fake implementation.
  See **FEATURE_PARITY.md** for the exact list.

## Getting started

```bash
# 1. Generate the native platform folders (this project ships without them —
#    flutter create does this correctly using YOUR installed SDK version).
flutter create --platforms=android,ios,web --org com.eyeoty .

# 2. Install dependencies
flutter pub get

# 3. Static analysis
flutter analyze

# 4. Run on Chrome (primary target per project requirements)
flutter run -d chrome

# 5. Run tests
flutter test

# 6. Build a release APK
flutter build apk --release
```

If `flutter pub get` reports version conflicts, the caret ranges in
`pubspec.yaml` (`provider`, `go_router`, `http`, `flutter_secure_storage`,
`flutter_map`, `latlong2`) were chosen from known-stable major versions but
**were not checked against the live pub.dev registry** — bump/adjust as
`pub get` suggests.

## Configuring the API

The backend base URL defaults to `https://tech-hop.com/api` (the confirmed
base URL from the existing web app). Override at build/run time:

```bash
flutter run -d chrome --dart-define=API_BASE_URL=https://your-api.example.com/api
```

See `lib/config/env.dart`.

## ⚠️ Endpoints that need verification

Three endpoints are marked `UNCONFIRMED` in the service layer because their
exact REST paths were referenced only by JS function name in the source
shared during conversion (e.g. `apiService.getMapViewData(accid)`), not by
their underlying URL:

| Service | File | What's unconfirmed |
|---|---|---|
| Login | `lib/services/auth_service.dart` | `_loginPath = '/users/login'` — guessed from the service map, not confirmed |
| Dashboard summary | `lib/services/dashboard_service.dart` | `_path = '/usage/dashboard'` — guessed |
| Map view data | `lib/services/tracking_service.dart` | `_mapViewPath` — guessed |
| Live track | `lib/services/tracking_service.dart` | `_liveTrackPath` — guessed |

**Confirmed and used as-is** (verified earlier in this project's history):
`POST /usage/alerts/by-account` with `{ accid, startTime, endTime, pageSize }`,
Bearer token auth header, base URL `https://tech-hop.com/api`.

Paste the real `auth.service.js`, `dashboard.service.js`, and the internals
of `apiService.js` to correct the four paths above.

## Screens not yet ported

Reachable from the Drawer / "More" rail (so there are no dead-end taps), each
renders `PendingScreen` (`lib/widgets/pending_screen.dart`) stating plainly
that its source wasn't available: **Fleet Intelligence, Map View (dedicated
cluster view), Trips, Geofence, Reports (Distance/Working Hour/Stoppage/Fuel
Theft/TrackPlay), Analytics, IoT Sensors, Load Cell Report, Live Load
Graph.** Provide the matching React component + its API service for any of
these and it can be built out for real, the same way Dashboard/Alerts/
Tracking/Settings/**Vehicles** were.

**Vehicles** is now real (`lib/screens/vehicles/fleet_devices_screen.dart`) —
ported from `FleetTableCard.jsx`.

## Dashboard — full port (this pass)

Every widget on `DashboardPage.jsx` that's actually imported by that page is
now implemented for real: KPI grid, `LiveMapCard` (mini map), `RecentAlertsCard`
(+ `AlertTypeListSheet`, mobile equivalent of `AlertsModal.jsx`),
`FleetUtilizationCard` (real 7-day derived trend line, using `fl_chart`),
`TopDistanceCard`, and `FleetDevicesSummaryCard` linking to the full
`FleetDevicesScreen`. `VehicleDrawer.jsx` is ported as `VehicleDetailSheet` —
a bottom sheet with live-telemetry polling, a mini map with route trail, and
per-vehicle recent alerts. The hover-based `AccountPopup` is ported as
`AccountStatusDialog` — a tap dialog (mobile has no hover state).

**Explicitly NOT ported, on purpose (not silently dropped):**
- **CSV/Excel/PDF export** from `FleetTableCard.jsx` — a genuinely separate,
  substantial feature (cross-platform file generation + share/download).
  Flagged here as a dedicated follow-up rather than faked with a button
  that does nothing.
- **`AlertsPieCard.jsx`** and **`FleetLiveStrip.jsx`** — neither is actually
  imported by `DashboardPage.jsx` in the source provided, so neither was
  built. If either belongs on a different page, say so and it'll be built
  there instead.
- Desktop-table pagination (20/page) was replaced with a natural scrollable
  list + search + status filter chips on `FleetDevicesScreen` — a deliberate
  mobile-appropriate simplification, not a missing feature.

## Architecture

```
lib/
  core/utils/      Shared enums/helpers (LoadStatus)
  config/          Runtime config (API base URL, storage keys)
  theme/           Colors ported from the web app's tokens.js, ThemeData
  models/          Plain Dart data classes + fromJson()
  services/        Raw HTTP calls (ApiClient, AuthService, ...)
  repositories/    Thin pass-through layer over services
  providers/       ChangeNotifier state (provider package) per feature
  routes/          go_router config incl. auth redirect guard + ShellRoute
  screens/         One folder per feature; screens return body content
                    only — the single Scaffold/AppBar/Drawer lives in
                    widgets/app_nav_shell.dart
  widgets/         Reusable UI (KpiCard, badges, loading/error/empty states,
                    the responsive nav shell, PendingScreen)
```

State management is `provider` (ChangeNotifier) — no code generation, matches
"don't introduce unnecessary complexity." Routing is `go_router`, which
supports web deep-linking and an auth redirect guard out of the box.

## Responsive behaviour (mobile vs. Chrome)

`lib/widgets/app_nav_shell.dart` switches layout at a 900px width breakpoint:
narrow widths get a `BottomNavigationBar` + `Drawer`; wide widths (tablet /
Chrome desktop) get a `NavigationRail` + a persistent "More" list beside the
content — the same information architecture as the original web sidebar,
without stretching the phone UI across a desktop browser window.

## Authentication flow

Token is stored via `flutter_secure_storage` (Android Keystore / iOS
Keychain / WebCrypto-backed on web) under the key `auspre-token` — named to
match the original web app's localStorage key for cross-reference, though
the two apps do not share storage. `AuthProvider` exposes
`unknown / authenticated / unauthenticated` status; `go_router`'s
`refreshListenable` re-evaluates the redirect guard automatically whenever
that status changes, so login/logout navigation "just works" without manual
`Navigator` calls scattered through the app.

## Known limitations

- Login endpoint path is unconfirmed (see table above) — login will not
  succeed until it's corrected.
- Alert severity classification (`lib/models/alert_model.dart` →
  `FleetAlert.severity`) is a simplified guess at the original
  `utils/alertSeverity.js` logic, which wasn't shared. Replace with the real
  rules.
- No offline caching / local persistence of fetched data beyond the session
  token.
- No push notifications (not confirmed whether the original web app has
  server-driven notifications to mirror).
- `assets/` is empty — the original app's logo/icons weren't provided as
  binary files during this conversion; copy them in and uncomment the
  `flutter: assets:` block in `pubspec.yaml`.

## For continued development

This project spans many files across many concerns (auth, networking, 10+
screens, native platform config) — exactly the kind of multi-session,
iterative build that benefits from a real local Flutter toolchain a coding
agent can actually run and re-run (`flutter analyze`, `flutter run -d chrome`,
etc.) rather than one written blind. Claude Code, run locally where Flutter
is installed, can pick this project up, execute the verification steps this
environment couldn't, and keep building out the pending screens against your
real API — worth considering for the next phase of this.
