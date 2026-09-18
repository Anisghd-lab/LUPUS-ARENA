import '../../models/game_role.dart';
import '../../models/game_state.dart';
import 'role_action_handler.dart';

class WolfCubHandler implements RoleActionHandler {
  @override
  GameRole get role => GameRole.wolfCub;

  @override
  bool canAct(GameState state, String playerId) => false; // Passif

  @override
  GameState executeAction(
    GameState state, {
    required String actorId,
    required Map<String, dynamic> actionPayload,
  }) =>
      state;

  /// Déclenché lors du trépas du chiot loup
  static GameState onCubDeath(GameState state) {
    final updatedExpanded = state.expandedRolesState.copyWith(cubDiedYesterday: true);
    return state.copyWith(expandedRolesState: updatedExpanded);
  }

  @override
  RoleUIControls getUIControls(GameState state, String playerId) => RoleUIControls.empty;
}
