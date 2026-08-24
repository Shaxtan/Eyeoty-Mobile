# Feature parity — original web app vs. this Flutter conversion

Honest status as of generation. "Implemented" means real code exists and is
wired to a provider/screen — it does NOT mean it was tested against a live
backend (see README "What's real and what isn't").

| Page / Feature | Exists in Flutter? | API connected? | Loading/Error/Empty states? | Notes |
|---|---|---|---|---|
| Splash / session bootstrap | ✅ Implemented | — | — | Checks stored token via `flutter_secure_storage` |
| Login | ✅ Implemented | ⚠️ Endpoint path unconfirmed | ✅ | Form validation, remember-me checkbox (non-functional, matches original), error snackbar |
| Dashboard (KPI summary) | ✅ Implemented | ⚠️ Endpoint path unconfirmed | ✅ | 6 KPI cards: Total/Moving/Stopped/Idle/Offline/Unreachable, pull-to-refresh |
| Alerts (list + detail) | ✅ Implemented | ✅ Confirmed endpoint | ✅ | Severity badges, tap for detail bottom sheet, pull-to-refresh. Acknowledge/Resolve actions from the web app NOT ported (no confirmed triage endpoint) |
| Live Tracking / Map View | ✅ Implemented (combined into one screen) | ⚠️ Endpoint path unconfirmed | ✅ | flutter_map + OSM tiles (mirrors existing Leaflet/OSM usage), vehicle list synced to map selection |
| Settings | ✅ Implemented | N/A (local + auth only) | N/A | Real role gate (Super Admin / Administrator → admin section; others → basic), REAL working dark-mode toggle, logout |
| Fleet Intelligence | ❌ Not ported | — | — | Source not shared during conversion |
| Dedicated Map View (cluster/filter UI) | ❌ Not ported | — | — | Source not shared; basic map exists under Tracking |
| Vehicles (CRUD) | ❌ Not ported | — | — | Source not shared |
| Trips (CRUD) | ❌ Not ported | — | — | Source not shared |
| Geofence | ❌ Not ported | — | — | Source not shared |
| Reports — Distance Report | ❌ Not ported | — | — | Source not shared |
| Reports — Working Hour Report | ❌ Not ported | — | — | Source not shared |
| Reports — Stoppage Report | ❌ Not ported | — | — | Source not shared |
| Reports — Fuel Theft Report | ❌ Not ported | — | — | Source not shared |
| Reports — TrackPlay | ❌ Not ported | — | — | Source not shared |
| Analytics | ❌ Not ported | — | — | Source not shared |
| IoT Sensors | ❌ Not ported | — | — | Source not shared |
| Load Cell Report | ❌ Not ported | — | — | Source not shared |
| Live Load Graph | ❌ Not ported | — | — | Source not shared |
| Users / Devices / Maintenance / Drivers (seen referenced but not sourced) | ❌ Not ported | — | — | Source not shared |

## Cross-cutting

| Requirement | Status |
|---|---|
| Auth redirect guard (protected routes) | ✅ Implemented via go_router `redirect` + `refreshListenable` |
| No dead-end screens | ✅ Every original nav item routes somewhere — either a real screen or an honest `PendingScreen` |
| Responsive: phone vs. tablet vs. Chrome desktop | ✅ Implemented — 900px breakpoint switches BottomNav+Drawer vs. NavigationRail |
| Design language (colors) ported | ✅ `lib/theme/app_colors.dart` mirrors `tokens.js` hex values exactly |
| Design language (logo/images/fonts) ported | ❌ No binary assets were shared during conversion |
| `flutter analyze` run and passing | ❌ Could not run — no Flutter SDK in the generation environment |
| `flutter run -d chrome` verified | ❌ Could not run — no Flutter SDK, and pub.dev/storage.googleapis.com are network-blocked in the generation environment |
| `flutter build apk` verified | ❌ Could not run, same reason |
| Real APIs, not mocks | ✅ Every implemented screen calls real HTTP endpoints — nothing returns hardcoded fake data. Some endpoint *paths* are marked unconfirmed (see README) but the request/response handling is real |
