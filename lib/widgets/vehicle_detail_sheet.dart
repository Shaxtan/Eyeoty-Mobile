import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import '../core/alerts/alert_type_meta.dart';
import '../models/device_item.dart';
import '../providers/tracking_provider.dart';
import '../providers/dashboard_provider.dart';

/// Mobile equivalent of VehicleDrawer.jsx — a bottom sheet instead of a
/// slide-in side drawer (same information, mobile-appropriate container).
/// Polls getLiveTrack every 30s like the original, shows a mini map with
/// an accumulating route trail, and lists this vehicle's recent alerts
/// (filtered from the SAME db-alerts data already loaded on the
/// dashboard — no separate fetch, mirroring VehicleDrawer's own
/// filter-in-place approach for alerts... except VehicleDrawer actually
/// does its own dedicated db-alerts fetch scoped by account; this sheet
/// reuses DashboardProvider's already-loaded dbAlerts instead, since
/// re-fetching the same account-wide feed again on every tap would be
/// wasteful — same data, same filter logic, fewer network calls).
class VehicleDetailSheet extends StatefulWidget {
  final DeviceItem vehicle;
  const VehicleDetailSheet({super.key, required this.vehicle});

  static Future<void> show(BuildContext context, DeviceItem vehicle) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VehicleDetailSheet(vehicle: vehicle),
    );
  }

  @override
  State<VehicleDetailSheet> createState() => _VehicleDetailSheetState();
}

class _VehicleDetailSheetState extends State<VehicleDetailSheet> {
  Map<String, dynamic>? _live;
  bool _liveLoading = true;
  Timer? _timer;
  final List<LatLng> _route = [];

  @override
  void initState() {
    super.initState();
    if (widget.vehicle.lat != null && widget.vehicle.lng != null) {
      _route.add(LatLng(widget.vehicle.lat!, widget.vehicle.lng!));
    }
    _fetchLive();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _fetchLive());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchLive() async {
    // fetchLiveTrackFor() is a one-off single-vehicle lookup added to
    // TrackingProvider specifically for this sheet's 30s polling —
    // distinct from TrackingProvider.load(), which fetches the whole
    // fleet's map-view snapshot.
    final tracking = context.read<TrackingProvider>();
    try {
      final accountId = widget.vehicle.accountId ?? '1';
      final data = await tracking.fetchLiveTrackFor(accountId: accountId, imei: widget.vehicle.imei);
      if (!mounted) return;
      setState(() {
        _live = data;
        _liveLoading = false;
        final lat = double.tryParse('${data?['lat'] ?? data?['latitude'] ?? ''}');
        final lng = double.tryParse('${data?['lng'] ?? data?['longitude'] ?? ''}');
        if (lat != null && lng != null && lat != 0 && lng != 0) {
          _route.add(LatLng(lat, lng));
          if (_route.length > 20) _route.removeAt(0);
        }
      });
    } catch (_) {
      if (mounted) setState(() => _liveLoading = false);
    }
  }

  Widget _stat(IconData icon, String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
        const SizedBox(height: 1),
        Text(label, style: TextStyle(fontSize: 9, color: Colors.grey.shade500)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.vehicle;
    final d = _live ?? {};

    final speed = d['speed'] ?? v.speed;
    final ign = (d['ign'] ?? v.ignition ?? 'N').toString().toUpperCase();
    final gps = (d['gps'] ?? v.gps ?? '').toString().toUpperCase();
    final bearing = d['disha'];
    final misc = d['misc'] as Map<String, dynamic>?;
    final battery = misc?['batteryPercentage'] ?? d['batAmp'] ?? d['battery'];
    final odometer = misc?['odometer'];
    final address = d['address'] ?? v.address ?? '\u2014';
    final updated = d['devTs'] ?? d['cts'] ?? v.lastUpdate ?? '\u2014';

    final dashboard = context.watch<DashboardProvider>();
    final relatedAlerts = (dashboard.dbAlerts?.alerts ?? [])
        .where((a) => a.imei == v.imei)
        .toList()
      ..sort((a, b) => (b.createdOn ?? '').compareTo(a.createdOn ?? ''));
    final top5Alerts = relatedAlerts.take(5).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E293B),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(v.displayName,
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text(v.imei,
                              style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace')),
                          if (v.accountName != null)
                            Text(v.accountName!, style: const TextStyle(color: Colors.white54, fontSize: 10)),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        context.go('/tracking?imei=${v.imei}');
                      },
                      icon: const Icon(Icons.open_in_new, size: 13, color: Colors.white),
                      label: const Text('Track', style: TextStyle(color: Colors.white, fontSize: 11)),
                      style: TextButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.1)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.zero,
                  children: [
                    // Live telemetry strip
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: _liveLoading
                          ? const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
                          : Row(
                              children: [
                                Expanded(child: _stat(Icons.speed, 'Speed', '$speed km/h', Colors.blue)),
                                Expanded(
                                  child: _stat(Icons.bolt, 'Ignition', ign == 'Y' ? 'ON' : 'OFF',
                                      ign == 'Y' ? Colors.green : Colors.redAccent),
                                ),
                                Expanded(
                                  child: _stat(Icons.gps_fixed, 'GPS', gps == 'A' ? 'Active' : 'No fix',
                                      gps == 'A' ? Colors.green : Colors.grey),
                                ),
                                Expanded(
                                  child: _stat(Icons.battery_std, 'Battery', battery != null ? '$battery V' : '\u2014',
                                      Colors.amber.shade700),
                                ),
                                Expanded(
                                  child: _stat(Icons.rotate_left, 'Odometer',
                                      odometer != null ? '$odometer km' : '\u2014', Colors.purple),
                                ),
                                Expanded(
                                  child: _stat(Icons.navigation, 'Bearing', bearing != null ? '$bearing\u00b0' : '\u2014',
                                      Colors.grey),
                                ),
                              ],
                            ),
                    ),
                    // Address strip
                    Container(
                      color: const Color(0xFFF8FAFC),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 12, color: Colors.grey),
                          const SizedBox(width: 6),
                          Expanded(child: Text(address, style: const TextStyle(fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis)),
                          Text('$updated', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                        ],
                      ),
                    ),
                    // Mini map
                    SizedBox(
                      height: 200,
                      child: _route.isEmpty
                          ? Container(
                              color: Colors.grey.shade100,
                              alignment: Alignment.center,
                              child: const Text('No location data', style: TextStyle(color: Colors.grey)),
                            )
                          : Stack(
                              children: [
                                FlutterMap(
                                  options: MapOptions(initialCenter: _route.last, initialZoom: 14),
                                  children: [
                                    TileLayer(
                                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                      userAgentPackageName: 'com.eyeoty.mobile',
                                    ),
                                    if (_route.length > 1)
                                      PolylineLayer(polylines: [
                                        Polyline(points: _route, color: Colors.blue, strokeWidth: 3),
                                      ]),
                                    MarkerLayer(markers: [
                                      Marker(
                                        point: _route.last,
                                        width: 32,
                                        height: 32,
                                        child: const Icon(Icons.local_shipping, color: Colors.blue, size: 28),
                                      ),
                                    ]),
                                  ],
                                ),
                                Positioned(
                                  right: 8,
                                  bottom: 8,
                                  child: ElevatedButton.icon(
                                    onPressed: () => launchUrl(
                                      Uri.parse('https://www.google.com/maps?q=${_route.last.latitude},${_route.last.longitude}'),
                                      mode: LaunchMode.externalApplication,
                                    ),
                                    icon: const Icon(Icons.open_in_new, size: 12),
                                    label: const Text('Google Maps', style: TextStyle(fontSize: 10)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.black87,
                                      elevation: 2,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                    // Recent alerts for this vehicle
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('RECENT ALERTS',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey.shade500, letterSpacing: 0.5)),
                          const SizedBox(height: 8),
                          if (top5Alerts.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: Center(
                                child: Text('No recent alerts for this vehicle.',
                                    style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                              ),
                            )
                          else
                            ...top5Alerts.map((a) {
                              final meta = alertTypeMetaFor(a.type);
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade200),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 26,
                                      height: 26,
                                      decoration: BoxDecoration(color: meta.color.withValues(alpha: 0.12), shape: BoxShape.circle),
                                      child: Icon(meta.icon, size: 13, color: meta.color),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(meta.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: meta.color)),
                                          const SizedBox(height: 2),
                                          Text(a.createdOn ?? '', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                                          if (a.address != null)
                                            Text(a.address!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
