import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import '../../models/alert_model.dart';
import '../../core/alerts/alert_severity_meta.dart';

/// Ported from AlertLiveMap.jsx - component source not shared, built
/// from its props in AlertsPage.jsx (alerts, loading). Severity-colored,
/// clustered markers, matching the map style used elsewhere in this app.
class AlertLiveMapCard extends StatelessWidget {
  final List<FleetAlert> alerts;
  final bool loading;
  const AlertLiveMapCard({super.key, required this.alerts, required this.loading});

  @override
  Widget build(BuildContext context) {
    final located = alerts.where((a) => a.lat != null && a.lng != null).toList();
    if (located.isEmpty) {
      return Center(
        child: Text(
          loading ? 'Loading\u2026' : 'No located alerts in this period.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
        ),
      );
    }
    final center = LatLng(located.first.lat!, located.first.lng!);

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: FlutterMap(
        options: MapOptions(initialCenter: center, initialZoom: 5.5),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.eyeoty.mobile',
          ),
          MarkerClusterLayerWidget(
            options: MarkerClusterLayerOptions(
              maxClusterRadius: 50,
              size: const Size(32, 32),
              markers: located.map((a) {
                final color = severityColor(a.severity);
                return Marker(
                  point: LatLng(a.lat!, a.lng!),
                  width: 20,
                  height: 20,
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 3)],
                    ),
                  ),
                );
              }).toList(),
              builder: (context, markers) {
                return Container(
                  decoration: const BoxDecoration(color: Color(0xFF2563EB), shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text('${markers.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}