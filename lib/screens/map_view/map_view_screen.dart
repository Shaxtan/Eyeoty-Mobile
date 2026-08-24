import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../core/utils/load_status.dart';
import '../../core/map_view/map_view_status.dart';
import '../../models/device_item.dart';
import '../../providers/map_view_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/error_view.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/vehicle_detail_sheet.dart';

const _indiaCenter = LatLng(22.5589, 75.6089);
const _refreshInterval =
    Duration(minutes: 3); // matches MapPage.jsx's REFRESH_MS

/// Ported from MapPage.jsx. Mobile adaptation: the desktop's floating
/// sidebar-over-map is replaced with a stacked map-on-top /
/// list-below split (same pattern already proven in TrackingScreen),
/// since a floating panel over a full-bleed map is cramped on a phone
/// width. Marker-tap and list-tap both open VehicleDetailSheet (already
/// built, with live telemetry/mini-map/alerts) instead of Leaflet's
/// small popup bubble - richer and consistent with the rest of the app.
/// Map-style switching is NOT ported (utils/mapTiles.js source wasn't
/// shared) - single OSM tile layer, same as every other map screen here.
class MapViewScreen extends StatefulWidget {
  const MapViewScreen({super.key});

  @override
  State<MapViewScreen> createState() => _MapViewScreenState();
}

class _MapViewScreenState extends State<MapViewScreen> {
  final _mapController = MapController();
  final _searchCtrl = TextEditingController();
  Timer? _timer;

  MapViewStatus? _filter; // null = "All"
  String _search = '';
  String? _highlightedImei;

  void _load() {
    final accountId = context.read<AuthProvider>().user?.accountId ?? '1';
    context.read<MapViewProvider>().load(accountId);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    _timer = Timer.periodic(_refreshInterval, (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Filter + sort, matching MapPage.jsx's Sidebar useMemo exactly:
  /// status filter, then search substring match, then sort with
  /// exact-match-first, then startsWith-first priority.
  List<DeviceItem> _filteredSorted(List<DeviceItem> all) {
    final term = _search.toLowerCase().trim();
    final list = all.where((d) {
      final matchesFilter = _filter == null || mapViewStatusOf(d) == _filter;
      final matchesSearch =
          term.isEmpty || d.displayName.toLowerCase().contains(term);
      return matchesFilter && matchesSearch;
    }).toList();

    list.sort((a, b) {
      final at = a.displayName.toLowerCase();
      final bt = b.displayName.toLowerCase();
      if (at == term && bt != term) return -1;
      if (bt == term && at != term) return 1;
      if (at.startsWith(term) && !bt.startsWith(term)) return -1;
      if (bt.startsWith(term) && !at.startsWith(term)) return 1;
      return 0;
    });
    return list;
  }

  void _onVehicleTap(DeviceItem d) {
    setState(() => _highlightedImei = d.imei);
    if (d.lat != null && d.lng != null) {
      _mapController.move(LatLng(d.lat!, d.lng!), 15);
    }
    VehicleDetailSheet.show(context, d);
  }

  @override
  Widget build(BuildContext context) {
    final mv = context.watch<MapViewProvider>();
    final all = mv.vehicles;
    final filtered = _filteredSorted(all);

    final counts = <String, int>{'All': all.length};
    for (final s in [
      MapViewStatus.motion,
      MapViewStatus.idle,
      MapViewStatus.stop,
      MapViewStatus.lock
    ]) {
      counts[mapViewStatusLabel(s)] =
          all.where((d) => mapViewStatusOf(d) == s).length;
    }

    final withLocation =
        all.where((d) => d.lat != null && d.lng != null).toList();
    final center = withLocation.isNotEmpty
        ? LatLng(withLocation.first.lat!, withLocation.first.lng!)
        : _indiaCenter;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _search = v),
            decoration: const InputDecoration(
              hintText: 'Search vehicle\u2026',
              prefixIcon: Icon(Icons.search, size: 18),
              isDense: true,
            ),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: kMapViewFilters.map((f) {
              final active = _filter == f;
              final label = mapViewFilterLabel(f);
              final count = counts[label] ?? 0;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text('$label ($count)'),
                  selected: active,
                  onSelected: (_) => setState(() => _filter = f),
                  labelStyle: const TextStyle(fontSize: 11),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 6),
        if (mv.status == LoadStatus.error && all.isEmpty)
          Expanded(
              child: ErrorView(
                  message: mv.errorMessage ?? 'Failed to load map data.',
                  onRetry: _load))
        else if (mv.status == LoadStatus.loading && all.isEmpty)
          const Expanded(child: LoadingView())
        else ...[
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(initialCenter: center, initialZoom: 5.5),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.eyeoty.mobile',
                    ),
                    MarkerClusterLayerWidget(
                      options: MarkerClusterLayerOptions(
                        maxClusterRadius:
                            60, // matches MapPage.jsx's L.markerClusterGroup config
                        size: const Size(40, 40),
                        markers: withLocation.map((d) {
                          final s = mapViewStatusOf(d);
                          final color = kMapViewStatusColor[s]!;
                          final isHighlighted = d.imei == _highlightedImei;
                          final size = isHighlighted ? 40.0 : 28.0;
                          return Marker(
                            point: LatLng(d.lat!, d.lng!),
                            width: size,
                            height: size,
                            child: GestureDetector(
                              onTap: () => _onVehicleTap(d),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: Colors.white, width: 3),
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.35),
                                        blurRadius: 4),
                                  ],
                                ),
                                child: const Icon(Icons.local_shipping,
                                    color: Colors.white, size: 14),
                              ),
                            ),
                          );
                        }).toList(),
                        builder: (context, markers) {
                          return Container(
                            decoration: const BoxDecoration(
                                color: Color(0xFF2563EB),
                                shape: BoxShape.circle),
                            alignment: Alignment.center,
                            child: Text(
                              '${markers.length}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                // Matches MapPage.jsx's own loading overlay, which shows
                // on EVERY refresh (including the periodic auto-refresh),
                // not just the first load.
                if (mv.status == LoadStatus.loading)
                  Container(
                    color: Colors.white.withValues(alpha: 0.6),
                    alignment: Alignment.center,
                    child: const Text(
                      'Loading vehicles\u2026',
                      style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.w600,
                          fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: filtered.isEmpty
                ? const EmptyView(
                    message: 'No vehicles found.',
                    icon: Icons.local_shipping_outlined)
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final d = filtered[i];
                      final s = mapViewStatusOf(d);
                      final color = kMapViewStatusColor[s]!;
                      final isTop = _search.isNotEmpty && i == 0;
                      final isActive = d.imei == _highlightedImei;
                      return Container(
                        color: isActive
                            ? Colors.blue.withValues(alpha: 0.05)
                            : (isTop
                                ? Colors.amber.withValues(alpha: 0.05)
                                : null),
                        child: ListTile(
                          onTap: () => _onVehicleTap(d),
                          title: Text(d.displayName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 13)),
                          subtitle: Text(d.lastUpdate ?? '\u2014',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade500)),
                          trailing: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.grey.shade200),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 2)
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                    color: color, shape: BoxShape.circle)),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ],
    );
  }
}
