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
  });

  bool isAlive(String playerId) {
    if (players.containsKey(playerId)) {
      return players[playerId]?.isAlive ?? true;
    }
    return alivePlayerIdsInOrder.contains(playerId);
  }

  String getPlayerName(String playerId) {
    return players[playerId]?.name ?? playerId;
  }

  List<String> get alivePlayerIds {
    if (players.isNotEmpty) {
      return players.values.where((p) => p.isAlive).map((p) => p.id).toList();
    }
    return alivePlayerIdsInOrder;
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
    String? lastEliminatedPlayerId,
    List<String>? nightSecondaryDeaths,
    String? nightPrimaryVictimId,
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
      pendingExecutedPlayerId:
          pendingExecutedPlayerId ?? this.pendingExecutedPlayerId,
      lastEliminatedPlayerId:
          lastEliminatedPlayerId ?? this.lastEliminatedPlayerId,
      nightSecondaryDeaths:
          nightSecondaryDeaths ?? this.nightSecondaryDeaths,
      nightPrimaryVictimId:
          nightPrimaryVictimId ?? this.nightPrimaryVictimId,
    );
  }
}
