import '../../models/game_role.dart';
import '../../models/game_state.dart';
import 'role_action_handler.dart';

class CrowHandler implements RoleActionHandler {
  @override
  GameRole get role => GameRole.raven;

  @override
  bool canAct(GameState state, String playerId) {
    return state.isAlive(playerId);
  }

  @override
  GameState executeAction(
    GameState state, {
    required String actorId,
    required Map<String, dynamic> actionPayload,
  }) {
    final targetId = actionPayload['targetId'] as String?;
    final updatedExpanded = state.expandedRolesState.copyWith(crowTargetId: targetId);
    return state.copyWith(expandedRolesState: updatedExpanded);
  }

  @override
  RoleUIControls getUIControls(GameState state, String playerId) {
    return RoleUIControls(
      title: 'Le Corbeau',
      instruction: 'Désignez un joueur suspect. Il recevra 2 votes d\'office lors du procès de jour.',
      inputType: RoleActionInputType.singleTarget,
      availableTargetIds: state.alivePlayerIds.where((id) => id != playerId).toList(),
      confirmButtonLabel: 'Placer le corbeau (+2 votes)',
      skipButtonLabel: 'Ne dénoncer personne cette nuit',
      canSkip: true,
    );
  }
}
