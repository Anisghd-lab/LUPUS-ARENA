import '../../models/game_role.dart';
import '../../models/game_state.dart';
import 'role_action_handler.dart';

/// Gestionnaire de rôle pour L'Ange.
/// Remporte la victoire s'il est éliminé par le village lors du vote du premier jour.
class AngelHandler extends RoleActionHandler {
  @override
  GameRole get role => GameRole.angel;

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
    final eliminated = actionPayload['eliminatedOnDay1'] as bool? ?? false;
    if (eliminated) {
      final updated = state.expandedRolesState.copyWith(angelWon: true);
      return state.copyWith(expandedRolesState: updated);
    }
    return state;
  }

  @override
  RoleUIControls getUIControls(GameState state, String playerId) {
    return const RoleUIControls(
      title: 'L\'Ange',
      instruction: 'Faites-vous éliminer par le village dès le premier jour pour remporter la victoire.',
      inputType: RoleActionInputType.none,
    );
  }
}
