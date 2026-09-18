import '../../models/game_role.dart';
import '../../models/game_state.dart';
import 'role_action_handler.dart';

class TwoSistersHandler implements RoleActionHandler {
  @override
  GameRole get role => GameRole.twoSisters;

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
    final otherSister = state.playerRoles.entries
        .firstWhere((e) => e.value == GameRole.twoSisters && e.key != playerId,
            orElse: () => const MapEntry('', GameRole.simpleVillager))
        .key;

    return RoleUIControls(
      title: 'Les Deux Sœurs',
      instruction: otherSister.isNotEmpty
          ? 'Votre sœur est : ${state.getPlayerName(otherSister)}.'
          : 'Vous n\'avez pas trouvé votre sœur.',
      inputType: RoleActionInputType.confirmation,
      confirmButtonLabel: 'J\'ai reconnu ma sœur',
      canSkip: false,
    );
  }
}
