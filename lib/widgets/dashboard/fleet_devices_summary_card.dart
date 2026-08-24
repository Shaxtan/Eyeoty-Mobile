import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Compact summary of FleetTableCard.jsx's two tabs (Live Vehicles /
/// Unreachable), shown on the Dashboard. The full searchable, filterable
/// list lives on its own screen (FleetDevicesScreen at /vehicles) —
/// this is the mobile-appropriate "compact card that opens the full
/// experience" pattern (Desktop multi-column dashboard -> responsive
/// mobile cards/sections), rather than cramming the whole dense table
/// onto the dashboard itself.
class FleetDevicesSummaryCard extends StatelessWidget {
  final int liveCount;
  final int unreachableCount;
  final bool loading;
  final VoidCallback onViewAll;

  const FleetDevicesSummaryCard({
    super.key,
    required this.liveCount,
    required this.unreachableCount,
    required this.loading,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Fleet Device Report', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _countTile(
                    icon: Icons.local_shipping,
                    color: AppColors.primary,
                    bg: AppColors.primarySoft,
                    label: 'Live Vehicles',
                    value: loading ? '\u2014' : '$liveCount',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _countTile(
                    icon: Icons.location_off_outlined,
                    color: Colors.grey.shade600,
                    bg: Colors.grey.shade100,
                    label: 'Unreachable',
                    value: loading ? '\u2014' : '$unreachableCount',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onViewAll,
                icon: const Icon(Icons.list_alt, size: 15),
                label: const Text('View All Devices'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _countTile({required IconData icon, required Color color, required Color bg, required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
