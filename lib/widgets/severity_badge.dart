import 'package:flutter/material.dart';
import '../models/alert_model.dart';
import '../core/alerts/alert_severity_meta.dart';

class SeverityBadge extends StatelessWidget {
  final AlertSeverity severity;
  const SeverityBadge({super.key, required this.severity});

  @override
  Widget build(BuildContext context) {
    final color = severityColor(severity);
    final label = severityLabel(severity);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}