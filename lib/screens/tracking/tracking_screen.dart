import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../core/utils/load_status.dart';
import '../../core/map_view/map_view_status.dart';
import '../../models/device_item.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tracking_provider.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/error_view.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/vehicle_detail_sheet.dart';

/// Redesigned from a flat, un-clustered blue-truck-icon map (which
/// visually collapsed into a solid blob once a fleet had more than a
/// few dozen vehicles close together) into the same clustered,
/// status-colored marker style Map View already uses - genuinely
/// shared via mapViewStatusOf()/kMapViewStatusColor, not just visually
/// similar. Tapping a vehicle (marker or list row) now opens the same
/// rich VehicleDetailSheet Map View uses, instead of just re-centering
/// the camera - this only became possible because the fleet list is
/// now DeviceItem (see tracking_provider.dart's header comment for why
/// that switch also fixes every status badge previously showing
/// "No Data" regardless of actual vehicle speed.
class TrackingScreen extends StatefulWidget {
  /// Optional deep-linked vehicle, e.g. from a "Track" button elsewhere
  /// in the app (`context.go('/tracking?imei=...')`) — auto-selected and
  /// centred once the fleet list has loaded.
  final String? initialImei;

  const TrackingScreen({super.key, this.initialImei});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final _mapController = MapController();
  bool _initialSelectHandled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final accountId = context.read<AuthProvider>().user?.accountId ?? '1';
      context.read<TrackingProvider>().load(accountId);
    });
  }

  void _maybeSelectInitial(List<DeviceItem> vehicles) {
    if (_initialSelectHandled || widget.initialImei == null || vehicles.isEmpty) return;
    _initialSelectHandled = true;
    final match = vehicles.where((v) => v.imei == widget.initialImei);
    if (match.isNotEmpty) {
      final v = match.first;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<TrackingProvider>().select(v);
        if (v.lat != null && v.lng != null) {
          _mapController.move(LatLng(v.lat!, v.lng!), 14);
        }
      });
    }
  }

  void _onTapVehicle(DeviceItem v) {
    context.read<TrackingProvider>().select(v);
    if (v.lat != null && v.lng != null) {
      _mapController.move(LatLng(v.lat!, v.lng!), 14);
    }
    VehicleDetailSheet.show(context, v);
  }

  String _fmtLastUpdate(String raw) {
    final d = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    if (d == null) return raw;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final tracking = context.watch<TrackingProvider>();

    if (tracking.status == LoadStatus.loading && tracking.vehicles.isEmpty) {
      return const LoadingView();
    }
    if (tracking.status == LoadStatus.error) {
      return ErrorView(
        message: tracking.errorMessage ?? 'Failed to load vehicles.',
        onRetry: () {
          final accountId = context.read<AuthProvider>().user?.accountId ?? '1';
          context.read<TrackingProvider>().load(accountId);
        },
      );
    }

    _maybeSelectInitial(tracking.vehicles);

    final withLocation = tracking.vehicles.where((v) => v.lat != null && v.lng != null).toList();
    final center = withLocation.isNotEmpty
        ? LatLng(withLocation.first.lat!, withLocation.first.lng!)
        : const LatLng(22.2587, 71.1924); // Gujarat fallback centre, matches TrackingPage.jsx's default

    return Column(
      children: [
        Expanded(
          flex: 3,
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(initialCenter: center, initialZoom: 6),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.eyeoty.mobile',
                  ),
                  MarkerClusterLayerWidget(
                    options: MarkerClusterLayerOptions(
                      maxClusterRadius: 60,
                      size: const Size(40, 40),
                      markers: withLocation.map((d) {
                        final s = mapViewStatusOf(d);
                        final color = kMapViewStatusColor[s]!;
                        final selected = tracking.selected?.imei == d.imei;
                        final size = selected ? 40.0 : 30.0;
                        return Marker(
                          point: LatLng(d.lat!, d.lng!),
                          width: size,
                          height: size,
                          child: GestureDetector(
                            onTap: () => _onTapVehicle(d),
                            child: Container(
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 4)],
                              ),
                              child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 15),
                            ),
                          ),
                        );
                      }).toList(),
                      builder: (context, markers) {
                        return Container(
                          decoration: const BoxDecoration(color: Color(0xFF2563EB), shape: BoxShape.circle),
                          alignment: Alignment.center,
                          child: Text(
                            '${markers.length}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              Positioned(
                left: 10,
                bottom: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 6)],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final s in [MapViewStatus.motion, MapViewStatus.idle, MapViewStatus.stop, MapViewStatus.lock])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(width: 8, height: 8, decoration: BoxDecoration(color: kMapViewStatusColor[s], shape: BoxShape.circle)),
                              const SizedBox(width: 3),
                              Text(mapViewStatusLabel(s), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.black87)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: Container(
            color: Colors.grey.shade50,
            child: tracking.vehicles.isEmpty
                ? const EmptyView(message: 'No live vehicles found.', icon: Icons.local_shipping_outlined)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Row(
                          children: [
                            Text('Live Fleet', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.grey.shade700)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(999)),
                              child: Text('${tracking.vehicles.length}',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          itemCount: tracking.vehicles.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final v = tracking.vehicles[i];
                            final s = mapViewStatusOf(v);
                            final color = kMapViewStatusColor[s]!;
                            final selected = tracking.selected?.imei == v.imei;
                            final lastUpdate = v.lastUpdate;

                            return Material(
                              color: selected ? color.withValues(alpha: 0.06) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => _onTapVehicle(v),
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: selected ? color.withValues(alpha: 0.4) : Colors.grey.shade200),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 42,
                                        height: 42,
                                        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                                        alignment: Alignment.center,
                                        child: Icon(Icons.local_shipping_rounded, color: color, size: 20),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(v.displayName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                                            const SizedBox(height: 3),
                                            Row(
                                              children: [
                                                Icon(Icons.speed_rounded, size: 13, color: Colors.grey.shade400),
                                                const SizedBox(width: 3),
                                                Text('${v.speed} km/h', style: TextStyle(color: Colors.grey.shade500, fontSize: 11.5)),
                                                if (lastUpdate != null) ...[
                                                  const SizedBox(width: 10),
                                                  Icon(Icons.access_time_rounded, size: 12, color: Colors.grey.shade400),
                                                  const SizedBox(width: 3),
                                                  Expanded(
                                                    child: Text(
                                                      _fmtLastUpdate(lastUpdate),
                                                      style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
                                        child: Text(
                                          mapViewStatusLabel(s),
                                          style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}