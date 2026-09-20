import '../../models/game_role.dart';
import '../../models/game_state.dart';
import 'role_action_handler.dart';

/// Gestionnaire de rôle pour L'Idiot du Village.
/// S'il est condamné par le vote du village, il est gracié mais perd définitivement son droit de vote.
class IdiotHandler extends RoleActionHandler {
  @override
  GameRole get role => GameRole.idiot;

  @override
  bool canAct(GameState state, String playerId) {
    return state.isAlive(playerId) && state.pendingExecutedPlayerId == playerId;
  }

  @override
  GameState executeAction(
    GameState state, {
    required String actorId,
    required Map<String, dynamic> actionPayload,
  }) {
    // Si l'idiot est exécuté, on annule l'exécution et on lui retire son droit de vote
    final banned = Set<String>.from(state.expandedRolesState.bannedVotersForToday)..add(actorId);
    final updated = state.expandedRolesState.copyWith(bannedVotersForToday: banned);

    return state.copyWith(
      pendingExecutedPlayerId: null, // Gracié !
      expandedRolesState: updated,
    );
  }

  @override
  RoleUIControls getUIControls(GameState state, String playerId) {
    return const RoleUIControls(
      title: 'L\'Idiot du Village',
      instruction: 'Si le village vous condamne, vous êtes immédiatement gracié mais perdez votre droit de vote.',
      inputType: RoleActionInputType.none,
    );
  }
}
