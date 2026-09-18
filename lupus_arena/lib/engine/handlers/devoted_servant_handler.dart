import '../../models/game_role.dart';
import '../../models/game_state.dart';
import 'role_action_handler.dart';

class DevotedServantHandler extends RoleActionHandler {
  @override
  GameRole get role => GameRole.servantMaid;

  @override
  bool canAct(GameState state, String playerId) {
    return state.isAlive(playerId) && state.pendingExecutedPlayerId != null;
  }

  @override
  GameState executeAction(
    GameState state, {
    required String actorId,
    required Map<String, dynamic> actionPayload,
  }) {
    final wantsToSwap = actionPayload['swap'] as bool? ?? false;
    final victimId = state.pendingExecutedPlayerId;
    if (!wantsToSwap || victimId == null) {
      return state;
    }

    final victimRole = state.playerRoles[victimId] ?? GameRole.simpleVillager;
    final updatedRoles = Map<String, GameRole>.from(state.playerRoles);

    // La servante prend le rôle du défunt, le défunt devient Simple Villageois à titre posthume
    updatedRoles[actorId] = victimRole;
    updatedRoles[victimId] = GameRole.simpleVillager;

    return state.copyWith(playerRoles: updatedRoles);
  }

  @override
  RoleUIControls getUIControls(GameState state, String playerId) {
    final victimId = state.pendingExecutedPlayerId ?? '';
    final victimName = state.getPlayerName(victimId);
    return RoleUIControls(
      title: 'La Servante Dévouée',
      instruction:
          'Le village a condamné $victimName. Souhaitez-vous échanger votre rôle avec le sien ?',
      inputType: RoleActionInputType.confirmation,
      confirmButtonLabel: 'Prendre sa place et son rôle',
      skipButtonLabel: 'Laisser mourir',
      canSkip: true,
    );
  }
}
