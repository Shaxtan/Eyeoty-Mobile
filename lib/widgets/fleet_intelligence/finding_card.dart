import 'package:flutter/material.dart';
import '../../core/fleet_intelligence/agent_meta.dart';
import '../../models/fleet_scan_result.dart';

/// Mobile equivalent of FleetIntelligencePage.jsx's findings TABLE —
/// converted to a card list (Desktop table -> mobile-friendly list/card
/// layout, per conversion guidelines) since 5 dense columns don't fit a
/// phone width. Carries the same information: severity, agent, title,
/// detail, vehicle, value/expected. Tappable through to Live Tracking
/// when the finding has an IMEI, exactly like the web row's onClick.
class FindingCard extends StatelessWidget {
  final FleetFinding finding;
  final VoidCallback? onTap;

  const FindingCard({super.key, required this.finding, this.onTap});

  @override
  Widget build(BuildContext context) {
    final sev = severityMetaFor(finding.severity);
    final agent = agentMetaFor(finding.agent);
    final canOpen = finding.imei != null && finding.imei!.isNotEmpty;

    return Card(
      child: InkWell(
        onTap: canOpen ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(color: sev.bg, borderRadius: BorderRadius.circular(999)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 5, height: 5, decoration: BoxDecoration(color: sev.dot, shape: BoxShape.circle)),
                        const SizedBox(width: 4),
                        Text(sev.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: sev.color)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(agent.icon, size: 12, color: Colors.grey.shade400),
                  const SizedBox(width: 3),
                  Text(agent.label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  if (canOpen) Icon(Icons.chevron_right, size: 16, color: Colors.grey.shade300),
                ],
              ),
              const SizedBox(height: 8),
              Text(finding.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(finding.detail, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              if (finding.vehnum != null || finding.imei != null || finding.value != null) ...[
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (finding.vehnum != null || finding.imei != null)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (finding.vehnum != null)
                              Text(finding.vehnum!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF2563EB))),
                            if (finding.imei != null)
                              Text(finding.imei!, style: TextStyle(fontSize: 9, color: Colors.grey.shade400, fontFamily: 'monospace')),
                          ],
                        ),
                      ),
                    if (finding.value != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(finding.value!, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w700)),
                          if (finding.expected != null)
                            Text('exp: ${finding.expected}', style: TextStyle(fontSize: 9, color: Colors.grey.shade400)),
                        ],
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}