import 'package:flutter/material.dart';

/// Ported 1:1 from FleetIntelligencePage.jsx's SEV_META and AGENT_META.

class SeverityMeta {
  final String label;
  final Color color;
  final Color bg;
  final Color dot;
  const SeverityMeta(this.label, this.color, this.bg, this.dot);
}

const Map<String, SeverityMeta> kSeverityMeta = {
  'critical': SeverityMeta('Critical', Color(0xFFE11D48), Color(0xFFFFF1F2), Color(0xFFF43F5E)),
  'warning': SeverityMeta('Warning', Color(0xFFD97706), Color(0xFFFFFBEB), Color(0xFFFBBF24)),
  'info': SeverityMeta('Info', Color(0xFF64748B), Color(0xFFF1F5F9), Color(0xFF94A3B8)),
};
const SeverityMeta kDefaultSeverityMeta = SeverityMeta('Info', Color(0xFF64748B), Color(0xFFF1F5F9), Color(0xFF94A3B8));

SeverityMeta severityMetaFor(String severity) => kSeverityMeta[severity] ?? kDefaultSeverityMeta;

class AgentMeta {
  final String label;
  final IconData icon;
  final int num;
  const AgentMeta(this.label, this.icon, this.num);
}

const Map<String, AgentMeta> kAgentMeta = {
  'data-quality': AgentMeta('Data Quality', Icons.storage_rounded, 6),
  'device-health': AgentMeta('Device Health', Icons.podcasts_rounded, 8),
  'alert-priority': AgentMeta('Alert Priority', Icons.notifications_active_rounded, 18),
  'gps-jump': AgentMeta('GPS Jump', Icons.timeline_rounded, 7),
};

AgentMeta agentMetaFor(String agent) => kAgentMeta[agent] ?? AgentMeta(agent, Icons.smart_toy_outlined, 0);