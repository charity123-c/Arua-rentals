import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const primaryColor = Color(0xFFFF5722);

  static ThemeData get light => ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: primaryColor),
        useMaterial3: true,
      );
}
