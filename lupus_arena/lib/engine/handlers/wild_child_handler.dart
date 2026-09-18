import '../../models/game_role.dart';
import '../../models/game_state.dart';
import 'role_action_handler.dart';

class WildChildHandler implements RoleActionHandler {
  @override
  GameRole get role => GameRole.wildChild;

  @override
  bool canAct(GameState state, String playerId) {
    return state.isAlive(playerId) &&
        state.currentTurn == 1 &&
        state.expandedRolesState.wildChildModelId == null;
  }

  @override
  GameState executeAction(
    GameState state, {
    required String actorId,
    required Map<String, dynamic> actionPayload,
  }) {
    final modelId = actionPayload['modelPlayerId'] as String?;
    if (modelId == null) return state;

    final updatedExpanded = state.expandedRolesState.copyWith(wildChildModelId: modelId);
    return state.copyWith(expandedRolesState: updatedExpanded);
  }

  /// Déclenché lors de n'importe quelle élimination pour vérifier la mutation
  static GameState checkModelDeath(GameState state, String deadPlayerId) {
    if (state.expandedRolesState.wildChildModelId == deadPlayerId &&
        !state.expandedRolesState.wildChildTransformed) {
      final updatedExpanded = state.expandedRolesState.copyWith(wildChildTransformed: true);
      return state.copyWith(expandedRolesState: updatedExpanded);
    }
    return state;
  }

  @override
  RoleUIControls getUIControls(GameState state, String playerId) {
    return RoleUIControls(
      title: 'L\'Enfant Sauvage',
      instruction: 'Désignez votre modèle protecteur. Si ce joueur meurt, vous deviendrez Loup-Garou.',
      inputType: RoleActionInputType.singleTarget,
      availableTargetIds: state.alivePlayerIds.where((id) => id != playerId).toList(),
      confirmButtonLabel: 'Choisir ce modèle',
      canSkip: false,
    );
  }
}
