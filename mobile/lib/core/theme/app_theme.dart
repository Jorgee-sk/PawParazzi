import 'package:flutter/material.dart';

import 'tokens.dart';
import 'typography.dart';

ThemeData buildPawTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: PawColors.plum,
    primary: PawColors.plum,
    onPrimary: PawColors.white,
    secondary: PawColors.coral,
    surface: PawColors.cream,
    onSurface: PawColors.textPrimary,
    error: PawColors.error,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: PawColors.cream,
    fontFamily: 'Inter',
    textTheme: const TextTheme(
      displayLarge: PawText.display40,
      displayMedium: PawText.display32,
      displaySmall: PawText.display28,
      headlineMedium: PawText.heading24,
      headlineSmall: PawText.heading22,
      titleLarge: PawText.heading20,
      titleMedium: PawText.title18,
      bodyLarge: PawText.body15,
      bodyMedium: PawText.body14,
      bodySmall: PawText.caption13,
      labelLarge: PawText.button,
      labelSmall: PawText.caption12,
    ),
    textSelectionTheme: const TextSelectionThemeData(cursorColor: PawColors.plum),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: PawColors.plum),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
