import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../GameNotifier.dart';
import '../../models/game_phase.dart';
import '../../models/player_model.dart';
import '../admin/admin_control_sheet.dart';
import '../admin/admin_secret_dialog.dart';
import '../bento/bento_action_panel.dart';
import '../bento/bento_card.dart';
import '../bento/bento_player_grid.dart';
import '../bento/bento_voice_controls.dart';
import '../bento/mystic_radial_table.dart';
import '../bento/role_card_image.dart';
import '../theme/lupus_assets.dart';
import '../theme/lupus_theme.dart';
import 'lobby_screen.dart';
import 'village_chronicles_screen.dart';

/// Écran principal d'Arène inspiré directement de la maquette Stitch
/// "Lupus Arena - Table de Nuit Ultime" (Design gothique nocturne,
/// table circulaire mystique, carrousel de sélection de cible, HUD arcanique).
class ArenaGameScreen extends ConsumerStatefulWidget {
  const ArenaGameScreen({super.key});

  @override
  ConsumerState<ArenaGameScreen> createState() => _ArenaGameScreenState();
}

class _ArenaGameScreenState extends ConsumerState<ArenaGameScreen> {
  String? _selectedPlayerId;
  bool _useRadialView = true; // Bascule entre Table Mystique et Grille Bento

  // Gestion du journal et badge de notification des Chroniques
  int _lastSeenLogCount = 0;

  // Gestion du chronomètre décomptant actif
  Timer? _phaseCountdownTimer;
  int _localCountdown = 40;
  GamePhase? _lastTrackedPhase;
  int? _lastTrackedRound;
  String? _lastTrackedSpeaker;

  @override
  void dispose() {
    _phaseCountdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _phaseCountdownTimer?.cancel();
    _phaseCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_localCountdown > 0) {
        setState(() {
          _localCountdown--;
        });
      } else {
        timer.cancel();
        // Clôture du timer : l'hôte fait progresser automatiquement la phase
        final currentGameState = ref.read(gameNotifierProvider);
        final currentRoom = currentGameState.room;
        if (currentGameState.isHost &&
            currentRoom != null &&
            currentRoom.phase != GamePhase.gameOver &&
            currentRoom.phase != GamePhase.lobby) {
          ref.read(gameNotifierProvider.notifier).nextPhase();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameNotifierProvider);
    final room = gameState.room;

    // Synchronisation réactive du décompte de phase lors des transitions
    if (room != null) {
      if (_lastTrackedPhase != room.phase ||
          _lastTrackedRound != room.round ||
          _lastTrackedSpeaker != room.currentSpeakerId) {
        _lastTrackedPhase = room.phase;
        _lastTrackedRound = room.round;
        _lastTrackedSpeaker = room.currentSpeakerId;
        _localCountdown = room.timerSeconds > 0 ? room.timerSeconds : 40;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _startCountdown();
        });
      }
    }

    // Si la salle n'existe plus ou si le joueur a quitté
    if (room == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LobbyScreen()),
        );
      });
      return const Scaffold(
        backgroundColor: LupusColors.background,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(LupusColors.arcanePurple),
          ),
        ),
      );
    }

    final speakingUids = ref.watch(activeSpeakersProvider);
    final isMeAlive = gameState.isAlive;
    final myRole = gameState.myRole;
    final isNight = room.phase.isNight;
    final isMeEvil = myRole.isEvil || gameState.isAdmin;
    final revealRoles = room.phase == GamePhase.gameOver || gameState.isAdmin;

    return Scaffold(
      backgroundColor: LupusColors.background,
      body: Stack(
        children: [
          // 1. FOND ATMOSPHÉRIQUE STITCH (Village nocturne sous la pleine lune)
          Positioned.fill(
            child: LupusAssets.adaptiveImage(
              assetPath: LupusAssets.villageNightBgAsset,
              networkUrl: LupusAssets.villageNightBgUrl,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          ),

          // VIGNETTES ET BRUMES ARCANES STITCH
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF060A18).withValues(alpha: 0.92),
                    const Color(0xFF070B1D).withValues(alpha: 0.50),
                    const Color(0xFF04060E).withValues(alpha: 0.96),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.8,
                  colors: [
                    LupusColors.arcaneViolet.withValues(alpha: 0.14),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // 2. CONTENU PRINCIPAL
          SafeArea(
            child: Column(
              children: [
                // TOP HUD & NAVIGATION BAR (Fidèle à Stitch Screen 2)
                _buildStitchTopHUD(context, room, gameState),

                // SOUS-BARRE : BOUTON RÔLE & DÉCOMPTE (Stitch Sub-Bar)
                _buildStitchSubBar(
                  context,
                  myRole,
                  isMeAlive,
                  _localCountdown,
                  isNight,
                  gameState,
                ),

                // BANNIÈRE D'ANNONCE DE PHASE (Stitch Phase Banner)
                _buildStitchPhaseBanner(room, gameState, isMeEvil, myRole),

                // MINI-TICKER : DERNIER ÉVÉNEMENT COMPACT (cliquable pour ouvrir les chroniques)
                _buildMiniTicker(context, room.logs, room.roomCode),

                // SÉLECTEUR DE VUE : TABLE MYSTIQUE RADIALE vs GRILLE BENTO
                _buildViewModeToggle(),
                const SizedBox(height: 4),

                // ZONE CENTRALE (EXPANDED) : TABLE MYSTIQUE OU GRILLE BENTO (Zéro Scroll)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: _useRadialView
                        ? Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: MysticRadialTable(
                                players: room.playerList,
                                selectedPlayerId: _selectedPlayerId,
                                currentUserId: gameState.currentUserId,
                                speakingAgoraUids: speakingUids,
                                currentSpeakerId: room.currentSpeakerId,
                                revealRoles: revealRoles,
                                isMeEvil: isMeEvil,
                                voteCounts: room.voteCounts,
                                captainTargetVoteId: room.captainTargetVoteId,
                                centerActionTitle: _getTargetActionTitle(
                                  room.phase,
                                  room,
                                ),
                                centerActionSubtitle: _getTargetActionSubtitle(
                                  room.phase,
                                  room,
                                ),
                                onPlayerSelected: (id) {
                                  setState(() {
                                    _selectedPlayerId =
                                        (_selectedPlayerId == id) ? null : id;
                                  });
                                },
                              ),
                            ),
                          )
                        : BentoPlayerGrid(
                            players: room.playerList,
                            currentUserId: gameState.currentUserId,
                            speakingAgoraUids: speakingUids,
                            currentSpeakerId: room.currentSpeakerId,
                            selectedPlayerId: _selectedPlayerId,
                            revealRoles: revealRoles,
                            isMeEvil: isMeEvil,
                            onPlayerSelected: (id) {
                              setState(() {
                                _selectedPlayerId =
                                    (_selectedPlayerId == id) ? null : id;
                              });
                            },
                          ),
                  ),
                ),

                // BAS : ACTIONS STRATÉGIQUES & CONTRÔLES VOCAUX (Zero-Scroll, toujours visibles)
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // PANNEAU D'ACTIONS STRATÉGIQUES STITCH
                        BentoActionPanel(
                          room: room,
                          currentUserId: gameState.currentUserId,
                          selectedTargetId: _selectedPlayerId,
                          inspectedRole: gameState.inspectedRole,
                          isHost: gameState.isHost,
                          isAdmin: gameState.isAdmin,
                          onNextPhase: () => ref
                              .read(gameNotifierProvider.notifier)
                              .nextPhase(),
                          onVote: (targetId) => ref
                              .read(gameNotifierProvider.notifier)
                              .castVote(targetId),
                          onInspect: (targetId) => ref
                              .read(gameNotifierProvider.notifier)
                              .inspectPlayer(targetId),
                          onCompleteSeerTurn: () => ref
                              .read(gameNotifierProvider.notifier)
                              .completeSeerTurn(),
                          onWitchSave: () => ref
                              .read(gameNotifierProvider.notifier)
                              .witchSaveVictim(),
                          onWitchPoison: (targetId) => ref
                              .read(gameNotifierProvider.notifier)
                              .witchPoison(targetId),
                          onWitchPass: () => ref
                              .read(gameNotifierProvider.notifier)
                              .witchPass(),
                          onDefenderProtect: (targetId) => ref
                              .read(gameNotifierProvider.notifier)
                              .defenderProtect(targetId),
                          onCupidBind: (p1, p2) => ref
                              .read(gameNotifierProvider.notifier)
                              .cupidBindLovers(p1, p2),
                          onThiefSteal: (targetId) => ref
                              .read(gameNotifierProvider.notifier)
                              .thiefSteal(targetId),
                          onHunterShoot: (targetId) => ref
                              .read(gameNotifierProvider.notifier)
                              .hunterShoot(targetId),
                          onCaptainPass: (targetId) => ref
                              .read(gameNotifierProvider.notifier)
                              .captainPassBadge(targetId),
                          onPyromaniacDouse: (targetId) => ref
                              .read(gameNotifierProvider.notifier)
                              .pyromaniacDouse(targetId),
                          onPyromaniacIgnite: () => ref
                              .read(gameNotifierProvider.notifier)
                              .pyromaniacIgnite(),
                          onPyromaniacPass: () => ref
                              .read(gameNotifierProvider.notifier)
                              .pyromaniacPass(),
                          onPassDebate: () => ref
                              .read(gameNotifierProvider.notifier)
                              .passTurnDebate(),
                        ),
                        const SizedBox(height: 4),

                        // CONTRÔLES VOCAUX AGORA
                        BentoVoiceControls(
                          isAlive: isMeAlive,
                          isCurrentSpeaker:
                              room.currentSpeakerId == gameState.currentUserId,
                          currentSpeakerName: room.currentSpeakerId != null
                              ? room.players[room.currentSpeakerId]?.name
                              : null,
                          phase: room.phase,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // OVERLAY DE FIN DE PARTIE
          if (room.phase == GamePhase.gameOver)
            _buildGameOverOverlay(context, room.winner),
        ],
      ),
    );
  }

  /// Top HUD & Navigation Bar conforme au design Stitch
  Widget _buildStitchTopHUD(
    BuildContext context,
    dynamic room,
    dynamic gameState,
  ) {
    final isNight = (room.phase as GamePhase).isNight;
    final myRole = gameState.myRole is GameRole
        ? gameState.myRole as GameRole
        : GameRole.simpleVillager;
    final isMeAlive = gameState.isAlive as bool? ?? true;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Bouton Fermer circulaire en verre
          GestureDetector(
            onTap: () => _confirmLeave(context),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xC012182E),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 18,
                color: LupusColors.textSecondary,
              ),
            ),
          ),

          // Centre : Titre Fantasy et Code de Salle (Déclencheur Secret Admin: Long press ou Double tap)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPress: () => _openAdminTrigger(context),
            onDoubleTap: () => _openAdminTrigger(context),
            child: Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: LupusTheme.glowPurple(opacity: 0.45),
                        border: Border.all(
                          color: LupusColors.arcaneGold.withValues(alpha: 0.5),
                          width: 0.8,
                        ),
                      ),
                      child: ClipOval(
                        child: LupusAssets.adaptiveImage(
                          assetPath: LupusAssets.wolfSealAsset,
                          networkUrl: LupusAssets.wolfSealUrl,
                          fit: BoxFit.cover,
                          placeholder: const Text(
                            '🐺',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    const Text(
                      'LUPUS ARENA',
                      style: TextStyle(
                        fontFamily: 'serif',
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                    if (gameState.isAdmin as bool) ...[
                      const SizedBox(width: 5),
                      const Text('👑', style: TextStyle(fontSize: 12)),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Builder(
                  builder: (_) {
                    final isWolfVoice =
                        (gameState.isWolfVoiceChannel == true) ||
                        ((room.phase as GamePhase) ==
                                GamePhase.nightWerewolves &&
                            ((gameState.myRole as GameRole).isEvil ||
                                (gameState.isAdmin as bool)));
                    final isAdmin = gameState.isAdmin as bool;

                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: isWolfVoice
                            ? const Color(0xCC7F1D1D)
                            : (isAdmin
                                  ? const Color(0xFF422006)
                                  : const Color(0x991E1B4B)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isWolfVoice
                              ? const Color(0xFFFF2A4B)
                              : (isAdmin
                                    ? LupusColors.arcaneGold
                                    : LupusColors.arcanePurple.withValues(
                                        alpha: 0.4,
                                      )),
                          width: isWolfVoice ? 1.2 : 0.8,
                        ),
                        boxShadow: isWolfVoice
                            ? [
                                BoxShadow(
                                  color: const Color(0xFFFF2A4B)
                                      .withValues(alpha: 0.4),
                                  blurRadius: 8,
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isWolfVoice) ...[
                            const Text('🐺', style: TextStyle(fontSize: 10)),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            isWolfVoice
                                ? '#${room.roomCode} • CANAL MEUTE'
                                : '#${room.roomCode}',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                              color: isWolfVoice
                                  ? const Color(0xFFFFE4E6)
                                  : (isAdmin
                                        ? LupusColors.arcaneGold
                                        : const Color(0xFFC7D2FE)),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Côté Droit : Pilule Nuit/Jour & Cœur Amoureux / Orbe
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isNight
                      ? const Color(0x99450A0A)
                      : const Color(0x99422006),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isNight
                        ? LupusColors.arcaneCrimson.withValues(alpha: 0.5)
                        : LupusColors.arcaneGold.withValues(alpha: 0.5),
                  ),
                  boxShadow: isNight
                      ? LupusTheme.glowRed(opacity: 0.3)
                      : LupusTheme.glowGold(opacity: 0.3),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isNight
                            ? LupusColors.arcaneCrimson
                            : LupusColors.arcaneGold,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isNight ? 'NUIT' : 'JOUR',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                        color: isNight
                            ? const Color(0xFFFECDD3)
                            : const Color(0xFFFEF08A),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Bouton Parchemin / Journal des Chroniques avec Badge de notification
              Builder(
                builder: (_) {
                  final logList = (room.logs is List) ? (room.logs as List) : const [];
                  final unreadCount = (logList.length - _lastSeenLogCount).clamp(0, 999);

                  return GestureDetector(
                    onTap: () => _openChroniclesBottomSheet(
                      context,
                      List<String>.from((room.logs as Iterable?) ?? const []),
                      room.roomCode.toString(),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xC012182E),
                            border: Border.all(
                              color: LupusColors.arcaneGold.withValues(alpha: 0.5),
                              width: 1.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: LupusColors.arcaneGold.withValues(alpha: 0.2),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              '📜',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                        if (unreadCount > 0)
                          Positioned(
                            top: -3,
                            right: -3,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: LupusColors.arcaneCrimson,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Center(
                                child: Text(
                                  unreadCount > 99 ? '99+' : '$unreadCount',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),

              // Orbe joueur / amoureux (cliquable pour consulter sa carte)
              GestureDetector(
                onTap: () =>
                    _showSecretRoleModal(context, myRole, isMeAlive, gameState),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFDE68A), Color(0xFFFDA4AF)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(1.5),
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF1B172A),
                    ),
                    child: Center(
                      child: Text(
                        gameState.isLover
                            ? '💖'
                            : (gameState.isCaptain ? '⭐' : '🛡️'),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Sous-barre Stitch : Bouton Mon Rôle compact & Minuteur de tour
  Widget _buildStitchSubBar(
    BuildContext context,
    dynamic myRole,
    bool isMeAlive,
    int timerSeconds,
    bool isNight,
    dynamic gameState,
  ) {
    final role = myRole is GameRole ? myRole : GameRole.simpleVillager;
    final accentColor = role.accentColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Petit bouton compact Bento "MON RÔLE"
          GestureDetector(
            onTap: () =>
                _showSecretRoleModal(context, role, isMeAlive, gameState),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xE012182E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.5),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield_outlined, size: 14, color: accentColor),
                  const SizedBox(width: 5),
                  Text(
                    'MON RÔLE',
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: accentColor,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Minuteur de tour réactif avec halo ambré / alerte écarlate sous 10s
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: timerSeconds <= 10
                  ? const Color(0xE0280707)
                  : const Color(0xE005070F),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: timerSeconds <= 10
                    ? LupusColors.arcaneCrimson
                    : LupusColors.arcaneGold.withValues(alpha: 0.4),
                width: timerSeconds <= 10 ? 1.5 : 1.0,
              ),
              boxShadow: timerSeconds <= 10
                  ? LupusTheme.glowCrimson(opacity: 0.55)
                  : LupusTheme.glowGold(opacity: 0.2),
            ),
            child: Row(
              children: [
                Text(
                  timerSeconds <= 10 ? '⏳' : (isNight ? '🌙' : '☀️'),
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(width: 6),
                Text(
                  '${timerSeconds}s',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                    color: timerSeconds <= 10
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
  }

  /// Bannière d'annonce de phase selon le design Stitch
  Widget _buildStitchPhaseBanner(
    dynamic room,
    dynamic gameState,
    bool isMeEvil,
    dynamic myRole,
  ) {
    final phase = room.phase as GamePhase;
    final title = _getPhaseTitle(phase);
    final subtitle = _getPhaseSubtitle(phase);
    final phaseChip =
        '${phase.isNight ? "Phase Nuit" : "Phase Jour"} • Tour ${room.round}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'serif',
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: LupusColors.arcanePurple.withValues(alpha: 0.8),
                  blurRadius: 14,
                ),
              ],
            ),
          ),
          const SizedBox(height: 1),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontStyle: FontStyle.italic,
              fontSize: 11,
              color: Color(0xFFC7D2FE),
            ),
          ),

          // Alerte Notification Canal Privé des Loups-Garous (sans overflow)
          if (phase == GamePhase.nightWerewolves) ...[
            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isMeEvil
                      ? [const Color(0xDD7F1D1D), const Color(0xDD3F0B0B)]
                      : [const Color(0xCC0F172A), const Color(0xCC1E1B4B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isMeEvil
                      ? const Color(0xFFFF2A4B)
                      : const Color(0xFF6366F1),
                  width: 1.2,
                ),
                boxShadow: isMeEvil
                    ? [
                        BoxShadow(
                          color: const Color(0xFFFF2A4B)
                              .withValues(alpha: 0.35),
                          blurRadius: 10,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isMeEvil
                          ? const Color(0xFFB91C1C)
                          : const Color(0xFF312E81),
                      border: Border.all(
                        color: isMeEvil
                            ? const Color(0xFFFF4D6D)
                            : const Color(0xFF818CF8),
                        width: 1.0,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        isMeEvil
                            ? '🐺'
                            : (myRole == GameRole.littleGirl ? '👀' : '🌙'),
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isMeEvil
                                    ? const Color(0xFF00FF88)
                                    : const Color(0xFF94A3B8),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                isMeEvil
                                    ? 'CANAL PRIVÉ DE LA MEUTE (ACTIF)'
                                    : (myRole == GameRole.littleGirl
                                          ? 'PETITE FILLE : ESPIONNAGE DU CANAL'
                                          : 'NUIT DES LOUPS • VILLAGE SILENCIEUX'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.6,
                                  color: isMeEvil
                                      ? const Color(0xFFFFE4E6)
                                      : (myRole == GameRole.littleGirl
                                            ? const Color(0xFFF3E8FF)
                                            : const Color(0xFFE2E8F0)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isMeEvil
                              ? 'Micro ouvert entre loups. Échangez en direct.'
                              : (myRole == GameRole.littleGirl
                                    ? 'Vous entendez les loups en secret !'
                                    : 'Les loups complotent dans le noir.'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9.5,
                            color: isMeEvil
                                ? const Color(0xFFFECDD3)
                                : (myRole == GameRole.littleGirl
                                      ? const Color(0xFFD8B4FE)
                                      : const Color(0xFF94A3B8)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isMeEvil
                          ? const Color(0x80000000)
                          : const Color(0x50000000),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isMeEvil
                            ? const Color(0xFFFF2A4B)
                            : const Color(0xFF64748B),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isMeEvil
                              ? (gameState.isMuted
                                    ? Icons.mic_off_rounded
                                    : Icons.mic_rounded)
                              : Icons.mic_off_rounded,
                          size: 11,
                          color: isMeEvil
                              ? (gameState.isMuted
                                    ? Colors.redAccent
                                    : const Color(0xFF00FF88))
                              : const Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          isMeEvil
                              ? (gameState.isMuted ? 'MUET' : 'OUVERT')
                              : 'MUET',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: isMeEvil
                                ? (gameState.isMuted
                                      ? Colors.redAccent
                                      : const Color(0xFF00FF88))
                                : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Alerte Victime des Loups pour la Sorcière
          if (phase == GamePhase.nightWitch) ...[
            Builder(
              builder: (_) {
                final victimId = room.nightVictimId;
                final victim = victimId != null ? room.players[victimId] : null;
                final isHealed = room.witchHealed == true;
                if (victim == null) return const SizedBox.shrink();
                return Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isHealed
                        ? const Color(0x33059669)
                        : const Color(0x4DDC2626),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isHealed
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isHealed ? '✨' : '🩸',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isHealed
                            ? 'Victime ${victim.name} sauvée par votre potion !'
                            : 'Victime des Loups : ${victim.name} (À l\'agonie !)',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: isHealed
                              ? const Color(0xFF6EE7B7)
                              : const Color(0xFFFECDD3),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1.5),
            decoration: BoxDecoration(
              color: const Color(0x991E1B4B),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: LupusColors.arcanePurple.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              phaseChip.toUpperCase(),
              style: const TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: Color(0xFFA5B4FC),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Mini-Ticker compact affichant uniquement le dernier log du village
  Widget _buildMiniTicker(
    BuildContext context,
    List<String> logs,
    String roomCode,
  ) {
    if (logs.isEmpty) return const SizedBox.shrink();
    final latestLog = logs.last;

    return GestureDetector(
      onTap: () => _openChroniclesBottomSheet(context, logs, roomCode),
      child: Container(
        height: 26,
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xB0080D1A),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: LupusColors.arcaneGold.withValues(alpha: 0.35),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 4,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📜', style: TextStyle(fontSize: 11)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                latestLog,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: LupusColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 9,
              color: LupusColors.arcaneGold,
            ),
          ],
        ),
      ),
    );
  }

  /// Sélecteur de vue (Table Mystique vs Grille Bento)
  Widget _buildViewModeToggle() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: const Color(0xC00A0F1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => setState(() => _useRadialView = true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _useRadialView
                      ? LupusColors.arcanePurple.withValues(alpha: 0.35)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(13),
                  border: _useRadialView
                      ? Border.all(
                          color: LupusColors.arcanePurple.withValues(
                            alpha: 0.6,
                          ),
                        )
                      : null,
                ),
                child: const Row(
                  children: [
                    Text('⭕', style: TextStyle(fontSize: 11)),
                    SizedBox(width: 5),
                    Text(
                      'Table Mystique',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _useRadialView = false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: !_useRadialView
                      ? LupusColors.arcanePurple.withValues(alpha: 0.35)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(13),
                  border: !_useRadialView
                      ? Border.all(
                          color: LupusColors.arcanePurple.withValues(
                            alpha: 0.6,
                          ),
                        )
                      : null,
                ),
                child: const Row(
                  children: [
                    Text('▦', style: TextStyle(fontSize: 11)),
                    SizedBox(width: 5),
                    Text(
                      'Grille Bento',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Titres et sous-titres adaptés à chaque phase canonique
  String _getPhaseTitle(GamePhase phase) {
    switch (phase) {
      case GamePhase.nightThief:
        return 'Le Voleur Rode';
      case GamePhase.nightCupid:
        return 'Les Flèches de Cupidon';
      case GamePhase.nightDefender:
        return 'La Bénédiction du Salvateur';
      case GamePhase.nightSeer:
        return 'L\'Œil de la Voyante';
      case GamePhase.nightWerewolves:
        return 'La Nuit Tombe';
      case GamePhase.nightWitch:
        return 'Les Chaudrons de la Sorcière';
      case GamePhase.nightPyromaniac:
        return 'Le Brasier du Pyromane';
      case GamePhase.morningAnnouncement:
        return 'L\'Aube se Lève';
      case GamePhase.hunterDeathChoice:
        return 'Le Dernier Souffle du Chasseur';
      case GamePhase.captainSuccession:
        return 'Succession du Capitaine';
      case GamePhase.captainElection:
        return 'Élection du Capitaine';
      case GamePhase.dayDebate:
        return 'Le Débat du Village';
      case GamePhase.dayVoting:
        return 'L\'Heure du Jugement';
      case GamePhase.dayDefense:
        return 'Ultime Plaidoyer';
      case GamePhase.dayTieBreakVote:
        return 'Vote Décisif de l\'Égalité';
      case GamePhase.dayResolution:
        return 'Le Verdict Tombe';
      case GamePhase.gameOver:
        return 'Fin de Partie';
      case GamePhase.lobby:
        return 'Lobby';
    }
  }

  String _getPhaseSubtitle(GamePhase phase) {
    switch (phase) {
      case GamePhase.nightCupid:
        return 'Cupidon unit deux destins d\'un amour éternel';
      case GamePhase.nightWerewolves:
        return 'sur le village endormi de Thiercelieux';
      case GamePhase.dayVoting:
      case GamePhase.dayTieBreakVote:
        return 'Les villageois votent • La voix du Maire compte double (2 voix)';
      case GamePhase.captainElection:
        return 'Élisez le Maire du village dont la voix comptera double';
      case GamePhase.dayDebate:
        return 'Écoutez attentivement le joueur qui a la parole';
      case GamePhase.nightSeer:
        return 'Découvrez la véritable allégeance d\'une âme';
      case GamePhase.nightDefender:
        return 'Désignez un villageois immunisé cette nuit';
      case GamePhase.nightWitch:
        return 'Une potion de vie, une fiole de mort';
      case GamePhase.nightPyromaniac:
        return 'Aspergez un foyer d\'essence ou embrasez le village';
      case GamePhase.morningAnnouncement:
        return 'Le village découvre le bilan des attaques nocturnes';
      default:
        return 'Restez sur vos gardes dans l\'arène';
    }
  }

  String _getTargetActionTitle(GamePhase phase, dynamic room) {
    if (phase == GamePhase.nightWerewolves) return 'PROIE';
    if (phase == GamePhase.nightWitch) return 'VICTIME';
    if (phase == GamePhase.nightPyromaniac) return 'FOYER';
    if (phase == GamePhase.nightCupid) return 'AMANT';
    if (phase == GamePhase.dayVoting || phase == GamePhase.dayTieBreakVote) {
      return 'ACCUSÉ';
    }
    if (phase == GamePhase.nightSeer) return 'SONDÉ';
    if (phase == GamePhase.nightDefender) return 'PROTÉGÉ';
    if (phase == GamePhase.captainElection) return 'CANDIDAT';
    return 'CIBLE';
  }

  String _getTargetActionSubtitle(GamePhase phase, dynamic room) {
    if (phase == GamePhase.nightWitch && room.nightVictimId != null) {
      final victim = room.players[room.nightVictimId];
      if (victim != null) {
        return '${victim.name} (${room.witchHealed == true ? "Sauvé(e)" : "Mordu(e)"})';
      }
    }
    if (phase == GamePhase.nightWerewolves) return 'En délibération';
    if (phase == GamePhase.dayVoting) return 'Aucun vote émis';
    return 'Aucune cible';
  }

  /// Carte modale centrée (Dialog / Pop-up) au format tarot compact
  void _showSecretRoleModal(
    BuildContext context,
    dynamic myRole,
    bool isAlive,
    dynamic gameState,
  ) {
    final role = myRole is GameRole ? myRole : GameRole.simpleVillager;
    final color = role.accentColor;
    final isEvil = role.isEvil;
    final teamName = isEvil
        ? 'CAMP DE LA MEUTE'
        : (role.defaultTeam == Team.solo
              ? 'CAMP SOLITAIRE'
              : 'CAMP DU VILLAGE');
    final teamColor = isEvil
        ? LupusColors.arcaneCrimson
        : (role.defaultTeam == Team.solo
              ? const Color(0xFFE11D48)
              : const Color(0xFF38BDF8));

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 320),
            decoration: BoxDecoration(
              color: const Color(0xF5151C33), // #151C33 sombre translucide
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: color.withValues(alpha: 0.65),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 24,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.7),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Barre supérieure de la carte : Badge et bouton fermer
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 12, 10),
                    decoration: BoxDecoration(
                      color: const Color(0x600B0F1D),
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.shield_rounded, size: 14, color: color),
                            const SizedBox(width: 6),
                            const Text(
                              'VOTRE RÔLE SECRET',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1,
                                color: Color(0xFFC7D2FE),
                              ),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () => Navigator.of(ctx).pop(),
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: LupusColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Contenu principal de la carte de tarot
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Illustration grand format avec coins arrondis et ombre
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: color.withValues(alpha: 0.5),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: color.withValues(alpha: 0.35),
                                blurRadius: 14,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(13),
                            child: RoleCardImage(
                              role: role,
                              width: 120,
                              height: 160,
                              fit: BoxFit.cover,
                              showGlow: false,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Nom officiel du rôle en gras
                        Text(
                          role.displayNameFr,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'serif',
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: color.withValues(alpha: 0.8),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Badge du Camp (Villageois, Meute, Solo)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3.5,
                          ),
                          decoration: BoxDecoration(
                            color: teamColor.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: teamColor.withValues(alpha: 0.6),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isEvil
                                    ? '🐺 '
                                    : (role.defaultTeam == Team.solo
                                          ? '✨ '
                                          : '🛡️ '),
                                style: const TextStyle(fontSize: 10.5),
                              ),
                              Text(
                                teamName,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: teamColor,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Badges spéciaux contextuels (Capitaine, Amoureux, Mort)
                        if (gameState != null &&
                            ((gameState.isCaptain as bool? ?? false) ||
                                (gameState.isLover as bool? ?? false) ||
                                !isAlive)) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            alignment: WrapAlignment.center,
                            children: [
                              if (gameState.isCaptain as bool? ?? false)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0x33F59E0B),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFFF59E0B),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: const Text(
                                    '⭐ Capitaine (Voix double)',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFFFDE68A),
                                    ),
                                  ),
                                ),
                              if (gameState.isLover as bool? ?? false)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0x33EC4899),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFFEC4899),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    '💖 Âme sœur : ${gameState.loverName ?? "Inconnu"}',
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFFFBCFE8),
                                    ),
                                  ),
                                ),
                              if (!isAlive)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0x33DC2626),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFFDC2626),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: const Text(
                                    '💀 Éliminé(e)',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFFFECDD3),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),

                        // Courte description des pouvoirs du rôle
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.28),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Text(
                            role.descriptionFr.isNotEmpty
                                ? role.descriptionFr
                                : role.description,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11,
                              height: 1.35,
                              color: Color(0xFFCBD5E1),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Bouton Compris / Replier
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: color.withValues(alpha: 0.25),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: color.withValues(alpha: 0.7),
                                  width: 1.2,
                                ),
                              ),
                              elevation: 0,
                            ),
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text(
                              'Compris / Replier',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Overlay de victoire finale
  Widget _buildGameOverOverlay(BuildContext context, String? winner) {
    final isWolvesWin = winner == 'werewolves';
    final accent = isWolvesWin
        ? LupusColors.arcaneCrimson
        : LupusColors.arcaneCyan;

    return Container(
      color: Colors.black.withValues(alpha: 0.88),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: BentoCard(
        borderColor: accent,
        glowing: true,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isWolvesWin ? Icons.pets_rounded : Icons.shield_rounded,
              color: accent,
              size: 56,
            ),
            const SizedBox(height: 16),
            Text(
              isWolvesWin
                  ? 'VICTOIRE DES LOUPS-GAROUS !'
                  : 'VICTOIRE DU VILLAGE !',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'serif',
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
                color: accent,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              isWolvesWin
                  ? 'Les ombres ont dévoré la totalité des âmes de l\'arène.'
                  : 'La lumière triomphe ! Tous les loups-garous ont été démasqués.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: LupusColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () {
                ref.read(gameNotifierProvider.notifier).leaveRoom();
              },
              child: const Text(
                'REVENIR AU SALON',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmLeave(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LupusColors.surface,
        title: const Text(
          'Quitter la partie ?',
          style: TextStyle(color: LupusColors.textPrimary),
        ),
        content: const Text(
          'Voulez-vous vraiment quitter l\'arène et le vocal en cours ?',
          style: TextStyle(color: LupusColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: LupusColors.arcaneCrimson,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(gameNotifierProvider.notifier).leaveRoom();
            },
            child: const Text('Quitter'),
          ),
        ],
      ),
    );
  }

  void _openAdminTrigger(BuildContext context) {
    final isAdmin = ref.read(gameNotifierProvider).isAdmin;
    if (isAdmin) {
      AdminControlSheet.show(context);
    } else {
      AdminSecretDialog.show(context);
    }
  }

  /// Déporte et ouvre les Chroniques du Village dans un Modal BottomSheet Glassmorphism
  void _openChroniclesBottomSheet(
    BuildContext context,
    List<String> logs,
    String roomCode,
  ) {
    setState(() {
      _lastSeenLogCount = logs.length;
    });

    VillageChroniclesScreen.show(context, logs, roomCode);
  }
}
