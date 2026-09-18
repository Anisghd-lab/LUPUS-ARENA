import '../../models/game_role.dart';
import '../../models/game_state.dart';
import 'role_action_handler.dart';

class BearTamerHandler implements RoleActionHandler {
  @override
  GameRole get role => GameRole.bearTamer;

  @override
  bool canAct(GameState state, String playerId) => false; // Automatisé à l'aube

  @override
  GameState executeAction(
    GameState state, {
    required String actorId,
    required Map<String, dynamic> actionPayload,
  }) => state;

  /// Méthode d'arbitrage appelée lors de la résolution de l'aube
  static GameState resolveMorningGrowl(GameState state) {
    final bearTamerEntry = state.playerRoles.entries
        .firstWhere((e) => e.value == GameRole.bearTamer && state.isAlive(e.key),
            orElse: () => const MapEntry('', GameRole.simpleVillager));

    if (bearTamerEntry.key.isEmpty) return state;

    final tamerId = bearTamerEntry.key;
    final isInfected = tamerId == state.expandedRolesState.infectedPlayerId;
    bool shouldGrowl = isInfected;

    if (!shouldGrowl) {
      final alive = state.alivePlayerIdsInOrder;
      final idx = alive.indexOf(tamerId);
      if (idx != -1) {
        final n = alive.length;
        final left = alive[(idx - 1 + n) % n];
        final right = alive[(idx + 1) % n];

        shouldGrowl = [left, right].any((id) {
          final r = state.playerRoles[id];
          return r?.camp == Camp.wolves || id == state.expandedRolesState.infectedPlayerId;
        });
      }
    }

    final updatedExpanded = state.expandedRolesState.copyWith(bearGrowledThisMorning: shouldGrowl);
    return state.copyWith(expandedRolesState: updatedExpanded);
  }

  @override
  RoleUIControls getUIControls(GameState state, String playerId) => RoleUIControls.empty;
}
