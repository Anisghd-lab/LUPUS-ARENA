import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../models/game_phase.dart';
import '../../models/game_room.dart';
import '../../models/player_model.dart';
import '../../services/app_translations.dart';
import '../theme/lupus_theme.dart';
import 'bento_card.dart';
import 'bento_player_tile.dart';

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
  final ValueChanged<GameRole>? onThiefChooseRole;
  final ValueChanged<List<String>>? onPiperCharm;
  final ValueChanged<String>? onInfect;
  final VoidCallback? onExecuteBotNightAction;
  final ValueChanged<String>? onHunterShoot;
  final ValueChanged<String>? onCaptainPass;
  final ValueChanged<String>? onPyromaniacDouse;
  final VoidCallback? onPyromaniacIgnite;
  final VoidCallback? onPyromaniacPass;
  final bool isAdmin;
  final VoidCallback? onPassDebate;
  final ValueListenable<int>? countdownListenable;
  final ValueChanged<String>? onSelectTarget;

  // Paramètres injectables pour les tests et la modularité
  final bool? isCaptain;
  final bool? isAlive;
  final GamePhase? phase;
  final int? timerSeconds;
  final List<dynamic>? survivors;
  final ValueChanged<String>? onSuccessorSelected;

  BentoActionPanel({
    super.key,
    GameRoom? room,
    String? currentUserId,
    this.selectedTargetId,
    this.inspectedRole,
    this.isHost = false,
    this.isAdmin = false,
    VoidCallback? onNextPhase,
    ValueChanged<String?>? onVote,
    ValueChanged<String>? onInspect,
    VoidCallback? onCompleteSeerTurn,
    VoidCallback? onWitchSave,
    ValueChanged<String>? onWitchPoison,
    VoidCallback? onWitchPass,
    this.onDefenderProtect,
    this.onBlackWolfSilence,
    this.onCupidBind,
    this.onThiefSteal,
    this.onThiefChooseRole,
    this.onPiperCharm,
    this.onInfect,
    this.onExecuteBotNightAction,
    this.onHunterShoot,
    this.onCaptainPass,
    this.onPyromaniacDouse,
    this.onPyromaniacIgnite,
    this.onPyromaniacPass,
    this.onPassDebate,
    this.countdownListenable,
    this.onSelectTarget,
    this.isCaptain,
    this.isAlive,
    this.phase,
    this.timerSeconds,
    this.survivors,
    this.onSuccessorSelected,
  })  : room = _synthesizeRoom(room, currentUserId, isCaptain, isAlive, phase, timerSeconds, survivors),
        currentUserId = currentUserId ?? 'test_user',
        onNextPhase = onNextPhase ?? _noop,
        onVote = onVote ?? _noopValue,
        onInspect = onInspect ?? _noopValue,
        onCompleteSeerTurn = onCompleteSeerTurn ?? _noop,
        onWitchSave = onWitchSave ?? _noop,
        onWitchPoison = onWitchPoison ?? _noopValue,
        onWitchPass = onWitchPass ?? _noop;

  static void _noop() {}
  static void _noopValue(dynamic _) {}

  static GameRoom _synthesizeRoom(
    GameRoom? room,
    String? currentUserId,
    bool? isCaptain,
    bool? isAlive,
    GamePhase? phase,
    int? timerSeconds,
    List<dynamic>? survivors,
  ) {
    if (room != null && isCaptain == null && isAlive == null && phase == null && timerSeconds == null && survivors == null) {
      return room;
    }
    final uid = currentUserId ?? 'test_user';
    final alive = isAlive ?? room?.players[uid]?.isAlive ?? true;
    final captain = isCaptain ?? room?.players[uid]?.isCaptain ?? false;
    final ph = phase ?? room?.phase ?? GamePhase.lobby;
    final timer = timerSeconds ?? room?.timerSeconds ?? 10;

    final Map<String, PlayerModel> players = Map<String, PlayerModel>.from(room?.players ?? {});
    if (!players.containsKey(uid)) {
      players[uid] = PlayerModel(
        id: uid,
        name: 'Moi',
        isAlive: alive,
        isCaptain: captain,
      );
    } else {
      players[uid] = players[uid]!.copyWith(
        isAlive: alive,
        isCaptain: captain,
      );
    }

    if (survivors != null) {
      for (final s in survivors) {
        if (s is Map) {
          final sid = (s['id'] ?? '').toString();
          final sname = (s['name'] ?? sid).toString();
          players[sid] = PlayerModel(
            id: sid,
            name: sname,
            isAlive: true,
          );
        } else if (s is PlayerModel) {
          players[s.id] = s;
        }
      }
    }

    return room?.copyWith(
      phase: ph,
      timerSeconds: timer,
      players: players,
      captainId: captain ? uid : room.captainId,
      pendingCaptainId: (captain && !alive) ? uid : room.pendingCaptainId,
    ) ?? GameRoom(
      roomCode: 'TEST',
      hostId: uid,
      phase: ph,
      timerSeconds: timer,
      captainId: captain ? uid : null,
      pendingCaptainId: (captain && !alive) ? uid : null,
      players: players,
    );
  }

  @override
  State<BentoActionPanel> createState() => _BentoActionPanelState();
}

class _BentoActionPanelState extends State<BentoActionPanel> {
  // Sélection des deux amoureux par Cupidon
  String? _cupidLover1Id;
  String? _cupidLover2Id;

  // Sélection des deux cibles par le Joueur de Flûte
  String? _piperTarget1Id;
  String? _piperTarget2Id;

  // Sélection du successeur par le Capitaine défunt (Testament)
  String? _selectedCaptainSuccessorId;

  GameRoom get effectiveRoom => widget.room;

  @override
  void didUpdateWidget(covariant BentoActionPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Nettoyage impératif des sous-états lors des transitions de phase ou de round
    final oldPhase = oldWidget.phase ?? oldWidget.room.phase;
    final newPhase = widget.phase ?? widget.room.phase;
    final oldRound = oldWidget.room.round;
    final newRound = widget.room.round;
    if (oldPhase != newPhase || oldRound != newRound) {
      _cupidLover1Id = null;
      _cupidLover2Id = null;
      _selectedCaptainSuccessorId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = effectiveRoom;
    final currentUserId = widget.currentUserId;
    final me = room.players[currentUserId] ??
        PlayerModel(
          id: currentUserId,
          name: 'Moi',
          isAlive: widget.isAlive ?? true,
          isCaptain: widget.isCaptain ?? false,
        );

    final isAlive = widget.isAlive ?? me.isAlive;
    final role = me.role;
    final phase = widget.phase ?? room.phase;
    final isDyingCaptain = (widget.isCaptain == true && widget.isAlive == false) ||
        (room.pendingCaptainId == currentUserId) ||
        (me.isCaptain && !isAlive) ||
        (room.captainId == currentUserId && !isAlive);
    final selectedTarget = widget.selectedTargetId != null
        ? room.players[widget.selectedTargetId]
        : null;

    return BentoCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      borderColor: LupusColors.borderGlow,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // En-tête compact avec badge de décompte et badge de la cible sélectionnée
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.tr('strategic_actions'),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: LupusColors.textMuted.withValues(alpha: 0.8),
                    ),
                  ),
                  if (widget.countdownListenable != null) ...[
                    const SizedBox(width: 8),
                    ValueListenableBuilder<int>(
                      valueListenable: widget.countdownListenable!,
                      builder: (context, seconds, _) {
                        final isUrgent = seconds <= 10;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: isUrgent
                                ? const Color(0x44DC2626)
                                : const Color(0x2A1E1B4B),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isUrgent
                                  ? LupusColors.arcaneCrimson
                                  : LupusColors.arcaneGold.withValues(alpha: 0.5),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isUrgent ? '⏳' : '⏱️',
                                style: const TextStyle(fontSize: 9),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${seconds}s',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  color: isUrgent
                                      ? const Color(0xFFFFA4A4)
                                      : LupusColors.arcaneGold,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
              if (selectedTarget != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: LupusColors.arcaneGold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: LupusColors.arcaneGold.withValues(alpha: 0.3),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: LupusColors.arcaneGold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        selectedTarget.name,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: LupusColors.arcaneGold,
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
                // 0. BARRE DE CONTRÔLE GODMODE POUR LES TOURS DE BOTS
                if (widget.isAdmin && phase.isNight) ...[
                  _buildGodmodeBotControlBar(phase),
                  const SizedBox(height: 6),
                ],

                // 1. CHASSEUR AU DERNIER SOUFFLE
                if (phase == GamePhase.hunterDeathChoice &&
                    (widget.room.pendingHunterId == widget.currentUserId || widget.isAdmin)) ...[
                  _buildHunterSection(selectedTarget),
                ]
                // 2. CAPITAINE DÉFUNT (TESTAMENT) OU SPECTATEUR / VILLAGE
                else if (phase == GamePhase.captainSuccession) ...[
                  if (isDyingCaptain || widget.isAdmin) ...[
                    _buildCaptainSuccessionSection(selectedTarget),
                  ] else ...[
                    _buildCaptainSuccessionSpectatorSection(),
                  ],
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
                // 8.B LOUP NOIR (Unifié dans la section Loups-Garous)
                else if (phase == GamePhase.nightBlackWolf &&
                    (role.isEvil || widget.isAdmin)) ...[
                  _buildWerewolvesSection(me, selectedTarget),
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
                // 9.C JOUEUR DE FLÛTE
                else if (phase == GamePhase.nightPiper &&
                    (role == GameRole.piedPiper || widget.isAdmin)) ...[
                  _buildPiperSection(selectedTarget),
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

  /// Module Sorcière :
  /// 1. Carte dédiée pour la victime des loups avec bouton direct [Sauver (Nom)] (sans sélection préalable)
  ///    OU bannière explicite si aucune victime ciblée par les loups.
  /// 2. Section Fiole de Mort (sélection libre parmi les joueurs vivants)
  /// 3. Bouton [Valider / Passer son tour]
  Widget _buildWitchSection(PlayerModel witch, PlayerModel? selectedTarget) {
    final wolfVictimId = widget.room.nightVictimId;
    final wolfVictim = wolfVictimId != null ? widget.room.players[wolfVictimId] : null;
    final hasHeal = (witch.potionsVie > 0 && !widget.room.witchHealed) || widget.isAdmin;
    final hasPoison = witch.potionsMort > 0 || widget.isAdmin;
    final isHealed = widget.room.witchHealed;
    final poisonVictimId = widget.room.witchPoisonVictimId;
    final poisonVictim = poisonVictimId != null ? widget.room.players[poisonVictimId] : null;
    final hasActed = isHealed || poisonVictim != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Bandeau d'état des potions Sorcière (stocks indépendants)
        Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0x1F10B981),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: LupusColors.poisonGreen.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '🧪 Potions de Vie : ${witch.potionsVie}',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: witch.potionsVie > 0
                      ? LupusColors.poisonGreen
                      : LupusColors.textMuted,
                ),
              ),
              Text(
                '☠️ Potions de Mort : ${witch.potionsMort}',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: witch.potionsMort > 0
                      ? LupusColors.arcaneCrimson
                      : LupusColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        // --- 1. CARTE DÉDIÉE : VICTIME DES LOUPS & POTION DE VIE ---
        if (wolfVictim != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isHealed
                    ? [const Color(0x33064E3B), const Color(0x22022C22)]
                    : [const Color(0x33450A0A), const Color(0x221E1B4B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isHealed
                    ? LupusColors.poisonGreen.withValues(alpha: 0.8)
                    : LupusColors.arcaneCrimson.withValues(alpha: 0.8),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                // Avatar de la victime
                CircleAvatar(
                  radius: 17,
                  backgroundColor: isHealed
                      ? LupusColors.poisonGreen.withValues(alpha: 0.2)
                      : LupusColors.bloodRed.withValues(alpha: 0.25),
                  child: Icon(
                    BentoPlayerTile.avatarIcons[
                        wolfVictim.avatarIndex % BentoPlayerTile.avatarIcons.length],
                    size: 17,
                    color: isHealed
                        ? LupusColors.poisonGreen
                        : const Color(0xFFFECDD3),
                  ),
                ),
                const SizedBox(width: 8),
                // Pseudo et statut de danger
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              wolfVictim.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: isHealed
                                  ? LupusColors.poisonGreen.withValues(alpha: 0.2)
                                  : LupusColors.bloodRed.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isHealed ? context.tr('saved') : context.tr('victim'),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: isHealed
                                    ? LupusColors.poisonGreen
                                    : const Color(0xFFFECDD3),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isHealed
                            ? context.tr('victim_saved_tonight')
                            : (hasHeal
                                ? context.tr('life_potion')
                                : context.tr('heal_exhausted')),
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: isHealed
                              ? LupusColors.poisonGreen
                              : (hasHeal
                                  ? const Color(0xFFFECDD3)
                                  : LupusColors.textMuted),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                // Action directe sur la victime : Sauver en 1 clic
                if (isHealed) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0x33064E3B),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: LupusColors.poisonGreen.withValues(alpha: 0.6)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            size: 13, color: LupusColors.poisonGreen),
                        const SizedBox(width: 3),
                        Text(
                          context.tr('saved'),
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: LupusColors.poisonGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (hasHeal) ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.black,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 2,
                    ),
                    onPressed: widget.onWitchSave,
                    icon: const Icon(Icons.healing_rounded, size: 14),
                    label: Text(
                      context.tr('save_target', {'name': wolfVictim.name}),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 11),
                    ),
                  ),
                ] else ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      context.tr('used_potion'),
                      style: const TextStyle(
                          fontSize: 9.5,
                          color: LupusColors.textMuted,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ] else ...[
          // Message explicite : Aucune victime des loups cette nuit (bouton soin désactivé/masqué)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0x1F1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: const Color(0x330284C7),
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: const Color(0xFF38BDF8), width: 1),
                  ),
                  child: const Text('🕊️', style: TextStyle(fontSize: 13)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.tr('no_victim_to_save'),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFBAE6FD),
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        hasHeal
                            ? context.tr('potion_available')
                            : context.tr('potion_depleted'),
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: hasHeal
                              ? LupusColors.poisonGreen
                              : LupusColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 6),

        // --- 2. SECTION POTION DE MORT (SÉLECTION LIBRE) ---
        if (poisonVictim != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: LupusColors.bloodRed.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: LupusColors.bloodRed.withValues(alpha: 0.6)),
            ),
            child: Row(
              children: [
                const Icon(Icons.science_rounded,
                    size: 14, color: LupusColors.bloodRed),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    context.tr('victim_poisoned_tonight',
                        {'name': poisonVictim.name}),
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFFECDD3),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else if (hasPoison) ...[
          if (selectedTarget != null &&
              selectedTarget.isAlive &&
              selectedTarget.id != widget.currentUserId) ...[
            SizedBox(
              height: 38,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: LupusColors.bloodRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => widget.onWitchPoison(selectedTarget.id),
                icon: const Icon(Icons.science_rounded, size: 14),
                label: Text(
                  context.tr('poison_target', {'name': selectedTarget.name}),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 11),
                ),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0x1F450A0A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: LupusColors.bloodRed.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.science_outlined,
                      size: 13,
                      color: LupusColors.bloodRed.withValues(alpha: 0.8)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      context.tr('tap_player_to_target'),
                      style: const TextStyle(
                          fontSize: 10, color: LupusColors.textMuted),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ] else ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.science_outlined,
                    size: 13, color: LupusColors.textMuted),
                const SizedBox(width: 6),
                Text(
                  context.tr('poison_exhausted'),
                  style: const TextStyle(
                      fontSize: 10, color: LupusColors.textMuted),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 6),

        // --- 3. BOUTON VALIDER / PASSER SON TOUR ---
        SizedBox(
          height: 38,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: hasActed
                  ? LupusColors.arcanePurple
                  : LupusColors.surfaceLight,
              foregroundColor: Colors.white,
              elevation: hasActed ? 2 : 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              side: BorderSide(
                color: hasActed
                    ? LupusColors.arcanePurple
                    : LupusColors.border.withValues(alpha: 0.6),
              ),
            ),
            onPressed: widget.onWitchPass,
            icon: Icon(
              hasActed
                  ? Icons.check_circle_rounded
                  : Icons.bedtime_outlined,
              size: 14,
            ),
            label: Text(
              hasActed
                  ? context.tr('confirm_witch_choices')
                  : context.tr('witch_pass'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 11),
            ),
          ),
        ),
      ],
    );
  }

  /// Module Loups-Garous : Double action obligatoire (Dévorer ET Museler) + [Valider l'Assaut]
  Widget _buildWerewolvesSection(PlayerModel me, PlayerModel? selectedTarget) {
    final effectiveVictimId = widget.room.nightVictimId ?? me.targetVoteId;
    final currentVoteTarget = effectiveVictimId != null
        ? widget.room.players[effectiveVictimId]
        : null;

    final silencedTargetId = widget.room.blackWolfTargetId;
    final silencedTarget = (silencedTargetId != null && silencedTargetId.isNotEmpty)
        ? widget.room.players[silencedTargetId]
        : null;

    final isDoubleActionComplete = effectiveVictimId != null &&
        silencedTargetId != null &&
        effectiveVictimId != silencedTargetId;

    final isTargetWolf = selectedTarget != null &&
        (selectedTarget.role.isEvil ||
            selectedTarget.role.isWolfTeam ||
            selectedTarget.role == GameRole.whiteWerewolf);

    final isSilencedWolf = silencedTarget != null &&
        (silencedTarget.role.isEvil ||
            silencedTarget.role.isWolfTeam ||
            silencedTarget.role == GameRole.whiteWerewolf);

    final isSelf = selectedTarget != null && selectedTarget.id == widget.currentUserId;
    final isSilencedSelf = silencedTarget != null && silencedTarget.id == widget.currentUserId;

    final canDevour = selectedTarget != null &&
        selectedTarget.isAlive &&
        !isTargetWolf &&
        !isSelf;

    final canSilence = selectedTarget != null &&
        selectedTarget.isAlive &&
        selectedTarget.id != effectiveVictimId;

    final hasInfectWolf = widget.room.alivePlayers.any(
      (p) => p.role == GameRole.vileFatherOfWolves,
    );
    final canInfect = (hasInfectWolf || widget.isAdmin) && !widget.room.vileFatherInfectionUsed;
    final isInfected = effectiveVictimId != null && widget.room.infectedPlayerId == effectiveVictimId;

    final canValidate = widget.isAdmin || isDoubleActionComplete;

    final devourButtonText = selectedTarget != null
        ? '🥩 Dévorer ${selectedTarget.name}'
        : (currentVoteTarget != null ? '🥩 Proie : ${currentVoteTarget.name}' : '🥩 Choisir Proie');

    final silenceButtonText = selectedTarget != null
        ? (isSelf ? '🔇 Me Museler' : '🔇 Museler ${selectedTarget.name}')
        : (silencedTarget != null ? '🔇 Silence : ${silencedTarget.name}' : '🔇 Museler');

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Synthèse Double Action : Deux emplacements obligatoires (Proie & Silence)
        Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isDoubleActionComplete
                ? const Color(0x1F06D6A0)
                : const Color(0x221E1B4B),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDoubleActionComplete
                  ? LupusColors.poisonGreen.withValues(alpha: 0.6)
                  : const Color(0xFF9333EA).withValues(alpha: 0.4),
              width: 1.2,
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isDoubleActionComplete
                        ? '✅ ASSAUT PRÊT (2/2) : PROIE & SILENCE'
                        : '🐺 DOUBLE OBLIGATION : PROIE & SILENCE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      color: isDoubleActionComplete
                          ? LupusColors.poisonGreen
                          : const Color(0xFFFECDD3),
                    ),
                  ),
                  if (selectedTarget != null && (isTargetWolf || isSelf))
                    Text(
                      isSelf ? 'Moi-même (Auto-Silence)' : 'Allié (Bluff Silence)',
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFC084FC),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  // Emplacement 1 : Proie désignée
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: effectiveVictimId != null
                            ? const Color(0x33B91C1C)
                            : Colors.black26,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: effectiveVictimId != null
                              ? LupusColors.bloodRed
                              : Colors.white10,
                        ),
                      ),
                      child: Text(
                        effectiveVictimId != null
                            ? '🥩 Proie : ${currentVoteTarget?.name ?? "Cible"}'
                            : '🥩 Proie : Aucune',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: effectiveVictimId != null
                              ? const Color(0xFFFECDD3)
                              : LupusColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Emplacement 2 : Cible du silence
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: silencedTarget != null
                            ? const Color(0x33581C87)
                            : Colors.black26,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: silencedTarget != null
                              ? const Color(0xFFC084FC)
                              : Colors.white10,
                        ),
                      ),
                      child: Text(
                        silencedTarget != null
                            ? '🔇 Silence : ${silencedTarget.name}${isSilencedSelf ? " (Auto-Silence)" : (isSilencedWolf ? " (Bluff)" : "")}'
                            : '🔇 Silence : Aucun',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: silencedTarget != null
                              ? const Color(0xFFE9D5FF)
                              : LupusColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // 2. Boutons d'Action Distincts
        Row(
          children: [
            // Bouton Dévorer
            Expanded(
              child: SizedBox(
                height: 40,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LupusColors.bloodRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: canDevour
                      ? () => widget.onVote(selectedTarget.id)
                      : null,
                  icon: const Icon(Icons.pets_rounded, size: 14),
                  label: Text(
                    devourButtonText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Bouton Faire Taire (Silence)
            Expanded(
              child: SizedBox(
                height: 40,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF311042),
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: canSilence ? const Color(0xFFC084FC) : Colors.white12,
                      width: 1.2,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: canSilence
                      ? () => widget.onBlackWolfSilence?.call(selectedTarget.id)
                      : null,
                  icon: const Icon(Icons.volume_off_rounded, size: 14, color: Color(0xFFC084FC)),
                  label: Text(
                    silenceButtonText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Bouton Valider l'Assaut
            SizedBox(
              height: 40,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: canValidate ? const Color(0xFF7F1D1D) : const Color(0x992B1010),
                  foregroundColor: const Color(0xFFFECDD3),
                  side: BorderSide(
                    color: canValidate
                        ? LupusColors.arcaneCrimson
                        : LupusColors.arcaneCrimson.withValues(alpha: 0.3),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: canValidate ? widget.onNextPhase : null,
                icon: const Icon(Icons.check_rounded, size: 14),
                label: Text(
                  isDoubleActionComplete ? 'Valider (2/2)' : context.tr('validate'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
                ),
              ),
            ),
          ],
        ),
        // Option Loup Infect (Pouvoir Unique)
        if (canInfect && effectiveVictimId != null) ...[
          const SizedBox(height: 6),
          SizedBox(
            height: 34,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                backgroundColor: isInfected ? const Color(0x33DC2626) : Colors.transparent,
                foregroundColor: isInfected ? const Color(0xFFF87171) : const Color(0xFFE2E8F0),
                side: BorderSide(
                  color: isInfected ? const Color(0xFFDC2626) : const Color(0x66DC2626),
                  width: isInfected ? 1.5 : 1.0,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => widget.onInfect?.call(effectiveVictimId),
              icon: Icon(
                isInfected ? Icons.check_circle_rounded : Icons.pest_control_rounded,
                size: 14,
                color: isInfected ? const Color(0xFFF87171) : const Color(0xFFEF4444),
              ),
              label: Text(
                isInfected ? '🩸 Proie infectée (Transformée en Loup à l\'Aube)' : '🩸 Infecter la proie au lieu de l\'exécuter (Infect Père des Loups)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isInfected ? FontWeight.w900 : FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Module Voyante : [Sonder (Nom)] + [Valider]
  Widget _buildSeerSection(PlayerModel? selectedTarget) {
    final me = widget.room.players[widget.currentUserId] ??
        widget.room.playerList.first;
    final seerPlayer = widget.room.playerList.firstWhere(
      (p) => p.role == GameRole.seer || p.roleInitial == GameRole.seer,
      orElse: () => me,
    );
    final visionsLeft = seerPlayer.visionsRestantes;

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
                      textAlign: TextAlign.center,
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
              label: Text(context.tr('validate'), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
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

    final canInspect = (visionsLeft > 0 || widget.isAdmin) &&
        selectedTarget != null &&
        selectedTarget.isAlive &&
        selectedTarget.id != widget.currentUserId;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Indicateur quota dynamique de visions Voyante
        Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0x1F9333EA),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: LupusColors.arcanePurple.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('🔮', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 6),
                  Text(
                    'Visions restantes : $visionsLeft',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: visionsLeft > 0
                          ? const Color(0xFFE9D5FF)
                          : LupusColors.textMuted,
                    ),
                  ),
                ],
              ),
              if (visionsLeft == 0 && !widget.isAdmin)
                const Text(
                  'Déchu en Villageois',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: LupusColors.arcaneCrimson,
                  ),
                ),
            ],
          ),
        ),
        Row(
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
                  onPressed: canInspect
                      ? () => widget.onInspect(selectedTarget.id)
                      : null,
                  icon: const Icon(Icons.visibility_rounded, size: 15),
                  label: Text(
                    inspectLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
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
                label: Text(context.tr('validate'), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              ),
            ),
          ],
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
                    textAlign: TextAlign.center,
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
                child: Text(context.tr('pass'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
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



  /// Module Chasseur au dernier souffle : Bouton direct [Tirer sur (Nom)] et [Passer]
  Widget _buildHunterSection(PlayerModel? selectedTarget) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
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
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 40,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0x33450A0A),
              foregroundColor: LupusColors.textMuted,
              side: BorderSide(color: LupusColors.border.withValues(alpha: 0.5)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: widget.onNextPhase,
            icon: const Icon(Icons.cancel_outlined, size: 14),
            label: const Text(
              'Passer',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
            ),
          ),
        ),
      ],
    );
  }

  /// Module Scrutin du Bûcher : Bouton direct [Voter contre (Nom)]
  Widget _buildVotingSection(PlayerModel me, PlayerModel? selectedTarget) {
    final isTieBreak = widget.room.phase == GamePhase.dayTieBreakVote;
    final isEligible = !isTieBreak || widget.room.tiedPlayerIds.contains(selectedTarget?.id);
    final currentVoteTargetId = me.targetVoteId;
    final totalAlive = widget.room.alivePlayers.length;
    final totalVoted = widget.room.alivePlayers.where((p) => p.targetVoteId != null).length;
    final allVoted = totalAlive > 0 && totalVoted >= totalAlive;

    if (allVoted) {
      return Container(
        height: 40,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: LupusColors.bloodRed.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: LupusColors.bloodRed.withValues(alpha: 0.6)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(LupusColors.bloodRed),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Tous les votes sont enregistrés ($totalVoted/$totalAlive) • Dépouillement immédiat...',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    }

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
                textAlign: TextAlign.center,
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
              child: Text(context.tr('cancel'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
            ),
          ),
        ],
      ],
    );
  }

  /// Module Capitaine (Testament du Capitaine) : Vue dédiée pour le Capitaine mourant
  Widget _buildCaptainSuccessionSection(PlayerModel? selectedTarget) {
    final countdownListenable = widget.countdownListenable ??
        ValueNotifier<int>(widget.timerSeconds ?? (effectiveRoom.timerSeconds > 0 ? effectiveRoom.timerSeconds : 10));

    return ValueListenableBuilder<int>(
      valueListenable: countdownListenable,
      builder: (context, countdown, _) {
        if (countdown <= 0) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0x33450A0A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: LupusColors.arcaneCrimson.withValues(alpha: 0.4),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(LupusColors.arcaneCrimson),
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  "Temps expiré — Transmission d'office du titre...",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFFA4A4),
                  ),
                ),
              ],
            ),
          );
        }

        final survivors = widget.survivors != null
            ? widget.survivors!.map((s) {
                if (s is Map) {
                  return PlayerModel(
                    id: (s['id'] ?? '').toString(),
                    name: (s['name'] ?? '').toString(),
                    isAlive: true,
                  );
                }
                return s as PlayerModel;
              }).toList()
            : effectiveRoom.alivePlayers
                .where((p) => p.id != widget.currentUserId)
                .toList();

        final effectiveSuccessorId =
            _selectedCaptainSuccessorId ?? selectedTarget?.id;
        final effectiveSuccessor = effectiveSuccessorId != null
            ? (survivors.cast<PlayerModel?>().firstWhere(
                (p) => p?.id == effectiveSuccessorId,
                orElse: () => effectiveRoom.players[effectiveSuccessorId],
              ))
            : null;
        final isValidSuccessor = effectiveSuccessor != null &&
            effectiveSuccessor.isAlive &&
            effectiveSuccessor.id != widget.currentUserId;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // En-tête : « Testament du Capitaine » + Compte à rebours circulaire de 10s
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0x332A1D05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: LupusColors.arcaneGold.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: LupusColors.arcaneGold.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.history_edu_rounded,
                      size: 16,
                      color: LupusColors.arcaneGold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Testament du Capitaine',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: LupusColors.arcaneGold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          "Désignez l'héritier de l'écharpe parmi les survivants",
                          style: TextStyle(
                            fontSize: 9.5,
                            color: LupusColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Compte à rebours circulaire de 10 secondes
                  SizedBox(
                    width: 30,
                    height: 30,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: (countdown / 10.0).clamp(0.0, 1.0),
                          strokeWidth: 2.5,
                          backgroundColor: Colors.white12,
                          valueColor: AlwaysStoppedAnimation(
                            countdown <= 3
                                ? LupusColors.arcaneCrimson
                                : LupusColors.arcaneGold,
                          ),
                        ),
                        Text(
                          '$countdown',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            color: countdown <= 3
                                ? const Color(0xFFFFA4A4)
                                : LupusColors.arcaneGold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // Liste interactive des survivants
            if (survivors.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  'Aucun survivant disponible.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: LupusColors.textMuted),
                ),
              )
            else
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: survivors.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 6),
                  itemBuilder: (context, i) {
                    final survivor = survivors[i];
                    final isChosen = survivor.id == effectiveSuccessorId;
                    return InkWell(
                      onTap: () {
                        setState(() => _selectedCaptainSuccessorId = survivor.id);
                        widget.onSelectTarget?.call(survivor.id);
                        widget.onSuccessorSelected?.call(survivor.id);
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isChosen
                              ? LupusColors.arcaneGold.withValues(alpha: 0.22)
                              : const Color(0x440F172A),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isChosen
                                ? LupusColors.arcaneGold
                                : LupusColors.border.withValues(alpha: 0.4),
                            width: isChosen ? 1.4 : 0.8,
                          ),
                          boxShadow: isChosen
                              ? [
                                  BoxShadow(
                                    color: LupusColors.arcaneGold.withValues(alpha: 0.35),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: isChosen
                                  ? LupusColors.arcaneGold
                                  : const Color(0xFF2E3856),
                              child: Text(
                                survivor.name.isNotEmpty
                                    ? survivor.name[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: isChosen ? Colors.black : Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              survivor.name,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isChosen ? FontWeight.w900 : FontWeight.w700,
                                color: isChosen ? Colors.white : LupusColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 6),

            // Bouton doré : « Léguer l'écharpe à [Nom] »
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isValidSuccessor
                            ? LupusColors.arcaneGold
                            : const Color(0x333F2E05),
                        foregroundColor: isValidSuccessor
                            ? Colors.black
                            : LupusColors.textMuted,
                        disabledBackgroundColor: const Color(0x223F2E05),
                        disabledForegroundColor: LupusColors.textMuted,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: isValidSuccessor ? 3 : 0,
                      ),
                      onPressed: isValidSuccessor
                          ? () {
                              widget.onSuccessorSelected?.call(effectiveSuccessor.id);
                              widget.onCaptainPass?.call(effectiveSuccessor.id);
                            }
                          : null,
                      icon: Icon(
                        Icons.military_tech_rounded,
                        size: 16,
                        color: isValidSuccessor ? Colors.black : LupusColors.textMuted,
                      ),
                      label: Text(
                        isValidSuccessor
                            ? "Léguer l'écharpe à ${effectiveSuccessor.name}"
                            : "Choisir un survivant...",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          color: isValidSuccessor ? Colors.black : LupusColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 40,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0x33450A0A),
                      foregroundColor: LupusColors.textMuted,
                      side: BorderSide(
                        color: LupusColors.border.withValues(alpha: 0.5),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: widget.onNextPhase,
                    icon: const Icon(Icons.casino_outlined, size: 14),
                    label: const Text(
                      "D'office",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  /// Module Spectateur / Village : Bandeau immersif non interactif avec compte à rebours synchronisé de 10s
  Widget _buildCaptainSuccessionSpectatorSection() {
    final countdownListenable = widget.countdownListenable ??
        ValueNotifier<int>(widget.timerSeconds ?? (effectiveRoom.timerSeconds > 0 ? effectiveRoom.timerSeconds : 10));

    return ValueListenableBuilder<int>(
      valueListenable: countdownListenable,
      builder: (context, countdown, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xE60D111F),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: LupusColors.arcaneGold.withValues(alpha: 0.35),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: LupusColors.arcaneGold.withValues(alpha: 0.12),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: LupusColors.arcaneGold.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: LupusColors.arcaneGold.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.military_tech_outlined,
                  size: 18,
                  color: LupusColors.arcaneGold,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Le Capitaine agonisant choisit son successeur...',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Le village retient son souffle devant ses dernières volontés.',
                      style: TextStyle(
                        fontSize: 9.5,
                        color: LupusColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Compte à rebours synchronisé de 10s
              SizedBox(
                width: 28,
                height: 28,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: (countdown / 10.0).clamp(0.0, 1.0),
                      strokeWidth: 2.5,
                      backgroundColor: Colors.white10,
                      valueColor: AlwaysStoppedAnimation(
                        countdown <= 3
                            ? LupusColors.arcaneCrimson
                            : LupusColors.arcaneGold,
                      ),
                    ),
                    Text(
                      '$countdown',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: countdown <= 3
                            ? const Color(0xFFFFA4A4)
                            : LupusColors.arcaneGold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
        ),
      ),
    );
  }

  /// Module Débat tour par tour
  Widget _buildDebateSection() {
    final isSpeaker = widget.room.currentSpeakerId == widget.currentUserId;
    if (isSpeaker || widget.isAdmin) {
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
            isSpeaker ? context.tr('pass_speaking_turn') : 'Forcer la parole au suivant (MJ)',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: Colors.black,
              fontSize: 12,
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

  /// Module Voleur (Nuit 1) : Choix entre 2 cartes non attribuées ou rester Voleur
  Widget _buildThiefSection(PlayerModel? selectedTarget) {
    final available = widget.room.thiefAvailableRoles;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (available.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: const Color(0x228338EC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF8338EC).withValues(alpha: 0.4)),
            ),
            child: const Text(
              '🃏 Cartes disponibles au centre :',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFC084FC)),
            ),
          ),
          Row(
            children: available.map((role) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: SizedBox(
                    height: 38,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: role.isEvil ? const Color(0xFF7F1D1D) : const Color(0xFF1E3A8A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                      ),
                      onPressed: () => widget.onThiefChooseRole?.call(role),
                      icon: Icon(role.icon, size: 14),
                      label: Text(
                        role.displayNameFr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 6),
        ],
        Row(
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
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
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
                child: const Text('Rester Voleur', style: TextStyle(fontSize: 10.5)),
              ),
            ),
          ],
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
                textAlign: TextAlign.center,
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
                textAlign: TextAlign.center,
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
            child: Text(context.tr('bind_lovers_btn'), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5)),
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
                textAlign: TextAlign.center,
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
              textAlign: TextAlign.center,
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
            child: Text(context.tr('pass'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
          ),
        ),
      ],
    );
  }

  Widget _buildGodmodeBotControlBar(GamePhase phase) {
    PlayerModel? activePlayer;
    switch (phase) {
      case GamePhase.nightThief:
        activePlayer = widget.room.alivePlayers.cast<PlayerModel?>().firstWhere(
              (p) => p != null && p.role == GameRole.thief,
              orElse: () => null,
            );
        break;
      case GamePhase.nightCupid:
        activePlayer = widget.room.alivePlayers.cast<PlayerModel?>().firstWhere(
              (p) => p != null && p.role == GameRole.cupid,
              orElse: () => null,
            );
        break;
      case GamePhase.nightDefender:
        activePlayer = widget.room.alivePlayers.cast<PlayerModel?>().firstWhere(
              (p) => p != null && p.role == GameRole.defender,
              orElse: () => null,
            );
        break;
      case GamePhase.nightWerewolves:
      case GamePhase.nightBlackWolf:
        activePlayer = widget.room.alivePlayers.cast<PlayerModel?>().firstWhere(
              (p) => p != null && p.role.isEvil,
              orElse: () => null,
            );
        break;
      case GamePhase.nightSeer:
        activePlayer = widget.room.alivePlayers.cast<PlayerModel?>().firstWhere(
              (p) => p != null && p.role == GameRole.seer,
              orElse: () => null,
            );
        break;
      case GamePhase.nightWitch:
        activePlayer = widget.room.alivePlayers.cast<PlayerModel?>().firstWhere(
              (p) => p != null && p.role == GameRole.witch,
              orElse: () => null,
            );
        break;
      case GamePhase.nightPiper:
        activePlayer = widget.room.alivePlayers.cast<PlayerModel?>().firstWhere(
              (p) => p != null && p.role == GameRole.piedPiper,
              orElse: () => null,
            );
        break;
      case GamePhase.nightPyromaniac:
        activePlayer = widget.room.alivePlayers.cast<PlayerModel?>().firstWhere(
              (p) => p != null && p.role == GameRole.pyromaniac,
              orElse: () => null,
            );
        break;
      default:
        break;
    }

    final isBot = activePlayer != null && activePlayer.id.startsWith('bot_');
    final activeName = activePlayer?.name ?? 'Entité';
    final activeRole = activePlayer?.role.displayNameFr ?? phase.titleFr;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1405),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: LupusColors.arcaneGold.withValues(alpha: 0.6), width: 1.2),
        boxShadow: LupusTheme.glowGold(opacity: 0.25),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF422006),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text('👑', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isBot ? '🎮 Contrôle du Bot : $activeName' : '👑 Contrôle Hôte : $activeName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    color: LupusColors.arcaneGold,
                  ),
                ),
                Text(
                  'Rôle : $activeRole',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            height: 28,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: LupusColors.arcaneGold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: widget.onExecuteBotNightAction,
              icon: const Icon(Icons.smart_toy_rounded, size: 13),
              label: const Text(
                'Laisser l\'IA agir',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Module Joueur de Flûte : Envoûte 2 joueurs avec sa mélodie
  Widget _buildPiperSection(PlayerModel? selectedTarget) {
    final target1 = _piperTarget1Id != null ? widget.room.players[_piperTarget1Id] : null;
    final target2 = _piperTarget2Id != null ? widget.room.players[_piperTarget2Id] : null;

    final uncharmedLiving = widget.room.alivePlayers.where((p) => !p.isCharmed).toList();
    final canCharm = (target1 != null && target2 != null && target1.id != target2.id) ||
        (uncharmedLiving.length == 1 && target1 != null);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (selectedTarget != null &&
                      selectedTarget.isAlive &&
                      !selectedTarget.isCharmed &&
                      selectedTarget.id != _piperTarget2Id) {
                    setState(() => _piperTarget1Id = selectedTarget.id);
                  }
                },
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: target1 != null
                        ? const Color(0xFF06D6A0).withValues(alpha: 0.18)
                        : Colors.black26,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: target1 != null
                          ? const Color(0xFF06D6A0)
                          : LupusColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.music_note_rounded, size: 14, color: Color(0xFF06D6A0)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          target1 != null ? target1.name : '1ère Cible',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: target1 != null ? FontWeight.w800 : FontWeight.w500,
                            color: target1 != null ? const Color(0xFF06D6A0) : LupusColors.textMuted,
                          ),
                        ),
                      ),
                    ],
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
                      !selectedTarget.isCharmed &&
                      selectedTarget.id != _piperTarget1Id) {
                    setState(() => _piperTarget2Id = selectedTarget.id);
                  }
                },
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: target2 != null
                        ? const Color(0xFF06D6A0).withValues(alpha: 0.18)
                        : Colors.black26,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: target2 != null
                          ? const Color(0xFF06D6A0)
                          : LupusColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.music_note_rounded, size: 14, color: Color(0xFF06D6A0)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          target2 != null ? target2.name : '2ème Cible',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: target2 != null ? FontWeight.w800 : FontWeight.w500,
                            color: target2 != null ? const Color(0xFF06D6A0) : LupusColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 38,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF06D6A0),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: canCharm
                ? () {
                    final targets = [
                      if (target1 != null) target1.id,
                      if (target2 != null) target2.id,
                    ];
                    widget.onPiperCharm?.call(targets);
                  }
                : null,
            icon: const Icon(Icons.graphic_eq_rounded, size: 16),
            label: const Text(
              'Envoûter avec la Flûte',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5),
            ),
          ),
        ),
      ],
    );
  }
}
