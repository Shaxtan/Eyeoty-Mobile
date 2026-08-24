import 'package:flutter/material.dart';

/// Genuinely working (not mocked) dark-mode toggle — no backend needed
/// for this one, so it's implemented for real rather than stubbed.
class ThemeModeProvider extends ChangeNotifier {
  ThemeMode mode = ThemeMode.light;

  void toggle(bool dark) {
    mode = dark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
}
