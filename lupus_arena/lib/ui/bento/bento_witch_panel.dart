import 'package:flutter/material.dart';

import '../../models/game_room.dart';
import '../../services/app_translations.dart';
import '../theme/lupus_theme.dart';
import 'bento_card.dart';

import 'server_countdown_timer.dart';

/// Panneau Bento complet à deux fioles (Vie & Mort) réservé à la Sorcière.
/// Permet de sauver la victime des loups, d'empoisonner un suspect, ou de passer la nuit.
class BentoWitchPanel extends StatefulWidget {
  final GameRoom room;
  final String currentUserId;
  final String? selectedTargetId;
  final VoidCallback onSaveVictim;
  final ValueChanged<String> onPoisonVictim;
  final VoidCallback onConfirmAndEndNight;

  const BentoWitchPanel({
    super.key,
    required this.room,
    required this.currentUserId,
    required this.selectedTargetId,
    required this.onSaveVictim,
    required this.onPoisonVictim,
    required this.onConfirmAndEndNight,
  });

  @override
  State<BentoWitchPanel> createState() => _BentoWitchPanelState();
}

class _BentoWitchPanelState extends State<BentoWitchPanel> {
  bool _ended = false;

  void _triggerEnd() {
    if (_ended) return;
    _ended = true;
    widget.onConfirmAndEndNight();
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final witch = room.players[widget.currentUserId];
    final hasHeal = witch != null && (witch.potionsVie > 0 || !witch.hasUsedHealPotion);
    final hasPoison = witch != null && (witch.potionsMort > 0 || !witch.hasUsedPoisonPotion);

    final wolfVictim = room.nightVictimId != null ? room.players[room.nightVictimId] : null;
    final poisonVictim = room.witchPoisonVictimId != null ? room.players[room.witchPoisonVictimId] : null;
    final selectedTarget = widget.selectedTargetId != null ? room.players[widget.selectedTargetId] : null;

    final hasActed = room.witchHealed || room.witchPoisonVictimId != null;

    return BentoCard(
      borderColor: LupusColors.poisonGreen.withValues(alpha: 0.65),
      gradient: const LinearGradient(
        colors: [
          Color(0x33064E3B),
          Color(0x221E1B4B),
          Color(0x33450A0A),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // En-tête : Antre de la Sorcière & Minuteur
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: LupusColors.poisonGreen.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: LupusColors.poisonGreen, width: 1.2),
                    ),
                    child: const Text('🧙‍♀️', style: TextStyle(fontSize: 18)),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('witch_lair'),
                        style: const TextStyle(
                          fontFamily: 'serif',
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          color: Color(0xFFA7F3D0),
                        ),
                      ),
                      Text(
                        context.tr('witch_sub'),
                        style: const TextStyle(fontSize: 10.5, color: LupusColors.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
              // Minuteur dynamique réactif basé sur le temps serveur
              ServerCountdownBuilder(
                phaseEndsAt: widget.room.phaseEndsAt,
                fallbackSeconds: widget.room.timerSeconds > 0 ? widget.room.timerSeconds : 25,
                onTimerExpired: _triggerEnd,
                builder: (context, secondsRemaining) {
                  final isUrgent = secondsRemaining <= 5;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0x9905070F),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isUrgent ? LupusColors.bloodRed : LupusColors.poisonGreen,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.timer_outlined, size: 14, color: LupusColors.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          '${secondsRemaining}s',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: isUrgent ? LupusColors.bloodRed : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Les Deux Fioles Bento (Vie vs Mort)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. FIOLE DE VIE (SAUVETAGE)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0x22064E3B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: hasHeal
                          ? LupusColors.poisonGreen
                          : LupusColors.border.withValues(alpha: 0.5),
                      width: hasHeal ? 1.4 : 0.8,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Text('✨', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              context.tr('life_potion'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                                color: hasHeal ? LupusColors.poisonGreen : LupusColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Statut de la victime
                      if (room.witchHealed) ...[
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: LupusColors.poisonGreen.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            context.tr('victim_saved_tonight'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: LupusColors.poisonGreen,
                            ),
                          ),
                        ),
                      ] else if (wolfVictim != null) ...[
                        Text(
                          context.tr('wolf_attack'),
                          style: TextStyle(
                            fontSize: 10,
                            color: LupusColors.textMuted.withValues(alpha: 0.8),
                          ),
                        ),
                        Text(
                          wolfVictim.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: LupusColors.poisonGreen,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: hasHeal ? widget.onSaveVictim : null,
                          child: Text(
                            hasHeal ? context.tr('save_victim') : context.tr('used_potion'),
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
                          ),
                        ),
                      ] else ...[
                        Text(
                          context.tr('no_victim_to_save'),
                          style: const TextStyle(fontSize: 10.5, color: LupusColors.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          hasHeal ? context.tr('potion_available') : context.tr('potion_depleted'),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: hasHeal ? LupusColors.poisonGreen : LupusColors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // 2. FIOLE DE MORT (EMPOISONNEMENT)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0x22450A0A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: hasPoison
                          ? LupusColors.bloodRed
                          : LupusColors.border.withValues(alpha: 0.5),
                      width: hasPoison ? 1.4 : 0.8,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Text('☠️', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              context.tr('death_potion'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                                color: hasPoison ? LupusColors.bloodRed : LupusColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (poisonVictim != null) ...[
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: LupusColors.bloodRed.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            context.tr('victim_poisoned_tonight', {'name': poisonVictim.name}),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: LupusColors.bloodRed,
                            ),
                          ),
                        ),
                      ] else if (hasPoison) ...[
                        if (selectedTarget != null && selectedTarget.isAlive) ...[
                          Text(
                            context.tr('chosen_target', {'name': selectedTarget.name}),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: LupusColors.bloodRed,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => widget.onPoisonVictim(selectedTarget.id),
                            child: Text(
                              context.tr('poison_victim'),
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
                            ),
                          ),
                        ] else ...[
                          Text(
                            context.tr('tap_player_to_target'),
                            style: const TextStyle(fontSize: 10.5, color: LupusColors.textSecondary),
                          ),
                        ],
                      ] else ...[
                        Text(
                          context.tr('poison_used'),
                          style: const TextStyle(fontSize: 10.5, color: LupusColors.textMuted),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 3. Bouton Neutre / Validation Globale
          SizedBox(
            height: 46,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: hasActed ? LupusColors.poisonGreen : LupusColors.surfaceLight,
                foregroundColor: hasActed ? Colors.black : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: hasActed ? 4 : 0,
              ),
              onPressed: _triggerEnd,
              icon: Icon(
                hasActed ? Icons.check_circle_rounded : Icons.bedtime_outlined,
                size: 20,
              ),
              label: Text(
                hasActed
                    ? context.tr('confirm_witch_choices')
                    : context.tr('witch_pass'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
