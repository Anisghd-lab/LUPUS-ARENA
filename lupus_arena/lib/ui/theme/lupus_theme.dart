import 'package:flutter/material.dart';

/// Palette chromatique inspirée directement des maquettes Stitch de Lupus Arena
class LupusColors {
  // Fond et surfaces sombres d'inspiration gothique nocturne
  static const Color background = Color(0xFF05070F);
  static const Color surface = Color(0xFF0A0F1E);
  static const Color surfaceLight = Color(0xFF12172A);
  static const Color surfaceElevated = Color(0xFF1E243D);

  // Verre dépoli et panneaux translucides (Stitch Glass Panels)
  static const Color glassPanel = Color(0xAE0A0F1E);
  static const Color glassButton = Color(0xC012182E);

  // Bordures Bento & Arcanes
  static const Color border = Color(0x38A855F7); // Violet néon subtil
  static const Color borderSubtle = Color(0x1FFFFFFF);
  static const Color borderGlow = Color(0xFF9D4EDD);

  // Couleurs Arcanes Stitch
  static const Color arcanePurple = Color(0xFF9D4EDD);
  static const Color arcaneViolet = Color(0xFF7B2CBF);
  static const Color arcaneGlow = Color(0xFFC77DFF);
  static const Color arcaneCyan = Color(0xFF38BDF8);
  static const Color arcaneCrimson = Color(0xFFE63946);
  static const Color arcaneGold = Color(0xFFFFB703);
  static const Color arcaneAmber = Color(0xFFFB8500);

  // Aliases rétrocompatibles
  static const Color bloodRed = arcaneCrimson;
  static const Color moonIndigo = Color(0xFF6C63FF);
  static const Color mysticPurple = arcanePurple;
  static const Color poisonGreen = Color(0xFF06D6A0);
  static const Color sunAmber = arcaneGold;
  static const Color daylightCyan = arcaneCyan;

  // Statuts vocaux
  static const Color voiceActive = Color(0xFF00F5D4);
  static const Color voiceMuted = Color(0xFFFF477E);

  // Textes
  static const Color textPrimary = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);
}

class LupusTheme {
  static ThemeData get darkTheme {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: LupusColors.background,
      colorScheme: const ColorScheme.dark(
        primary: LupusColors.arcanePurple,
        secondary: LupusColors.arcaneCrimson,
        surface: LupusColors.surface,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: LupusColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  /// Décoration Bento classique ou en verre teinté
  static BoxDecoration bentoDecoration({
    Color? color,
    Color? borderColor,
    double borderWidth = 1.0,
    double borderRadius = 20,
    bool glowing = false,
  }) {
    return BoxDecoration(
      color: color ?? LupusColors.surface,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor ?? (glowing ? LupusColors.voiceActive : LupusColors.border),
        width: borderWidth,
      ),
      boxShadow: glowing
          ? [
              BoxShadow(
                color: (borderColor ?? LupusColors.voiceActive).withValues(alpha: 0.35),
                blurRadius: 16,
                spreadRadius: 2,
              )
            ]
          : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
    );
  }

  /// Décoration en verre dépoli (Glass Panel) fidèle au design Stitch
  static BoxDecoration glassDecoration({
    Color? color,
    Color? borderColor,
    double borderWidth = 1.0,
    double borderRadius = 20,
    List<BoxShadow>? shadows,
  }) {
    return BoxDecoration(
      color: color ?? LupusColors.glassPanel,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor ?? LupusColors.border,
        width: borderWidth,
      ),
      boxShadow: shadows ??
          [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
    );
  }

  /// Halos lumineux Stitch
  static List<BoxShadow> glowPurple({double opacity = 0.45}) => [
        BoxShadow(
          color: LupusColors.arcanePurple.withValues(alpha: opacity),
          blurRadius: 20,
          spreadRadius: 1,
        ),
      ];

  static List<BoxShadow> glowGold({double opacity = 0.55}) => [
        BoxShadow(
          color: LupusColors.arcaneGold.withValues(alpha: opacity),
          blurRadius: 22,
          spreadRadius: 1,
        ),
      ];

  static List<BoxShadow> glowCyan({double opacity = 0.4}) => [
        BoxShadow(
          color: LupusColors.arcaneCyan.withValues(alpha: opacity),
          blurRadius: 16,
          spreadRadius: 1,
        ),
      ];

  static List<BoxShadow> glowRed({double opacity = 0.6}) => [
        BoxShadow(
          color: LupusColors.arcaneCrimson.withValues(alpha: opacity),
          blurRadius: 16,
          spreadRadius: 1,
        ),
      ];

  static List<BoxShadow> glowCrimson({double opacity = 0.45}) => [
        BoxShadow(
          color: LupusColors.arcaneCrimson.withValues(alpha: opacity),
          blurRadius: 18,
          spreadRadius: 1,
        ),
      ];
}
