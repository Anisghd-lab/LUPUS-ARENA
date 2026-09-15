// ignore_for_file: file_names

import 'dart:async';
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'AgoraVoiceService.dart';
import 'models/chat_message.dart';
import 'models/game_phase.dart';
import 'models/game_room.dart';
import 'models/player_model.dart';
import 'services/role_security_service.dart';

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
    );
  }
}

/// Moteur de règles canoniques des Loups-Garous de Thiercelieux
class GameNotifier extends StateNotifier<LupusGameState> {
  final AgoraVoiceService _voiceService = AgoraVoiceService();
  StreamSubscription<DatabaseEvent>? _roomSubscription;
  StreamSubscription<DatabaseEvent>? _secretRoleSubscription;
  StreamSubscription<DatabaseEvent>? _wolfPackSubscription;
  DatabaseReference? _currentRoomRef;
  String? _lastAppliedVoiceChannel;
  GamePhase? _lastAppliedVoicePhase;

  GameNotifier()
      : super(
          LupusGameState(
            currentUserId: _generateUniqueId(),
            currentUserName: 'Guerrier_${Random().nextInt(900) + 100}',
            currentUserAvatar: Random().nextInt(6),
            agoraUid: Random().nextInt(899999) + 100000,
          ),
        ) {
    loadSavedProfile();
  }

  /// Charge le profil utilisateur précédemment sauvegardé sur l'appareil
  Future<void> loadSavedProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedName = prefs.getString('player_nickname');
      final savedAvatar = prefs.getInt('player_avatar');
      if (savedName != null && savedName.trim().isNotEmpty) {
        state = state.copyWith(currentUserName: savedName.trim());
      }
      if (savedAvatar != null) {
        state = state.copyWith(currentUserAvatar: savedAvatar);
      }
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
        currentSpeakerId: updates.containsKey('currentSpeakerId')
            ? updates['currentSpeakerId']
            : state.room!.currentSpeakerId,
      );
      state = state.copyWith(room: provisionalRoom);
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
          isCaptain: isCaptain,
          isHost: isLocal,
          isReady: true,
          isAlive: true,
          seatIndex: seat,
          agoraUid: isLocal ? state.agoraUid : 2000 + i,
        );
      }

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

      _currentRoomRef = _database.ref('games/$roomCode');
      await _currentRoomRef!.set(newRoom.toMap());
      await _database.ref('rooms/$roomCode/state').set(newRoom.toMap());

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
        userAccount: state.currentUserId,
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
          final victim = room.players[wolfVictimId];
          final victimName = victim?.name ?? 'Un villageois';
          logs.add(
            '🐺 Les Loups-Garous ont choisi leur victime dans l\'ombre : $victimName.',
          );
        }
      }

      // Nettoyage systématique des votes lors de chaque transition
      _resetAllVotes(updates);

      await _syncState(updates);
    }
  }

  /// Ordre choisi : Salvateur -> Loups-Garous -> Loup Noir -> Voyante -> Sorcière
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

    bool hasActiveWitch() {
      final witch = players.values.cast<PlayerModel?>().firstWhere(
            (p) => p != null && p.isAlive && getRole(p) == GameRole.witch,
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
      if (hasAlive(GameRole.blackWolf)) return GamePhase.nightBlackWolf;
      if (hasAlive(GameRole.seer)) return GamePhase.nightSeer;
      if (hasActiveWitch()) return GamePhase.nightWitch;
      if (hasAlive(GameRole.pyromaniac)) return GamePhase.nightPyromaniac;
      return GamePhase.morningAnnouncement;
    }

    if (current == GamePhase.nightThief) {
      if (round == 1 && hasAlive(GameRole.cupid)) return GamePhase.nightCupid;
      if (hasAlive(GameRole.defender)) return GamePhase.nightDefender;
      if (hasAliveWerewolves()) return GamePhase.nightWerewolves;
      if (hasAlive(GameRole.blackWolf)) return GamePhase.nightBlackWolf;
      if (hasAlive(GameRole.seer)) return GamePhase.nightSeer;
      if (hasActiveWitch()) return GamePhase.nightWitch;
      if (hasAlive(GameRole.pyromaniac)) return GamePhase.nightPyromaniac;
      return GamePhase.morningAnnouncement;
    }

    if (current == GamePhase.nightCupid) {
      if (hasAlive(GameRole.defender)) return GamePhase.nightDefender;
      if (hasAliveWerewolves()) return GamePhase.nightWerewolves;
      if (hasAlive(GameRole.blackWolf)) return GamePhase.nightBlackWolf;
      if (hasAlive(GameRole.seer)) return GamePhase.nightSeer;
      if (hasActiveWitch()) return GamePhase.nightWitch;
      if (hasAlive(GameRole.pyromaniac)) return GamePhase.nightPyromaniac;
      return GamePhase.morningAnnouncement;
    }

    // 1. Salvateur
    if (current == GamePhase.nightDefender) {
      if (hasAliveWerewolves()) return GamePhase.nightWerewolves;
      if (hasAlive(GameRole.blackWolf)) return GamePhase.nightBlackWolf;
      if (hasAlive(GameRole.seer)) return GamePhase.nightSeer;
      if (hasActiveWitch()) return GamePhase.nightWitch;
      if (hasAlive(GameRole.pyromaniac)) return GamePhase.nightPyromaniac;
      return GamePhase.morningAnnouncement;
    }

    // 2. Loups
    if (current == GamePhase.nightWerewolves) {
      if (hasAlive(GameRole.blackWolf)) return GamePhase.nightBlackWolf;
      if (hasAlive(GameRole.seer)) return GamePhase.nightSeer;
      if (hasActiveWitch()) return GamePhase.nightWitch;
      if (hasAlive(GameRole.pyromaniac)) return GamePhase.nightPyromaniac;
      return GamePhase.morningAnnouncement;
    }

    // 2.B Loup Noir (Pouvoir de faire taire un joueur)
    if (current == GamePhase.nightBlackWolf) {
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
    if (state.room == null) return;

    final room = state.room!;
    if (room.phase == GamePhase.morningAnnouncement ||
        room.phase == GamePhase.dayDebate ||
        room.phase == GamePhase.gameOver) {
      return;
    }
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
        GameRole revealedRole = player.role;
        try {
          final sSnap = await _database
              .ref('rooms/${room.roomCode}/secret_roles/$id/roleId')
              .get();
          if (sSnap.exists && sSnap.value != null) {
            revealedRole = GameRole.fromId(sSnap.value.toString());
          }
        } catch (_) {}
        updates['players/$id/role'] = revealedRole.id;
        logs.add(
          '💀 ${player.name} (${revealedRole.displayNameFr}) a succombé.',
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

    // 2c. Loup Noir : Réduire au silence pour toute la durée de la journée
    if (room.blackWolfTargetId != null) {
      final silencedId = room.blackWolfTargetId!;
      final silencedPlayer = room.players[silencedId];
      if (silencedPlayer != null && !allDeaths.contains(silencedId)) {
        updates['players/$silencedId/isMuted'] = true;
        logs.add(
          '🔇 SORT DU LOUP NOIR : ${silencedPlayer.name} est réduit(e) au silence pour toute la journée ! (Micro et chat désactivés)',
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
    updates['morningVictims'] = allDeaths.toList();

    _resetAllVotes(updates);

    String? pendingHunter;
    String? pendingCaptain;

    final realRoles = await _resolveRealRoles(room);

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
      // Révélation publique de tous les rôles restants à la fin de partie
      for (final p in room.playerList) {
        final revealedRole = realRoles[p.id] ?? p.role;
        updates['players/${p.id}/role'] = revealedRole.id;
      }
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
    final currentSpeakerName =
        room.players[room.currentSpeakerId]?.name ?? 'Un citoyen';

    if (queue.isNotEmpty) {
      queue.removeAt(0);
    }

    if (queue.isNotEmpty) {
      final nextSpeakerId = queue.first;
      final speakerName = room.players[nextSpeakerId]?.name ?? 'Inconnu';
      updates['debateQueue'] = queue;
      updates['currentSpeakerId'] = nextSpeakerId;
      updates['timerSeconds'] = 45;
      logs.add('🎙️ $currentSpeakerName a cédé sa parole. La parole passe à $speakerName.');
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
      }
    }

    final allDeaths = {
      condemnedId,
      ?deadPartnerId,
    };
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

  String? checkWinConditions(
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

    // 3. Victoires Solitaires au Dernier Survivant (Loup Blanc ou Pyromane)
    if (alive.length == 1) {
      final survivor = alive.first;
      final role = getRole(survivor);
      if (role == GameRole.whiteWerewolf) return 'whiteWerewolf';
      if (role == GameRole.pyromaniac) return 'pyromaniac';
      if (role.isEvil) return 'werewolves';
      return 'village';
    }

    // 4. Décompte des camps avec les vrais rôles
    final aliveWolves = alive.where((p) => getRole(p).isEvil).length;
    final aliveVillagers = alive.where((p) => !getRole(p).isEvil).length;
    final totalPlayersAtStart = room.players.length;

    // Condition de victoire des Loups :
    // - 0 loup en vie = impossible qu'ils gagnent
    // - Pour une partie lancée à 4 joueurs :
    //   Le loup gagne uniquement s'il reste 1 loup face à 1 villageois (ou 0 villageois)
    // - Règle générale (5 joueurs et plus) :
    //   1 loup vivant contre 2 villageois (ou moins) suffit pour gagner
    final bool wolvesWon;
    if (aliveWolves == 0) {
      wolvesWon = false;
    } else if (totalPlayersAtStart <= 4) {
      wolvesWon = (aliveWolves >= 1 && aliveVillagers <= 1);
    } else {
      wolvesWon = (aliveWolves >= 1 && aliveVillagers <= 2);
    }

    // Application du résultat
    if (wolvesWon) {
      return 'werewolves';
    }

    if (aliveWolves == 0) {
      final hasHostileSolo = alive.any((p) {
        final r = getRole(p);
        return r == GameRole.pyromaniac || r == GameRole.whiteWerewolf;
      });
      if (!hasHostileSolo) {
        return 'village';
      }
    }

    // La partie continue (nuit ou jour suivant)
    return null;
  }

  String _formatVictoryMessage(String winner) {
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

  /// Pouvoir du Loup Noir : durant la nuit, sélectionne un joueur vivant pour le réduire au silence
  Future<bool> blackWolfSilence(String targetPlayerId) async {
    if ((state.myRole != GameRole.blackWolf && !state.isAdmin) ||
        _currentRoomRef == null) {
      return false;
    }
    final target = state.room?.players[targetPlayerId];
    if (target == null || !target.isAlive) {
      return false;
    }

    await _syncState({
      'blackWolfTargetId': targetPlayerId,
      'logs': [
        ...?state.room?.logs,
        '🐺 Une aura ténébreuse s\'empare d\'un villageois... Le Loup Noir a désigné sa cible de silence.',
      ],
    });
    await processNightTransitions();
    return true;
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

    // Règle spéciale Voyante : Le Loup Blanc apparaît comme un Simple Villageois
    discoveredRole = getSeerPerceivedRole(discoveredRole);

    final updatedMap = Map<String, GameRole>.from(state.seerInspectedRoles);
    updatedMap[targetId] = discoveredRole;

    state = state.copyWith(
      inspectedRole: discoveredRole,
      seerInspectedRoles: updatedMap,
    );
    return target.copyWith(role: discoveredRole);
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
    await processNightTransitions();
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
      }
    }

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
    if (state.room == null) return;
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
            (phase == GamePhase.nightBlackWolf &&
                (state.myRole == GameRole.blackWolf || state.isAdmin)));

    if (!state.isHost && !state.isAdmin && !canAdvanceNight) return;

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
      final updatedRoom =
          GameRoom.fromMap(data, roomCode, state.currentUserId);
      state = state.copyWith(room: updatedRoom);

      _applyVoiceRulesForPhase(updatedRoom);
    });

    // Écouter son propre rôle secret depuis la source confidentielle
    _secretRoleSubscription?.cancel();
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

    // Écouter le canal meute des loups-garous (filtré et déchiffré)
    _wolfPackSubscription?.cancel();
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

    String targetChannel = mainChannel;
    bool shouldMute = false;

    switch (room.phase) {
      case GamePhase.nightWerewolves:
        final isWolf = me.role.isEvil;
        final canSpy =
            me.role == GameRole.littleGirl ||
            (state.isAdmin && state.isOmniscientVoice);

        if (isWolf || canSpy) {
          targetChannel = wolfChannel;
          shouldMute = !isWolf;
        } else {
          targetChannel = mainChannel;
          shouldMute = true;
        }
        break;

      case GamePhase.dayDebate:
      case GamePhase.dayDefense:
        targetChannel = mainChannel;
        final isCurrentSpeaker = room.currentSpeakerId == state.currentUserId;
        shouldMute = !isCurrentSpeaker;
        break;

      case GamePhase.dayVoting:
      case GamePhase.dayTieBreakVote:
      case GamePhase.dayResolution:
      case GamePhase.captainElection:
      case GamePhase.morningAnnouncement:
      case GamePhase.lobby:
      case GamePhase.gameOver:
        targetChannel = mainChannel;
        shouldMute = false;
        break;

      case GamePhase.hunterDeathChoice:
        targetChannel = mainChannel;
        shouldMute = room.pendingHunterId != state.currentUserId;
        break;

      case GamePhase.captainSuccession:
        targetChannel = mainChannel;
        shouldMute = room.pendingCaptainId != state.currentUserId;
        break;

      default:
        targetChannel = mainChannel;
        shouldMute = true;
        break;
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

    // Si le joueur est réduit au silence par le Loup Noir (isMuted), son micro est forcé en sourdine
    if (me.isMuted) {
      shouldMute = true;
    }

    await _voiceService.setMute(shouldMute);
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
    final realRoles = await _resolveRealRoles(state.room!);
    final win = checkWinConditions(simulated, realRoles);
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

  /// Envoi d'un message dans le chat du jeu
  /// Si le joueur est réduit au silence par le Loup Noir (isMuted = true),
  /// l'envoi est strictement interdit et le chat est bloqué pour toute la journée.
  Future<bool> sendChatMessage(String content) async {
    final clean = content.trim();
    if (clean.isEmpty || state.room == null) return false;
    final room = state.room!;

    final me = state.currentPlayer;
    if (me?.isMuted == true) {
      state = state.copyWith(
        errorMessage:
            '🔇 Vous êtes réduit au silence par le Loup Noir (micro coupé et chat désactivé pour toute la journée).',
      );
      return false;
    }

    if (!state.isAlive && !state.isAdmin) {
      state = state.copyWith(
        errorMessage: 'Les défunts ne peuvent pas s\'exprimer dans le village.',
      );
      return false;
    }

    final messageId =
        'msg_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
    final chatMsg = ChatMessage(
      id: messageId,
      senderId: state.currentUserId,
      senderName: state.currentUserName,
      senderAvatar: state.currentUserAvatar,
      content: clean,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      isWolfChat: false,
      senderRole: state.myRole.displayName,
    );

    try {
      await _database
          .ref('rooms/${room.roomCode}/chat/$messageId')
          .set(chatMsg.toMap());
      return true;
    } catch (e) {
      debugPrint('[Firebase Chat Error] $e');
      return false;
    }
  }

  Future<void> leaveRoom() async {
    _roomSubscription?.cancel();
    _roomSubscription = null;
    _secretRoleSubscription?.cancel();
    _secretRoleSubscription = null;
    _wolfPackSubscription?.cancel();
    _wolfPackSubscription = null;
    _lastAppliedVoiceChannel = null;
    _lastAppliedVoicePhase = null;
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
    _secretRoleSubscription?.cancel();
    _wolfPackSubscription?.cancel();
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
