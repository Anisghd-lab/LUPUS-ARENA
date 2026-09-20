import '../../models/game_phase.dart';
import '../../models/game_role.dart';
import '../../models/game_state.dart';
import 'role_action_handler.dart';

/// Gestionnaire de rôle pour Cupidon.
/// Désigne deux amoureux la première nuit dont les destins seront à jamais liés.
class CupidHandler extends RoleActionHandler {
  @override
  GameRole get role => GameRole.cupid;

  @override
  bool canAct(GameState state, String playerId) {
    return state.isAlive(playerId) &&
        state.currentTurn == 1 &&
        (state.currentPhase == GamePhase.nightCupid || state.currentPhase.isNight);
  }

  @override
  GameState executeAction(
    GameState state, {
    required String actorId,
    required Map<String, dynamic> actionPayload,
  }) {
    final lover1Id = actionPayload['lover1Id'] as String?;
    final lover2Id = actionPayload['lover2Id'] as String?;

    if (lover1Id == null || lover2Id == null || lover1Id == lover2Id) return state;

    final acknowledged = Set<String>.from(state.nightAcknowledgedPlayerIds)..add(actorId);
    return state.copyWith(nightAcknowledgedPlayerIds: acknowledged);
  }

  @override
  RoleUIControls getUIControls(GameState state, String playerId) {
    return RoleUIControls(
      title: 'Cupidon',
      instruction: 'Désignez deux âmes sœurs. Si l\'une périt, l\'autre meurt instantanément de chagrin.',
      inputType: RoleActionInputType.multipleTargets,
      availableTargetIds: state.alivePlayerIds,
      confirmButtonLabel: 'Lier les deux amoureux',
      canSkip: false,
    );
  }
}
