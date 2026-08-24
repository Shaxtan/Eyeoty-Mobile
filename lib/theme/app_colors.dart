import 'package:flutter/material.dart';

/// Colour tokens ported 1:1 from the existing web app's design system
/// (src/themes/tokens.js). Keeping identical hex values here is what
/// makes the mobile app visually consistent with the web platform.
class AppColors {
  AppColors._();

  // Sidebar / nav surface
  static const sidebar = Color(0xFF0E1A30);
  static const sidebarSoft = Color(0xFF16243D);
  static const sidebarLine = Color(0xFF1E3050);
  static const sidebarText = Color(0xFF94A8C6);
  static const sidebarMuted = Color(0xFF64789A);

  // Brand
  static const brandGold = Color(0xFFD29A4A);
  static const brandRed = Color(0xFFE0533A);

  // Primary
  static const primary = Color(0xFF2563EB);
  static const primaryHover = Color(0xFF1D4ED8);
  static const primarySoft = Color(0xFFEFF6FF);

  // Status
  static const statusMoving = Color(0xFF10B981);
  static const statusStopped = Color(0xFFF59E0B);
  static const statusInactive = Color(0xFFCBD5E1);
  static const statusOnline = Color(0xFF10B981);
  static const statusIdle = Color(0xFFF59E0B);
  static const statusOffline = Color(0xFF94A3B8);
  static const success = Color(0xFF059669);
  static const danger = Color(0xFFE11D48);

  // Severity (alerts) — mirrors SEVERITY_META usage in AlertsPage.jsx.
  static const severityCritical = Color(0xFFE11D48);
  static const severityHigh = Color(0xFFF59E0B);
  static const severityMedium = Color(0xFFF59E0B);
  static const severityLow = Color(0xFF2563EB);
}
