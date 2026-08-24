import 'package:flutter/material.dart';
import '../../models/device_item.dart';

/// Ported 1:1 from MapPage.jsx's own getStatus() - genuinely different
/// from DeviceItem.status (FleetTableCard.jsx's getVtsStatus): no
/// staleness/offline check, and adds a "Locked" state driven by the
/// device's lock flag, checked first.
enum MapViewStatus { motion, idle, stop, lock }

MapViewStatus mapViewStatusOf(DeviceItem d) {
  final isLock = d.lock == '1' || d.lock?.toLowerCase() == 'true';
  if (isLock) return MapViewStatus.lock;

  final speed = d.speed.toDouble();
  final ignOn = (d.ignition ?? '').toUpperCase() == 'Y';
  if (speed > 5 && ignOn) return MapViewStatus.motion;
  if (ignOn) return MapViewStatus.idle;
  return MapViewStatus.stop;
}

// Exact hex values from MapPage.jsx's STATUS_COLOR.
const Map<MapViewStatus, Color> kMapViewStatusColor = {
  MapViewStatus.motion: Color(0xFF4CAF50),
  MapViewStatus.idle: Color(0xFFFF9800),
  MapViewStatus.stop: Color(0xFFF44336),
  MapViewStatus.lock: Color(0xFF2196F3),
};

String mapViewStatusLabel(MapViewStatus s) {
  switch (s) {
    case MapViewStatus.motion:
      return 'Motion';
    case MapViewStatus.idle:
      return 'Idle';
    case MapViewStatus.stop:
      return 'Stopped';
    case MapViewStatus.lock:
      return 'Locked';
  }
}

// Matches MapPage.jsx's FILTERS array/order exactly.
const List<MapViewStatus?> kMapViewFilters = [null, MapViewStatus.motion, MapViewStatus.idle, MapViewStatus.stop, MapViewStatus.lock];

String mapViewFilterLabel(MapViewStatus? s) => s == null ? 'All' : mapViewStatusLabel(s);