import 'package:flutter/material.dart';

/// Bouton Médiéval Fantastique RPG Haut de Gamme (MedievalFantasyButton)
/// Inspiré des assets graphiques World of Warcraft, Hearthstone et RPG Dark Fantasy :
/// - Cadre extérieur sculpté en bronze / métal / pierre taillée
/// - Texture et dégradé intérieur façon gemme taillée (Améthyste, Rubis, Ardoise runique, Or)
/// - Biseau avec reflet spéculaire supérieur et ombre d'incision inférieure
/// - Halo magique (Outer Glow) et ombre portée profonde
class MedievalFantasyButton extends StatefulWidget {
  final Widget? child;
  final VoidCallback? onTap;
  final double? width;
  final double? height;
  final List<Color> gradientColors;
  final Color borderColor;
  final Color glowColor;
  final double borderRadius;
  final List<Color> outerBevelColors;
  final EdgeInsetsGeometry padding;
  final bool enabled;

  const MedievalFantasyButton({
    super.key,
    this.child,
    this.onTap,
    this.width,
    this.height,
    required this.gradientColors,
    this.borderColor = const Color(0xFF8C7A58), // Bronze / Pierre dorée
    this.glowColor = const Color(0x66A855F7), // Lueur violette magique
    this.borderRadius = 16.0,
    this.outerBevelColors = const [
      Color(0xFF5A5243),
      Color(0xFF28231D),
      Color(0xFF141210),
    ],
    this.padding = const EdgeInsets.all(4.0),
    this.enabled = true,
  });

  /// 1. Bouton Cristal d'Améthyste Majeur (Pour "Créer un Salon" / Action Principale)
  factory MedievalFantasyButton.amethyst({
    Key? key,
    required Widget child,
    VoidCallback? onTap,
    double? width,
    double? height,
    double borderRadius = 16.0,
    bool enabled = true,
  }) {
    return MedievalFantasyButton(
      key: key,
      onTap: onTap,
      width: width,
      height: height,
      borderRadius: borderRadius,
      enabled: enabled,
      borderColor: const Color(0xFFA78BFA),
      glowColor: const Color(0x889333EA),
      outerBevelColors: const [
        Color(0xFF6B583E),
        Color(0xFF382E1E),
        Color(0xFF1A140B),
      ],
      gradientColors: const [
        Color(0xFF6B21A8),
        Color(0xFF4C1D95),
        Color(0xFF2E1065),
      ],
      child: child,
    );
  }

  /// 2. Bouton Rubis Sang / Flamboyant (Pour "Rejoindre un Salon" / Combat)
  factory MedievalFantasyButton.ruby({
    Key? key,
    required Widget child,
    VoidCallback? onTap,
    double? width,
    double? height,
    double borderRadius = 12.0,
    bool enabled = true,
  }) {
    return MedievalFantasyButton(
      key: key,
      onTap: onTap,
      width: width,
      height: height,
      borderRadius: borderRadius,
      enabled: enabled,
      borderColor: const Color(0xFFF87171),
      glowColor: const Color(0x66DC2626),
      outerBevelColors: const [
        Color(0xFF5B3434),
        Color(0xFF2E1515),
        Color(0xFF140808),
      ],
      gradientColors: const [
        Color(0xFF991B1B),
        Color(0xFF7F1D1D),
        Color(0xFF450A0A),
      ],
      child: child,
    );
  }

  /// 3. Bouton Pierre / Ardoise Runique Sombre (Pour Code du salon / Secondaire)
  factory MedievalFantasyButton.stone({
    Key? key,
    required Widget child,
    VoidCallback? onTap,
    double? width,
    double? height,
    double borderRadius = 12.0,
    bool enabled = true,
  }) {
    return MedievalFantasyButton(
      key: key,
      onTap: onTap,
      width: width,
      height: height,
      borderRadius: borderRadius,
      enabled: enabled,
      borderColor: const Color(0xFF64748B),
      glowColor: Colors.transparent,
      outerBevelColors: const [
        Color(0xFF3F3F46),
        Color(0xFF27272A),
        Color(0xFF18181B),
      ],
      gradientColors: const [
        Color(0xFF27272A),
        Color(0xFF18181B),
        Color(0xFF0F0F12),
      ],
      child: child,
    );
  }

  /// 4. Bouton Trésor / Or / Bénédiction (Pour Lancement / Succès)
  factory MedievalFantasyButton.gold({
    Key? key,
    required Widget child,
    VoidCallback? onTap,
    double? width,
    double? height,
    double borderRadius = 14.0,
    bool enabled = true,
  }) {
    return MedievalFantasyButton(
      key: key,
      onTap: onTap,
      width: width,
      height: height,
      borderRadius: borderRadius,
      enabled: enabled,
      borderColor: const Color(0xFFFDE047),
      glowColor: const Color(0x66EAB308),
      outerBevelColors: const [
        Color(0xFF785928),
        Color(0xFF4A3414),
        Color(0xFF241706),
      ],
      gradientColors: const [
        Color(0xFFB45309),
        Color(0xFF854D0E),
        Color(0xFF451A03),
      ],
      child: child,
    );
  }

  @override
  State<MedievalFantasyButton> createState() => _MedievalFantasyButtonState();
}

class _MedievalFantasyButtonState extends State<MedievalFantasyButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final effectiveEnabled = widget.enabled && widget.onTap != null;
    final scale = _isPressed ? 0.97 : 1.0;

    return AnimatedScale(
      scale: scale,
      duration: const Duration(milliseconds: 90),
      child: GestureDetector(
        onTapDown: effectiveEnabled ? (_) => setState(() => _isPressed = true) : null,
        onTapUp: effectiveEnabled ? (_) => setState(() => _isPressed = false) : null,
        onTapCancel: effectiveEnabled ? () => setState(() => _isPressed = false) : null,
        onTap: effectiveEnabled ? widget.onTap : null,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius + 3),
            // Cadre extérieur métallique / sculpté en biseau
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: widget.outerBevelColors,
            ),
            boxShadow: [
              // Lueur magique extérieure (glow)
              if (widget.glowColor != Colors.transparent && effectiveEnabled)
                BoxShadow(
                  color: widget.glowColor,
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              // Ombre portée profonde
              const BoxShadow(
                color: Colors.black87,
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          padding: widget.padding,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: Border.all(
                color: effectiveEnabled
                    ? widget.borderColor
                    : widget.borderColor.withValues(alpha: 0.35),
                width: 1.5,
              ),
              // Dégradé intérieur façon gemme taillée
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: effectiveEnabled
                    ? widget.gradientColors
                    : widget.gradientColors
                        .map((c) => c.withValues(alpha: 0.45))
                        .toList(),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.borderRadius - 1),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Reflet intérieur de biseau (haut lumineux, bas ombré)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.22),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.45),
                          ],
                          stops: const [0.0, 0.4, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // Contenu centré
                  if (widget.child != null)
                    Center(child: widget.child!),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
