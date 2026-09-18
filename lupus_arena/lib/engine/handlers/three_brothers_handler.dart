import '../../models/game_role.dart';
import '../../models/game_state.dart';
import 'role_action_handler.dart';

class ThreeBrothersHandler extends RoleActionHandler {
  @override
  GameRole get role => GameRole.threeBrothers;

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
    final acknowledged = Set<String>.from(state.nightAcknowledgedPlayerIds)..add(actorId);
    return state.copyWith(nightAcknowledgedPlayerIds: acknowledged);
  }

  @override
  RoleUIControls getUIControls(GameState state, String playerId) {
    final brothers = state.playerRoles.entries
        .where((e) => e.value == GameRole.threeBrothers && e.key != playerId)
        .map((e) => state.getPlayerName(e.key))
        .join(', ');

    return RoleUIControls(
      title: 'Les Trois Frères',
      instruction: brothers.isNotEmpty
          ? 'Vos frères sont : $brothers.'
          : 'Aucun frère identifié.',
      inputType: RoleActionInputType.confirmation,
      confirmButtonLabel: 'J\'ai reconnu mes frères',
      canSkip: false,
    );
  }
}
