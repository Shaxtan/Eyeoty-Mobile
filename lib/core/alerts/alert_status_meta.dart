import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Color scheme for the local triage states (open / acknowledged /
/// resolved). AlertsPage.jsx's real STATUS_META (from
/// ResponseStatusCard.jsx) wasn't shared, so these are chosen to be
/// consistent with this app's EXISTING tokens rather than invented from
/// scratch: open=danger (needs attention), acknowledged=primary (being
/// handled), resolved=success (done). Replace with the real hex values
/// if ResponseStatusCard.jsx is shared later.
class AlertStatusMeta {
  final String label;
  final Color color;
  const AlertStatusMeta(this.label, this.color);
}

const Map<String, AlertStatusMeta> kAlertStatusMeta = {
  'open': AlertStatusMeta('Open', AppColors.danger),
  'acknowledged': AlertStatusMeta('Acknowledged', AppColors.primary),
  'resolved': AlertStatusMeta('Resolved', AppColors.success),
};