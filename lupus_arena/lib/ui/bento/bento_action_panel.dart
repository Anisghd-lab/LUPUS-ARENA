import 'package:flutter/material.dart';

import '../../models/game_phase.dart';
import '../../models/game_room.dart';
import '../../models/player_model.dart';
import '../theme/lupus_theme.dart';
import 'bento_card.dart';

/// Panneau d'actions Bento contextuel ultra-complet pour chaque rôle,
/// fidèle à 100% au design Stitch (surfaces sombres, halos dorés/crimson/cyan, verre dépoli).
class BentoActionPanel extends StatefulWidget {
  final GameRoom room;
  final String currentUserId;
  final String? selectedTargetId;
  final GameRole? inspectedRole;
  final bool isHost;
  final VoidCallback onNextPhase;
  final ValueChanged<String?> onVote;
  final ValueChanged<String> onInspect;
  final VoidCallback onCompleteSeerTurn;
  final VoidCallback onWitchSave;
  final ValueChanged<String> onWitchPoison;
  final VoidCallback onWitchPass;
  final ValueChanged<String>? onDefenderProtect;
  final void Function(String p1, String p2)? onCupidBind;
  final ValueChanged<String>? onThiefSteal;
  final ValueChanged<String>? onHunterShoot;
  final ValueChanged<String>? onCaptainPass;
  final ValueChanged<String>? onPyromaniacDouse;
  final VoidCallback? onPyromaniacIgnite;
  final VoidCallback? onPyromaniacPass;
  final bool isAdmin;
  final VoidCallback? onPassDebate;

  const BentoActionPanel({
    super.key,
    required this.room,
    required this.currentUserId,
    required this.selectedTargetId,
    this.inspectedRole,
    required this.isHost,
    this.isAdmin = false,
    required this.onNextPhase,
    required this.onVote,
    required this.onInspect,
    required this.onCompleteSeerTurn,
    required this.onWitchSave,
    required this.onWitchPoison,
    required this.onWitchPass,
    this.onDefenderProtect,
    this.onCupidBind,
    this.onThiefSteal,
    this.onHunterShoot,
    this.onCaptainPass,
    this.onPyromaniacDouse,
    this.onPyromaniacIgnite,
    this.onPyromaniacPass,
    this.onPassDebate,
  });

  @override
  State<BentoActionPanel> createState() => _BentoActionPanelState();
}

class _BentoActionPanelState extends State<BentoActionPanel> {
  // Sélection des deux amoureux par Cupidon
  String? _cupidLover1Id;
  String? _cupidLover2Id;

  @override
  Widget build(BuildContext context) {
    final me = widget.room.players[widget.currentUserId];
    if (me == null) return const SizedBox.shrink();

    final isAlive = me.isAlive;
    final role = me.role;
    final phase = widget.room.phase;
    final selectedTarget = widget.selectedTargetId != null
        ? widget.room.players[widget.selectedTargetId]
        : null;

    return BentoCard(
      padding: const EdgeInsets.all(16),
      borderColor: LupusColors.borderGlow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // En-tête avec badge de la cible sélectionnée
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ACTIONS STRATÉGIQUES',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: isAlive
                      ? LupusColors.textSecondary
                      : LupusColors.textMuted,
                ),
              ),
              if (selectedTarget != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: LupusColors.surfaceLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: LupusColors.arcaneGold.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.gps_fixed_rounded,
                        size: 12,
                        color: LupusColors.arcaneGold,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Cible : ${selectedTarget.name}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: LupusColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // -------------------------------------------------------------
          // 1. CHASSEUR DANS SON DERNIER SOUFFLE (Interruption prioritaire)
          // -------------------------------------------------------------
          if (phase == GamePhase.hunterDeathChoice &&
              (widget.room.pendingHunterId == widget.currentUserId ||
                  widget.isAdmin)) ...[
            _buildHunterSection(selectedTarget),
          ]
          // -------------------------------------------------------------
          // 2. CAPITAINE DÉFUNT QUI TRANSMET SON ÉCHARPE
          // -------------------------------------------------------------
          else if (phase == GamePhase.captainSuccession &&
              (widget.room.pendingCaptainId == widget.currentUserId ||
                  widget.isAdmin)) ...[
            _buildCaptainSuccessionSection(selectedTarget),
          ]
          // -------------------------------------------------------------
          // 3. JOUEUR ÉLIMINÉ SANS ACTION PARTICULIÈRE (Sauf en Mode God)
          // -------------------------------------------------------------
          else if (!isAlive && !widget.isAdmin) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: LupusColors.textMuted.withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.nightlight_round,
                    color: LupusColors.textMuted,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '💀 Vous êtes tombé au combat. Vous observez le destin du village en silence.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: LupusColors.textMuted,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ]
          // -------------------------------------------------------------
          // 4. VOLEUR (NUIT 1)
          // -------------------------------------------------------------
          else if (phase == GamePhase.nightThief &&
              (role == GameRole.thief || widget.isAdmin)) ...[
            _buildThiefSection(selectedTarget),
          ]
          // -------------------------------------------------------------
          // 5. CUPIDON (NUIT 1 : CHOIX DES DEUX AMOUREUX)
          // -------------------------------------------------------------
          else if (phase == GamePhase.nightCupid &&
              (role == GameRole.cupid || widget.isAdmin)) ...[
            _buildCupidSection(selectedTarget),
          ]
          // -------------------------------------------------------------
          // 6. VOYANTE (SONDER UNE ÂME)
          // -------------------------------------------------------------
          else if (phase == GamePhase.nightSeer &&
              (role == GameRole.seer || widget.isAdmin)) ...[
            _buildSeerSection(selectedTarget),
          ]
          // -------------------------------------------------------------
          // 7. SALVATEUR (PROTECTION NOCTURNE)
          // -------------------------------------------------------------
          else if (phase == GamePhase.nightDefender &&
              (role == GameRole.defender || widget.isAdmin)) ...[
            _buildDefenderSection(selectedTarget),
          ]
          // -------------------------------------------------------------
          // 8. LOUPS-GAROUS (CHASSE NOCTURNE DE LA MEUTE)
          // -------------------------------------------------------------
          else if (phase == GamePhase.nightWerewolves &&
              (role.isEvil || widget.isAdmin)) ...[
            _buildWerewolvesSection(me, selectedTarget),
          ]
          // -------------------------------------------------------------
          // 9. SORCIÈRE (POTIONS DE VIE ET DE MORT)
          // -------------------------------------------------------------
          else if (phase == GamePhase.nightWitch &&
              (role == GameRole.witch || widget.isAdmin)) ...[
            _buildWitchSection(
              widget.room.playerList.firstWhere(
                (p) => p.role == GameRole.witch,
                orElse: () => me,
              ),
              selectedTarget,
            ),
          ]
          // -------------------------------------------------------------
          // 9b. PYROMANE (ASPERGER D'HUILE OU METTRE LE FEU)
          // -------------------------------------------------------------
          else if (phase == GamePhase.nightPyromaniac &&
              (role == GameRole.pyromaniac || widget.isAdmin)) ...[
            _buildPyromaniacSection(selectedTarget),
          ]
          // -------------------------------------------------------------
          // 10. ÉLECTION DU CAPITAINE (JOUR 1)
          // -------------------------------------------------------------
          else if (phase == GamePhase.captainElection) ...[
            _buildCaptainElectionSection(selectedTarget),
          ]
          // -------------------------------------------------------------
          // 11. DÉBAT AU TOUR PAR TOUR
          // -------------------------------------------------------------
          else if (phase == GamePhase.dayDebate) ...[
            _buildDebateSection(),
          ]
          // -------------------------------------------------------------
          // 12. SCRUTIN DU BÛCHER & SECOND VOTE
          // -------------------------------------------------------------
          else if (phase == GamePhase.dayVoting ||
              phase == GamePhase.dayTieBreakVote) ...[
            _buildVotingSection(me, selectedTarget),
          ]
          // -------------------------------------------------------------
          // PAR DÉFAUT : AUCUNE ACTION REQUISE
          // -------------------------------------------------------------
          else ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              alignment: Alignment.center,
              child: Text(
                phase.isNight
                    ? '🌑 Les ténèbres recouvrent le village. Vous dormez d\'un sommeil profond.'
                    : '🏛️ Observez les échanges et préparez vos soupçons pour le scrutin.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: LupusColors.textSecondary,
                  fontSize: 12.5,
                ),
              ),
            ),
          ],

          // BOUTON MAÎTRE DU JEU (HÔTE) POUR FORCER LA PHASE
          if (widget.isHost &&
              phase != GamePhase.lobby &&
              phase != GamePhase.gameOver) ...[
            const SizedBox(height: 14),
            const Divider(color: LupusColors.border, height: 1),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: LupusColors.sunAmber,
                side: BorderSide(
                  color: LupusColors.sunAmber.withValues(alpha: 0.6),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onPressed: widget.onNextPhase,
              icon: const Icon(Icons.fast_forward_rounded, size: 18),
              label: const Text(
                'Avancer la phase (Maître du Jeu)',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // MODULES PAR RÔLE
  // ===========================================================================

  /// Module Sorcière : Panneau des Potions (Vie & Mort)
  Widget _buildWitchSection(PlayerModel witch, PlayerModel? selectedTarget) {
    final wolfVictimId = widget.room.nightVictimId;
    PlayerModel? wolfVictim = wolfVictimId != null
        ? widget.room.players[wolfVictimId]
        : null;

    // Si aucune victime n'est encore définie (ex: saut direct de phase), récupérer un innocent vivant
    if (wolfVictim == null) {
      final innocentLiving = widget.room.alivePlayers
          .where((p) => !p.role.isEvil)
          .toList();
      if (innocentLiving.isNotEmpty) {
        wolfVictim = innocentLiving.first;
      }
    }

    final isHealed = widget.room.witchHealed;
    final hasHeal = !witch.hasUsedHealPotion && !isHealed;
    final hasPoison = !witch.hasUsedPoisonPotion;
    final poisonVictimId = widget.room.witchPoisonVictimId;
    final poisonVictim = poisonVictimId != null
        ? widget.room.players[poisonVictimId]
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.isAdmin &&
            widget.room.players[widget.currentUserId]?.role !=
                GameRole.witch) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: LupusColors.poisonGreen.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: LupusColors.poisonGreen.withValues(alpha: 0.7),
                width: 1,
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.science_rounded,
                  size: 14,
                  color: LupusColors.poisonGreen,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'OBSERVATION DIVINE (MODE GOD) : POTIONS DE LA SORCIÈRE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      color: Color(0xFFD1FAE5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // 1. CARTE MAJEURE : VICTIME DES LOUPS-GAROUS (CLAIREMENT VISIBLE)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isHealed ? const Color(0x33059669) : const Color(0x3DDC2626),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isHealed
                  ? const Color(0xFF10B981)
                  : const Color(0xFFEF4444),
              width: 1.5,
            ),
            boxShadow: isHealed
                ? [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.3),
                      blurRadius: 12,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                      blurRadius: 14,
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isHealed
                          ? const Color(0xFF064E3B)
                          : const Color(0xFF7F1D1D),
                      border: Border.all(
                        color: isHealed
                            ? const Color(0xFF34D399)
                            : const Color(0xFFF87171),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        isHealed ? '✨' : '🩸',
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isHealed
                              ? 'VICTIME SAUVÉE DU TRÉPAS'
                              : 'VICTIME DES LOUPS-GAROUS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            color: isHealed
                                ? const Color(0xFF6EE7B7)
                                : const Color(0xFFFCA5A5),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          wolfVictim?.name ?? 'Villageois inconnu',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          isHealed
                              ? 'Votre fiole de vie a refermé ses plaies mortelles.'
                              : 'Les crocs des loups l\'ont déchiqueté. Il mourra à l\'aube sans votre potion !',
                          style: TextStyle(
                            fontSize: 11,
                            color: isHealed
                                ? const Color(0xFFD1FAE5)
                                : const Color(0xFFFECDD3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isHealed
                      ? const Color(0xFF064E3B)
                      : (hasHeal
                            ? const Color(0xFF10B981)
                            : Colors.grey.shade800),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: hasHeal ? 4 : 0,
                ),
                onPressed: (wolfVictim != null && hasHeal)
                    ? widget.onWitchSave
                    : null,
                icon: Icon(
                  isHealed ? Icons.check_circle_rounded : Icons.healing_rounded,
                  size: 18,
                ),
                label: Text(
                  isHealed
                      ? 'Victime ${wolfVictim?.name} sauvée par votre potion ✨'
                      : (witch.hasUsedHealPotion
                            ? 'Potion de vie déjà épuisée'
                            : 'Sauver ${wolfVictim?.name ?? "la victime"} (Potion de Guérison) 🧪'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 2. POTION DE POISON (MORT)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0x223B0764),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: LupusColors.arcanePurple.withValues(alpha: 0.4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'POTION DE MORT (POISON)',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: Color(0xFFC084FC),
                    ),
                  ),
                  Text(
                    witch.hasUsedPoisonPotion
                        ? 'Fiole épuisée'
                        : '1 fiole disponible',
                    style: const TextStyle(
                      fontSize: 10,
                      color: LupusColors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (poisonVictim != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: LupusColors.bloodRed.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: LupusColors.bloodRed),
                  ),
                  child: Text(
                    '☠️ Poison versé sur : ${poisonVictim.name} (Succombera à l\'aube)',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: LupusColors.bloodRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: hasPoison ? 3 : 0,
                ),
                onPressed:
                    (selectedTarget != null &&
                        selectedTarget.isAlive &&
                        hasPoison)
                    ? () => widget.onWitchPoison(selectedTarget.id)
                    : null,
                icon: const Icon(Icons.science_rounded, size: 18),
                label: Text(
                  poisonVictim != null
                      ? 'Changer la cible du poison ☠️'
                      : (witch.hasUsedPoisonPotion
                            ? 'Potion de mort déjà consommée'
                            : (selectedTarget != null
                                  ? 'Empoisonner ${selectedTarget.name} ☠️'
                                  : 'Sélectionnez un suspect sur la table')),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 3. CLÔTURE DE LA NUIT
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: LupusColors.arcanePurple,
            side: const BorderSide(color: LupusColors.arcanePurple),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 11),
          ),
          onPressed: widget.onWitchPass,
          icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
          label: const Text(
            'Valider mes potions & Clore la nuit de la Sorcière 🌙',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ),
      ],
    );
  }

  /// Module Salvateur : Protection Nocturne
  Widget _buildDefenderSection(PlayerModel? selectedTarget) {
    final lastProtected = widget.room.lastProtectedPlayerId != null
        ? widget.room.players[widget.room.lastProtectedPlayerId]
        : null;
    final currentProtected = widget.room.currentProtectedPlayerId != null
        ? widget.room.players[widget.room.currentProtectedPlayerId]
        : null;

    final isSameAsLast =
        selectedTarget?.id == widget.room.lastProtectedPlayerId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (currentProtected != null)
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF3A86FF).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF3A86FF).withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.verified_user_rounded,
                  color: Color(0xFF3A86FF),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Protection active sur ${currentProtected.name} cette nuit.',
                    style: const TextStyle(
                      color: Color(0xFF3A86FF),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3A86FF),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 4,
          ),
          onPressed:
              (selectedTarget != null &&
                  selectedTarget.isAlive &&
                  !isSameAsLast)
              ? () => widget.onDefenderProtect?.call(selectedTarget.id)
              : null,
          icon: const Icon(Icons.security_rounded),
          label: Text(
            isSameAsLast
                ? 'Interdit de protéger ${selectedTarget?.name} 2 nuits de suite'
                : (selectedTarget != null
                      ? 'Protéger ${selectedTarget.name} cette nuit 🛡️'
                      : 'Sélectionnez un habitant à protéger'),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
        ),
        if (lastProtected != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'ℹ️ Protégé la nuit précédente : ${lastProtected.name} (interdit cette nuit)',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: LupusColors.textMuted,
                fontSize: 11,
              ),
            ),
          ),
      ],
    );
  }

  /// Module Cupidon : Choix des Deux Amoureux
  Widget _buildCupidSection(PlayerModel? selectedTarget) {
    final lover1 = _cupidLover1Id != null
        ? widget.room.players[_cupidLover1Id]
        : null;
    final lover2 = _cupidLover2Id != null
        ? widget.room.players[_cupidLover2Id]
        : null;

    final canBind = lover1 != null && lover2 != null && lover1.id != lover2.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Affichage des deux emplacements d'amoureux
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: lover1 != null
                      ? const Color(0xFFFF70A6).withValues(alpha: 0.15)
                      : LupusColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: lover1 != null
                        ? const Color(0xFFFF70A6)
                        : LupusColors.border,
                  ),
                ),
                child: Column(
                  children: [
                    const Text(
                      'AMANT 1',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFFF70A6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lover1?.name ?? 'Non défini',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    if (selectedTarget != null &&
                        selectedTarget.id != _cupidLover2Id)
                      TextButton(
                        onPressed: () {
                          setState(() => _cupidLover1Id = selectedTarget.id);
                        },
                        child: const Text(
                          'Assigner cible',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: lover2 != null
                      ? const Color(0xFFFF70A6).withValues(alpha: 0.15)
                      : LupusColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: lover2 != null
                        ? const Color(0xFFFF70A6)
                        : LupusColors.border,
                  ),
                ),
                child: Column(
                  children: [
                    const Text(
                      'AMANT 2',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFFF70A6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lover2?.name ?? 'Non défini',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    if (selectedTarget != null &&
                        selectedTarget.id != _cupidLover1Id)
                      TextButton(
                        onPressed: () {
                          setState(() => _cupidLover2Id = selectedTarget.id);
                        },
                        child: const Text(
                          'Assigner cible',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Bouton de liaison définitive
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF70A6),
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: canBind ? 4 : 0,
          ),
          onPressed: canBind
              ? () => widget.onCupidBind?.call(lover1.id, lover2.id)
              : null,
          icon: const Icon(Icons.favorite_rounded),
          label: Text(
            canBind
                ? 'Lier pour la vie ${lover1.name} & ${lover2.name} 💘'
                : 'Sélectionnez deux amants sur la table',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5),
          ),
        ),
        if (widget.room.playerList.any((p) => p.isLover)) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFFF70A6),
              side: const BorderSide(color: Color(0xFFFF70A6)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: widget.onNextPhase,
            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
            label: const Text(
              'Valider et passer au tour suivant 🌙',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
            ),
          ),
        ],
      ],
    );
  }

  /// Module Pyromane : Asperger d'essence ou allumer le brasier
  Widget _buildPyromaniacSection(PlayerModel? selectedTarget) {
    final dousedPlayers =
        widget.room.alivePlayers.where((p) => p.isDoused).toList();
    final isTargetDoused = selectedTarget?.isDoused == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // État des demeures aspergées
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0x33FF4800),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFFFF4800).withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'MAISONS IMBIBÉES D\'ESSENCE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: Color(0xFFFF8C00),
                    ),
                  ),
                  Text(
                    '${dousedPlayers.length} cible(s)',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (dousedPlayers.isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: dousedPlayers.map((p) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF4800).withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFFF4800),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        '🛢️ ${p.name}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    );
                  }).toList(),
                )
              else
                const Text(
                  'Aucune maison aspergée. Choisissez un habitant à imbiber de carburant.',
                  style: TextStyle(fontSize: 11, color: LupusColors.textMuted),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Action 1 : Asperger la cible
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF97316),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
          ),
          onPressed: (selectedTarget != null &&
                  selectedTarget.isAlive &&
                  !isTargetDoused)
              ? () => widget.onPyromaniacDouse?.call(selectedTarget.id)
              : null,
          icon: const Icon(Icons.water_drop_rounded, size: 18),
          label: Text(
            isTargetDoused
                ? '${selectedTarget?.name} est déjà imbibé(e) d\'essence'
                : (selectedTarget != null
                    ? 'Asperger ${selectedTarget.name} d\'essence 🛢️'
                    : 'Sélectionnez un habitant à asperger'),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
          ),
        ),
        const SizedBox(height: 8),

        // Action 2 : Allumer le Brasier
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
            elevation: dousedPlayers.isNotEmpty ? 4 : 0,
          ),
          onPressed: dousedPlayers.isNotEmpty
              ? () => widget.onPyromaniacIgnite?.call()
              : null,
          icon: const Icon(Icons.local_fire_department_rounded, size: 18),
          label: Text(
            dousedPlayers.isNotEmpty
                ? 'METTRE LE FEU AU BRASIER (${dousedPlayers.length} cibles) 🔥'
                : 'Mettre le feu (requiert au moins 1 maison aspergée)',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5),
          ),
        ),
        const SizedBox(height: 8),

        // Action 3 : Passer au tour suivant
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFFF8C00),
            side: const BorderSide(color: Color(0xFFFF8C00)),
            padding: const EdgeInsets.symmetric(vertical: 11),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: widget.onPyromaniacPass ?? widget.onNextPhase,
          icon: const Icon(Icons.arrow_forward_rounded, size: 16),
          label: const Text(
            'Valider et passer au tour suivant 🌙',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
          ),
        ),
      ],
    );
  }

  /// Module Voyante : Vision Divinatoire
  Widget _buildSeerSection(PlayerModel? selectedTarget) {
    if (widget.inspectedRole != null) {
      final role = widget.inspectedRole!;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: role.accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: role.accentColor, width: 1.5),
            ),
            child: Row(
              children: [
                Icon(role.icon, color: role.accentColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RÉVÉLATION : ${selectedTarget?.name ?? "Cible"}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: role.accentColor,
                        ),
                      ),
                      Text(
                        role.displayNameFr,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        role.descriptionFr,
                        style: const TextStyle(
                          fontSize: 11,
                          color: LupusColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: LupusColors.arcanePurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: widget.onCompleteSeerTurn,
            icon: const Icon(Icons.check_circle_outline_rounded),
            label: const Text(
              'Consigner ma vision & Me rendormir 🌙',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      );
    }

    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: LupusColors.arcanePurple,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed:
          (selectedTarget != null &&
              selectedTarget.isAlive &&
              selectedTarget.id != widget.currentUserId)
          ? () => widget.onInspect(selectedTarget.id)
          : null,
      icon: const Icon(Icons.visibility_rounded),
      label: Text(
        selectedTarget != null
            ? 'Sonder l\'âme de ${selectedTarget.name} 🔮'
            : 'Sélectionnez qui scruter sur la table',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }

  /// Module Voleur : Larcin Nocturne
  Widget _buildThiefSection(PlayerModel? selectedTarget) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8338EC),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed:
              (selectedTarget != null &&
                  selectedTarget.isAlive &&
                  selectedTarget.id != widget.currentUserId)
              ? () => widget.onThiefSteal?.call(selectedTarget.id)
              : null,
          icon: const Icon(Icons.pan_tool_rounded),
          label: Text(
            selectedTarget != null
                ? 'Dérober l\'identité de ${selectedTarget.name} 🎭'
                : 'Sélectionnez une victime à détrousser',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: LupusColors.textSecondary,
            side: const BorderSide(color: LupusColors.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: widget.onNextPhase,
          child: const Text('Garder le rôle de Voleur (Passer)'),
        ),
      ],
    );
  }

  /// Module Loups-Garous : Vote de la Proie & Conseil de la Meute
  Widget _buildWerewolvesSection(PlayerModel me, PlayerModel? selectedTarget) {
    final livingWolves = widget.room.alivePlayers
        .where((p) => p.role.isEvil)
        .toList();
    final isUserWolf = me.role.isEvil;
    final currentVoteTargetId = me.targetVoteId;
    final currentVoteTarget = currentVoteTargetId != null
        ? widget.room.players[currentVoteTargetId]
        : null;

    final consensusVictimId = widget.room.nightVictimId;
    final consensusVictim = consensusVictimId != null
        ? widget.room.players[consensusVictimId]
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Badge Mode God si l'utilisateur est un observateur divin non-loup
        if (widget.isAdmin && !isUserWolf) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: LupusColors.arcaneCrimson.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: LupusColors.arcaneCrimson.withValues(alpha: 0.7),
                width: 1,
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.visibility_rounded,
                  size: 14,
                  color: LupusColors.arcaneCrimson,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'OBSERVATION DIVINE (MODE GOD) : CONSEIL DES LOUPS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      color: Color(0xFFFECDD3),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Liste des membres vivants de la meute
        Container(
          padding: const EdgeInsets.all(10),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: const Color(0x331C0808),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: LupusColors.arcaneCrimson.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'MEUTE NOCTURNE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: LupusColors.arcaneCrimson,
                    ),
                  ),
                  Text(
                    '${livingWolves.length} loup(s) en chasse',
                    style: const TextStyle(
                      fontSize: 10,
                      color: LupusColors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: livingWolves.map((w) {
                  final target = w.targetVoteId != null
                      ? widget.room.players[w.targetVoteId]
                      : null;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: LupusColors.surfaceLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: w.id == widget.currentUserId
                            ? LupusColors.arcaneCrimson
                            : LupusColors.border,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🐺', style: TextStyle(fontSize: 11)),
                        const SizedBox(width: 4),
                        Text(
                          w.name,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: w.id == widget.currentUserId
                                ? Colors.white
                                : LupusColors.textSecondary,
                          ),
                        ),
                        if (target != null) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_forward,
                            size: 9,
                            color: LupusColors.arcaneCrimson,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            target.name,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: LupusColors.arcaneCrimson,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),

        // Statut du consensus / Proie désignée
        if (consensusVictim != null) ...[
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: LupusColors.bloodRed.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: LupusColors.bloodRed.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.pets_rounded,
                  color: LupusColors.bloodRed,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Proie désignée par la meute : ${consensusVictim.name}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Bouton de vote / désignation de la proie
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: LupusColors.bloodRed,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 4,
          ),
          onPressed:
              (selectedTarget != null &&
                  selectedTarget.isAlive &&
                  !selectedTarget.role.isEvil)
              ? () => widget.onVote(selectedTarget.id)
              : null,
          icon: const Icon(Icons.pets_rounded),
          label: Text(
            selectedTarget != null
                ? (selectedTarget.id == currentVoteTargetId
                      ? 'Proie ciblée : ${selectedTarget.name} 🩸 (Re-voter)'
                      : 'Désigner ${selectedTarget.name} comme proie 🩸')
                : (currentVoteTarget != null
                      ? 'Proie choisie : ${currentVoteTarget.name} (touchez pour changer)'
                      : 'Sélectionnez un innocent sur la table'),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
          ),
        ),

        // Bouton de validation rapide pour clore la nuit des loups et réveiller la sorcière
        const SizedBox(height: 8),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: LupusColors.arcaneCrimson,
            side: BorderSide(
              color: LupusColors.arcaneCrimson.withValues(alpha: 0.6),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 10),
          ),
          onPressed: widget.onNextPhase,
          icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
          label: const Text(
            'Valider la proie des Loups & Passer à la Sorcière 🌙',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5),
          ),
        ),
      ],
    );
  }

  /// Module Chasseur au dernier souffle
  Widget _buildHunterSection(PlayerModel? selectedTarget) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: LupusColors.sunAmber,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed:
          (selectedTarget != null &&
              selectedTarget.isAlive &&
              selectedTarget.id != widget.currentUserId)
          ? () => widget.onHunterShoot?.call(selectedTarget.id)
          : null,
      icon: const Icon(Icons.crisis_alert_rounded),
      label: Text(
        selectedTarget != null
            ? 'Abattre ${selectedTarget.name} dans un dernier souffle 💥'
            : 'Sélectionnez qui abattre',
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }

  /// Module Capitaine (Succession)
  Widget _buildCaptainSuccessionSection(PlayerModel? selectedTarget) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: LupusColors.sunAmber,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed:
          (selectedTarget != null &&
              selectedTarget.isAlive &&
              selectedTarget.id != widget.currentUserId)
          ? () => widget.onCaptainPass?.call(selectedTarget.id)
          : null,
      icon: const Icon(Icons.military_tech_rounded),
      label: Text(
        selectedTarget != null
            ? 'Nommer ${selectedTarget.name} nouveau Capitaine 🎖️'
            : 'Désignez votre successeur parmi les vivants',
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }

  /// Module Élection du Capitaine
  Widget _buildCaptainElectionSection(PlayerModel? selectedTarget) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: LupusColors.sunAmber,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: (selectedTarget != null && selectedTarget.isAlive)
          ? () => widget.onVote(selectedTarget.id)
          : null,
      icon: const Icon(Icons.military_tech_rounded),
      label: Text(
        selectedTarget != null
            ? 'Voter pour élire ${selectedTarget.name} Capitaine 🎖️'
            : 'Sélectionnez votre candidat Capitaine',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }

  /// Module Débat tour par tour
  Widget _buildDebateSection() {
    final isSpeaker = widget.room.currentSpeakerId == widget.currentUserId;
    if (isSpeaker) {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: LupusColors.voiceActive,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: widget.onPassDebate,
        icon: const Icon(Icons.record_voice_over_rounded),
        label: const Text(
          'Vous avez la parole ! (Cliquer pour passer) 🎙️',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      );
    }

    final speaker = widget.room.players[widget.room.currentSpeakerId];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      alignment: Alignment.center,
      child: Text(
        '🎙️ Écoutez attentivement : ${speaker?.name ?? "un citoyen"} s\'exprime.',
        style: const TextStyle(
          color: LupusColors.voiceActive,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  /// Module Scrutin du Bûcher
  Widget _buildVotingSection(PlayerModel me, PlayerModel? selectedTarget) {
    final isTieBreak = widget.room.phase == GamePhase.dayTieBreakVote;
    final isEligible =
        !isTieBreak || widget.room.tiedPlayerIds.contains(selectedTarget?.id);
    final hasVotedForThis =
        me.targetVoteId != null && me.targetVoteId == selectedTarget?.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (me.isCaptain) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: LupusColors.arcaneGold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: LupusColors.arcaneGold.withValues(alpha: 0.6),
              ),
            ),
            child: const Row(
              children: [
                Text('⭐', style: TextStyle(fontSize: 16)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'POUVOIR DU MAIRE : Votre vote compte DOUBLE (2 voix) et tranchera toute égalité au scrutin.',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: LupusColors.arcaneGold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: me.isCaptain
                ? (hasVotedForThis
                    ? const Color(0xFFB45309)
                    : LupusColors.bloodRed)
                : LupusColors.bloodRed,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: me.isCaptain
                  ? const BorderSide(color: LupusColors.arcaneGold, width: 1.5)
                  : BorderSide.none,
            ),
            elevation: me.isCaptain ? 6 : 2,
          ),
          onPressed:
              (selectedTarget != null &&
                  selectedTarget.isAlive &&
                  selectedTarget.id != widget.currentUserId &&
                  isEligible)
              ? () => widget.onVote(selectedTarget.id)
              : null,
          icon: Icon(
            me.isCaptain ? Icons.star_rounded : Icons.how_to_vote_rounded,
            color: me.isCaptain ? LupusColors.arcaneGold : Colors.white,
          ),
          label: Text(
            selectedTarget != null
                ? (hasVotedForThis
                    ? 'Vote du Maire confirmé sur ${selectedTarget.name} ⭐ (2 voix)'
                    : (me.isCaptain
                        ? 'VOTER EN TANT QUE MAIRE POUR ${selectedTarget.name.toUpperCase()} (2 VOIX ⭐)'
                        : 'Condamner ${selectedTarget.name} au bûcher 🔥'))
                : (isTieBreak
                      ? 'Votez uniquement pour un accusé ex æquo'
                      : (me.isCaptain
                          ? 'Sélectionnez un suspect (Votre vote de Maire vaut 2 voix ⭐)'
                          : 'Sélectionnez un suspect à envoyer au bûcher')),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}
