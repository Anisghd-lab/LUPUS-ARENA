import '../../models/game_phase.dart';
import '../../models/game_role.dart';
import '../../models/game_state.dart';
import 'role_action_handler.dart';

/// Gestionnaire de rôle pour La Voyante.
/// Chaque nuit, elle sonde l'âme d'un joueur pour découvrir son identité secrète.
class SeerHandler extends RoleActionHandler {
  @override
  GameRole get role => GameRole.seer;

  @override
  bool canAct(GameState state, String playerId) {
    return state.isAlive(playerId) &&
        (state.currentPhase == GamePhase.nightSeer || state.currentPhase.isNight);
  }

  @override
  GameState executeAction(
    GameState state, {
    required String actorId,
    required Map<String, dynamic> actionPayload,
  }) {
    final targetId = actionPayload['targetId'] as String?;
    if (targetId == null || !state.isAlive(targetId)) return state;

    final acknowledged = Set<String>.from(state.nightAcknowledgedPlayerIds)..add(actorId);
    return state.copyWith(nightAcknowledgedPlayerIds: acknowledged);
  }

  @override
  RoleUIControls getUIControls(GameState state, String playerId) {
    final targets = state.alivePlayerIds.where((id) => id != playerId).toList();

    return RoleUIControls(
      title: 'La Voyante',
      instruction: 'Choisissez un joueur dont vous souhaitez percer l\'identité secrète.',
      inputType: RoleActionInputType.singleTarget,
      availableTargetIds: targets,
      confirmButtonLabel: 'Sonder cette âme',
      canSkip: false,
    );
  }
}
