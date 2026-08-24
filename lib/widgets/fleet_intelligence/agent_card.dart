import 'package:flutter/material.dart';
import '../../core/fleet_intelligence/agent_meta.dart';

class AgentStatRow {
  final String label;
  final String value;
  final String? code;
  const AgentStatRow(this.label, this.value, {this.code});
}

/// Ported from FleetIntelligencePage.jsx's AgentCard — icon + label +
/// agent number, with tappable stat rows. Tapping a row calls onStatRow
/// with that row's code (or null), tapping the card header calls
/// onAgentTap — matches the web version's onStatClick ?? onAgentClick
/// fallback pattern exactly.
class AgentCard extends StatelessWidget {
  final String agentKey;
  final List<AgentStatRow>? stats;
  final bool loading;
  final VoidCallback onAgentTap;
  final void Function(String? code)? onStatTap;

  const AgentCard({
    super.key,
    required this.agentKey,
    required this.stats,
    required this.loading,
    required this.onAgentTap,
    this.onStatTap,
  });

  @override
  Widget build(BuildContext context) {
    final meta = agentMetaFor(agentKey);
    return Card(
      child: InkWell(
        onTap: onAgentTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(10)),
                    child: Icon(meta.icon, size: 17, color: const Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(meta.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                        Text('Agent #${meta.num}', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade300),
                ],
              ),
              const SizedBox(height: 10),
              if (loading || stats == null)
                Container(height: 70, color: Colors.grey.shade50)
              else
                ...stats!.map(
                  (s) => InkWell(
                    onTap: () => (onStatTap ?? (_) => onAgentTap())(s.code),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(s.label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                          Text(s.value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}