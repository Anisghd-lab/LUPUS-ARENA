import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../AgoraVoiceService.dart';
import '../../GameNotifier.dart';
import '../../models/game_phase.dart';
import '../../models/game_room.dart';
import '../../models/player_model.dart';
import '../admin/admin_control_sheet.dart';
import '../admin/admin_secret_dialog.dart';
import '../bento/bento_action_panel.dart';
import '../bento/bento_player_grid.dart';
import '../bento/bento_voice_controls.dart';
import '../bento/mystic_radial_table.dart';
import '../bento/revealed_death_card_overlay.dart';
import '../bento/role_card_image.dart';
import '../bento/server_countdown_timer.dart';
import '../theme/lupus_assets.dart';
import '../theme/lupus_theme.dart';
import '../../services/app_translations.dart';
import '../../services/audio_manager.dart';
import '../../services/locale_provider.dart';
import '../../services/server_time_service.dart';
import '../../services/death_registry_service.dart';
import '../bento/language_dialog.dart';
import 'game_over_screen.dart';
import 'lobby_screen.dart';
import 'village_chronicles_screen.dart';

/// Widget dédié et totalement isolé pour l'affichage du compte à rebours du tour.
/// Encapsulé dans un RepaintBoundary avec ValueListenableBuilder pour éliminer
/// tout rebuild et tout repaint de l'arbre de widgets parent (Arène, Table, Joueurs, Shaders).
class CountdownTimerBadge extends StatelessWidget {
  final ValueListenable<int> countdownListenable;
  final bool isNight;

  const CountdownTimerBadge({
    super.key,
    required this.countdownListenable,
    required this.isNight,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ValueListenableBuilder<int>(
        valueListenable: countdownListenable,
        builder: (context, timerSeconds, child) {
          final isUrgent = timerSeconds <= 10;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isUrgent
                  ? const Color(0xE0280707)
                  : const Color(0xE005070F),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isUrgent
                    ? LupusColors.arcaneCrimson
                    : LupusColors.arcaneGold.withValues(alpha: 0.4),
                width: isUrgent ? 1.5 : 1.0,
              ),
              boxShadow: isUrgent
                  ? LupusTheme.glowCrimson(opacity: 0.55)
                  : LupusTheme.glowGold(opacity: 0.2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isUrgent ? '⏳' : (isNight ? '🌙' : '☀️'),
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
    );
  }
}

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
  bool _isLeavingOrNavigating = false;

  // Gestion du journal et badge de notification des Chroniques
  int _lastSeenLogCount = 0;

  // Notifier réactif du compte à rebours (alimenté de façon pure par ServerCountdownTimerBadge)
  final ValueNotifier<int> _countdownNotifier = ValueNotifier<int>(40);
  GamePhase? _lastTrackedPhase;
  int? _lastTrackedRound;
  String? _lastTrackedSpeaker;

  // File d'attente cinématique 3D d'annonce des morts (centre de la table mystique)
  final List<DeathAnnouncementEvent> _deathQueue = [];
  final Set<String> _processedDeathKeys = {};

  // Minute vocale collective à la victoire (60 secondes)
  Timer? _victoryVoiceTimer;
  final ValueNotifier<int> _victoryVoiceCountdownNotifier =
      ValueNotifier<int>(60);
  bool _victoryVoiceStarted = false;

  @override
  void initState() {
    super.initState();
    LupusAudioManager.instance.stopLobbyMusic();
  }

  void _checkAndQueueDeathAnnouncements(GameRoom room) {
    bool hasNewDeaths = false;

    // 1. Source PRIORITAIRE : deathAnnouncementQueue (file ordonnée des défunts)
    if (room.deathAnnouncementQueue.isNotEmpty) {
      for (final entry in room.deathAnnouncementQueue) {
        final pid = (entry['joueurId'] ?? entry['playerId'] ?? '').toString();
        if (pid.isEmpty) continue;
        final cause = (entry['cause'] ?? '').toString();
        final key = '${pid}_${cause}_${room.round}';
        if (!_processedDeathKeys.contains(key) &&
            !_processedDeathKeys.contains('${pid}_${room.round}') &&
            !_deathQueue.any((e) => e.playerId == pid)) {
          _processedDeathKeys.add(key);
          _processedDeathKeys.add('${pid}_${room.round}');
          _deathQueue.add(DeathAnnouncementEvent.fromMap(entry));
          hasNewDeaths = true;
        }
      }
    }
    // 2. Source SECONDAIRE : morningVictims (uniquement si deathAnnouncementQueue est vide)
    else if (room.phase == GamePhase.morningAnnouncement && room.morningVictims.isNotEmpty) {
      for (final victimId in room.morningVictims) {
        if (victimId.isEmpty) continue;
        final player = room.players[victimId];
        if (player != null) {
          final cause = (victimId == room.witchPoisonVictimId)
              ? 'POISON_SORCIERE'
              : 'MORSURE_LOUPS';
          final key = '${victimId}_${cause}_${room.round}';
          if (!_processedDeathKeys.contains(key) &&
              !_processedDeathKeys.contains('${victimId}_${room.round}') &&
              !_deathQueue.any((e) => e.playerId == victimId)) {
            _processedDeathKeys.add(key);
            _processedDeathKeys.add('${victimId}_${room.round}');
            final role = (player.roleInitial != GameRole.simpleVillager)
                ? player.roleInitial
                : player.role;
            _deathQueue.add(DeathAnnouncementEvent(
              playerId: victimId,
              playerName: player.name,
              role: role,
              cause: cause,
            ));
            hasNewDeaths = true;
          }
        }
      }
    }
    // 3. Source TERTIAIRE : lastDeathFlip (pour les éliminations unitaires isolées)
    else if (room.lastDeathFlip != null && room.lastDeathFlip is Map) {
      final flip = room.lastDeathFlip as Map;
      final pid = (flip['joueurId'] ?? flip['playerId'] ?? '').toString();
      if (pid.isNotEmpty) {
        final cause = (flip['cause'] ?? '').toString();
        final key = '${pid}_${cause}_${room.round}';
        if (!_processedDeathKeys.contains(key) &&
            !_processedDeathKeys.contains('${pid}_${room.round}') &&
            !_deathQueue.any((e) => e.playerId == pid)) {
          _processedDeathKeys.add(key);
          _processedDeathKeys.add('${pid}_${room.round}');
          _deathQueue.add(DeathAnnouncementEvent.fromMap(flip));
          hasNewDeaths = true;
        }
      }
    }

    if (hasNewDeaths && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _countdownNotifier.dispose();
    _victoryVoiceTimer?.cancel();
    _victoryVoiceCountdownNotifier.dispose();
    if (ref.read(gameNotifierProvider).room == null) {
      LupusAudioManager.instance.playLobbyMusic();
    }
    super.dispose();
  }

  /// Déclenche un canal vocal ouvert à tous les joueurs (morts et vivants) pendant 60 secondes
  void _startVictoryVoiceCountdown() {
    _victoryVoiceTimer?.cancel();
    _victoryVoiceCountdownNotifier.value = 60;
    ref.read(gameNotifierProvider.notifier).setVictoryVoiceExpired(false);
    AgoraVoiceService().setMute(false);

    _victoryVoiceTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_victoryVoiceCountdownNotifier.value > 0) {
        _victoryVoiceCountdownNotifier.value--;
      } else {
        timer.cancel();
        // Clôture de la minute vocale collective : coupe le micro de tous les joueurs
        AgoraVoiceService().setMute(true);
        ref.read(gameNotifierProvider.notifier).setVictoryVoiceExpired(true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameNotifierProvider);
    final room = gameState.room;

    // Synchronisation réactive du décompte de phase lors des transitions
    if (room != null) {
      if (room.phase == GamePhase.lobby) {
        _deathQueue.clear();
        _processedDeathKeys.clear();
      } else {
        _checkAndQueueDeathAnnouncements(room);
      }

      if (room.phase == GamePhase.gameOver) {
        if (!_victoryVoiceStarted) {
          _victoryVoiceStarted = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _startVictoryVoiceCountdown();
          });
        }
      } else {
        if (_victoryVoiceStarted) {
          _victoryVoiceStarted = false;
          _victoryVoiceTimer?.cancel();
          _victoryVoiceCountdownNotifier.value = 60;
        }
      }

      if (_lastTrackedPhase != room.phase ||
          _lastTrackedRound != room.round ||
          _lastTrackedSpeaker != room.currentSpeakerId) {
        // Réinitialisation stricte de la cible à chaque transition de phase (Jour <-> Nuit)
        if (_lastTrackedPhase != room.phase || _lastTrackedRound != room.round) {
          _selectedPlayerId = null;
          // Synchronisation immédiate du notifier de décompte pour éliminer toute latence visuelle
          final initialRemaining = ServerTimeService().calculateRemainingSeconds(
            room.phaseEndsAt,
            fallbackSeconds: room.timerSeconds > 0
                ? room.timerSeconds
                : (room.phase.isNight ? 40 : 15),
          );
          _countdownNotifier.value = initialRemaining;
        }
        _lastTrackedPhase = room.phase;
        _lastTrackedRound = room.round;
        _lastTrackedSpeaker = room.currentSpeakerId;
      }

      // Dépouillement anticipé dès que tous les vivants ont voté pendant dayVoting
      if (room.phase == GamePhase.dayVoting &&
          room.alivePlayers.isNotEmpty &&
          room.alivePlayers.every((p) => p.targetVoteId != null)) {
        _countdownNotifier.value = 0;
      }
    }

    // Si la salle n'existe plus ou si la partie est revenue au lobby
    if (room == null || room.phase == GamePhase.lobby) {
      if (!_isLeavingOrNavigating) {
        _isLeavingOrNavigating = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const LobbyScreen()),
            );
          }
        });
      }
      return const Scaffold(
        backgroundColor: LupusColors.background,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(LupusColors.arcanePurple),
          ),
        ),
      );
    }
    final isMeAlive = gameState.isAlive;
    final myRole = gameState.myRole;
    final isNight = room.phase.isNight;
    final isDevModeActive = gameState.isDevModeActive;
    final isDevRoom = room.isDevRoom;
    final isDevMode = isDevModeActive || isDevRoom || gameState.isAdmin;
    final isMeEvil = myRole.isEvil || isDevMode;
    final revealRoles = room.phase == GamePhase.gameOver || isDevMode;

    return Scaffold(
      backgroundColor: LupusColors.background,
      body: Stack(
        children: [
          // 1. FOND ATMOSPHÉRIQUE STITCH (Isolé dans un RepaintBoundary pour mise en cache GPU)
          Positioned.fill(
            child: RepaintBoundary(
              child: LupusAssets.adaptiveImage(
                assetPath: LupusAssets.villageNightBgAsset,
                networkUrl: LupusAssets.villageNightBgUrl,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),
          ),

          // VIGNETTES ET BRUMES ARCANES STITCH (Isolé dans un RepaintBoundary pour zéro re-draw GPU)
          Positioned.fill(
            child: RepaintBoundary(
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
          ),
          Positioned.fill(
            child: RepaintBoundary(
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
          ),

          // 2. CONTENU PRINCIPAL
          SafeArea(
            child: Column(
              children: [
                // TOP HUD UNIFIÉ (Header Row: Quitter, Code Room, Mon Rôle, Chrono compact, Parchemin, Globe)
                _buildStitchTopHUD(
                  context,
                  room,
                  gameState,
                  myRole,
                  isMeAlive,
                  _countdownNotifier,
                  isNight,
                ),

                // BANNIÈRE D'ANNONCE DE PHASE (Stitch Phase Banner)
                _buildStitchPhaseBanner(room, gameState, isMeEvil, myRole),

                // MINI-TICKER : DERNIER ÉVÉNEMENT COMPACT (cliquable pour ouvrir les chroniques)
                _buildMiniTicker(context, room.logs, room.roomCode, room, gameState),

                // SÉLECTEUR DE VUE : TABLE MYSTIQUE RADIALE vs GRILLE BENTO
                _buildViewModeToggle(),
                const SizedBox(height: 2),

                // ZONE CENTRALE (EXPANDED) : TABLE MYSTIQUE OU GRILLE BENTO (Zéro Scroll)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: ValueListenableBuilder<Set<int>>(
                      valueListenable: AgoraVoiceService().speakingUids,
                      builder: (context, speakingUids, _) {
                        return _useRadialView
                            ? Center(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: RepaintBoundary(
                                    child: MysticRadialTable(
                                      players: room.playerList,
                                      selectedPlayerId: _selectedPlayerId,
                                      currentUserId: gameState.currentUserId,
                                      speakingAgoraUids: speakingUids,
                                      currentSpeakerId: room.currentSpeakerId,
                                      revealRoles: revealRoles,
                                      isMeEvil: isMeEvil,
                                      isDevModeActive: isDevModeActive,
                                      isDevRoom: isDevRoom,
                                      myRole: myRole,
                                      seerInspectedRoles:
                                          gameState.seerInspectedRoles,
                                      wolfPlayerIds: gameState.wolfPlayerIds,
                                      voteCounts: room.voteCounts,
                                      captainTargetVoteId:
                                          room.captainTargetVoteId,
                                      centerActionTitle: _getTargetActionTitle(
                                        context,
                                        room.phase,
                                        room,
                                      ),
                                      centerActionSubtitle:
                                          _getTargetActionSubtitle(
                                        context,
                                        room.phase,
                                        room,
                                      ),
                                      onPlayerSelected: (id) {
                                        if (room.phase == GamePhase.nightSeer &&
                                            (myRole == GameRole.seer || isDevMode) &&
                                            _selectedPlayerId != null) {
                                          return;
                                        }
                                        final target = room.players[id];
                                        if (target == null || !target.isAlive || DeathRegistryService.instance.isDead(id)) return;
                                        setState(() {
                                          _selectedPlayerId =
                                              (_selectedPlayerId == id)
                                                  ? null
                                                  : id;
                                        });
                                      },
                                      deathQueue: _deathQueue.isNotEmpty
                                          ? List<DeathAnnouncementEvent>.unmodifiable(_deathQueue)
                                          : null,
                                      onDeathSequenceCompleted: () {
                                        if (mounted) {
                                          setState(() {
                                            _deathQueue.clear();
                                          });
                                        }
                                      },
                                    ),
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
                                isDevModeActive: isDevModeActive,
                                isDevRoom: isDevRoom,
                                myRole: myRole,
                                seerInspectedRoles:
                                    gameState.seerInspectedRoles,
                                wolfPlayerIds: gameState.wolfPlayerIds,
                                onPlayerSelected: (id) {
                                  if (room.phase == GamePhase.nightSeer &&
                                      (myRole == GameRole.seer || isDevMode) &&
                                      _selectedPlayerId != null) {
                                    return;
                                  }
                                  final target = room.players[id];
                                  if (target == null || !target.isAlive || DeathRegistryService.instance.isDead(id)) return;
                                  setState(() {
                                    _selectedPlayerId =
                                        (_selectedPlayerId == id) ? null : id;
                                  });
                                },
                              );
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
                          currentUserId: gameState.effectiveUserId,
                          selectedTargetId: _selectedPlayerId,
                          inspectedRole: gameState.inspectedRole,
                          isHost: gameState.isHost,
                          isAdmin: isDevMode,
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
                          onWitchSave: ([targetId]) => ref
                              .read(gameNotifierProvider.notifier)
                              .witchSaveVictim(targetId),
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
                          onThiefChooseRole: (role) => ref
                              .read(gameNotifierProvider.notifier)
                              .thiefChooseRole(role),
                          onPiperCharm: (targets) => ref
                              .read(gameNotifierProvider.notifier)
                              .piperCharmPlayers(targets),
                          onInfect: (victimId) => ref
                              .read(gameNotifierProvider.notifier)
                              .infectWolfInfect(victimId),
                          onHunterShoot: (targetId) => ref
                              .read(gameNotifierProvider.notifier)
                              .hunterShoot(targetId),
                          onCaptainPass: (targetId) => ref
                              .read(gameNotifierProvider.notifier)
                              .designateCaptainSuccessor(targetId),
                          onCrowDesignate: (targetId) => ref
                              .read(gameNotifierProvider.notifier)
                              .crowDesignate(targetId),
                          onPyromaniacDouse: (targetId) => ref
                              .read(gameNotifierProvider.notifier)
                              .pyromaniacDouse(targetId),
                          onPyromaniacIgnite: () => ref
                              .read(gameNotifierProvider.notifier)
                              .pyromaniacIgnite(),
                          onPyromaniacPass: () => ref
                              .read(gameNotifierProvider.notifier)
                              .pyromaniacPass(),
                          onBlackWolfSilence: (targetId) => ref
                              .read(gameNotifierProvider.notifier)
                              .werewolfSilence(targetId),
                          onPassDebate: () => ref
                              .read(gameNotifierProvider.notifier)
                              .passTurnDebate(),
                          countdownListenable: _countdownNotifier,
                          onSelectTarget: (id) =>
                              setState(() => _selectedPlayerId = id),
                        ),
                        const SizedBox(height: 8),

                        // CONTRÔLES VOCAUX AGORA
                        BentoVoiceControls(
                          isAlive: isMeAlive,
                          isCurrentSpeaker:
                              room.currentSpeakerId == gameState.currentUserId,
                          currentSpeakerName: room.currentSpeakerId != null
                              ? room.players[room.currentSpeakerId]?.name
                              : null,
                          phase: room.phase,
                          isMutedByBlackWolf: gameState.isSilencedByBlackWolf,
                          isVictoryVoiceExpired:
                              gameState.isVictoryVoiceExpired,
                          isWolf: myRole.isEvil || myRole == GameRole.whiteWerewolf,
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
            _buildGameOverOverlay(context, room, gameState),
        ],
      ),
    );
  }

  /// Top HUD & Navigation Bar unifié :
  /// Disposition horizontale (Row) unique bien espacée et centrée :
  /// [Bouton Quitter] -> [Code Room] -> [Mon Rôle (centré via Expanded)] -> [Chrono compact] -> [Parchemin] -> [Globe de langue]
  Widget _buildStitchTopHUD(
    BuildContext context,
    dynamic room,
    dynamic gameState,
    dynamic myRole,
    bool isMeAlive,
    ValueNotifier<int> countdownNotifier,
    bool isNight,
  ) {
    final role = myRole is GameRole ? myRole : GameRole.simpleVillager;
    final accentColor = role.accentColor;
    final isDevRoom = (room.isDevRoom as bool?) ?? false;
    final isDevModeActive = (gameState.isDevModeActive as bool?) ?? false;
    final isDevMode =
        isDevModeActive || isDevRoom || (gameState.isAdmin as bool? ?? false);

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 2, 10, 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Bouton Quitter circulaire en verre (fermer la salle)
          GestureDetector(
            onTap: () => _confirmLeave(context),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xC012182E),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 16,
                color: LupusColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 6),

          // 2. [Code Room] : Le badge #ZVEFR (bordure ambrée, déclencheur secret admin)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPress: () => _openAdminTrigger(context),
            onDoubleTap: () => _openAdminTrigger(context),
            child: Builder(
              builder: (_) {
                final isWolfVoice =
                    (gameState.isWolfVoiceChannel == true) ||
                    ((room.phase as GamePhase) ==
                            GamePhase.nightWerewolves &&
                        ((role).isEvil || isDevMode));
                final isAdmin = (gameState.isAdmin as bool?) ?? false;

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3.5,
                  ),
                  decoration: BoxDecoration(
                    color: isWolfVoice
                        ? const Color(0xCC7F1D1D)
                        : (isAdmin
                              ? const Color(0xFF422006)
                              : const Color(0xCC12182E)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isWolfVoice
                          ? const Color(0xFFFF2A4B)
                          : LupusColors.arcaneGold.withValues(alpha: 0.6),
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
                        : [
                            BoxShadow(
                              color: LupusColors.arcaneGold
                                  .withValues(alpha: 0.12),
                              blurRadius: 6,
                            ),
                          ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isWolfVoice) ...[
                        const Text('🐺', style: TextStyle(fontSize: 10)),
                        const SizedBox(width: 3),
                      ],
                      Text(
                        isWolfVoice
                            ? '#${room.roomCode} • ${context.tr("pack_channel").toUpperCase()}'
                            : '#${room.roomCode}',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                          color: isWolfVoice
                              ? const Color(0xFFFFE4E6)
                              : LupusColors.arcaneGold,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // 3. [Mon Rôle] : Bouton/capsule "MON RÔLE", placé et centré/ajusté dans l'espace disponible
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: GestureDetector(
                    onTap: () => _showSecretRoleModal(
                      context,
                      role,
                      isMeAlive,
                      gameState,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xE012182E),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.5),
                          width: 0.9,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withValues(alpha: 0.2),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            size: 13,
                            color: accentColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            context.tr('my_role'),
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
                ),
              ),
            ),
          ),

          // 4. [Chrono compact] : Minuteur de tour réactif en pilule compacte
          ServerCountdownTimerBadge(
            isCompact: true,
            phaseEndsAt: room.phaseEndsAt,
            fallbackSeconds: room.timerSeconds > 0
                ? room.timerSeconds
                : (isNight ? 40 : 15),
            isNight: isNight,
            phase: room.phase,
            round: room.round,
            onTick: (seconds) {
              countdownNotifier.value = seconds;
            },
            onTimerExpired: () {
              final currentRoom = ref.read(gameNotifierProvider).room;
              if (currentRoom == null) return;
              if (currentRoom.phase != room.phase ||
                  currentRoom.round != room.round) {
                // La phase ou le tour a déjà progressé entre-temps, ignorer l'expiration orpheline !
                return;
              }
              if (gameState.isHost &&
                  currentRoom.phase != GamePhase.gameOver &&
                  currentRoom.phase != GamePhase.lobby) {
                ref.read(gameNotifierProvider.notifier).nextPhase();
              }
            },
          ),
          const SizedBox(width: 6),

          // 5. [Parchemin] : Journal des Chroniques avec Badge de notification
          Builder(
            builder: (_) {
              final logList =
                  (room.logs is List) ? (room.logs as List) : const [];
              final unreadCount =
                  (logList.length - _lastSeenLogCount).clamp(0, 999);

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
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xC012182E),
                        border: Border.all(
                          color: LupusColors.arcaneGold.withValues(alpha: 0.5),
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: LupusColors.arcaneGold
                                .withValues(alpha: 0.2),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          '📜',
                          style: TextStyle(fontSize: 15),
                        ),
                      ),
                    ),
                    if (unreadCount > 0)
                      PositionedDirectional(
                        top: -3,
                        end: -3,
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
          const SizedBox(width: 6),

          // 6. [Globe de langue] : Bouton circulaire avec l'icône globe tout à droite
          GestureDetector(
            onTap: () =>
                LanguageDialog.show(context, LocaleProvider.instance),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xC012182E),
                shape: BoxShape.circle,
                border: Border.all(
                  color: LupusColors.arcaneGold.withValues(alpha: 0.4),
                ),
              ),
              child: const Icon(
                Icons.language_rounded,
                size: 16,
                color: LupusColors.arcaneGold,
              ),
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
    final title = _getPhaseTitle(context, phase);
    final subtitle = _getPhaseSubtitle(context, phase);
    final phaseChip = phase.isNight
        ? context.tr('night_phase_round', {'round': room.round})
        : context.tr('day_phase_round', {'round': room.round});

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            margin: const EdgeInsets.only(bottom: 2),
            decoration: BoxDecoration(
              color: phase.isNight ? const Color(0x66450A0A) : const Color(0x66422006),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: phase.isNight
                    ? LupusColors.arcaneCrimson.withValues(alpha: 0.4)
                    : LupusColors.arcaneGold.withValues(alpha: 0.4),
                width: 0.8,
              ),
            ),
            child: Text(
              phaseChip,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
                color: phase.isNight ? const Color(0xFFFCA5A5) : const Color(0xFFFDE68A),
              ),
            ),
          ),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'serif',
              fontSize: 16.5,
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
          const SizedBox(height: 0.5),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontStyle: FontStyle.italic,
              fontSize: 10.5,
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
                                    ? context.tr('wolf_channel_active')
                                    : (myRole == GameRole.littleGirl
                                          ? context.tr('little_girl_spying')
                                          : context.tr('silent_village_night')),
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
                              ? context.tr('mic_open_wolves')
                              : (myRole == GameRole.littleGirl
                                    ? context.tr('secret_eavesdropping')
                                    : context.tr('wolves_plotting')),
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
                              ? (gameState.isMuted
                                    ? context.tr('mic_muted')
                                    : context.tr('status_open'))
                              : context.tr('mic_muted'),
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
          if (phase == GamePhase.nightWitch &&
              (gameState.myRole == GameRole.witch || gameState.isAdmin)) ...[
            Builder(
              builder: (_) {
                final victimId = room.nightVictimId;
                final victim = victimId != null ? room.players[victimId] : null;
                final isHealed = room.witchHealed == true;
                if (victim == null) {
                  return Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x330284C7),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF38BDF8),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '🕊️',
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          context.tr('no_victim_to_save'),
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFBAE6FD),
                          ),
                        ),
                      ],
                    ),
                  );
                }
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
                            ? context.tr('witch_victim_saved_banner', {'name': victim.name})
                            : context.tr('witch_victim_dying_banner', {'name': victim.name}),
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

        ],
      ),
    );
  }

  /// Filtrage confidentiel des logs selon le rôle et la phase :
  /// Les villageois innocents ne doivent JAMAIS voir les actions occultes des Loups (proie, silence) durant la nuit.
  List<String> _filterConfidentialLogs(
    List<String> logs,
    GameRoom room,
    LupusGameState gameState,
  ) {
    final isEvilOrAdmin = gameState.myRole.isEvil || gameState.isAdmin;
    if (isEvilOrAdmin || !room.phase.isNight) {
      return logs;
    }
    return logs.where((log) {
      final l = log.toLowerCase();
      if (l.contains('🐺') ||
          l.contains('silence') ||
          l.contains('victime dans l\'ombre') ||
          l.contains('réduit(e) au silence') ||
          l.contains('intimé le silence')) {
        return false;
      }
      return true;
    }).toList();
  }

  /// Mini-Ticker compact affichant uniquement le dernier log du village
  Widget _buildMiniTicker(
    BuildContext context,
    List<String> logs,
    String roomCode,
    GameRoom room,
    LupusGameState gameState,
  ) {
    final filteredLogs = _filterConfidentialLogs(logs, room, gameState);
    if (filteredLogs.isEmpty) return const SizedBox.shrink();
    final latestLog = filteredLogs.last;
    final displayLog = _formatLogForDisplay(context, latestLog);

    return GestureDetector(
      onTap: () => _openChroniclesBottomSheet(context, filteredLogs, roomCode),
      child: Container(
        height: 24,
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1.5),
        decoration: BoxDecoration(
          color: const Color(0xB0080D1A),
          borderRadius: BorderRadius.circular(12),
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
            const Text('📜', style: TextStyle(fontSize: 10.5)),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                displayLog,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: LupusColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Directionality.of(context) == TextDirection.rtl
                  ? Icons.arrow_back_ios_rounded
                  : Icons.arrow_forward_ios_rounded,
              size: 8.5,
              color: LupusColors.arcaneGold,
            ),
          ],
        ),
      ),
    );
  }

  /// Formate et traduit les logs clés du village pour l'affichage en temps réel
  String _formatLogForDisplay(BuildContext context, String log) {
    return context.translateLog(log);
  }

  /// Sélecteur de vue (Table Mystique vs Grille Bento)
  Widget _buildViewModeToggle() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: const Color(0xC00A0F1E),
          borderRadius: BorderRadius.circular(14),
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
                  horizontal: 10,
                  vertical: 3.5,
                ),
                decoration: BoxDecoration(
                  color: _useRadialView
                      ? LupusColors.arcanePurple.withValues(alpha: 0.35)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  border: _useRadialView
                      ? Border.all(
                          color: LupusColors.arcanePurple.withValues(
                            alpha: 0.6,
                          ),
                        )
                      : null,
                ),
                child: Row(
                  children: [
                    const Text('⭕', style: TextStyle(fontSize: 10)),
                    const SizedBox(width: 4),
                    Text(
                      context.tr('view_mystic_table'),
                      style: const TextStyle(
                        fontSize: 10,
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
                  horizontal: 10,
                  vertical: 3.5,
                ),
                decoration: BoxDecoration(
                  color: !_useRadialView
                      ? LupusColors.arcanePurple.withValues(alpha: 0.35)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  border: !_useRadialView
                      ? Border.all(
                          color: LupusColors.arcanePurple.withValues(
                            alpha: 0.6,
                          ),
                        )
                      : null,
                ),
                child: Row(
                  children: [
                    const Text('▦', style: TextStyle(fontSize: 10)),
                    const SizedBox(width: 4),
                    Text(
                      context.tr('view_bento_grid'),
                      style: const TextStyle(
                        fontSize: 10,
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
  String _getPhaseTitle(BuildContext context, GamePhase phase) {
    switch (phase) {
      case GamePhase.nightThief:
        return context.tr('phase_thief_title');
      case GamePhase.nightCupid:
        return context.tr('phase_cupid_title');
      case GamePhase.nightDefender:
        return context.tr('salvateur_power_title');
      case GamePhase.nightSeer:
        return context.tr('seer_power_title');
      case GamePhase.nightWerewolves:
        return context.tr('phase_werewolves_title');
      case GamePhase.nightBlackWolf:
        return context.tr('phase_black_wolf_title');
      case GamePhase.nightWitch:
        return context.tr('phase_witch_title');
      case GamePhase.nightPiper:
        return context.tr('phase_night_piper_title');
      case GamePhase.nightPyromaniac:
        return context.tr('phase_pyromaniac_title');
      case GamePhase.morningAnnouncement:
        return context.tr('phase_dawn_title');
      case GamePhase.hunterDeathChoice:
        return context.tr('phase_hunter_breath_title');
      case GamePhase.captainSuccession:
      case GamePhase.mayorSuccession:
        return context.tr('phase_captain_succession_title');
      case GamePhase.captainElection:
      case GamePhase.mayorElection:
        return context.tr('phase_captain_election_title');
      case GamePhase.mayorSpeechOpening:
        return context.tr('phase_mayor_speech_opening_title');
      case GamePhase.dayDebate:
        return context.tr('phase_debate_title');
      case GamePhase.mayorSpeechClosing:
        return context.tr('phase_mayor_speech_closing_title');
      case GamePhase.dayVoting:
        return context.tr('phase_judgment_title');
      case GamePhase.dayDefense:
        return context.tr('phase_defense_title');
      case GamePhase.dayTieBreakVote:
        return context.tr('phase_tie_break_title');
      case GamePhase.dayResolution:
        return context.tr('phase_verdict_title');
      case GamePhase.gameOver:
        return context.tr('phase_game_over_title');
      case GamePhase.lobby:
        return context.tr('lobby');
    }
  }

  String _getPhaseSubtitle(BuildContext context, GamePhase phase) {
    switch (phase) {
      case GamePhase.nightCupid:
        return context.tr('phase_cupid_subtitle');
      case GamePhase.nightWerewolves:
        return context.tr('phase_werewolves_subtitle');
      case GamePhase.dayVoting:
      case GamePhase.dayTieBreakVote:
        return context.tr('phase_voting_subtitle');
      case GamePhase.captainElection:
      case GamePhase.mayorElection:
        return context.tr('phase_captain_election_subtitle');
      case GamePhase.mayorSpeechOpening:
        return context.tr('phase_mayor_speech_opening_subtitle');
      case GamePhase.dayDebate:
        return context.tr('phase_debate_subtitle');
      case GamePhase.mayorSpeechClosing:
        return context.tr('phase_mayor_speech_closing_subtitle');
      case GamePhase.captainSuccession:
      case GamePhase.mayorSuccession:
        return context.tr('phase_captain_succession_subtitle');
      case GamePhase.nightSeer:
        return context.tr('seer_power_desc');
      case GamePhase.nightDefender:
        return context.tr('salvateur_power_desc');
      case GamePhase.nightWitch:
        return context.tr('phase_witch_subtitle');
      case GamePhase.nightPyromaniac:
        return context.tr('phase_pyromaniac_subtitle');
      case GamePhase.morningAnnouncement:
        return context.tr('phase_dawn_subtitle');
      default:
        return context.tr('phase_default_subtitle');
    }
  }

  String _getTargetActionTitle(
    BuildContext context,
    GamePhase phase,
    dynamic room,
  ) {
    if (phase == GamePhase.nightWerewolves) return context.tr('prey');
    if (phase == GamePhase.nightWitch) return context.tr('victim');
    if (phase == GamePhase.nightPyromaniac) return context.tr('hearth');
    if (phase == GamePhase.nightCupid) return context.tr('lover');
    if (phase == GamePhase.dayVoting || phase == GamePhase.dayTieBreakVote) {
      return context.tr('accused');
    }
    if (phase == GamePhase.nightSeer) return context.tr('status_scanned');
    if (phase == GamePhase.nightDefender) return context.tr('status_protected');
    if (phase == GamePhase.captainElection || phase == GamePhase.mayorElection) return context.tr('candidate');
    if (phase == GamePhase.captainSuccession || phase == GamePhase.mayorSuccession) return context.tr('successor');
    return context.tr('target');
  }

  String _getTargetActionSubtitle(
    BuildContext context,
    GamePhase phase,
    dynamic room,
  ) {
    if (phase == GamePhase.nightWitch && room.nightVictimId != null) {
      final victim = room.players[room.nightVictimId];
      if (victim != null) {
        final status = room.witchHealed == true
            ? context.tr('saved')
            : context.tr('bitten');
        return '${victim.name} ($status)';
      }
    }
    if (phase == GamePhase.nightWerewolves) return context.tr('deliberating');
    if (phase == GamePhase.dayVoting) return context.tr('no_votes_cast');
    return context.tr('no_target');
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
        ? context.tr('camp_werewolves')
        : (role.defaultTeam == Team.solo
              ? context.tr('camp_solo')
              : context.tr('camp_village'));
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
                            Text(
                              context.tr('your_secret_role'),
                              style: const TextStyle(
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
                          role.displayName,
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
                                  child: Text(
                                    context.tr('captain_double_voice'),
                                    style: const TextStyle(
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
                                    context.tr('soulmate_label', {
                                      'name': gameState.loverName ??
                                          context.tr('unknown')
                                    }),
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
                                  child: Text(
                                    '💀 ${context.tr("eliminated")}',
                                    style: const TextStyle(
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
                            role.description,
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
                            child: Text(
                              context.tr('close'),
                              style: const TextStyle(
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

  /// Overlay de victoire finale et débriefing
  Widget _buildGameOverOverlay(
    BuildContext context,
    GameRoom room,
    LupusGameState gameState,
  ) {
    return GameOverScreen(
      room: room,
      gameState: gameState,
    );
  }

  void _confirmLeave(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LupusColors.surface,
        title: Text(
          context.tr('confirm_leave_title'),
          style: const TextStyle(color: LupusColors.textPrimary),
        ),
        content: Text(
          context.tr('confirm_leave_desc'),
          style: const TextStyle(color: LupusColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.tr('cancel')),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: LupusColors.arcaneCrimson,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(gameNotifierProvider.notifier).leaveRoom();
            },
            child: Text(context.tr('quit')),
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

    final gameState = ref.read(gameNotifierProvider);
    final room = gameState.room;
    final displayLogs = (room != null)
        ? _filterConfidentialLogs(logs, room, gameState)
        : logs;

    VillageChroniclesScreen.show(context, displayLogs, roomCode);
  }
}
