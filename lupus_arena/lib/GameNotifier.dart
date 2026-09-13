// ignore_for_file: file_names

import 'dart:async';
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'AgoraVoiceService.dart';
import 'models/game_phase.dart';
import 'models/game_room.dart';
import 'models/player_model.dart';

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
  final bool isOmniscientVoice;
  final String? currentVoiceChannel;

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
    this.isOmniscientVoice = false,
    this.currentVoiceChannel,
  });

  bool get isInGame => room != null;
  bool get isHost => room != null && room!.hostId == currentUserId;
  PlayerModel? get currentPlayer => room?.players[currentUserId];
  bool get isAlive => currentPlayer?.isAlive ?? true;
  GameRole get myRole => currentPlayer?.role ?? GameRole.simpleVillager;
  bool get isCaptain => currentPlayer?.isCaptain ?? false;
  bool get isLover => currentPlayer?.isLover ?? false;
  bool get isWolfVoiceChannel =>
      currentVoiceChannel != null && currentVoiceChannel!.endsWith('_wolves');
  String? get loverName {
    if (!isLover || currentPlayer?.loverId == null || room == null) return null;
    return room!.players[currentPlayer!.loverId!]?.name;
  }

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
    bool? isOmniscientVoice,
    String? currentVoiceChannel,
    bool clearRoom = false,
  }) {
    return LupusGameState(
      currentUserId: currentUserId ?? this.currentUserId,
      currentUserName: currentUserName ?? this.currentUserName,
      currentUserAvatar: currentUserAvatar ?? this.currentUserAvatar,
      agoraUid: agoraUid ?? this.agoraUid,
      room: clearRoom ? null : (room ?? this.room),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      inspectedRole: inspectedRole ?? this.inspectedRole,
      speakingAgoraUids: speakingAgoraUids ?? this.speakingAgoraUids,
      isVoiceConnected: isVoiceConnected ?? this.isVoiceConnected,
      isMuted: isMuted ?? this.isMuted,
      isAdmin: isAdmin ?? this.isAdmin,
      isOmniscientVoice: isOmniscientVoice ?? this.isOmniscientVoice,
      currentVoiceChannel: currentVoiceChannel ?? this.currentVoiceChannel,
    );
  }
}

/// Moteur de règles canoniques des Loups-Garous de Thiercelieux
class GameNotifier extends StateNotifier<LupusGameState> {
  final AgoraVoiceService _voiceService = AgoraVoiceService();
  StreamSubscription<DatabaseEvent>? _roomSubscription;
  DatabaseReference? _currentRoomRef;

  GameNotifier()
      : super(
          LupusGameState(
            currentUserId: _generateUniqueId(),
            currentUserName: 'Guerrier_${Random().nextInt(900) + 100}',
            currentUserAvatar: Random().nextInt(6),
            agoraUid: Random().nextInt(899999) + 100000,
          ),
        ) {
    _voiceService.speakingUids.addListener(() {
      if (mounted) {
        state = state.copyWith(
          speakingAgoraUids: _voiceService.speakingUids.value,
        );
      }
    });
    _voiceService.isConnected.addListener(() {
      if (mounted) {
        state = state.copyWith(
          isVoiceConnected: _voiceService.isConnected.value,
        );
      }
    });
    _voiceService.isMuted.addListener(() {
      if (mounted) {
        state = state.copyWith(isMuted: _voiceService.isMuted.value);
      }
    });
    _voiceService.currentChannel.addListener(() {
      if (mounted) {
        state = state.copyWith(
          currentVoiceChannel: _voiceService.currentChannel.value,
        );
      }
    });
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
    state = state.copyWith(
      currentUserName: name ?? state.currentUserName,
      currentUserAvatar: avatarIndex ?? state.currentUserAvatar,
    );
  }

  /// Synchronise l'état atomiquement sur Firebase (rooms et games)
  Future<void> _syncState(Map<String, dynamic> updates) async {
    if (_currentRoomRef == null) return;
    try {
      await _currentRoomRef!.update(updates);
      if (state.room != null) {
        final roomCode = state.room!.roomCode;
        await _database.ref('rooms/$roomCode/state').update(updates);
      }
    } catch (e) {
      debugPrint('[Firebase Sync Error] $e');
    }

    if (state.room != null &&
        (updates.containsKey('phase') ||
            updates.containsKey('currentSpeakerId'))) {
      final updatedPhase = updates.containsKey('phase')
          ? GamePhase.values.firstWhere(
              (p) => p.name == updates['phase'],
              orElse: () => state.room!.phase,
            )
          : state.room!.phase;
      final provisionalRoom = state.room!.copyWith(
        phase: updatedPhase,
        currentSpeakerId: updates.containsKey('currentSpeakerId')
            ? updates['currentSpeakerId']
            : state.room!.currentSpeakerId,
      );
      await _applyVoiceRulesForPhase(provisionalRoom);
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
        agoraUid: state.agoraUid,
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

      _currentRoomRef = _database.ref('games/$roomCode');
      await _currentRoomRef!.set(newRoom.toMap());
      await _database.ref('rooms/$roomCode/state').set(newRoom.toMap());

      _subscribeToRoom(roomCode);

      await _voiceService.initialize();
      await _voiceService.joinChannel(
        channelId: 'lupus_$roomCode',
        uid: state.agoraUid,
      );

      state = state.copyWith(room: newRoom, isLoading: false);
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

      final botData = [
        ('Arthur (Maire)', GameRole.simpleVillager, 0, true),
        ('Morgane', GameRole.simpleWerewolf, 1, false),
        ('Gauvain', GameRole.simpleWerewolf, 2, false),
        ('Lancelot', GameRole.hunter, 3, false),
        ('Merlin', GameRole.witch, 4, false),
        ('Perceval', GameRole.defender, 5, false),
        ('Bohort', GameRole.cupid, 6, false),
        ('Ygraine', GameRole.littleGirl, 7, false),
        ('Guenièvre', GameRole.simpleVillager, 8, false),
        ('Tristan', GameRole.twoSisters, 9, false),
        ('Iseult', GameRole.twoSisters, 0, false),
        ('Viviane', GameRole.fox, 1, false),
        ('Léodagan', GameRole.elder, 2, false),
        ('Dagonet', GameRole.idiot, 3, false),
      ];

      final Map<String, PlayerModel> players = {};
      final adminPlayer = PlayerModel(
        id: state.currentUserId,
        name: '${state.currentUserName} [Admin]',
        avatarIndex: state.currentUserAvatar,
        role: GameRole.seer,
        isHost: true,
        isReady: true,
        isAlive: true,
        agoraUid: state.agoraUid,
      );
      players[state.currentUserId] = adminPlayer;

      for (int i = 0; i < botData.length; i++) {
        final b = botData[i];
        final bId = 'bot_${i + 1}';
        players[bId] = PlayerModel(
          id: bId,
          name: b.$1,
          avatarIndex: b.$3,
          role: b.$2,
          isCaptain: b.$4,
          isHost: false,
          isReady: true,
          isAlive: true,
          agoraUid: 2000 + i + 1,
        );
      }

      final newRoom = GameRoom(
        roomCode: roomCode,
        hostId: state.currentUserId,
        phase: GamePhase.nightDefender, // Le Salvateur commence en premier
        round: 1,
        players: players,
        captainId: 'bot_1',
        rolePool: generateDefaultRolePool(15),
        logs: [
          'Partie de test Maître du Jeu initialisée (15 joueurs).',
          'Arthur (Maire) est le Capitaine du village.',
          'La première nuit tombe... Salvateur, réveillez-vous !',
        ],
      );

      _currentRoomRef = _database.ref('games/$roomCode');
      await _currentRoomRef!.set(newRoom.toMap());
      await _database.ref('rooms/$roomCode/state').set(newRoom.toMap());

      _subscribeToRoom(roomCode);

      try {
        await _voiceService.initialize();
        await _voiceService.joinChannel(
          channelId: 'lupus_$roomCode',
          uid: state.agoraUid,
        );
      } catch (e) {
        _voiceService.addLog('⚠️ Exception vocal test room: $e');
      }

      state = state.copyWith(room: newRoom, isLoading: false, isAdmin: true);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Échec de création du salon test: $e',
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
      final ref = _database.ref('games/$cleanCode');
      final snapshot = await ref.get();

      if (!snapshot.exists || snapshot.value == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Salon introuvable. Vérifiez le code.',
        );
        return false;
      }

      final data = snapshot.value as Map<dynamic, dynamic>;
      final room = GameRoom.fromMap(data, cleanCode);

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
        agoraUid: state.agoraUid,
      );

      await ref.child('players/${state.currentUserId}').set(player.toMap());
      await ref.child('logs').set([
        ...room.logs,
        '${state.currentUserName} a rejoint le village.',
      ]);

      _currentRoomRef = ref;
      _subscribeToRoom(cleanCode);

      await _voiceService.initialize();
      await _voiceService.joinChannel(
        channelId: 'lupus_$cleanCode',
        uid: state.agoraUid,
      );

      state = state.copyWith(room: room, isLoading: false);
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
      await _currentRoomRef!.child('rolePool').set(currentPool);
      await _currentRoomRef!.child('config/rolePool').set(currentPool);
      await _database.ref('rooms/$roomCode/config/rolePool').set(currentPool);
      await _database.ref('rooms/$roomCode/state/rolePool').set(currentPool);
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

    flatRoles.shuffle(Random());
    final shuffledPlayers = List<PlayerModel>.from(playersList)
      ..shuffle(Random());

    final Map<String, dynamic> updatedPlayers = {};
    final Map<String, dynamic> secretRoles = {};

    for (int i = 0; i < shuffledPlayers.length; i++) {
      final p = shuffledPlayers[i];
      final assignedRole = flatRoles[i];
      final updatedP = p.copyWith(
        role: assignedRole,
        isAlive: true,
        targetVoteId: null,
        isCaptain: false,
        isLover: false,
        loverId: null,
      );
      updatedPlayers[p.id] = updatedP.toMap();
      secretRoles[p.id] = {
        'roleId': assignedRole.id,
        'roleName': assignedRole.displayName,
        'assignedAt': ServerValue.timestamp,
      };
    }

    final roomCode = state.room!.roomCode;
    try {
      await _database.ref('rooms/$roomCode/secret_roles').set(secretRoles);
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
      'captainId': null,
      'lastProtectedPlayerId': null,
      'currentProtectedPlayerId': null,
      'nightVictimId': null,
      'witchHealed': false,
      'witchPoisonVictimId': null,
      'seerInspectedTargetId': null,
      'seerInspectedRole': null,
      'morningVictims': [],
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
    if (!state.isHost || state.room == null) return;

    final room = state.room!;
    final current = room.phase;
    final round = room.round;

    final next = _getNextNightPhase(
      current: current,
      round: round,
      players: room.players,
    );

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
        String? wolfVictimId = _tallyWerewolfVotes();

        if (wolfVictimId == null) {
          final innocentLiving = room.alivePlayers
              .where((p) => !p.role.isEvil)
              .toList();
          if (innocentLiving.isNotEmpty) {
            final randomVictim =
                innocentLiving[Random().nextInt(innocentLiving.length)];
            wolfVictimId = randomVictim.id;
          }
        }

        if (wolfVictimId != null) {
          updates['nightVictimId'] = wolfVictimId;
          final victim = room.players[wolfVictimId];
          final victimName = victim?.name ?? 'Un villageois';
          logs.add(
            '🐺 Les Loups-Garous ont choisi leur victime dans l\'ombre : $victimName.',
          );
        }
        _resetAllVotes(updates);
      }

      await _syncState(updates);
    }
  }

  /// Ordre choisi : Salvateur -> Loups-Garous -> Voyante -> Sorcière
  GamePhase _getNextNightPhase({
    required GamePhase current,
    required int round,
    required Map<String, PlayerModel> players,
  }) {
    bool hasAlive(GameRole role) =>
        players.values.any((p) => p.isAlive && p.role == role);

    bool hasAliveWerewolves() =>
        players.values.any((p) => p.isAlive && p.role.isEvil);

    bool hasActiveWitch() {
      final witch = players.values.cast<PlayerModel?>().firstWhere(
            (p) => p != null && p.isAlive && p.role == GameRole.witch,
            orElse: () => null,
          );
      return witch != null &&
          (!witch.hasUsedHealPotion || !witch.hasUsedPoisonPotion);
    }

    if (current == GamePhase.lobby || current == GamePhase.dayResolution) {
      if (round == 1 && hasAlive(GameRole.thief)) return GamePhase.nightThief;
      if (round == 1 && hasAlive(GameRole.cupid)) return GamePhase.nightCupid;
      if (hasAlive(GameRole.defender)) return GamePhase.nightDefender;
      if (hasAliveWerewolves()) return GamePhase.nightWerewolves;
      if (hasAlive(GameRole.seer)) return GamePhase.nightSeer;
      if (hasActiveWitch()) return GamePhase.nightWitch;
      if (hasAlive(GameRole.pyromaniac)) return GamePhase.nightPyromaniac;
      return GamePhase.morningAnnouncement;
    }

    if (current == GamePhase.nightThief) {
      if (round == 1 && hasAlive(GameRole.cupid)) return GamePhase.nightCupid;
      if (hasAlive(GameRole.defender)) return GamePhase.nightDefender;
      if (hasAliveWerewolves()) return GamePhase.nightWerewolves;
      if (hasAlive(GameRole.seer)) return GamePhase.nightSeer;
      if (hasActiveWitch()) return GamePhase.nightWitch;
      if (hasAlive(GameRole.pyromaniac)) return GamePhase.nightPyromaniac;
      return GamePhase.morningAnnouncement;
    }

    if (current == GamePhase.nightCupid) {
      if (hasAlive(GameRole.defender)) return GamePhase.nightDefender;
      if (hasAliveWerewolves()) return GamePhase.nightWerewolves;
      if (hasAlive(GameRole.seer)) return GamePhase.nightSeer;
      if (hasActiveWitch()) return GamePhase.nightWitch;
      if (hasAlive(GameRole.pyromaniac)) return GamePhase.nightPyromaniac;
      return GamePhase.morningAnnouncement;
    }

    // 1. Salvateur
    if (current == GamePhase.nightDefender) {
      if (hasAliveWerewolves()) return GamePhase.nightWerewolves;
      if (hasAlive(GameRole.seer)) return GamePhase.nightSeer;
      if (hasActiveWitch()) return GamePhase.nightWitch;
      if (hasAlive(GameRole.pyromaniac)) return GamePhase.nightPyromaniac;
      return GamePhase.morningAnnouncement;
    }

    // 2. Loups
    if (current == GamePhase.nightWerewolves) {
      if (hasAlive(GameRole.seer)) return GamePhase.nightSeer;
      if (hasActiveWitch()) return GamePhase.nightWitch;
      if (hasAlive(GameRole.pyromaniac)) return GamePhase.nightPyromaniac;
      return GamePhase.morningAnnouncement;
    }

    // 3. Voyante
    if (current == GamePhase.nightSeer) {
      if (hasActiveWitch()) return GamePhase.nightWitch;
      if (hasAlive(GameRole.pyromaniac)) return GamePhase.nightPyromaniac;
      return GamePhase.morningAnnouncement;
    }

    // 4. Sorcière
    if (current == GamePhase.nightWitch) {
      if (hasAlive(GameRole.pyromaniac)) return GamePhase.nightPyromaniac;
      return GamePhase.morningAnnouncement;
    }

    return GamePhase.morningAnnouncement;
  }

  Future<void> resolveMorningDeaths() async {
    if (!state.isHost || state.room == null) return;

    final room = state.room!;
    final updates = <String, dynamic>{};
    final logs = List<String>.from(room.logs);
    final List<String> effectiveDeaths = [];

    // 1. Victime des Loups
    final wolfVictimId = room.nightVictimId ?? _tallyWerewolfVotes();
    if (wolfVictimId != null) {
      final isProtected = room.currentProtectedPlayerId == wolfVictimId;
      final isHealed = room.witchHealed;

      if (!isProtected && !isHealed) {
        effectiveDeaths.add(wolfVictimId);
      } else if (isProtected) {
        logs.add(
          '🛡️ Le Salvateur a veillé sur la cible des loups cette nuit !',
        );
      } else if (isHealed) {
        logs.add('✨ Une potion de guérison miraculeuse a sauvé la victime !');
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

    for (final id in allDeaths) {
      updates['players/$id/isAlive'] = false;
      final player = room.players[id];
      if (player != null) {
        logs.add(
          '💀 ${player.name} (${player.role.displayNameFr}) a succombé.',
        );
      }
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

    updates['lastProtectedPlayerId'] = room.currentProtectedPlayerId;
    updates['currentProtectedPlayerId'] = null;
    updates['nightVictimId'] = null;
    updates['witchHealed'] = false;
    updates['witchPoisonVictimId'] = null;
    updates['morningVictims'] = allDeaths.toList();

    _resetAllVotes(updates);

    String? pendingHunter;
    String? pendingCaptain;

    for (final id in allDeaths) {
      final p = room.players[id];
      if (p?.role == GameRole.hunter) {
        pendingHunter = id;
      }
      if (p?.isCaptain == true || room.captainId == id) {
        pendingCaptain = id;
      }
    }

    final simulatedRoom = room.copyWith(
      players: room.players.map(
        (k, v) =>
            MapEntry(k, allDeaths.contains(k) ? v.copyWith(isAlive: false) : v),
      ),
    );
    final win = checkWinConditions(simulatedRoom);

    if (win != null) {
      updates['phase'] = GamePhase.gameOver.name;
      updates['winner'] = win;
      logs.add(_formatVictoryMessage(win));
    } else if (pendingHunter != null) {
      updates['phase'] = GamePhase.hunterDeathChoice.name;
      updates['pendingHunterId'] = pendingHunter;
      updates['timerSeconds'] = 25;
      logs.add(
        '🎯 Le Chasseur a été abattu ! Il a 25s pour faire feu dans son dernier souffle.',
      );
    } else if (pendingCaptain != null) {
      updates['phase'] = GamePhase.captainSuccession.name;
      updates['pendingCaptainId'] = pendingCaptain;
      updates['timerSeconds'] = 25;
      logs.add('🎖️ Le Capitaine est tombé ! Il doit nommer son héritier.');
    } else {
      updates['phase'] = GamePhase.morningAnnouncement.name;
      updates['timerSeconds'] = 20;
    }

    updates['logs'] = logs;
    await _syncState(updates);
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

    final aliveList = room.alivePlayers.map((p) => p.id).toList();
    if (aliveList.isNotEmpty) {
      updates['phase'] = GamePhase.dayDebate.name;
      updates['debateQueue'] = aliveList;
      updates['currentSpeakerId'] = aliveList.first;
      updates['timerSeconds'] = 45;
      final speakerName = room.players[aliveList.first]?.name ?? 'Inconnu';
      logs.add(
        '🎙️ Débat du village ouvert. Parole exclusive accordée à $speakerName (45s).',
      );
    } else {
      updates['phase'] = GamePhase.dayVoting.name;
      updates['timerSeconds'] = 60;
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

    if (queue.isNotEmpty) {
      queue.removeAt(0);
    }

    if (queue.isNotEmpty) {
      final nextSpeakerId = queue.first;
      final speakerName = room.players[nextSpeakerId]?.name ?? 'Inconnu';
      updates['debateQueue'] = queue;
      updates['currentSpeakerId'] = nextSpeakerId;
      updates['timerSeconds'] = 45;
      logs.add('🎙️ Fin du temps. La parole passe à $speakerName.');
    } else {
      updates['phase'] = GamePhase.dayVoting.name;
      updates['currentSpeakerId'] = null;
      updates['debateQueue'] = [];
      updates['timerSeconds'] = 60;
      logs.add(
        '⚖️ Les débats sont clos. Tous les citoyens doivent désigner un suspect au bûcher !',
      );
    }

    updates['logs'] = logs;
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

    if (room.round == 1 && condemned.role == GameRole.angel) {
      updates['players/$condemnedId/isAlive'] = false;
      updates['phase'] = GamePhase.gameOver.name;
      updates['winner'] = 'angel';
      logs.add(
        '🪽 L\'Ange ${condemned.name} a été condamné dès le Jour 1 ! Il remporte instantanément la victoire solitaire !',
      );
      updates['logs'] = logs;
      await _syncState(updates);
      return;
    }

    if (condemned.role == GameRole.idiot) {
      logs.add(
        '🤪 L\'Idiot du Village ${condemned.name} est gracié par la compassion du village ! Il reste en vie mais perd tout droit de vote.',
      );
      _finishDayCycle(room, updates, logs);
      updates['logs'] = logs;
      await _syncState(updates);
      return;
    }

    updates['players/$condemnedId/isAlive'] = false;
    logs.add(
      '🔥 Le village a jeté ${condemned.name} aux flammes du bûcher ! Il était ${condemned.role.displayNameFr}.',
    );

    final deadPartnerId = handleLoverDeath(condemnedId, room.players, logs);
    if (deadPartnerId != null) {
      updates['players/$deadPartnerId/isAlive'] = false;
    }

    final allDeaths = {
      condemnedId,
      ?deadPartnerId,
    };
    String? pendingHunter;
    String? pendingCaptain;

    for (final id in allDeaths) {
      final p = room.players[id];
      if (p?.role == GameRole.hunter) pendingHunter = id;
      if (p?.isCaptain == true || room.captainId == id) pendingCaptain = id;
    }

    final simulatedRoom = room.copyWith(
      players: room.players.map(
        (k, v) =>
            MapEntry(k, allDeaths.contains(k) ? v.copyWith(isAlive: false) : v),
      ),
    );
    final win = checkWinConditions(simulatedRoom);

    if (win != null) {
      updates['phase'] = GamePhase.gameOver.name;
      updates['winner'] = win;
      logs.add(_formatVictoryMessage(win));
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
      updates['timerSeconds'] = 25;
      logs.add(
        '🎖️ Le Capitaine doit désigner son successeur avant de mourir.',
      );
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
    _resetAllVotes(updates);
  }

  // ===========================================================================
  // 2. CONDITIONS D'ARRÊT ET DÉCLARATION DE VICTOIRE
  // ===========================================================================

  String? checkWinConditions(GameRoom room) {
    final alive = room.alivePlayers;
    if (alive.isEmpty) return 'draw';

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
          (p) => p != null && p.role == GameRole.piedPiper,
          orElse: () => null,
        );
    if (piper != null) {
      final others = alive.where((p) => p.id != piper.id);
      if (others.isNotEmpty && others.every((p) => p.isCharmed)) {
        return 'piedPiper';
      }
    }

    // 3. Victoires Solitaires au Dernier Survivant (Loup Blanc ou Pyromane)
    if (alive.length == 1) {
      final survivor = alive.first;
      if (survivor.role == GameRole.whiteWerewolf) return 'whiteWerewolf';
      if (survivor.role == GameRole.pyromaniac) return 'pyromaniac';
    }

    // 4. Décompte des camps
    final wolves = alive.where((p) => p.role.isEvil).length;
    final nonWolves = alive.where((p) => !p.role.isEvil).length;

    // A. Tous les loups sont éliminés
    if (wolves == 0) {
      // S'il ne reste qu'un rôle solo non-villageois vivant (ex: Pyromane encore avec des villageois),
      // le village ne gagne que si tous les neutres hostiles sont aussi morts
      final hasHostileSolo = alive.any((p) => p.role == GameRole.pyromaniac);
      if (!hasHostileSolo) {
        return 'village';
      }
    }

    // B. La meute prend le contrôle numérique du village
    if (wolves >= nonWolves) {
      return 'werewolves';
    }

    return null;
  }

  String _formatVictoryMessage(String winner) {
    switch (winner) {
      case 'village':
        return '🏆 Victoire triomphale du Village ! Tous les loups-garous et traîtres ont été exterminés.';
      case 'werewolves':
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
  }

  Future<void> pyromaniacPass() async {
    await processNightTransitions();
  }

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
    return true;
  }

  PlayerModel? inspectPlayer(String targetId) {
    if (state.myRole != GameRole.seer && !state.isAdmin) return null;
    final target = state.room?.players[targetId];
    if (target == null) return null;

    state = state.copyWith(inspectedRole: target.role);
    return target;
  }

  Future<void> completeSeerTurn() async {
    if (state.room == null) return;
    final currentLogs = List<String>.from(state.room!.logs);
    currentLogs.add('La Voyante a achevé sa vision nocturne.');
    await _syncState({'logs': currentLogs});
    await processNightTransitions();
  }

  Future<void> castVote(String? targetId) async {
    if (_currentRoomRef == null || (!state.isAlive && !state.isAdmin)) return;
    await _currentRoomRef!
        .child('players/${state.currentUserId}/targetVoteId')
        .set(targetId);

    if (state.room?.phase == GamePhase.nightWerewolves && targetId != null) {
      await _currentRoomRef!.child('nightVictimId').set(targetId);
      state = state.copyWith(
        room: state.room?.copyWith(nightVictimId: targetId),
      );
    }
  }

  Future<void> witchSaveVictim() async {
    if ((state.myRole != GameRole.witch && !state.isAdmin) ||
        _currentRoomRef == null) {
      return;
    }
    if (state.currentPlayer?.hasUsedHealPotion == true && !state.isAdmin) {
      return;
    }

    final roomCode = state.room?.roomCode;
    final witchPlayer = state.room?.playerList.firstWhere(
      (p) => p.role == GameRole.witch,
      orElse: () => state.currentPlayer!,
    );
    final witchId = (state.myRole == GameRole.witch)
        ? state.currentUserId
        : (witchPlayer?.id ?? state.currentUserId);

    await _syncState({
      'witchHealed': true,
      'players/$witchId/hasUsedHealPotion': true,
      'logs': [
        ...?state.room?.logs,
        'Une fiole luisante a été versée dans le plus grand secret...',
      ],
    });

    if (roomCode != null) {
      try {
        await _database.ref('rooms/$roomCode/witch_potions/$witchId').update({
          'hasHeal': false,
        });
      } catch (_) {}
    }
  }

  Future<void> witchPoison(String targetId) async {
    if ((state.myRole != GameRole.witch && !state.isAdmin) ||
        _currentRoomRef == null) {
      return;
    }
    if (state.currentPlayer?.hasUsedPoisonPotion == true && !state.isAdmin) {
      return;
    }

    final roomCode = state.room?.roomCode;
    final witchPlayer = state.room?.playerList.firstWhere(
      (p) => p.role == GameRole.witch,
      orElse: () => state.currentPlayer!,
    );
    final witchId = (state.myRole == GameRole.witch)
        ? state.currentUserId
        : (witchPlayer?.id ?? state.currentUserId);

    await _syncState({
      'witchPoisonVictimId': targetId,
      'players/$witchId/hasUsedPoisonPotion': true,
      'logs': [
        ...?state.room?.logs,
        'Un breuvage mortel a été déposé au seuil d\'une maison...',
      ],
    });

    if (roomCode != null) {
      try {
        await _database.ref('rooms/$roomCode/witch_potions/$witchId').update({
          'hasPoison': false,
        });
      } catch (_) {}
    }
  }

  Future<void> confirmWitchTurn() async {
    if (state.room == null) return;
    await resolveMorningDeaths();
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

    final updates = <String, dynamic>{
      'players/$targetId/isAlive': false,
      'pendingHunterId': null,
    };
    final logs = List<String>.from(room.logs);
    logs.add(
      '💥 Le Chasseur a abattu ${victim.name} (${victim.role.displayNameFr}) dans son dernier râle !',
    );

    final deadPartnerId = handleLoverDeath(targetId, room.players, logs);
    if (deadPartnerId != null) {
      updates['players/$deadPartnerId/isAlive'] = false;
    }

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
    final win = checkWinConditions(simulated);
    if (win != null) {
      updates['phase'] = GamePhase.gameOver.name;
      updates['winner'] = win;
      logs.add(_formatVictoryMessage(win));
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

  Future<void> captainPassBadge(String successorId) async {
    if (_currentRoomRef == null || state.room == null) return;
    final room = state.room!;
    if (room.pendingCaptainId != state.currentUserId && !state.isAdmin) return;

    final successor = room.players[successorId];
    if (successor == null || !successor.isAlive) return;

    final updates = <String, dynamic>{
      'captainId': successorId,
      'players/$successorId/isCaptain': true,
      'pendingCaptainId': null,
    };
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
    final aliveList = room.alivePlayers.map((p) => p.id).toList();
    if (aliveList.isNotEmpty) {
      updates['phase'] = GamePhase.dayDebate.name;
      updates['debateQueue'] = aliveList;
      updates['currentSpeakerId'] = aliveList.first;
      updates['timerSeconds'] = 45;
      final speakerName = room.players[aliveList.first]?.name ?? 'Inconnu';
      logs.add(
        '🎙️ Débat du village ouvert. Parole exclusive accordée à $speakerName (45s).',
      );
    } else {
      updates['phase'] = GamePhase.dayVoting.name;
      updates['timerSeconds'] = 60;
    }

    updates['logs'] = logs;
    await _syncState(updates);
  }

  Future<void> nextPhase() async {
    if (!state.isHost || state.room == null) return;
    final phase = state.room!.phase;

    if (phase.isNight) {
      await processNightTransitions();
    } else if (phase == GamePhase.morningAnnouncement) {
      final updates = <String, dynamic>{};
      final logs = List<String>.from(state.room!.logs);
      _routeToDayPhase(state.room!, updates, logs);
      updates['logs'] = logs;
      await _syncState(updates);
    } else if (phase == GamePhase.captainElection) {
      await concludeCaptainElection();
    } else if (phase == GamePhase.dayDebate) {
      await passTurnDebate();
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
      final firstNight = _getNextNightPhase(
        current: GamePhase.dayResolution,
        round: nextRound,
        players: state.room!.players,
      );

      final updates = <String, dynamic>{
        'phase': firstNight.name,
        'round': nextRound,
        'nightVictimId': null,
        'witchHealed': false,
        'witchPoisonVictimId': null,
        'seerInspectedTargetId': null,
        'seerInspectedRole': null,
        'timerSeconds': 45,
        'logs': [
          ...?state.room?.logs,
          '🌑 La nuit $nextRound recouvre le village. Les habitants s\'endorment.',
        ],
      };
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
    }
  }

  void _subscribeToRoom(String roomCode) {
    _roomSubscription?.cancel();
    _roomSubscription = _currentRoomRef?.onValue.listen((event) {
      if (event.snapshot.value == null) {
        state = state.copyWith(clearRoom: true);
        return;
      }

      final data = event.snapshot.value as Map<dynamic, dynamic>;
      final updatedRoom = GameRoom.fromMap(data, roomCode);
      state = state.copyWith(room: updatedRoom);

      _applyVoiceRulesForPhase(updatedRoom);
    });
  }

  Future<void> _applyVoiceRulesForPhase(GameRoom room) async {
    final me = room.players[state.currentUserId];
    if (me == null) return;

    final roomCode = room.roomCode;
    final mainChannel = 'lupus_$roomCode';
    final wolfChannel = 'lupus_${roomCode}_wolves';

    if (!me.isAlive) {
      await _voiceService.setMute(true);
      return;
    }

    switch (room.phase) {
      case GamePhase.nightWerewolves:
        final isWolf = me.role.isEvil;
        final canSpy =
            me.role == GameRole.littleGirl ||
            (state.isAdmin && state.isOmniscientVoice);

        if (isWolf || canSpy) {
          await _voiceService.switchChannel(
            newChannelId: wolfChannel,
            uid: state.agoraUid,
            initialMute: !isWolf,
          );
        } else {
          await _voiceService.switchChannel(
            newChannelId: mainChannel,
            uid: state.agoraUid,
            initialMute: true,
          );
        }
        break;

      case GamePhase.dayDebate:
      case GamePhase.dayDefense:
        final isCurrentSpeaker = room.currentSpeakerId == state.currentUserId;
        await _voiceService.switchChannel(
          newChannelId: mainChannel,
          uid: state.agoraUid,
          initialMute: !isCurrentSpeaker,
        );
        break;

      case GamePhase.dayVoting:
      case GamePhase.dayTieBreakVote:
      case GamePhase.dayResolution:
      case GamePhase.captainElection:
      case GamePhase.morningAnnouncement:
      case GamePhase.lobby:
      case GamePhase.gameOver:
        await _voiceService.switchChannel(
          newChannelId: mainChannel,
          uid: state.agoraUid,
          initialMute: false,
        );
        break;

      case GamePhase.hunterDeathChoice:
        await _voiceService.switchChannel(
          newChannelId: mainChannel,
          uid: state.agoraUid,
          initialMute: room.pendingHunterId != state.currentUserId,
        );
        break;

      case GamePhase.captainSuccession:
        await _voiceService.switchChannel(
          newChannelId: mainChannel,
          uid: state.agoraUid,
          initialMute: room.pendingCaptainId != state.currentUserId,
        );
        break;

      default:
        await _voiceService.switchChannel(
          newChannelId: mainChannel,
          uid: state.agoraUid,
          initialMute: true,
        );
        break;
    }
  }

  // ==========================================
  // --- PANNEAU MAÎTRE DU JEU (GOD MODE / ADMIN) ---
  // ==========================================

  bool unlockAdmin(String pin) {
    if (pin.trim() == '03031994') {
      state = state.copyWith(isAdmin: true);
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
      final aliveIds = state.room!.alivePlayers.map((p) => p.id).toList();
      updates['debateQueue'] = aliveIds;
      updates['currentSpeakerId'] = aliveIds.isNotEmpty ? aliveIds.first : null;
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

    await _syncState({
      'players/$playerId/isAlive': newAlive,
      'logs': currentLogs,
    });

    final simulated = state.room!.copyWith(
      players: {
        ...state.room!.players,
        playerId: target.copyWith(isAlive: newAlive),
      },
    );
    final win = checkWinConditions(simulated);
    if (win != null) {
      await _syncState({'winner': win, 'phase': GamePhase.gameOver.name});
    }
  }

  Future<void> adminForceSpeaker(String? playerId) async {
    if (_currentRoomRef == null || state.room == null) return;
    final target = playerId != null ? state.room!.players[playerId] : null;
    final log =
        '[ADMIN] Parole accordée à : ${target?.name ?? "Silence général"}';
    final currentLogs = List<String>.from(state.room!.logs)..insert(0, log);

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

  Future<void> leaveRoom() async {
    _roomSubscription?.cancel();
    _roomSubscription = null;
    await _voiceService.leaveChannel();
    state = state.copyWith(clearRoom: true);
  }

  static String _generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    return List.generate(5, (_) => chars[random.nextInt(chars.length)]).join();
  }

  @override
  void dispose() {
    _roomSubscription?.cancel();
    _voiceService.dispose();
    super.dispose();
  }
}

final gameNotifierProvider =
    StateNotifierProvider<GameNotifier, LupusGameState>((ref) {
  return GameNotifier();
});

final activeSpeakersProvider = Provider<Set<int>>((ref) {
  return ref.watch(gameNotifierProvider.select((s) => s.speakingAgoraUids));
});

final isMutedProvider = Provider<bool>((ref) {
  return ref.watch(gameNotifierProvider.select((s) => s.isMuted));
});

final isVoiceConnectedProvider = Provider<bool>((ref) {
  return ref.watch(gameNotifierProvider.select((s) => s.isVoiceConnected));
});
