import 'package:flutter/material.dart';
import '../models/alert_model.dart';
import '../theme/app_colors.dart';

class SeverityBadge extends StatelessWidget {
  final AlertSeverity severity;
  const SeverityBadge({super.key, required this.severity});

  Color get _color {
    switch (severity) {
      case AlertSeverity.critical:
        return AppColors.severityCritical;
      case AlertSeverity.high:
        return AppColors.severityHigh;
      case AlertSeverity.medium:
        return AppColors.severityMedium;
      case AlertSeverity.low:
        return AppColors.severityLow;
    }
  }

  String get _label {
    switch (severity) {
      case AlertSeverity.critical:
        return 'Critical';
      case AlertSeverity.high:
        return 'High';
      case AlertSeverity.medium:
        return 'Medium';
      case AlertSeverity.low:
        return 'Low';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      // decoration: BoxDecoration(color: _color.withOpacity(0.12), borderRadius: BorderRadius.circular(999)),
            decoration: BoxDecoration(color: _color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
      child: Text(_label, style: TextStyle(color: _color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}
