import '../../models/game_role.dart';
import '../../models/game_state.dart';
import 'role_action_handler.dart';

class SoulStealerHandler extends RoleActionHandler {
  @override
  GameRole get role => GameRole.thiefOfHearts;

  @override
  bool canAct(GameState state, String playerId) {
    return state.isAlive(playerId) && state.currentTurn == 1;
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

    final targetRole = state.playerRoles[targetId] ?? GameRole.simpleVillager;
    final updatedRoles = Map<String, GameRole>.from(state.playerRoles);

    // Échange des identités secrètes
    updatedRoles[actorId] = targetRole;
    updatedRoles[targetId] = GameRole.simpleVillager;

    return state.copyWith(playerRoles: updatedRoles);
  }

  @override
  RoleUIControls getUIControls(GameState state, String playerId) {
    return RoleUIControls(
      title: 'Le Voleur d\'Âmes',
      instruction:
          'Volez l\'identité d\'un joueur lors de la 1re nuit pour lui dérober son rôle.',
      inputType: RoleActionInputType.singleTarget,
      availableTargetIds: state.alivePlayerIds.where((id) => id != playerId).toList(),
      confirmButtonLabel: 'Dérober l\'âme',
      skipButtonLabel: 'Conserver mon statut',
      canSkip: true,
    );
  }
}
