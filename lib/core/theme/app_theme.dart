import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const primaryColor = Color(0xFFFF5722);
  static const primaryTextColor = Color(0xFF9A3412);
  static const onPrimaryColor = Color(0xFF1B1B1B);

  static ThemeData get light => _buildTheme(
    ColorScheme.fromSeed(seedColor: primaryColor, onPrimary: onPrimaryColor),
  );

  static ThemeData _buildTheme(ColorScheme colorScheme) => ThemeData(
    colorScheme: colorScheme,
    textTheme: Typography.material2021().black.apply(fontFamily: 'Roboto'),
    useMaterial3: true,
  );
}
