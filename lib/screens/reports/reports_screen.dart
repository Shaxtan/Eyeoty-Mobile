import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class _ReportType {
  final String name;
  final String desc;
  final String route;
  const _ReportType(this.name, this.desc, this.route);
}

/// Ported from ReportsPage.jsx's landing grid. Mobile adaptation: the
/// desktop's inline setState-swap between report views (staying on the
/// same /reports URL) is replaced with real go_router sub-routes
/// (/reports/distance, /reports/stoppage, etc.) - gives correct native
/// back-button behaviour, which a mobile user expects and an in-place
/// JS state swap doesn't provide.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  static const _reportTypes = [
    _ReportType('Distance Report', 'Daily distance per vehicle', '/reports/distance'),
    _ReportType('Working Hour Report', 'Session trips & account analytics', '/reports/hourly'),
    _ReportType('Track Play', 'Historical route playback', '/reports/trackplay'),
    _ReportType('Overspeed Report', 'Violations by vehicle', '/reports/overspeed'),
    _ReportType('Stoppage Report', 'Stop duration & location', '/reports/stoppage'),
    _ReportType('Fuel Theft Report', 'Detect sudden analog sensor drops', '/reports/fuel-theft'),
    _ReportType('Load Cell Report', 'Sensor load data & averages', '/load-cell'),
    _ReportType('Live Load Graph', 'Real-time load monitoring', '/live-load'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Reports & Analytics', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(
          'Choose a report to generate detailed operational insights.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
        const SizedBox(height: 16),
        ..._reportTypes.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => context.go(r.route),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.bar_chart_outlined, size: 20, color: Colors.grey),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(r.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                                const SizedBox(height: 2),
                                Text(r.desc, style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade300),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            )),
      ],
    );
  }
}