import 'package:flutter/material.dart';

class ThemeNotifier {
  // We default to light mode (Sunlight Mode)
  static final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.light);

  static void toggle() {
    if (mode.value == ThemeMode.light) {
      mode.value = ThemeMode.dark;
    } else {
      mode.value = ThemeMode.light;
    }
  }
}
