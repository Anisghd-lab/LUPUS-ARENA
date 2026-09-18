import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Widget d'animation spectrale encadrant le badge ou l'avatar d'un joueur :
/// - Détecte la transition de vie à trépas (isAlive passant de true à false).
/// - Déclenche une vibration haptique immersive (HapticFeedback.heavyImpact).
/// - Grise et désature le badge sous-jacent via une matrice de couleur.
/// - Fait léviter une âme / fantôme spectral translucide avec aura néon (cyan/violet mystique)
///   qui s'élève vers le haut avant de s'estomper dans les limbes.
class GhostDeathBadge extends StatefulWidget {
  final Widget child; // Badge de joueur ou avatar
  final bool isAlive; // player.isAlive
  final String playerUid;

  const GhostDeathBadge({
    super.key,
    required this.child,
    required this.isAlive,
    required this.playerUid,
  });

  @override
  State<GhostDeathBadge> createState() => _GhostDeathBadgeState();
}

class _GhostDeathBadgeState extends State<GhostDeathBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _translateY;
  late Animation<double> _opacity;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    // Élévation verticale : monte de 75 pixels vers le haut
    _translateY = Tween<double>(begin: 0.0, end: -75.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.9, curve: Curves.easeOutCubic),
      ),
    );

    // Évanouissement spectral (apparition rapide puis dissipation)
    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 0.95), weight: 20),
      TweenSequenceItem(tween: Tween<double>(begin: 0.95, end: 0.0), weight: 80),
    ]).animate(_animController);

    // Dilatation progressive de l'âme
    _scale = Tween<double>(begin: 0.9, end: 1.25).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutQuad),
      ),
    );
  }

  @override
  void didUpdateWidget(covariant GhostDeathBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Déclenchement automatique dès que isAlive passe à false (élimination au bûcher ou meurtre de nuit)
    if (oldWidget.isAlive && !widget.isAlive) {
      HapticFeedback.heavyImpact();
      _animController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none, // Permet l'envol au-dessus du cadre
          children: [
            // 1. Badge joueur (grisé/désaturé si éliminé)
            ColorFiltered(
              colorFilter: widget.isAlive
                  ? const ColorFilter.mode(Colors.transparent, BlendMode.multiply)
                  : const ColorFilter.matrix(<double>[
                      0.2126, 0.7152, 0.0722, 0, 0, // Rouge
                      0.2126, 0.7152, 0.0722, 0, 0, // Vert
                      0.2126, 0.7152, 0.0722, 0, 0, // Bleu
                      0,      0,      0,      0.65, 0, // Alpha atténué
                    ]),
              child: widget.child,
            ),

            // 2. Fantôme spectral calqué sur la taille du badge
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _animController,
                  builder: (context, child) {
                    if (_animController.isDismissed || _animController.isCompleted) {
                      return const SizedBox.shrink();
                    }
                    return Transform.translate(
                      offset: Offset(0, _translateY.value),
                      child: Transform.scale(
                        scale: _scale.value,
                        child: Opacity(
                          opacity: _opacity.value,
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: const _GhostVisual(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Visuel plein format avec halo mystique néon (cyan spectral & violet)
class _GhostVisual extends StatelessWidget {
  const _GhostVisual();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF06B6D4).withValues(alpha: 0.15),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF06B6D4).withValues(alpha: 0.65), // Cyan néon
            blurRadius: 20,
            spreadRadius: 4,
          ),
          BoxShadow(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.45), // Violet mystique
            blurRadius: 26,
            spreadRadius: 8,
          ),
        ],
      ),
      child: const Center(
        child: FittedBox(
          fit: BoxFit.contain,
          child: Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              '👻',
              style: TextStyle(
                shadows: [
                  Shadow(
                    color: Color(0xFF10B981),
                    blurRadius: 16,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
