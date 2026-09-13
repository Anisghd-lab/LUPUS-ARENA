import 'package:flutter/material.dart';
import '../theme/lupus_theme.dart';

/// Carte de base au style Bento UI avec bordure subtile, fond dégradé
/// et support d'effets lumineux (glow) pour les états actifs.
class BentoCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final Color? borderColor;
  final bool glowing;
  final VoidCallback? onTap;
  final double borderRadius;
  final Gradient? gradient;

  const BentoCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.backgroundColor,
    this.borderColor,
    this.glowing = false,
    this.onTap,
    this.borderRadius = 20,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? (backgroundColor ?? LupusColors.surface) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ??
              (glowing
                  ? LupusColors.voiceActive.withValues(alpha: 0.8)
                  : LupusColors.border.withValues(alpha: 0.6)),
          width: glowing ? 1.5 : 1.0,
        ),
        boxShadow: glowing
            ? [
                BoxShadow(
                  color: (borderColor ?? LupusColors.voiceActive).withValues(alpha: 0.25),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: child,
    );

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: onTap,
          child: content,
        ),
      );
    }

    return content;
  }
}
