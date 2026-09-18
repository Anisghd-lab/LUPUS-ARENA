import 'expanded_roles_state.dart';
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

  // Nuits Spéciales Avancées (Voleur, Flûte, Loup Infect)
  final List<GameRole> thiefAvailableRoles;
  final bool vileFatherInfectionUsed;
  final String? infectedPlayerId;
  final List<String> charmedPlayerIds;

  // Résolutions de Morts & Successions
  final List<String> morningVictims;
  final String? pendingHunterId;
  final String? pendingCaptainId;
  final Map<String, dynamic>? lastDeathFlip;
  final List<Map<String, dynamic>> deathAnnouncementQueue;

  // Débat & Vote
  final String? currentSpeakerId;
  final List<String> debateQueue;
  final List<String> tiedPlayerIds;
  final bool isTieBreakActive;

  // Fin & Vainqueur
  final String? winner;
  final int timerSeconds;
  final List<String> logs;

  // Horloge Serveur & Synchronisation Absolue (Firebase RTDB)
  final int? phaseEndsAt; // Timestamp Epoch (ms) d'expiration de la phase courante
  final int? phaseStartedAt; // Timestamp Epoch (ms) de début de la phase courante
  final int? phaseDurationMs; // Durée totale allouée à la phase en millisecondes

  // Configuration du Deck de Rôles & Disposition des Sièges
  final Map<String, int> rolePool;
  final bool isDevRoom;
  final List<String> seatingOrder;
  final List<String> replayReadyUserIds;
  final ExpandedRolesState expandedRolesState;

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
    this.thiefAvailableRoles = const [],
    this.vileFatherInfectionUsed = false,
    this.infectedPlayerId,
    this.charmedPlayerIds = const [],
    this.morningVictims = const [],
    this.pendingHunterId,
    this.pendingCaptainId,
    this.lastDeathFlip,
    this.deathAnnouncementQueue = const [],
    this.currentSpeakerId,
    this.debateQueue = const [],
    this.tiedPlayerIds = const [],
    this.isTieBreakActive = false,
    this.winner,
    this.timerSeconds = 60,
    this.phaseEndsAt,
    this.phaseStartedAt,
    this.phaseDurationMs,
    this.logs = const [],
    this.rolePool = const {},
    this.isDevRoom = false,
    this.seatingOrder = const [],
    this.replayReadyUserIds = const [],
    this.expandedRolesState = const ExpandedRolesState(),
  });

  /// Temps restant en millisecondes calculé de manière pure par rapport à l'heure serveur estimée
  int remainingTimeMs(int currentServerEstimatedTime) {
    if (phaseEndsAt == null) {
      return timerSeconds * 1000;
    }
    final diff = phaseEndsAt! - currentServerEstimatedTime;
    return diff > 0 ? diff : 0;
  }

  /// Temps restant en secondes calculé de manière pure
  int remainingSeconds(int currentServerEstimatedTime) {
    return (remainingTimeMs(currentServerEstimatedTime) / 1000.0).ceil();
  }

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
        if (!seen.contains(entry.key) && !seen.contains(entry.value.id)) {
          list.add(entry.value);
          seen.add(entry.key);
          seen.add(entry.value.id);
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
    List<GameRole>? thiefAvailableRoles,
    bool? vileFatherInfectionUsed,
    String? infectedPlayerId,
    bool clearInfectedPlayerId = false,
    List<String>? charmedPlayerIds,
    List<String>? morningVictims,
    String? pendingHunterId,
    String? pendingCaptainId,
    Map<String, dynamic>? lastDeathFlip,
    List<Map<String, dynamic>>? deathAnnouncementQueue,
    String? currentSpeakerId,
    List<String>? debateQueue,
    List<String>? tiedPlayerIds,
    bool? isTieBreakActive,
    String? winner,
    int? timerSeconds,
    int? phaseEndsAt,
    int? phaseStartedAt,
    int? phaseDurationMs,
    bool clearPhaseEndsAt = false,
    List<String>? logs,
    Map<String, int>? rolePool,
    bool? isDevRoom,
    List<String>? seatingOrder,
    List<String>? replayReadyUserIds,
    ExpandedRolesState? expandedRolesState,
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
      thiefAvailableRoles: thiefAvailableRoles ?? this.thiefAvailableRoles,
      vileFatherInfectionUsed:
          vileFatherInfectionUsed ?? this.vileFatherInfectionUsed,
      infectedPlayerId: clearInfectedPlayerId
          ? null
          : (infectedPlayerId ?? this.infectedPlayerId),
      charmedPlayerIds: charmedPlayerIds ?? this.charmedPlayerIds,
      morningVictims: morningVictims ?? this.morningVictims,
      pendingHunterId: pendingHunterId,
      pendingCaptainId: pendingCaptainId,
      lastDeathFlip: lastDeathFlip ?? this.lastDeathFlip,
      deathAnnouncementQueue:
          deathAnnouncementQueue ?? this.deathAnnouncementQueue,
      currentSpeakerId: currentSpeakerId,
      debateQueue: debateQueue ?? this.debateQueue,
      tiedPlayerIds: tiedPlayerIds ?? this.tiedPlayerIds,
      isTieBreakActive: isTieBreakActive ?? this.isTieBreakActive,
      winner: winner ?? this.winner,
      timerSeconds: timerSeconds ?? this.timerSeconds,
      phaseEndsAt: clearPhaseEndsAt ? null : (phaseEndsAt ?? this.phaseEndsAt),
      phaseStartedAt: phaseStartedAt ?? this.phaseStartedAt,
      phaseDurationMs: phaseDurationMs ?? this.phaseDurationMs,
      logs: logs ?? this.logs,
      rolePool: rolePool ?? this.rolePool,
      isDevRoom: isDevRoom ?? this.isDevRoom,
      seatingOrder: seatingOrder ?? this.seatingOrder,
      replayReadyUserIds: replayReadyUserIds ?? this.replayReadyUserIds,
      expandedRolesState: expandedRolesState ?? this.expandedRolesState,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'roomCode': roomCode,
      'hostId': hostId,
      'phase': phase.name,
      'currentPhase': phase == GamePhase.dayVoting
          ? 'JOUR_VOTE'
          : (phase == GamePhase.dayDebate
              ? 'JOUR_DEBAT'
              : (phase == GamePhase.captainSuccession ? 'CAPITAINE_SUCCESSION' : phase.name)),
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
      'thiefAvailableRoles': thiefAvailableRoles.map((r) => r.id).toList(),
      'vileFatherInfectionUsed': vileFatherInfectionUsed,
      'infectedPlayerId': infectedPlayerId,
      'charmedPlayerIds': charmedPlayerIds,
      'morningVictims': morningVictims,
      'pendingHunterId': pendingHunterId,
      'pendingCaptainId': pendingCaptainId,
      'lastDeathFlip': lastDeathFlip,
      'deathAnnouncementQueue': deathAnnouncementQueue,
      'currentSpeakerId': currentSpeakerId,
      'debateQueue': debateQueue,
      'tiedPlayerIds': tiedPlayerIds,
      'isTieBreakActive': isTieBreakActive,
      'winner': winner,
      'timerSeconds': timerSeconds,
      'phaseEndsAt': phaseEndsAt,
      'phaseStartedAt': phaseStartedAt,
      'phaseDurationMs': phaseDurationMs,
      'logs': logs,
      'rolePool': rolePool,
      'isDevRoom': isDevRoom,
      'seatingOrder': seatingOrder,
      'replayReadyUserIds': replayReadyUserIds,
      'expandedRolesState': expandedRolesState.toMap(),
      'public_state': {
        'phase': phase.name,
        'currentPhase': phase.name,
        'round': round,
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
        'pendingHunterId': pendingHunterId,
        'pendingCaptainId': pendingCaptainId,
        'currentSpeakerId': currentSpeakerId,
        'winner': winner,
        'timerSeconds': timerSeconds,
        'phaseEndsAt': phaseEndsAt,
        'phaseStartedAt': phaseStartedAt,
        'phaseDurationMs': phaseDurationMs,
        'isTieBreakActive': isTieBreakActive,
      },
      'config': {
        'rolePool': rolePool,
      },
    };
  }

  factory GameRoom.fromMap(
    dynamic first, [
    dynamic second,
    String? currentUserId,
  ]) {
    final Map<dynamic, dynamic> rawMap = first is Map
        ? first
        : (second is Map ? second : <dynamic, dynamic>{});
    final publicState = rawMap['public_state'] as Map<dynamic, dynamic>?;
    final Map<dynamic, dynamic> map = publicState != null
        ? <dynamic, dynamic>{...rawMap, ...publicState}
        : rawMap;

    final String code = first is String
        ? first
        : (second is String ? second : (map['roomCode'] ?? map['code'] ?? 'DEV').toString());
    final roomCodeStr = (map['roomCode'] ?? map['code'] ?? code).toString();
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
          final pid = (val['id'] ?? key).toString();
          final player = PlayerModel.fromMap(
            val,
            pid,
            currentUserId,
            roomCodeStr,
          );
          if (parsedPlayers.containsKey(pid)) {
            final prev = parsedPlayers[pid]!;
            final preferNew = (player.isOnline && !prev.isOnline) ||
                ((player.lastSeen ?? 0) >= (prev.lastSeen ?? 0));
            parsedPlayers[pid] = preferNew ? player : prev;
          } else {
            parsedPlayers[pid] = player;
          }
        }
      });
    } else if (rawPlayers is List) {
      for (int i = 0; i < rawPlayers.length; i++) {
        final val = rawPlayers[i];
        if (val is Map) {
          final id = (val['id'] ?? 'player_$i').toString();
          final player = PlayerModel.fromMap(
            val,
            id,
            currentUserId,
            roomCodeStr,
          );
          if (parsedPlayers.containsKey(id)) {
            final prev = parsedPlayers[id]!;
            final preferNew = (player.isOnline && !prev.isOnline) ||
                ((player.lastSeen ?? 0) >= (prev.lastSeen ?? 0));
            parsedPlayers[id] = preferNew ? player : prev;
          } else {
            parsedPlayers[id] = player;
          }
        }
      }
    }

    // Merge sharded votes
    final rawVotes = map['votes'];
    if (rawVotes is Map) {
      rawVotes.forEach((voterId, targetId) {
        final vid = voterId.toString();
        if (parsedPlayers.containsKey(vid)) {
          parsedPlayers[vid] = parsedPlayers[vid]!.copyWith(
            targetVoteId: targetId?.toString(),
          );
        }
      });
    }

    // Merge sharded presence
    final rawPresence = map['presence'];
    if (rawPresence is Map) {
      rawPresence.forEach((uid, pData) {
        final userId = uid.toString();
        if (parsedPlayers.containsKey(userId) && pData is Map) {
          parsedPlayers[userId] = parsedPlayers[userId]!.copyWith(
            isOnline: pData['isOnline'] == true,
            isMuted: pData['isMuted'] == true,
            lastSeen: pData['lastSeen'] is int ? pData['lastSeen'] as int : null,
          );
        }
      });
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

    final rawLastDeathFlip = map['lastDeathFlip'];
    Map<String, dynamic>? parsedLastDeathFlip;
    if (rawLastDeathFlip is Map) {
      parsedLastDeathFlip = Map<String, dynamic>.from(rawLastDeathFlip);
    }

    final rawDeathQueue = map['deathAnnouncementQueue'];
    final List<Map<String, dynamic>> parsedDeathQueue = [];
    if (rawDeathQueue is List) {
      for (final item in rawDeathQueue) {
        if (item is Map) {
          parsedDeathQueue.add(Map<String, dynamic>.from(item));
        }
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

    final rawThiefRoles = map['thiefAvailableRoles'];
    final List<GameRole> parsedThiefRoles = [];
    if (rawThiefRoles is List) {
      for (final item in rawThiefRoles) {
        if (item != null) {
          parsedThiefRoles.add(GameRole.fromId(item.toString()));
        }
      }
    }

    final rawCharmed = map['charmedPlayerIds'];
    final List<String> parsedCharmed = [];
    if (rawCharmed is List) {
      for (final item in rawCharmed) {
        if (item != null) parsedCharmed.add(item.toString());
      }
    }

    final rawCurrent = map['currentPhase']?.toString();
    final rawPhase = map['phase']?.toString();
    GamePhase resolvedPhase;
    if (rawCurrent == 'JOUR_VOTE' || rawCurrent == 'JOUR_DEBAT' || rawCurrent == 'CAPITAINE_SUCCESSION') {
      resolvedPhase = GamePhase.fromString(rawCurrent);
    } else {
      final p1 = rawPhase != null ? GamePhase.fromString(rawPhase) : null;
      final p2 = rawCurrent != null ? GamePhase.fromString(rawCurrent) : null;
      if (p1 != null && p2 != null) {
        if (p1.isNight && p2.isNight) {
          // Progression monotone : privilégier systématiquement la phase la plus avancée
          resolvedPhase = p1.nightOrderIndex >= p2.nightOrderIndex ? p1 : p2;
        } else {
          resolvedPhase = p1 != GamePhase.lobby ? p1 : p2;
        }
      } else {
        resolvedPhase = p1 ?? p2 ?? GamePhase.lobby;
      }
    }

    return GameRoom(
      roomCode: (map['roomCode'] ?? code).toString(),
      hostId: (map['hostId'] ?? '').toString(),
      phase: resolvedPhase,
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
      thiefAvailableRoles: parsedThiefRoles,
      vileFatherInfectionUsed: map['vileFatherInfectionUsed'] == true,
      infectedPlayerId: map['infectedPlayerId']?.toString(),
      charmedPlayerIds: parsedCharmed,
      morningVictims: parsedMorningVictims,
      pendingHunterId: map['pendingHunterId']?.toString(),
      pendingCaptainId: map['pendingCaptainId']?.toString(),
      lastDeathFlip: parsedLastDeathFlip,
      deathAnnouncementQueue: parsedDeathQueue,
      currentSpeakerId: map['currentSpeakerId']?.toString(),
      debateQueue: parsedDebateQueue,
      tiedPlayerIds: parsedTied,
      isTieBreakActive: map['isTieBreakActive'] == true,
      winner: map['winner']?.toString(),
      timerSeconds: (map['timerSeconds'] is int)
          ? map['timerSeconds'] as int
          : int.tryParse(map['timerSeconds']?.toString() ?? '60') ?? 60,
      phaseEndsAt: (map['phaseEndsAt'] is num)
          ? (map['phaseEndsAt'] as num).toInt()
          : int.tryParse(map['phaseEndsAt']?.toString() ?? ''),
      phaseStartedAt: (map['phaseStartedAt'] is num)
          ? (map['phaseStartedAt'] as num).toInt()
          : int.tryParse(map['phaseStartedAt']?.toString() ?? ''),
      phaseDurationMs: (map['phaseDurationMs'] is num)
          ? (map['phaseDurationMs'] as num).toInt()
          : int.tryParse(map['phaseDurationMs']?.toString() ?? ''),
      logs: parsedLogs,
      rolePool: parsedRolePool,
      isDevRoom: isDevRoom,
      seatingOrder: parsedSeatingOrder,
      replayReadyUserIds: parsedReplayReady,
      expandedRolesState: ExpandedRolesState.fromMap(map['expandedRolesState'] as Map?),
    );
  }
}
