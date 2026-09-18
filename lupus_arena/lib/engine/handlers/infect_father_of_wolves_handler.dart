import '../../models/game_role.dart';
import '../../models/game_state.dart';
import 'role_action_handler.dart';

class InfectFatherOfWolvesHandler extends RoleActionHandler {
  @override
  GameRole get role => GameRole.vileFatherOfWolves;

  @override
  bool canAct(GameState state, String playerId) {
    return state.isAlive(playerId) &&
        !state.expandedRolesState.hasUsedInfection &&
        state.nightPrimaryVictimId != null;
  }

  @override
  GameState executeAction(
    GameState state, {
    required String actorId,
    required Map<String, dynamic> actionPayload,
  }) {
    final infect = actionPayload['infect'] as bool? ?? false;
    final victimId = state.nightPrimaryVictimId;
    if (!infect || victimId == null) return state;

    final updatedExpanded = state.expandedRolesState.copyWith(
      infectedPlayerId: victimId,
      hasUsedInfection: true,
    );

    // La victime survit à l'attaque de nuit
    return state.copyWith(
      nightPrimaryVictimId: null,
      expandedRolesState: updatedExpanded,
    );
  }

  @override
  RoleUIControls getUIControls(GameState state, String playerId) {
    final victimName = state.getPlayerName(state.nightPrimaryVictimId ?? '');
    return RoleUIControls(
      title: 'L\'Infect Père des Loups',
      instruction: 'Voulez-vous infecter $victimName pour qu\'il rejoigne secrètement les loups ?',
      inputType: RoleActionInputType.confirmation,
      confirmButtonLabel: 'Infecter la victime',
      skipButtonLabel: 'Laisser mourir',
      canSkip: true,
    );
  }
}
