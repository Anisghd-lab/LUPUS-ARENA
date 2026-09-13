import 'package:flutter/material.dart';
import '../../models/game_phase.dart';
import '../theme/lupus_theme.dart';
import 'bento_card.dart';

/// Composant Bento affichant la phase actuelle du jeu, la manche et le décompte
class BentoPhaseCard extends StatelessWidget {
  final GamePhase phase;
  final int round;
  final int timerSeconds;

  const BentoPhaseCard({
    super.key,
    required this.phase,
    required this.round,
    required this.timerSeconds,
  });

  @override
  Widget build(BuildContext context) {
    final isNight = phase.isNight;
    final accentColor = isNight
        ? LupusColors.moonIndigo
        : (phase == GamePhase.dayVoting ? LupusColors.bloodRed : LupusColors.sunAmber);

    return BentoCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      borderColor: accentColor.withValues(alpha: 0.4),
      gradient: LinearGradient(
        colors: [
          accentColor.withValues(alpha: 0.18),
          LupusColors.surface,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Badge de Manche
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accentColor.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isNight ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                      size: 14,
                      color: accentColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'CYCLE $round • ${isNight ? "NUIT" : "JOUR"}',
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),

              // Timer Circulaire ou Affichage Décompte
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: LupusColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: LupusColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 15,
                      color: timerSeconds <= 10 ? LupusColors.bloodRed : LupusColors.textSecondary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${timerSeconds}s',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: timerSeconds <= 10 ? LupusColors.bloodRed : LupusColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Titre et Description de Phase
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: accentColor.withValues(alpha: 0.6), width: 1.5),
                ),
                child: Icon(phase.icon, color: accentColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      phase.titleFr,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: LupusColors.textPrimary,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      phase.descriptionFr,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: LupusColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
