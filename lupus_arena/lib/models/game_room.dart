import 'game_phase.dart';
import 'player_model.dart';

class GameRoom {
  final String roomCode;
  final String hostId;
  final GamePhase phase;
  final int round;
  final Map<String, PlayerModel> players;

  // Rôles & Capacités de Nuit
  final String? captainId;
  final String? lastProtectedPlayerId;
  final String? currentProtectedPlayerId;
  final String? nightVictimId;
  final bool witchHealed;
  final String? witchPoisonVictimId;
  final bool pyromaniacIgnited;
  final String? seerInspectedTargetId;
  final String? seerInspectedRole;
  final String? blackWolfTargetId;

  // Résolutions de Morts & Successions
  final List<String> morningVictims;
  final String? pendingHunterId;
  final String? pendingCaptainId;

  // Débat & Vote
  final String? currentSpeakerId;
  final List<String> debateQueue;
  final List<String> tiedPlayerIds;
  final bool isTieBreakActive;

  // Fin & Vainqueur
  final String? winner;
  final int timerSeconds;
  final List<String> logs;

  // Configuration du Deck de Rôles & Disposition des Sièges
  final Map<String, int> rolePool;
  final bool isDevRoom;
  final List<String> seatingOrder;
  final List<String> replayReadyUserIds;

  const GameRoom({
    required this.roomCode,
    required this.hostId,
    this.phase = GamePhase.lobby,
    this.round = 1,
    this.players = const {},
    this.captainId,
    this.lastProtectedPlayerId,
    this.currentProtectedPlayerId,
    this.nightVictimId,
    this.witchHealed = false,
    this.witchPoisonVictimId,
    this.pyromaniacIgnited = false,
    this.seerInspectedTargetId,
    this.seerInspectedRole,
    this.blackWolfTargetId,
    this.morningVictims = const [],
    this.pendingHunterId,
    this.pendingCaptainId,
    this.currentSpeakerId,
    this.debateQueue = const [],
    this.tiedPlayerIds = const [],
    this.isTieBreakActive = false,
    this.winner,
    this.timerSeconds = 60,
    this.logs = const [],
    this.rolePool = const {},
    this.isDevRoom = false,
    this.seatingOrder = const [],
    this.replayReadyUserIds = const [],
  });

  List<PlayerModel> get playerList {
    if (seatingOrder.isNotEmpty) {
      final list = <PlayerModel>[];
      final seen = <String>{};
      for (final id in seatingOrder) {
        if (!seen.contains(id) && players.containsKey(id) && players[id] != null) {
          list.add(players[id]!);
          seen.add(id);
        }
      }
      for (final entry in players.entries) {
        if (!seen.contains(entry.key)) {
          list.add(entry.value);
          seen.add(entry.key);
        }
      }
      return list;
    }
    final all = <PlayerModel>[];
    final seen = <String>{};
    for (final p in players.values) {
      if (!seen.contains(p.id)) {
        all.add(p);
        seen.add(p.id);
      }
    }
    if (all.any((p) => p.seatIndex >= 0)) {
      all.sort((a, b) => a.seatIndex.compareTo(b.seatIndex));
      return all;
    }
    return all;
  }

  /// Vérifie si un joueur avec cet identifiant unique est déjà présent dans le salon (Anti-doublon)
  bool hasPlayer(String userId) {
    if (players.containsKey(userId)) return true;
    for (final p in players.values) {
      if (p.id == userId) return true;
    }
    return false;
  }

  int get replayReadyCount => replayReadyUserIds.length;
  int get totalPlayersCount => playerList.length;
  bool isPlayerReadyReplay(String userId) =>
      replayReadyUserIds.contains(userId) ||
      players[userId]?.isReadyReplay == true;

  List<PlayerModel> get alivePlayers =>
      playerList.where((p) => p.isAlive).toList();
  List<PlayerModel> get deadPlayers =>
      playerList.where((p) => !p.isAlive).toList();

  int get aliveWerewolvesCount =>
      alivePlayers.where((p) => p.role.isEvil).length;

  int get aliveVillagersCount =>
      alivePlayers.where((p) => !p.role.isEvil).length;

  Map<String, int> get voteCounts {
    final counts = <String, int>{};
    final isDayVote = phase == GamePhase.dayVoting || phase == GamePhase.dayTieBreakVote;
    for (final player in alivePlayers) {
      if (player.targetVoteId != null && player.targetVoteId!.isNotEmpty) {
        final weight = (isDayVote && player.isCaptain) ? 2 : 1;
        counts[player.targetVoteId!] = (counts[player.targetVoteId!] ?? 0) + weight;
      }
    }
    return counts;
  }

  /// Retourne l'identifiant du suspect ciblé par le vote du Maire (Capitaine), s'il existe et a voté
  String? get captainTargetVoteId {
    for (final player in alivePlayers) {
      if (player.isCaptain && player.targetVoteId != null && player.targetVoteId!.isNotEmpty) {
        return player.targetVoteId;
      }
    }
    return null;
  }

  int get totalRolesInPool =>
      rolePool.values.fold(0, (sum, count) => sum + count);

  GameRoom copyWith({
    String? roomCode,
    String? hostId,
    GamePhase? phase,
    int? round,
    Map<String, PlayerModel>? players,
    String? captainId,
    String? lastProtectedPlayerId,
    String? currentProtectedPlayerId,
    String? nightVictimId,
    bool? witchHealed,
    String? witchPoisonVictimId,
    bool? pyromaniacIgnited,
    String? seerInspectedTargetId,
    String? seerInspectedRole,
    String? blackWolfTargetId,
    bool clearBlackWolfTargetId = false,
    List<String>? morningVictims,
    String? pendingHunterId,
    String? pendingCaptainId,
    String? currentSpeakerId,
    List<String>? debateQueue,
    List<String>? tiedPlayerIds,
    bool? isTieBreakActive,
    String? winner,
    int? timerSeconds,
    List<String>? logs,
    Map<String, int>? rolePool,
    bool? isDevRoom,
    List<String>? seatingOrder,
    List<String>? replayReadyUserIds,
  }) {
    return GameRoom(
      roomCode: roomCode ?? this.roomCode,
      hostId: hostId ?? this.hostId,
      phase: phase ?? this.phase,
      round: round ?? this.round,
      players: players ?? this.players,
      captainId: captainId ?? this.captainId,
      lastProtectedPlayerId: lastProtectedPlayerId ?? this.lastProtectedPlayerId,
      currentProtectedPlayerId:
          currentProtectedPlayerId ?? this.currentProtectedPlayerId,
      nightVictimId: nightVictimId,
      witchHealed: witchHealed ?? this.witchHealed,
      witchPoisonVictimId: witchPoisonVictimId,
      pyromaniacIgnited: pyromaniacIgnited ?? this.pyromaniacIgnited,
      seerInspectedTargetId: seerInspectedTargetId,
      seerInspectedRole: seerInspectedRole,
      blackWolfTargetId: clearBlackWolfTargetId
          ? null
          : (blackWolfTargetId ?? this.blackWolfTargetId),
      morningVictims: morningVictims ?? this.morningVictims,
      pendingHunterId: pendingHunterId,
      pendingCaptainId: pendingCaptainId,
      currentSpeakerId: currentSpeakerId,
      debateQueue: debateQueue ?? this.debateQueue,
      tiedPlayerIds: tiedPlayerIds ?? this.tiedPlayerIds,
      isTieBreakActive: isTieBreakActive ?? this.isTieBreakActive,
      winner: winner ?? this.winner,
      timerSeconds: timerSeconds ?? this.timerSeconds,
      logs: logs ?? this.logs,
      rolePool: rolePool ?? this.rolePool,
      isDevRoom: isDevRoom ?? this.isDevRoom,
      seatingOrder: seatingOrder ?? this.seatingOrder,
      replayReadyUserIds: replayReadyUserIds ?? this.replayReadyUserIds,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'roomCode': roomCode,
      'hostId': hostId,
      'phase': phase.name,
      'round': round,
      'players': players.map((key, value) => MapEntry(key, value.toMap())),
      'captainId': captainId,
      'lastProtectedPlayerId': lastProtectedPlayerId,
      'currentProtectedPlayerId': currentProtectedPlayerId,
      'nightVictimId': nightVictimId,
      'witchHealed': witchHealed,
      'witchPoisonVictimId': witchPoisonVictimId,
      'pyromaniacIgnited': pyromaniacIgnited,
      'seerInspectedTargetId': seerInspectedTargetId,
      'seerInspectedRole': seerInspectedRole,
      'blackWolfTargetId': blackWolfTargetId,
      'morningVictims': morningVictims,
      'pendingHunterId': pendingHunterId,
      'pendingCaptainId': pendingCaptainId,
      'currentSpeakerId': currentSpeakerId,
      'debateQueue': debateQueue,
      'tiedPlayerIds': tiedPlayerIds,
      'isTieBreakActive': isTieBreakActive,
      'winner': winner,
      'timerSeconds': timerSeconds,
      'logs': logs,
      'rolePool': rolePool,
      'isDevRoom': isDevRoom,
      'seatingOrder': seatingOrder,
      'replayReadyUserIds': replayReadyUserIds,
      'config': {
        'rolePool': rolePool,
      },
    };
  }

  factory GameRoom.fromMap(
    Map<dynamic, dynamic> map,
    String code, [
    String? currentUserId,
  ]) {
    final roomCodeStr = (map['roomCode'] ?? code).toString();
    final isDevRoom = map['isDevRoom'] == true ||
        code.toUpperCase().startsWith('TEST') ||
        code.toUpperCase().startsWith('DEV') ||
        roomCodeStr.toUpperCase().startsWith('TEST') ||
        roomCodeStr.toUpperCase().startsWith('DEV');

    final rawPlayers = map['players'];
    final Map<String, PlayerModel> parsedPlayers = {};
    if (rawPlayers is Map) {
      rawPlayers.forEach((key, val) {
        if (val is Map) {
          parsedPlayers[key.toString()] = PlayerModel.fromMap(
            val,
            key.toString(),
            currentUserId,
            roomCodeStr,
          );
        }
      });
    } else if (rawPlayers is List) {
      for (int i = 0; i < rawPlayers.length; i++) {
        final val = rawPlayers[i];
        if (val is Map) {
          final id = val['id']?.toString() ?? 'player_$i';
          parsedPlayers[id] = PlayerModel.fromMap(
            val,
            id,
            currentUserId,
            roomCodeStr,
          );
        }
      }
    }

    final rawLogs = map['logs'];
    final List<String> parsedLogs = [];
    if (rawLogs is List) {
      for (final item in rawLogs) {
        if (item != null) parsedLogs.add(item.toString());
      }
    }

    final rawMorningVictims = map['morningVictims'];
    final List<String> parsedMorningVictims = [];
    if (rawMorningVictims is List) {
      for (final item in rawMorningVictims) {
        if (item != null) parsedMorningVictims.add(item.toString());
      }
    }

    final rawDebateQueue = map['debateQueue'];
    final List<String> parsedDebateQueue = [];
    if (rawDebateQueue is List) {
      for (final item in rawDebateQueue) {
        if (item != null) parsedDebateQueue.add(item.toString());
      }
    }

    final rawTied = map['tiedPlayerIds'];
    final List<String> parsedTied = [];
    if (rawTied is List) {
      for (final item in rawTied) {
        if (item != null) parsedTied.add(item.toString());
      }
    }

    final rawRolePool = map['config'] != null && map['config'] is Map
        ? (map['config'] as Map)['rolePool'] ?? map['rolePool']
        : map['rolePool'];
    final Map<String, int> parsedRolePool = {};
    if (rawRolePool is Map) {
      rawRolePool.forEach((key, val) {
        if (val is int) {
          parsedRolePool[key.toString()] = val;
        } else if (val != null) {
          final parsed = int.tryParse(val.toString());
          if (parsed != null) parsedRolePool[key.toString()] = parsed;
        }
      });
    }

    final rawSeatingOrder = map['seatingOrder'];
    final List<String> parsedSeatingOrder = [];
    if (rawSeatingOrder is List) {
      final seenSeats = <String>{};
      for (final item in rawSeatingOrder) {
        if (item != null) {
          final idStr = item.toString();
          if (!seenSeats.contains(idStr)) {
            parsedSeatingOrder.add(idStr);
            seenSeats.add(idStr);
          }
        }
      }
    }

    final rawReplayReady = map['replayReadyUserIds'];
    final List<String> parsedReplayReady = [];
    if (rawReplayReady is List) {
      for (final item in rawReplayReady) {
        if (item != null) parsedReplayReady.add(item.toString());
      }
    }

    return GameRoom(
      roomCode: (map['roomCode'] ?? code).toString(),
      hostId: (map['hostId'] ?? '').toString(),
      phase: GamePhase.fromString(map['phase']?.toString()),
      round: (map['round'] is int)
          ? map['round'] as int
          : int.tryParse(map['round']?.toString() ?? '1') ?? 1,
      players: parsedPlayers,
      captainId: map['captainId']?.toString(),
      lastProtectedPlayerId: map['lastProtectedPlayerId']?.toString(),
      currentProtectedPlayerId: map['currentProtectedPlayerId']?.toString(),
      nightVictimId: map['nightVictimId']?.toString(),
      witchHealed: map['witchHealed'] == true,
      witchPoisonVictimId: map['witchPoisonVictimId']?.toString(),
      pyromaniacIgnited: map['pyromaniacIgnited'] == true,
      seerInspectedTargetId: map['seerInspectedTargetId']?.toString(),
      seerInspectedRole: map['seerInspectedRole']?.toString(),
      blackWolfTargetId: map['blackWolfTargetId']?.toString(),
      morningVictims: parsedMorningVictims,
      pendingHunterId: map['pendingHunterId']?.toString(),
      pendingCaptainId: map['pendingCaptainId']?.toString(),
      currentSpeakerId: map['currentSpeakerId']?.toString(),
      debateQueue: parsedDebateQueue,
      tiedPlayerIds: parsedTied,
      isTieBreakActive: map['isTieBreakActive'] == true,
      winner: map['winner']?.toString(),
      timerSeconds: (map['timerSeconds'] is int)
          ? map['timerSeconds'] as int
          : int.tryParse(map['timerSeconds']?.toString() ?? '60') ?? 60,
      logs: parsedLogs,
      rolePool: parsedRolePool,
      isDevRoom: isDevRoom,
      seatingOrder: parsedSeatingOrder,
      replayReadyUserIds: parsedReplayReady,
    );
  }
}
