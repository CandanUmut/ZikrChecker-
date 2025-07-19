import 'package:flutter/material.dart';

ThemeData buildLightTheme() {
  final base = ThemeData.light(useMaterial3: true);
  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: Colors.teal,
      secondary: Colors.tealAccent,
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
    ),
    scaffoldBackgroundColor: const Color(0xFFF7F9FA),
    cardTheme: CardTheme(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
    ),
    switchTheme: base.switchTheme.copyWith(
      thumbIcon: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
            ? const Icon(Icons.check, size: 14)
            : const Icon(Icons.circle_outlined, size: 12),
      ),
    ),
  );
}
