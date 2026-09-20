import '../services/death_registry_service.dart';
import 'expanded_roles_state.dart';
import 'game_phase.dart';
import 'player_model.dart';

/// Modèle d'état immuable du moteur de jeu pour l'arbitrage pur et le Strategy Pattern
class GameState {
  final int currentTurn;
  final GamePhase currentPhase;
  final Map<String, GameRole> playerRoles;
  final Map<String, PlayerModel> players;
  final Set<String> nightAcknowledgedPlayerIds;
  final ExpandedRolesState expandedRolesState;
  final List<String> alivePlayerIdsInOrder;
  final String? pendingExecutedPlayerId;
  final String? lastEliminatedPlayerId;
  final List<String> nightSecondaryDeaths;
  final String? nightPrimaryVictimId;
  final String? currentProtectedPlayerId;
  final String? lastProtectedPlayerId;
  final String? blackWolfTargetId;

  const GameState({
    this.currentTurn = 1,
    this.currentPhase = GamePhase.lobby,
    this.playerRoles = const {},
    this.players = const {},
    this.nightAcknowledgedPlayerIds = const {},
    this.expandedRolesState = const ExpandedRolesState(),
    this.alivePlayerIdsInOrder = const [],
    this.pendingExecutedPlayerId,
    this.lastEliminatedPlayerId,
    this.nightSecondaryDeaths = const [],
    this.nightPrimaryVictimId,
    this.currentProtectedPlayerId,
    this.lastProtectedPlayerId,
    this.blackWolfTargetId,
  });

  bool isAlive(String playerId) {
    if (DeathRegistryService.instance.isDead(playerId)) {
      return false;
    }
    if (players.containsKey(playerId)) {
      return players[playerId]?.isAlive == true;
    }
    return alivePlayerIdsInOrder.contains(playerId);
  }

  String getPlayerName(String playerId) {
    return players[playerId]?.name ?? playerId;
  }

  List<String> get alivePlayerIds {
    if (players.isNotEmpty) {
      return players.values
          .where((p) => p.isAlive && !DeathRegistryService.instance.isDead(p.id))
          .map((p) => p.id)
          .toList();
    }
    return alivePlayerIdsInOrder
        .where((id) => !DeathRegistryService.instance.isDead(id))
        .toList();
  }

  bool get isDayPhase =>
      currentPhase == GamePhase.dayDebate ||
      currentPhase == GamePhase.dayVoting ||
      currentPhase == GamePhase.dayDefense ||
      currentPhase == GamePhase.dayTieBreakVote ||
      currentPhase == GamePhase.captainElection;

  GameState killPlayer(String playerId, {required String eliminationSource}) {
    final updatedPlayers = Map<String, PlayerModel>.from(players);
    if (updatedPlayers.containsKey(playerId)) {
      final p = updatedPlayers[playerId]!;
      updatedPlayers[playerId] = p.copyWith(isAlive: false);
    }
    final updatedAlive = List<String>.from(alivePlayerIdsInOrder)..remove(playerId);
    return copyWith(
      players: updatedPlayers,
      alivePlayerIdsInOrder: updatedAlive,
      lastEliminatedPlayerId: playerId,
    );
  }

  GameState copyWith({
    int? currentTurn,
    GamePhase? currentPhase,
    Map<String, GameRole>? playerRoles,
    Map<String, PlayerModel>? players,
    Set<String>? nightAcknowledgedPlayerIds,
    ExpandedRolesState? expandedRolesState,
    List<String>? alivePlayerIdsInOrder,
    String? pendingExecutedPlayerId,
    bool clearPendingExecutedPlayerId = false,
    String? lastEliminatedPlayerId,
    bool clearLastEliminatedPlayerId = false,
    List<String>? nightSecondaryDeaths,
    String? nightPrimaryVictimId,
    bool clearNightPrimaryVictimId = false,
    String? currentProtectedPlayerId,
    bool clearCurrentProtectedPlayerId = false,
    String? lastProtectedPlayerId,
    bool clearLastProtectedPlayerId = false,
    String? blackWolfTargetId,
    bool clearBlackWolfTargetId = false,
  }) {
    return GameState(
      currentTurn: currentTurn ?? this.currentTurn,
      currentPhase: currentPhase ?? this.currentPhase,
      playerRoles: playerRoles ?? this.playerRoles,
      players: players ?? this.players,
      nightAcknowledgedPlayerIds:
          nightAcknowledgedPlayerIds ?? this.nightAcknowledgedPlayerIds,
      expandedRolesState: expandedRolesState ?? this.expandedRolesState,
      alivePlayerIdsInOrder:
          alivePlayerIdsInOrder ?? this.alivePlayerIdsInOrder,
      pendingExecutedPlayerId: clearPendingExecutedPlayerId
          ? null
          : (pendingExecutedPlayerId ?? this.pendingExecutedPlayerId),
      lastEliminatedPlayerId: clearLastEliminatedPlayerId
          ? null
          : (lastEliminatedPlayerId ?? this.lastEliminatedPlayerId),
      nightSecondaryDeaths:
          nightSecondaryDeaths ?? this.nightSecondaryDeaths,
      nightPrimaryVictimId: clearNightPrimaryVictimId
          ? null
          : (nightPrimaryVictimId ?? this.nightPrimaryVictimId),
      currentProtectedPlayerId: clearCurrentProtectedPlayerId
          ? null
          : (currentProtectedPlayerId ?? this.currentProtectedPlayerId),
      lastProtectedPlayerId: clearLastProtectedPlayerId
          ? null
          : (lastProtectedPlayerId ?? this.lastProtectedPlayerId),
      blackWolfTargetId: clearBlackWolfTargetId
          ? null
          : (blackWolfTargetId ?? this.blackWolfTargetId),
    );
  }
}
