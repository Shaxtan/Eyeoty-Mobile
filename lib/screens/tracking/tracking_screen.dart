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

/// Redesigned again from the previous split-screen (map on top, fixed
/// vehicle list below) into a full-screen map with the fleet list moved
/// into a toggleable overlay sidebar, and per-vehicle details now shown
/// as a compact card overlaid directly on the map instead of opening
/// VehicleDetailSheet as a separate bottom sheet. Marker clustering,
/// status coloring, and the underlying DeviceItem-based fleet list (see
/// tracking_provider.dart's header comment for why that model switch
/// matters) are unchanged from the prior redesign.
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
  bool _sidebarOpen = false;

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
    // Selecting a vehicle (marker or list row) closes the sidebar so the
    // map + info card are fully visible, matching a standard
    // nav-drawer-closes-on-selection pattern.
    setState(() => _sidebarOpen = false);
  }

  String _fmtLastUpdate(String? raw) {
    if (raw == null) return '\u2014';
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
    final selected = tracking.selected;

    return Stack(
      children: [
        // Full-screen map
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
                  final isSelected = selected?.imei == d.imei;
                  final size = isSelected ? 40.0 : 30.0;
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

        // Legend (bottom-right, so it never collides with the left sidebar)
        Positioned(
          right: 10,
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

        // Vehicle info card, overlaid on the map, only while a vehicle is selected
        if (selected != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: _VehicleInfoCard(
              vehicle: selected,
              fmtLastUpdate: _fmtLastUpdate,
              onClose: () => context.read<TrackingProvider>().clearSelection(),
            ),
          ),

        // Sidebar toggle button
        Positioned(
          left: 12,
          top: 12,
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            elevation: 3,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _sidebarOpen = !_sidebarOpen),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(_sidebarOpen ? Icons.close_rounded : Icons.menu_rounded, size: 20),
              ),
            ),
          ),
        ),

        // Backdrop - tap outside the sidebar to close it
        if (_sidebarOpen)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _sidebarOpen = false),
              child: Container(color: Colors.black.withValues(alpha: 0.25)),
            ),
          ),

        // Sidebar panel (slides in from the left)
        AnimatedPositioned(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          left: _sidebarOpen ? 0 : -300,
          top: 0,
          bottom: 0,
          width: 290,
          child: Material(
            elevation: 8,
            child: _sidebarPanel(tracking),
          ),
        ),
      ],
    );
  }

  Widget _sidebarPanel(TrackingProvider tracking) {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
            child: Row(
              children: [
                Text('Live Fleet', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.grey.shade800)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(999)),
                  child: Text('${tracking.vehicles.length}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => _sidebarOpen = false),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          Expanded(
            child: tracking.vehicles.isEmpty
                ? const EmptyView(message: 'No live vehicles found.', icon: Icons.local_shipping_outlined)
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: tracking.vehicles.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) => _vehicleRow(tracking.vehicles[i], tracking),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _vehicleRow(DeviceItem v, TrackingProvider tracking) {
    final s = mapViewStatusOf(v);
    final color = kMapViewStatusColor[s]!;
    final isSelected = tracking.selected?.imei == v.imei;
    final lastUpdate = v.lastUpdate;

    return Material(
      color: isSelected ? color.withValues(alpha: 0.06) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _onTapVehicle(v),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: isSelected ? color.withValues(alpha: 0.4) : Colors.grey.shade200),
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
  }
}

/// Compact vehicle detail card overlaid on the map (replaces the
/// previous VehicleDetailSheet bottom-sheet for this screen specifically
/// - per the redesign request, details now live on the map itself).
class _VehicleInfoCard extends StatelessWidget {
  final DeviceItem vehicle;
  final VoidCallback onClose;
  final String Function(String?) fmtLastUpdate;

  const _VehicleInfoCard({required this.vehicle, required this.onClose, required this.fmtLastUpdate});

  @override
  Widget build(BuildContext context) {
    final s = mapViewStatusOf(vehicle);
    final color = kMapViewStatusColor[s]!;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Icon(Icons.local_shipping_rounded, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(vehicle.displayName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
                      child: Text(mapViewStatusLabel(s), style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
              IconButton(icon: const Icon(Icons.close, size: 18), onPressed: onClose, visualDensity: VisualDensity.compact),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              _stat(Icons.speed_rounded, '${vehicle.speed} km/h', 'Speed'),
              const SizedBox(width: 12),
              _stat(Icons.access_time_rounded, fmtLastUpdate(vehicle.lastUpdate), 'Updated'),
              if (vehicle.lat != null && vehicle.lng != null) ...[
                const SizedBox(width: 12),
                _stat(Icons.place_outlined, '${vehicle.lat!.toStringAsFixed(3)}, ${vehicle.lng!.toStringAsFixed(3)}', 'Location'),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, String value, String label) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: Colors.grey.shade400),
              const SizedBox(width: 3),
              Flexible(child: Text(value, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 1),
          Text(label, style: TextStyle(fontSize: 9, color: Colors.grey.shade400)),
        ],
      ),
    );
  }
}