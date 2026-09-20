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
    if (targetId == state.lastProtectedPlayerId) return state; // Règle anti-répétition consécutive

    final acknowledged = Set<String>.from(state.nightAcknowledgedPlayerIds)..add(actorId);
    return state.copyWith(
      currentProtectedPlayerId: targetId,
      nightAcknowledgedPlayerIds: acknowledged,
    );
  }

  @override
  RoleUIControls getUIControls(GameState state, String playerId) {
    // Exclure la cible protégée lors de la nuit précédente
    final targets = state.alivePlayerIds
        .where((id) => id != state.lastProtectedPlayerId)
        .toList();

    return RoleUIControls(
      title: 'Le Salvateur',
      instruction: 'Choisissez un joueur à protéger cette nuit contre les griffes des loups (interdiction de protéger le même joueur deux nuits consécutives).',
      inputType: RoleActionInputType.singleTarget,
      availableTargetIds: targets,
      confirmButtonLabel: 'Protéger ce joueur',
      canSkip: false,
    );
  }
}
