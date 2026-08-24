import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/device_item.dart';
import '../../theme/app_colors.dart';

const _statusColor = {
  'motion': AppColors.statusMoving,
  'idle': AppColors.statusIdle,
  'stopped': AppColors.statusStopped,
  'offline': AppColors.statusOffline,
};

/// Compact mini-map matching DashboardLiveMap.jsx: colour-coded dots,
/// a pulsing "Live" badge, and a "View Full Map" link. Tapping the link
/// pushes the full Live Tracking screen (the closest equivalent screen
/// this app has to the web app's dedicated /map page).
class LiveMapCard extends StatelessWidget {
  final List<DeviceItem> devices;
  final bool loading;
  final VoidCallback onViewFullMap;

  const LiveMapCard({
    super.key,
    required this.devices,
    required this.loading,
    required this.onViewFullMap,
  });

  @override
  Widget build(BuildContext context) {
    final withLocation = devices.where((d) => d.lat != null && d.lng != null).toList();
    final center = withLocation.isNotEmpty
        ? LatLng(withLocation.first.lat!, withLocation.first.lng!)
        : const LatLng(22.5, 78.9);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                const Text('Live Map', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(999)),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 6, color: Colors.white),
                      SizedBox(width: 4),
                      Text('Live', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: onViewFullMap,
                  icon: const Icon(Icons.open_in_full, size: 13),
                  label: const Text('Full Map', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6)),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 220,
            child: loading
                ? Container(color: Colors.grey.shade100)
                : FlutterMap(
                    options: MapOptions(
                      initialCenter: center,
                      initialZoom: 4.3,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.drag | InteractiveFlag.pinchZoom,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.eyeoty.mobile',
                      ),
                      MarkerLayer(
                        markers: withLocation.map((v) {
                          final color = _statusColor[v.status] ?? AppColors.statusOffline;
                          return Marker(
                            point: LatLng(v.lat!, v.lng!),
                            width: 12,
                            height: 12,
                            child: Container(
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1.5),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFFF8FAFC),
            child: Row(
              children: [
                for (final entry in _statusColor.entries) ...[
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: entry.value, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text(
                    entry.key[0].toUpperCase() + entry.key.substring(1),
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 10),
                ],
                const Spacer(),
                Text('${devices.length} vehicle${devices.length != 1 ? 's' : ''}',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
