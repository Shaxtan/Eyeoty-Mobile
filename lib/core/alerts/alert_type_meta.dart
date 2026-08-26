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
  'BAT':
      AlertTypeMeta('Battery', Color(0xFFF59E0B), Icons.battery_alert_rounded),
  'HAR': AlertTypeMeta(
      'Harsh Accel.', Color(0xFFEF4444), Icons.warning_amber_rounded),
  'HBR': AlertTypeMeta(
      'Harsh Brake', Color(0xFFE11D48), Icons.warning_amber_rounded),
  'OVS': AlertTypeMeta(
      'Overspeed', Color(0xFF8B5CF6), Icons.warning_amber_rounded),
  'GEO': AlertTypeMeta('Geofence', Color(0xFF0EA5E9), Icons.logout_rounded),
  'IGN': AlertTypeMeta('Ignition', Color(0xFF10B981), Icons.wifi_off_rounded),
  'SOS': AlertTypeMeta(
      'SOS / Panic', Color(0xFFDC2626), Icons.warning_amber_rounded),
  'TOW': AlertTypeMeta('Tow', Color(0xFF6366F1), Icons.wifi_off_rounded),
  'IDL': AlertTypeMeta('Idle', Color(0xFFF97316), Icons.wifi_off_rounded),
};

const AlertTypeMeta kDefaultAlertTypeMeta =
    AlertTypeMeta('Alert', Color(0xFF64748B), Icons.notifications_none_rounded);

AlertTypeMeta alertTypeMetaFor(String type) =>
    kAlertTypeMeta[type] ??
    AlertTypeMeta(
        type, kDefaultAlertTypeMeta.color, kDefaultAlertTypeMeta.icon);

String alertTypeLabel(String type) => kAlertTypeMeta[type]?.label ?? type;

/// Message-aware version of alertTypeMetaFor(). The backend sometimes
/// reuses a single code (e.g. "HAR") for multiple event kinds, so the
/// static kAlertTypeMeta lookup can disagree with what the `message`
/// field actually describes — for example a HAR event whose message
/// says "Driver used Harsh Braking" would show "Harsh Accel." under the
/// plain type-only lookup. This function scans the message first and
/// only falls back to the type-code lookup when no known phrase is
/// found, so what the user sees matches what actually happened.
AlertTypeMeta alertMetaFromMessage(String? message, String type) {
  final m = (message ?? '').toLowerCase();
  if (m.isNotEmpty) {
    if (m.contains('harsh braking') || m.contains('harsh brake')) {
      return const AlertTypeMeta(
          'Harsh Brake', Color(0xFFE11D48), Icons.warning_amber_rounded);
    }
    if (m.contains('harsh acceleration') || m.contains('harsh accel')) {
      return const AlertTypeMeta(
          'Harsh Accel.', Color(0xFFEF4444), Icons.warning_amber_rounded);
    }
    if (m.contains('harsh cornering') || m.contains('harsh turn')) {
      return const AlertTypeMeta(
          'Harsh Turn', Color(0xFFEF4444), Icons.warning_amber_rounded);
    }
    if (m.contains('ignition on')) {
      return const AlertTypeMeta(
          'Ignition On', Color(0xFF10B981), Icons.power_settings_new_rounded);
    }
    if (m.contains('ignition off')) {
      return const AlertTypeMeta(
          'Ignition Off', Color(0xFF64748B), Icons.power_settings_new_rounded);
    }
    if (m.contains('overspeed') ||
        m.contains('over speed') ||
        m.contains('speed limit')) {
      return const AlertTypeMeta(
          'Overspeed', Color(0xFF8B5CF6), Icons.warning_amber_rounded);
    }
    if (m.contains('geofence entry') ||
        m.contains('entered geofence') ||
        m.contains('geo-fence entry')) {
      return const AlertTypeMeta(
          'Geofence Entry', Color(0xFF0EA5E9), Icons.login_rounded);
    }
    if (m.contains('geofence exit') ||
        m.contains('exited geofence') ||
        m.contains('geo-fence exit')) {
      return const AlertTypeMeta(
          'Geofence Exit', Color(0xFF0EA5E9), Icons.logout_rounded);
    }
    if (m.contains('low battery') || m.contains('battery low')) {
      return const AlertTypeMeta(
          'Low Battery', Color(0xFFF59E0B), Icons.battery_alert_rounded);
    }
    if (m.contains('sos') || m.contains('panic')) {
      return const AlertTypeMeta(
          'SOS / Panic', Color(0xFFDC2626), Icons.warning_amber_rounded);
    }
    if (m.contains('tow') || m.contains('towed')) {
      return const AlertTypeMeta(
          'Tow', Color(0xFF6366F1), Icons.local_shipping_outlined);
    }
    if (m.contains('idle') || m.contains('idling')) {
      return const AlertTypeMeta(
          'Idle', Color(0xFFF97316), Icons.hourglass_bottom_rounded);
    }
    if (m.contains('tamper')) {
      return const AlertTypeMeta(
          'Tamper', Color(0xFFE11D48), Icons.warning_amber_rounded);
    }
  }
  return alertTypeMetaFor(type);
}

/// Convenience wrapper — just the label from alertMetaFromMessage().
String alertLabelFromMessage(String? message, String type) =>
    alertMetaFromMessage(message, type).label;
