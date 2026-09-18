import '../../models/game_role.dart';
import '../../models/game_state.dart';
import 'role_action_handler.dart';

class RustySwordKnightHandler extends RoleActionHandler {
  @override
  GameRole get role => GameRole.knightRustySword;

  @override
  bool canAct(GameState state, String playerId) => false; // Passif à la mort

  @override
  GameState executeAction(
    GameState state, {
    required String actorId,
    required Map<String, dynamic> actionPayload,
  }) => state;

  /// Appelé si le chevalier est dévoré la nuit par les loups
  static GameState onDevouredByWolves(GameState state, String knightId) {
    final alive = state.alivePlayerIdsInOrder;
    final startIndex = alive.indexOf(knightId);
    if (startIndex == -1) return state;

    final n = alive.length;
    String? contaminatedWolfId;

    // Premier loup à sa gauche (indice - 1 circulaire)
    for (int i = 1; i < n; i++) {
      final candId = alive[(startIndex - i + n) % n];
      final r = state.playerRoles[candId];
      if (r?.camp == Camp.wolves || candId == state.expandedRolesState.infectedPlayerId) {
        contaminatedWolfId = candId;
        break;
      }
    }

    final updated = state.expandedRolesState.copyWith(
      rustyKnightContaminatedWolfId: contaminatedWolfId,
      rustyKnightDeathNight: state.currentTurn,
    );
    return state.copyWith(expandedRolesState: updated);
  }

  @override
  RoleUIControls getUIControls(GameState state, String playerId) => RoleUIControls.empty;
}
