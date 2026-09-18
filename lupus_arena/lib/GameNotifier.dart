// ignore_for_file: file_names

import 'dart:async';
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'AgoraVoiceService.dart';
import 'models/expanded_roles_state.dart';
import 'models/game_phase.dart';
import 'models/game_room.dart';
import 'models/player_model.dart';
import 'services/expanded_roles_coordinator.dart';
import 'services/role_security_service.dart';
import 'services/server_time_service.dart';

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
  final bool isGodModeActive;
  final bool isOmniscientVoice;
  final String? currentVoiceChannel;
  final Map<String, GameRole> seerInspectedRoles;
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
    this.isGodModeActive = false,
    this.isOmniscientVoice = false,
    this.currentVoiceChannel,
    this.seerInspectedRoles = const {},
    this.wolfPlayerIds = const {},
    this.isVictoryVoiceExpired = false,
  });

  bool get isInGame => room != null;
  bool get isHost => room != null && room!.hostId == currentUserId;
  PlayerModel? get currentPlayer => room?.players[currentUserId];
  bool get isAlive => currentPlayer?.isAlive ?? true;
  GameRole get myRole => currentPlayer?.role ?? GameRole.simpleVillager;
  bool get isCaptain => currentPlayer?.isCaptain ?? false;
  bool get isLover => currentPlayer?.isLover ?? false;
  bool get isSilencedByBlackWolf => currentPlayer?.isMuted == true;
  bool get isWolfVoiceChannel =>
      currentVoiceChannel != null && currentVoiceChannel!.endsWith('_wolves');
  bool get isGodMode => isGodModeActive && (room?.isDevRoom == true);
  bool get canRevealAllRoles =>
      isGodMode || (room?.phase == GamePhase.gameOver);

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
    bool? isGodModeActive,
    bool? isOmniscientVoice,
    String? currentVoiceChannel,
    Map<String, GameRole>? seerInspectedRoles,
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
      isGodModeActive: isGodModeActive ?? this.isGodModeActive,
      isOmniscientVoice: isOmniscientVoice ?? this.isOmniscientVoice,
      currentVoiceChannel: currentVoiceChannel ?? this.currentVoiceChannel,
      seerInspectedRoles: seerInspectedRoles ?? this.seerInspectedRoles,
      wolfPlayerIds: wolfPlayerIds ?? this.wolfPlayerIds,
      isVictoryVoiceExpired:
          isVictoryVoiceExpired ?? this.isVictoryVoiceExpired,
    );
  }
}

/// Moteur de règles canoniques des Loups-Garous de Thiercelieux
class GameNotifier extends StateNotifier<LupusGameState> {
  final AgoraVoiceService _voiceService = AgoraVoiceService();
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
  DatabaseReference? _currentRoomRef;
  String? _lastAppliedVoiceChannel;
  GamePhase? _lastAppliedVoicePhase;
  bool _isTransitioningPhase = false;
  Timer? _phaseExpirationTimer;

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

    // Synchronisation stricte phase <-> currentPhase
    if (updates.containsKey('phase')) {
      final pName = updates['phase'].toString();
      updates['currentPhase'] = pName == GamePhase.dayVoting.name
          ? 'JOUR_VOTE'
          : (pName == GamePhase.dayDebate.name
              ? 'JOUR_DEBAT'
              : (pName == GamePhase.captainSuccession.name
                  ? 'CAPITAINE_SUCCESSION'
                  : pName));
    } else if (updates.containsKey('currentPhase')) {
      final cp = GamePhase.fromString(updates['currentPhase']?.toString());
      updates['phase'] = cp.name;
    }

    // CALCUL DU COMPTE À REBOURS SERVEUR PUR (phaseEndsAt, phaseStartedAt, phaseDurationMs)
    final bool isPhaseChanging = updates.containsKey('phase') || updates.containsKey('currentPhase');
    final bool isTimerUpdating = updates.containsKey('timerSeconds');
    final bool isSpeakerChanging = updates.containsKey('currentSpeakerId');

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
      'blackWolfTargetId',
      'isTieBreakActive',
      'winner',
    ];
    for (final k in publicKeys) {
      if (updates.containsKey(k)) {
        updates['public_state/$k'] = updates[k];
      }
    }

    try {
      // ── ÉCRITURE ATOMIQUE UNIQUE : rooms/$roomCode ──
      // Suppression des miroirs games/$roomCode et rooms/$roomCode/state.
      await _currentRoomRef!.update(updates);
    } catch (e) {
      debugPrint('[Firebase Sync Error] $e');
    }

    if (state.room != null &&
        (updates.containsKey('phase') ||
            updates.containsKey('timerSeconds') ||
            updates.containsKey('currentSpeakerId'))) {
      final updatedPhase = updates.containsKey('phase')
          ? GamePhase.values.firstWhere(
              (p) => p.name == updates['phase'],
              orElse: () => state.room!.phase,
            )
          : state.room!.phase;
      final updatedTimer = updates.containsKey('timerSeconds')
          ? (updates['timerSeconds'] as int)
          : state.room!.timerSeconds;
      final provisionalRoom = state.room!.copyWith(
        phase: updatedPhase,
        timerSeconds: updatedTimer,
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
      );
      state = state.copyWith(room: provisionalRoom);
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

      final initialRolePool = generateDefaultRolePool(4);
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
        isGodModeActive: false,
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

  /// Créer un salon de test / simulation avec 15 joueurs pré-générés et rôles attribués
  Future<bool> createTestRoom() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final roomCode = 'TEST${Random().nextInt(900) + 100}';
      unlockAdmin('03031994');

      final secureRandom = Random.secure();
      final pool = generateDefaultRolePool(15);
      final List<GameRole> flatRoles = [];
      pool.forEach((roleId, qty) {
        final role = GameRole.fromId(roleId);
        for (int i = 0; i < qty; i++) {
          flatRoles.add(role);
        }
      });
      flatRoles.shuffle(secureRandom);
      flatRoles.shuffle(secureRandom); // Double brassage cryptographique

      final botNames = [
        'Arthur',
        'Morgane',
        'Gauvain',
        'Lancelot',
        'Merlin',
        'Perceval',
        'Bohort',
        'Ygraine',
        'Guenièvre',
        'Tristan',
        'Iseult',
        'Viviane',
        'Léodagan',
        'Dagonet',
      ];
      botNames.shuffle(secureRandom);

      final List<String> participantIds = [
        state.currentUserId,
        for (int i = 1; i <= 14; i++) 'bot_$i',
      ];
      participantIds.shuffle(secureRandom);
      final seatingOrder = List<String>.from(participantIds);

      final Map<String, PlayerModel> players = {};
      final List<String> wolfPlayerIds = [];
      final Map<String, dynamic> secretRoles = {};
      String? initialCaptainId;

      final totalJoueurs = participantIds.length;
      final maxPotions = max(1, totalJoueurs ~/ 10);
      final maxVisions = totalJoueurs <= 4
          ? 1
          : totalJoueurs <= 9
              ? 2
              : totalJoueurs <= 14
                  ? 3
                  : totalJoueurs ~/ 4;

      for (int i = 0; i < participantIds.length; i++) {
        final id = participantIds[i];
        final role = flatRoles[i];
        final isLocal = id == state.currentUserId;
        final name = isLocal
            ? '${state.currentUserName} [Admin]'
            : botNames[(i - 1 + botNames.length) % botNames.length];
        final avatar = isLocal ? state.currentUserAvatar : (i % 6);
        final seat = seatingOrder.indexOf(id);
        final isCaptain = (i == 0);
        if (isCaptain) initialCaptainId = id;

        if (role.isEvil) {
          wolfPlayerIds.add(id);
        }

        secretRoles[id] = {
          'roleId': role.id,
          'roleName': role.displayName,
          'assignedAt': ServerValue.timestamp,
        };

        players[id] = PlayerModel(
          id: id,
          name: name,
          avatarIndex: avatar,
          role: role,
          initialRole: role,
          potionsVie: (role == GameRole.witch) ? maxPotions : 0,
          potionsMort: (role == GameRole.witch) ? maxPotions : 0,
          visionsRestantes: (role == GameRole.seer) ? maxVisions : 0,
          isCaptain: isCaptain,
          isHost: isLocal,
          isReady: true,
          isAlive: true,
          seatIndex: seat,
          agoraUid: isLocal ? state.agoraUid : 2000 + i,
        );
      }

        final nowMs = ServerTimeService().currentServerEstimatedTime;
        const initialDurationMs = 25000;

        final newRoom = GameRoom(
        roomCode: roomCode,
        hostId: state.currentUserId,
        phase: GamePhase.nightDefender, // Le Salvateur commence en premier
        round: 1,
        players: players,
        captainId: initialCaptainId ?? 'bot_1',
        rolePool: pool,
        isDevRoom: true,
        seatingOrder: seatingOrder,
        timerSeconds: 25,
        phaseEndsAt: nowMs + initialDurationMs,
        phaseStartedAt: nowMs,
        phaseDurationMs: initialDurationMs,
        logs: [
          'Partie de test Maître du Jeu initialisée (15 joueurs).',
          'Rôles et sièges distribués de manière 100% aléatoire.',
          'La première nuit tombe... Salvateur, réveillez-vous !',
        ],
      );

      try {
        await _database.ref('rooms/$roomCode/secret_roles').set(secretRoles);
        final encryptedWolves =
            RoleSecurityService.encryptWolfRoster(wolfPlayerIds, roomCode);
        await _database
            .ref('rooms/$roomCode/wolf_pack')
            .set({'data': encryptedWolves});
      } catch (e) {
        debugPrint('[Firebase Test Room Error] $e');
      }

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

      try {
        await _voiceService.initialize();
        await _voiceService.joinChannel(
          channelId: 'lupus_$roomCode',
          uid: state.agoraUid,
          userAccount: state.currentUserId,
        );
      } catch (e) {
        _voiceService.addLog('⚠️ Exception vocal test room: $e');
      }

      state = state.copyWith(
        room: newRoom,
        isLoading: false,
        isAdmin: true,
        isGodModeActive: true,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Échec de création du salon test: $e',
      );
      return false;
    }
  }

  /// Remplit le salon actuel avec des Bots configurables et leurs rôles assignés
  Future<bool> populateRoomWithBots({
    int totalCount = 8,
    Map<String, GameRole>? customRoleAssignments,
  }) async {
    if (state.room == null) return false;
    final room = state.room!;
    final botNames = [
      'Arthur', 'Morgane', 'Gauvain', 'Lancelot', 'Merlin',
      'Perceval', 'Bohort', 'Ygraine', 'Guenièvre', 'Tristan',
      'Iseult', 'Viviane', 'Léodagan', 'Dagonet',
    ];
    final secureRandom = Random.secure();
    botNames.shuffle(secureRandom);

    final updates = <String, dynamic>{};
    final currentPlayers = Map<String, PlayerModel>.from(room.players);

    final hostPlayer = currentPlayers[state.currentUserId] ??
        PlayerModel(
          id: state.currentUserId,
          name: state.currentUserName,
          isHost: true,
          isAlive: true,
          isReady: true,
        );

    final newPlayers = <String, PlayerModel>{
      state.currentUserId: hostPlayer,
    };
    final newSeating = <String>[state.currentUserId];

    final botsNeeded = max(3, totalCount - 1);
    for (int i = 1; i <= botsNeeded; i++) {
      final botId = 'bot_$i';
      final assignedRole = customRoleAssignments?[botId] ??
          GameRole.simpleVillager;
      final name = botNames[(i - 1) % botNames.length];
      newPlayers[botId] = PlayerModel(
        id: botId,
        name: '$name (Bot)',
        role: assignedRole,
        initialRole: assignedRole,
        avatarIndex: (i % 6),
        isAlive: true,
        isReady: true,
        seatIndex: i,
        agoraUid: 3000 + i,
      );
      newSeating.add(botId);
    }

    final pool = <String, int>{};
    for (final p in newPlayers.values) {
      pool[p.role.id] = (pool[p.role.id] ?? 0) + 1;
    }

    updates['players'] = newPlayers.map((k, v) => MapEntry(k, v.toMap()));
    updates['seatingOrder'] = newSeating;
    updates['rolePool'] = pool;

    await _syncState(updates);
    return true;
  }

  /// Retire tous les bots du salon actuel
  Future<bool> removeBotsFromRoom() async {
    if (state.room == null) return false;
    final room = state.room!;
    final updates = <String, dynamic>{};
    final remainingPlayers = <String, PlayerModel>{};
    final remainingSeating = <String>[];

    for (final entry in room.players.entries) {
      if (!entry.key.startsWith('bot_')) {
        remainingPlayers[entry.key] = entry.value;
        remainingSeating.add(entry.key);
      }
    }

    final pool = <String, int>{};
    for (final p in remainingPlayers.values) {
      pool[p.role.id] = (pool[p.role.id] ?? 0) + 1;
    }

    updates['players'] = remainingPlayers.map((k, v) => MapEntry(k, v.toMap()));
    updates['seatingOrder'] = remainingSeating;
    updates['rolePool'] = pool;

    await _syncState(updates);
    return true;
  }

  /// Lance immédiatement une vraie partie Sandbox / Testeur avec rôles forcés
  Future<bool> startSandboxGame({
    required Map<String, GameRole> roleAssignments,
    GameRole? hostRole,
    List<GameRole>? thiefExtraCards,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      unlockAdmin('03031994');
      final secureRandom = Random.secure();
      final roomCode = state.room?.roomCode ?? 'SBX${secureRandom.nextInt(900) + 100}';

      final botNames = [
        'Arthur', 'Morgane', 'Gauvain', 'Lancelot', 'Merlin',
        'Perceval', 'Bohort', 'Ygraine', 'Guenièvre', 'Tristan',
        'Iseult', 'Viviane', 'Léodagan', 'Dagonet',
      ];
      botNames.shuffle(secureRandom);

      final Map<String, PlayerModel> players = {};
      final Map<String, dynamic> secretRoles = {};
      final List<String> wolfPlayerIds = [];
      final List<String> seatingOrder = [];

      // 1. Joueur local (Hôte / Admin)
      final actualHostRole = hostRole ?? roleAssignments[state.currentUserId] ?? GameRole.seer;
      seatingOrder.add(state.currentUserId);
      if (actualHostRole.isEvil) {
        wolfPlayerIds.add(state.currentUserId);
      }
      secretRoles[state.currentUserId] = {
        'roleId': actualHostRole.id,
        'roleName': actualHostRole.displayName,
        'assignedAt': ServerValue.timestamp,
      };

      final totalJoueurs = roleAssignments.length;
      final maxPotions = max(1, totalJoueurs ~/ 10);
      final maxVisions = totalJoueurs <= 4 ? 1 : (totalJoueurs <= 9 ? 2 : 3);

      players[state.currentUserId] = PlayerModel(
        id: state.currentUserId,
        name: '${state.currentUserName} [Admin]',
        avatarIndex: state.currentUserAvatar,
        role: actualHostRole,
        initialRole: actualHostRole,
        potionsVie: (actualHostRole == GameRole.witch) ? maxPotions : 0,
        potionsMort: (actualHostRole == GameRole.witch) ? maxPotions : 0,
        visionsRestantes: (actualHostRole == GameRole.seer) ? maxVisions : 0,
        isCaptain: true,
        isHost: true,
        isReady: true,
        isAlive: true,
        seatIndex: 0,
        agoraUid: state.agoraUid,
      );

      // 2. Bots assignés
      int botIndex = 1;
      roleAssignments.forEach((id, role) {
        if (id == state.currentUserId) return;
        final botId = id.startsWith('bot_') ? id : 'bot_$botIndex';
        seatingOrder.add(botId);
        if (role.isEvil) {
          wolfPlayerIds.add(botId);
        }
        secretRoles[botId] = {
          'roleId': role.id,
          'roleName': role.displayName,
          'assignedAt': ServerValue.timestamp,
        };

        final bName = botNames[(botIndex - 1) % botNames.length];
        players[botId] = PlayerModel(
          id: botId,
          name: '$bName (Bot)',
          avatarIndex: (botIndex % 6),
          role: role,
          initialRole: role,
          potionsVie: (role == GameRole.witch) ? maxPotions : 0,
          potionsMort: (role == GameRole.witch) ? maxPotions : 0,
          visionsRestantes: (role == GameRole.seer) ? maxVisions : 0,
          isCaptain: false,
          isHost: false,
          isReady: true,
          isAlive: true,
          seatIndex: seatingOrder.length - 1,
          agoraUid: 3000 + botIndex,
        );
        botIndex++;
      });

      // Role Pool & Cartes Voleur
      final pool = <String, int>{};
      for (final p in players.values) {
        pool[p.role.id] = (pool[p.role.id] ?? 0) + 1;
      }

      final thiefCards = thiefExtraCards ?? [
        GameRole.simpleVillager,
        GameRole.simpleWerewolf,
      ];
      if (players.values.any((p) => p.role == GameRole.thief)) {
        for (final r in thiefCards) {
          pool[r.id] = (pool[r.id] ?? 0) + 1;
        }
      }

      // Première phase nocturne canonique
      final firstPhase = _getNextNightPhase(
        current: GamePhase.lobby,
        round: 1,
        players: players,
      );

      final nowMs = ServerTimeService().currentServerEstimatedTime;
      const initialNightDurationMs = 40000;

      final newRoom = GameRoom(
        roomCode: roomCode,
        hostId: state.currentUserId,
        phase: firstPhase,
        round: 1,
        players: players,
        captainId: state.currentUserId,
        rolePool: pool,
        isDevRoom: true,
        seatingOrder: seatingOrder,
        thiefAvailableRoles: thiefCards,
        timerSeconds: 40,
        phaseEndsAt: nowMs + initialNightDurationMs,
        phaseStartedAt: nowMs,
        phaseDurationMs: initialNightDurationMs,
        logs: [
          'Partie Sandbox Initialisée (${players.length} joueurs).',
          'Rôles configurés manuellement par le Maître du Jeu.',
          'La nuit tombe : ${firstPhase.titleFr}.',
        ],
      );

      await _database.ref('rooms/$roomCode/secret_roles').set(secretRoles);
      if (wolfPlayerIds.isNotEmpty) {
        final encryptedWolves =
            RoleSecurityService.encryptWolfRoster(wolfPlayerIds, roomCode);
        await _database
            .ref('rooms/$roomCode/wolf_pack')
            .set({'data': encryptedWolves});
      }
      await _database.ref('rooms/$roomCode').set(newRoom.toMap());

      await joinRoom(roomCode);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Échec du lancement Sandbox : $e',
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
        // JOUEUR DÉJÀ EXISTANT : RECONNEXION & REMPLACEMENT DU SOCKET
        // Conserve le rôle, le statut de vie et les privilèges du joueur sans dupliquer son entrée
        final updatedPlayer = existingPlayer.copyWith(
          agoraUid: state.agoraUid,
          socketId: currentSocketId,
          name: state.currentUserName,
          avatarIndex: state.currentUserAvatar,
          isOnline: true,
        );

        final playerUpdates = <String, dynamic>{
          'id': state.currentUserId,
          'agoraUid': state.agoraUid,
          'socketId': currentSocketId,
          'name': state.currentUserName,
          'avatarIndex': state.currentUserAvatar,
          'isOnline': true,
          'lastSeen': ServerValue.timestamp,
          'lastReconnectedAt': ServerValue.timestamp,
        };

        final updatedLogs = [
          ...room.logs,
          '🔄 ${state.currentUserName} s\'est reconnecté(e) au salon.',
        ];

        // ── Écriture atomique unique (joueur + logs) : rooms/$cleanCode ──
        await _updateRoomState(cleanCode, {
          'players/${state.currentUserId}': playerUpdates,
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

    final playersList = state.room!.playerList;
    final count = playersList.length;

    if (count < 4 || count > 30) {
      state = state.copyWith(
        errorMessage:
            'La partie nécessite entre 4 et 30 guerriers (actuellement $count).',
      );
      return;
    }

    final pool = state.room!.rolePool;
    final totalChosen = state.room!.totalRolesInPool;

    if (totalChosen != count) {
      state = state.copyWith(
        errorMessage:
            'Le total des rôles ($totalChosen) doit correspondre au nombre de joueurs connectés ($count).',
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
    if (assignedRoleIds.contains('thief')) {
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
      'timerSeconds': 60,
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

        // Si les loups terminent leur phase, calculer et fixer leur cible pour la Voyante et la Sorcière
        if (current == GamePhase.nightWerewolves) {
          String? wolfVictimId = _tallyWerewolfVotes() ?? room.nightVictimId;

          if (wolfVictimId == null) {
            final innocentLiving = room.alivePlayers
                .where((p) => !(realRoles[p.id] ?? p.role).isEvil)
                .toList();
            if (innocentLiving.isNotEmpty) {
              final randomVictim =
                  innocentLiving[Random().nextInt(innocentLiving.length)];
              wolfVictimId = randomVictim.id;
            }
          }

          if (wolfVictimId != null) {
            updates['nightVictimId'] = wolfVictimId;
            // CONFIDENTIALITÉ STRICTE : Ne JAMAIS divulguer l'identité de la victime dans le journal public avant l'Aube !
          }

          // Double action obligatoire : s'assurer qu'une cible de silence est définie
          if (room.blackWolfTargetId == null && room.alivePlayers.length >= 2) {
            final silenceCandidates = room.alivePlayers
                .where((p) => p.id != wolfVictimId)
                .toList();
            if (silenceCandidates.isNotEmpty) {
              final autoSilenceTarget =
                  silenceCandidates[Random().nextInt(silenceCandidates.length)];
              updates['blackWolfTargetId'] = autoSilenceTarget.id;
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
  /// 5: Loup Noir -> 6: Voyante -> 7: Sorcière -> 8: Joueur de Flûte -> 9: Pyromane -> 10: Aube
  GamePhase _getNextNightPhase({
    required GamePhase current,
    required int round,
    required Map<String, PlayerModel> players,
    Map<String, GameRole>? realRoles,
  }) {
    GameRole getRole(PlayerModel p) => realRoles?[p.id] ?? p.role;

    bool hasAlive(GameRole role) =>
        players.values.any((p) => p.isAlive && getRole(p) == role);

    bool hasAliveWerewolves() =>
        players.values.any((p) => p.isAlive && getRole(p).isEvil);

    // ═══════════════════════════════════════════════════════════════
    // RÈGLE CANONIQUE : La Sorcière est active tant qu'elle a AU MOINS
    // une potion restante (vie OU mort). Scalant : max(1, N÷10) potions.
    // Identique à GestionnaireSorciere.aEncoreDesPotions du moteur Kotlin.
    // ═══════════════════════════════════════════════════════════════
    bool hasActiveWitch() {
      final witch = players.values.cast<PlayerModel?>().firstWhere(
            (p) => p != null && p.isAlive && (getRole(p) == GameRole.witch || p.roleInitial == GameRole.witch),
            orElse: () => null,
          );
      if (witch == null) return false;
      // Stock réel des potions (scalant dès startGame via max(1, N÷10))
      final hasVie = witch.potionsVie > 0 && !witch.hasUsedHealPotion;
      final hasMort = witch.potionsMort > 0 && !witch.hasUsedPoisonPotion;
      return hasVie || hasMort;
    }

    GamePhase findNext(int afterIndex) {
      if (afterIndex < 1 && round == 1 && hasAlive(GameRole.thief)) {
        return GamePhase.nightThief;
      }
      if (afterIndex < 2 && round == 1 && hasAlive(GameRole.cupid)) {
        return GamePhase.nightCupid;
      }
      if (afterIndex < 3 && hasAlive(GameRole.defender)) {
        return GamePhase.nightDefender;
      }
      if (afterIndex < 4 && hasAliveWerewolves()) {
        return GamePhase.nightWerewolves;
      }
      // Voyante active UNIQUEMENT si elle a encore des visions restantes (quota scalant)
      bool hasActiveSeer() {
        final seer = players.values.cast<PlayerModel?>().firstWhere(
          (p) => p != null && p.isAlive && (getRole(p) == GameRole.seer || p.roleInitial == GameRole.seer),
          orElse: () => null,
        );
        return seer != null && seer.visionsRestantes > 0;
      }
      if (afterIndex < 6 && hasActiveSeer()) {
        return GamePhase.nightSeer;
      }
      if (afterIndex < 7 && hasActiveWitch()) {
        return GamePhase.nightWitch;
      }
      if (afterIndex < 8 && hasAlive(GameRole.piedPiper)) {
        return GamePhase.nightPiper;
      }
      if (afterIndex < 9 && hasAlive(GameRole.pyromaniac)) {
        return GamePhase.nightPyromaniac;
      }
      return GamePhase.morningAnnouncement;
    }

    final currentIndex = current.nightOrderIndex;
    return findNext(currentIndex);
  }
  }

  Future<void> resolveMorningDeaths() async {
    if (state.room == null) return;

    final room = state.room!;
    if (room.phase == GamePhase.morningAnnouncement ||
        room.phase == GamePhase.dayDebate ||
        room.phase == GamePhase.gameOver) {
      return;
    }
    try {
      final updates = <String, dynamic>{};
      final logs = List<String>.from(room.logs);
      final List<String> effectiveDeaths = [];

      // 1. Victime des Loups
      final wolfVictimId = room.nightVictimId ?? _tallyWerewolfVotes();
      if (wolfVictimId != null) {
        final isProtected = room.currentProtectedPlayerId == wolfVictimId;
        final isHealed = room.witchHealed;

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
      if (room.witchPoisonVictimId != null &&
          !effectiveDeaths.contains(room.witchPoisonVictimId)) {
        effectiveDeaths.add(room.witchPoisonVictimId!);
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
          final cause = (id == room.witchPoisonVictimId)
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
        updates['phase'] = GamePhase.captainSuccession.name;
        updates['pendingCaptainId'] = pendingCaptain;
        updates['timerSeconds'] = 10;
        logs.add('🎖️ Le Capitaine est tombé ! Il dispose de 10s pour nommer son héritier.');
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
    if (room.round == 1 && room.captainId == null) {
      updates['phase'] = GamePhase.captainElection.name;
      updates['timerSeconds'] = 50;
      logs.add(
        '🗳️ Jour 1 : Le village se rassemble pour élire son premier Capitaine !',
      );
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
      updates['phase'] = GamePhase.dayVoting.name;
      updates['currentPhase'] = 'JOUR_VOTE';
      updates['timerSeconds'] = 15;
    }
  }

  // ===========================================================================
  // C. PHASE DIURNE (DÉBAT & VOTE)
  // ===========================================================================

  Future<void> passTurnDebate() async {
    if (state.room == null) return;
    final room = state.room!;
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
      updates['phase'] = GamePhase.dayVoting.name;
      updates['currentPhase'] = 'JOUR_VOTE';
      updates['currentSpeakerId'] = null;
      updates['debateQueue'] = [];
      updates['timerSeconds'] = 15;
      logs.add(
        '⚖️ Les débats sont clos. Scrutin de 15s ouvert pour désigner un suspect au bûcher !',
      );
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

    final updates = <String, dynamic>{
      'phase': GamePhase.dayVoting.name,
      'currentPhase': 'JOUR_VOTE',
      'currentSpeakerId': null,
      'debateQueue': [],
      'timerSeconds': 15,
      'logs': [
        ...room.logs,
        '⚖️ Temps de débat expiré : clôture automatique et ouverture immédiate du scrutin du bûcher (15s) !',
      ],
    };
    _resetAllVotes(updates);
    await _syncState(updates);
  }

  Future<void> processDayVoteResolution() async {
    if (!state.isHost || state.room == null) return;

    final room = state.room!;
    final updates = <String, dynamic>{};
    final logs = List<String>.from(room.logs);

    final voteTally = <String, int>{};
    for (final voter in room.alivePlayers) {
      final target = voter.targetVoteId;
      if (target != null) {
        final weight = voter.isCaptain ? 2 : 1;
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
        '🎖️ Le Capitaine ${captain.name} tranche l\'égalité et condamne ${room.players[deciderTarget]?.name} !',
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
      logs.add(
        '🤪 L\'Idiot du Village ${condemned.name} est gracié par la compassion du village ! Il reste en vie mais perd tout droit de vote.',
      );
      _finishDayCycle(room, updates, logs);
      updates['logs'] = logs;
      await _syncState(updates);
      return;
    }

    updates['players/$condemnedId/isAlive'] = false;
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
      if (p?.isCaptain == true || room.captainId == id) pendingCaptain = id;
    }

    final simulatedRoom = room.copyWith(
      players: room.players.map(
        (k, v) =>
            MapEntry(k, allDeaths.contains(k) ? v.copyWith(isAlive: false) : v),
      ),
    );
    final win = checkWinConditions(simulatedRoom, realRoles);

    if (win != null) {
      updates['phase'] = GamePhase.gameOver.name;
      updates['winner'] = win;
      logs.add(_formatVictoryMessage(win));
      for (final p in room.playerList) {
        final pRole = realRoles[p.id] ?? p.role;
        updates['players/${p.id}/role'] = pRole.id;
      }
    } else if (pendingHunter != null) {
      updates['phase'] = GamePhase.hunterDeathChoice.name;
      updates['pendingHunterId'] = pendingHunter;
      updates['timerSeconds'] = 25;
      logs.add(
        '🎯 Le Chasseur ${room.players[pendingHunter]?.name} s\'effondre et épaule son fusil (25s) !',
      );
    } else if (pendingCaptain != null) {
      updates['phase'] = GamePhase.captainSuccession.name;
      updates['pendingCaptainId'] = pendingCaptain;
      updates['timerSeconds'] = 10;
      logs.add(
        '🎖️ Le Capitaine doit désigner son successeur avant de mourir (10s).',
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
    updates['phase'] = GamePhase.dayResolution.name;
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

    // Condition canonique de victoire des Loups :
    // - Au moins un loup en vie (aliveWolves > 0)
    // - Parité ou supériorité numérique atteinte face aux villageois (aliveWolves >= aliveVillagers)
    // - Aucun rôle solitaire hostile (Loup Blanc, Pyromane) en vie
    final bool wolvesWon = (aliveWolves > 0) && (aliveWolves >= aliveVillagers) && !hasHostileSolo;

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

  // ===========================================================================
  // POUVOIRS ET ACTIONS SPÉCIFIQUES DES JOUEURS
  // ===========================================================================

  Future<void> thiefSteal(String targetPlayerId) async {
    if ((state.myRole != GameRole.thief && !state.isAdmin) ||
        _currentRoomRef == null) {
      return;
    }
    final target = state.room?.players[targetPlayerId];
    if (target == null) return;

    final stolenRole = target.role;
    await _syncState({
      'players/${state.currentUserId}/role': stolenRole.id,
      'players/$targetPlayerId/role': GameRole.simpleVillager.id,
      'logs': [
        ...?state.room?.logs,
        'Une ombre a dérobé l\'identité d\'un citoyen cette nuit...',
      ],
    });
    await processNightTransitions();
  }

  Future<void> thiefChooseRole(GameRole chosenRole) async {
    if ((state.myRole != GameRole.thief && !state.isAdmin) ||
        _currentRoomRef == null) {
      return;
    }
    String thiefId = state.currentUserId;
    if (state.isAdmin && state.myRole != GameRole.thief) {
      final t = state.room?.alivePlayers.cast<PlayerModel?>().firstWhere(
            (p) => p != null && p.role == GameRole.thief,
            orElse: () => null,
          );
      if (t != null) thiefId = t.id;
    }

    final updates = <String, dynamic>{
      'players/$thiefId/role': chosenRole.id,
      'logs': [
        ...?state.room?.logs,
        'Le Voleur a choisi une nouvelle destinée parmi les cartes dissimulées...',
      ],
    };

    if (chosenRole.isEvil) {
      try {
        final wolfIds = state.room?.alivePlayers
            .where((p) => p.role.isEvil || p.id == thiefId)
            .map((p) => p.id)
            .toList() ?? [thiefId];
        final encrypted = RoleSecurityService.encryptWolfRoster(
            wolfIds, state.room!.roomCode);
        updates['encryptedWolfRoster'] = encrypted;
      } catch (_) {}
    }

    await _syncState(updates);
    try {
      await _database
          .ref('rooms/${state.room!.roomCode}/secret_roles/$thiefId/roleId')
          .set(chosenRole.id);
    } catch (_) {}
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

    final realRoles = await _resolveRealRoles(room);
    final seatingOrder = room.seatingOrder.isNotEmpty
        ? room.seatingOrder
        : room.players.keys.toList();
    final aliveIds = seatingOrder.where((id) => room.players[id]?.isAlive == true).toList();

    final hasWolf = ExpandedRolesCoordinator.resolveFoxSniff(
      targetPlayerId: targetPlayerId,
      alivePlayerIdsInOrder: aliveIds,
      playerRoles: realRoles,
      infectedPlayerId: room.expandedRolesState.infectedPlayerId ?? room.infectedPlayerId,
    );

    final updates = <String, dynamic>{};
    final logs = List<String>.from(room.logs);

    if (hasWolf) {
      logs.add('🦊 Le Renard a flairé une odeur suspecte ! Au moins un loup se cache dans le groupe observé.');
    } else {
      logs.add('🦊 Le Renard n\'a rien senti d\'anormal... Son flair s\'éteint à tout jamais.');
    }
    updates['logs'] = logs;
    await _syncState(updates);
    await processNightTransitions();
    return hasWolf;
  }

  Future<void> crowDesignate(String targetPlayerId) async {
    if (state.room == null || _currentRoomRef == null) return;
    final room = state.room!;
    if (state.myRole != GameRole.raven && !state.isAdmin) return;

    final targetName = room.players[targetPlayerId]?.name ?? targetPlayerId;
    final updates = <String, dynamic>{
      'expandedRolesState': room.expandedRolesState.copyWith(crowTargetId: targetPlayerId).toMap(),
      'logs': [
        ...?room.logs,
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
        ...?room.logs,
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
        ...?room.logs,
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
        ...?room.logs,
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
        ...?room.logs,
        '🐐 Dans son dernier souffle, le Bouc Émissaire a privé certains citoyens de leur droit de vote pour le prochain jour.',
      ],
    };
    await _syncState(updates);
  }

  Future<void> actorChooseRole(GameRole chosenRole) async {
    if (state.room == null || _currentRoomRef == null) return;
    final room = state.room!;
    if (state.myRole != GameRole.actor && !state.isAdmin) return;

    final actorId = state.currentUserId;
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
        ...?room.logs,
        '🎭 Le Comédien endosse le costume d\'un nouveau rôle pour la nuit !',
      ],
    };
    await _syncState(updates);
    await processNightTransitions();
  }

  Future<void> executeBotNightAction() async {
    if (state.room == null || !state.isAdmin) return;
    final room = state.room!;
    final phase = room.phase;
    final random = Random();

    switch (phase) {
      case GamePhase.nightThief:
        final choices = room.thiefAvailableRoles;
        if (choices.isNotEmpty) {
          final choice = choices[random.nextInt(choices.length)];
          await thiefChooseRole(choice);
        } else {
          await processNightTransitions();
        }
        break;

      case GamePhase.nightCupid:
        final alive = room.alivePlayers.toList();
        if (alive.length >= 2) {
          alive.shuffle(random);
          await cupidBindLovers(alive[0].id, alive[1].id);
        } else {
          await processNightTransitions();
        }
        break;

      case GamePhase.nightDefender:
        final candidates = room.alivePlayers
            .where((p) => p.id != room.lastProtectedPlayerId)
            .toList();
        if (candidates.isNotEmpty) {
          final target = candidates[random.nextInt(candidates.length)];
          await defenderProtect(target.id);
        } else {
          await processNightTransitions();
        }
        break;

      case GamePhase.nightWerewolves:
        final realRoles = await _resolveRealRoles(room);
        final innocents = room.alivePlayers
            .where((p) => !(realRoles[p.id] ?? p.role).isEvil)
            .toList();
        final victim = innocents.isNotEmpty
            ? innocents[random.nextInt(innocents.length)]
            : room.alivePlayers.first;

        final updates = <String, dynamic>{
          'nightVictimId': victim.id,
        };

        final hasBlackWolf = room.alivePlayers.any(
          (p) => (realRoles[p.id] ?? p.role) == GameRole.blackWolf,
        );
        if (hasBlackWolf && room.alivePlayers.length >= 2) {
          final silenceCandidates =
              room.alivePlayers.where((p) => p.id != victim.id).toList();
          if (silenceCandidates.isNotEmpty) {
            final silenceTarget =
                silenceCandidates[random.nextInt(silenceCandidates.length)];
            updates['blackWolfTargetId'] = silenceTarget.id;
          }
        }

        final hasInfectWolf = room.alivePlayers.any(
          (p) => (realRoles[p.id] ?? p.role) == GameRole.vileFatherOfWolves,
        );
        if (hasInfectWolf && !room.vileFatherInfectionUsed && random.nextBool()) {
          updates['infectedPlayerId'] = victim.id;
        }

        await _syncState(updates);
        await processNightTransitions();
        break;

      case GamePhase.nightSeer:
        final candidates = room.alivePlayers
            .where((p) => p.id != state.currentUserId)
            .toList();
        if (candidates.isNotEmpty) {
          final target = candidates[random.nextInt(candidates.length)];
          await inspectPlayer(target.id);
          await completeSeerTurn();
        } else {
          await processNightTransitions();
        }
        break;

      case GamePhase.nightWitch:
        final victimId = room.nightVictimId;
        final witch = room.alivePlayers.firstWhere(
          (p) => p.role == GameRole.witch,
          orElse: () => room.alivePlayers.first,
        );
        if (victimId != null && witch.potionsVie > 0 && !room.witchHealed) {
          if (random.nextDouble() < 0.7) {
            await witchSaveVictim();
          }
        }
        await processNightTransitions();
        break;

      case GamePhase.nightPiper:
        final uncharmed = room.alivePlayers.where((p) => !p.isCharmed).toList();
        if (uncharmed.isNotEmpty) {
          uncharmed.shuffle(random);
          final toCharm = uncharmed.take(2).map((p) => p.id).toList();
          await piperCharmPlayers(toCharm);
        } else {
          await processNightTransitions();
        }
        break;

      case GamePhase.nightPyromaniac:
        final undoused = room.alivePlayers.where((p) => !p.isDoused).toList();
        final dousedCount = room.alivePlayers.where((p) => p.isDoused).length;
        if (dousedCount >= 2 && random.nextBool()) {
          await pyromaniacIgnite();
        } else if (undoused.isNotEmpty) {
          final target = undoused[random.nextInt(undoused.length)];
          await pyromaniacDouse(target.id);
        } else {
          await pyromaniacPass();
        }
        break;

      default:
        await nextPhase();
        break;
    }
  }

  Future<void> cupidBindLovers(String p1Id, String p2Id) async {
    if ((state.myRole != GameRole.cupid && !state.isAdmin) ||
        _currentRoomRef == null) {
      return;
    }
    if (p1Id == p2Id) return;

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
    final currentLogs = List<String>.from(state.room!.logs);
    currentLogs.add('La Voyante a achevé sa vision nocturne.');
    await _syncState({'logs': currentLogs});
    state = state.copyWith(clearInspectedRole: true);
    await processNightTransitions();
  }

  Future<void> castVote(String? targetId) async {
    if (_currentRoomRef == null || (!state.isAlive && !state.isAdmin)) return;
    if (state.room?.phase == GamePhase.dayVoting &&
        state.room?.expandedRolesState.bannedVotersForToday.contains(state.currentUserId) == true) {
      return;
    }
    final voteUpdates = <String, dynamic>{
      'players/${state.currentUserId}/targetVoteId': targetId,
      'votes/${state.currentUserId}': targetId,
    };

    if (state.room?.phase == GamePhase.nightWerewolves && targetId != null) {
      voteUpdates['nightVictimId'] = targetId;
      voteUpdates['public_state/nightVictimId'] = targetId;
      state = state.copyWith(
        room: state.room?.copyWith(nightVictimId: targetId),
      );
    }
    await _currentRoomRef!.update(voteUpdates);
  }

  /// Intimidation nocturne de la meute : Faire taire un joueur pour toute la journée du lendemain
  Future<bool> werewolfSilence(String targetPlayerId) async {
    if ((!state.myRole.isEvil && !state.isAdmin) || _currentRoomRef == null) {
      return false;
    }
    final target = state.room?.players[targetPlayerId];
    if (target == null || !target.isAlive) {
      return false;
    }
    // Interdiction de cibler la proie déjà dévorée de la nuit (inutile de bâillonner un mort)
    final currentVictimId = state.room?.nightVictimId ?? _tallyWerewolfVotes();
    if (currentVictimId == targetPlayerId) {
      return false;
    }

    // Enregistrement confidentiel du sortilège de silence (divulgué publiquement à l'Aube)
    await _syncState({
      'blackWolfTargetId': targetPlayerId,
    });
    if (state.room != null) {
      state = state.copyWith(
        room: state.room!.copyWith(blackWolfTargetId: targetPlayerId),
      );
    }
    return true;
  }

  Future<void> witchSaveVictim() async {
    if ((state.myRole != GameRole.witch && !state.isAdmin) ||
        _currentRoomRef == null ||
        state.room == null) {
      return;
    }
    final wolfVictimId = state.room!.nightVictimId ?? _tallyWerewolfVotes();
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
    final witchId = (state.myRole == GameRole.witch)
        ? state.currentUserId
        : (witchPlayer?.id ?? state.currentUserId);
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

    await _syncState({
      'witchHealed': true,
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
  }

  Future<void> witchPoison(String targetId) async {
    if ((state.myRole != GameRole.witch && !state.isAdmin) ||
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
    final witchId = (state.myRole == GameRole.witch)
        ? state.currentUserId
        : (witchPlayer?.id ?? state.currentUserId);

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
    await confirmWitchTurn();
  }

  Future<void> hunterShoot(String targetId) async {
    if (_currentRoomRef == null || state.room == null) return;
    final room = state.room!;
    if (room.pendingHunterId != state.currentUserId && !state.isAdmin) return;

    final victim = room.players[targetId];
    if (victim == null || !victim.isAlive) return;

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
      'players/$targetId/role': victimRealRole.id,
      'pendingHunterId': null,
    };
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
    final win = checkWinConditions(simulated, realRoles);
    if (win != null) {
      updates['phase'] = GamePhase.gameOver.name;
      updates['winner'] = win;
      logs.add(_formatVictoryMessage(win));
      for (final p in room.playerList) {
        final pRole = realRoles[p.id] ?? p.role;
        updates['players/${p.id}/role'] = pRole.id;
      }
    } else {
      if (room.pendingCaptainId != null) {
        updates['phase'] = GamePhase.captainSuccession.name;
      } else if (room.morningVictims.isNotEmpty) {
        updates['phase'] = GamePhase.morningAnnouncement.name;
        updates['timerSeconds'] = 20;
      } else {
        _finishDayCycle(room, updates, logs);
      }
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
        !state.isAdmin) {
      return;
    }

    final successor = room.players[successorId];
    if (successor == null || !successor.isAlive) return;

    final updates = <String, dynamic>{
      'captainId': successorId,
      'players/$successorId/isCaptain': true,
      'pendingCaptainId': null,
    };
    // Retirer explicitement l'écharpe et le titre du capitaine défunt
    if (room.captainId != null && room.captainId != successorId) {
      updates['players/${room.captainId}/isCaptain'] = false;
    }
    if (room.pendingCaptainId != null &&
        room.pendingCaptainId != successorId) {
      updates['players/${room.pendingCaptainId}/isCaptain'] = false;
    }

    final logs = List<String>.from(room.logs);
    logs.add(
      '🎖️ Le défunt Capitaine remet son écharpe à ${successor.name}, nouveau chef du village !',
    );

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

    if (room.pendingCaptainId != null) {
      updates['phase'] = GamePhase.captainSuccession.name;
      updates['timerSeconds'] = 10;
      logs.add('🎖️ Le Capitaine a péri ! Il dispose de 10s pour désigner son successeur.');
    } else if (room.morningVictims.isNotEmpty) {
      updates['phase'] = GamePhase.morningAnnouncement.name;
      updates['timerSeconds'] = 20;
    } else {
      _finishDayCycle(room, updates, logs);
    }

    updates['logs'] = logs;
    await _syncState(updates);
  }

  /// Résolution automatique de fin de temps pour le Capitaine (désignation par défaut)
  Future<void> autoResolveCaptainTimeout() async {
    if (_currentRoomRef == null || state.room == null) return;
    final room = state.room!;
    if (room.phase != GamePhase.captainSuccession) return;

    final updates = <String, dynamic>{
      'pendingCaptainId': null,
    };
    final logs = List<String>.from(room.logs);

    final living = room.alivePlayers.toList();
    if (living.isNotEmpty) {
      final successor = living.first;
      updates['captainId'] = successor.id;
      updates['players/${successor.id}/isCaptain'] = true;
      if (room.captainId != null && room.captainId != successor.id) {
        updates['players/${room.captainId}/isCaptain'] = false;
      }
      if (room.pendingCaptainId != null &&
          room.pendingCaptainId != successor.id) {
        updates['players/${room.pendingCaptainId}/isCaptain'] = false;
      }
      logs.add(
        '⏳ Faute de choix du défunt Capitaine, l\'écharpe est transmise d\'office à ${successor.name} !',
      );
    } else {
      logs.add(
        '⏳ Le Capitaine n\'a pas désigné de successeur et aucun survivant ne peut reprendre l\'écharpe.',
      );
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

  Future<void> concludeCaptainElection() async {
    if (!state.isHost || state.room == null) return;
    final room = state.room!;

    final tally = <String, int>{};
    for (final p in room.alivePlayers) {
      if (p.targetVoteId != null) {
        tally[p.targetVoteId!] = (tally[p.targetVoteId!] ?? 0) + 1;
      }
    }

    final updates = <String, dynamic>{};
    final logs = List<String>.from(room.logs);

    if (tally.isNotEmpty) {
      final winnerId = tally.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
      final winnerName = room.players[winnerId]?.name ?? 'Inconnu';
      updates['captainId'] = winnerId;
      updates['players/$winnerId/isCaptain'] = true;
      logs.add(
        '🎖️ $winnerName est élu Capitaine du Village par ses pairs ! Sa voix comptera double.',
      );
    } else {
      final fallback = room.alivePlayers.first.id;
      updates['captainId'] = fallback;
      updates['players/$fallback/isCaptain'] = true;
      logs.add(
        '🎖️ ${room.players[fallback]?.name} est désigné Capitaine d\'office.',
      );
    }

    _resetAllVotes(updates);

    // Le Capitaine est définitivement élu : passage direct au débat du Jour 1
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
      updates['phase'] = GamePhase.dayVoting.name;
      updates['currentPhase'] = 'JOUR_VOTE';
      updates['timerSeconds'] = 15;
    }

    updates['logs'] = logs;
    await _syncState(updates);
  }

  Future<void> nextPhase() async {
    if (state.room == null) return;
    if (_isTransitioningPhase) {
      debugPrint('[nextPhase] Transition déjà en cours, appel ignoré.');
      return;
    }
    final phase = state.room!.phase;

    final canAdvanceNight = phase.isNight &&
        (state.isHost ||
            state.isAdmin ||
            (phase == GamePhase.nightWerewolves &&
                (state.myRole.isEvil || state.isAdmin)) ||
            (phase == GamePhase.nightSeer &&
                (state.myRole == GameRole.seer || state.isAdmin)) ||
            (phase == GamePhase.nightWitch &&
                (state.myRole == GameRole.witch || state.isAdmin)) ||
            (phase == GamePhase.nightDefender &&
                (state.myRole == GameRole.defender || state.isAdmin)) ||
            (phase == GamePhase.nightCupid &&
                (state.myRole == GameRole.cupid || state.isAdmin)) ||
            (phase == GamePhase.nightThief &&
                (state.myRole == GameRole.thief || state.isAdmin)) ||
            (phase == GamePhase.nightPyromaniac &&
                (state.myRole == GameRole.pyromaniac || state.isAdmin)) ||
            (phase == GamePhase.nightPiper &&
                (state.myRole == GameRole.piedPiper || state.isAdmin)) ||
            (phase == GamePhase.nightBlackWolf &&
                (state.myRole == GameRole.blackWolf || state.isAdmin)));

    if (!state.isHost && !state.isAdmin && !canAdvanceNight) return;

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
    } else if (phase == GamePhase.morningAnnouncement) {
      final room = state.room!;
      final realRoles = await _resolveRealRoles(room);
      final win = checkWinConditions(room, realRoles);

      final updates = <String, dynamic>{};
      final logs = List<String>.from(room.logs);

      if (win != null) {
        updates['phase'] = GamePhase.gameOver.name;
        updates['winner'] = win;
        logs.add(_formatVictoryMessage(win));
        for (final p in room.playerList) {
          final revealedRole = realRoles[p.id] ?? p.role;
          updates['players/${p.id}/role'] = revealedRole.id;
        }
      } else {
        _routeToDayPhase(room, updates, logs);
      }
      updates['logs'] = logs;
      await _syncState(updates);
    } else if (phase == GamePhase.captainElection) {
      await concludeCaptainElection();
    } else if (phase == GamePhase.hunterDeathChoice) {
      await autoResolveHunterTimeout();
    } else if (phase == GamePhase.captainSuccession) {
      await autoResolveCaptainTimeout();
    } else if (phase == GamePhase.dayDebate) {
      // Expiration du timer global du débat : clôture immédiate et bascule automatique sur dayVote (JOUR_VOTE)
      await endDebateAndOpenVote();
    } else if (phase == GamePhase.dayVoting ||
        phase == GamePhase.dayTieBreakVote) {
      await processDayVoteResolution();
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
        'witchHealed': false,
        'witchPoisonVictimId': null,
        'seerInspectedTargetId': null,
        'seerInspectedRole': null,
        'blackWolfTargetId': null,
        'timerSeconds': 45,
        'logs': [
          ...?state.room?.logs,
          '🌑 La nuit $nextRound recouvre le village. Les habitants s\'endorment.',
        ],
      };
      // Rétablir la parole pour les joueurs réduits au silence par le Loup Noir
      for (final p in state.room!.players.values) {
        if (p.isMuted) {
          updates['players/${p.id}/isMuted'] = false;
        }
      }
      _resetAllVotes(updates);
      await _syncState(updates);
    }
  }

  // ===========================================================================
  // UTILITAIRES ET INTÉGRATION VOCALE AGORA
  // ===========================================================================

  String? _tallyWerewolfVotes() {
    if (state.room == null) return null;
    final votes = <String, int>{};
    for (final p in state.room!.alivePlayers) {
      if ((p.role.isEvil || (p.id == state.currentUserId && state.isAdmin)) &&
          p.targetVoteId != null) {
        votes[p.targetVoteId!] = (votes[p.targetVoteId!] ?? 0) + 1;
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
      if (isOnline != null) 'isOnline': isOnline,
      if (isMuted != null) 'isMuted': isMuted,
      if (micVolume != null) 'micVolume': micVolume,
      if (isSpeaking != null) 'isSpeaking': isSpeaking,
      'lastSeen': ServerValue.timestamp,
    };
    try {
      await _currentRoomRef!
          .child('presence/${state.currentUserId}')
          .update(presenceUpdates);
    } catch (_) {}
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

      // GARDE MONOTONE STRICT : Empêcher toute régression nocturne
      if (state.room!.round == (data['round'] ?? state.room!.round) &&
          state.room!.phase.isNight &&
          parsedPhase.isNight &&
          parsedPhase.nightOrderIndex < state.room!.phase.nightOrderIndex) {
        debugPrint(
          '[Monotonic Guard] Régression nocturne bloquée sur public_state : ${state.room!.phase.name} -> ${parsedPhase.name}',
        );
        return;
      }

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
        nightVictimId:
            data['nightVictimId']?.toString() ?? state.room!.nightVictimId,
        witchHealed: data['witchHealed'] == true,
        witchPoisonVictimId: data['witchPoisonVictimId']?.toString() ??
            state.room!.witchPoisonVictimId,
        blackWolfTargetId:
            data['blackWolfTargetId']?.toString() ?? state.room!.blackWolfTargetId,
        winner: data['winner']?.toString() ?? state.room!.winner,
        isTieBreakActive: data['isTieBreakActive'] == true,
      );

      state = state.copyWith(room: updatedRoom);
      _applyVoiceRulesForPhase(updatedRoom);
      _syncPhaseExpirationSchedule(updatedRoom);
    });

    // Écoute dédiée sur currentPhase pour compatibilité temps réel immédiate
    _currentPhaseSubscription =
        _currentRoomRef?.child('currentPhase').onValue.listen((event) {
      final rawPhase = event.snapshot.value?.toString();
      if (rawPhase != null && state.room != null) {
        final parsed = GamePhase.fromString(rawPhase);
        if (state.room!.phase != parsed) {
          if (state.room!.phase.isNight &&
              parsed.isNight &&
              parsed.nightOrderIndex < state.room!.phase.nightOrderIndex) {
            return;
          }
          final updatedRoom = state.room!.copyWith(phase: parsed);
          state = state.copyWith(room: updatedRoom);
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
      }

      final updatedRoom = state.room!.copyWith(players: parsedPlayers);
      state = state.copyWith(room: updatedRoom);

      // Dépouillement anticipé dès que tous les vivants ont voté pendant dayVoting
      final aliveCount = updatedRoom.alivePlayers.length;
      final votedCount =
          updatedRoom.alivePlayers.where((p) => p.targetVoteId != null).length;
      if (state.isHost &&
          updatedRoom.phase == GamePhase.dayVoting &&
          votedCount >= aliveCount &&
          aliveCount > 0) {
        processDayVoteResolution();
      }
    });

    // 4. ── SOUSCRIPTION GRANULAIRE : votes (table dynamique des votes du tour) ──
    _votesSubscription =
        _currentRoomRef?.child('votes').onValue.listen((event) {
      if (state.room == null) return;
      final rawVotes = event.snapshot.value;
      if (rawVotes is Map) {
        final updatedPlayers =
            Map<String, PlayerModel>.from(state.room!.players);
        bool hasChanges = false;
        rawVotes.forEach((voterId, targetId) {
          final vid = voterId.toString();
          final tid = targetId?.toString();
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

          final aliveCount = updatedRoom.alivePlayers.length;
          final votedCount = updatedRoom.alivePlayers
              .where((p) => p.targetVoteId != null)
              .length;
          if (state.isHost &&
              updatedRoom.phase == GamePhase.dayVoting &&
              votedCount >= aliveCount &&
              aliveCount > 0) {
            processDayVoteResolution();
          }
        }
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
        final isGodMode =
            state.isGodModeActive && (state.room?.isDevRoom == true);
        if (isMeWolf || isGodMode) {
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
        }
      }
    });

    // 10. Écouter game_reset_to_lobby
    _gameResetSubscription = _database
        .ref('rooms/$roomCode/game_reset_to_lobby')
        .onValue
        .listen((event) {
      if (event.snapshot.value != null && state.room != null) {
        state = state.copyWith(isVictoryVoiceExpired: false);
      }
    });
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
        state = state.copyWith(wolfPlayerIds: wolfIds);
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
    String? pendingHunterId,
    String? pendingCaptainId,
    String? currentUserId,
  }) {
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

    // 4. Règles spécifiques par phase
    switch (phase) {
      case GamePhase.nightWerewolves:
        return !isEvil;
      case GamePhase.dayDebate:
      case GamePhase.dayDefense:
        return !isCurrentSpeaker;
      case GamePhase.dayVoting:
      case GamePhase.dayTieBreakVote:
      case GamePhase.dayResolution:
      case GamePhase.captainElection:
      case GamePhase.morningAnnouncement:
      case GamePhase.lobby:
        return false;
      case GamePhase.hunterDeathChoice:
        return pendingHunterId != currentUserId;
      case GamePhase.captainSuccession:
        return pendingCaptainId != currentUserId;
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

    if (!me.isAlive && room.phase != GamePhase.gameOver) {
      await _voiceService.setMute(true);
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
      pendingHunterId: room.pendingHunterId,
      pendingCaptainId: room.pendingCaptainId,
      currentUserId: state.currentUserId,
    );

    await _voiceService.setMute(shouldMute);

    // Contrôle du haut-parleur (muteSpeaker) :
    // Pendant la nuit des loups, couper le flux entrant pour tous les non-loups (!isWolf)
    // Sauf si la petite fille espionne. Pour tous les autres cas/phases, réactiver l'audio.
    if (room.phase == GamePhase.nightWerewolves && !isWolf && !canSpy) {
      await _voiceService.muteSpeaker(true);
    } else {
      await _voiceService.muteSpeaker(false);
    }
  }

  // ==========================================
  // --- PANNEAU MAÎTRE DU JEU (GOD MODE / ADMIN) ---
  // ==========================================

  bool unlockAdmin(String pin) {
    if (pin.trim() == '03031994') {
      state = state.copyWith(isAdmin: true, isGodModeActive: true);
      return true;
    }
    return false;
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
          '🔇 [GOD MODE] $mutedName est bâillonné ! Son tour de parole est sauté.',
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

    // En God Mode : si le joueur bâillonné avait la parole pendant le débat, on saute immédiatement son tour
    if (newMuted &&
        state.room?.phase == GamePhase.dayDebate &&
        state.room?.currentSpeakerId == playerId) {
      await passTurnDebate();
    }
  }

  /// God Mode : Forcer ou réinitialiser la proie nocturne des loups
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

  /// God Mode : Forcer ou réinitialiser la cible de silence nocturne des loups
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
        '[ADMIN] ${target.name} a été proclamé(e) Capitaine par le Maître du Jeu.';
    updates['logs'] = List<String>.from(state.room!.logs)..insert(0, log);

    await _syncState(updates);
  }

  Future<void> adminForceRole(String playerId, GameRole role) async {
    if (_currentRoomRef == null || state.room == null) return;
    final target = state.room!.players[playerId];
    if (target == null) return;

    final log =
        '[ADMIN] Rôle de ${target.name} changé en : ${role.displayName}';
    final currentLogs = List<String>.from(state.room!.logs)..insert(0, log);

    await _syncState({'players/$playerId/role': role.id, 'logs': currentLogs});

    if (playerId == state.currentUserId && state.room != null) {
      final updatedRoom = state.room!.copyWith(
        players: {
          ...state.room!.players,
          playerId: target.copyWith(role: role),
        },
      );
      state = state.copyWith(room: updatedRoom);
      await _applyVoiceRulesForPhase(updatedRoom);
    }
  }

  Future<void> adminToggleOmniscientVoice() async {
    if (state.room == null) return;
    final newOmniscient = !state.isOmniscientVoice;
    state = state.copyWith(isOmniscientVoice: newOmniscient);

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

  /// Gestion du vote client : Au premier clic, émettre player_ready_replay avec userId et roomId
  Future<void> playerReadyReplay({String? userId, String? roomId}) async {
    final effectiveUserId = userId ?? state.currentUserId;
    final effectiveRoomId = roomId ?? state.room?.roomCode;
    if (effectiveRoomId == null || effectiveRoomId.isEmpty) return;

    try {
      final roomRef = _database.ref('rooms/$effectiveRoomId');

      // 1. Ajouter userId à la liste des joueurs prêts pour le replay
      final snapshot = await roomRef.child('replayReadyUserIds').get();
      List<String> readyList = [];
      if (snapshot.value is List) {
        readyList = (snapshot.value as List).map((e) => e.toString()).toList();
      }
      if (!readyList.contains(effectiveUserId)) {
        readyList.add(effectiveUserId);
      }

      final totalCount = state.room?.playerList.length ?? 0;
      final readyCount = readyList.length;

      // 2. Mettre à jour Firebase de manière atomique
      await roomRef.update({
        'replayReadyUserIds': readyList,
        'players/$effectiveUserId/isReadyReplay': true,
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
              updatedPlayers[effectiveUserId]!.copyWith(isReadyReplay: true);
        }
        state = state.copyWith(
          room: state.room!.copyWith(
            replayReadyUserIds: readyList,
            players: updatedPlayers,
          ),
        );
      }

      // 3. Vérification du quorum : dès que tous les joueurs (ou le quorum) sont prêts,
      // le serveur réinitialise la partie et redistribue les rôles
      if (totalCount > 0 && readyCount >= totalCount) {
        await resetGameAndRedistributeRoles(effectiveRoomId);
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

      final snapshot = await roomRef.child('replayReadyUserIds').get();
      List<String> readyList = [];
      if (snapshot.value is List) {
        readyList = (snapshot.value as List).map((e) => e.toString()).toList();
      }
      readyList.remove(effectiveUserId);

      final totalCount = state.room?.playerList.length ?? 0;
      final readyCount = readyList.length;

      // ── Mise à jour atomique unique : rooms/$effectiveRoomId ──
      await roomRef.update({
        'replayReadyUserIds': readyList,
        'players/$effectiveUserId/isReadyReplay': false,
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
              updatedPlayers[effectiveUserId]!.copyWith(isReadyReplay: false);
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

  /// Réinitialise la salle pour une nouvelle partie (Rejouer) avec nouvelle attribution des rôles
  Future<void> resetGameAndRedistributeRoles(String roomCode) async {
    try {
      final roomRef = _database.ref('rooms/$roomCode');
      final snapshot = await roomRef.get();
      if (!snapshot.exists || snapshot.value == null) return;

      final data = snapshot.value as Map<dynamic, dynamic>;
      final playersData = data['players'] as Map<dynamic, dynamic>? ?? {};
      final playerIds = playersData.keys.map((k) => k.toString()).toList();
      final count = playerIds.length;

      if (count < 4) return;

      // 1. Génération et mélange aléatoire des rôles
      final flatRoles = generateDefaultRolePool(count);
      final List<GameRole> rolesList = [];
      flatRoles.forEach((roleId, qty) {
        final role = GameRole.fromId(roleId);
        for (int i = 0; i < qty; i++) {
          rolesList.add(role);
        }
      });
      final secureRandom = Random.secure();
      rolesList.shuffle(secureRandom);
      rolesList.shuffle(secureRandom);

      // 2. Nouveau placement aléatoire des sièges
      final seatingOrder = List<String>.from(playerIds)..shuffle(secureRandom);

      // 3. Préparation des rôles secrets et des joueurs réinitialisés
      final Map<String, dynamic> secretRoles = {};
      final List<String> wolfPlayerIds = [];
      final Map<String, dynamic> updatedPlayers = {};

      for (int i = 0; i < playerIds.length; i++) {
        final pid = playerIds[i];
        final assignedRole = rolesList[i];
        final seatIdx = seatingOrder.indexOf(pid);

        if (assignedRole.isEvil) {
          wolfPlayerIds.add(pid);
        }

        secretRoles[pid] = {
          'roleId': assignedRole.id,
          'roleName': assignedRole.displayName,
          'assignedAt': ServerValue.timestamp,
        };

        final existingMap = Map<String, dynamic>.from(
          playersData[pid] as Map<dynamic, dynamic>? ?? {},
        );

        updatedPlayers[pid] = {
          ...existingMap,
          'role': 'masked',
          'isAlive': true,
          'isReady': true,
          'isReadyReplay': false,
          'targetVoteId': null,
          'isCaptain': false,
          'isLover': false,
          'loverId': null,
          'isCharmed': false,
          'isDoused': false,
          'hasUsedHealPotion': false,
          'hasUsedPoisonPotion': false,
          'seatIndex': seatIdx,
        };
      }

      // 4. Écriture des rôles secrets et de la meute
      await _database.ref('rooms/$roomCode/secret_roles').set(secretRoles);
      if (wolfPlayerIds.isNotEmpty) {
        final encryptedWolves =
            RoleSecurityService.encryptWolfRoster(wolfPlayerIds, roomCode);
        await _database
            .ref('rooms/$roomCode/wolf_pack')
            .set({'data': encryptedWolves});
      }

      // 5. Réinitialisation complète du salon avec événements atomiques intégrés
      final initialLogs = [
        '🔄 Nouvelle partie lancée ! Le village renaît de ses cendres.',
        'La Nuit 1 tombe... Les rôles secrets ont été redistribués.',
      ];

      final roomResetUpdates = <String, dynamic>{
        'phase': GamePhase.nightDefender.name,
        'currentPhase': GamePhase.nightDefender.name,
        'round': 1,
        'winner': null,
        'players': updatedPlayers,
        'seatingOrder': seatingOrder,
        'replayReadyUserIds': <String>[],
        'logs': initialLogs,
        'timerSeconds': 30,
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

      // ── Écriture atomique unique de réinitialisation : rooms/$roomCode ──
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
          // ── Écriture atomique unique (statut + logs) : rooms/$roomCode ──
          await canonicalRef.update({
            'players/$userId/isOnline': false,
            'players/$userId/lastSeen': ServerValue.timestamp,
            'logs': [
              ...currentRoom.logs,
              '📡 ${state.currentUserName} s\'est déconnecté(e) (partie en cours).',
            ],
          });
        }
      }
    } catch (e) {
      debugPrint('[LeaveRoom Error] $e');
    } finally {
      // Libération des flux et du canal Agora
      _cancelAllRoomSubscriptions();
      _lastAppliedVoiceChannel = null;
      _lastAppliedVoicePhase = null;
      _currentRoomRef = null;
      _phaseExpirationTimer?.cancel();
      _phaseExpirationTimer = null;

      await _voiceService.leaveChannel();
      state = state.copyWith(clearRoom: true, isVictoryVoiceExpired: false);
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
