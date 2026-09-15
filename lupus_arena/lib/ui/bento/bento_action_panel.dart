import 'package:flutter/material.dart';
import '../../models/game_phase.dart';
import '../../models/game_role.dart';
import '../../models/game_room.dart';
import '../../models/player_model.dart';
import '../../services/app_translations.dart';
import '../theme/lupus_theme.dart';
import 'bento_card.dart';

/// Panneau d'actions Bento contextuel compact pour chaque rôle.
/// Format compact sans overflow, sans narrations superflues,
/// avec boutons d'actions directs et brefs.
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
  final ValueChanged<String>? onBlackWolfSilence;
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
    this.onBlackWolfSilence,
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
  void didUpdateWidget(covariant BentoActionPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Nettoyage impératif des sous-états lors des transitions de phase ou de round
    if (oldWidget.room.phase != widget.room.phase ||
        oldWidget.room.round != widget.room.round) {
      _cupidLover1Id = null;
      _cupidLover2Id = null;
    }
  }

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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      borderColor: LupusColors.borderGlow,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // En-tête compact avec badge de la cible sélectionnée
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.tr('strategic_actions'),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: isAlive ? LupusColors.textSecondary : LupusColors.textMuted,
                ),
              ),
              if (selectedTarget != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: LupusColors.surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: LupusColors.arcaneGold.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.gps_fixed_rounded,
                          size: 11, color: LupusColors.arcaneGold),
                      const SizedBox(width: 4),
                      Text(
                        '${context.tr("target")} : ${selectedTarget.name}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: LupusColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),

          // Zone d'action scrollable si nécessaire pour les petits écrans
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. CHASSEUR AU DERNIER SOUFFLE
                if (phase == GamePhase.hunterDeathChoice &&
                    (widget.room.pendingHunterId == widget.currentUserId || widget.isAdmin)) ...[
                  _buildHunterSection(selectedTarget),
                ]
                // 2. CAPITAINE DÉFUNT QUI TRANSMET SON ÉCHARPE
                else if (phase == GamePhase.captainSuccession &&
                    (widget.room.pendingCaptainId == widget.currentUserId || widget.isAdmin)) ...[
                  _buildCaptainSuccessionSection(selectedTarget),
                ]
                // 3. JOUEUR ÉLIMINÉ SANS ACTION PARTICULIÈRE
                else if (!isAlive && !widget.isAdmin) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: LupusColors.textMuted.withValues(alpha: 0.2)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      context.tr('eliminated_spectator_msg'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: LupusColors.textMuted, fontSize: 11),
                    ),
                  ),
                ]
                // 4. VOLEUR (NUIT 1)
                else if (phase == GamePhase.nightThief && (role == GameRole.thief || widget.isAdmin)) ...[
                  _buildThiefSection(selectedTarget),
                ]
                // 5. CUPIDON (NUIT 1)
                else if (phase == GamePhase.nightCupid && (role == GameRole.cupid || widget.isAdmin)) ...[
                  _buildCupidSection(selectedTarget),
                ]
                // 6. VOYANTE
                else if (phase == GamePhase.nightSeer && (role == GameRole.seer || widget.isAdmin)) ...[
                  _buildSeerSection(selectedTarget),
                ]
                // 7. SALVATEUR
                else if (phase == GamePhase.nightDefender && (role == GameRole.defender || widget.isAdmin)) ...[
                  _buildDefenderSection(selectedTarget),
                ]
                // 8. LOUPS-GAROUS
                else if (phase == GamePhase.nightWerewolves && (role.isEvil || widget.isAdmin)) ...[
                  _buildWerewolvesSection(me, selectedTarget),
                ]
                // 8.B LOUP NOIR
                else if (phase == GamePhase.nightBlackWolf &&
                    (role == GameRole.blackWolf || widget.isAdmin)) ...[
                  _buildBlackWolfSection(selectedTarget),
                ]
                // 9. SORCIÈRE
                else if (phase == GamePhase.nightWitch && (role == GameRole.witch || widget.isAdmin)) ...[
                  _buildWitchSection(
                    widget.room.playerList.firstWhere(
                      (p) => p.role == GameRole.witch,
                      orElse: () => me,
                    ),
                    selectedTarget,
                  ),
                ]
                // 9.B PYROMANE
                else if (phase == GamePhase.nightPyromaniac &&
                    (role == GameRole.pyromaniac || widget.isAdmin)) ...[
                  _buildPyromaniacSection(selectedTarget),
                ]
                // 10. ÉLECTION DU CAPITAINE
                else if (phase == GamePhase.captainElection) ...[
                  _buildCaptainElectionSection(selectedTarget),
                ]
                // 11. DÉBAT TOUR PAR TOUR
                else if (phase == GamePhase.dayDebate) ...[
                  _buildDebateSection(),
                ]
                // 12. SCRUTIN DU BÛCHER & SECOND VOTE
                else if (phase == GamePhase.dayVoting || phase == GamePhase.dayTieBreakVote) ...[
                  _buildVotingSection(me, selectedTarget),
                ]
                // PAR DÉFAUT : AUCUNE ACTION REQUISE
                else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      phase.isNight
                          ? context.tr('night_in_progress_msg')
                          : context.tr('silence_votes_closed_msg'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: LupusColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // --- MODULES DE RÔLES COMPACTS SANS OVERFLOW ---
  // ==========================================

  /// Module Sorcière : Boutons côte à côte [Sauver (Nom)] et [Empoisonner (Nom)] avec un bouton [Valider]
  Widget _buildWitchSection(PlayerModel witch, PlayerModel? selectedTarget) {
    final wolfVictimId = widget.room.nightVictimId;
    final wolfVictim = wolfVictimId != null ? widget.room.players[wolfVictimId] : null;
    final hasHeal = !witch.hasUsedHealPotion || widget.isAdmin;
    final hasPoison = !witch.hasUsedPoisonPotion || widget.isAdmin;
    final isHealed = widget.room.witchHealed;
    final poisonVictimId = widget.room.witchPoisonVictimId;
    final poisonVictim = poisonVictimId != null ? widget.room.players[poisonVictimId] : null;

    final String saveLabel;
    if (isHealed) {
      saveLabel = context.tr('healed_badge');
    } else if (!hasHeal) {
      saveLabel = context.tr('heal_exhausted');
    } else if (wolfVictim != null) {
      saveLabel = context.tr('save_target', {'name': wolfVictim.name});
    } else {
      saveLabel = context.tr('save_victim_btn');
    }

    final String poisonLabel;
    if (poisonVictim != null) {
      poisonLabel = context.tr('poisoned_target', {'name': poisonVictim.name});
    } else if (!hasPoison) {
      poisonLabel = context.tr('poison_exhausted');
    } else if (selectedTarget != null) {
      poisonLabel = context.tr('poison_target', {'name': selectedTarget.name});
    } else {
      poisonLabel = context.tr('poison_target_btn');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            // Bouton Sauver (Nom)
            Expanded(
              child: SizedBox(
                height: 40,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isHealed
                        ? const Color(0xFF064E3B)
                        : (hasHeal ? const Color(0xFF10B981) : LupusColors.surfaceLight),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: (wolfVictim != null && hasHeal && !isHealed) ? widget.onWitchSave : null,
                  icon: Icon(isHealed ? Icons.check_circle_rounded : Icons.healing_rounded, size: 14),
                  label: Text(
                    saveLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Bouton Empoisonner (Nom)
            Expanded(
              child: SizedBox(
                height: 40,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasPoison ? LupusColors.bloodRed : LupusColors.surfaceLight,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: (selectedTarget != null && selectedTarget.isAlive && hasPoison && poisonVictimId == null)
                      ? () => widget.onWitchPoison(selectedTarget.id)
                      : null,
                  icon: const Icon(Icons.science_rounded, size: 14),
                  label: Text(
                    poisonLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Bouton [Valider]
        SizedBox(
          height: 38,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: LupusColors.arcanePurple,
              side: const BorderSide(color: LupusColors.arcanePurple, width: 1.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: widget.onWitchPass,
            icon: const Icon(Icons.check_circle_outline_rounded, size: 15),
            label: Text(
              context.tr('validate'),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }

  /// Module Loups-Garous : [Dévorer (Nom)] + [Valider]
  Widget _buildWerewolvesSection(PlayerModel me, PlayerModel? selectedTarget) {
    final currentVoteTargetId = me.targetVoteId;
    final currentVoteTarget = currentVoteTargetId != null
        ? widget.room.players[currentVoteTargetId]
        : null;

    final String devourLabel;
    if (selectedTarget != null) {
      devourLabel = context.tr('devour_target', {'name': selectedTarget.name});
    } else if (currentVoteTarget != null) {
      devourLabel = context.tr('prey_target', {'name': currentVoteTarget.name});
    } else {
      devourLabel = context.tr('devour_select');
    }

    return Row(
      children: [
        // Bouton Dévorer (Nom)
        Expanded(
          child: SizedBox(
            height: 40,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: LupusColors.bloodRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: (selectedTarget != null &&
                      selectedTarget.isAlive &&
                      !selectedTarget.role.isEvil)
                  ? () => widget.onVote(selectedTarget.id)
                  : null,
              icon: const Icon(Icons.pets_rounded, size: 15),
              label: Text(
                devourLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Bouton [Valider]
        SizedBox(
          height: 40,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0x992B1010),
              foregroundColor: const Color(0xFFFECDD3),
              side: BorderSide(color: LupusColors.arcaneCrimson.withValues(alpha: 0.6)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: widget.onNextPhase,
            icon: const Icon(Icons.check_rounded, size: 15),
            label: Text(
              context.tr('validate'),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }

  /// Module Voyante : [Sonder (Nom)] + [Valider]
  Widget _buildSeerSection(PlayerModel? selectedTarget) {
    if (widget.inspectedRole != null) {
      final role = widget.inspectedRole!;
      return Row(
        children: [
          Expanded(
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: role.accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: role.accentColor, width: 1.2),
              ),
              child: Row(
                children: [
                  Icon(role.icon, color: role.accentColor, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${selectedTarget?.name ?? context.tr("target")} : ${role.displayName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 40,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: LupusColors.arcanePurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: widget.onCompleteSeerTurn,
              icon: const Icon(Icons.check_rounded, size: 15),
              label: Text(context.tr('validate'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
            ),
          ),
        ],
      );
    }

    final String inspectLabel;
    if (selectedTarget != null) {
      inspectLabel = context.tr('inspect_target', {'name': selectedTarget.name});
    } else {
      inspectLabel = context.tr('inspect_select');
    }

    return Row(
      children: [
        // Bouton Sonder (Nom)
        Expanded(
          child: SizedBox(
            height: 40,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: LupusColors.arcanePurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: (selectedTarget != null &&
                      selectedTarget.isAlive &&
                      selectedTarget.id != widget.currentUserId)
                  ? () => widget.onInspect(selectedTarget.id)
                  : null,
              icon: const Icon(Icons.visibility_rounded, size: 15),
              label: Text(
                inspectLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Bouton Valider
        SizedBox(
          height: 40,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: LupusColors.arcanePurple,
              side: const BorderSide(color: LupusColors.arcanePurple),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: widget.onCompleteSeerTurn,
            icon: const Icon(Icons.check_rounded, size: 15),
            label: Text(context.tr('validate'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
          ),
        ),
      ],
    );
  }

  /// Module Salvateur : Bouton direct [Protéger (Nom)] sans affichage "null"
  Widget _buildDefenderSection(PlayerModel? selectedTarget) {
    final lastProtectedId = widget.room.lastProtectedPlayerId;
    final lastProtected = (lastProtectedId != null && lastProtectedId.isNotEmpty)
        ? widget.room.players[lastProtectedId]
        : null;

    // Comparaison stricte : non-null et correspondance des IDs
    final isSameAsLast = selectedTarget != null &&
        lastProtectedId != null &&
        selectedTarget.id == lastProtectedId;

    final String buttonText;
    if (selectedTarget == null) {
      buttonText = context.tr('protect_select');
    } else if (isSameAsLast) {
      buttonText = context.tr('protect_forbidden', {'name': selectedTarget.name});
    } else {
      buttonText = context.tr('protect_target', {'name': selectedTarget.name});
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 40,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3A86FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: (selectedTarget != null && selectedTarget.isAlive && !isSameAsLast)
                      ? () => widget.onDefenderProtect?.call(selectedTarget.id)
                      : null,
                  icon: const Icon(Icons.security_rounded, size: 15),
                  label: Text(
                    buttonText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 40,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: LupusColors.textSecondary,
                  side: const BorderSide(color: LupusColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: widget.onNextPhase,
                child: Text(context.tr('pass'), style: const TextStyle(fontSize: 11)),
              ),
            ),
          ],
        ),
        if (lastProtected != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              context.tr('last_protected_info', {'name': lastProtected.name}),
              textAlign: TextAlign.center,
              style: const TextStyle(color: LupusColors.textMuted, fontSize: 10),
            ),
          ),
      ],
    );
  }

  /// Module Loup Noir : Réduire au silence un joueur vivant pour la journée suivante
  Widget _buildBlackWolfSection(PlayerModel? selectedTarget) {
    final currentTargetId = widget.room.blackWolfTargetId;
    final currentTarget = (currentTargetId != null && currentTargetId.isNotEmpty)
        ? widget.room.players[currentTargetId]
        : null;

    final String buttonText;
    if (currentTarget != null) {
      buttonText = '${context.tr("target_with_name", {"name": currentTarget.name})} 🔇';
    } else if (selectedTarget == null) {
      buttonText = context.tr('silence_select');
    } else {
      buttonText = context.tr('silence_target', {'name': selectedTarget.name});
    }

    final bool canSilence = selectedTarget != null &&
        selectedTarget.isAlive &&
        selectedTarget.id != widget.currentUserId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 40,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF311042),
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF9333EA), width: 1.2),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: canSilence
                      ? () => widget.onBlackWolfSilence?.call(selectedTarget.id)
                      : null,
                  icon: const Icon(Icons.volume_off_rounded, size: 15, color: Color(0xFFC084FC)),
                  label: Text(
                    buttonText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 40,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: LupusColors.textSecondary,
                  side: const BorderSide(color: LupusColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: widget.onNextPhase,
                child: Text(context.tr('pass'), style: const TextStyle(fontSize: 11)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Module Chasseur au dernier souffle : Bouton direct [Tirer sur (Nom)]
  Widget _buildHunterSection(PlayerModel? selectedTarget) {
    return SizedBox(
      height: 40,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: LupusColors.sunAmber,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: (selectedTarget != null &&
                selectedTarget.isAlive &&
                selectedTarget.id != widget.currentUserId)
            ? () => widget.onHunterShoot?.call(selectedTarget.id)
            : null,
        icon: const Icon(Icons.crisis_alert_rounded, size: 15),
        label: Text(
          selectedTarget != null
              ? context.tr('shoot_target', {'name': selectedTarget.name})
              : context.tr('shoot_select'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
        ),
      ),
    );
  }

  /// Module Scrutin du Bûcher : Bouton direct [Voter contre (Nom)]
  Widget _buildVotingSection(PlayerModel me, PlayerModel? selectedTarget) {
    final isTieBreak = widget.room.phase == GamePhase.dayTieBreakVote;
    final isEligible = !isTieBreak || widget.room.tiedPlayerIds.contains(selectedTarget?.id);
    final currentVoteTargetId = me.targetVoteId;

    final String voteText;
    if (selectedTarget != null) {
      voteText = '${context.tr("vote_against_target", {"name": selectedTarget.name})}${me.isCaptain ? " (x2)" : ""}';
    } else {
      voteText = isTieBreak ? context.tr('vote_tie_break') : context.tr('vote_select');
    }

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 40,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: LupusColors.bloodRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: (selectedTarget != null &&
                      selectedTarget.isAlive &&
                      selectedTarget.id != widget.currentUserId &&
                      isEligible)
                  ? () => widget.onVote(selectedTarget.id)
                  : null,
              icon: const Icon(Icons.how_to_vote_rounded, size: 15),
              label: Text(
                voteText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
              ),
            ),
          ),
        ),
        if (currentVoteTargetId != null) ...[
          const SizedBox(width: 8),
          SizedBox(
            height: 40,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: LupusColors.textMuted,
                side: const BorderSide(color: LupusColors.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => widget.onVote(null),
              child: Text(context.tr('cancel'), style: const TextStyle(fontSize: 11)),
            ),
          ),
        ],
      ],
    );
  }

  /// Module Capitaine (Succession) : Bouton direct [Nommer (Nom)]
  Widget _buildCaptainSuccessionSection(PlayerModel? selectedTarget) {
    return SizedBox(
      height: 40,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: LupusColors.sunAmber,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: (selectedTarget != null &&
                selectedTarget.isAlive &&
                selectedTarget.id != widget.currentUserId)
            ? () => widget.onCaptainPass?.call(selectedTarget.id)
            : null,
        icon: const Icon(Icons.military_tech_rounded, size: 15),
        label: Text(
          selectedTarget != null
              ? context.tr('name_captain_target', {'name': selectedTarget.name})
              : context.tr('name_captain_select'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
        ),
      ),
    );
  }

  /// Module Élection du Capitaine
  Widget _buildCaptainElectionSection(PlayerModel? selectedTarget) {
    return SizedBox(
      height: 40,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: LupusColors.sunAmber,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: (selectedTarget != null && selectedTarget.isAlive)
            ? () => widget.onVote(selectedTarget.id)
            : null,
        icon: const Icon(Icons.military_tech_rounded, size: 15),
        label: Text(
          selectedTarget != null
              ? context.tr('elect_captain_target', {'name': selectedTarget.name})
              : context.tr('elect_captain_select'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
        ),
      ),
    );
  }

  /// Module Débat tour par tour
  Widget _buildDebateSection() {
    final isSpeaker = widget.room.currentSpeakerId == widget.currentUserId;
    if (isSpeaker) {
      return SizedBox(
        height: 40,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00FFCC),
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: widget.onPassDebate,
          icon: const Text('🎙️', style: TextStyle(fontSize: 16)),
          label: Text(
            context.tr('pass_speaking_turn'),
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: Colors.black,
              fontSize: 13,
            ),
          ),
        ),
      );
    }

    final speaker = widget.room.players[widget.room.currentSpeakerId];
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: LupusColors.border.withValues(alpha: 0.5)),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.record_voice_over_rounded, color: Color(0xFF00FFCC), size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              context.tr('listen_speaker', {'name': speaker?.name ?? context.tr('speaker')}),
              style: const TextStyle(
                color: Color(0xFF00FFCC),
                fontWeight: FontWeight.w700,
                fontSize: 11.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Module Voleur (Nuit 1)
  Widget _buildThiefSection(PlayerModel? selectedTarget) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 40,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8338EC),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: (selectedTarget != null &&
                      selectedTarget.isAlive &&
                      selectedTarget.id != widget.currentUserId)
                  ? () => widget.onThiefSteal?.call(selectedTarget.id)
                  : null,
              icon: const Icon(Icons.swap_horiz_rounded, size: 15),
              label: Text(
                selectedTarget != null
                    ? context.tr('steal_target', {'name': selectedTarget.name})
                    : context.tr('steal_select'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 40,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: LupusColors.textSecondary,
              side: const BorderSide(color: LupusColors.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: widget.onNextPhase,
            child: Text(context.tr('pass'), style: const TextStyle(fontSize: 11)),
          ),
        ),
      ],
    );
  }

  /// Module Cupidon (Nuit 1)
  Widget _buildCupidSection(PlayerModel? selectedTarget) {
    final lover1 = _cupidLover1Id != null ? widget.room.players[_cupidLover1Id] : null;
    final lover2 = _cupidLover2Id != null ? widget.room.players[_cupidLover2Id] : null;
    final canBind = lover1 != null && lover2 != null && lover1.id != lover2.id;

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              if (selectedTarget != null &&
                  selectedTarget.isAlive &&
                  selectedTarget.id != _cupidLover2Id) {
                setState(() => _cupidLover1Id = selectedTarget.id);
              }
            },
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: lover1 != null
                    ? const Color(0xFFFF70A6).withValues(alpha: 0.15)
                    : LupusColors.surfaceLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: lover1 != null ? const Color(0xFFFF70A6) : LupusColors.border,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                lover1 != null ? '❤️ ${lover1.name}' : context.tr('add_lover_1'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: GestureDetector(
            onTap: () {
              if (selectedTarget != null &&
                  selectedTarget.isAlive &&
                  selectedTarget.id != _cupidLover1Id) {
                setState(() => _cupidLover2Id = selectedTarget.id);
              }
            },
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: lover2 != null
                    ? const Color(0xFFFF70A6).withValues(alpha: 0.15)
                    : LupusColors.surfaceLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: lover2 != null ? const Color(0xFFFF70A6) : LupusColors.border,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                lover2 != null ? '❤️ ${lover2.name}' : context.tr('add_lover_2'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          height: 40,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF70A6),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: canBind ? () => widget.onCupidBind?.call(lover1.id, lover2.id) : null,
            child: Text(context.tr('bind_lovers_btn'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5)),
          ),
        ),
      ],
    );
  }

  /// Module Pyromane : Asperger d'huile ou brûler
  Widget _buildPyromaniacSection(PlayerModel? selectedTarget) {
    final dousedPlayers = widget.room.alivePlayers.where((p) => p.isDoused).toList();
    final isTargetDoused = selectedTarget?.isDoused == true;

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 40,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF4800),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: (selectedTarget != null && selectedTarget.isAlive && !isTargetDoused)
                  ? () => widget.onPyromaniacDouse?.call(selectedTarget.id)
                  : null,
              icon: const Icon(Icons.water_drop_rounded, size: 14),
              label: Text(
                selectedTarget != null
                    ? (isTargetDoused ? context.tr('doused_target', {'name': selectedTarget.name}) : context.tr('douse_target', {'name': selectedTarget.name}))
                    : context.tr('douse_select'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          height: 40,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: dousedPlayers.isNotEmpty ? widget.onPyromaniacIgnite : null,
            icon: const Icon(Icons.local_fire_department_rounded, size: 15),
            label: Text(
              context.tr('ignite_count', {'count': '${dousedPlayers.length}'}),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5),
            ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          height: 40,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: LupusColors.textMuted,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: widget.onPyromaniacPass,
            child: Text(context.tr('pass'), style: const TextStyle(fontSize: 11)),
          ),
        ),
      ],
    );
  }
}
