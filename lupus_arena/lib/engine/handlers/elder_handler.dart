import '../../models/game_role.dart';
import '../../models/game_state.dart';
import 'role_action_handler.dart';

class ElderHandler implements RoleActionHandler {
  @override
  GameRole get role => GameRole.elder;

  @override
  bool canAct(GameState state, String playerId) => false; // Passif

  @override
  GameState executeAction(
    GameState state, {
    required String actorId,
    required Map<String, dynamic> actionPayload,
  }) =>
      state;

  /// Résolution de l'attaque des loups sur l'Ancien
  static GameState handleWolfAttack(GameState state, String elderId) {
    final currentLives = state.expandedRolesState.ancientLives[elderId] ?? 2;
    if (currentLives > 1) {
      // Survit à la 1re attaque de loup
      final updatedLives = Map<String, int>.from(state.expandedRolesState.ancientLives)
        ..[elderId] = currentLives - 1;
      return state.copyWith(
        expandedRolesState: state.expandedRolesState.copyWith(ancientLives: updatedLives),
      );
    } else {
      // 2e morsure : élimination standard
      return state.killPlayer(elderId, eliminationSource: 'wolves');
    }
  }

  /// Résolution en cas de lynchage ou tir par le village
  static GameState handleVillageKill(GameState state, String elderId) {
    final updatedExpanded = state.expandedRolesState.copyWith(ancientPowerLost: true);
    return state.copyWith(expandedRolesState: updatedExpanded);
  }

  @override
  RoleUIControls getUIControls(GameState state, String playerId) => RoleUIControls.empty;
}
