import 'package:flutter/material.dart';

/// The game's colours and text styles, in one place.
class AppTheme {
  const AppTheme._();

  static const Color felt = Color(0xFF0B1220);
  static const Color feltDeep = Color(0xFF060A12);
  static const Color cabinet = Color(0xFF141C2E);
  static const Color cabinetEdge = Color(0xFF243049);
  static const Color gold = Color(0xFFFFC94D);
  static const Color goldDeep = Color(0xFFCE8F1C);
  static const Color crimson = Color(0xFFE23B4E);
  static const Color mint = Color(0xFF3DDC97);
  static const Color violet = Color(0xFF8B6BFF);
  static const Color ice = Color(0xFF6FD3FF);
  static const Color textDim = Color(0xFF8A94AC);

  /// Backdrop behind the whole cabinet.
  static const LinearGradient background = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[Color(0xFF16203A), felt, feltDeep],
    stops: <double>[0, 0.55, 1],
  );

  /// The brushed-gold sweep used on the frame and the spin button.
  static const LinearGradient goldSheen = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFFFFE9A8), gold, goldDeep, Color(0xFFFFD873)],
    stops: <double>[0, 0.35, 0.72, 1],
  );

  static ThemeData build() {
    final ThemeData base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: gold,
        brightness: Brightness.dark,
      ).copyWith(surface: cabinet),
      scaffoldBackgroundColor: felt,
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
    );
  }

  /// Digits that line up in columns as the credit counter rolls.
  static const TextStyle counter = TextStyle(
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
  );

  /// Small all-caps label above a readout.
  static const TextStyle label = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.6,
    color: textDim,
  );
}
