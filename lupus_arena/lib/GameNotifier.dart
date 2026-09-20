// ignore_for_file: file_names

import 'dart:async';
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'AgoraVoiceService.dart';
import 'engine/handlers/role_handlers_registry.dart';
import 'models/expanded_roles_state.dart';
import 'models/game_phase.dart';
import 'models/game_room.dart';
import 'models/game_state.dart';
import 'models/player_model.dart';
import 'services/death_registry_service.dart';
import 'services/conditional_role_distributor.dart';
import 'services/expanded_roles_coordinator.dart';
import 'services/game_phase_coordinator.dart';
import 'services/mayor_coordinator.dart';
import 'services/role_action_dispatcher.dart';
import 'services/role_security_service.dart';
import 'services/room_presence_service.dart';
import 'services/server_time_service.dart';
import 'services/vote_coordinator.dart';

/// URL spécifique de la Realtime Database configurée dans google-services.json
const String kFirebaseDatabaseUrl =
    'https://lupusarena-default-rtdb.europe-west1.firebasedatabase.app';

/// État global du jeu pour Riverpod
class LupusGameState {
  final String currentUserId;
  final String currentUserName;
  final int currentUserAvatar;
  final int agoraUid;
  final GameRoom? room;
  final bool isLoading;
  final String? errorMessage;
  final GameRole? inspectedRole;
  final Set<int> speakingAgoraUids;
  final bool isVoiceConnected;
  final bool isMuted;
  final bool isAdmin;
  final bool isDevModeActive;
  final String? impersonatedUserId; // UID du joueur incarné par l'hôte en Mode Dev
  final bool isOmniscientVoice;
  final String? currentVoiceChannel;
  final Map<String, GameRole> seerInspectedRoles;
  final List<String> foxSniffedPlayerIds;
  final bool? foxWolfDetected;
  final Set<String> wolfPlayerIds;
  final bool isVictoryVoiceExpired;

  const LupusGameState({
    required this.currentUserId,
    required this.currentUserName,
    this.currentUserAvatar = 0,
    required this.agoraUid,
    this.room,
    this.isLoading = false,
    this.errorMessage,
    this.inspectedRole,
    this.speakingAgoraUids = const {},
    this.isVoiceConnected = false,
    this.isMuted = false,
    this.isAdmin = false,
    this.isDevModeActive = false,
    this.impersonatedUserId,
    this.isOmniscientVoice = false,
    this.currentVoiceChannel,
    this.seerInspectedRoles = const {},
    this.foxSniffedPlayerIds = const [],
    this.foxWolfDetected,
    this.wolfPlayerIds = const {},
    this.isVictoryVoiceExpired = false,
  });

  bool get isInGame => room != null;
  bool get isHost => room != null && room!.hostId == currentUserId;
  bool get isDevMode => isDevModeActive || (room?.isDevRoom == true) || isAdmin;

  /// UID effectif pour l'émission d'actions (permet à l'Hôte Dev d'incarner n'importe quel personnage)
  String get effectiveUserId =>
      (isDevMode && impersonatedUserId != null && impersonatedUserId!.isNotEmpty)
          ? impersonatedUserId!
          : currentUserId;

  PlayerModel? get currentPlayer => room?.players[effectiveUserId] ?? room?.players[currentUserId];
  PlayerModel? get realUserPlayer => room?.players[currentUserId];
  bool get isImpersonating =>
      isDevMode &&
      impersonatedUserId != null &&
      impersonatedUserId!.isNotEmpty &&
      impersonatedUserId != currentUserId;

  bool get isAlive {
    final uid = effectiveUserId;
    if (DeathRegistryService.instance.isDead(uid)) return false;
    return currentPlayer?.isAlive ?? false;
  }
  GameRole get myRole => currentPlayer?.role ?? GameRole.simpleVillager;
  bool get isCaptain => currentPlayer?.isCaptain ?? false;
  bool get isLover => currentPlayer?.isLover ?? false;
  bool get isSilencedByBlackWolf => currentPlayer?.isMuted == true;
  bool get isWolfVoiceChannel =>
      currentVoiceChannel != null && currentVoiceChannel!.endsWith('_wolves');
  bool get canRevealAllRoles =>
      isDevMode || (room?.phase == GamePhase.gameOver);

  String? get loverName {
    if (!isLover || currentPlayer?.loverId == null || room == null) return null;
    return room!.players[currentPlayer!.loverId!]?.name;
  }

  ExpandedRolesState get expandedRolesState =>
      room?.expandedRolesState ?? const ExpandedRolesState();

  LupusGameState copyWith({
    String? currentUserId,
    String? currentUserName,
    int? currentUserAvatar,
    int? agoraUid,
    GameRoom? room,
    bool? isLoading,
    String? errorMessage,
    GameRole? inspectedRole,
    Set<int>? speakingAgoraUids,
    bool? isVoiceConnected,
    bool? isMuted,
    bool? isAdmin,
    bool? isDevModeActive,
    String? impersonatedUserId,
    bool clearImpersonation = false,
    bool? isOmniscientVoice,
    String? currentVoiceChannel,
    Map<String, GameRole>? seerInspectedRoles,
    List<String>? foxSniffedPlayerIds,
    bool? foxWolfDetected,
    bool clearFoxSniff = false,
    Set<String>? wolfPlayerIds,
    bool? isVictoryVoiceExpired,
    bool clearRoom = false,
    bool clearInspectedRole = false,
  }) {
    return LupusGameState(
      currentUserId: currentUserId ?? this.currentUserId,
      currentUserName: currentUserName ?? this.currentUserName,
      currentUserAvatar: currentUserAvatar ?? this.currentUserAvatar,
      agoraUid: agoraUid ?? this.agoraUid,
      room: clearRoom ? null : (room ?? this.room),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      inspectedRole: clearInspectedRole
          ? null
          : (inspectedRole ?? this.inspectedRole),
      speakingAgoraUids: speakingAgoraUids ?? this.speakingAgoraUids,
      isVoiceConnected: isVoiceConnected ?? this.isVoiceConnected,
      isMuted: isMuted ?? this.isMuted,
      isAdmin: isAdmin ?? this.isAdmin,
      isDevModeActive: isDevModeActive ?? this.isDevModeActive,
      impersonatedUserId: clearImpersonation
          ? null
          : (impersonatedUserId ?? this.impersonatedUserId),
      isOmniscientVoice: isOmniscientVoice ?? this.isOmniscientVoice,
      currentVoiceChannel: currentVoiceChannel ?? this.currentVoiceChannel,
      seerInspectedRoles: seerInspectedRoles ?? this.seerInspectedRoles,
      foxSniffedPlayerIds: clearFoxSniff
          ? const []
          : (foxSniffedPlayerIds ?? this.foxSniffedPlayerIds),
      foxWolfDetected: clearFoxSniff
          ? null
          : (foxWolfDetected ?? this.foxWolfDetected),
      wolfPlayerIds: wolfPlayerIds ?? this.wolfPlayerIds,
      isVictoryVoiceExpired:
          isVictoryVoiceExpired ?? this.isVictoryVoiceExpired,
    );
  }
}

/// Moteur de règles canoniques des Loups-Garous de Thiercelieux
class GameNotifier extends StateNotifier<LupusGameState> {
  final AgoraVoiceService _voiceService = AgoraVoiceService();
  final GamePhaseCoordinator phaseCoordinator = const GamePhaseCoordinator();
  GamePhaseCoordinator get _phaseCoordinator => phaseCoordinator;
  final VoteCoordinator voteCoordinator = const VoteCoordinator();
  final RoleActionDispatcher roleDispatcher = const RoleActionDispatcher();
  late final RoomPresenceService presenceService = RoomPresenceService(_database);

  StreamSubscription<DatabaseEvent>? _publicStateSubscription;
  StreamSubscription<DatabaseEvent>? _playersSubscription;
  StreamSubscription<DatabaseEvent>? _votesSubscription;
  StreamSubscription<DatabaseEvent>? _presenceSubscription;
  StreamSubscription<DatabaseEvent>? _logsSubscription;
  StreamSubscription<DatabaseEvent>? _currentPhaseSubscription;
  StreamSubscription<DatabaseEvent>? _secretRoleSubscription;
  StreamSubscription<DatabaseEvent>? _wolfPackSubscription;
  StreamSubscription<DatabaseEvent>? _replayStatusSubscription;
  StreamSubscription<DatabaseEvent>? _gameResetSubscription;
  StreamSubscription<DatabaseEvent>? _cemeterySubscription;
  /// Surveille le statut en ligne de l'hôte pour déclencher le transfert automatique.
  StreamSubscription<DatabaseEvent>? _hostPresenceSubscription;
  /// Écoute les changements de hostId pour que le nouvel hôte active immédiatement ses timers.
  StreamSubscription<DatabaseEvent>? _hostIdSubscription;
  DatabaseReference? _currentRoomRef;
  String? _lastAppliedVoiceChannel;
  GamePhase? _lastAppliedVoicePhase;
  bool _isTransitioningPhase = false;
  bool _isResettingReplay = false;
  Timer? _phaseExpirationTimer;
  int _lastProcessedPhaseStartedAt = 0;

  /// Ensemble des tours de jeu pour lesquels la résolution du vote diurne a déjà été traitée (Garantie d'Idempotence stricte).
  final Set<int> _resolvedDayVoteRounds = {};

  /// Annule et détruit immédiatement le minuteur d'expiration de phase en cours
  void _cancelPhaseTimer() {
    _phaseExpirationTimer?.cancel();
    _phaseExpirationTimer = null;
  }

  /// Clôture définitivement le vote du jour (idempotent par cycle journalier)
  Future<void> cloturerVote() => processDayVoteResolution();

  /// Affiche le verdict et déclenche la transition suivante
  Future<void> afficherVerdict() => nextPhase();

  /// Registre inviolable des défunts (délégué au singleton DeathRegistryService).
  /// Règle d'or : "Celui qui meurt meurt".
  DeathRegistryService get _deathRegistry => DeathRegistryService.instance;

  /// Exception unique de résurrection : Potion de vie de la Sorcière
  void applyWitchRevive(String victimId) {
    _deathRegistry.allowWitchRevive(victimId);
  }

  /// Correction immédiate en base de données si un zombie a été détecté
  Future<void> _fixZombieOnDatabase(String pid) async {
    if (_currentRoomRef == null) return;
    try {
      await _currentRoomRef!.child('players/$pid/isAlive').set(false);
      await _currentRoomRef!.child('cemetery/$pid').set(true);
      debugPrint('[_fixZombieOnDatabase] 🛡️ Verrou anti-zombie appliqué sur Firebase pour $pid');
    } catch (e) {
      debugPrint('[_fixZombieOnDatabase] Erreur fixation zombie de $pid: $e');
    }
  }

  /// Reconnexion sécurisée : ré-impose l'état serveur et préserve l'état de mort
  Future<void> handlePlayerReconnect(String roomId, String uid) async {
    try {
      final snapshot = await _database.ref('rooms/$roomId/players/$uid').get();
      if (!snapshot.exists || snapshot.value == null) return;

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      bool serverIsAlive = data['isAlive'] == true;
      if (DeathRegistryService.instance.isDead(uid)) {
        serverIsAlive = false;
      } else if (!serverIsAlive) {
        DeathRegistryService.instance.markDead(uid);
      }

      await _database.ref('rooms/$roomId/players/$uid').update({
        'isOnline': true,
        'lastSeen': ServerValue.timestamp,
        'isAlive': serverIsAlive,
      });
      if (!serverIsAlive) {
        await _database.ref('rooms/$roomId/cemetery/$uid').set(true);
      }
    } catch (e) {
      debugPrint('[handlePlayerReconnect] Erreur: $e');
    }
  }

  GameNotifier()
      : super(
          () {
            final initialId = _generateUniqueId();
            return LupusGameState(
              currentUserId: initialId,
              currentUserName: 'Guerrier_${Random().nextInt(900) + 100}',
              currentUserAvatar: Random().nextInt(6),
              agoraUid: AgoraVoiceService.deriveUid(initialId),
            );
          }(),
        ) {
    loadSavedProfile();
    ServerTimeService().initialize(_database);
  }

  /// Charge le profil utilisateur précédemment sauvegardé sur l'appareil
  Future<void> loadSavedProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? savedUserId = prefs.getString('player_user_id');
      if (savedUserId == null || savedUserId.trim().isEmpty) {
        savedUserId = state.currentUserId;
        await prefs.setString('player_user_id', savedUserId);
      }
      final savedName = prefs.getString('player_nickname');
      final savedAvatar = prefs.getInt('player_avatar');
      final stableAgoraUid = AgoraVoiceService.deriveUid(savedUserId);
      state = state.copyWith(
        currentUserId: savedUserId,
        agoraUid: stableAgoraUid,
        currentUserName: (savedName != null && savedName.trim().isNotEmpty)
            ? savedName.trim()
            : state.currentUserName,
        currentUserAvatar: savedAvatar ?? state.currentUserAvatar,
      );
    } catch (e) {
      debugPrint('[Profile] Erreur de chargement du profil local : $e');
    }
  }

  FirebaseDatabase get _database {
    try {
      return FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: kFirebaseDatabaseUrl,
      );
    } catch (_) {
      return FirebaseDatabase.instance;
    }
  }

  static String _generateUniqueId() {
    return 'usr_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
  }

  void updateProfile({String? name, int? avatarIndex}) {
    final updatedName = name ?? state.currentUserName;
    final updatedAvatar = avatarIndex ?? state.currentUserAvatar;
    state = state.copyWith(
      currentUserName: updatedName,
      currentUserAvatar: updatedAvatar,
    );

    // Sauvegarde persistante sur le téléphone (SharedPreferences)
    SharedPreferences.getInstance().then((prefs) {
      if (name != null && name.trim().isNotEmpty) {
        prefs.setString('player_nickname', name.trim());
      }
      if (avatarIndex != null) {
        prefs.setInt('player_avatar', avatarIndex);
      }
    }).catchError((e) {
      debugPrint('[Profile] Erreur de sauvegarde du profil : $e');
    });
  }

  /// Efface le message d'erreur actuel
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// ÉCRITURE FIREBASE ATOMIQUE — chemin canonique unique : rooms/$roomCode
  /// Une seule requête multi-path par action, éliminant toute écriture miroir.
  /// ═══════════════════════════════════════════════════════════════════════════
  Future<void> _syncState(Map<String, dynamic> updates) async {
    if (_currentRoomRef == null) return;

    // ── GARDE MONOTONE STRICT (Anti-Rollback local & distant) ──
    if (state.room != null) {
      final currentRound = state.room!.round;
      final currentPhase = state.room!.phase;

      // 1. Refus formel de rétrogradation de tour
      if (updates.containsKey('round')) {
        final rawRound = updates['round'];
        final incomingRound = rawRound is num ? rawRound.toInt() : currentRound;
        if (incomingRound < currentRound) {
          debugPrint(
            '⛔ [Anti-Rollback _syncState] Refus de rétrograder le tour : $incomingRound < $currentRound. Mise à jour rejetée.',
          );
          return;
        }
      }

      // 2. Refus formel de régression Nuit -> Jour ou d'ordre nocturne au sein du même tour
      final rawIncomingPhase = updates['phase']?.toString() ?? updates['currentPhase']?.toString();
      if (rawIncomingPhase != null) {
        final incomingPhase = GamePhase.fromString(rawIncomingPhase);
        final incomingRound = updates.containsKey('round') && updates['round'] is num
            ? (updates['round'] as num).toInt()
            : currentRound;

        if (incomingRound == currentRound) {
          if (currentPhase.isNight && incomingPhase.isDay) {
            debugPrint(
              '⛔ [Anti-Rollback _syncState] Refus de rétrograder de Nuit (${currentPhase.name}) vers Jour (${incomingPhase.name}) au tour $currentRound.',
            );
            return;
          }
          if (currentPhase.isNight &&
              incomingPhase.isNight &&
              incomingPhase.nightOrderIndex < currentPhase.nightOrderIndex) {
            debugPrint(
              '⛔ [Anti-Rollback _syncState] Refus de rétrograder l\'ordre nocturne : ${currentPhase.name} -> ${incomingPhase.name} au tour $currentRound.',
            );
            return;
          }
        }
      }
    }

    // Synchronisation stricte phase <-> currentPhase
    if (updates.containsKey('phase')) {
      final pName = updates['phase'].toString();
      updates['currentPhase'] = pName == GamePhase.dayVoting.name
          ? 'JOUR_VOTE'
          : (pName == GamePhase.dayDebate.name
              ? 'JOUR_DEBAT'
              : (pName == GamePhase.captainSuccession.name || pName == GamePhase.mayorSuccession.name
                  ? 'CAPITAINE_SUCCESSION'
                  : (pName == GamePhase.captainElection.name || pName == GamePhase.mayorElection.name
                      ? 'CAPITAINE_ELECTION'
                      : (pName == GamePhase.mayorSpeechOpening.name
                          ? 'MAYOR_SPEECH_OPENING'
                          : (pName == GamePhase.mayorSpeechClosing.name
                              ? 'MAYOR_SPEECH_CLOSING'
                              : pName)))));
    } else if (updates.containsKey('currentPhase')) {
      final cp = GamePhase.fromString(updates['currentPhase']?.toString());
      updates['phase'] = cp.name;
    }

    if (updates['phase'] == GamePhase.gameOver.name || updates['winner'] != null) {
      _cancelPhaseTimer();
    }

    // CALCUL DU COMPTE À REBOURS SERVEUR PUR (phaseEndsAt, phaseStartedAt, phaseDurationMs)
    final bool isPhaseChanging = updates.containsKey('phase') || updates.containsKey('currentPhase');
    final bool isTimerUpdating = updates.containsKey('timerSeconds');
    final bool isSpeakerChanging = updates.containsKey('currentSpeakerId');

    // ── RÉINITIALISATION AUTOMATIQUE SYSTÉMIQUE DES VOTES ET ACTIONS STRATÉGIQUES ──
    // À chaque transition de phase ou de cycle nocturne, tous les votes de joueurs,
    // tables de votes et sélections tactiques sont réinitialisés de façon atomique.
    if (isPhaseChanging) {
      _resetAllVotes(updates);
    }

    if (isPhaseChanging || isTimerUpdating || isSpeakerChanging) {
      int durationSec = 30;
      if (updates.containsKey('timerSeconds')) {
        final tVal = updates['timerSeconds'];
        if (tVal is num) durationSec = tVal.toInt();
      } else if (state.room != null) {
        durationSec = state.room!.timerSeconds;
      }

      final durationMs = durationSec * 1000;
      final currentServerTime = ServerTimeService().currentServerEstimatedTime;

      updates['phaseEndsAt'] = currentServerTime + durationMs;
      updates['phaseStartedAt'] = currentServerTime;
      updates['phaseDurationMs'] = durationMs;
    }

    // ── Synchroniser le sous-nœud public_state pour les abonnements partitionnés ──
    final publicKeys = [
      'phase',
      'currentPhase',
      'round',
      'timerSeconds',
      'phaseEndsAt',
      'phaseStartedAt',
      'phaseDurationMs',
      'captainId',
      'currentSpeakerId',
      'pendingHunterId',
      'pendingCaptainId',
      'nightVictimId',
      'witchHealed',
      'witchPoisonVictimId',
      'pyromaniacIgnited',
      'blackWolfTargetId',
      'isTieBreakActive',
      'winner',
      'morningVictims',
      'deathAnnouncementQueue',
      'lastDeathFlip',
    ];
    for (final k in publicKeys) {
      if (updates.containsKey(k)) {
        updates['public_state/$k'] = updates[k];
      }
    }

    // Synchroniser et garantir le verrou anti-résurrection absolu sur Firebase
    final bool isWitchHealAction = (updates['witchHealed'] == true && updates['nightVictimId'] != null) ||
        (state.room?.witchHealed == true && state.room?.nightVictimId != null);
    final String? healedPid = updates['witchHealed'] == true
        ? updates['nightVictimId']?.toString()
        : state.room?.nightVictimId;

    if (isWitchHealAction && healedPid != null) {
      DeathRegistryService.instance.allowWitchRevive(healedPid);
      updates['cemetery/$healedPid'] = null;
    }

    for (final pid in DeathRegistryService.instance.deadPlayerIds) {
      if (pid != healedPid) {
        updates['players/$pid/isAlive'] = false;
        updates['cemetery/$pid'] = true;
      }
    }

    try {
      // ── ÉCRITURE ATOMIQUE UNIQUE : rooms/$roomCode ──
      // Suppression des miroirs games/$roomCode et rooms/$roomCode/state.
      await _currentRoomRef!.update(updates);
    } catch (e) {
      debugPrint('[Firebase Sync Error] $e');
    }

    if (state.room != null) {
      final updatedPhase = updates.containsKey('phase')
          ? GamePhase.values.firstWhere(
              (p) => p.name == updates['phase'],
              orElse: () => state.room!.phase,
            )
          : state.room!.phase;
      final updatedTimer = updates.containsKey('timerSeconds')
          ? (updates['timerSeconds'] is num ? (updates['timerSeconds'] as num).toInt() : state.room!.timerSeconds)
          : state.room!.timerSeconds;

      // Appliquer les mises à jour directes sur les joueurs (isAlive, role, isCaptain, etc.)
      final updatedPlayers = Map<String, PlayerModel>.from(state.room!.players);
      if (isPhaseChanging) {
        for (final pid in updatedPlayers.keys) {
          updatedPlayers[pid] = updatedPlayers[pid]!.copyWith(
            clearTargetVote: true,
            clearTargetVoteId: true,
          );
        }
      }
      for (final entry in updates.entries) {
        if (entry.key.startsWith('players/')) {
          final parts = entry.key.split('/');
          if (parts.length >= 3) {
            final pid = parts[1];
            final field = parts[2];
            final p = updatedPlayers[pid];
            if (p != null) {
              if (field == 'isAlive') {
                final val = entry.value;
                final isDead = (val == false || val == 'false' || val == 0 || val == '0');
                final bool isWitchHeal = (state.room?.witchHealed == true && pid == state.room?.nightVictimId) ||
                    (updates['witchHealed'] == true && pid == updates['nightVictimId']);
                if (DeathRegistryService.instance.isDead(pid) && !isWitchHeal && !state.isAdmin) {
                  updatedPlayers[pid] = p.copyWith(isAlive: false);
                } else if (isDead) {
                  DeathRegistryService.instance.markDead(pid);
                  updatedPlayers[pid] = p.copyWith(isAlive: false);
                } else {
                  if (isWitchHeal || state.isAdmin) {
                    DeathRegistryService.instance.allowWitchRevive(pid);
                  }
                  if (DeathRegistryService.instance.isDead(pid)) {
                    updatedPlayers[pid] = p.copyWith(isAlive: false);
                  } else {
                    updatedPlayers[pid] = p.copyWith(isAlive: true);
                  }
                }
              } else if (field == 'role') {
                updatedPlayers[pid] = p.copyWith(role: GameRole.fromId(entry.value.toString()));
              } else if (field == 'isCaptain') {
                updatedPlayers[pid] = p.copyWith(isCaptain: entry.value == true);
              } else if (field == 'isMuted') {
                updatedPlayers[pid] = p.copyWith(isMuted: entry.value == true);
              } else if (field == 'isDoused') {
                updatedPlayers[pid] = p.copyWith(isDoused: entry.value == true);
              } else if (field == 'isInfected') {
                updatedPlayers[pid] = p.copyWith(isInfected: entry.value == true);
              } else if (field == 'potionsVie') {
                updatedPlayers[pid] = p.copyWith(potionsVie: entry.value as int? ?? p.potionsVie);
              } else if (field == 'potionsMort') {
                updatedPlayers[pid] = p.copyWith(potionsMort: entry.value as int? ?? p.potionsMort);
              } else if (field == 'hasUsedPoisonPotion') {
                updatedPlayers[pid] = p.copyWith(hasUsedPoisonPotion: entry.value == true);
              } else if (field == 'hasUsedHealPotion') {
                updatedPlayers[pid] = p.copyWith(hasUsedHealPotion: entry.value == true);
              } else if (field == 'targetVoteId') {
                final targetVal = entry.value?.toString();
                updatedPlayers[pid] = p.copyWith(
                  targetVoteId: targetVal,
                  clearTargetVote: targetVal == null,
                  clearTargetVoteId: targetVal == null,
                );
              }
            }
          }
        }
      }

      final rawMorningVictims = updates['morningVictims'];
      final List<String> parsedMorningVictims = rawMorningVictims is List
          ? List<String>.from(rawMorningVictims.map((e) => e.toString()))
          : state.room!.morningVictims;

      final rawDeathQueue = updates['deathAnnouncementQueue'];
      final List<Map<String, dynamic>> parsedDeathQueue = rawDeathQueue is List
          ? List<Map<String, dynamic>>.from(rawDeathQueue.map((e) => Map<String, dynamic>.from(e as Map)))
          : state.room!.deathAnnouncementQueue;

      final rawLastFlip = updates['lastDeathFlip'];
      final Map<String, dynamic>? parsedLastFlip = rawLastFlip is Map
          ? Map<String, dynamic>.from(rawLastFlip)
          : state.room!.lastDeathFlip;

      final rawLogs = updates['logs'];
      final List<String> parsedLogs = rawLogs is List
          ? List<String>.from(rawLogs.map((e) => e.toString()))
          : state.room!.logs;

      final provisionalRoom = state.room!.copyWith(
        phase: updatedPhase,
        round: updates.containsKey('round')
            ? (updates['round'] is num ? (updates['round'] as num).toInt() : state.room!.round)
            : state.room!.round,
        timerSeconds: updatedTimer,
        players: DeathRegistryService.instance.filterOrEnforce(updatedPlayers),
        winner: updates.containsKey('winner')
            ? updates['winner']?.toString()
            : state.room!.winner,
        isTieBreakActive: updates.containsKey('isTieBreakActive')
            ? updates['isTieBreakActive'] == true
            : state.room!.isTieBreakActive,
        blackWolfTargetId: updates.containsKey('blackWolfTargetId')
            ? updates['blackWolfTargetId']?.toString()
            : state.room!.blackWolfTargetId,
        clearBlackWolfTargetId: updates.containsKey('blackWolfTargetId') && updates['blackWolfTargetId'] == null,
        expandedRolesState: updates.containsKey('expandedRolesState')
            ? (updates['expandedRolesState'] is Map
                ? ExpandedRolesState.fromMap(updates['expandedRolesState'] as Map)
                : state.room!.expandedRolesState)
            : state.room!.expandedRolesState,
        phaseEndsAt: updates.containsKey('phaseEndsAt')
            ? (updates['phaseEndsAt'] as int?)
            : state.room!.phaseEndsAt,
        phaseStartedAt: updates.containsKey('phaseStartedAt')
            ? (updates['phaseStartedAt'] as int?)
            : state.room!.phaseStartedAt,
        phaseDurationMs: updates.containsKey('phaseDurationMs')
            ? (updates['phaseDurationMs'] as int?)
            : state.room!.phaseDurationMs,
        currentSpeakerId: updates.containsKey('currentSpeakerId')
            ? updates['currentSpeakerId'] as String?
            : state.room!.currentSpeakerId,
        captainId: updates.containsKey('captainId')
            ? updates['captainId'] as String?
            : state.room!.captainId,
        pendingHunterId: updates.containsKey('pendingHunterId')
            ? updates['pendingHunterId'] as String?
            : state.room!.pendingHunterId,
        pendingCaptainId: updates.containsKey('pendingCaptainId')
            ? updates['pendingCaptainId'] as String?
            : state.room!.pendingCaptainId,
        nightVictimId: updates.containsKey('nightVictimId')
            ? updates['nightVictimId'] as String?
            : state.room!.nightVictimId,
        clearNightVictimId: updates.containsKey('nightVictimId') && updates['nightVictimId'] == null,
        witchHealed: updates.containsKey('witchHealed')
            ? updates['witchHealed'] == true
            : state.room!.witchHealed,
        witchPoisonVictimId: updates.containsKey('witchPoisonVictimId')
            ? updates['witchPoisonVictimId'] as String?
            : state.room!.witchPoisonVictimId,
        pyromaniacIgnited: updates.containsKey('pyromaniacIgnited')
            ? updates['pyromaniacIgnited'] == true
            : state.room!.pyromaniacIgnited,
        morningVictims: parsedMorningVictims,
        deathAnnouncementQueue: parsedDeathQueue,
        lastDeathFlip: parsedLastFlip,
        logs: parsedLogs,
      );
      state = state.copyWith(
        clearInspectedRole: isPhaseChanging,
        room: provisionalRoom,
      );
      _applyVoiceRulesForPhase(provisionalRoom);
      _syncPhaseExpirationSchedule(provisionalRoom);
    }
  }

  /// Méthode utilitaire d'écriture multi-path atomique sur rooms/$roomCode
  /// pour les opérations hors-_syncState (join, leave, status).
  Future<void> _updateRoomState(
    String roomCode,
    Map<String, dynamic> updates,
  ) async {
    try {
      await _database.ref('rooms/$roomCode').update(updates);
    } catch (e) {
      debugPrint('[_updateRoomState Error] $e');
    }
  }

  /// Créer un salon de jeu
  Future<bool> createRoom() async {
    DeathRegistryService.instance.clearForNewGame();
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final roomCode = _generateRoomCode();
      final player = PlayerModel(
        id: state.currentUserId,
        name: state.currentUserName,
        avatarIndex: state.currentUserAvatar,
        isHost: true,
        isReady: true,
        isAlive: true,
        isOnline: true,
        agoraUid: state.agoraUid,
        socketId:
            'sock_${state.currentUserId}_${DateTime.now().millisecondsSinceEpoch}',
      );

      final initialRolePool = generateDefaultRolePool(12);
      final newRoom = GameRoom(
        roomCode: roomCode,
        hostId: state.currentUserId,
        phase: GamePhase.lobby,
        players: {state.currentUserId: player},
        rolePool: initialRolePool,
        logs: ['Le salon $roomCode a été créé par ${state.currentUserName}.'],
      );

      _currentRoomRef = _database.ref('rooms/$roomCode');
      await _currentRoomRef!.set(newRoom.toMap());

      try {
        await _currentRoomRef!
            .child('players/${state.currentUserId}/isOnline')
            .onDisconnect()
            .set(false);
        await _currentRoomRef!
            .child('players/${state.currentUserId}/lastSeen')
            .onDisconnect()
            .set(ServerValue.timestamp);
      } catch (_) {}

      _subscribeToRoom(roomCode);

      await _voiceService.initialize();
      await _voiceService.joinChannel(
        channelId: 'lupus_$roomCode',
        uid: state.agoraUid,
        userAccount: state.currentUserId,
      );

      state = state.copyWith(
        room: newRoom,
        isLoading: false,
        isAdmin: false,
        isDevModeActive: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Échec de création du salon: $e',
      );
      return false;
    }
  }

  /// Rejoindre un salon
  Future<bool> joinRoom(String code) async {
    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.isEmpty) {
      state = state.copyWith(errorMessage: 'Veuillez saisir un code valide.');
      return false;
    }

    if (cleanCode == '03031994') {
      unlockAdmin('03031994');
      state = state.copyWith(isLoading: false, errorMessage: null);
      return true;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final DatabaseReference ref = _database.ref('rooms/$cleanCode');
      final DataSnapshot snapshot = await ref.get();

      if (!snapshot.exists || snapshot.value == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Salon introuvable. Vérifiez le code.',
        );
        return false;
      }

      final data = snapshot.value as Map<dynamic, dynamic>;
      final room = GameRoom.fromMap(data, cleanCode, state.currentUserId);

      // --- 4. ENTRÉE UNIQUE PAR JOUEUR DANS LE SALON (ANTI-DOUBLON & RECONNEXION) ---
      // Vérification de l'identifiant unique (userId) dans la table de hachage des joueurs
      final existingPlayer = room.players[state.currentUserId] ??
          room.playerList.cast<PlayerModel?>().firstWhere(
                (p) => p != null && p.id == state.currentUserId,
                orElse: () => null,
              );

      final String currentSocketId =
          'sock_${state.currentUserId}_${DateTime.now().millisecondsSinceEpoch}';

      if (existingPlayer != null) {
        // Enregistre tous les morts connus du salon dans le registre de cimetière
        for (final p in room.playerList) {
          if (!p.isAlive) {
            DeathRegistryService.instance.markDead(p.id);
          }
        }
        bool serverIsAlive = existingPlayer.isAlive;
        if (DeathRegistryService.instance.isDead(state.currentUserId)) {
          serverIsAlive = false;
        } else if (!serverIsAlive) {
          DeathRegistryService.instance.markDead(state.currentUserId);
        }

        // JOUEUR DÉJÀ EXISTANT : RECONNEXION & REMPLACEMENT DU SOCKET
        // Conserve le rôle, le statut de vie et les privilèges du joueur sans dupliquer son entrée
        final updatedPlayer = existingPlayer.copyWith(
          agoraUid: state.agoraUid,
          socketId: currentSocketId,
          name: state.currentUserName,
          avatarIndex: state.currentUserAvatar,
          isOnline: true,
          isAlive: serverIsAlive,
        );

        final updatedLogs = [
          ...room.logs,
          '🔄 ${state.currentUserName} s\'est reconnecté(e) au salon.',
        ];

        final leafPlayerUpdates = <String, dynamic>{
          'players/${state.currentUserId}/id': state.currentUserId,
          'players/${state.currentUserId}/agoraUid': state.agoraUid,
          'players/${state.currentUserId}/socketId': currentSocketId,
          'players/${state.currentUserId}/name': state.currentUserName,
          'players/${state.currentUserId}/avatarIndex': state.currentUserAvatar,
          'players/${state.currentUserId}/isOnline': true,
          'players/${state.currentUserId}/lastSeen': ServerValue.timestamp,
          'players/${state.currentUserId}/lastReconnectedAt': ServerValue.timestamp,
          'players/${state.currentUserId}/isAlive': serverIsAlive,
          'logs': updatedLogs,
        };

        // ── Écriture atomique unique par clés feuilles (préserve isAlive, rôles et états) ──
        await _updateRoomState(cleanCode, leafPlayerUpdates);

        try {
          final playerRef = _database.ref('rooms/$cleanCode/players/${state.currentUserId}');
          await playerRef.child('isOnline').onDisconnect().set(false);
          await playerRef.child('lastSeen').onDisconnect().set(ServerValue.timestamp);
        } catch (_) {}

        _currentRoomRef = _database.ref('rooms/$cleanCode');
        _subscribeToRoom(cleanCode);

        await _voiceService.initialize();
        await _voiceService.joinChannel(
          channelId: 'lupus_$cleanCode',
          uid: state.agoraUid,
          userAccount: state.currentUserId,
        );

        final updatedPlayers = Map<String, PlayerModel>.from(room.players)
          ..[state.currentUserId] = updatedPlayer;
        final updatedRoom = room.copyWith(players: updatedPlayers, logs: updatedLogs);

        state = state.copyWith(room: updatedRoom, isLoading: false);
        await _applyVoiceRulesForPhase(updatedRoom);
        return true;
      }

      // NOUVEAU JOUEUR TENTANT D'ENTRER DANS LE SALON
      if (room.phase != GamePhase.lobby) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Cette partie a déjà commencé.',
        );
        return false;
      }

      if (room.playerList.length >= 30) {
        state = state.copyWith(
          isLoading: false,
          errorMessage:
              'Ce salon a atteint la capacité maximale de 30 guerriers.',
        );
        return false;
      }

      final player = PlayerModel(
        id: state.currentUserId,
        name: state.currentUserName,
        avatarIndex: state.currentUserAvatar,
        isHost: false,
        isReady: false,
        isAlive: true,
        isOnline: true,
        agoraUid: state.agoraUid,
        socketId: currentSocketId,
      );

      final playerMap = player.toMap();
      playerMap['lastSeen'] = ServerValue.timestamp;

      final updatedLogs = [
        ...room.logs,
        '${state.currentUserName} a rejoint le village.',
      ];

      // ── Écriture atomique unique (joueur + logs) : rooms/$cleanCode ──
      await _updateRoomState(cleanCode, {
        'players/${state.currentUserId}': playerMap,
        'logs': updatedLogs,
      });

      try {
        final playerRef = _database.ref('rooms/$cleanCode/players/${state.currentUserId}');
        await playerRef.child('isOnline').onDisconnect().set(false);
        await playerRef.child('lastSeen').onDisconnect().set(ServerValue.timestamp);
      } catch (_) {}

      _currentRoomRef = _database.ref('rooms/$cleanCode');
      _subscribeToRoom(cleanCode);

      await _voiceService.initialize();
      await _voiceService.joinChannel(
        channelId: 'lupus_$cleanCode',
        uid: state.agoraUid,
        userAccount: state.currentUserId,
      );

      final updatedPlayers = Map<String, PlayerModel>.from(room.players)
        ..[state.currentUserId] = player;
      final updatedRoom = room.copyWith(players: updatedPlayers, logs: updatedLogs);

      state = state.copyWith(room: updatedRoom, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Impossible de rejoindre: $e',
      );
      return false;
    }
  }

  static Map<String, int> generateDefaultRolePool(int count) {
    final pool = <String, int>{};
    if (count <= 0) return pool;

    switch (count) {
      case 4:
        pool['simple_werewolf'] = 1;
        pool['seer'] = 1;
        pool['witch'] = 1;
        pool['simple_villager'] = 1;
        return pool;
      case 5:
        pool['simple_werewolf'] = 1;
        pool['seer'] = 1;
        pool['witch'] = 1;
        pool['hunter'] = 1;
        pool['simple_villager'] = 1;
        return pool;
      case 6:
        pool['simple_werewolf'] = 1;
        pool['seer'] = 1;
        pool['witch'] = 1;
        pool['hunter'] = 1;
        pool['cupid'] = 1;
        pool['simple_villager'] = 1;
        return pool;
      case 7:
        pool['simple_werewolf'] = 1;
        pool['seer'] = 1;
        pool['witch'] = 1;
        pool['hunter'] = 1;
        pool['cupid'] = 1;
        pool['little_girl'] = 1;
        pool['simple_villager'] = 1;
        return pool;
      case 8:
        pool['simple_werewolf'] = 2;
        pool['seer'] = 1;
        pool['witch'] = 1;
        pool['hunter'] = 1;
        pool['little_girl'] = 1;
        pool['simple_villager'] = 2;
        return pool;
      case 9:
        pool['simple_werewolf'] = 2;
        pool['seer'] = 1;
        pool['witch'] = 1;
        pool['hunter'] = 1;
        pool['cupid'] = 1;
        pool['little_girl'] = 1;
        pool['simple_villager'] = 2;
        return pool;
      case 10:
        pool['simple_werewolf'] = 2;
        pool['seer'] = 1;
        pool['witch'] = 1;
        pool['hunter'] = 1;
        pool['cupid'] = 1;
        pool['little_girl'] = 1;
        pool['thief'] = 1;
        pool['simple_villager'] = 2;
        return pool;
      case 11:
        pool['simple_werewolf'] = 2;
        pool['seer'] = 1;
        pool['witch'] = 1;
        pool['hunter'] = 1;
        pool['cupid'] = 1;
        pool['little_girl'] = 1;
        pool['thief'] = 1;
        pool['simple_villager'] = 3;
        return pool;
      case 12:
        pool['simple_werewolf'] = 3;
        pool['seer'] = 1;
        pool['witch'] = 1;
        pool['hunter'] = 1;
        pool['cupid'] = 1;
        pool['little_girl'] = 1;
        pool['thief'] = 1;
        pool['simple_villager'] = 3;
        return pool;
      case 13:
        pool['simple_werewolf'] = 3;
        pool['seer'] = 1;
        pool['witch'] = 1;
        pool['hunter'] = 1;
        pool['cupid'] = 1;
        pool['little_girl'] = 1;
        pool['thief'] = 1;
        pool['simple_villager'] = 4;
        return pool;
      case 14:
        pool['simple_werewolf'] = 4;
        pool['seer'] = 1;
        pool['witch'] = 1;
        pool['hunter'] = 1;
        pool['cupid'] = 1;
        pool['little_girl'] = 1;
        pool['thief'] = 1;
        pool['simple_villager'] = 4;
        return pool;
      case 15:
        pool['simple_werewolf'] = 4;
        pool['seer'] = 1;
        pool['witch'] = 1;
        pool['hunter'] = 1;
        pool['cupid'] = 1;
        pool['little_girl'] = 1;
        pool['thief'] = 1;
        pool['simple_villager'] = 5;
        return pool;
      case 16:
        pool['simple_werewolf'] = 4;
        pool['seer'] = 1;
        pool['witch'] = 1;
        pool['hunter'] = 1;
        pool['cupid'] = 1;
        pool['little_girl'] = 1;
        pool['thief'] = 1;
        pool['simple_villager'] = 6;
        return pool;
      default:
        final wolves = (count >= 28)
            ? 7
            : ((count >= 23)
                ? 6
                : ((count >= 18)
                    ? 5
                    : ((count >= 14)
                        ? 4
                        : ((count >= 12) ? 3 : ((count >= 8) ? 2 : 1)))));
        pool['simple_werewolf'] = wolves;
        pool['seer'] = 1;
        int used = wolves + 1;
        if (count >= 4 && used < count) {
          pool['witch'] = 1;
          used++;
        }
        if (count >= 5 && used < count) {
          pool['hunter'] = 1;
          used++;
        }
        if (count >= 6 && used < count) {
          pool['cupid'] = 1;
          used++;
        }
        if (count >= 7 && used < count) {
          pool['little_girl'] = 1;
          used++;
        }
        if (count >= 10 && used < count) {
          pool['thief'] = 1;
          used++;
        }
        if (count >= 8 && used < count) {
          pool['defender'] = 1;
          used++;
        }
        if (count > used) {
          pool['simple_villager'] = count - used;
        }
        return pool;
    }
  }

  Future<void> updateRolePool(String roleId, int delta) async {
    // Le Maire est un titre électif par vote, strictement interdit dans le pool de cartes
    if (roleId == GameRole.mayor.id || roleId == 'mayor') return;
    if (!state.isHost || _currentRoomRef == null || state.room == null) return;

    final currentPool = Map<String, int>.from(state.room!.rolePool);
    final currentQty = currentPool[roleId] ?? 0;
    int newQty = currentQty + delta;
    if (newQty < 0) newQty = 0;

    final isMultiple =
        (roleId == 'simple_werewolf' || roleId == 'simple_villager');
    if (!isMultiple && newQty > 1) {
      newQty = 1;
    }

    if (newQty == 0) {
      currentPool.remove(roleId);
    } else {
      currentPool[roleId] = newQty;
    }

    state = state.copyWith(room: state.room!.copyWith(rolePool: currentPool));

    final roomCode = state.room!.roomCode;
    try {
      // ── Écriture atomique unique : rooms/$roomCode/rolePool ──
      await _updateRoomState(roomCode, {'rolePool': currentPool});
    } catch (e) {
      debugPrint('[Firebase RolePool Sync Error] $e');
    }
  }

  Future<void> startGame() async {
    if (!state.isHost || _currentRoomRef == null || state.room == null) return;
    _cancelPhaseTimer();
    _resolvedDayVoteRounds.clear();
    _lastProcessedPhaseStartedAt = 0;

    final playersList = state.room!.playerList;
    final count = playersList.length;

    if (count != 12) {
      state = state.copyWith(
        errorMessage:
            'La partie nécessite exactement 12 guerriers connectés (actuellement $count).',
      );
      return;
    }

    final pool = state.room!.rolePool;
    final totalChosen = state.room!.totalRolesInPool;

    if (totalChosen != 12) {
      state = state.copyWith(
        errorMessage:
            'Le total des cartes de rôles ($totalChosen) doit être exactement de 12 cartes.',
      );
      return;
    }

    final List<GameRole> flatRoles = [];
    pool.forEach((roleId, qty) {
      final role = GameRole.fromId(roleId);
      for (int i = 0; i < qty; i++) {
        flatRoles.add(role);
      }
    });

    final secureRandom = Random.secure();
    flatRoles.shuffle(secureRandom);
    flatRoles.shuffle(secureRandom); // Double brassage cryptographique pour aléatoire 100% garanti

    final shuffledPlayers = List<PlayerModel>.from(playersList)
      ..shuffle(secureRandom);

    // Distribution des sièges à la table 100% aléatoire à chaque partie
    final seatingOrder = shuffledPlayers.map((p) => p.id).toList()
      ..shuffle(secureRandom);

    final roomCode = state.room!.roomCode;
    final isDevRoom = state.room?.isDevRoom == true;

    final Map<String, dynamic> updatedPlayers = {};
    final Map<String, dynamic> secretRoles = {};
    final List<String> wolfPlayerIds = [];

    final totalJoueurs = shuffledPlayers.length;
    final maxPotions = max(1, totalJoueurs ~/ 10);
    final maxVisions = totalJoueurs <= 4
        ? 1
        : totalJoueurs <= 9
            ? 2
            : totalJoueurs <= 14
                ? 3
                : totalJoueurs ~/ 4;

    for (int i = 0; i < shuffledPlayers.length; i++) {
      final p = shuffledPlayers[i];
      final assignedRole = flatRoles[i];
      if (assignedRole.isEvil) {
        wolfPlayerIds.add(p.id);
      }

      secretRoles[p.id] = {
        'roleId': assignedRole.id,
        'roleName': assignedRole.displayName,
        'assignedAt': ServerValue.timestamp,
      };

      final encryptedRoleToken = RoleSecurityService.encryptRole(
        assignedRole.id,
        p.id,
        roomCode,
      );

      final seatIdx = seatingOrder.indexOf(p.id);

      final updatedP = p.copyWith(
        role: isDevRoom ? assignedRole : GameRole.simpleVillager,
        initialRole: assignedRole,
        potionsVie: (assignedRole == GameRole.witch) ? maxPotions : 0,
        potionsMort: (assignedRole == GameRole.witch) ? maxPotions : 0,
        visionsRestantes: (assignedRole == GameRole.seer) ? maxVisions : 0,
        isAlive: true,
        targetVoteId: null,
        isCaptain: false,
        isLover: false,
        loverId: null,
        seatIndex: seatIdx,
        encryptedRole: encryptedRoleToken,
      );
      final pMap = updatedP.toMap();
      if (!isDevRoom) {
        pMap['role'] = 'masked';
      }
      pMap['seatIndex'] = seatIdx;
      updatedPlayers[p.id] = pMap;
    }

    try {
      await _database.ref('rooms/$roomCode/secret_roles').set(secretRoles);
      final encryptedWolves =
          RoleSecurityService.encryptWolfRoster(wolfPlayerIds, roomCode);
      await _database.ref('rooms/$roomCode/wolf_pack').set({'data': encryptedWolves});
      await _currentRoomRef!.child('seatingOrder').set(seatingOrder);
    } catch (e) {
      debugPrint('[Firebase Secret Roles Error] $e');
    }

    // Ordre : Voleur -> Cupidon -> Salvateur -> Loups -> Voyante -> Sorcière
    final assignedRoleIds = flatRoles.map((r) => r.id).toSet();
    GamePhase firstPhase;
    if (assignedRoleIds.contains('thief') ||
        assignedRoleIds.contains('thief_of_hearts') ||
        assignedRoleIds.contains('soul_stealer')) {
      firstPhase = GamePhase.nightThief;
    } else if (assignedRoleIds.contains('cupid')) {
      firstPhase = GamePhase.nightCupid;
    } else if (assignedRoleIds.contains('defender')) {
      firstPhase = GamePhase.nightDefender;
    } else if (flatRoles.any((r) => r.isEvil)) {
      firstPhase = GamePhase.nightWerewolves;
    } else if (assignedRoleIds.contains('seer')) {
      firstPhase = GamePhase.nightSeer;
    } else if (assignedRoleIds.contains('witch')) {
      firstPhase = GamePhase.nightWitch;
    } else if (assignedRoleIds.contains('pyromaniac')) {
      firstPhase = GamePhase.nightPyromaniac;
    } else {
      firstPhase = GamePhase.morningAnnouncement;
    }

    final initialLogs = [
      'L\'Arène de Lupus s\'ouvre pour $count vaillants guerriers.',
      'La Nuit 1 tombe sur le village... Les cartes secrètes ont été distribuées.',
    ];

    await _syncState({
      'phase': firstPhase.name,
      'round': 1,
      'players': updatedPlayers,
      'seatingOrder': seatingOrder,
      'captainId': null,
      'lastProtectedPlayerId': null,
      'currentProtectedPlayerId': null,
      'nightVictimId': null,
      'witchHealed': false,
      'witchPoisonVictimId': null,
      'seerInspectedTargetId': null,
      'seerInspectedRole': null,
      'morningVictims': [],
      'blackWolfTargetId': null,
      'pendingHunterId': null,
      'pendingCaptainId': null,
      'currentSpeakerId': null,
      'debateQueue': [],
      'tiedPlayerIds': [],
      'isTieBreakActive': false,
      'winner': null,
      'timerSeconds': firstPhase.durationSeconds,
      'logs': initialLogs,
    });
  }

  // ===========================================================================
  // 1. CYCLE DE JEU : ALTERNANCE NUIT / JOUR
  // ===========================================================================

  Future<void> processNightTransitions() async {
    if (state.room == null) return;
    if (_isTransitioningPhase) {
      debugPrint('[processNightTransitions] Transition déjà en cours, appel ignoré.');
      return;
    }

    _cancelPhaseTimer();
    _isTransitioningPhase = true;
    try {
      final room = state.room!;
      final current = room.phase;
      final round = room.round;
      final realRoles = await _resolveRealRoles(room);

      final next = _getNextNightPhase(
        current: current,
        round: round,
        players: room.players,
        realRoles: realRoles,
      );

      // GARDE MONOTONE STRICT : Interdiction absolue de reculer dans l'ordre des phases nocturnes
      if (current.isNight && next.isNight && next.nightOrderIndex <= current.nightOrderIndex) {
        debugPrint(
          '[processNightTransitions] Violation de monotonie nocturne : tentative de passer de $current (${current.nightOrderIndex}) à $next (${next.nightOrderIndex}) - Transition annulée.',
        );
        return;
      }

      if (next == GamePhase.morningAnnouncement) {
        await resolveMorningDeaths();
      } else {
        final logs = List<String>.from(room.logs);
        logs.add('Éveil nocturne : ${next.titleFr}.');

        final updates = <String, dynamic>{
          'phase': next.name,
          'timerSeconds': 40,
          'logs': logs,
        };

        // Entrée dans le tour des loups : réinitialisation stricte des choix stratégiques de la meute
        if (next == GamePhase.nightWerewolves) {
          updates['nightVictimId'] = null;
          updates['blackWolfTargetId'] = null;
          updates['public_state/nightVictimId'] = null;
          updates['public_state/blackWolfTargetId'] = null;
        }

        // Si Cupidon termine sa phase sans choix, lier d'office 2 survivants aléatoires
        if (current == GamePhase.nightCupid) {
          final hasLovers = room.playerList.any((p) => p.isLover);
          if (!hasLovers) {
            final alive = room.alivePlayers;
            if (alive.length >= 2) {
              final shuffled = List<PlayerModel>.from(alive)..shuffle();
              final p1 = shuffled[0].id;
              final p2 = shuffled[1].id;
              updates['players/$p1/isLover'] = true;
              updates['players/$p1/loverId'] = p2;
              updates['players/$p2/isLover'] = true;
              updates['players/$p2/loverId'] = p1;
              logs.add('💘 Le destin a uni deux cœurs dans la nuit.');
            }
          }
        }

        // Si les loups terminent leur phase, calculer et fixer leur cible pour la Voyante et la Sorcière
        if (current == GamePhase.nightWerewolves) {
          String? wolfVictimId = _tallyWerewolfVotes(realRoles) ?? room.nightVictimId;
          if (wolfVictimId != null && (room.players[wolfVictimId]?.isAlive != true || DeathRegistryService.instance.isDead(wolfVictimId))) {
            wolfVictimId = null;
          }

          if (wolfVictimId == null) {
            final innocentLiving = room.alivePlayers
                .where((p) => !(realRoles[p.id] ?? p.role).isEvil && !DeathRegistryService.instance.isDead(p.id))
                .toList();
            if (innocentLiving.isNotEmpty) {
              final randomVictim =
                  innocentLiving[Random().nextInt(innocentLiving.length)];
              wolfVictimId = randomVictim.id;
            }
          }

          if (wolfVictimId != null) {
            updates['nightVictimId'] = wolfVictimId;
            updates['public_state/nightVictimId'] = wolfVictimId;
            // CONFIDENTIALITÉ STRICTE : Ne JAMAIS divulguer l'identité de la victime dans le journal public avant l'Aube !
          }

          // Double action obligatoire : s'assurer qu'une cible de silence est définie
          String? currentSilenceId = room.blackWolfTargetId;
          if (currentSilenceId != null && (room.players[currentSilenceId]?.isAlive != true || DeathRegistryService.instance.isDead(currentSilenceId))) {
            currentSilenceId = null;
          }

          if (currentSilenceId == null && room.alivePlayers.length >= 2) {
            final silenceCandidates = room.alivePlayers
                .where((p) => p.id != wolfVictimId && !DeathRegistryService.instance.isDead(p.id))
                .toList();
            if (silenceCandidates.isNotEmpty) {
              final autoSilenceTarget =
                  silenceCandidates[Random().nextInt(silenceCandidates.length)];
              updates['blackWolfTargetId'] = autoSilenceTarget.id;
              updates['public_state/blackWolfTargetId'] = autoSilenceTarget.id;
              // CONFIDENTIALITÉ STRICTE : Ne JAMAIS divulguer la cible du silence dans le journal public avant l'Aube !
            }
          }
        }

        // Nettoyage systématique des votes lors de chaque transition
        _resetAllVotes(updates);

        await _syncState(updates);
      }
    } catch (e, stack) {
      debugPrint('[processNightTransitions Exception] $e\n$stack');
      try {
        await resolveMorningDeaths();
      } catch (_) {}
    } finally {
      _isTransitioningPhase = false;
    }
  }

  /// Séquence canonique stricte des nuits :
  /// 1: Voleur (Nuit 1) -> 2: Cupidon (Nuit 1) -> 3: Salvateur -> 4: Loups-Garous ->
  /// 5: Loup Noir -> 6: Loup Blanc (Paires) -> 7: Voyante -> 8: Renard -> 9: Sorcière ->
  /// 10: Joueur de Flûte -> 11: Pyromane -> 12: Aube
  GamePhase _getNextNightPhase({
    required GamePhase current,
    required int round,
    required Map<String, PlayerModel> players,
    Map<String, GameRole>? realRoles,
    ExpandedRolesState? expandedRolesState,
  }) {
    return _phaseCoordinator.getNextNightPhase(
      current: current,
      round: round,
      players: players,
      realRoles: realRoles,
      expandedRolesState: expandedRolesState ?? state.room?.expandedRolesState,
    );
  }

  Future<void> resolveMorningDeaths() async {
    if (state.room == null) return;

    final room = state.room!;
    if (room.phase == GamePhase.dayDebate ||
        room.phase == GamePhase.dayVoting ||
        room.phase == GamePhase.dayResolution ||
        room.phase == GamePhase.gameOver) {
      return;
    }
    try {
      final updates = <String, dynamic>{};
      final logs = List<String>.from(room.logs);
      final List<String> effectiveDeaths = [];

      // 1. Victime des Loups
      final wolfVictimId = room.nightVictimId ?? state.room?.nightVictimId ?? _tallyWerewolfVotes();
      if (wolfVictimId != null) {
        final isProtected = room.currentProtectedPlayerId == wolfVictimId;
        final isHealed = room.witchHealed || (state.room?.witchHealed == true);

        if (isProtected) {
          logs.add(
            '🛡️ Le Salvateur a veillé sur la cible des loups cette nuit !',
          );
        } else if (isHealed) {
          logs.add('✨ Une potion de guérison miraculeuse a sauvé la victime !');
        } else if (room.infectedPlayerId == wolfVictimId && !room.vileFatherInfectionUsed) {
          // L'Infect Père des Loups corrompt la victime au lieu de la tuer !
          updates['players/$wolfVictimId/isInfected'] = true;
          updates['vileFatherInfectionUsed'] = true;
          updates['infectedPlayerId'] = null;
          logs.add(
            '🩸 POUVOIR DU LOUP INFECT : La victime a survécu mais a été infectée et rejoint la meute !',
          );
          try {
            final wolfIds = room.alivePlayers
                .where((p) => p.role.isEvil || p.isInfected || p.id == wolfVictimId)
                .map((p) => p.id)
                .toList();
            updates['encryptedWolfRoster'] =
                RoleSecurityService.encryptWolfRoster(wolfIds, room.roomCode);
          } catch (_) {}
        } else {
          final victimRole = room.players[wolfVictimId]?.role;
          final ancientLives = room.expandedRolesState.ancientLives[wolfVictimId] ?? 2;
          if (victimRole == GameRole.elder && ancientLives > 1) {
            final updatedLives = Map<String, int>.from(room.expandedRolesState.ancientLives);
            updatedLives[wolfVictimId] = ancientLives - 1;
            updates['expandedRolesState'] = room.expandedRolesState.copyWith(ancientLives: updatedLives).toMap();
            logs.add('🛡️ L\'Ancien (${room.players[wolfVictimId]?.name}) résiste à la morsure des loups grâce à sa robustesse légendaire ! (1 vie restante)');
          } else {
            effectiveDeaths.add(wolfVictimId);
          }
        }
      }

      // 2. Victime du poison
      final poisonVictimId = room.witchPoisonVictimId ?? state.room?.witchPoisonVictimId;
      if (poisonVictimId != null &&
          !effectiveDeaths.contains(poisonVictimId)) {
        effectiveDeaths.add(poisonVictimId);
      }

      // 2b. Pyromane
      if (room.pyromaniacIgnited) {
        int burnedCount = 0;
        for (final p in room.alivePlayers) {
          if (p.isDoused) {
            if (!effectiveDeaths.contains(p.id)) {
              effectiveDeaths.add(p.id);
            }
            updates['players/${p.id}/isDoused'] = false;
            burnedCount++;
          }
        }
        if (burnedCount > 0) {
          logs.add(
            '🔥 LE BRASIER DU PYROMANE : $burnedCount maison(s) calcinée(s) !',
          );
        }
        updates['pyromaniacIgnited'] = false;
      }

      // 2c. Victime du Loup-Garou Blanc
      final whiteWolfTargetId = room.expandedRolesState.whiteWolfTargetId;
      if (whiteWolfTargetId != null &&
          whiteWolfTargetId.isNotEmpty &&
          !effectiveDeaths.contains(whiteWolfTargetId)) {
        effectiveDeaths.add(whiteWolfTargetId);
        final victimName = room.players[whiteWolfTargetId]?.name ?? whiteWolfTargetId;
        logs.add('🐺⚪ Le Loup-Garou Blanc a frappé dans l\'obscurité : $victimName a été déchiqueté !');
        updates['expandedRolesState'] = room.expandedRolesState.copyWith(whiteWolfTargetId: '').toMap();
      }

      // 3. Morts et Chagrin des Amoureux
      final allDeaths = <String>{...effectiveDeaths};
      for (final deadId in effectiveDeaths) {
        final partnerDead = handleLoverDeath(deadId, room.players, logs);
        if (partnerDead != null) {
          allDeaths.add(partnerDead);
        }
      }

      final List<Map<String, dynamic>> deathQueueList = [];
      for (final id in allDeaths) {
        updates['players/$id/isAlive'] = false;
        updates['cemetery/$id'] = true;
        DeathRegistryService.instance.markDead(id);
        final player = room.players[id];
        if (player != null) {
          GameRole revealedRole = player.roleInitial;
          try {
            final sSnap = await _database
                .ref('rooms/${room.roomCode}/secret_roles/$id/roleId')
                .get();
            if (sSnap.exists && sSnap.value != null) {
              revealedRole = GameRole.fromId(sSnap.value.toString());
            }
          } catch (_) {}
          updates['players/$id/role'] = revealedRole.id;
          final cause = (id == poisonVictimId)
              ? 'POISON_SORCIERE'
              : 'MORSURE_LOUPS';
          final deathEntry = {
            'action': 'FLIP_CARTE_MORT',
            'joueurId': id,
            'nom': player.name,
            'role': revealedRole.name,
            'camp': revealedRole.isEvil ? 'LOUPS' : 'VILLAGE',
            'cause': cause,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          };
          updates['lastDeathFlip'] = deathEntry;
          deathQueueList.add(deathEntry);
          logs.add(
            '💀 ${player.name} (${revealedRole.displayNameFr}) a succombé.',
          );
        }
      }
      if (deathQueueList.isNotEmpty) {
        updates['deathAnnouncementQueue'] = deathQueueList;
      }

      if (allDeaths.isEmpty) {
        logs.add(
          '🌅 L\'aube se lève sur Thiercelieux... Aucun mort n\'est à déplorer cette nuit !',
        );
      } else {
        logs.add(
          '🌅 L\'aube se lève dans le deuil. Le village compte ${allDeaths.length} trépassé(s).',
        );
      }

      // 2c. Loup Noir : Réduire au silence pour toute la durée de la journée
      if (room.blackWolfTargetId != null) {
        final silencedId = room.blackWolfTargetId!;
        final silencedPlayer = room.players[silencedId];
        if (silencedPlayer != null && !allDeaths.contains(silencedId)) {
          updates['players/$silencedId/isMuted'] = true;
          logs.add(
            '🔇 SORT DU LOUP NOIR : ${silencedPlayer.name} est réduit(e) au silence pour toute la journée ! (Micro désactivé)',
          );
          if (state.currentUserId == silencedId) {
            _voiceService.setMute(true);
          }
        }
      }

      updates['lastProtectedPlayerId'] = room.currentProtectedPlayerId;
      updates['currentProtectedPlayerId'] = null;
      updates['nightVictimId'] = null;
      updates['blackWolfTargetId'] = null;
      updates['public_state/nightVictimId'] = null;
      updates['public_state/blackWolfTargetId'] = null;
      updates['witchHealed'] = false;
      updates['witchPoisonVictimId'] = null;

      final realRoles = await _resolveRealRoles(room);

      // Montreur d'Ours : grogne à l'aube si un loup est adjacent
      final bearTamer = room.alivePlayers.cast<PlayerModel?>().firstWhere(
            (p) => p != null && (realRoles[p.id] ?? p.role) == GameRole.bearTamer,
            orElse: () => null,
          );
      if (bearTamer != null && !allDeaths.contains(bearTamer.id)) {
        final growl = ExpandedRolesCoordinator.shouldBearGrowl(
          bearTamerPlayerId: bearTamer.id,
          alivePlayerIdsInOrder: room.seatingOrder
              .where((id) => room.players[id]?.isAlive == true && !allDeaths.contains(id))
              .toList(),
          playerRoles: realRoles,
          infectedPlayerId: room.expandedRolesState.infectedPlayerId ?? room.infectedPlayerId,
        );
        if (growl) {
          logs.add('🐻 Le grognement caverneux de l\'ours résonne dans tout le village ! Au moins un loup se tapit parmi ses voisins directs.');
        }
      }

      // Chevalier à l'Épée Rouillée : contamination du loup à gauche
      for (final id in allDeaths) {
        final r = realRoles[id] ?? room.players[id]?.role;
        if (r == GameRole.knightRustySword) {
          final contaminatedWolf = ExpandedRolesCoordinator.findWolfToContaminate(
            knightPlayerId: id,
            alivePlayerIdsInOrder: room.seatingOrder.where((pid) => room.players[pid]?.isAlive == true).toList(),
            playerRoles: realRoles,
            infectedPlayerId: room.expandedRolesState.infectedPlayerId ?? room.infectedPlayerId,
          );
          if (contaminatedWolf != null) {
            final wName = room.players[contaminatedWolf]?.name ?? contaminatedWolf;
            logs.add('🗡️ L\'Épée Rouillée a entaillé $wName lors de l\'assaut nocturne ! Le venin le foudroiera la nuit prochaine.');
            updates['expandedRolesState'] = room.expandedRolesState.copyWith(
              rustyKnightContaminatedWolfId: contaminatedWolf,
              rustyKnightDeathNight: room.round + 1,
            ).toMap();
          }
        }
      }

      // Chevalier à l'Épée Rouillée : résolution de la mort différée du loup contaminé
      final contaminatedWolfId = room.expandedRolesState.rustyKnightContaminatedWolfId;
      final deathNight = room.expandedRolesState.rustyKnightDeathNight;
      if (contaminatedWolfId != null && deathNight != null && room.round >= deathNight) {
        final cWolf = room.players[contaminatedWolfId];
        if (cWolf != null && cWolf.isAlive) {
          allDeaths.add(contaminatedWolfId);
          updates['players/$contaminatedWolfId/isAlive'] = false;
          logs.add('🗡️ Le venin de l\'Épée Rouillée a terrassé ${cWolf.name} ! Le loup expire dans d\'atroces souffrances.');
          updates['expandedRolesState'] = room.expandedRolesState.copyWith(
            rustyKnightContaminatedWolfId: null,
            rustyKnightDeathNight: null,
          ).toMap();
        }
      }

      // Enfant Sauvage : transformation si son modèle périt cette nuit
      final wildModelId = room.expandedRolesState.wildChildModelId;
      if (wildModelId != null && allDeaths.contains(wildModelId)) {
        final wildChild = room.alivePlayers.cast<PlayerModel?>().firstWhere(
              (p) => p != null && (realRoles[p.id] ?? p.role) == GameRole.wildChild,
              orElse: () => null,
            );
        if (wildChild != null && !allDeaths.contains(wildChild.id)) {
          logs.add('🐺 Son modèle ayant péri cette nuit, l\'Enfant Sauvage (${wildChild.name}) succombe à sa rage bestiale et rejoint la meute !');
          updates['players/${wildChild.id}/role'] = GameRole.simpleWerewolf.id;
          updates['expandedRolesState'] = room.expandedRolesState.copyWith(wildChildTransformed: true).toMap();
        }
      }
      // Chiot de Loup : double meurtre pour la meute la nuit prochaine s'il périt
      for (final id in allDeaths) {
        final r = realRoles[id] ?? room.players[id]?.role;
        if (r == GameRole.wolfCub) {
          logs.add('🐺 Le Chiot de Loup a succombé cette nuit ! La meute enragée dévorera deux victimes la nuit prochaine.');
          updates['expandedRolesState'] = (updates['expandedRolesState'] != null
                  ? ExpandedRolesState.fromMap(updates['expandedRolesState'] as Map)
                  : room.expandedRolesState)
              .copyWith(cubDiedYesterday: true)
              .toMap();
        }
      }

      if (room.expandedRolesState.cubDiedYesterday) {
        updates['expandedRolesState'] = (updates['expandedRolesState'] != null
                ? ExpandedRolesState.fromMap(updates['expandedRolesState'] as Map)
                : room.expandedRolesState)
            .copyWith(cubDiedYesterday: false)
            .toMap();
      }

      updates['morningVictims'] = allDeaths.toList();
      _resetAllVotes(updates);

      // ── DÉCLENCHEMENT SYNCHRONE APRÈS LES MORTS DE LA NUIT (RÉSOLUTION DE L'AUBE) ──
      final simulatedRoom = room.copyWith(
        players: room.players.map(
          (k, v) => MapEntry(k, allDeaths.contains(k) ? v.copyWith(isAlive: false) : v),
        ),
      );

      final isGameOver = await evaluateVictoryConditions(
        room: simulatedRoom,
        updates: updates,
        logs: logs,
        realRoles: realRoles,
      );

      if (isGameOver) {
        // Interruption immédiate : victoire proclamée instantanément, aucune sous-phase superflue
        return;
      }

      String? pendingHunter;
      String? pendingCaptain;

      for (final id in allDeaths) {
        final p = room.players[id];
        final r = realRoles[id] ?? p?.role;
        if (r == GameRole.hunter) {
          pendingHunter = id;
        }
        if (p?.isCaptain == true || room.captainId == id) {
          pendingCaptain = id;
        }
      }

      if (pendingHunter != null) {
        updates['phase'] = GamePhase.hunterDeathChoice.name;
        updates['pendingHunterId'] = pendingHunter;
        updates['timerSeconds'] = 25;
        logs.add(
          '🎯 Le Chasseur a été abattu ! Il a 25s pour faire feu dans son dernier souffle.',
        );
      } else if (pendingCaptain != null) {
        updates['phase'] = GamePhase.mayorSuccession.name;
        updates['pendingCaptainId'] = pendingCaptain;
        updates['timerSeconds'] = 15;
        logs.add('🎖️ Le Maire est tombé ! Il dispose de 15s pour nommer son héritier.');
      } else {
        updates['phase'] = GamePhase.morningAnnouncement.name;
        updates['timerSeconds'] = 20;
      }

      updates['logs'] = logs;
      await _syncState(updates);
    } catch (e, stack) {
      debugPrint('[resolveMorningDeaths Exception] $e\n$stack');
      try {
        await _syncState({
          'phase': GamePhase.morningAnnouncement.name,
          'timerSeconds': 20,
          'witchHealed': false,
          'witchPoisonVictimId': null,
          'nightVictimId': null,
          'blackWolfTargetId': null,
          'public_state/nightVictimId': null,
          'public_state/blackWolfTargetId': null,
        });
      } catch (_) {}
    }
  }

  String? handleLoverDeath(
    String deadPlayerId,
    Map<String, PlayerModel> players,
    List<String> logs,
  ) {
    final dead = players[deadPlayerId];
    if (dead == null || !dead.isLover || dead.loverId == null) return null;

    final partner = players[dead.loverId!];
    if (partner != null && partner.isAlive) {
      logs.add(
        '💔 Mort par Amour : ${partner.name} ne peut supporter la disparition de son âme sœur ${dead.name} et meurt de chagrin sur-le-champ !',
      );
      return partner.id;
    }
    return null;
  }

  void _routeToDayPhase(
    GameRoom room,
    Map<String, dynamic> updates,
    List<String> logs,
  ) {
    _cancelPhaseTimer();

    // GARDE ABSOLU : Si une condition de victoire est atteinte, fin de partie immédiate sans sous-phase
    final win = checkWinConditions(room);
    if (win != null) {
      updates['phase'] = GamePhase.gameOver.name;
      updates['winner'] = win;
      logs.add(_formatVictoryMessage(win));
      return;
    }

    final mayorId = room.captainId ?? room.expandedRolesState.mayorPlayerId;
    final isMayorAlive = mayorId != null && (room.players[mayorId]?.isAlive ?? false);

    if (room.round == 1 && mayorId == null) {
      updates['phase'] = GamePhase.mayorElection.name;
      updates['timerSeconds'] = 15;
      logs.add(
        '🗳️ Jour 1 : Le village se rassemble pour élire son premier Maire !',
      );
      return;
    }

    if (isMayorAlive && !room.expandedRolesState.mayorSpeechOpeningDone) {
      updates['phase'] = GamePhase.mayorSpeechOpening.name;
      updates['currentSpeakerId'] = mayorId;
      updates['timerSeconds'] = 15;
      final mayorName = room.players[mayorId]?.name ?? 'Le Maire';
      logs.add('🎖️ $mayorName ouvre solennellement les débats de l\'arène (15s) !');
      return;
    }

    final queue = List<String>.from(room.alivePlayers.map((p) => p.id));
    while (queue.isNotEmpty && (room.players[queue.first]?.isMuted ?? false)) {
      final mutedId = queue.removeAt(0);
      final mutedName = room.players[mutedId]?.name ?? 'Un citoyen';
      logs.add('🔇 $mutedName est bâillonné par les loups ! Son tour de parole est sauté.');
    }

    if (queue.isNotEmpty) {
      updates['phase'] = GamePhase.dayDebate.name;
      updates['debateQueue'] = queue;
      updates['currentSpeakerId'] = queue.first;
      updates['timerSeconds'] = 60;
      final speakerName = room.players[queue.first]?.name ?? 'Inconnu';
      logs.add(
        '🎙️ Débat du village ouvert. Parole exclusive accordée à $speakerName (60s).',
      );
    } else {
      if (isMayorAlive && !room.expandedRolesState.mayorSpeechClosingDone) {
        updates['phase'] = GamePhase.mayorSpeechClosing.name;
        updates['currentSpeakerId'] = mayorId;
        updates['timerSeconds'] = 15;
        final mayorName = room.players[mayorId]?.name ?? 'Le Maire';
        logs.add('⚖️ Clôture des débats : parole solennelle accordée à $mayorName (15s) avant l\'ouverture du scrutin !');
      } else {
        updates['phase'] = GamePhase.dayVoting.name;
        updates['currentPhase'] = 'JOUR_VOTE';
        updates['timerSeconds'] = 15;
      }
    }
  }

  // ===========================================================================
  // C. PHASE DIURNE (DÉBAT & VOTE)
  // ===========================================================================

  Future<void> concludeMayorSpeechOpening() async {
    if (state.room == null) return;
    final room = state.room!;
    if (room.phase != GamePhase.mayorSpeechOpening) return;

    final updates = <String, dynamic>{
      'expandedRolesState': room.expandedRolesState
          .copyWith(mayorSpeechOpeningDone: true)
          .toMap(),
    };
    final logs = List<String>.from(room.logs);

    final queue = List<String>.from(room.alivePlayers.map((p) => p.id));
    while (queue.isNotEmpty && (room.players[queue.first]?.isMuted ?? false)) {
      final mutedId = queue.removeAt(0);
      final mutedName = room.players[mutedId]?.name ?? 'Un citoyen';
      logs.add('🔇 $mutedName est bâillonné par les loups ! Son tour de parole est sauté.');
    }

    if (queue.isNotEmpty) {
      updates['phase'] = GamePhase.dayDebate.name;
      updates['debateQueue'] = queue;
      updates['currentSpeakerId'] = queue.first;
      updates['timerSeconds'] = 60;
      final speakerName = room.players[queue.first]?.name ?? 'Inconnu';
      logs.add(
        '🎙️ Le Maire a ouvert les débats. Parole exclusive accordée à $speakerName (60s).',
      );
    } else {
      final mayorId = room.captainId ?? room.expandedRolesState.mayorPlayerId;
      final isMayorAlive =
          mayorId != null && (room.players[mayorId]?.isAlive ?? false);
      if (isMayorAlive && !room.expandedRolesState.mayorSpeechClosingDone) {
        updates['phase'] = GamePhase.mayorSpeechClosing.name;
        updates['currentSpeakerId'] = mayorId;
        updates['timerSeconds'] = 15;
      } else {
        updates['phase'] = GamePhase.dayVoting.name;
        updates['currentPhase'] = 'JOUR_VOTE';
        updates['timerSeconds'] = 15;
        logs.add('⚖️ Ouverture immédiate du scrutin du bûcher (15s).');
      }
    }

    updates['logs'] = logs;
    await _syncState(updates);
  }

  Future<void> concludeMayorSpeechClosing() async {
    if (state.room == null) return;
    final room = state.room!;
    if (room.phase != GamePhase.mayorSpeechClosing) return;

    final updates = <String, dynamic>{
      'phase': GamePhase.dayVoting.name,
      'currentPhase': 'JOUR_VOTE',
      'currentSpeakerId': null,
      'debateQueue': [],
      'timerSeconds': 15,
      'expandedRolesState': room.expandedRolesState
          .copyWith(mayorSpeechClosingDone: true)
          .toMap(),
    };
    final logs = List<String>.from(room.logs);
    logs.add(
      '⚖️ Le Maire a prononcé son mot de clôture. Scrutin de 15s ouvert pour désigner un suspect au bûcher !',
    );
    _resetAllVotes(updates);
    updates['logs'] = logs;
    await _syncState(updates);
  }

  Future<void> passTurnDebate() async {
    if (state.room == null) return;
    final room = state.room!;

    if (room.phase == GamePhase.mayorSpeechOpening) {
      await concludeMayorSpeechOpening();
      return;
    }
    if (room.phase == GamePhase.mayorSpeechClosing) {
      await concludeMayorSpeechClosing();
      return;
    }
    if (room.phase != GamePhase.dayDebate) return;

    final queue = List<String>.from(room.debateQueue);
    final updates = <String, dynamic>{};
    final logs = List<String>.from(room.logs);
    final currentSpeakerName =
        room.players[room.currentSpeakerId]?.name ?? 'Un citoyen';

    if (queue.isNotEmpty) {
      queue.removeAt(0);
    }

    // SAUT AUTOMATIQUE SI LE JOUEUR EST RÉDUIT AU SILENCE (isMuted)
    while (queue.isNotEmpty && (room.players[queue.first]?.isMuted ?? false)) {
      final mutedId = queue.removeAt(0);
      final mutedName = room.players[mutedId]?.name ?? 'Un citoyen';
      logs.add('🔇 $mutedName est bâillonné par les loups ! Son tour de parole est sauté.');
    }

    if (queue.isNotEmpty) {
      final nextSpeakerId = queue.first;
      final speakerName = room.players[nextSpeakerId]?.name ?? 'Inconnu';
      updates['debateQueue'] = queue;
      updates['currentSpeakerId'] = nextSpeakerId;
      updates['timerSeconds'] = 60;
      logs.add('🎙️ $currentSpeakerName a cédé sa parole. La parole passe à $speakerName.');
    } else {
      final mayorId = room.captainId ?? room.expandedRolesState.mayorPlayerId;
      final isMayorAlive =
          mayorId != null && (room.players[mayorId]?.isAlive ?? false);

      if (isMayorAlive && !room.expandedRolesState.mayorSpeechClosingDone) {
        updates['phase'] = GamePhase.mayorSpeechClosing.name;
        updates['currentSpeakerId'] = mayorId;
        updates['debateQueue'] = [];
        updates['timerSeconds'] = 15;
        final mayorName = room.players[mayorId]?.name ?? 'Le Maire';
        logs.add('⚖️ Clôture des débats : parole solennelle accordée à $mayorName (15s) avant l\'ouverture du scrutin !');
      } else {
        updates['phase'] = GamePhase.dayVoting.name;
        updates['currentPhase'] = 'JOUR_VOTE';
        updates['currentSpeakerId'] = null;
        updates['debateQueue'] = [];
        updates['timerSeconds'] = 15;
        logs.add(
          '⚖️ Les débats sont clos. Scrutin de 15s ouvert pour désigner un suspect au bûcher !',
        );
      }
    }

    updates['logs'] = logs;
    await _syncState(updates);
  }

  Future<void> passDebate() => passTurnDebate();

  /// Clôture immédiate du débat et bascule autoritaire sur le vote du village (JOUR_VOTE / dayVoting)
  Future<void> endDebateAndOpenVote() async {
    if (state.room == null) return;
    final room = state.room!;
    if (room.phase != GamePhase.dayDebate) return;

    final mayorId = room.captainId ?? room.expandedRolesState.mayorPlayerId;
    final isMayorAlive =
        mayorId != null && (room.players[mayorId]?.isAlive ?? false);

    final updates = <String, dynamic>{};
    final logs = List<String>.from(room.logs);

    if (isMayorAlive && !room.expandedRolesState.mayorSpeechClosingDone) {
      updates['phase'] = GamePhase.mayorSpeechClosing.name;
      updates['currentSpeakerId'] = mayorId;
      updates['debateQueue'] = [];
      updates['timerSeconds'] = 15;
      final mayorName = room.players[mayorId]?.name ?? 'Le Maire';
      logs.add('⚖️ Temps de débat expiré : $mayorName prend la parole pour son discours de clôture (15s) !');
    } else {
      updates['phase'] = GamePhase.dayVoting.name;
      updates['currentPhase'] = 'JOUR_VOTE';
      updates['currentSpeakerId'] = null;
      updates['debateQueue'] = [];
      updates['timerSeconds'] = 15;
      logs.add(
        '⚖️ Temps de débat expiré : clôture automatique et ouverture immédiate du scrutin du bûcher (15s) !',
      );
    }

    _resetAllVotes(updates);
    await _syncState(updates);
  }

  Future<void> processDayVoteResolution() async {
    if (!state.isHost || state.room == null) return;
    if (_isTransitioningPhase) {
      debugPrint('[processDayVoteResolution] Transition déjà en cours, appel ignoré.');
      return;
    }

    final room = state.room!;
    if (room.phase != GamePhase.dayVoting && room.phase != GamePhase.dayTieBreakVote) {
      debugPrint('[processDayVoteResolution] Appel ignoré : la phase actuelle (${room.phase.name}) n\'est pas un scrutin diurne.');
      return;
    }

    if (_resolvedDayVoteRounds.contains(room.round)) {
      debugPrint('🛡️ [Idempotence Guard] Vote du tour ${room.round} déjà résolu, appel ignoré.');
      return;
    }

    _cancelPhaseTimer();
    _isTransitioningPhase = true;
    try {
      await _processDayVoteResolutionInternal();
    } finally {
      _isTransitioningPhase = false;
    }
  }

  Future<void> _processDayVoteResolutionInternal() async {
    final room = state.room!;
    final updates = <String, dynamic>{};
    final logs = List<String>.from(room.logs);

    final livingCount = room.alivePlayers.length;
    final mayorId = room.captainId ?? room.expandedRolesState.mayorPlayerId;

    // ── LECTURE AUTORITAIRE DIRECTE DE LA TABLE DES VOTES SUR FIREBASE ──
    // Élimine toute race condition où un vote concurrent validé sur le réseau n'a pas
    // encore été traité par le flux asynchrone local.
    final liveVotes = <String, String>{};
    try {
      final snap = await _currentRoomRef?.child('votes').get();
      if (snap != null && snap.exists && snap.value is Map) {
        (snap.value as Map).forEach((k, v) {
          if (v != null) liveVotes[k.toString()] = v.toString();
        });
      }
    } catch (e) {
      debugPrint('[VoteResolution] Avertissement: échec lecture directe votes: $e');
    }

    final voteTally = <String, int>{};
    for (final voter in room.alivePlayers) {
      // Priorité au snapshot direct Firebase, sinon fallback sur l'état local
      final target = liveVotes[voter.id] ?? voter.targetVoteId;
      if (target != null) {
        final weight = _phaseCoordinator.getVoteWeight(
          voterId: voter.id,
          mayorPlayerId: mayorId,
          livingCount: livingCount,
        );
        voteTally[target] = (voteTally[target] ?? 0) + weight;
      }
    }

    // 1. Bonus de 2 voix du Corbeau
    final crowTarget = room.expandedRolesState.crowTargetId;
    if (crowTarget != null && room.players[crowTarget]?.isAlive == true) {
      voteTally[crowTarget] = (voteTally[crowTarget] ?? 0) + 2;
      logs.add('🦅 Malédiction du Corbeau : 2 voix d\'office accablent ${room.players[crowTarget]?.name ?? crowTarget} !');
      updates['expandedRolesState'] = room.expandedRolesState.copyWith(crowTargetId: null).toMap();
    }

    if (voteTally.isEmpty) {
      logs.add(
        '🕊️ Aucun vote exprimé. Le village s\'endort sans condamnation.',
      );
      _finishDayCycle(room, updates, logs);
      await _syncState(updates);
      return;
    }

    final maxVotes = voteTally.values.reduce(max);
    final topCandidates = voteTally.entries
        .where((e) => e.value == maxVotes)
        .map((e) => e.key)
        .toList();

    if (topCandidates.length == 1) {
      await _executeCondemnedPlayer(topCandidates.first, room, updates, logs);
      return;
    }

    logs.add(
      '⚖️ Égalité parfaite au scrutin (${topCandidates.length} accusés à $maxVotes voix) !',
    );

    // 2. Sacrifice canonique du Bouc Émissaire en cas d'égalité
    final scapegoat = room.alivePlayers.cast<PlayerModel?>().firstWhere(
          (p) => p != null && p.role == GameRole.scapegoat,
          orElse: () => null,
        );
    if (scapegoat != null) {
      logs.add(
        '🐐 Égalité des suffrages ! Le Bouc Émissaire ${scapegoat.name} est désigné coupable expiatoire d\'office et trépasse pour le village !',
      );
      await _executeCondemnedPlayer(scapegoat.id, room, updates, logs);
      return;
    }

    final captain = room.players[room.captainId];
    if (captain != null &&
        captain.isAlive &&
        !topCandidates.contains(captain.id) &&
        captain.targetVoteId != null &&
        topCandidates.contains(captain.targetVoteId)) {
      final deciderTarget = captain.targetVoteId!;
      logs.add(
        '🎖️ Le Maire ${captain.name} tranche l\'égalité et condamne ${room.players[deciderTarget]?.name} !',
      );
      await _executeCondemnedPlayer(deciderTarget, room, updates, logs);
      return;
    }

    if (room.isTieBreakActive) {
      logs.add(
        '🌙 La seconde égalité persiste. La clémence l\'emporte : personne n\'est exécuté ce soir.',
      );
      updates['isTieBreakActive'] = false;
      updates['tiedPlayerIds'] = [];
      _finishDayCycle(room, updates, logs);
      await _syncState(updates);
      return;
    }

    updates['phase'] = GamePhase.dayDefense.name;
    updates['isTieBreakActive'] = true;
    updates['tiedPlayerIds'] = topCandidates;
    updates['debateQueue'] = List<String>.from(topCandidates);
    updates['currentSpeakerId'] = topCandidates.first;
    updates['timerSeconds'] = 30;

    _resetAllVotes(updates);
    final suspectNames = topCandidates
        .map((id) => room.players[id]?.name ?? '')
        .join(', ');
    logs.add(
      '🛡️ Phase de défense accordée aux suspects : $suspectNames (30s chacun).',
    );

    updates['logs'] = logs;
    await _syncState(updates);
  }

  Future<void> _executeCondemnedPlayer(
    String condemnedId,
    GameRoom room,
    Map<String, dynamic> updates,
    List<String> logs,
  ) async {
    final condemned = room.players[condemnedId];
    if (condemned == null) return;

    GameRole condemnedRealRole = condemned.role;
    try {
      final sSnap = await _database
          .ref('rooms/${room.roomCode}/secret_roles/$condemnedId/roleId')
          .get();
      if (sSnap.exists && sSnap.value != null) {
        condemnedRealRole = GameRole.fromId(sSnap.value.toString());
      }
    } catch (_) {}

    if (room.round == 1 && condemnedRealRole == GameRole.angel) {
      _cancelPhaseTimer();
      updates['players/$condemnedId/isAlive'] = false;
      updates['players/$condemnedId/role'] = condemnedRealRole.id;
      updates['phase'] = GamePhase.gameOver.name;
      updates['winner'] = 'angel';
      logs.add(
        '🪽 L\'Ange ${condemned.name} a été condamné dès le Jour 1 ! Il remporte instantanément la victoire solitaire !',
      );
      updates['logs'] = logs;
      await _syncState(updates);
      return;
    }

    if (condemnedRealRole == GameRole.idiot) {
      if (room.expandedRolesState.idiotPardoned) {
        logs.add(
          '⚖️ L\'Idiot du Village ${condemned.name} a déjà épuisé sa grâce passée. Le verdict s\'abat irrémédiablement !',
        );
      } else {
        logs.add(
          '🤪 L\'Idiot du Village ${condemned.name} est gracié par la compassion du village ! Il reste en vie mais perd tout droit de vote.',
        );
        final inMemoryState = GameState(
          currentTurn: room.round,
          currentPhase: room.phase,
          playerRoles: {condemnedId: GameRole.idiot},
          players: room.players,
          expandedRolesState: room.expandedRolesState,
          pendingExecutedPlayerId: condemnedId,
        );
        RoleHandlersRegistry.dispatchAction(
          inMemoryState,
          role: GameRole.idiot,
          actorId: condemnedId,
          payload: {},
        );
        final updatedExpanded = room.expandedRolesState.copyWith(
          idiotPardoned: true,
          permanentlyBannedVoters: {
            ...room.expandedRolesState.permanentlyBannedVoters,
            condemnedId,
          },
        );
        updates['expandedRolesState'] = updatedExpanded.toMap();
        _finishDayCycle(room, updates, logs);
        updates['logs'] = logs;
        await _syncState(updates);
        return;
      }
    }

    updates['players/$condemnedId/isAlive'] = false;
    updates['cemetery/$condemnedId'] = true;
    DeathRegistryService.instance.markDead(condemnedId);
    updates['players/$condemnedId/role'] = condemnedRealRole.id;
    final voteDeathEntry = {
      'action': 'FLIP_CARTE_MORT',
      'joueurId': condemnedId,
      'nom': condemned.name,
      'role': condemnedRealRole.name,
      'camp': condemnedRealRole.isEvil ? 'LOUPS' : 'VILLAGE',
      'cause': 'VOTE_VILLAGE',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    updates['lastDeathFlip'] = voteDeathEntry;
    final List<Map<String, dynamic>> voteDeathQueue = [voteDeathEntry];
    logs.add(
      '🔥 Le village a jeté ${condemned.name} aux flammes du bûcher ! Il était ${condemnedRealRole.displayNameFr}.',
    );

    final deadPartnerId = handleLoverDeath(condemnedId, room.players, logs);
    if (deadPartnerId != null) {
      updates['players/$deadPartnerId/isAlive'] = false;
      updates['cemetery/$deadPartnerId'] = true;
      DeathRegistryService.instance.markDead(deadPartnerId);
      final deadPartner = room.players[deadPartnerId];
      if (deadPartner != null) {
        GameRole partnerRole = deadPartner.role;
        try {
          final pSnap = await _database
              .ref('rooms/${room.roomCode}/secret_roles/$deadPartnerId/roleId')
              .get();
          if (pSnap.exists && pSnap.value != null) {
            partnerRole = GameRole.fromId(pSnap.value.toString());
          }
        } catch (_) {}
        updates['players/$deadPartnerId/role'] = partnerRole.id;
        voteDeathQueue.add({
          'action': 'FLIP_CARTE_MORT',
          'joueurId': deadPartnerId,
          'nom': deadPartner.name,
          'role': partnerRole.name,
          'camp': partnerRole.isEvil ? 'LOUPS' : 'VILLAGE',
          'cause': 'AMOUREUX',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      }
    }
    updates['deathAnnouncementQueue'] = voteDeathQueue;

    final allDeaths = {
      condemnedId,
      ?deadPartnerId,
    };

    // Ancien : Déchéance des pouvoirs si exécuté par le village
    if (ExpandedRolesCoordinator.checkElderDeathConsequences(
      killedPlayerId: condemnedId,
      killedRole: condemnedRealRole,
      eliminationSource: 'vote',
    )) {
      logs.add('📜 Malédiction de l\'Ancien : Condamné par le village, l\'Ancien maudit Thiercelieux ! Tous les villageois perdent leurs pouvoirs.');
      updates['expandedRolesState'] = room.expandedRolesState.copyWith(ancientPowerLost: true).toMap();
    }

    // Enfant Sauvage : transformation en loup si son modèle périt
    final wildModelId = room.expandedRolesState.wildChildModelId;
    if (wildModelId != null && allDeaths.contains(wildModelId)) {
      final wildChild = room.alivePlayers.cast<PlayerModel?>().firstWhere(
            (p) => p != null && p.role == GameRole.wildChild,
            orElse: () => null,
          );
      if (wildChild != null && !allDeaths.contains(wildChild.id)) {
        logs.add('🐺 Son modèle ayant péri, l\'Enfant Sauvage (${wildChild.name}) succombe à sa rage bestiale et rejoint la meute !');
        updates['players/${wildChild.id}/role'] = GameRole.simpleWerewolf.id;
        updates['expandedRolesState'] = room.expandedRolesState.copyWith(wildChildTransformed: true).toMap();
      }
    }

    // Chiot de Loup : double meurtre pour la meute la nuit prochaine s'il est lynché
    if (condemnedRealRole == GameRole.wolfCub) {
      logs.add('🐺 Le Chiot de Loup a été lynché par le village ! La meute enragée dévorera deux victimes la nuit prochaine.');
      updates['expandedRolesState'] = (updates['expandedRolesState'] != null
              ? ExpandedRolesState.fromMap(updates['expandedRolesState'] as Map)
              : room.expandedRolesState)
          .copyWith(cubDiedYesterday: true)
          .toMap();
    }

    String? pendingHunter;
    String? pendingCaptain;

    final realRoles = await _resolveRealRoles(room);

    for (final id in allDeaths) {
      final p = room.players[id];
      final r = realRoles[id] ?? p?.role;
      if (r == GameRole.hunter) pendingHunter = id;
      if (p?.isCaptain == true || room.captainId == id || room.expandedRolesState.mayorPlayerId == id) {
        pendingCaptain = id;
      }
    }

    // ── DÉCLENCHEMENT SYNCHRONE APRÈS L'ÉLIMINATION DU VOTE DIURNE (BÛCHER) ──
    final simulatedRoom = room.copyWith(
      players: room.players.map(
        (k, v) =>
            MapEntry(k, allDeaths.contains(k) ? v.copyWith(isAlive: false) : v),
      ),
    );

    final isGameOver = await evaluateVictoryConditions(
      room: simulatedRoom,
      updates: updates,
      logs: logs,
      realRoles: realRoles,
    );

    if (isGameOver) {
      // Interruption immédiate : fin de partie proclamée, aucune sous-phase superflue
      return;
    }

    if (pendingHunter != null) {
      updates['phase'] = GamePhase.hunterDeathChoice.name;
      updates['pendingHunterId'] = pendingHunter;
      updates['timerSeconds'] = 25;
      logs.add(
        '🎯 Le Chasseur ${room.players[pendingHunter]?.name} s\'effondre et épaule son fusil (25s) !',
      );
    } else if (pendingCaptain != null) {
      updates['phase'] = GamePhase.mayorSuccession.name;
      updates['pendingCaptainId'] = pendingCaptain;
      updates['timerSeconds'] = 15;
      logs.add(
        '🎖️ Le Maire doit désigner son successeur avant de mourir (15s).',
      );
    } else if (room.expandedRolesState.isSecondVoteTriggered) {
      logs.add('⚖️ Le Juge Bègue a exigé un second vote consécutif ! Le village retourne immédiatement aux urnes.');
      updates['phase'] = GamePhase.dayVoting.name;
      updates['timerSeconds'] = 30;
      updates['expandedRolesState'] = room.expandedRolesState.copyWith(
        isSecondVoteTriggered: false,
        judgeSecondVoteAvailable: false,
      ).toMap();
      _resetAllVotes(updates);
    } else {
      _finishDayCycle(room, updates, logs);
    }

    updates['logs'] = logs;
    await _syncState(updates);
  }

  void _finishDayCycle(
    GameRoom room,
    Map<String, dynamic> updates,
    List<String> logs,
  ) {
    _cancelPhaseTimer();
    _resolvedDayVoteRounds.add(room.round);
    updates['phase'] = GamePhase.dayResolution.name;
    updates['round'] = room.round;
    updates['timerSeconds'] = 10;
    updates['isTieBreakActive'] = false;
    updates['tiedPlayerIds'] = [];
    if (room.expandedRolesState.bannedVotersForToday.isNotEmpty) {
      updates['expandedRolesState'] = (updates['expandedRolesState'] != null
              ? ExpandedRolesState.fromMap(updates['expandedRolesState'] as Map)
              : room.expandedRolesState)
          .copyWith(bannedVotersForToday: const {})
          .toMap();
    }
    _resetAllVotes(updates);
  }

  // ===========================================================================
  // 2. CONDITIONS D'ARRÊT ET DÉCLARATION DE VICTOIRE
  // ===========================================================================

  /// Résout les rôles réels (authentiques) de tous les joueurs de la salle,
  /// que la salle soit en production (chiffrée/masquée) ou en mode test.
  Future<Map<String, GameRole>> _resolveRealRoles(GameRoom room) async {
    final roles = <String, GameRole>{};

    for (final p in room.playerList) {
      if (p.encryptedRole != null && p.encryptedRole!.isNotEmpty) {
        final dec = RoleSecurityService.decryptRole(
          p.encryptedRole,
          p.id,
          room.roomCode,
        );
        if (dec != null) {
          roles[p.id] = dec;
          continue;
        }
      }
      if (p.role != GameRole.simpleVillager || room.isDevRoom) {
        roles[p.id] = p.role;
      }
    }

    final missing = room.playerList
        .where((p) =>
            !roles.containsKey(p.id) || roles[p.id] == GameRole.simpleVillager)
        .toList();
    if (missing.isNotEmpty) {
      try {
        final snap = await _database
            .ref('rooms/${room.roomCode}/secret_roles')
            .get();
        if (snap.exists && snap.value is Map) {
          final map = snap.value as Map;
          for (final entry in map.entries) {
            final pId = entry.key.toString();
            if (entry.value is Map) {
              final roleId = (entry.value as Map)['roleId']?.toString();
              if (roleId != null) {
                roles[pId] = GameRole.fromId(roleId);
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[resolveRealRoles Firebase Error] $e');
      }
    }

    for (final p in room.playerList) {
      roles.putIfAbsent(p.id, () => p.role);
    }
    return roles;
  }

  static String? checkWinConditions(
    GameRoom room, [
    Map<String, GameRole>? resolvedRealRoles,
  ]) {
    final alive = room.alivePlayers;
    if (alive.isEmpty) return 'draw';

    GameRole getRole(PlayerModel p) {
      if (resolvedRealRoles != null && resolvedRealRoles.containsKey(p.id)) {
        return resolvedRealRoles[p.id]!;
      }
      return p.resolveRealRole(room.roomCode);
    }

    // 1. Victoire Absolue des Amoureux : les deux derniers survivants sont en couple
    if (alive.length == 2) {
      final p1 = alive[0];
      final p2 = alive[1];
      if (p1.isLover && p1.loverId == p2.id) {
        return 'lovers';
      }
    }

    // 2. Victoire Solitaire : Joueur de Flûte (tous les autres vivants sont charmés)
    final piper = alive.cast<PlayerModel?>().firstWhere(
          (p) => p != null && getRole(p) == GameRole.piedPiper,
          orElse: () => null,
        );
    if (piper != null) {
      final others = alive.where((p) => p.id != piper.id);
      if (others.isNotEmpty && others.every((p) => p.isCharmed)) {
        return 'piedPiper';
      }
    }

    // 2b. Victoire Solitaire : Abominable Sectaire (éradication du clan adverse)
    final sectarian = alive.cast<PlayerModel?>().firstWhere(
          (p) => p != null && getRole(p) == GameRole.sectLeader,
          orElse: () => null,
        );
    if (sectarian != null && room.expandedRolesState.sectarianTeams.isNotEmpty) {
      final isSectarianVictor = ExpandedRolesCoordinator.checkSectarianVictory(
        sectarianPlayerId: sectarian.id,
        alivePlayerIds: alive.map((p) => p.id).toList(),
        sectarianTeams: room.expandedRolesState.sectarianTeams,
      );
      if (isSectarianVictor) {
        return 'abominableSectarian';
      }
    }

    // 3. Victoires Solitaires au Dernier Survivant (Loup Blanc ou Pyromane)
    if (alive.length == 1) {
      final survivor = alive.first;
      final role = getRole(survivor);
      if (role == GameRole.whiteWerewolf) return 'whiteWerewolf';
      if (role == GameRole.pyromaniac) return 'pyromaniac';
      if (role == GameRole.sectLeader) return 'abominableSectarian';
      if (role.isEvil) return 'werewolves';
      return 'village';
    }

    // 4. Décompte des camps avec les vrais rôles (y compris les infectés)
    final aliveWolves = alive.where((p) => getRole(p).isEvil || p.isInfected).length;
    final aliveVillagers = alive.where((p) => !getRole(p).isEvil && !p.isInfected).length;

    // Rôles solitaires hostiles pouvant encore l'emporter seuls
    final hasHostileSolo = alive.any((p) {
      final r = getRole(p);
      return r == GameRole.pyromaniac || r == GameRole.whiteWerewolf;
    });

    // Détection d'un couple mixte encore en vie (un loup et un villageois)
    final hasLivingMixedCouple = alive.any((p) {
      if (!p.isLover || p.loverId == null) return false;
      final partner = room.players[p.loverId!];
      if (partner == null || !partner.isAlive || DeathRegistryService.instance.isDead(partner.id)) {
        return false;
      }
      final pIsWolf = getRole(p).isEvil || p.isInfected;
      final partnerIsWolf = getRole(partner).isEvil || partner.isInfected;
      return pIsWolf != partnerIsWolf;
    });

    // Condition canonique de victoire des Loups :
    // - Au moins un loup en vie (aliveWolves > 0)
    // - Parité ou supériorité numérique atteinte face aux villageois (aliveWolves >= aliveVillagers)
    // - Aucun rôle solitaire hostile (Loup Blanc, Pyromane) en vie
    // - Aucun couple mixte encore en vie (sinon le couple mixte peut encore l'emporter)
    final bool wolvesWon = (aliveWolves > 0) &&
        (aliveWolves >= aliveVillagers) &&
        !hasHostileSolo &&
        !hasLivingMixedCouple;

    if (wolvesWon) {
      return 'werewolves';
    }

    // Condition canonique de victoire du Village :
    // - Tous les loups sont éliminés (aliveWolves == 0)
    // - Aucun rôle solitaire hostile en vie
    if (aliveWolves == 0) {
      if (!hasHostileSolo) {
        return 'village';
      }
    }

    // La partie continue (nuit ou jour suivant)
    return null;
  }

  static String _formatVictoryMessage(String winner) {
    switch (winner) {
      case 'village':
      case 'VILLAGERS':
      case 'villagers':
        return '🏆 Victoire triomphale du Village ! Tous les loups-garous et traîtres ont été exterminés.';
      case 'werewolves':
      case 'WOLVES':
      case 'wolves':
        return '🩸 Victoire sanguinaire de la Meute ! Les loups-garous ont dévoré la totalité du village.';
      case 'lovers':
        return '💖 Victoire absolue des Amoureux ! Leur passion triomphe sur toutes les allégeances.';
      case 'angel':
        return '🪽 Victoire divine de l\'Ange ! Son martyre dès le premier jour l\'élève au rang suprême.';
      case 'piedPiper':
        return '🎶 Victoire envoûtante du Joueur de Flûte ! Tous les survivants sont charmés sous son emprise.';
      case 'whiteWerewolf':
        return '🐺 Victoire solitaire du Loup-Garou Blanc ! Il a massacré meute et village sans pitié.';
      case 'pyromaniac':
        return '🔥 Victoire solitaire du Pyromane ! Le village entier n\'est plus qu\'un tas de cendres.';
      case 'abominableSectarian':
      case 'sectLeader':
        return '🌀 Victoire de l\'Abominable Sectaire ! Seuls les adeptes de son culte ont survécu.';
      default:
        return '🏁 Fin de partie : Égalité funeste, aucun survivant ne subsiste.';
    }
  }

  /// Évaluation synchrone des conditions de victoire et interruption immédiate du jeu en cas de victoire.
  /// Stoppe instantanément le flux de la partie (purge des timers, annonce de la victoire et fin de cycle).
  Future<bool> evaluateVictoryConditions({
    required GameRoom room,
    required Map<String, dynamic> updates,
    required List<String> logs,
    Map<String, GameRole>? realRoles,
  }) async {
    final roles = realRoles ?? await _resolveRealRoles(room);
    final win = checkWinConditions(room, roles);
    if (win != null) {
      _cancelPhaseTimer();
      updates['phase'] = GamePhase.gameOver.name;
      updates['winner'] = win;
      logs.add(_formatVictoryMessage(win));
      for (final p in room.playerList) {
        final pRole = roles[p.id] ?? p.role;
        updates['players/${p.id}/role'] = pRole.id;
      }
      updates['logs'] = logs;
      await _syncState(updates);
      debugPrint('🏆 [evaluateVictoryConditions] Fin de partie immédiate : $win.');
      return true;
    }
    return false;
  }

  /// Alias conforme à la spécification checkGameEnd
  Future<bool> checkGameEnd({
    required GameRoom room,
    required Map<String, dynamic> updates,
    required List<String> logs,
    Map<String, GameRole>? realRoles,
  }) => evaluateVictoryConditions(
    room: room,
    updates: updates,
    logs: logs,
    realRoles: realRoles,
  );

  // ===========================================================================
  // POUVOIRS ET ACTIONS SPÉCIFIQUES DES JOUEURS
  // ===========================================================================

  Future<void> thiefSteal(String targetPlayerId) async {
    final bool canAct = state.myRole == GameRole.thief ||
        state.myRole == GameRole.thiefOfHearts ||
        state.isAdmin ||
        state.isDevMode;
    if (!canAct || _currentRoomRef == null) {
      return;
    }
    final target = state.room?.players[targetPlayerId];
    if (target == null) return;
    final roomCode = state.room?.roomCode;
    if (roomCode == null) return;

    // Détermination de l'ID effectif du voleur
    String thiefId = state.effectiveUserId;
    if (state.myRole != GameRole.thief && state.myRole != GameRole.thiefOfHearts) {
      final t = state.room?.alivePlayers.cast<PlayerModel?>().firstWhere(
            (p) => p != null && (p.role == GameRole.thief || p.role == GameRole.thiefOfHearts),
            orElse: () => null,
          );
      if (t != null) thiefId = t.id;
    }

    final thiefPlayer = state.room?.players[thiefId];
    final thiefRole = thiefPlayer?.role ?? state.myRole;
    final isSoulStealer = thiefRole == GameRole.thiefOfHearts || state.myRole == GameRole.thiefOfHearts;

    // Résolution du rôle authentique de la cible (démasquage live et dev)
    GameRole stolenRole = target.role;
    if (stolenRole == GameRole.simpleVillager || target.encryptedRole != null) {
      if (target.encryptedRole != null && target.encryptedRole!.isNotEmpty) {
        final dec = RoleSecurityService.decryptRole(
          target.encryptedRole,
          target.id,
          roomCode,
        );
        if (dec != null) stolenRole = dec;
      }
      try {
        final sSnap = await _database
            .ref('rooms/$roomCode/secret_roles/$targetPlayerId/roleId')
            .get();
        if (sSnap.exists && sSnap.value != null) {
          stolenRole = GameRole.fromId(sSnap.value.toString());
        }
      } catch (_) {}
    }

    // Exécution du handler métier
    final inMemoryState = GameState(
      currentTurn: state.room?.round ?? 1,
      currentPhase: state.room?.phase ?? GamePhase.nightThief,
      playerRoles: {
        for (final p in (state.room?.playerList ?? <PlayerModel>[]))
          p.id: p.role,
        thiefId: thiefRole,
        targetPlayerId: stolenRole,
      },
    );
    RoleHandlersRegistry.dispatchAction(
      inMemoryState,
      role: isSoulStealer ? GameRole.thiefOfHearts : GameRole.thief,
      actorId: thiefId,
      payload: {'targetId': targetPlayerId},
    );

    final encryptedThiefRole = RoleSecurityService.encryptRole(
      stolenRole.id,
      thiefId,
      roomCode,
    );
    final encryptedTargetRole = RoleSecurityService.encryptRole(
      GameRole.simpleVillager.id,
      targetPlayerId,
      roomCode,
    );

    final updates = <String, dynamic>{
      'players/$thiefId/role': stolenRole.id,
      'players/$thiefId/encryptedRole': encryptedThiefRole,
      'players/$targetPlayerId/role': GameRole.simpleVillager.id,
      'players/$targetPlayerId/encryptedRole': encryptedTargetRole,
      'players/$targetPlayerId/potionsVie': 0,
      'players/$targetPlayerId/potionsMort': 0,
      'players/$targetPlayerId/visionsRestantes': 0,
      'logs': [
        ...?state.room?.logs,
        isSoulStealer
            ? 'Une ombre insaisissable a dérobé l\'âme d\'un citoyen cette nuit...'
            : 'Une ombre a dérobé l\'identité d\'un citoyen cette nuit...',
      ],
    };

    // Attribution des charges de pouvoir si applicable
    final totalJoueurs = state.room?.players.length ?? 8;
    final maxPotions = max(1, totalJoueurs ~/ 10);
    final maxVisions = totalJoueurs <= 4
        ? 1
        : totalJoueurs <= 9
            ? 2
            : totalJoueurs <= 14
                ? 3
                : totalJoueurs ~/ 4;

    final stolenPotionsVie = target.potionsVie > 0 ? target.potionsVie : maxPotions;
    final stolenPotionsMort = target.potionsMort > 0 ? target.potionsMort : maxPotions;
    final stolenVisions = target.visionsRestantes > 0 ? target.visionsRestantes : maxVisions;

    if (stolenRole == GameRole.witch) {
      updates['players/$thiefId/potionsVie'] = stolenPotionsVie;
      updates['players/$thiefId/potionsMort'] = stolenPotionsMort;
    } else if (stolenRole == GameRole.seer) {
      updates['players/$thiefId/visionsRestantes'] = stolenVisions;
    }

    // Gestion de la meute de loups
    final allAlive = state.room?.alivePlayers ?? [];
    final wolfIds = allAlive
        .where((p) =>
            (p.id == thiefId && stolenRole.isEvil) ||
            (p.id != targetPlayerId && p.id != thiefId && p.role.isEvil))
        .map((p) => p.id)
        .toList();
    if (stolenRole.isEvil && !wolfIds.contains(thiefId)) {
      wolfIds.add(thiefId);
    }
    try {
      final encWolves = RoleSecurityService.encryptWolfRoster(wolfIds, roomCode);
      updates['encryptedWolfRoster'] = encWolves;
      await _database.ref('rooms/$roomCode/wolf_pack').set({'data': encWolves});
    } catch (_) {}

    await _syncState(updates);

    // CRUCIAL : Mise à jour des rôles secrets dans Firebase RTDB
    try {
      await Future.wait([
        _database
            .ref('rooms/$roomCode/secret_roles/$thiefId/roleId')
            .set(stolenRole.id),
        _database
            .ref('rooms/$roomCode/secret_roles/$thiefId/roleName')
            .set(stolenRole.displayName),
        _database
            .ref('rooms/$roomCode/secret_roles/$targetPlayerId/roleId')
            .set(GameRole.simpleVillager.id),
        _database
            .ref('rooms/$roomCode/secret_roles/$targetPlayerId/roleName')
            .set(GameRole.simpleVillager.displayName),
      ]);
    } catch (e) {
      debugPrint('[Thief Steal secret_roles error] $e');
    }

    // Mise à jour optimiste du state local
    if (state.room != null) {
      final curPlayers = Map<String, PlayerModel>.from(state.room!.players);
      if (curPlayers.containsKey(thiefId)) {
        curPlayers[thiefId] = curPlayers[thiefId]!.copyWith(
          role: stolenRole,
          encryptedRole: encryptedThiefRole,
          potionsVie: stolenRole == GameRole.witch ? stolenPotionsVie : 0,
          potionsMort: stolenRole == GameRole.witch ? stolenPotionsMort : 0,
          visionsRestantes: stolenRole == GameRole.seer ? stolenVisions : 0,
        );
      }
      if (curPlayers.containsKey(targetPlayerId)) {
        curPlayers[targetPlayerId] = curPlayers[targetPlayerId]!.copyWith(
          role: GameRole.simpleVillager,
          encryptedRole: encryptedTargetRole,
          potionsVie: 0,
          potionsMort: 0,
          visionsRestantes: 0,
        );
      }
      final updatedRoom = state.room!.copyWith(players: curPlayers);
      state = state.copyWith(room: updatedRoom);

      if (thiefId == state.currentUserId && stolenRole.isEvil) {
        _syncWolfRoster(roomCode);
      }
    }

    await processNightTransitions();
  }

  Future<void> thiefChooseRole(GameRole chosenRole) async {
    final bool canAct = state.myRole == GameRole.thief ||
        state.myRole == GameRole.thiefOfHearts ||
        state.isAdmin ||
        state.isDevMode;
    if (!canAct || _currentRoomRef == null) {
      return;
    }
    final roomCode = state.room?.roomCode;
    if (roomCode == null) return;

    String thiefId = state.effectiveUserId;
    if (state.myRole != GameRole.thief && state.myRole != GameRole.thiefOfHearts) {
      final t = state.room?.alivePlayers.cast<PlayerModel?>().firstWhere(
            (p) => p != null && (p.role == GameRole.thief || p.role == GameRole.thiefOfHearts),
            orElse: () => null,
          );
      if (t != null) thiefId = t.id;
    }

    final thiefPlayer = state.room?.players[thiefId];
    final thiefRole = thiefPlayer?.role ?? state.myRole;
    final isSoulStealer = thiefRole == GameRole.thiefOfHearts || state.myRole == GameRole.thiefOfHearts;

    // Dispatch métier via handler
    final inMemoryState = GameState(
      currentTurn: state.room?.round ?? 1,
      currentPhase: state.room?.phase ?? GamePhase.nightThief,
      playerRoles: {
        for (final p in (state.room?.playerList ?? <PlayerModel>[]))
          p.id: p.role,
        thiefId: thiefRole,
      },
    );
    RoleHandlersRegistry.dispatchAction(
      inMemoryState,
      role: isSoulStealer ? GameRole.thiefOfHearts : GameRole.thief,
      actorId: thiefId,
      payload: {'chosenRole': chosenRole},
    );

    final encryptedThiefRole = RoleSecurityService.encryptRole(
      chosenRole.id,
      thiefId,
      roomCode,
    );

    final updates = <String, dynamic>{
      'players/$thiefId/role': chosenRole.id,
      'players/$thiefId/encryptedRole': encryptedThiefRole,
      'logs': [
        ...?state.room?.logs,
        'Le Voleur a choisi une nouvelle destinée parmi les cartes dissimulées...',
      ],
    };

    final totalJoueurs = state.room?.players.length ?? 8;
    final maxPotions = max(1, totalJoueurs ~/ 10);
    final maxVisions = totalJoueurs <= 4
        ? 1
        : totalJoueurs <= 9
            ? 2
            : totalJoueurs <= 14
                ? 3
                : totalJoueurs ~/ 4;

    if (chosenRole == GameRole.witch) {
      updates['players/$thiefId/potionsVie'] = maxPotions;
      updates['players/$thiefId/potionsMort'] = maxPotions;
    } else if (chosenRole == GameRole.seer) {
      updates['players/$thiefId/visionsRestantes'] = maxVisions;
    }

    if (chosenRole.isEvil) {
      try {
        final wolfIds = state.room?.alivePlayers
            .where((p) => p.role.isEvil || p.id == thiefId)
            .map((p) => p.id)
            .toList() ?? [thiefId];
        final encrypted = RoleSecurityService.encryptWolfRoster(
            wolfIds, roomCode);
        updates['encryptedWolfRoster'] = encrypted;
        await _database.ref('rooms/$roomCode/wolf_pack').set({'data': encrypted});
      } catch (_) {}
    }

    await _syncState(updates);
    try {
      await Future.wait([
        _database
            .ref('rooms/$roomCode/secret_roles/$thiefId/roleId')
            .set(chosenRole.id),
        _database
            .ref('rooms/$roomCode/secret_roles/$thiefId/roleName')
            .set(chosenRole.displayName),
      ]);
    } catch (_) {}

    // Mise à jour optimiste du state local
    if (state.room != null) {
      final curPlayers = Map<String, PlayerModel>.from(state.room!.players);
      if (curPlayers.containsKey(thiefId)) {
        curPlayers[thiefId] = curPlayers[thiefId]!.copyWith(
          role: chosenRole,
          encryptedRole: encryptedThiefRole,
          potionsVie: chosenRole == GameRole.witch ? maxPotions : 0,
          potionsMort: chosenRole == GameRole.witch ? maxPotions : 0,
          visionsRestantes: chosenRole == GameRole.seer ? maxVisions : 0,
        );
      }
      final updatedRoom = state.room!.copyWith(players: curPlayers);
      state = state.copyWith(room: updatedRoom);

      if (thiefId == state.currentUserId && chosenRole.isEvil) {
        _syncWolfRoster(roomCode);
      }
    }

    await processNightTransitions();
  }

  Future<void> piperCharmPlayers(List<String> targetIds) async {
    if ((state.myRole != GameRole.piedPiper && !state.isAdmin) ||
        _currentRoomRef == null) {
      return;
    }
    final updates = <String, dynamic>{};
    final charmedList = List<String>.from(state.room?.charmedPlayerIds ?? []);
    for (final id in targetIds) {
      updates['players/$id/isCharmed'] = true;
      if (!charmedList.contains(id)) {
        charmedList.add(id);
      }
    }
    updates['charmedPlayerIds'] = charmedList;
    updates['logs'] = [
      ...?state.room?.logs,
      '🎵 Une mélodie ensorcelante résonne dans la nuit : de nouvelles âmes sont charmées.',
    ];

    if (state.room != null) {
      final inMemoryState = GameState(
        currentTurn: state.room!.round,
        currentPhase: state.room!.phase,
        players: state.room!.players,
        expandedRolesState: state.room!.expandedRolesState,
      );
      RoleHandlersRegistry.dispatchAction(
        inMemoryState,
        role: GameRole.piedPiper,
        actorId: state.effectiveUserId,
        payload: {'targetIds': targetIds},
      );
    }

    await _syncState(updates);
    await processNightTransitions();
  }

  Future<void> infectWolfInfect(String targetPlayerId) async {
    if ((state.myRole != GameRole.vileFatherOfWolves && !state.isAdmin) ||
        _currentRoomRef == null) {
      return;
    }
    if (state.room?.vileFatherInfectionUsed == true) return;
    await _syncState({
      'infectedPlayerId': targetPlayerId,
    });
  }

  Future<bool> foxSniff(String targetPlayerId) async {
    if (state.room == null || _currentRoomRef == null) return false;
    final room = state.room!;
    if (state.myRole != GameRole.fox && !state.isAdmin) return false;
    if (room.expandedRolesState.ancientPowerLost) return false;
    if (!room.expandedRolesState.foxPowerActive) return false;

    final realRoles = await _resolveRealRoles(room);
    final seatingOrder = room.seatingOrder.isNotEmpty
        ? room.seatingOrder
        : room.players.keys.toList();
    final aliveIds = seatingOrder.where((id) => room.players[id]?.isAlive == true).toList();

    final trio = ExpandedRolesCoordinator.getFoxTrioIds(
      targetPlayerId: targetPlayerId,
      alivePlayerIdsInOrder: aliveIds,
    );

    final hasWolf = ExpandedRolesCoordinator.resolveFoxSniff(
      targetPlayerId: targetPlayerId,
      alivePlayerIdsInOrder: aliveIds,
      playerRoles: realRoles,
      infectedPlayerId: room.expandedRolesState.infectedPlayerId ?? room.infectedPlayerId,
    );

    // Mémorisation locale immédiate pour le Renard (Fog of War asymétrique)
    state = state.copyWith(
      foxSniffedPlayerIds: trio,
      foxWolfDetected: hasWolf,
    );

    final inMemoryState = GameState(
      currentTurn: room.round,
      currentPhase: room.phase,
      playerRoles: realRoles,
      players: room.players,
      expandedRolesState: room.expandedRolesState,
      alivePlayerIdsInOrder: aliveIds,
    );
    RoleHandlersRegistry.dispatchAction(
      inMemoryState,
      role: GameRole.fox,
      actorId: state.effectiveUserId,
      payload: {'targetId': targetPlayerId},
    );

    final updates = <String, dynamic>{};
    for (final id in trio) {
      updates['players/$id/isSniffed'] = true;
      updates['players/$id/hasWolfSmell'] = hasWolf;
    }
    final updatedExpanded = room.expandedRolesState.copyWith(
      foxPowerActive: hasWolf,
      lastFoxCheckResult: hasWolf,
    );
    updates['expandedRolesState'] = updatedExpanded.toMap();

    final logs = List<String>.from(room.logs);
    if (hasWolf) {
      logs.add('🦊 Le Renard a flairé une odeur suspecte ! Au moins un loup se cache dans le groupe observé.');
    } else {
      logs.add('🦊 Le Renard n\'a rien senti d\'anormal... Son flair s\'éteint à tout jamais.');
    }
    updates['logs'] = logs;
    await _syncState(updates);

    // Délai de 2.5 secondes pour permettre l'observation visuelle immédiate sur la table avant transition
    await Future.delayed(const Duration(milliseconds: 2500));
    await processNightTransitions();
    return hasWolf;
  }

  Future<void> foxPass() async {
    if (state.room == null || _currentRoomRef == null) return;
    final room = state.room!;
    if (state.myRole != GameRole.fox && !state.isAdmin) return;

    final inMemoryState = GameState(
      currentTurn: room.round,
      currentPhase: room.phase,
      players: room.players,
      expandedRolesState: room.expandedRolesState,
    );
    RoleHandlersRegistry.dispatchAction(
      inMemoryState,
      role: GameRole.fox,
      actorId: state.effectiveUserId,
      payload: {'skip': true},
    );

    final logs = List<String>.from(room.logs);
    logs.add('🦊 Le Renard a choisi de préserver son flair et ne flaire personne cette nuit.');
    await _syncState({'logs': logs});
    await processNightTransitions();
  }

  Future<void> whiteWolfDevour(String targetPlayerId) async {
    if (state.room == null || _currentRoomRef == null) return;
    final room = state.room!;
    if (state.myRole != GameRole.whiteWerewolf && !state.isAdmin) return;

    final inMemoryState = GameState(
      currentTurn: room.round,
      currentPhase: room.phase,
      players: room.players,
      expandedRolesState: room.expandedRolesState,
    );
    RoleHandlersRegistry.dispatchAction(
      inMemoryState,
      role: GameRole.whiteWerewolf,
      actorId: state.effectiveUserId,
      payload: {'targetId': targetPlayerId},
    );

    final targetName = room.players[targetPlayerId]?.name ?? targetPlayerId;
    final logs = List<String>.from(room.logs);
    logs.add('🐺⚪ Le Loup-Garou Blanc a éliminé $targetName dans l\'obscurité...');

    final updatedExpanded = room.expandedRolesState.copyWith(
      whiteWolfTargetId: targetPlayerId,
    );
    final updates = <String, dynamic>{
      'expandedRolesState': updatedExpanded.toMap(),
      'logs': logs,
    };
    await _syncState(updates);
    await processNightTransitions();
  }

  Future<void> whiteWolfPass() async {
    if (state.room == null || _currentRoomRef == null) return;
    final room = state.room!;
    if (state.myRole != GameRole.whiteWerewolf && !state.isAdmin) return;

    final inMemoryState = GameState(
      currentTurn: room.round,
      currentPhase: room.phase,
      players: room.players,
      expandedRolesState: room.expandedRolesState,
    );
    RoleHandlersRegistry.dispatchAction(
      inMemoryState,
      role: GameRole.whiteWerewolf,
      actorId: state.effectiveUserId,
      payload: {'skip': true},
    );

    final logs = List<String>.from(room.logs);
    logs.add('🐺⚪ Le Loup-Garou Blanc a choisi de ne dévorer aucun loup cette nuit.');
    await _syncState({'logs': logs});
    await processNightTransitions();
  }

  Future<void> crowDesignate(String targetPlayerId) async {
    if (state.room == null || _currentRoomRef == null) return;
    final room = state.room!;
    if (state.myRole != GameRole.raven && !state.isAdmin) return;

    final targetName = room.players[targetPlayerId]?.name ?? targetPlayerId;
    final updates = <String, dynamic>{
      'expandedRolesState': room.expandedRolesState.copyWith(crowTargetId: targetPlayerId).toMap(),
      'logs': [
        ...room.logs,
        '🦅 Le Corbeau a cloué un sinistre mot d\'accusation sur la porte de $targetName.',
      ],
    };
    await _syncState(updates);
    await processNightTransitions();
  }

  Future<void> wildChildChooseModel(String modelId) async {
    if (state.room == null || _currentRoomRef == null) return;
    final room = state.room!;
    if (state.myRole != GameRole.wildChild && !state.isAdmin) return;

    final modelName = room.players[modelId]?.name ?? modelId;
    final updates = <String, dynamic>{
      'expandedRolesState': room.expandedRolesState.copyWith(wildChildModelId: modelId).toMap(),
      'logs': [
        ...room.logs,
        '🐾 L\'Enfant Sauvage a choisi $modelName comme modèle protecteur pour son existence.',
      ],
    };
    await _syncState(updates);
    await processNightTransitions();
  }

  Future<void> stutteringJudgeTriggerSecondVote() async {
    if (state.room == null || _currentRoomRef == null) return;
    final room = state.room!;
    if (state.myRole != GameRole.stutteringJudge && !state.isAdmin) return;
    if (!room.expandedRolesState.judgeSecondVoteAvailable) return;

    final updates = <String, dynamic>{
      'expandedRolesState': room.expandedRolesState.copyWith(
        isSecondVoteTriggered: true,
        judgeSecondVoteAvailable: false,
      ).toMap(),
      'logs': [
        ...room.logs,
        '⚖️ Le Juge Bègue a fait le signe convenu : un second vote aura lieu immédiatement après le premier !',
      ],
    };
    await _syncState(updates);
  }

  Future<void> sectarianFormTeams(List<String> teamA, List<String> teamB) async {
    if (state.room == null || _currentRoomRef == null) return;
    final room = state.room!;
    if (state.myRole != GameRole.sectLeader && !state.isAdmin) return;

    final updates = <String, dynamic>{
      'expandedRolesState': room.expandedRolesState.copyWith(
        sectarianTeams: {'teamA': teamA, 'teamB': teamB},
      ).toMap(),
      'logs': [
        ...room.logs,
        '🌀 L\'Abominable Sectaire a divisé en secret le village en deux factions opposées.',
      ],
    };
    await _syncState(updates);
    await processNightTransitions();
  }

  Future<void> scapegoatBanVoters(Set<String> bannedVoters) async {
    if (state.room == null || _currentRoomRef == null) return;
    final room = state.room!;
    if (state.myRole != GameRole.scapegoat && !state.isAdmin) return;

    final updates = <String, dynamic>{
      'expandedRolesState': room.expandedRolesState.copyWith(
        bannedVotersForToday: bannedVoters,
      ).toMap(),
      'logs': [
        ...room.logs,
        '🐐 Dans son dernier souffle, le Bouc Émissaire a privé certains citoyens de leur droit de vote pour le prochain jour.',
      ],
    };
    await _syncState(updates);
  }

  Future<void> actorChooseRole(GameRole chosenRole) async {
    if (state.room == null || _currentRoomRef == null) return;
    final room = state.room!;
    if (state.myRole != GameRole.actor && !state.isAdmin) return;

    final actorId = state.effectiveUserId;
    final currentRoles = List<GameRole>.from(room.expandedRolesState.actorAvailableRoles[actorId] ?? []);
    currentRoles.remove(chosenRole);

    final updatedMap = Map<String, List<GameRole>>.from(room.expandedRolesState.actorAvailableRoles);
    updatedMap[actorId] = currentRoles;

    final updates = <String, dynamic>{
      'players/$actorId/role': chosenRole.id,
      'expandedRolesState': room.expandedRolesState.copyWith(
        actorAvailableRoles: updatedMap,
      ).toMap(),
      'logs': [
        ...room.logs,
        '🎭 Le Comédien endosse le costume d\'un nouveau rôle pour la nuit !',
      ],
    };
    await _syncState(updates);
    await processNightTransitions();
  }

  Future<void> cupidBindLovers(String p1Id, String p2Id) async {
    if ((state.myRole != GameRole.cupid && !state.isAdmin) ||
        _currentRoomRef == null) {
      return;
    }
    if (p1Id == p2Id) return;

    if (state.room != null) {
      final inMemoryState = GameState(
        currentTurn: state.room!.round,
        currentPhase: state.room!.phase,
        players: state.room!.players,
        expandedRolesState: state.room!.expandedRolesState,
      );
      RoleHandlersRegistry.dispatchAction(
        inMemoryState,
        role: GameRole.cupid,
        actorId: state.effectiveUserId,
        payload: {'lover1Id': p1Id, 'lover2Id': p2Id},
      );
    }

    await _syncState({
      'players/$p1Id/isLover': true,
      'players/$p1Id/loverId': p2Id,
      'players/$p2Id/isLover': true,
      'players/$p2Id/loverId': p1Id,
      'logs': [
        ...?state.room?.logs,
        '💘 Deux flèches ont fendu la nuit : deux cœurs sont désormais unis à la vie, à la mort.',
      ],
    });
    await processNightTransitions();
  }

  Future<void> pyromaniacDouse(String targetPlayerId) async {
    if ((state.myRole != GameRole.pyromaniac && !state.isAdmin) ||
        _currentRoomRef == null) {
      return;
    }
    final target = state.room?.players[targetPlayerId];
    if (target == null) return;

    if (state.room != null) {
      final inMemoryState = GameState(
        currentTurn: state.room!.round,
        currentPhase: state.room!.phase,
        players: state.room!.players,
        expandedRolesState: state.room!.expandedRolesState,
      );
      RoleHandlersRegistry.dispatchAction(
        inMemoryState,
        role: GameRole.pyromaniac,
        actorId: state.effectiveUserId,
        payload: {'action': 'douse', 'targetId': targetPlayerId},
      );
    }

    await _syncState({
      'players/$targetPlayerId/isDoused': true,
      'logs': [
        ...?state.room?.logs,
        '🛢️ Une forte odeur de carburant plane silencieusement sur les toits cette nuit...',
      ],
    });
    await processNightTransitions();
  }

  Future<void> pyromaniacIgnite() async {
    if ((state.myRole != GameRole.pyromaniac && !state.isAdmin) ||
        _currentRoomRef == null) {
      return;
    }

    if (state.room != null) {
      final inMemoryState = GameState(
        currentTurn: state.room!.round,
        currentPhase: state.room!.phase,
        players: state.room!.players,
        expandedRolesState: state.room!.expandedRolesState,
      );
      RoleHandlersRegistry.dispatchAction(
        inMemoryState,
        role: GameRole.pyromaniac,
        actorId: state.effectiveUserId,
        payload: {'action': 'ignite'},
      );
    }

    await _syncState({
      'pyromaniacIgnited': true,
      'logs': [
        ...?state.room?.logs,
        '🔥 Le Pyromane frotte une allumette... L\'enfer s\'abattra au petit matin !',
      ],
    });
    await processNightTransitions();
  }

  Future<void> pyromaniacPass() async {
    if (state.room != null) {
      final inMemoryState = GameState(
        currentTurn: state.room!.round,
        currentPhase: state.room!.phase,
        players: state.room!.players,
        expandedRolesState: state.room!.expandedRolesState,
      );
      RoleHandlersRegistry.dispatchAction(
        inMemoryState,
        role: GameRole.pyromaniac,
        actorId: state.effectiveUserId,
        payload: {'skip': true},
      );
    }
    await processNightTransitions();
  }

  /// Pouvoir de silence des loups : durant la nuit, sélectionne un joueur vivant pour le réduire au silence
  Future<bool> blackWolfSilence(String targetPlayerId) => werewolfSilence(targetPlayerId);

  Future<bool> defenderProtect(String targetPlayerId) async {
    if ((state.myRole != GameRole.defender && !state.isAdmin) ||
        _currentRoomRef == null) {
      return false;
    }
    if (state.room?.lastProtectedPlayerId == targetPlayerId) {
      state = state.copyWith(
        errorMessage:
            'Vous ne pouvez pas protéger le même joueur deux nuits consécutives.',
      );
      return false;
    }

    if (state.room != null) {
      final inMemoryState = GameState(
        currentTurn: state.room!.round,
        currentPhase: state.room!.phase,
        players: state.room!.players,
        lastProtectedPlayerId: state.room!.lastProtectedPlayerId,
        expandedRolesState: state.room!.expandedRolesState,
      );
      RoleHandlersRegistry.dispatchAction(
        inMemoryState,
        role: GameRole.defender,
        actorId: state.effectiveUserId,
        payload: {'targetId': targetPlayerId},
      );
    }

    await _syncState({
      'currentProtectedPlayerId': targetPlayerId,
      'logs': [
        ...?state.room?.logs,
        'Le salvateur a étendu son bouclier protecteur sur un foyer.',
      ],
    });
    await processNightTransitions();
    return true;
  }

  /// Fonction d'inspection du rôle de la Voyante :
  /// Si le joueur ciblé possède le rôle Loup Blanc (loupBlanc / whiteWerewolf),
  /// la fonction retourne Simple Villageois (simpleVillageois / simpleVillager) au lieu de son vrai rôle.
  static GameRole getSeerPerceivedRole(GameRole actualRole) {
    if (actualRole == GameRole.whiteWerewolf) {
      return GameRole.simpleVillager;
    }
    return actualRole;
  }

  Future<PlayerModel?> inspectPlayer(String targetId) async {
    if (state.myRole != GameRole.seer && !state.isAdmin) return null;
    final target = state.room?.players[targetId];
    if (target == null) return null;

    // Résolution du vrai rôle depuis Firebase (rôle chiffré ou devMode)
    GameRole discoveredRole = target.role;
    final roomCode = state.room?.roomCode;
    if (roomCode != null) {
      try {
        final snap = await _database
            .ref('rooms/$roomCode/secret_roles/$targetId/roleId')
            .get();
        if (snap.exists && snap.value != null) {
          discoveredRole = GameRole.fromId(snap.value.toString());
        }
      } catch (e) {
        debugPrint('[Seer Inspect Error] $e');
      }
    }

    // ═══════════════════════════════════════════════════════════════
    // RÈGLE CANONIQUE : Masquage absolu du Loup Blanc pour la Voyante.
    // Le Loup Blanc apparaît systématiquement comme un Simple Villageois
    // aux yeux de la Voyante — il est invisible aux deux camps.
    // ═══════════════════════════════════════════════════════════════
    final inspectedRole = (discoveredRole == GameRole.whiteWerewolf)
        ? GameRole.simpleVillager
        : discoveredRole;

    final updatedMap = Map<String, GameRole>.from(state.seerInspectedRoles);
    updatedMap[targetId] = inspectedRole;

    // Récupération de la Voyante et de son quota de visions restantes
    final seerPlayer = state.room?.playerList.cast<PlayerModel?>().firstWhere(
      (p) => p != null && (p.role == GameRole.seer || p.roleInitial == GameRole.seer),
      orElse: () => state.currentPlayer,
    );
    final seerId = seerPlayer?.id ?? state.currentUserId;
    final curVisions = seerPlayer?.visionsRestantes ?? 1;

    // ═══════════════════════════════════════════════════════════════
    // RÈGLE CANONIQUE : Quota de visions scalant par nombre de joueurs
    // ≤4j → 1  |  5-9j → 2  |  10-14j → 3  |  ≥15j → N÷4
    // Si le quota est épuisé, la Voyante ne peut plus inspecter.
    // ═══════════════════════════════════════════════════════════════
    if (curVisions <= 0 && !state.isAdmin) {
      debugPrint('[inspectPlayer] Quota de visions épuisé — inspection refusée.');
      return null;
    }

    final newVisions = max(0, curVisions - 1);
    final isDechue = newVisions == 0;

    await _syncState({
      'players/$seerId/visionsRestantes': newVisions,
      if (isDechue) 'players/$seerId/role': GameRole.simpleVillager.name,
      'logs': [
        ...?state.room?.logs,
        '🔮 La Voyante a sondé une âme ($newVisions vision(s) restante(s)).',
        if (isDechue)
          '🥀 La Voyante a épuisé toutes ses visions : elle devient désormais Simple Villageoise !',
      ],
    });

    state = state.copyWith(
      inspectedRole: inspectedRole,
      seerInspectedRoles: updatedMap,
    );
    return target.copyWith(role: inspectedRole);
  }

  Future<void> completeSeerTurn() async {
    if (state.room == null) return;
    final inMemoryState = GameState(
      currentTurn: state.room!.round,
      currentPhase: state.room!.phase,
      players: state.room!.players,
      expandedRolesState: state.room!.expandedRolesState,
    );
    RoleHandlersRegistry.dispatchAction(
      inMemoryState,
      role: GameRole.seer,
      actorId: state.effectiveUserId,
      payload: {},
    );

    final currentLogs = List<String>.from(state.room!.logs);
    currentLogs.add('La Voyante a achevé sa vision nocturne.');
    await _syncState({'logs': currentLogs});
    state = state.copyWith(clearInspectedRole: true);
    await processNightTransitions();
  }

  Future<void> castVote(String? targetId) async {
    if (_currentRoomRef == null) return;
    final voterId = state.effectiveUserId;
    if ((!state.isAlive || DeathRegistryService.instance.isDead(voterId)) && !state.isAdmin) {
      debugPrint('[castVote] ⛔ Action bloquée: $voterId est décédé et ne peut pas voter.');
      return;
    }
    if (targetId != null && (DeathRegistryService.instance.isDead(targetId) || state.room?.players[targetId]?.isAlive == false)) {
      debugPrint('[castVote] ⛔ Action bloquée: impossible de voter contre $targetId qui est déjà décédé.');
      return;
    }
    if ((state.room?.phase == GamePhase.dayVoting || state.room?.phase == GamePhase.dayTieBreakVote) &&
        (state.room?.expandedRolesState.bannedVotersForToday.contains(voterId) == true ||
         state.room?.expandedRolesState.permanentlyBannedVoters.contains(voterId) == true)) {
      debugPrint('[castVote] ⛔ Action bloquée: $voterId est privé de son droit de vote.');
      return;
    }
    final voteUpdates = <String, dynamic>{
      'players/$voterId/targetVoteId': targetId,
      'votes/$voterId': targetId,
    };

    if (state.room?.phase == GamePhase.nightWerewolves && state.room != null) {
      final currentWolfVotes = <String, int>{};
      for (final p in state.room!.alivePlayers) {
        if (p.role.isEvil || p.role == GameRole.whiteWerewolf || p.id == voterId) {
          final chosenTarget = (p.id == voterId) ? targetId : p.targetVoteId;
          if (chosenTarget != null) {
            currentWolfVotes[chosenTarget] = (currentWolfVotes[chosenTarget] ?? 0) + 1;
          }
        }
      }
      if (currentWolfVotes.isNotEmpty) {
        final majorityTarget = currentWolfVotes.entries.reduce((a, b) => a.value > b.value ? a : b).key;
        voteUpdates['nightVictimId'] = majorityTarget;
        voteUpdates['public_state/nightVictimId'] = majorityTarget;
        state = state.copyWith(
          room: state.room?.copyWith(
            nightVictimId: majorityTarget,
          ),
        );
      } else {
        voteUpdates['nightVictimId'] = null;
        voteUpdates['public_state/nightVictimId'] = null;
        state = state.copyWith(
          room: state.room?.copyWith(clearNightVictimId: true),
        );
      }
    }
    await _currentRoomRef!.update(voteUpdates);
  }

  /// Intimidation nocturne de la meute : Faire taire un joueur pour toute la journée du lendemain
  Future<bool> werewolfSilence(String targetPlayerId) async {
    if ((!state.myRole.isEvil && !state.isAdmin) || _currentRoomRef == null) {
      return false;
    }
    final target = state.room?.players[targetPlayerId];
    if (target == null || !target.isAlive || DeathRegistryService.instance.isDead(targetPlayerId)) {
      return false;
    }
    // Interdiction de cibler la proie déjà dévorée de la nuit (inutile de bâillonner un mort)
    final rawVictimId = state.room?.nightVictimId ?? _tallyWerewolfVotes();
    final victim = rawVictimId != null ? state.room?.players[rawVictimId] : null;
    final currentVictimId = (victim != null && victim.isAlive && !DeathRegistryService.instance.isDead(victim.id)) ? rawVictimId : null;
    if (currentVictimId == targetPlayerId) {
      return false;
    }

    // Enregistrement confidentiel du sortilège de silence (divulgué publiquement à l'Aube)
    if (state.room != null) {
      final inMemoryState = GameState(
        currentTurn: state.room!.round,
        currentPhase: state.room!.phase,
        players: state.room!.players,
        nightPrimaryVictimId: currentVictimId,
        expandedRolesState: state.room!.expandedRolesState,
      );
      RoleHandlersRegistry.dispatchAction(
        inMemoryState,
        role: GameRole.blackWolf,
        actorId: state.effectiveUserId,
        payload: {'targetId': targetPlayerId},
      );
    }

    await _syncState({
      'blackWolfTargetId': targetPlayerId,
    });
    if (state.room != null) {
      final updatedRoom = state.room!.copyWith(blackWolfTargetId: targetPlayerId);
      state = state.copyWith(room: updatedRoom);
      _checkEarlyResolutionQuorum(updatedRoom);
    }
    return true;
  }

  Future<void> witchSaveVictim([String? fallbackTargetId]) async {
    if ((state.myRole != GameRole.witch &&
            state.currentPlayer?.roleInitial != GameRole.witch &&
            !state.isAdmin) ||
        _currentRoomRef == null ||
        state.room == null) {
      return;
    }
    final wolfVictimId = state.room!.nightVictimId ?? _tallyWerewolfVotes() ?? fallbackTargetId;
    if (wolfVictimId == null) {
      return; // Aucune cible des loups à sauver
    }
    if (state.room!.witchHealed) {
      return; // Déjà sauvé cette nuit
    }

    final witchPlayer = state.room!.playerList.cast<PlayerModel?>().firstWhere(
      (p) => p != null && (p.role == GameRole.witch || p.roleInitial == GameRole.witch),
      orElse: () => state.currentPlayer,
    );
    final witchId = (state.myRole == GameRole.witch ||
            state.currentPlayer?.roleInitial == GameRole.witch)
        ? state.effectiveUserId
        : (witchPlayer?.id ?? state.effectiveUserId);
    // ═══════════════════════════════════════════════════════════════
    // RÈGLE CANONIQUE : Stock de potions de vie scalant max(1, N÷10).
    // Initialisé dans startGame(). potionsVie est la source de vérité.
    // ═══════════════════════════════════════════════════════════════
    final curVie = witchPlayer?.potionsVie ?? 0;
    if (curVie <= 0 && !state.isAdmin) {
      return; // Plus de potion de vie
    }

    final newVie = max(0, curVie - 1);
    final curMort = witchPlayer?.potionsMort ?? 0;
    final isDechue = newVie == 0 && curMort == 0;

    if (state.room != null) {
      final inMemoryState = GameState(
        currentTurn: state.room!.round,
        currentPhase: state.room!.phase,
        players: state.room!.players,
        nightPrimaryVictimId: wolfVictimId,
        expandedRolesState: state.room!.expandedRolesState,
      );
      RoleHandlersRegistry.dispatchAction(
        inMemoryState,
        role: GameRole.witch,
        actorId: witchId,
        payload: {'save': true},
      );
    }

    await _syncState({
      'witchHealed': true,
      'nightVictimId': wolfVictimId,
      'players/$witchId/hasUsedHealPotion': newVie == 0,
      'players/$witchId/potionsVie': newVie,
      if (isDechue) 'players/$witchId/role': GameRole.simpleVillager.name,
      'logs': [
        ...?state.room?.logs,
        '✨ Une fiole de guérison a sauvé la victime ($newVie potion(s) de vie restante(s)).',
        if (isDechue)
          '🥀 La Sorcière a épuisé toutes ses potions et devient Simple Villageoise !',
      ],
    });

    // Auto-advance UNIQUEMENT si aucune autre action n'est possible cette nuit
    // (ex: si le poison a déjà été utilisé cette nuit, ou si la Sorcière n'a plus de potion de mort, ou si elle est déchue)
    final alreadyPoisoned = state.room?.witchPoisonVictimId != null;
    final canPoison = curMort > 0 && !alreadyPoisoned;
    if (isDechue || !canPoison) {
      await processNightTransitions();
    }
  }

  Future<void> witchPoison(String targetId) async {
    if ((state.myRole != GameRole.witch &&
            state.currentPlayer?.roleInitial != GameRole.witch &&
            !state.isAdmin) ||
        _currentRoomRef == null ||
        state.room == null) {
      return;
    }
    if (targetId.isEmpty) return;
    final target = state.room!.players[targetId];
    if (target == null || !target.isAlive) {
      return; // Cible invalide ou déjà morte
    }
    if (state.room!.witchPoisonVictimId != null) {
      return; // Déjà empoisonné cette nuit
    }

    final witchPlayer = state.room!.playerList.cast<PlayerModel?>().firstWhere(
      (p) => p != null && (p.role == GameRole.witch || p.roleInitial == GameRole.witch),
      orElse: () => state.currentPlayer,
    );
    final witchId = (state.myRole == GameRole.witch ||
            state.currentPlayer?.roleInitial == GameRole.witch)
        ? state.effectiveUserId
        : (witchPlayer?.id ?? state.effectiveUserId);

    // ═══════════════════════════════════════════════════════════════
    // RÈGLE CANONIQUE : Stock de potions de mort scalant max(1, N÷10).
    // potionsMort est la source de vérité, initialisé dans startGame().
    // ═══════════════════════════════════════════════════════════════
    final curMort = witchPlayer?.potionsMort ?? 0;
    if (curMort <= 0 && !state.isAdmin) {
      return; // Plus de potion de mort
    }

    final newMort = max(0, curMort - 1);
    final curVie = witchPlayer?.potionsVie ?? 0;
    final isDechue = newMort == 0 && curVie == 0;

    if (state.room != null) {
      final inMemoryState = GameState(
        currentTurn: state.room!.round,
        currentPhase: state.room!.phase,
        players: state.room!.players,
        expandedRolesState: state.room!.expandedRolesState,
      );
      RoleHandlersRegistry.dispatchAction(
        inMemoryState,
        role: GameRole.witch,
        actorId: witchId,
        payload: {'poisonTargetId': targetId},
      );
    }

    // La potion de mort marque la cible pour la résolution du matin sans altérer son statut durant la nuit
    await _syncState({
      'witchPoisonVictimId': targetId,
      'players/$witchId/hasUsedPoisonPotion': newMort == 0,
      'players/$witchId/potionsMort': newMort,
      if (isDechue) 'players/$witchId/role': GameRole.simpleVillager.name,
      'logs': [
        ...?state.room?.logs,
        '🧪 Un breuvage mortel a été déposé pour ${target.name} ($newMort potion(s) de mort restante(s)).',
        if (isDechue)
          '🥀 La Sorcière a épuisé toutes ses potions et devient Simple Villageoise !',
      ],
    });

    // Auto-advance UNIQUEMENT si aucune autre action n'est possible cette nuit
    // (ex: si guérison déjà faite, ou plus de potion de vie, ou pas de victime des loups, ou déchue)
    final alreadyHealed = state.room?.witchHealed == true;
    final wolfVictimId = state.room?.nightVictimId ?? _tallyWerewolfVotes();
    final canHeal = curVie > 0 && !alreadyHealed && wolfVictimId != null;
    if (isDechue || !canHeal) {
      await processNightTransitions();
    }
  }

  Future<void> confirmWitchTurn() async {
    if (state.room == null) return;
    try {
      await processNightTransitions();
    } catch (e, stack) {
      debugPrint('[confirmWitchTurn Exception] $e\n$stack');
    }
  }

  Future<void> witchPass() async {
    if (state.room != null) {
      final inMemoryState = GameState(
        currentTurn: state.room!.round,
        currentPhase: state.room!.phase,
        players: state.room!.players,
        expandedRolesState: state.room!.expandedRolesState,
      );
      RoleHandlersRegistry.dispatchAction(
        inMemoryState,
        role: GameRole.witch,
        actorId: state.effectiveUserId,
        payload: {'skip': true},
      );
    }
    await confirmWitchTurn();
  }

  Future<void> hunterShoot(String targetId) async {
    if (_currentRoomRef == null || state.room == null) return;
    final room = state.room!;
    final hunterId = state.effectiveUserId;
    if (room.pendingHunterId != hunterId && room.pendingHunterId != state.currentUserId && !state.isAdmin) return;

    final victim = room.players[targetId];
    if (victim == null || !victim.isAlive) return;

    final inMemoryState = GameState(
      currentTurn: room.round,
      currentPhase: room.phase,
      players: room.players,
      pendingExecutedPlayerId: hunterId,
      expandedRolesState: room.expandedRolesState,
    );
    RoleHandlersRegistry.dispatchAction(
      inMemoryState,
      role: GameRole.hunter,
      actorId: hunterId,
      payload: {'targetId': targetId},
    );

    GameRole victimRealRole = victim.role;
    try {
      final sSnap = await _database
          .ref('rooms/${room.roomCode}/secret_roles/$targetId/roleId')
          .get();
      if (sSnap.exists && sSnap.value != null) {
        victimRealRole = GameRole.fromId(sSnap.value.toString());
      }
    } catch (_) {}

    final updates = <String, dynamic>{
      'players/$targetId/isAlive': false,
      'cemetery/$targetId': true,
      'players/$targetId/role': victimRealRole.id,
      'pendingHunterId': null,
    };
    DeathRegistryService.instance.markDead(targetId);
    final logs = List<String>.from(room.logs);
    logs.add(
      '💥 Le Chasseur a abattu ${victim.name} (${victimRealRole.displayNameFr}) dans son dernier râle !',
    );

    final hunterDeathEntry = {
      'action': 'FLIP_CARTE_MORT',
      'joueurId': targetId,
      'nom': victim.name,
      'role': victimRealRole.name,
      'camp': victimRealRole.isEvil ? 'LOUPS' : 'VILLAGE',
      'cause': 'CHASSEUR',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    updates['lastDeathFlip'] = hunterDeathEntry;
    final List<Map<String, dynamic>> hunterQueue = [hunterDeathEntry];

    final deadPartnerId = handleLoverDeath(targetId, room.players, logs);
    if (deadPartnerId != null) {
      updates['players/$deadPartnerId/isAlive'] = false;
      updates['cemetery/$deadPartnerId'] = true;
      DeathRegistryService.instance.markDead(deadPartnerId);
      final deadPartner = room.players[deadPartnerId];
      if (deadPartner != null) {
        GameRole partnerRole = deadPartner.role;
        try {
          final pSnap = await _database
              .ref('rooms/${room.roomCode}/secret_roles/$deadPartnerId/roleId')
              .get();
          if (pSnap.exists && pSnap.value != null) {
            partnerRole = GameRole.fromId(pSnap.value.toString());
          }
        } catch (_) {}
        updates['players/$deadPartnerId/role'] = partnerRole.id;
        hunterQueue.add({
          'action': 'FLIP_CARTE_MORT',
          'joueurId': deadPartnerId,
          'nom': deadPartner.name,
          'role': partnerRole.name,
          'camp': partnerRole.isEvil ? 'LOUPS' : 'VILLAGE',
          'cause': 'AMOUREUX',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      }
    }
    updates['deathAnnouncementQueue'] = hunterQueue;

    final realRoles = await _resolveRealRoles(room);

    final simulated = room.copyWith(
      players: room.players.map(
        (k, v) => MapEntry(
          k,
          (k == targetId || (deadPartnerId != null && k == deadPartnerId))
              ? v.copyWith(isAlive: false)
              : v,
        ),
      ),
    );
    final isGameOver = await evaluateVictoryConditions(
      room: simulated,
      updates: updates,
      logs: logs,
      realRoles: realRoles,
    );
    if (isGameOver) {
      return;
    }
    if (room.pendingCaptainId != null) {
      updates['phase'] = GamePhase.captainSuccession.name;
    } else if (room.morningVictims.isNotEmpty) {
      updates['phase'] = GamePhase.morningAnnouncement.name;
      updates['timerSeconds'] = 20;
    } else {
      _finishDayCycle(room, updates, logs);
    }

    updates['logs'] = logs;
    await _syncState(updates);
  }

  /// Alias officiel conforme à la spécification du Testament du Capitaine
  Future<void> designateCaptainSuccessor(String successorId) =>
      captainPassBadge(successorId);

  Future<void> captainPassBadge(String successorId) async {
    if (_currentRoomRef == null || state.room == null) return;
    final room = state.room!;
    if (room.pendingCaptainId != state.currentUserId &&
        room.captainId != state.currentUserId &&
        room.expandedRolesState.mayorPlayerId != state.currentUserId &&
        !state.isAdmin) {
      return;
    }

    final successor = room.players[successorId];
    if (successor == null || !successor.isAlive) return;

    final updates = <String, dynamic>{
      'captainId': successorId,
      'players/$successorId/isCaptain': true,
      'pendingCaptainId': null,
      'expandedRolesState': room.expandedRolesState.copyWith(
        mayorPlayerId: successorId,
        isMayorSuccessionPending: false,
      ).toMap(),
    };
    // Retirer explicitement l'écharpe et le titre du maire défunt
    if (room.captainId != null && room.captainId != successorId) {
      updates['players/${room.captainId}/isCaptain'] = false;
    }
    if (room.pendingCaptainId != null &&
        room.pendingCaptainId != successorId) {
      updates['players/${room.pendingCaptainId}/isCaptain'] = false;
    }

    // Confirmation explicite et inviolable de l'état de mort pour tous les défunts
    for (final pid in DeathRegistryService.instance.deadPlayerIds) {
      updates['players/$pid/isAlive'] = false;
      updates['cemetery/$pid'] = true;
    }
    for (final p in room.playerList) {
      if (!p.isAlive) {
        DeathRegistryService.instance.markDead(p.id);
        updates['players/${p.id}/isAlive'] = false;
        updates['cemetery/${p.id}'] = true;
      }
    }

    final logs = List<String>.from(room.logs);
    logs.add(
      '🎖️ Le défunt Maire transmet son écharpe à ${successor.name}, nouveau chef du village !',
    );

    final realRoles = await _resolveRealRoles(room);
    final isGameOver = await evaluateVictoryConditions(
      room: room,
      updates: updates,
      logs: logs,
      realRoles: realRoles,
    );
    if (isGameOver) {
      return;
    }

    if (room.morningVictims.isNotEmpty) {
      updates['phase'] = GamePhase.morningAnnouncement.name;
      updates['timerSeconds'] = 20;
    } else {
      _finishDayCycle(room, updates, logs);
    }
    updates['logs'] = logs;
    await _syncState(updates);
  }

  /// Résolution automatique de fin de temps pour le Chasseur (abandon automatique)
  Future<void> autoResolveHunterTimeout() async {
    if (_currentRoomRef == null || state.room == null) return;
    final room = state.room!;
    if (room.phase != GamePhase.hunterDeathChoice) return;

    final updates = <String, dynamic>{
      'pendingHunterId': null,
    };
    final logs = List<String>.from(room.logs);
    logs.add(
      '⏳ Le Chasseur n\'a pas tiré à temps dans son dernier souffle. Son tir est perdu !',
    );

    final realRoles = await _resolveRealRoles(room);
    final isGameOver = await evaluateVictoryConditions(
      room: room,
      updates: updates,
      logs: logs,
      realRoles: realRoles,
    );
    if (isGameOver) {
      return;
    }

    if (room.pendingCaptainId != null) {
      updates['phase'] = GamePhase.mayorSuccession.name;
      updates['timerSeconds'] = 15;
      logs.add('🎖️ Le Maire a péri ! Il dispose de 15s pour désigner son successeur.');
    } else if (room.morningVictims.isNotEmpty) {
      updates['phase'] = GamePhase.morningAnnouncement.name;
      updates['timerSeconds'] = 20;
    } else {
      _finishDayCycle(room, updates, logs);
    }

    updates['logs'] = logs;
    await _syncState(updates);
  }

  /// Résolution automatique de fin de temps pour le Capitaine / Maire (désignation par défaut)
  Future<void> autoResolveCaptainTimeout() async {
    if (_currentRoomRef == null || state.room == null) return;
    final room = state.room!;
    if (room.phase != GamePhase.captainSuccession && room.phase != GamePhase.mayorSuccession) return;

    final updates = <String, dynamic>{
      'pendingCaptainId': null,
    };
    final logs = List<String>.from(room.logs);

    final living = room.alivePlayers.toList();
    if (living.isNotEmpty) {
      final successorId = _phaseCoordinator.mayorCoordinator.autoPassOnTimeout(
        players: room.players,
        deceasedMayorId: room.pendingCaptainId ?? room.captainId ?? '',
      );
      final successor = room.players[successorId] ?? living.first;
      updates['captainId'] = successor.id;
      updates['players/${successor.id}/isCaptain'] = true;
      updates['expandedRolesState'] = room.expandedRolesState.copyWith(
        mayorPlayerId: successor.id,
        isMayorSuccessionPending: false,
      ).toMap();
      if (room.captainId != null && room.captainId != successor.id) {
        updates['players/${room.captainId}/isCaptain'] = false;
      }
      if (room.pendingCaptainId != null &&
          room.pendingCaptainId != successor.id) {
        updates['players/${room.pendingCaptainId}/isCaptain'] = false;
      }
      logs.add(
        '⏳ Faute de choix du défunt Maire, l\'écharpe est transmise d\'office à ${successor.name} !',
      );
    } else {
      logs.add(
        '⏳ Le Maire n\'a pas désigné de successeur et aucun survivant ne peut reprendre l\'écharpe.',
      );
    }

    // Confirmation explicite et inviolable de l'état de mort pour tous les défunts
    for (final pid in DeathRegistryService.instance.deadPlayerIds) {
      updates['players/$pid/isAlive'] = false;
      updates['cemetery/$pid'] = true;
    }
    for (final p in room.playerList) {
      if (!p.isAlive) {
        DeathRegistryService.instance.markDead(p.id);
        updates['players/${p.id}/isAlive'] = false;
        updates['cemetery/${p.id}'] = true;
      }
    }

    final realRoles = await _resolveRealRoles(room);
    final isGameOver = await evaluateVictoryConditions(
      room: room,
      updates: updates,
      logs: logs,
      realRoles: realRoles,
    );
    if (isGameOver) {
      return;
    }

    if (room.morningVictims.isNotEmpty) {
      updates['phase'] = GamePhase.morningAnnouncement.name;
      updates['timerSeconds'] = 20;
    } else {
      _finishDayCycle(room, updates, logs);
    }

    updates['logs'] = logs;
    await _syncState(updates);
  }

  Future<void> concludeMayorElection() => concludeCaptainElection();

  Future<void> concludeCaptainElection() async {
    if (!state.isHost || state.room == null) return;
    final room = state.room!;

    // ── LECTURE AUTORITAIRE DIRECTE DES VOTES D'ÉLECTION SUR FIREBASE ──
    final liveElectionVotes = <String, String>{};
    try {
      final snap = await _currentRoomRef?.child('votes').get();
      if (snap != null && snap.exists && snap.value is Map) {
        (snap.value as Map).forEach((k, v) {
          if (v != null) liveElectionVotes[k.toString()] = v.toString();
        });
      }
    } catch (_) {}

    final electionVotes = <String, String>{};
    for (final p in room.alivePlayers) {
      final target = liveElectionVotes[p.id] ?? p.targetVoteId;
      if (target != null) {
        electionVotes[p.id] = target;
      }
    }

    final MayorElectionResult electionResult = _phaseCoordinator.mayorCoordinator.electMayor(
      players: room.players,
      electionVotes: electionVotes,
      fallbackId: room.alivePlayers.isNotEmpty ? room.alivePlayers.first.id : null,
    );

    final winnerId = electionResult.mayorId;
    final winnerName = electionResult.mayorName;

    final updates = <String, dynamic>{
      'captainId': winnerId,
      'players/$winnerId/isCaptain': true,
      'expandedRolesState': room.expandedRolesState.copyWith(
        mayorPlayerId: winnerId,
        isMayorElected: true,
      ).toMap(),
    };
    // Confirmation explicite et inviolable de l'état de mort pour tous les défunts
    for (final pid in DeathRegistryService.instance.deadPlayerIds) {
      updates['players/$pid/isAlive'] = false;
      updates['cemetery/$pid'] = true;
    }
    for (final p in room.playerList) {
      if (!p.isAlive) {
        DeathRegistryService.instance.markDead(p.id);
        updates['players/${p.id}/isAlive'] = false;
        updates['cemetery/${p.id}'] = true;
      }
    }

    final logs = List<String>.from(room.logs);
    logs.add(electionResult.logMessage);

    _resetAllVotes(updates);

    // Après l'élection : Prise de parole solennelle d'ouverture du Maire (15s)
    updates['phase'] = GamePhase.mayorSpeechOpening.name;
    updates['currentSpeakerId'] = winnerId;
    updates['timerSeconds'] = 15;
    logs.add('🎖️ $winnerName prend la parole pour son discours d\'ouverture (15s) !');

    updates['logs'] = logs;
    await _syncState(updates);
  }

  Future<void> nextPhase() async {
    if (state.room == null) return;
    if (_isTransitioningPhase) {
      debugPrint('[nextPhase] Transition déjà en cours, appel ignoré.');
      return;
    }
    _cancelPhaseTimer();
    final phase = state.room!.phase;

    final canAdvanceNight = phase.isNight &&
        (state.isHost ||
            state.isAdmin ||
            state.isDevMode ||
            (phase == GamePhase.nightWerewolves &&
                (state.myRole.isEvil || state.isAdmin || state.isDevMode)) ||
            (phase == GamePhase.nightSeer &&
                (state.myRole == GameRole.seer || state.isAdmin || state.isDevMode)) ||
            (phase == GamePhase.nightWitch &&
                (state.myRole == GameRole.witch || state.isAdmin || state.isDevMode)) ||
            (phase == GamePhase.nightDefender &&
                (state.myRole == GameRole.defender || state.isAdmin || state.isDevMode)) ||
            (phase == GamePhase.nightCupid &&
                (state.myRole == GameRole.cupid || state.isAdmin || state.isDevMode)) ||
            (phase == GamePhase.nightThief &&
                (state.myRole == GameRole.thief || state.myRole == GameRole.thiefOfHearts || state.isAdmin || state.isDevMode)) ||
            (phase == GamePhase.nightPyromaniac &&
                (state.myRole == GameRole.pyromaniac || state.isAdmin || state.isDevMode)) ||
            (phase == GamePhase.nightPiper &&
                (state.myRole == GameRole.piedPiper || state.isAdmin || state.isDevMode)) ||
            (phase == GamePhase.nightFox &&
                (state.myRole == GameRole.fox || state.isAdmin || state.isDevMode)) ||
            (phase == GamePhase.nightWhiteWerewolf &&
                (state.myRole == GameRole.whiteWerewolf || state.isAdmin || state.isDevMode)) ||
            (phase == GamePhase.nightBlackWolf &&
                (state.myRole == GameRole.blackWolf || state.isAdmin || state.isDevMode)));

    if (!state.isHost && !state.isAdmin && !state.isDevMode && !canAdvanceNight) return;

    if (phase == GamePhase.nightWerewolves && !state.isAdmin && !state.isHost) {
      final victimId = _tallyWerewolfVotes() ?? state.room!.nightVictimId;
      final silenceId = state.room!.blackWolfTargetId;
      final livingCount = state.room!.alivePlayers.length;
      if (victimId == null || (livingCount >= 2 && (silenceId == null || victimId == silenceId))) {
        state = state.copyWith(
          errorMessage:
              'La meute doit obligatoirement désigner une proie ET un joueur distinct à réduire au silence.',
        );
        return;
      }
    }

    if (phase.isNight) {
      await processNightTransitions();
      return;
    }

    _isTransitioningPhase = true;
    try {
      if (phase == GamePhase.morningAnnouncement) {
        final room = state.room!;
        final realRoles = await _resolveRealRoles(room);
        final updates = <String, dynamic>{};
        final logs = List<String>.from(room.logs);

        final isGameOver = await evaluateVictoryConditions(
          room: room,
          updates: updates,
          logs: logs,
          realRoles: realRoles,
        );

        if (isGameOver) {
          return;
        }

        _routeToDayPhase(room, updates, logs);
        updates['logs'] = logs;
        await _syncState(updates);
      } else if (phase == GamePhase.captainElection || phase == GamePhase.mayorElection) {
        await concludeCaptainElection();
      } else if (phase == GamePhase.hunterDeathChoice) {
        await autoResolveHunterTimeout();
      } else if (phase == GamePhase.captainSuccession || phase == GamePhase.mayorSuccession) {
        await autoResolveCaptainTimeout();
      } else if (phase == GamePhase.mayorSpeechOpening) {
        await concludeMayorSpeechOpening();
      } else if (phase == GamePhase.mayorSpeechClosing) {
        await concludeMayorSpeechClosing();
      } else if (phase == GamePhase.dayDebate) {
        // Expiration du temps de parole de l'orateur en cours (bot ou humain) : avancement au prochain tour ou clôture vers le vote
        await passTurnDebate();
      } else if (phase == GamePhase.dayVoting ||
          phase == GamePhase.dayTieBreakVote) {
        await _processDayVoteResolutionInternal();
      } else if (phase == GamePhase.dayDefense) {
        final updates = <String, dynamic>{
          'phase': GamePhase.dayTieBreakVote.name,
          'timerSeconds': 45,
          'logs': [
            ...?state.room?.logs,
            '⚖️ Second scrutin décisif : votez uniquement pour les accusés ex æquo !',
          ],
        };
        await _syncState(updates);
      } else if (phase == GamePhase.dayResolution) {
        final nextRound = state.room!.round + 1;
        final realRoles = await _resolveRealRoles(state.room!);
        final firstNight = _getNextNightPhase(
          current: GamePhase.dayResolution,
          round: nextRound,
          players: state.room!.players,
          realRoles: realRoles,
        );

        final updates = <String, dynamic>{
          'phase': firstNight.name,
          'round': nextRound,
          'nightVictimId': null,
          'blackWolfTargetId': null,
          'public_state/nightVictimId': null,
          'public_state/blackWolfTargetId': null,
          'witchHealed': false,
          'witchPoisonVictimId': null,
          'seerInspectedTargetId': null,
          'seerInspectedRole': null,
          'timerSeconds': 45,
          'expandedRolesState': state.room!.expandedRolesState.copyWith(
            mayorSpeechOpeningDone: false,
            mayorSpeechClosingDone: false,
            whiteWolfTargetId: '',
          ).toMap(),
          'logs': [
            ...?state.room?.logs,
            '🌑 La nuit $nextRound recouvre le village. Les habitants s\'endorment.',
          ],
        };
        // Rétablir la parole pour les joueurs réduits au silence par le Loup Noir
        // et réinitialiser les marqueurs éphémères de flairage du Renard du cycle précédent
        for (final p in state.room!.players.values) {
          if (p.isMuted) {
            updates['players/${p.id}/isMuted'] = false;
          }
          if (p.isSniffed || p.hasWolfSmell) {
            updates['players/${p.id}/isSniffed'] = false;
            updates['players/${p.id}/hasWolfSmell'] = false;
          }
        }
        state = state.copyWith(clearFoxSniff: true);
        _resetAllVotes(updates);
        await _syncState(updates);
      }
    } finally {
      _isTransitioningPhase = false;
    }
  }

  // ===========================================================================
  // UTILITAIRES ET INTÉGRATION VOCALE AGORA
  // ===========================================================================

  String? _tallyWerewolfVotes([Map<String, GameRole>? realRoles]) {
    if (state.room == null) return null;
    final votes = <String, int>{};
    for (final p in state.room!.alivePlayers) {
      final role = realRoles?[p.id] ?? p.role;
      if ((role.isEvil || role == GameRole.whiteWerewolf || (p.id == state.currentUserId && state.isAdmin)) &&
          p.targetVoteId != null) {
        final target = state.room!.players[p.targetVoteId!];
        if (target != null && target.isAlive && !DeathRegistryService.instance.isDead(target.id)) {
          votes[p.targetVoteId!] = (votes[p.targetVoteId!] ?? 0) + 1;
        }
      }
    }
    if (votes.isEmpty) return null;
    return votes.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  void _resetAllVotes(Map<String, dynamic> updates) {
    if (state.room == null) return;
    for (final p in state.room!.playerList) {
      updates['players/${p.id}/targetVoteId'] = null;
      updates['votes/${p.id}'] = null;
    }
    updates['votes'] = null;
    // Réinitialisation des sélections et cibles stratégiques éphémères
    updates['seerInspectedTargetId'] = null;
    updates['seerInspectedRole'] = null;
    updates['public_state/seerInspectedTargetId'] = null;
    updates['public_state/seerInspectedRole'] = null;
  }

  /// Met à jour la présence et le statut audio sans impacter l'état global du jeu
  Future<void> updatePresence({
    bool? isOnline,
    bool? isMuted,
    int? micVolume,
    bool? isSpeaking,
  }) async {
    if (_currentRoomRef == null || state.currentUserId.isEmpty) return;
    final presenceUpdates = <String, dynamic>{
      'lastSeen': ServerValue.timestamp,
    };
    if (isOnline != null) presenceUpdates['isOnline'] = isOnline;
    if (isMuted != null) presenceUpdates['isMuted'] = isMuted;
    if (micVolume != null) presenceUpdates['micVolume'] = micVolume;
    if (isSpeaking != null) presenceUpdates['isSpeaking'] = isSpeaking;
    try {
      await _currentRoomRef!
          .child('presence/${state.currentUserId}')
          .update(presenceUpdates);
    } catch (_) {}
  }

  /// Vérifie et déclenche l'anticipation instantanée (Fast-Track Quorum)
  /// Dès que tous les acteurs requis ont validé leur décision / vote,
  /// court-circuite immédiatement le timer restant sans aucune attente inutile.
  void _checkEarlyResolutionQuorum(GameRoom updatedRoom) {
    if (!state.isHost && !state.isAdmin) return;
    if (_isTransitioningPhase) return;
    final aliveCount = updatedRoom.alivePlayers.length;
    if (aliveCount <= 0) return;

    final votedCount =
        updatedRoom.alivePlayers.where((p) => p.targetVoteId != null).length;

    // 1. Scrutin diurne (Vote ordinaire du village ou Scrutin de ballottage)
    if ((updatedRoom.phase == GamePhase.dayVoting ||
            updatedRoom.phase == GamePhase.dayTieBreakVote) &&
        votedCount >= aliveCount) {
      debugPrint('[Quorum Fast-Track] Tous les vivants ont voté ($votedCount/$aliveCount). Résolution immédiate du scrutin.');
      processDayVoteResolution();
      return;
    }

    // 2. Élection solennelle du Capitaine / Maire (Matin Jour 1)
    if ((updatedRoom.phase == GamePhase.captainElection ||
            updatedRoom.phase == GamePhase.mayorElection) &&
        votedCount >= aliveCount) {
      debugPrint('[Quorum Fast-Track] Tous les vivants ont voté pour le Maire ($votedCount/$aliveCount). Élection immédiate.');
      concludeCaptainElection();
      return;
    }

    // 3. Nuit des Loups-Garous : tous les loups ont voté + cible de silence prête si loup noir présent
    if (updatedRoom.phase == GamePhase.nightWerewolves) {
      final aliveWolves = updatedRoom.alivePlayers
          .where((p) => p.role.isEvil || p.role == GameRole.whiteWerewolf)
          .toList();
      final wolvesVoted =
          aliveWolves.where((p) => p.targetVoteId != null).length;
      if (aliveWolves.isNotEmpty && wolvesVoted >= aliveWolves.length) {
        final hasBlackWolf =
            aliveWolves.any((p) => p.role == GameRole.blackWolf);
        if (!hasBlackWolf ||
            updatedRoom.blackWolfTargetId != null ||
            aliveCount < 2) {
          debugPrint('[Quorum Fast-Track] Tous les loups ont voté ($wolvesVoted/${aliveWolves.length}). Transition nocturne immédiate.');
          processNightTransitions();
          return;
        }
      }
    }
  }

  /// Synchronise l'ordonnancement automatique d'expiration de phase pour l'Hôte
  /// Fonction pure du temps serveur : si le temps restant est nul ou négatif,
  /// la phase progresse immédiatement sans dépendre de timers UI locaux.
  void _syncPhaseExpirationSchedule(GameRoom room) {
    _phaseExpirationTimer?.cancel();
    _phaseExpirationTimer = null;

    if (!state.isHost && !state.isAdmin) return;
    if (room.phase == GamePhase.lobby || room.phase == GamePhase.gameOver) return;

    final currentServerTime = ServerTimeService().currentServerEstimatedTime;
    final targetEndsAt = room.phaseEndsAt ??
        (currentServerTime +
            (room.timerSeconds > 0 ? room.timerSeconds : 30) * 1000);
    final remainingMs = targetEndsAt - currentServerTime;

    if (remainingMs <= 0) {
      debugPrint(
        '[PhaseExpiration] Phase ${room.phase.name} déjà expirée (${remainingMs}ms). Avancement immédiat vers la phase suivante.',
      );
      if (!_isTransitioningPhase) {
        nextPhase();
      }
    } else {
      _phaseExpirationTimer = Timer(Duration(milliseconds: remainingMs), () {
        if ((state.isHost || state.isAdmin) &&
            state.room?.phase == room.phase &&
            state.room?.round == room.round) {
          debugPrint(
            '[PhaseExpirationTimer] Expiration du temps serveur pour ${room.phase.name}. Déclenchement automatique nextPhase().',
          );
          nextPhase();
        }
      });
    }
  }

  /// Fermeture et nettoyage propre de tous les abonnements partitionnés
  void _cancelAllRoomSubscriptions() {
    _cancelPhaseTimer();
    _resolvedDayVoteRounds.clear();
    _lastProcessedPhaseStartedAt = 0;
    _publicStateSubscription?.cancel();
    _publicStateSubscription = null;
    _playersSubscription?.cancel();
    _playersSubscription = null;
    _votesSubscription?.cancel();
    _votesSubscription = null;
    _presenceSubscription?.cancel();
    _presenceSubscription = null;
    _logsSubscription?.cancel();
    _logsSubscription = null;
    _currentPhaseSubscription?.cancel();
    _currentPhaseSubscription = null;
    _secretRoleSubscription?.cancel();
    _secretRoleSubscription = null;
    _wolfPackSubscription?.cancel();
    _wolfPackSubscription = null;
    _replayStatusSubscription?.cancel();
    _replayStatusSubscription = null;
    _gameResetSubscription?.cancel();
    _gameResetSubscription = null;
    _cemeterySubscription?.cancel();
    _cemeterySubscription = null;
    _hostPresenceSubscription?.cancel();
    _hostPresenceSubscription = null;
    _hostIdSubscription?.cancel();
    _hostIdSubscription = null;
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// ABONNEMENT PARTITIONNÉ (SHARDING D'ÉCOUTE)
  /// Remplace l'écoute monolithique de la racine par des souscriptions ciblées :
  /// 1. public_state : phase, timer/endsAt, round, arbitrage
  /// 2. players : rôles publics, vie, sièges
  /// 3. votes : table dynamique des votes
  /// 4. presence : statut vocal, volume micro, connectivité
  /// 5. logs : historique textuel
  /// ═══════════════════════════════════════════════════════════════════════════
  void _subscribeToRoom(String roomCode) {
    _cancelAllRoomSubscriptions();

    // 1. Chargement initial complet de la salle
    _currentRoomRef?.get().then((snap) {
      if (snap.exists && snap.value != null) {
        final data = snap.value as Map<dynamic, dynamic>;
        final initialRoom =
            GameRoom.fromMap(data, roomCode, state.currentUserId);
        state = state.copyWith(room: initialRoom);
        _applyVoiceRulesForPhase(initialRoom);
        _syncPhaseExpirationSchedule(initialRoom);
      }
    }).catchError((e) {
      debugPrint('[Initial Room Fetch Error] $e');
    });

    // 2. ── SOUSCRIPTION GRANULAIRE : public_state ──
    _publicStateSubscription = _currentRoomRef
        ?.child('public_state')
        .onValue
        .listen((event) {
      if (event.snapshot.value == null || state.room == null) return;
      final data = event.snapshot.value as Map<dynamic, dynamic>;

      final rawPhase = data['phase']?.toString() ?? data['currentPhase']?.toString();
      final parsedPhase = rawPhase != null
          ? GamePhase.fromString(rawPhase)
          : state.room!.phase;

      final currentRound = state.room!.round;
      final currentPhase = state.room!.phase;
      final incomingRound = data['round'] is int ? data['round'] as int : currentRound;

      // GARDE MONOTONE STRICT 1 : Rejet systématique des tours antérieurs
      if (incomingRound < currentRound) {
        debugPrint(
          '⛔ [Anti-Rollback public_state] Tour antérieur ignoré : $incomingRound < $currentRound',
        );
        return;
      }

      // GARDE MONOTONE STRICT 2 : Rejet de timestamp antérieur au sein du même tour
      if (data['phaseStartedAt'] is num) {
        final incomingStartedAt = (data['phaseStartedAt'] as num).toInt();
        if (incomingRound == currentRound &&
            incomingStartedAt < _lastProcessedPhaseStartedAt) {
          debugPrint(
            '⛔ [Anti-Rollback public_state] Timestamp antérieur ignoré : $incomingStartedAt < $_lastProcessedPhaseStartedAt',
          );
          return;
        }
        if (incomingStartedAt > _lastProcessedPhaseStartedAt) {
          _lastProcessedPhaseStartedAt = incomingStartedAt;
        }
      }

      // GARDE MONOTONE STRICT 3 : Empêcher toute régression Nuit -> Jour ou régression de l'ordre nocturne au même tour
      if (incomingRound == currentRound) {
        if (currentPhase.isNight && parsedPhase.isDay) {
          debugPrint(
            '⛔ [Anti-Rollback public_state] Régression Nuit -> Jour bloquée : ${currentPhase.name} -> ${parsedPhase.name}',
          );
          return;
        }
        if (currentPhase.isNight &&
            parsedPhase.isNight &&
            parsedPhase.nightOrderIndex < currentPhase.nightOrderIndex) {
          debugPrint(
            '⛔ [Anti-Rollback public_state] Régression nocturne bloquée : ${currentPhase.name} -> ${parsedPhase.name}',
          );
          return;
        }
      }

      final rawMorningVictims = data['morningVictims'];
      final List<String> parsedMorningVictims = [];
      if (rawMorningVictims is List) {
        for (final v in rawMorningVictims) {
          if (v != null) parsedMorningVictims.add(v.toString());
        }
      }

      final rawDeathQueue = data['deathAnnouncementQueue'];
      final List<Map<String, dynamic>> parsedDeathQueue = [];
      if (rawDeathQueue is List) {
        for (final item in rawDeathQueue) {
          if (item is Map) {
            parsedDeathQueue.add(Map<String, dynamic>.from(item));
          }
        }
      }

      final rawLastFlip = data['lastDeathFlip'];
      final Map<String, dynamic>? parsedLastFlip = (rawLastFlip is Map)
          ? Map<String, dynamic>.from(rawLastFlip)
          : null;

      final updatedRoom = state.room!.copyWith(
        phase: parsedPhase,
        round: data['round'] is int ? data['round'] as int : state.room!.round,
        timerSeconds: data['timerSeconds'] is int
            ? data['timerSeconds'] as int
            : state.room!.timerSeconds,
        phaseEndsAt: (data['phaseEndsAt'] is num)
            ? (data['phaseEndsAt'] as num).toInt()
            : state.room!.phaseEndsAt,
        phaseStartedAt: (data['phaseStartedAt'] is num)
            ? (data['phaseStartedAt'] as num).toInt()
            : state.room!.phaseStartedAt,
        phaseDurationMs: (data['phaseDurationMs'] is num)
            ? (data['phaseDurationMs'] as num).toInt()
            : state.room!.phaseDurationMs,
        captainId: data['captainId']?.toString() ?? state.room!.captainId,
        currentSpeakerId:
            data['currentSpeakerId']?.toString() ?? state.room!.currentSpeakerId,
        pendingHunterId:
            data['pendingHunterId']?.toString() ?? state.room!.pendingHunterId,
        pendingCaptainId:
            data['pendingCaptainId']?.toString() ?? state.room!.pendingCaptainId,
        nightVictimId: data['nightVictimId']?.toString(),
        clearNightVictimId: data['nightVictimId'] == null,
        witchHealed: data['witchHealed'] == true,
        witchPoisonVictimId: data['witchPoisonVictimId']?.toString() ??
            state.room!.witchPoisonVictimId,
        pyromaniacIgnited: data['pyromaniacIgnited'] == true,
        blackWolfTargetId: data['blackWolfTargetId']?.toString(),
        clearBlackWolfTargetId: data['blackWolfTargetId'] == null,
        winner: data['winner']?.toString() ?? state.room!.winner,
        isTieBreakActive: data['isTieBreakActive'] == true,
        morningVictims: data.containsKey('morningVictims')
            ? parsedMorningVictims
            : state.room!.morningVictims,
        deathAnnouncementQueue: data.containsKey('deathAnnouncementQueue')
            ? parsedDeathQueue
            : state.room!.deathAnnouncementQueue,
        lastDeathFlip: data.containsKey('lastDeathFlip')
            ? parsedLastFlip
            : state.room!.lastDeathFlip,
      );

      final bool phaseChanged = parsedPhase != state.room!.phase;
      Map<String, PlayerModel> currentPlayers = state.room!.players;
      if (phaseChanged) {
        currentPlayers = currentPlayers.map(
          (k, v) => MapEntry(
            k,
            v.copyWith(clearTargetVote: true, clearTargetVoteId: true),
          ),
        );
      }

      final finalRoom = updatedRoom.copyWith(players: currentPlayers);
      state = state.copyWith(
        clearInspectedRole: phaseChanged,
        room: finalRoom,
      );
      _applyVoiceRulesForPhase(finalRoom);
      _syncPhaseExpirationSchedule(finalRoom);
    });

    // Écoute dédiée sur currentPhase pour compatibilité temps réel immédiate
    _currentPhaseSubscription =
        _currentRoomRef?.child('currentPhase').onValue.listen((event) {
      final rawPhase = event.snapshot.value?.toString();
      if (rawPhase != null && state.room != null) {
        final parsed = GamePhase.fromString(rawPhase);
        if (state.room!.phase != parsed) {
          // GARDE MONOTONE STRICT : Empêcher toute régression Nuit -> Jour ou régression nocturne
          if (state.room!.phase.isNight && parsed.isDay) {
            debugPrint(
              '⛔ [Anti-Rollback currentPhase] Régression Nuit -> Jour ignorée : ${state.room!.phase.name} -> ${parsed.name}',
            );
            return;
          }
          if (state.room!.phase.isNight &&
              parsed.isNight &&
              parsed.nightOrderIndex < state.room!.phase.nightOrderIndex) {
            debugPrint(
              '⛔ [Anti-Rollback currentPhase] Régression nocturne ignorée : ${state.room!.phase.name} -> ${parsed.name}',
            );
            return;
          }
          final clearedPlayers = state.room!.players.map(
            (k, v) => MapEntry(
              k,
              v.copyWith(clearTargetVote: true, clearTargetVoteId: true),
            ),
          );
          final updatedRoom = state.room!.copyWith(
            phase: parsed,
            players: clearedPlayers,
          );
          state = state.copyWith(
            room: updatedRoom,
            clearInspectedRole: true,
          );
          _applyVoiceRulesForPhase(updatedRoom);
        }
      }
    });

    // 3. ── SOUSCRIPTION GRANULAIRE : players (profils, vie, rôles publics, sièges) ──
    _playersSubscription =
        _currentRoomRef?.child('players').onValue.listen((event) {
      if (event.snapshot.value == null || state.room == null) return;
      final rawPlayers = event.snapshot.value;
      final parsedPlayers = <String, PlayerModel>{};

      if (rawPlayers is Map) {
        rawPlayers.forEach((key, val) {
          if (val is Map) {
            final pid = (val['id'] ?? key).toString();
            parsedPlayers[pid] = PlayerModel.fromMap(
              val,
              pid,
              state.currentUserId,
              roomCode,
            );
          }
        });
      } else if (rawPlayers is List) {
        for (int i = 0; i < rawPlayers.length; i++) {
          final val = rawPlayers[i];
          if (val is Map) {
            final pid = (val['id'] ?? '$i').toString();
            parsedPlayers[pid] = PlayerModel.fromMap(
              val,
              pid,
              state.currentUserId,
              roomCode,
            );
          }
        }
      }
      // ── VERROU D'IMMORTALITÉ INVERSE (TOMBSTONE LOCAL & ANTI-RÉSURRECTION) ──
      // Un joueur éliminé (inscrit au DeathRegistryService) ne peut JAMAIS revenir à la vie,
      // sauf si la Sorcière a utilisé sa potion de vie (witchHealed == true) sur la victime de nuit.
      final bool witchHealed = state.room?.witchHealed == true;
      final String? nightVictimId = state.room?.nightVictimId;

      for (final entry in parsedPlayers.entries) {
        final pid = entry.key;
        var player = entry.value;

        // Exception Sorcière : si la Sorcière a soigné la victime de cette nuit
        if (witchHealed && pid == nightVictimId) {
          DeathRegistryService.instance.allowWitchRevive(pid);
        }

        // Si le joueur est déjà marqué comme mort dans notre registre :
        if (DeathRegistryService.instance.isDead(pid) && !state.isAdmin) {
          // FORÇAGE : Il RESTE mort, peu importe ce que prétend le snapshot réseau
          if (player.isAlive) {
            player = player.copyWith(isAlive: false);
            // Corriger Firebase en tâche de fond si le serveur était désynchronisé
            _fixZombieOnDatabase(pid);
          }
        } else if (!player.isAlive) {
          // Dès qu'on apprend qu'il est mort, on l'inscrit définitivement au registre
          DeathRegistryService.instance.markDead(pid);
        }

        parsedPlayers[pid] = player;
      }

      final enforcedPlayers = DeathRegistryService.instance.filterOrEnforce(parsedPlayers);
      final updatedRoom = state.room!.copyWith(players: enforcedPlayers);
      state = state.copyWith(room: updatedRoom);

      _checkEarlyResolutionQuorum(updatedRoom);
    });

    // 4. ── SOUSCRIPTION GRANULAIRE : votes (table dynamique des votes du tour) ──
    _votesSubscription =
        _currentRoomRef?.child('votes').onValue.listen((event) {
      if (state.room == null) return;
      final rawVotes = event.snapshot.value;
      if (rawVotes is Map) {
        final updatedPlayers =
            DeathRegistryService.instance.filterOrEnforce(
                Map<String, PlayerModel>.from(state.room!.players)
            );
        bool hasChanges = false;
        rawVotes.forEach((voterId, targetId) {
          final vid = voterId.toString();
          final tid = targetId?.toString();
          // Un défunt ne peut en aucun cas voter
          if (DeathRegistryService.instance.isDead(vid)) {
            return;
          }
          if (updatedPlayers.containsKey(vid) &&
              updatedPlayers[vid]!.targetVoteId != tid) {
            updatedPlayers[vid] =
                updatedPlayers[vid]!.copyWith(targetVoteId: tid);
            hasChanges = true;
          }
        });
        if (hasChanges) {
          final updatedRoom = state.room!.copyWith(players: updatedPlayers);
          state = state.copyWith(room: updatedRoom);

          _checkEarlyResolutionQuorum(updatedRoom);
        }
      }
    });

    // 4b. ── SOUSCRIPTION GRANULAIRE : cemetery (registre de mort partagé en temps-réel) ──
    _cemeterySubscription =
        _currentRoomRef?.child('cemetery').onValue.listen((event) {
      if (state.room == null) return;
      final rawCemetery = event.snapshot.value;
      if (rawCemetery is Map) {
        DeathRegistryService.instance.syncFromFirebase(rawCemetery);
        final enforced = DeathRegistryService.instance.filterOrEnforce(
          Map<String, PlayerModel>.from(state.room!.players),
        );
        state = state.copyWith(room: state.room!.copyWith(players: enforced));
      }
    });

    // 5. ── SOUSCRIPTION GRANULAIRE : presence (statut vocal, volume, connectivité) ──
    // Met à jour la présence de façon isolée SANS re-parser ni reconstruire la salle entière
    _presenceSubscription =
        _currentRoomRef?.child('presence').onValue.listen((event) {
      if (state.room == null) return;
      final rawPresence = event.snapshot.value;
      if (rawPresence is Map) {
        final updatedPlayers =
            Map<String, PlayerModel>.from(state.room!.players);
        bool hasChanges = false;
        rawPresence.forEach((uid, pData) {
          final userId = uid.toString();
          if (updatedPlayers.containsKey(userId) && pData is Map) {
            final isOnline = pData['isOnline'] == true;
            final isMuted = pData['isMuted'] == true;
            final prev = updatedPlayers[userId]!;
            if (prev.isOnline != isOnline || prev.isMuted != isMuted) {
              updatedPlayers[userId] = prev.copyWith(
                isOnline: isOnline,
                isMuted: isMuted,
              );
              hasChanges = true;
            }
          }
        });
        if (hasChanges) {
          state = state.copyWith(
            room: state.room!.copyWith(players: updatedPlayers),
          );
        }
      }
    });

    // 6. ── SOUSCRIPTION GRANULAIRE : logs (historique textuel uniquement) ──
    _logsSubscription =
        _currentRoomRef?.child('logs').onValue.listen((event) {
      if (state.room == null) return;
      final rawLogs = event.snapshot.value;
      final List<String> parsedLogs = [];
      if (rawLogs is List) {
        for (final item in rawLogs) {
          if (item != null) parsedLogs.add(item.toString());
        }
      }
      state = state.copyWith(room: state.room!.copyWith(logs: parsedLogs));
    });

    // 7. Écouter son propre rôle secret depuis la source confidentielle
    _secretRoleSubscription = _database
        .ref('rooms/$roomCode/secret_roles/${state.currentUserId}')
        .onValue
        .listen((event) {
      if (event.snapshot.value != null && event.snapshot.value is Map) {
        final val = event.snapshot.value as Map;
        final roleId = val['roleId']?.toString();
        if (roleId != null && state.room != null) {
          final realRole = GameRole.fromId(roleId);
          final me = state.room!.players[state.currentUserId];
          if (me != null && me.role != realRole) {
            final updatedMe = me.copyWith(role: realRole);
            final updatedPlayers =
                Map<String, PlayerModel>.from(state.room!.players)
                  ..[state.currentUserId] = updatedMe;
            final updatedRoom =
                state.room!.copyWith(players: updatedPlayers);
            state = state.copyWith(room: updatedRoom);
            _applyVoiceRulesForPhase(updatedRoom);

            if (realRole.isEvil) {
              _syncWolfRoster(roomCode);
            }
          }
        }
      }
    });

    // 8. Écouter le canal meute des loups-garous (filtré et déchiffré)
    _wolfPackSubscription = _database
        .ref('rooms/$roomCode/wolf_pack')
        .onValue
        .listen((event) {
      if (event.snapshot.value != null && event.snapshot.value is Map) {
        final val = event.snapshot.value as Map;
        Set<String> wolfIds = {};
        if (val.containsKey('data')) {
          wolfIds = RoleSecurityService.decryptWolfRoster(
            val['data']?.toString(),
            roomCode,
          );
        } else {
          wolfIds = val.keys.map((k) => k.toString()).toSet();
        }

        final isMeWolf = state.myRole.isEvil;
        final isDevMode = state.isDevMode;
        if (isMeWolf || isDevMode) {
          state = state.copyWith(wolfPlayerIds: wolfIds);
        } else {
          state = state.copyWith(wolfPlayerIds: {});
        }
      }
    });

    // 9. Écouter replay_status_updated
    _replayStatusSubscription = _database
        .ref('rooms/$roomCode/replay_status_updated')
        .onValue
        .listen((event) {
      if (event.snapshot.value != null && event.snapshot.value is Map) {
        final val = event.snapshot.value as Map;
        final readyUserIds = (val['readyUserIds'] as List?)
            ?.map((e) => e.toString())
            .toList();
        if (readyUserIds != null && state.room != null) {
          final updatedRoom = state.room!.copyWith(
            replayReadyUserIds: readyUserIds,
          );
          state = state.copyWith(room: updatedRoom);

          // Seul l'hôte vérifie et déclenche la réinitialisation de partie
          if (state.isHost) {
            _checkReplayQuorum(updatedRoom, roomCode);
          }
        }
      }
    });

    // 10. Écouter game_reset_to_lobby
    _gameResetSubscription = _database
        .ref('rooms/$roomCode/game_reset_to_lobby')
        .onValue
        .listen((event) {
      if (event.snapshot.value != null && state.room != null) {
        DeathRegistryService.instance.clearForNewGame();
        state = state.copyWith(isVictoryVoiceExpired: false);
      }
    });

    // 11. ── SURVEILLANCE DE L'HÔTE (Host-Presence Watchdog) ──
    // Si l'hôte se déconnecte de façon inattendue (crash, perte réseau),
    // le premier joueur en ligne par ordre alphabétique de UID prend le relais.
    // L'idempotence est garantie : seul ce joueur-là exécute l'écriture.
    _hostPresenceSubscription = _database
        .ref('rooms/$roomCode/players')
        .onValue
        .listen((event) {
      if (state.room == null || _currentRoomRef == null) return;
      final currentRoom = state.room!;

      // Ne déclencher que si l'hôte actuel n'est plus en ligne
      final hostId = currentRoom.hostId;
      final hostPlayer = currentRoom.players[hostId];
      if (hostPlayer == null || hostPlayer.isOnline) return;

      // L'hôte est offline → identifier le successeur
      _triggerHostTransfer(roomCode, hostId, currentRoom);
    });

    // 12. ── SYNCHRONISATION DE L'HÔTE ACTIF (hostId sync) ──
    // Assure que tous les clients et le nouveau hôte synchronisent leur rôle.
    _hostIdSubscription = _database
        .ref('rooms/$roomCode/hostId')
        .onValue
        .listen((event) {
      final newHostId = event.snapshot.value?.toString();
      if (newHostId != null && state.room != null && state.room!.hostId != newHostId) {
        debugPrint('[HostSync] 👑 Mise à jour de l\'hôte détectée : $newHostId');
        final updatedRoom = state.room!.copyWith(hostId: newHostId);
        state = state.copyWith(room: updatedRoom);
        if (newHostId == state.currentUserId) {
          debugPrint('[HostSync] 🎉 Vous êtes désigné comme nouvel Hôte ! Reprise immédiate des timers.');
          _syncPhaseExpirationSchedule(updatedRoom);
          _checkEarlyResolutionQuorum(updatedRoom);
        }
      }
    });
  }

  /// Transfère l'hôte au premier joueur online non-hôte (tri UID pour idempotence).
  /// Cette méthode est appelée par chaque client, mais seul le candidat désigné
  /// écrit effectivement sur Firebase — les autres détectent l'écart via le snapshot.
  Future<void> _triggerHostTransfer(
    String roomCode,
    String currentHostId,
    GameRoom currentRoom,
  ) async {
    // Candidats : joueurs online, vivants ou non, sauf l'hôte déconnecté
    final candidates = currentRoom.players.values
        .where((p) => p.id != currentHostId && p.isOnline)
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id)); // Tri déterministe

    if (candidates.isEmpty) return;

    final nextHost = candidates.first;

    // Idempotence : seul le joueur désigné s'auto-sélectionne
    if (nextHost.id != state.currentUserId) return;

    // Vérifier que l'hôte n'a pas déjà été transféré (évite la double écriture)
    try {
      final snap = await _database.ref('rooms/$roomCode/hostId').get();
      if (snap.value?.toString() != currentHostId) return; // Déjà transféré
    } catch (_) {
      return;
    }

    try {
      final updatedLogs = [
        ...currentRoom.logs,
        '👑 ${nextHost.name} a pris le relais en tant que nouvel hôte (connexion hôte perdue).',
      ];
      await _database.ref('rooms/$roomCode').update({
        'hostId': nextHost.id,
        'players/${nextHost.id}/isHost': true,
        'players/$currentHostId/isHost': false,
        'logs': updatedLogs,
      });

      // Synchronisation locale immédiate pour le nouvel hôte
      final updatedRoom = currentRoom.copyWith(
        hostId: nextHost.id,
        players: {
          ...currentRoom.players,
          nextHost.id: nextHost.copyWith(isHost: true),
          if (currentRoom.players.containsKey(currentHostId))
            currentHostId: currentRoom.players[currentHostId]!.copyWith(isHost: false),
        },
        logs: updatedLogs,
      );
      state = state.copyWith(room: updatedRoom);
      _syncPhaseExpirationSchedule(updatedRoom);
      _checkEarlyResolutionQuorum(updatedRoom);

      debugPrint('[HostTransfer] 👑 Hôte transféré de $currentHostId vers ${nextHost.id}');
    } catch (e) {
      debugPrint('[HostTransfer] Erreur transfert hôte: $e');
    }
  }

  Future<void> _syncWolfRoster(String roomCode) async {
    try {
      final snap = await _database.ref('rooms/$roomCode/wolf_pack').get();
      if (snap.exists && snap.value is Map) {
        final val = snap.value as Map;
        Set<String> wolfIds = {};
        if (val.containsKey('data')) {
          wolfIds = RoleSecurityService.decryptWolfRoster(
            val['data']?.toString(),
            roomCode,
          );
        } else {
          wolfIds = val.keys.map((k) => k.toString()).toSet();
        }
        final isMeWolf = state.myRole.isEvil;
        final isDevMode = state.isDevMode;
        if (isMeWolf || isDevMode) {
          state = state.copyWith(wolfPlayerIds: wolfIds);
        } else {
          state = state.copyWith(wolfPlayerIds: {});
        }
      }
    } catch (_) {}
  }

  bool get isVictoryVoiceExpired => state.isVictoryVoiceExpired;

  void setVictoryVoiceExpired(bool expired) {
    state = state.copyWith(isVictoryVoiceExpired: expired);
    if (state.room != null && state.room!.phase == GamePhase.gameOver) {
      _applyVoiceRulesForPhase(state.room!);
    }
  }

  /// Détermine si un joueur doit avoir son micro coupé selon les règles de la phase en cours.
  static bool calculateShouldMuteForPhase({
    required GamePhase phase,
    required bool isAlive,
    required bool isSilencedByBlackWolf,
    required bool isCurrentSpeaker,
    required bool isEvil,
    required bool isVictoryVoiceExpired,
    bool isBot = false,
    String? pendingHunterId,
    String? pendingCaptainId,
    String? currentUserId,
  }) {
    // 0. Si le joueur est un bot, son micro est strictement et invariablement coupé
    if (isBot) {
      return true;
    }

    // 1. Lors de la fin de partie (gameOver) : Minute vocale collective (60s)
    // Tous les joueurs (morts, vivants, ou réduits au silence) peuvent parler tant que la minute n'a pas expiré.
    if (phase == GamePhase.gameOver) {
      return isVictoryVoiceExpired;
    }

    // 2. Morts éliminés du vocal durant la partie
    if (!isAlive) {
      return true;
    }

    // 3. Réduit au silence par le pouvoir du Loup Noir
    if (isSilencedByBlackWolf) {
      return true;
    }

    // 4. Règles spécifiques par phase nocturne / diurne
    if (phase.isNight) {
      if (phase == GamePhase.nightWerewolves) {
        return !isEvil; // Seuls les loups parlent dans le canal meute
      }
      // Toutes les autres sous-phases nocturnes (Voyante, Sorcière, Voleur, Salvateur, Cupidon, etc.) : micro coupé
      return true;
    }

    switch (phase) {
      case GamePhase.dayDebate:
      case GamePhase.dayDefense:
      case GamePhase.mayorSpeechOpening:
      case GamePhase.mayorSpeechClosing:
        return !isCurrentSpeaker;
      case GamePhase.hunterDeathChoice:
        return pendingHunterId != currentUserId;
      case GamePhase.captainSuccession:
      case GamePhase.mayorSuccession:
        return pendingCaptainId != currentUserId;
      case GamePhase.dayVoting:
      case GamePhase.dayTieBreakVote:
      case GamePhase.dayResolution:
      case GamePhase.captainElection:
      case GamePhase.mayorElection:
      case GamePhase.morningAnnouncement:
      case GamePhase.lobby:
        return false;
      default:
        return true;
    }
  }

  Future<void> _applyVoiceRulesForPhase(GameRoom room) async {
    final me = room.players[state.currentUserId];
    if (me == null) return;

    if (room.phase != GamePhase.gameOver && state.isVictoryVoiceExpired) {
      state = state.copyWith(isVictoryVoiceExpired: false);
    }

    final roomCode = room.roomCode;
    final mainChannel = 'lupus_$roomCode';
    final wolfChannel = 'lupus_${roomCode}_wolves';

    // 1. Joueur éliminé : micro strictement coupé
    if (!me.isAlive && room.phase != GamePhase.gameOver) {
      await _voiceService.setMute(true);
      // Les morts peuvent écouter les phases de jour mais sont isolés la nuit
      if (room.phase.isNight) {
        await _voiceService.muteSpeaker(true);
      } else {
        await _voiceService.muteSpeaker(false);
      }
      return;
    }

    String targetChannel = mainChannel;
    final isWolf = me.role.isEvil || me.role == GameRole.whiteWerewolf;
    final canSpy =
        me.role == GameRole.littleGirl ||
        (state.isAdmin && state.isOmniscientVoice);

    if (room.phase == GamePhase.nightWerewolves && (isWolf || canSpy)) {
      targetChannel = wolfChannel;
    } else {
      targetChannel = mainChannel;
    }

    // Bascule uniquement si le canal de destination ou la phase a réellement changé
    if (_lastAppliedVoiceChannel != targetChannel || _lastAppliedVoicePhase != room.phase) {
      _lastAppliedVoiceChannel = targetChannel;
      _lastAppliedVoicePhase = room.phase;
      await _voiceService.switchChannel(
        newChannelId: targetChannel,
        uid: state.agoraUid,
        userAccount: state.currentUserId,
      );
    }

    final shouldMute = calculateShouldMuteForPhase(
      phase: room.phase,
      isAlive: me.isAlive,
      isSilencedByBlackWolf: me.isMuted,
      isCurrentSpeaker: room.currentSpeakerId == state.currentUserId,
      isEvil: isWolf,
      isVictoryVoiceExpired: state.isVictoryVoiceExpired,
      isBot: me.isBot,
      pendingHunterId: room.pendingHunterId,
      pendingCaptainId: room.pendingCaptainId,
      currentUserId: state.currentUserId,
    );

    await _voiceService.setMute(shouldMute);

    // Contrôle strict du haut-parleur (muteSpeaker / deafen) :
    // - Nuit des Loups-Garous : seuls les loups et l'espionne (Petite Fille / Admin) écoutent le canal de la meute.
    // - Autres nuits solitaires (Voyante, Sorcière, etc.) : silence complet pour tous (muteSpeaker = true).
    // - Phases de jour / Débat / Vote / Aube / GameOver : haut-parleur actif pour tous les survivants (muteSpeaker = false).
    if (room.phase == GamePhase.nightWerewolves) {
      if (isWolf || canSpy) {
        await _voiceService.muteSpeaker(false);
      } else {
        await _voiceService.muteSpeaker(true);
      }
    } else if (room.phase.isNight) {
      await _voiceService.muteSpeaker(true);
    } else {
      await _voiceService.muteSpeaker(false);
    }
  }

  // ==========================================
  // --- PANNEAU MAÎTRE DU JEU (MODE DEV / ADMIN) ---
  // ==========================================

  bool unlockAdmin(String pin) {
    if (pin.trim() == '03031994') {
      state = state.copyWith(isAdmin: true, isDevModeActive: true);
      return true;
    }
    return false;
  }

  /// Permet à l'Hôte en Mode Dev d'incarner / basculer sur un joueur ou bot pour agir en son nom
  void impersonatePlayer(String? targetUid) {
    if (!state.isDevMode) return;
    state = state.copyWith(
      impersonatedUserId: targetUid,
      clearImpersonation: targetUid == null || targetUid.isEmpty,
    );
  }

  Future<void> adminForcePhase(GamePhase targetPhase) async {
    if (_currentRoomRef == null || state.room == null) return;
    final log = '[ADMIN] Passage forcé à la phase : ${targetPhase.displayName}';
    final currentLogs = List<String>.from(state.room!.logs)..insert(0, log);
    final updates = <String, dynamic>{
      'phase': targetPhase.name,
      'logs': currentLogs,
    };
    if (targetPhase == GamePhase.dayDebate) {
      final queue = List<String>.from(state.room!.alivePlayers.map((p) => p.id));
      while (queue.isNotEmpty && (state.room!.players[queue.first]?.isMuted ?? false)) {
        final mutedId = queue.removeAt(0);
        final mutedName = state.room!.players[mutedId]?.name ?? 'Un citoyen';
        currentLogs.insert(
          0,
          '🔇 [MODE DEV] $mutedName est bâillonné ! Son tour de parole est sauté.',
        );
      }
      updates['debateQueue'] = queue;
      updates['currentSpeakerId'] = queue.isNotEmpty ? queue.first : null;
      updates['timerSeconds'] = 60;
    }
    if (targetPhase.isNight) {
      for (final p in state.room!.players.values) {
        if (p.isMuted) {
          updates['players/${p.id}/isMuted'] = false;
        }
      }
    }
    if (targetPhase == GamePhase.nightWitch &&
        state.room?.nightVictimId == null) {
      String? wolfVictimId = _tallyWerewolfVotes();
      if (wolfVictimId == null) {
        final innocentLiving = state.room!.alivePlayers
            .where((p) => !p.role.isEvil)
            .toList();
        if (innocentLiving.isNotEmpty) {
          wolfVictimId = innocentLiving.first.id;
        }
      }
      if (wolfVictimId != null) {
        updates['nightVictimId'] = wolfVictimId;
        final victim = state.room!.players[wolfVictimId];
        currentLogs.insert(
          0,
          '🐺 Les Loups-Garous ont désigné ${victim?.name ?? "un villageois"} comme proie.',
        );
      }
    }
    await _syncState(updates);
  }

  Future<void> adminForceMorningResolution() async {
    await resolveMorningDeaths();
  }

  Future<void> adminTogglePlayerLife(String playerId) async {
    if (_currentRoomRef == null || state.room == null) return;
    final target = state.room!.players[playerId];
    if (target == null) return;
    final newAlive = !target.isAlive;
    final log =
        '[ADMIN] ${target.name} a été ${newAlive ? "ressuscité(e)" : "éliminé(e)"} par le Maître du Jeu.';
    final currentLogs = List<String>.from(state.room!.logs)..insert(0, log);

    final updates = <String, dynamic>{
      'players/$playerId/isAlive': newAlive,
      'logs': currentLogs,
    };

    if (!newAlive) {
      GameRole realRole = target.roleInitial;
      try {
        final sSnap = await _database
            .ref('rooms/${state.room!.roomCode}/secret_roles/$playerId/roleId')
            .get();
        if (sSnap.exists && sSnap.value != null) {
          realRole = GameRole.fromId(sSnap.value.toString());
          updates['players/$playerId/role'] = sSnap.value.toString();
        }
      } catch (_) {}

      updates['lastDeathFlip'] = {
        'action': 'FLIP_CARTE_MORT',
        'joueurId': playerId,
        'nom': target.name,
        'role': realRole.name,
        'camp': realRole.isEvil ? 'LOUPS' : 'VILLAGE',
        'cause': 'VOTE_VILLAGE',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
    }

    await _syncState(updates);

    final simulated = state.room!.copyWith(
      players: {
        ...state.room!.players,
        playerId: target.copyWith(isAlive: newAlive),
      },
    );
    final realRoles = await _resolveRealRoles(state.room!);
    final win = checkWinConditions(simulated, realRoles);
    if (win != null) {
      await _syncState({'winner': win, 'phase': GamePhase.gameOver.name});
    }
  }

  Future<void> adminTogglePlayerMute(String playerId) async {
    if (_currentRoomRef == null || state.room == null) return;
    final target = state.room!.players[playerId];
    if (target == null) return;
    final newMuted = !target.isMuted;
    final log =
        '[ADMIN] ${target.name} a été ${newMuted ? "réduit(e) au silence (micro coupé)" : "rétabli(e) dans son droit de parole"} par le Maître du Jeu.';
    final currentLogs = List<String>.from(state.room!.logs)..insert(0, log);

    await _syncState({
      'players/$playerId/isMuted': newMuted,
      'logs': currentLogs,
    });

    // En Mode Dev : si le joueur bâillonné avait la parole pendant le débat, on saute immédiatement son tour
    if (newMuted &&
        state.room?.phase == GamePhase.dayDebate &&
        state.room?.currentSpeakerId == playerId) {
      await passTurnDebate();
    }
  }

  /// Mode Dev : Forcer ou réinitialiser la proie nocturne des loups
  Future<void> adminSetNightVictim(String? playerId) async {
    if (_currentRoomRef == null || state.room == null) return;
    final target = playerId != null ? state.room!.players[playerId] : null;
    final log = target != null
        ? '[ADMIN] Proie des Loups fixée à : ${target.name}'
        : '[ADMIN] Proie des Loups réinitialisée';
    final currentLogs = List<String>.from(state.room!.logs)..insert(0, log);

    await _syncState({
      'nightVictimId': playerId,
      'logs': currentLogs,
    });
  }

  /// Mode Dev : Forcer ou réinitialiser la cible de silence nocturne des loups
  Future<void> adminSetNightSilence(String? playerId) async {
    if (_currentRoomRef == null || state.room == null) return;
    final target = playerId != null ? state.room!.players[playerId] : null;
    final log = target != null
        ? '[ADMIN] Cible de silence des Loups fixée à : ${target.name}'
        : '[ADMIN] Cible de silence des Loups réinitialisée';
    final currentLogs = List<String>.from(state.room!.logs)..insert(0, log);

    await _syncState({
      'blackWolfTargetId': playerId,
      'logs': currentLogs,
    });
  }

  Future<void> adminForceSpeaker(String? playerId) async {
    if (_currentRoomRef == null || state.room == null) return;
    final target = playerId != null ? state.room!.players[playerId] : null;
    final currentLogs = List<String>.from(state.room!.logs);
    if (target != null && target.isMuted) {
      currentLogs.insert(
        0,
        '⚠️ [ADMIN] Attention : ${target.name} est bâillonné(e) par les loups !',
      );
    }
    final log =
        '[ADMIN] Parole accordée à : ${target?.name ?? "Silence général"}';
    currentLogs.insert(0, log);

    await _syncState({'currentSpeakerId': playerId, 'logs': currentLogs});
  }

  Future<void> adminForceCaptain(String playerId) async {
    if (_currentRoomRef == null || state.room == null) return;
    final target = state.room!.players[playerId];
    if (target == null) return;

    final updates = <String, dynamic>{'captainId': playerId};
    for (final p in state.room!.playerList) {
      updates['players/${p.id}/isCaptain'] = (p.id == playerId);
    }
    final log =
        '[ADMIN] ${target.name} a été proclamé(e) Maire par le Maître du Jeu.';
    updates['logs'] = List<String>.from(state.room!.logs)..insert(0, log);

    await _syncState(updates);
  }

  Future<void> adminForceRole(String playerId, GameRole newRole) async {
    // Le Maire est un statut électif (géré via captainId), pas une carte de rôle distribuable
    if (newRole == GameRole.mayor) return;
    if (_currentRoomRef == null || state.room == null) return;
    final target = state.room!.players[playerId];
    if (target == null) return;
    final log =
        '[ADMIN] Rôle de ${target.name} modifié : ${target.role.displayNameFr} -> ${newRole.displayNameFr}';
    final currentLogs = List<String>.from(state.room!.logs)..insert(0, log);

    final roomCode = state.room!.roomCode;
    final encrypted = RoleSecurityService.encryptRole(newRole.id, playerId, roomCode);

    final updates = <String, dynamic>{
      'players/$playerId/role': newRole.id,
      'players/$playerId/initialRole': newRole.id,
      'players/$playerId/encryptedRole': encrypted,
      'logs': currentLogs,
    };

    if (newRole == GameRole.witch) {
      updates['players/$playerId/potionsVie'] = 1;
      updates['players/$playerId/potionsMort'] = 1;
    } else if (newRole == GameRole.seer) {
      updates['players/$playerId/visionsRestantes'] = 2;
    }

    await _syncState(updates);
    try {
      await _database
          .ref('rooms/$roomCode/secret_roles/$playerId/roleId')
          .set(newRole.id);
    } catch (_) {}
  }

  void toggleDevOmniscientAudio() {
    state = state.copyWith(isOmniscientVoice: !state.isOmniscientVoice);
    _syncOmniscientAudioChannel();
  }

  void adminToggleOmniscientVoice() => toggleDevOmniscientAudio();

  Future<void> _syncOmniscientAudioChannel() async {
    if (_currentRoomRef == null || state.room == null) return;
    final isMeWolf = state.myRole.isEvil || state.myRole == GameRole.whiteWerewolf;
    final isNightWerewolves = state.room!.phase == GamePhase.nightWerewolves;
    final isDevRoom = state.room!.isDevRoom;
    final newOmniscient = state.isOmniscientVoice && isDevRoom && isNightWerewolves && !isMeWolf;

    final roomCode = state.room!.roomCode;
    final mainChannel = 'lupus_$roomCode';
    final wolfChannel = 'lupus_${roomCode}_wolves';

    if (newOmniscient) {
      await _voiceService.switchChannel(
        newChannelId: wolfChannel,
        uid: state.agoraUid,
      );
      _voiceService.setMute(false);
    } else {
      await _voiceService.switchChannel(
        newChannelId: mainChannel,
        uid: state.agoraUid,
      );
      if (state.room != null) {
        _applyVoiceRulesForPhase(state.room!);
      }
    }
  }

  // ==========================================
  // --- SIMULATION SANDBOX AVEC BOTS (DEV-MODE) ---
  // ==========================================

  /// Génère une composition équilibrée et canonique de rôles selon le nombre de participants (6 à 18)
  static List<GameRole> generateBalancedRoles(int total) {
    final count = total.clamp(6, 18);
    final roles = <GameRole>[];

    // 1. Voyante (indispensable)
    roles.add(GameRole.seer);

    // 2. Loups selon l'effectif (1 à 4)
    final numWolves = count <= 8 ? 1 : (count <= 11 ? 2 : (count <= 14 ? 3 : 4));
    roles.add(GameRole.simpleWerewolf);
    if (numWolves >= 2) roles.add(GameRole.bigBadWolf);
    if (numWolves >= 3) roles.add(GameRole.simpleWerewolf);
    if (numWolves >= 4) roles.add(GameRole.vileFatherOfWolves);

    // 3. Rôles villageois majeurs et rôles spéciaux
    roles.add(GameRole.witch);
    roles.add(GameRole.hunter);
    roles.add(GameRole.defender);

    if (roles.length < count) roles.add(GameRole.cupid);
    if (roles.length < count) roles.add(GameRole.elder);
    if (roles.length < count) roles.add(GameRole.piedPiper);
    if (roles.length < count) roles.add(GameRole.knightRustySword);
    if (roles.length < count) roles.add(GameRole.pyromaniac);
    if (roles.length < count) roles.add(GameRole.whiteWerewolf);
    if (roles.length < count) roles.add(GameRole.fox);
    if (roles.length < count) roles.add(GameRole.bearTamer);

    // 4. Remplir le reste avec des simples villageois
    while (roles.length < count) {
      roles.add(GameRole.simpleVillager);
    }
    return roles.sublist(0, count);
  }

  /// Lancer une simulation Dev-Mode avec un nombre configurable de participants (6 à 18) et bots passifs
  /// Exécute STRICTEMENT le moteur de jeu réel multijoueur (minuteurs réels, règles canoniques, quotas, RTDB, tokens chiffrés)
  Future<bool> startSandboxGame({
    int playerCount = 12,
    List<GameRole>? customRoles,
    Map<String, GameRole>? customBotRoles,
  }) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      isAdmin: true,
      isDevModeActive: true,
    );
    try {
      final roomCode = _generateRoomCode();
      final totalJoueurs = playerCount.clamp(6, 18);
      final rolesList = (customRoles != null && customRoles.length == totalJoueurs)
          ? List<GameRole>.from(customRoles)
          : generateBalancedRoles(totalJoueurs);

      final maxPotions = max(1, totalJoueurs ~/ 10);
      final maxVisions = totalJoueurs <= 4
          ? 1
          : totalJoueurs <= 9
              ? 2
              : totalJoueurs <= 14
                  ? 3
                  : totalJoueurs ~/ 4;

      final myRole = rolesList[0];
      final myPlayer = PlayerModel(
        id: state.currentUserId,
        name: '${state.currentUserName} 👑 (Dev)',
        avatarIndex: state.currentUserAvatar,
        role: myRole,
        initialRole: myRole,
        isHost: true,
        isReady: true,
        isAlive: true,
        isOnline: true,
        isBot: false,
        seatIndex: 0,
        agoraUid: state.agoraUid,
        socketId: 'sock_${state.currentUserId}_${DateTime.now().millisecondsSinceEpoch}',
        potionsVie: (myRole == GameRole.witch) ? maxPotions : 0,
        potionsMort: (myRole == GameRole.witch) ? maxPotions : 0,
        visionsRestantes: (myRole == GameRole.seer) ? maxVisions : 0,
        encryptedRole: RoleSecurityService.encryptRole(myRole.id, state.currentUserId, roomCode),
      );

      final Map<String, PlayerModel> allPlayers = {
        state.currentUserId: myPlayer,
      };

      final botNames = [
        'Bot Alice', 'Bot Bob', 'Bot Charlie', 'Bot David', 'Bot Emma',
        'Bot Gabriel', 'Bot Helena', 'Bot Bastien', 'Bot Liam', 'Bot Zoe',
        'Bot Sam', 'Bot Chloe', 'Bot Lucas', 'Bot Lea', 'Bot Thomas',
        'Bot Camille', 'Bot Antoine', 'Bot Sarah'
      ];

      for (int i = 1; i < totalJoueurs; i++) {
        final botId = 'bot_$i';
        final role = customBotRoles?[botId] ?? rolesList[i];
        final name = (i - 1 < botNames.length) ? botNames[i - 1] : 'Bot $i';
        final avatar = ((i - 1) % 15) + 1;
        allPlayers[botId] = PlayerModel(
          id: botId,
          name: name,
          avatarIndex: avatar,
          role: role,
          initialRole: role,
          isHost: false,
          isReady: true,
          isAlive: true,
          isOnline: true,
          isBot: true,
          seatIndex: i,
          potionsVie: (role == GameRole.witch) ? maxPotions : 0,
          potionsMort: (role == GameRole.witch) ? maxPotions : 0,
          visionsRestantes: (role == GameRole.seer) ? maxVisions : 0,
          encryptedRole: RoleSecurityService.encryptRole(role.id, botId, roomCode),
        );
      }

      final pool = <String, int>{};
      for (final p in allPlayers.values) {
        pool[p.role.id] = (pool[p.role.id] ?? 0) + 1;
      }

      // Détermination de la première phase nocturne canonique selon les rôles présents
      final assignedRoleIds = allPlayers.values.map((p) => p.role.id).toSet();
      GamePhase firstPhase;
      if (assignedRoleIds.contains('thief') ||
          assignedRoleIds.contains('thief_of_hearts') ||
          assignedRoleIds.contains('soul_stealer')) {
        firstPhase = GamePhase.nightThief;
      } else if (assignedRoleIds.contains('cupid')) {
        firstPhase = GamePhase.nightCupid;
      } else if (assignedRoleIds.contains('defender')) {
        firstPhase = GamePhase.nightDefender;
      } else if (assignedRoleIds.contains('werewolf') ||
          assignedRoleIds.contains('simpleWerewolf') ||
          assignedRoleIds.contains('bigBadWolf') ||
          assignedRoleIds.contains('whiteWerewolf') ||
          assignedRoleIds.contains('vileFatherOfWolves')) {
        firstPhase = GamePhase.nightWerewolves;
      } else if (assignedRoleIds.contains('seer')) {
        firstPhase = GamePhase.nightSeer;
      } else if (assignedRoleIds.contains('witch')) {
        firstPhase = GamePhase.nightWitch;
      } else if (assignedRoleIds.contains('pyromaniac')) {
        firstPhase = GamePhase.nightPyromaniac;
      } else if (assignedRoleIds.contains('piedPiper')) {
        firstPhase = GamePhase.nightPiper;
      } else {
        firstPhase = GamePhase.morningAnnouncement;
      }

      // Minuteur authentique réel selon les règles de production (ex: 20s, 30s, 40s) — PAS 999s
      final realTimerSeconds = firstPhase.durationSeconds > 0
          ? firstPhase.durationSeconds
          : (firstPhase.isNight ? 20 : 60);

      final seatingOrder = allPlayers.keys.toList();
      final currentServerTime = ServerTimeService().currentServerEstimatedTime;

      final newRoom = GameRoom(
        roomCode: roomCode,
        hostId: state.currentUserId,
        isDevRoom: true,
        phase: firstPhase,
        players: allPlayers,
        rolePool: pool,
        round: 1,
        seatingOrder: seatingOrder,
        timerSeconds: realTimerSeconds,
        phaseStartedAt: currentServerTime,
        phaseEndsAt: currentServerTime + (realTimerSeconds * 1000),
        logs: [
          '🎮 [MODE DEV] Session $totalJoueurs joueurs initialisée (1 Hôte Dev + ${totalJoueurs - 1} Bots passifs).',
          '🌙 Nuit 1 : Moteur réel actif (${firstPhase.titleFr}, minuteur $realTimerSeconds s). Incarnez n\'importe quel rôle via le sélecteur.',
        ],
      );

      _currentRoomRef = _database.ref('rooms/$roomCode');
      await _currentRoomRef!.set(newRoom.toMap());

      // Écriture des rôles secrets et de l'ordre des sièges dans RTDB
      try {
        await _currentRoomRef!.child('seatingOrder').set(seatingOrder);
      } catch (_) {}

      for (final p in allPlayers.values) {
        try {
          await _database
              .ref('rooms/$roomCode/secret_roles/${p.id}/roleId')
              .set(p.role.id);
        } catch (_) {}
      }

      // Si des loups existent, enregistrer la meute chiffrée
      final wolfIds = allPlayers.values
          .where((p) => p.role.isEvil)
          .map((p) => p.id)
          .toList();
      if (wolfIds.isNotEmpty) {
        try {
          final enc = RoleSecurityService.encryptWolfRoster(wolfIds, roomCode);
          await _database.ref('rooms/$roomCode/wolf_pack').set({'data': enc});
        } catch (_) {}
      }

      _subscribeToRoom(roomCode);

      await _voiceService.initialize();
      await _voiceService.joinChannel(
        channelId: 'lupus_$roomCode',
        uid: state.agoraUid,
        userAccount: state.currentUserId,
      );

      state = state.copyWith(
        room: newRoom,
        isLoading: false,
        isAdmin: true,
        isDevModeActive: true,
      );
      return true;
    } catch (e) {
      debugPrint('[startSandboxGame Error] $e');
      state = state.copyWith(isLoading: false, errorMessage: 'Erreur mode dev: $e');
      return false;
    }
  }

  /// Remplit le salon actuel avec des bots passifs pour atteindre 12 joueurs
  Future<void> populateRoomWithBots() async {
    if (_currentRoomRef == null || state.room == null) return;
    final currentCount = state.room!.players.length;
    final needed = 12 - currentCount;
    if (needed <= 0) return;

    final defaultRoles = [
      GameRole.simpleWerewolf,
      GameRole.simpleWerewolf,
      GameRole.witch,
      GameRole.hunter,
      GameRole.defender,
      GameRole.cupid,
      GameRole.elder,
      GameRole.seer,
      GameRole.bigBadWolf,
      GameRole.piedPiper,
      GameRole.simpleVillager,
    ];

    final updates = <String, dynamic>{};
    for (int i = 0; i < needed; i++) {
      final botIndex = currentCount + i;
      final botId = 'bot_$botIndex';
      final role = defaultRoles[i % defaultRoles.length];
      final bot = PlayerModel(
        id: botId,
        name: 'Bot $botIndex',
        avatarIndex: (botIndex % 12),
        role: role,
        initialRole: role,
        isReady: true,
        isAlive: true,
        isOnline: true,
        isBot: true,
        seatIndex: botIndex,
      );
      updates['players/$botId'] = bot.toMap();
    }
    updates['rolePool'] = generateDefaultRolePool(12);
    updates['logs'] = [
      ...?state.room?.logs,
      '🤖 $needed bot(s) passifs de test ont rejoint le salon (Total: 12 joueurs).',
    ];
    await _syncState(updates);
  }

  // ===================== CONTRÔLES MODE DEV (ACTIONS FORCÉES) =====================

  /// Mode Dev : Forcer l'élimination directe avec gestion des mécaniques associées
  Future<void> devKill(String playerId, {String reason = 'décision du Maître du Jeu'}) async {
    if (_currentRoomRef == null || state.room == null) return;
    final target = state.room!.players[playerId];
    if (target == null || !target.isAlive) return;

    final realRoles = await _resolveRealRoles(state.room!);
    final targetRole = realRoles[playerId] ?? target.role;
    final ancientLives = state.room!.expandedRolesState.ancientLives[playerId] ??
        (targetRole == GameRole.elder ? 2 : 1);

    if (targetRole == GameRole.elder && ancientLives > 1 && reason.contains('loup')) {
      final updatedLives = Map<String, int>.from(state.room!.expandedRolesState.ancientLives);
      updatedLives[playerId] = ancientLives - 1;
      await _syncState({
        'expandedRolesState': state.room!.expandedRolesState.copyWith(ancientLives: updatedLives).toMap(),
        'logs': [
          ...?state.room?.logs,
          '🛡️ [DEV RESISTANCE] ${target.name} (Ancien) survit à l\'assaut (1 vie restante).',
        ],
      });
      return;
    }

    final logs = List<String>.from(state.room!.logs);
    logs.insert(0, '💀 [DEV MORT] ${target.name} (${targetRole.displayNameFr}) est éliminé(e) -> Raison: $reason');

    final updates = <String, dynamic>{
      'players/$playerId/isAlive': false,
      'players/$playerId/role': targetRole.id,
      'lastDeathFlip': {
        'action': 'FLIP_CARTE_MORT',
        'joueurId': playerId,
        'nom': target.name,
        'role': targetRole.name,
        'camp': targetRole.isEvil ? 'LOUPS' : 'VILLAGE',
        'cause': reason.toUpperCase(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    };
    updates['cemetery/$playerId'] = true;
    DeathRegistryService.instance.markDead(playerId);

    final partnerDead = handleLoverDeath(playerId, state.room!.players, logs);
    if (partnerDead != null) {
      final pPartner = state.room!.players[partnerDead];
      final partnerRole = realRoles[partnerDead] ?? pPartner?.role ?? GameRole.simpleVillager;
      updates['players/$partnerDead/isAlive'] = false;
      updates['cemetery/$partnerDead'] = true;
      updates['players/$partnerDead/role'] = partnerRole.id;
      DeathRegistryService.instance.markDead(partnerDead);
    }

    if (targetRole == GameRole.hunter) {
      updates['pendingHunterId'] = playerId;
      logs.insert(0, '🎯 [DEV POUVOIR] Le Chasseur ${target.name} est tombé et peut tirer sa riposte.');
    }

    updates['logs'] = logs;
    await _syncState(updates);

    final simulated = state.room!.copyWith(
      players: {
        ...state.room!.players,
        playerId: target.copyWith(isAlive: false),
        if (partnerDead != null && state.room!.players[partnerDead] != null)
          partnerDead: state.room!.players[partnerDead]!.copyWith(isAlive: false),
      },
    );
    final win = checkWinConditions(simulated, realRoles);
    if (win != null) {
      await _syncState({'winner': win, 'phase': GamePhase.gameOver.name});
    }
  }

  /// Mode Dev : Ressusciter un joueur
  Future<void> devRevive(String playerId) async {
    if (_currentRoomRef == null || state.room == null) return;
    final target = state.room!.players[playerId];
    if (target == null) return;
    DeathRegistryService.instance.allowWitchRevive(playerId);
    final logs = List<String>.from(state.room!.logs);
    logs.insert(0, '✨ [DEV RÉANIMATION] ${target.name} a été ressuscité(e) par le Maître du Jeu.');
    await _syncState({
      'players/$playerId/isAlive': true,
      'cemetery/$playerId': null,
      'logs': logs,
    });
  }

  /// Mode Dev : Forcer le rôle d'un joueur
  Future<void> devSetRole(String playerId, GameRole role) => adminForceRole(playerId, role);

  /// Mode Dev : Forcer la proie des loups
  Future<void> devSetNightVictim(String targetId) => adminSetNightVictim(targetId);

  /// Mode Dev : Sonde de la Voyante instantanée
  Future<GameRole?> devSeerInspect(String targetId) async {
    if (_currentRoomRef == null || state.room == null) return null;
    final target = state.room!.players[targetId];
    if (target == null) return null;
    final realRoles = await _resolveRealRoles(state.room!);
    final role = realRoles[targetId] ?? target.role;
    final logs = List<String>.from(state.room!.logs);
    logs.insert(0, '🔮 [DEV VOYANTE] Sonde sur ${target.name} -> [${role.displayNameFr}].');
    await _syncState({'logs': logs});
    return role;
  }

  /// Mode Dev : Potion de vie de la Sorcière
  Future<void> devWitchHeal() async {
    if (_currentRoomRef == null || state.room == null) return;
    final logs = List<String>.from(state.room!.logs);
    logs.insert(0, '✨ [DEV SORCIÈRE] Potion de vie appliquée sur la victime de la meute.');
    await _syncState({'witchHealed': true, 'logs': logs});
  }

  /// Mode Dev : Potion de mort de la Sorcière
  Future<void> devWitchPoison(String targetId) async {
    if (_currentRoomRef == null || state.room == null) return;
    final target = state.room!.players[targetId];
    final logs = List<String>.from(state.room!.logs);
    logs.insert(0, '🧪 [DEV SORCIÈRE] Potion de mort versée sur ${target?.name ?? targetId}.');
    await _syncState({'witchPoisonVictimId': targetId, 'logs': logs});
  }

  /// Mode Dev : Protection du Salvateur
  Future<void> devGuardProtect(String targetId) async {
    if (_currentRoomRef == null || state.room == null) return;
    final target = state.room!.players[targetId];
    final logs = List<String>.from(state.room!.logs);
    logs.insert(0, '🛡️ [DEV SALVATEUR] Bouclier protecteur déployé sur ${target?.name ?? targetId}.');
    await _syncState({'currentProtectedPlayerId': targetId, 'logs': logs});
  }

  /// Mode Dev : Liaison des Amoureux par Cupidon
  Future<void> devCupidLink(String p1Id, String p2Id) async {
    if (_currentRoomRef == null || state.room == null || p1Id == p2Id) return;
    final p1 = state.room!.players[p1Id];
    final p2 = state.room!.players[p2Id];
    final logs = List<String>.from(state.room!.logs);
    logs.insert(0, '💘 [DEV CUPIDON] ${p1?.name ?? p1Id} et ${p2?.name ?? p2Id} sont liés par l\'amour.');
    await _syncState({
      'players/$p1Id/isLover': true,
      'players/$p1Id/loverId': p2Id,
      'players/$p2Id/isLover': true,
      'players/$p2Id/loverId': p1Id,
      'logs': logs,
    });
  }

  /// Mode Dev : Tir du Chasseur
  Future<void> devHunterShoot(String targetId) async {
    await devKill(targetId, reason: 'tir de riposte du chasseur');
  }

  /// Mode Dev : Résolution instantanée de l'Aube / Lever du Jour
  Future<void> devResolveNight() async {
    if (_currentRoomRef == null || state.room == null) return;
    final room = state.room!;
    final updates = <String, dynamic>{};
    final logs = List<String>.from(room.logs);
    final realRoles = await _resolveRealRoles(room);
    final List<String> effectiveDeaths = [];

    // 1. Morsure des Loups
    final wolfVictimId = room.nightVictimId ?? _tallyWerewolfVotes();
    if (wolfVictimId != null) {
      final isProtected = room.currentProtectedPlayerId == wolfVictimId;
      final isHealed = room.witchHealed;

      if (isProtected) {
        logs.insert(0, '🛡️ [RÉSOLU] L\'attaque de la meute sur ${room.players[wolfVictimId]?.name} a été contrée par le bouclier du Salvateur !');
      } else if (isHealed) {
        logs.insert(0, '✨ [RÉSOLU] La potion de vie de la Sorcière a sauvé ${room.players[wolfVictimId]?.name} de la meute !');
      } else {
        final victimRole = realRoles[wolfVictimId] ?? room.players[wolfVictimId]?.role;
        final ancientLives = room.expandedRolesState.ancientLives[wolfVictimId] ?? (victimRole == GameRole.elder ? 2 : 1);
        if (victimRole == GameRole.elder && ancientLives > 1) {
          final updatedLives = Map<String, int>.from(room.expandedRolesState.ancientLives);
          updatedLives[wolfVictimId] = ancientLives - 1;
          updates['expandedRolesState'] = room.expandedRolesState.copyWith(ancientLives: updatedLives).toMap();
          logs.insert(0, '🛡️ [RÉSOLU] L\'Ancien (${room.players[wolfVictimId]?.name}) résiste à la morsure des loups (1 vie restante).');
        } else {
          effectiveDeaths.add(wolfVictimId);
        }
      }
    }

    // 2. Poison Sorcière
    final poisonVictimId = room.witchPoisonVictimId;
    if (poisonVictimId != null && !effectiveDeaths.contains(poisonVictimId)) {
      effectiveDeaths.add(poisonVictimId);
    }

    // 3. Amoureux en chaîne
    final allDeaths = <String>{...effectiveDeaths};
    for (final deadId in effectiveDeaths) {
      final partner = handleLoverDeath(deadId, room.players, logs);
      if (partner != null) allDeaths.add(partner);
    }

    for (final id in allDeaths) {
      updates['players/$id/isAlive'] = false;
      final p = room.players[id];
      final r = realRoles[id] ?? p?.role ?? GameRole.simpleVillager;
      updates['players/$id/role'] = r.id;
      final cause = (id == poisonVictimId) ? 'POISON_SORCIERE' : 'MORSURE_LOUPS';
      updates['lastDeathFlip'] = {
        'action': 'FLIP_CARTE_MORT',
        'joueurId': id,
        'nom': p?.name ?? id,
        'role': r.name,
        'camp': r.isEvil ? 'LOUPS' : 'VILLAGE',
        'cause': cause,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      logs.insert(0, '💀 ${p?.name ?? id} (${r.displayNameFr}) a succombé.');
    }

    updates['lastProtectedPlayerId'] = room.currentProtectedPlayerId;
    updates['currentProtectedPlayerId'] = null;
    updates['nightVictimId'] = null;
    updates['blackWolfTargetId'] = null;
    updates['public_state/nightVictimId'] = null;
    updates['public_state/blackWolfTargetId'] = null;
    updates['witchHealed'] = false;
    updates['witchPoisonVictimId'] = null;
    updates['morningVictims'] = allDeaths.toList();
    _resetAllVotes(updates);

    logs.insert(0, '🌅 [DEV LEVER DU JOUR] L\'aube est résolue instantanément. ${allDeaths.isEmpty ? "Aucun mort." : "${allDeaths.length} trépassé(s)."}');

    final simulated = room.copyWith(
      players: room.players.map((k, v) => MapEntry(k, allDeaths.contains(k) ? v.copyWith(isAlive: false) : v)),
    );
    final win = checkWinConditions(simulated, realRoles);
    if (win != null) {
      updates['phase'] = GamePhase.gameOver.name;
      updates['winner'] = win;
      logs.insert(0, _formatVictoryMessage(win));
    } else {
      _routeToDayPhase(room, updates, logs);
    }

    updates['logs'] = logs;
    await _syncState(updates);
  }

  // ==========================================
  // --- REPLAY & RÉINITIALISATION DE PARTIE ---
  // ==========================================

  /// Algorithme de mélange de Fisher-Yates (Knuth) garanti O(N) et mathématiquement uniforme
  static void fisherYatesShuffle<T>(List<T> list, [Random? random]) {
    final rng = random ?? Random.secure();
    for (int i = list.length - 1; i > 0; i--) {
      final j = rng.nextInt(i + 1);
      final temp = list[i];
      list[i] = list[j];
      list[j] = temp;
    }
  }

  /// Prépare un deck de cartes rôles adapté au nombre de joueurs connectés
  /// (ex: Loup Blanc, Loup Noir, Voyante, Sorcière, Chasseur, Villageois...)
  static List<GameRole> prepareReplayRoleDeck(int count) {
    if (count <= 0) return [];

    final deck = <GameRole>[];

    // Rôles canoniques prioritaires demandés explicitement :
    // Loup Blanc, Loup Noir, Voyante, Sorcière, Chasseur, Villageois...
    final priorityRoles = <GameRole>[
      GameRole.whiteWerewolf, // Loup Blanc
      GameRole.blackWolf, // Loup Noir
      GameRole.seer, // Voyante
      GameRole.witch, // Sorcière
      GameRole.hunter, // Chasseur
      GameRole.simpleVillager, // Simple Villageois
      GameRole.cupid, // Cupidon
      GameRole.littleGirl, // Petite Fille
      GameRole.defender, // Salvateur / Défenseur
      GameRole.simpleWerewolf, // Simple Loup-Garou
      GameRole.thief, // Voleur
      GameRole.bigBadWolf, // Grand Méchant Loup
      GameRole.vileFatherOfWolves, // Infect Père des Loups
      GameRole.angel, // Ange
      GameRole.piedPiper, // Joueur de Flûte
      GameRole.pyromaniac, // Pyromane
    ];

    for (final role in priorityRoles) {
      if (deck.length < count) {
        deck.add(role);
      } else {
        break;
      }
    }

    // Si la salle compte plus de 16 joueurs, compléter par alternance
    while (deck.length < count) {
      if (deck.length % 4 == 0) {
        deck.add(GameRole.simpleWerewolf);
      } else {
        deck.add(GameRole.simpleVillager);
      }
    }

    return deck.sublist(0, count);
  }

  /// Vérification sécurisée et idempotente du quorum de Replay (exécutée par l'Hôte uniquement)
  Future<void> _checkReplayQuorum(GameRoom room, String roomCode) async {
    if (!state.isHost) return;
    if (_isResettingReplay) return;
    // Ne réinitialiser que si le jeu est actuellement en GameOver (évite tout double reset intempestif)
    if (room.phase != GamePhase.gameOver) return;

    final totalCount = room.playerList.length;
    final readyCount = room.replayReadyUserIds.length;

    if (totalCount > 0 && readyCount >= totalCount) {
      _isResettingReplay = true;
      try {
        debugPrint('[Replay Quorum] 🎯 Tous les joueurs ($readyCount/$totalCount) sont prêts. L\'Hôte relance la partie.');
        await resetGameAndRedistributeRoles(roomCode);
      } catch (e) {
        debugPrint('[Replay Quorum] Erreur relance partie: $e');
      } finally {
        _isResettingReplay = false;
      }
    }
  }

  /// Gestion du vote client : Au premier clic, émettre player_ready_replay avec userId et roomId
  Future<void> playerReadyReplay({String? userId, String? roomId}) async {
    final effectiveUserId = userId ?? state.currentUserId;
    final effectiveRoomId = roomId ?? state.room?.roomCode;
    if (effectiveRoomId == null || effectiveRoomId.isEmpty) return;

    try {
      final roomRef = _database.ref('rooms/$effectiveRoomId');

      // 1. Écriture sans conflit sur sa propre clé feuille (atomicité garantie par utilisateur)
      await roomRef.update({
        'replay_votes/$effectiveUserId': true,
        'players/$effectiveUserId/isReadyReplay': true,
        'players/$effectiveUserId/wantsRematch': true,
      });

      // 2. Synchroniser la liste globale consolidée depuis la table des votes
      final snapshot = await roomRef.child('replay_votes').get();
      List<String> readyList = [];
      if (snapshot.value is Map) {
        final votesMap = snapshot.value as Map;
        readyList = votesMap.entries
            .where((e) => e.value == true)
            .map((e) => e.key.toString())
            .toList();
      } else if (!readyList.contains(effectiveUserId)) {
        readyList.add(effectiveUserId);
      }

      final totalCount = state.room?.playerList.length ?? 0;
      final readyCount = readyList.length;

      await roomRef.update({
        'replayReadyUserIds': readyList,
        'replay_status_updated': {
          'event': 'replay_status_updated',
          'userId': effectiveUserId,
          'readyCount': readyCount,
          'totalCount': totalCount,
          'readyUserIds': readyList,
          'timestamp': ServerValue.timestamp,
        },
      });

      // Synchronisation optimiste locale
      if (state.room != null) {
        final updatedPlayers =
            Map<String, PlayerModel>.from(state.room!.players);
        if (updatedPlayers.containsKey(effectiveUserId)) {
          updatedPlayers[effectiveUserId] =
              updatedPlayers[effectiveUserId]!.copyWith(
            isReadyReplay: true,
            wantsRematch: true,
          );
        }
        final updatedRoom = state.room!.copyWith(
          replayReadyUserIds: readyList,
          players: updatedPlayers,
        );
        state = state.copyWith(room: updatedRoom);

        // Seul l'hôte déclenche la réinitialisation
        if (state.isHost) {
          _checkReplayQuorum(updatedRoom, effectiveRoomId);
        }
      }
    } catch (e) {
      debugPrint('[Replay Error] playerReadyReplay: $e');
    }
  }

  /// Gestion du vote client : Un second clic annule le vote via player_cancel_replay
  Future<void> playerCancelReplay({String? userId, String? roomId}) async {
    final effectiveUserId = userId ?? state.currentUserId;
    final effectiveRoomId = roomId ?? state.room?.roomCode;
    if (effectiveRoomId == null || effectiveRoomId.isEmpty) return;

    try {
      final roomRef = _database.ref('rooms/$effectiveRoomId');

      // 1. Suppression de sa clé feuille individuelle
      await roomRef.update({
        'replay_votes/$effectiveUserId': null,
        'players/$effectiveUserId/isReadyReplay': false,
        'players/$effectiveUserId/wantsRematch': false,
      });

      // 2. Synchroniser la liste consolidée
      final snapshot = await roomRef.child('replay_votes').get();
      List<String> readyList = [];
      if (snapshot.value is Map) {
        final votesMap = snapshot.value as Map;
        readyList = votesMap.entries
            .where((e) => e.value == true)
            .map((e) => e.key.toString())
            .toList();
      }

      final totalCount = state.room?.playerList.length ?? 0;
      final readyCount = readyList.length;

      await roomRef.update({
        'replayReadyUserIds': readyList,
        'replay_status_updated': {
          'event': 'replay_status_updated',
          'userId': effectiveUserId,
          'readyCount': readyCount,
          'totalCount': totalCount,
          'readyUserIds': readyList,
          'timestamp': ServerValue.timestamp,
        },
      });

      // Synchronisation optimiste locale
      if (state.room != null) {
        final updatedPlayers =
            Map<String, PlayerModel>.from(state.room!.players);
        if (updatedPlayers.containsKey(effectiveUserId)) {
          updatedPlayers[effectiveUserId] =
              updatedPlayers[effectiveUserId]!.copyWith(
            isReadyReplay: false,
            wantsRematch: false,
          );
        }
        state = state.copyWith(
          room: state.room!.copyWith(
            replayReadyUserIds: readyList,
            players: updatedPlayers,
          ),
        );
      }
    } catch (e) {
      debugPrint('[Replay Error] playerCancelReplay: $e');
    }
  }

  /// Réinitialisation et redistribution aléatoire conditionnelle des rôles :
  /// - Double Fisher-Yates cryptographiquement sécurisé
  /// - Anti-répétition consécutive des rôles par UID
  /// - Recalcul dynamique des quotas (visions = max(1, N ~/ 4), potions = max(1, N ~/ 10))
  /// - PV = 100, isAlive = true, isMuted = false
  /// - Émission de game_reset_to_lobby
  Future<void> resetGameAndRedistributeRoles(String roomCode) async {
    DeathRegistryService.instance.clearForNewGame();
    final roomRef = _database.ref('rooms/$roomCode');
    final roomSnap = await roomRef.get();
    if (!roomSnap.exists || roomSnap.value == null) return;

    final roomData = roomSnap.value as Map<dynamic, dynamic>;
    final currentRoom =
        GameRoom.fromMap(roomData, roomCode, state.currentUserId);
    final playersMap = currentRoom.players;
    final count = playersMap.length;
    if (count == 0) return;

    // Récupérer les rôles de la manche précédente par UID pour l'anti-répétition
    final Map<String, GameRole> previousRoles = {};
    for (final p in playersMap.values) {
      previousRoles[p.id] = p.trueOriginalRole;
    }

    // Role Pool effectif (salle de dev ou pool par défaut)
    final effectiveRolePool = currentRoom.rolePool.isNotEmpty
        ? currentRoom.rolePool
        : GameNotifier.generateDefaultRolePool(count);

    // Distribution conditionnelle optimisée
    final distribution = ConditionalRoleDistributor.distribute(
      currentPlayers: playersMap,
      rolePool: effectiveRolePool,
      roomCode: roomCode,
      previousRoles: previousRoles,
    );

    final Map<String, dynamic> updatedPlayersMap = {};
    final Map<String, dynamic> secretRolesMap = {};

    distribution.updatedPlayers.forEach((uid, player) {
      final pMap = player.toMap();
      if (!currentRoom.isDevRoom) {
        pMap['role'] = 'masked';
      }
      updatedPlayersMap[uid] = pMap;
      secretRolesMap[uid] = {
        'roleId': player.role.id,
        'roleName': player.role.displayName,
        'assignedAt': ServerValue.timestamp,
      };
    });

    try {
      // 1. Mettre à jour les rôles secrets et la meute chiffrée sur le chemin canonique de la salle
      await _database.ref('rooms/$roomCode/secret_roles').set(secretRolesMap);
      await _database
          .ref('rooms/$roomCode/wolf_pack')
          .set({'data': distribution.encryptedWolfRoster});

      final initialLogs = [
        '🔄 Nouvelle partie lancée ! Le village renaît de ses cendres.',
        'La Nuit 1 tombe... Les rôles secrets ont été redistribués.',
      ];

      // 2. Réinitialiser la salle au lobby
      final Map<String, dynamic> roomResetUpdates = {
        'phase': GamePhase.lobby.name,
        'round': 1,
        'winner': null,
        'players': updatedPlayersMap,
        'seatingOrder': distribution.seatingOrder,
        'replayReadyUserIds': <String>[],
        'replay_votes': null,
        'logs': initialLogs,
        'timerSeconds': 60,
        'captainId': null,
        'nightVictimId': null,
        'witchHealed': false,
        'witchPoisonVictimId': null,
        'seerInspectedTargetId': null,
        'seerInspectedRole': null,
        'morningVictims': <String>[],
        'blackWolfTargetId': null,
        'pendingHunterId': null,
        'pendingCaptainId': null,
        'currentSpeakerId': null,
        'debateQueue': <String>[],
        'tiedPlayerIds': <String>[],
        'isTieBreakActive': false,
        // ── Événements atomiques inclus dans l'update unique ──
        'game_reset_to_lobby': {
          'event': 'game_reset_to_lobby',
          'roomCode': roomCode,
          'playerCount': count,
          'timestamp': ServerValue.timestamp,
        },
        'events/last_event': {
          'type': 'game_reset_to_lobby',
          'roomCode': roomCode,
          'timestamp': ServerValue.timestamp,
        },
      };

      // ── Écriture atomique unique de réinitialisation : rooms/ ──
      await roomRef.update(roomResetUpdates);
      state = state.copyWith(isVictoryVoiceExpired: false);
    } catch (e) {
      debugPrint('[Replay Reset Error] $e');
    }
  }

  Future<void> leaveRoom() async {
    final currentRoom = state.room;
    final userId = state.currentUserId;
    final roomCode = currentRoom?.roomCode;

    try {
      if (currentRoom != null && roomCode != null) {
        final canonicalRef = _database.ref('rooms/$roomCode');

        // ── Annuler les onDisconnect sur le chemin canonique uniquement ──
        try {
          final playerRef = canonicalRef.child('players/$userId');
          await playerRef.child('isOnline').onDisconnect().cancel();
          await playerRef.child('lastSeen').onDisconnect().cancel();
        } catch (_) {}

        if (currentRoom.phase == GamePhase.lobby) {
          // --- SORTIE EN PHASE DE LOBBY ---
          // ── Suppression canonique unique : rooms/$roomCode/players/$userId ──
          await canonicalRef.child('players/$userId').remove();

          // Déterminer les joueurs restants
          final remainingPlayers = currentRoom.players.values
              .where((p) => p.id != userId)
              .toList();

          if (remainingPlayers.isEmpty) {
            // Salon vidé : suppression définitive
            await canonicalRef.remove();
          } else if (currentRoom.hostId == userId) {
            // L'hôte quitte : passation de l'hôte au prochain joueur de la liste
            final nextHost = remainingPlayers.first;
            final updatedLogs = [
              ...currentRoom.logs,
              '🚪 ${state.currentUserName} a quitté le salon.',
              '👑 ${nextHost.name} est devenu le nouvel hôte du village.',
            ];
            // ── Écriture atomique unique (passation + logs) : rooms/$roomCode ──
            await canonicalRef.update({
              'hostId': nextHost.id,
              'players/${nextHost.id}/isHost': true,
              'logs': updatedLogs,
            });
          } else {
            // Joueur normal quittant le lobby
            final updatedLogs = [
              ...currentRoom.logs,
              '🚪 ${state.currentUserName} a quitté le salon.',
            ];
            await canonicalRef.child('logs').set(updatedLogs);
          }
        } else {
          // --- SORTIE EN JEU (IN-GAME) ---
          // Passer isOnline = false et horodater lastSeen pour reprise ultérieure.
          // Si l'hôte quitte, transférer immédiatement l'hôte au prochain joueur en ligne.
          final inGameUpdates = <String, dynamic>{
            'players/$userId/isOnline': false,
            'players/$userId/lastSeen': ServerValue.timestamp,
          };

          if (currentRoom.hostId == userId) {
            final otherOnlinePlayers = currentRoom.players.values
                .where((p) => p.id != userId && p.isOnline)
                .toList()
              ..sort((a, b) => a.id.compareTo(b.id));

            if (otherOnlinePlayers.isNotEmpty) {
              final nextHost = otherOnlinePlayers.first;
              inGameUpdates['hostId'] = nextHost.id;
              inGameUpdates['players/${nextHost.id}/isHost'] = true;
              inGameUpdates['players/$userId/isHost'] = false;
              inGameUpdates['logs'] = [
                ...currentRoom.logs,
                '📡 L\'hôte ${state.currentUserName} a quitté l\'arène en cours de partie.',
                '👑 ${nextHost.name} est désigné(e) comme nouvel hôte pour poursuivre le combat.',
              ];
            } else {
              inGameUpdates['logs'] = [
                ...currentRoom.logs,
                '📡 ${state.currentUserName} s\'est déconnecté(e) (partie en cours).',
              ];
            }
          } else {
            inGameUpdates['logs'] = [
              ...currentRoom.logs,
              '📡 ${state.currentUserName} s\'est déconnecté(e) (partie en cours).',
            ];
          }

          // ── Écriture atomique unique (statut + passation + logs) : rooms/$roomCode ──
          await canonicalRef.update(inGameUpdates);
        }
      }
    } catch (e) {
      debugPrint('[LeaveRoom Error] $e');
    } finally {
      // Libération des flux et du canal Agora
      DeathRegistryService.instance.clearForNewGame();
      _cancelAllRoomSubscriptions();
      _lastAppliedVoiceChannel = null;
      _lastAppliedVoicePhase = null;
      _currentRoomRef = null;
      _phaseExpirationTimer?.cancel();
      _phaseExpirationTimer = null;

      await _voiceService.leaveChannel();
      state = state.copyWith(
        clearRoom: true,
        isVictoryVoiceExpired: false,
        clearFoxSniff: true,
      );
    }
  }

  static String _generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    return List.generate(5, (_) => chars[random.nextInt(chars.length)]).join();
  }

  @override
  void dispose() {
    _phaseExpirationTimer?.cancel();
    _cancelAllRoomSubscriptions();
    _voiceService.dispose();
    super.dispose();
  }
}

final gameNotifierProvider =
    StateNotifierProvider<GameNotifier, LupusGameState>((ref) {
  return GameNotifier();
});

/// Provider isolé pour les utilisateurs qui parlent actuellement
/// Découplé de GameNotifier.state pour supprimer tout re-render de l'écran d'arène
final activeSpeakersProvider = ChangeNotifierProvider<ValueNotifier<Set<int>>>((ref) {
  return AgoraVoiceService().speakingUids;
});

/// Provider pour le statut du micro local
final isMutedProvider = ChangeNotifierProvider<ValueNotifier<bool>>((ref) {
  return AgoraVoiceService().isMuted;
});

/// Provider pour la connexion vocale
final isVoiceConnectedProvider = ChangeNotifierProvider<ValueNotifier<bool>>((ref) {
  return AgoraVoiceService().isConnected;
});
