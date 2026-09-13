import 'dart:async';
import 'package:flutter/material.dart';

import '../../models/game_room.dart';
import '../theme/lupus_theme.dart';
import 'bento_card.dart';

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
  Timer? _turnTimer;
  int _secondsRemaining = 25;
  bool _ended = false;

  @override
  void initState() {
    super.initState();
    _secondsRemaining = widget.room.timerSeconds > 0 ? widget.room.timerSeconds : 25;
    _turnTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_secondsRemaining > 1) {
          _secondsRemaining--;
        } else {
          _triggerEnd();
        }
      });
    });
  }

  void _triggerEnd() {
    if (_ended) return;
    _ended = true;
    _turnTimer?.cancel();
    widget.onConfirmAndEndNight();
  }

  @override
  void dispose() {
    _turnTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final witch = room.players[widget.currentUserId];
    final hasHeal = witch != null && !witch.hasUsedHealPotion;
    final hasPoison = witch != null && !witch.hasUsedPoisonPotion;

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
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'L\'ANTRE DE LA SORCIÈRE',
                        style: TextStyle(
                          fontFamily: 'serif',
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          color: Color(0xFFA7F3D0),
                        ),
                      ),
                      Text(
                        'Deux fioles secrètes à votre disposition',
                        style: TextStyle(fontSize: 10.5, color: LupusColors.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
              // Minuteur dynamique 25s
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0x9905070F),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _secondsRemaining <= 5 ? LupusColors.bloodRed : LupusColors.poisonGreen,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined, size: 14, color: LupusColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      '${_secondsRemaining}s',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _secondsRemaining <= 5 ? LupusColors.bloodRed : Colors.white,
                      ),
                    ),
                  ],
                ),
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
                              'POTION DE VIE',
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
                          child: const Text(
                            '✨ Victime sauvée cette nuit !',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: LupusColors.poisonGreen,
                            ),
                          ),
                        ),
                      ] else if (wolfVictim != null) ...[
                        Text(
                          'Attaque des loups :',
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
                            hasHeal ? 'SAUVER' : 'ÉPUISÉE',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
                          ),
                        ),
                      ] else ...[
                        const Text(
                          'Aucune victime à sauver cette nuit.',
                          style: TextStyle(fontSize: 10.5, color: LupusColors.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          hasHeal ? 'Fiole disponible' : 'Fiole épuisée',
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
                              'POTION DE MORT',
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
                            '☠️ ${poisonVictim.name} empoisonné(e) !',
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
                            'Cible choisie : ${selectedTarget.name}',
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
                            child: const Text(
                              'EMPOISONNER',
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
                            ),
                          ),
                        ] else ...[
                          const Text(
                            'Touchez un joueur dans le village pour cibler.',
                            style: TextStyle(fontSize: 10.5, color: LupusColors.textSecondary),
                          ),
                        ],
                      ] else ...[
                        const Text(
                          'Fiole de poison déjà consommée.',
                          style: TextStyle(fontSize: 10.5, color: LupusColors.textMuted),
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
                    ? 'CONFIRMER MES CHOIX ET TERMINER LA NUIT'
                    : 'NE RIEN FAIRE • CONSERVER MES POTIONS',
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
