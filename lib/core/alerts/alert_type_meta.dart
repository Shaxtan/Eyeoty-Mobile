import 'package:flutter/material.dart';

/// Consolidates AlertsModal.jsx's ALERT_META (labels + colors — the
/// authoritative source per its own comment) with RecentAlertsListCard's
/// TYPE_ICON (icon choices) into one Dart source of truth, since both
/// JS files key off the same short type codes and are always used
/// together in practice.
class AlertTypeMeta {
  final String label;
  final Color color;
  final IconData icon;
  const AlertTypeMeta(this.label, this.color, this.icon);
}

const Map<String, AlertTypeMeta> kAlertTypeMeta = {
  'BAT': AlertTypeMeta('Battery', Color(0xFFF59E0B), Icons.battery_alert_rounded),
  'HAR': AlertTypeMeta('Harsh Accel.', Color(0xFFEF4444), Icons.warning_amber_rounded),
  'HBR': AlertTypeMeta('Harsh Brake', Color(0xFFE11D48), Icons.warning_amber_rounded),
  'OVS': AlertTypeMeta('Overspeed', Color(0xFF8B5CF6), Icons.warning_amber_rounded),
  'GEO': AlertTypeMeta('Geofence', Color(0xFF0EA5E9), Icons.logout_rounded),
  'IGN': AlertTypeMeta('Ignition', Color(0xFF10B981), Icons.wifi_off_rounded),
  'SOS': AlertTypeMeta('SOS / Panic', Color(0xFFDC2626), Icons.warning_amber_rounded),
  'TOW': AlertTypeMeta('Tow', Color(0xFF6366F1), Icons.wifi_off_rounded),
  'IDL': AlertTypeMeta('Idle', Color(0xFFF97316), Icons.wifi_off_rounded),
};

const AlertTypeMeta kDefaultAlertTypeMeta =
    AlertTypeMeta('Alert', Color(0xFF64748B), Icons.notifications_none_rounded);

AlertTypeMeta alertTypeMetaFor(String type) => kAlertTypeMeta[type] ?? AlertTypeMeta(type, kDefaultAlertTypeMeta.color, kDefaultAlertTypeMeta.icon);

String alertTypeLabel(String type) => kAlertTypeMeta[type]?.label ?? type;
