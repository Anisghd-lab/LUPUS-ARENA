import '../../models/game_role.dart';
import '../../models/game_state.dart';
import 'role_action_handler.dart';

class StutteringJudgeHandler implements RoleActionHandler {
  @override
  GameRole get role => GameRole.stutteringJudge;

  @override
  bool canAct(GameState state, String playerId) {
    return state.isAlive(playerId) &&
        state.isDayPhase &&
        state.expandedRolesState.judgeSecondVoteAvailable &&
        !state.expandedRolesState.isSecondVoteTriggered;
  }

  @override
  GameState executeAction(
    GameState state, {
    required String actorId,
    required Map<String, dynamic> actionPayload,
  }) {
    final updatedExpanded = state.expandedRolesState.copyWith(
      judgeSecondVoteAvailable: false,
      isSecondVoteTriggered: true,
    );
    return state.copyWith(expandedRolesState: updatedExpanded);
  }

  @override
  RoleUIControls getUIControls(GameState state, String playerId) {
    return const RoleUIControls(
      title: 'Le Juge Bègue',
      instruction: 'Vous pouvez exiger un second vote consécutif du village aujourd\'hui.',
      inputType: RoleActionInputType.confirmation,
      confirmButtonLabel: 'Déclencher un 2nd vote immédiat',
      canSkip: false,
    );
  }
}
