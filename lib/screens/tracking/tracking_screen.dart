import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../core/utils/load_status.dart';
import '../../models/vehicle_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tracking_provider.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/error_view.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/status_badge.dart';

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

  void _maybeSelectInitial(List<LiveVehicle> vehicles) {
    if (_initialSelectHandled || widget.initialImei == null || vehicles.isEmpty) return;
    _initialSelectHandled = true;
    final match = vehicles.where((v) => v.id == widget.initialImei);
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
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: center, initialZoom: 6),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.eyeoty.mobile',
              ),
              MarkerLayer(
                markers: withLocation
                    .map(
                      (v) => Marker(
                        point: LatLng(v.lat!, v.lng!),
                        width: 34,
                        height: 34,
                        child: GestureDetector(
                          onTap: () {
                            context.read<TrackingProvider>().select(v);
                            _mapController.move(LatLng(v.lat!, v.lng!), 14);
                          },
                          child: const Icon(Icons.local_shipping, color: Colors.blue, size: 30),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: tracking.vehicles.isEmpty
              ? const EmptyView(message: 'No live vehicles found.', icon: Icons.local_shipping_outlined)
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: tracking.vehicles.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final v = tracking.vehicles[i];
                    final selected = tracking.selected?.id == v.id;
                    return ListTile(
                      selected: selected,
                      title: Text(v.displayName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      subtitle: Text('${v.speed} km/h', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                      trailing: StatusBadge(status: v.status),
                      onTap: () {
                        context.read<TrackingProvider>().select(v);
                        if (v.lat != null && v.lng != null) {
                          _mapController.move(LatLng(v.lat!, v.lng!), 14);
                        }
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}
