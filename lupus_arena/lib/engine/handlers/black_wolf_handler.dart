import '../../models/game_phase.dart';
import '../../models/game_role.dart';
import '../../models/game_state.dart';
import 'role_action_handler.dart';

/// Gestionnaire de rôle pour Le Loup Noir.
/// Choisit un joueur chaque nuit pour lui couper la parole au lever du jour.
class BlackWolfHandler extends RoleActionHandler {
  @override
  GameRole get role => GameRole.blackWolf;

  @override
  bool canAct(GameState state, String playerId) {
    return state.isAlive(playerId) &&
        (state.currentPhase == GamePhase.nightBlackWolf ||
            state.currentPhase == GamePhase.nightWerewolves);
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
    return state.copyWith(
      nightAcknowledgedPlayerIds: acknowledged,
    );
  }

  @override
  RoleUIControls getUIControls(GameState state, String playerId) {
    final targets = state.alivePlayerIds.where((id) => id != playerId).toList();

    return RoleUIControls(
      title: 'Loup Noir',
      instruction: 'Désignez un joueur pour lui couper le micro lors de la journée suivante.',
      inputType: RoleActionInputType.singleTarget,
      availableTargetIds: targets,
      confirmButtonLabel: 'Réduire au silence',
      canSkip: false,
    );
  }
}
