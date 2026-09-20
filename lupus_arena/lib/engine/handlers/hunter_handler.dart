import '../../models/game_phase.dart';
import '../../models/game_role.dart';
import '../../models/game_state.dart';
import 'role_action_handler.dart';

/// Gestionnaire de rôle pour Le Chasseur.
/// S'il est éliminé, tire immédiatement une ultime balle sur un joueur de son choix.
class HunterHandler extends RoleActionHandler {
  @override
  GameRole get role => GameRole.hunter;

  @override
  bool canAct(GameState state, String playerId) {
    if (state.currentPhase != GamePhase.hunterDeathChoice) return false;
    return state.pendingExecutedPlayerId == playerId ||
        state.lastEliminatedPlayerId == playerId ||
        !state.isAlive(playerId);
  }

  @override
  GameState executeAction(
    GameState state, {
    required String actorId,
    required Map<String, dynamic> actionPayload,
  }) {
    final targetId = actionPayload['targetId'] as String?;
    if (targetId == null || !state.isAlive(targetId)) return state;

    return state.killPlayer(targetId, eliminationSource: 'hunter_shot');
  }

  @override
  RoleUIControls getUIControls(GameState state, String playerId) {
    return RoleUIControls(
      title: 'Le Chasseur',
      instruction: 'Vous quittez la partie. Désignez un joueur pour l\'emporter avec vous.',
      inputType: RoleActionInputType.singleTarget,
      availableTargetIds: state.alivePlayerIds,
      confirmButtonLabel: 'Désigner cette cible',
      canSkip: false,
    );
  }
}
