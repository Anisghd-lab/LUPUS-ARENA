import '../../models/game_phase.dart';
import '../../models/game_role.dart';
import '../../models/game_state.dart';
import 'role_action_handler.dart';

/// Gestionnaire de rôle pour Le Salvateur.
/// Chaque nuit, immunise un joueur contre l'attaque des loups.
class DefenderHandler extends RoleActionHandler {
  @override
  GameRole get role => GameRole.defender;

  @override
  bool canAct(GameState state, String playerId) {
    return state.isAlive(playerId) &&
        (state.currentPhase == GamePhase.nightDefender || state.currentPhase.isNight);
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
    return RoleUIControls(
      title: 'Le Salvateur',
      instruction: 'Choisissez un joueur à protéger cette nuit contre les griffes des loups.',
      inputType: RoleActionInputType.singleTarget,
      availableTargetIds: state.alivePlayerIds,
      confirmButtonLabel: 'Protéger ce joueur',
      canSkip: false,
    );
  }
}
