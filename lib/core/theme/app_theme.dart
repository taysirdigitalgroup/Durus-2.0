import 'package:flutter/material.dart';

/// Thème de l'application. Le mode sombre n'utilise volontairement PAS le
/// gris/noir par défaut de Material : on définit un bleu nuit moderne
/// ("deep navy") pour les surfaces, plus chaleureux et cohérent avec
/// l'identité visuelle (logo bleu) qu'un dark theme neutre générique.
class AppTheme {
  AppTheme._();

  static const Color _seedColor = Color(0xFF0B3D91); // bleu proche du logo

  // Palette "bleu nuit" pour le thème sombre.
  static const Color _darkBackground = Color(0xFF0A1930);
  static const Color _darkSurface = Color(0xFF11213D);
  static const Color _darkSurfaceVariant = Color(0xFF1A2C4E);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(seedColor: _seedColor, brightness: Brightness.light);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
    );
  }

  static ThemeData get dark {
    final base = ColorScheme.fromSeed(seedColor: _seedColor, brightness: Brightness.dark);
    final scheme = base.copyWith(
      surface: _darkSurface,
      surfaceContainerHighest: _darkSurfaceVariant,
      surfaceContainer: _darkSurfaceVariant,
      surfaceContainerLow: _darkSurface,
      surfaceContainerLowest: _darkBackground,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: _darkBackground,
      appBarTheme: AppBarTheme(centerTitle: false, elevation: 0, backgroundColor: _darkSurface),
      drawerTheme: DrawerThemeData(backgroundColor: _darkSurface),
      cardTheme: CardThemeData(
        elevation: 0,
        color: _darkSurfaceVariant,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.3)),
        ),
      ),
      dialogTheme: DialogThemeData(backgroundColor: _darkSurfaceVariant),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: _darkSurfaceVariant),
      popupMenuTheme: PopupMenuThemeData(color: _darkSurfaceVariant),
    );
  }
}
