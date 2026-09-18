import '../../models/game_role.dart';
import '../../models/game_state.dart';
import 'role_action_handler.dart';

class ScapegoatHandler implements RoleActionHandler {
  @override
  GameRole get role => GameRole.scapegoat;

  @override
  bool canAct(GameState state, String playerId) {
    // Activable lors de son testament post-mortem si éliminé par égalité
    return state.lastEliminatedPlayerId == playerId &&
        state.expandedRolesState.scapegoatNeedsToBan;
  }

  @override
  GameState executeAction(
    GameState state, {
    required String actorId,
    required Map<String, dynamic> actionPayload,
  }) {
    final bannedIds = List<String>.from(actionPayload['bannedVoterIds'] ?? []);
    final updatedExpanded = state.expandedRolesState.copyWith(
      bannedVotersForToday: bannedIds.toSet(),
      scapegoatNeedsToBan: false,
    );
    return state.copyWith(expandedRolesState: updatedExpanded);
  }

  @override
  RoleUIControls getUIControls(GameState state, String playerId) {
    return RoleUIControls(
      title: 'Le Bouc Émissaire',
      instruction: 'En mourant pour le village, désignez les joueurs qui seront privés de vote demain.',
      inputType: RoleActionInputType.multipleTargets,
      availableTargetIds: state.alivePlayerIds,
      confirmButtonLabel: 'Valider l\'interdiction de vote',
      canSkip: false,
    );
  }
}
