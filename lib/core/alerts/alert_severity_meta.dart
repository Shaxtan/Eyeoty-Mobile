import 'package:flutter/material.dart';
import '../../models/alert_model.dart';
import '../../theme/app_colors.dart';

/// Shared severity color/label lookup, consolidated out of SeverityBadge
/// so other alert widgets (donut, categories, KPIs) can use the same
/// values without duplicating the switch statement.
Color severityColor(AlertSeverity s) {
  switch (s) {
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

String severityLabel(AlertSeverity s) {
  switch (s) {
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