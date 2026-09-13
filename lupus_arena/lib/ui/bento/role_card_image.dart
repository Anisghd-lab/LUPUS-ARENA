import 'package:flutter/material.dart';
import '../../models/game_role.dart';

/// Helper associant chaque rôle du jeu à sa carte d'illustration officielle
/// issue du dossier 'LOUP GAROU ENHANCED'.
class RoleAssetMap {
  static String? getImagePath(GameRole role) {
    switch (role) {
      case GameRole.simpleVillager:
        return 'LOUP GAROU ENHANCED/Simple Villageois.jpg';
      case GameRole.seer:
        return 'LOUP GAROU ENHANCED/VOYANTE.jpg';
      case GameRole.witch:
        return 'LOUP GAROU ENHANCED/Sorcière.jpg';
      case GameRole.hunter:
        return 'LOUP GAROU ENHANCED/Chasseur.jpg';
      case GameRole.cupid:
        return 'LOUP GAROU ENHANCED/CUPIDON.jpg';
      case GameRole.littleGirl:
        return 'LOUP GAROU ENHANCED/Petite Fille.jpg';
      case GameRole.thief:
        return 'LOUP GAROU ENHANCED/Voleur.jpg';
      case GameRole.defender:
        return 'LOUP GAROU ENHANCED/Salvateur.jpg';
      case GameRole.elder:
        return 'LOUP GAROU ENHANCED/Ancien.jpg';
      case GameRole.scapegoat:
        return 'LOUP GAROU ENHANCED/Bouc Émissaire.jpg';
      case GameRole.idiot:
        return 'LOUP GAROU ENHANCED/Idiot du village.jpg';
      case GameRole.twoSisters:
        return 'LOUP GAROU ENHANCED/Deux Sœurs.jpg';
      case GameRole.threeBrothers:
        return 'LOUP GAROU ENHANCED/Trois Frères.jpg';
      case GameRole.fox:
        return 'LOUP GAROU ENHANCED/Renard.jpg';
      case GameRole.bearTamer:
        return 'LOUP GAROU ENHANCED/Montreur d\'Ours.jpg';
      case GameRole.stutteringJudge:
        return 'LOUP GAROU ENHANCED/Juge bègue.jpg';
      case GameRole.knightRustySword:
        return 'LOUP GAROU ENHANCED/Chevalier à l\'Épée Rouillée.jpg';
      case GameRole.servantMaid:
        return 'LOUP GAROU ENHANCED/Servante Dévouée.jpg';
      case GameRole.actor:
        return 'LOUP GAROU ENHANCED/Comédien.jpg';
      case GameRole.simpleWerewolf:
        return 'LOUP GAROU ENHANCED/Loup-Garou.jpg';
      case GameRole.bigBadWolf:
        return 'LOUP GAROU ENHANCED/Grand-Méchant-Loup.jpg';
      case GameRole.whiteWerewolf:
        return 'LOUP GAROU ENHANCED/Loup Blanc.jpg';
      case GameRole.vileFatherOfWolves:
        return 'LOUP GAROU ENHANCED/Infect Père des Loups.jpg';
      case GameRole.wolfCub:
        return 'LOUP GAROU ENHANCED/Chien-loup.jpg';
      case GameRole.wildChild:
        return 'LOUP GAROU ENHANCED/Enfant Sauvage.jpg';
      case GameRole.pyromaniac:
        return 'LOUP GAROU ENHANCED/Pyromane.jpg';
      case GameRole.raven:
        return 'LOUP GAROU ENHANCED/Corbeau.jpg';
      case GameRole.angel:
        return 'LOUP GAROU ENHANCED/Ange.jpg';
      case GameRole.piedPiper:
        return 'LOUP GAROU ENHANCED/Joueur de Flûte.jpg';
      case GameRole.sectLeader:
        return 'LOUP GAROU ENHANCED/Abominable Sectaire.jpg';
      case GameRole.thiefOfHearts:
        return 'LOUP GAROU ENHANCED/Gitane.jpg';
      case GameRole.mayor:
        return 'LOUP GAROU ENHANCED/Maire.jpg';
    }
  }
}

/// Widget affichant l'illustration officielle haute définition d'un rôle
/// avec gestion de cache et fallback gracieux.
class RoleCardImage extends StatelessWidget {
  final GameRole role;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final bool showBorder;
  final bool showGlow;

  const RoleCardImage({
    super.key,
    required this.role,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.showBorder = true,
    this.showGlow = false,
  });

  @override
  Widget build(BuildContext context) {
    final imagePath = RoleAssetMap.getImagePath(role);
    final radius = borderRadius ?? BorderRadius.circular(16);
    final accent = role.accentColor;

    Widget imageWidget;
    if (imagePath != null) {
      imageWidget = Image.asset(
        imagePath,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholder(accent);
        },
      );
    } else {
      imageWidget = _buildPlaceholder(accent);
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: showBorder
            ? Border.all(
                color: accent.withValues(alpha: showGlow ? 0.8 : 0.4),
                width: showGlow ? 2.0 : 1.2,
              )
            : null,
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.4),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: imageWidget,
      ),
    );
  }

  Widget _buildPlaceholder(Color accent) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            accent.withValues(alpha: 0.25),
            const Color(0xFF0A0F1E),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              role.icon,
              size: (width != null && width! < 60) ? 22 : 36,
              color: accent,
            ),
            if (width == null || width! >= 80) ...[
              const SizedBox(height: 6),
              Text(
                role.displayName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
