import '../../models/game_role.dart';
import '../../models/game_state.dart';
import 'role_action_handler.dart';

class FoxHandler extends RoleActionHandler {
  @override
  GameRole get role => GameRole.fox;

  @override
  bool canAct(GameState state, String playerId) {
    final foxActive = state.expandedRolesState.foxPowerActive;
    return state.isAlive(playerId) && foxActive;
  }

  @override
  GameState executeAction(
    GameState state, {
    required String actorId,
    required Map<String, dynamic> actionPayload,
  }) {
    final skip = actionPayload['skip'] as bool? ?? false;
    if (skip) return state;

    final targetId = actionPayload['targetId'] as String?;
    if (targetId == null) return state;

    final aliveIds = state.alivePlayerIdsInOrder;
    final targetIdx = aliveIds.indexOf(targetId);
    if (targetIdx == -1) return state;

    final n = aliveIds.length;
    final leftId = aliveIds[(targetIdx - 1 + n) % n];
    final rightId = aliveIds[(targetIdx + 1) % n];

    final trio = [targetId, leftId, rightId];

    final hasWolf = trio.any((id) {
      final r = state.playerRoles[id];
      return r?.camp == Camp.wolves || id == state.expandedRolesState.infectedPlayerId;
    });

    final updatedExpanded = state.expandedRolesState.copyWith(
      foxPowerActive: hasWolf,
      lastFoxCheckResult: hasWolf,
    );

    final updatedPlayers = Map<String, PlayerModel>.from(state.players);
    for (final pid in trio) {
      if (updatedPlayers.containsKey(pid)) {
        updatedPlayers[pid] = updatedPlayers[pid]!.copyWith(
          isSniffed: true,
          hasWolfSmell: hasWolf,
        );
      }
    }

    return state.copyWith(
      players: updatedPlayers,
      expandedRolesState: updatedExpanded,
    );
  }

  @override
  RoleUIControls getUIControls(GameState state, String playerId) {
    return RoleUIControls(
      title: 'Le Renard',
      instruction: 'Désignez un joueur. Son flair analysera ce joueur et ses 2 voisins directs.',
      inputType: RoleActionInputType.singleTarget,
      availableTargetIds: state.alivePlayerIds.where((id) => id != playerId).toList(),
      confirmButtonLabel: 'Flairer le groupe',
      skipButtonLabel: 'Garder mon flair pour plus tard',
      canSkip: true,
    );
  }
}
