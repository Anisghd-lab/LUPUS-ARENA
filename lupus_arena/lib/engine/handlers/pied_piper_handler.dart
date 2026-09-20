import '../../models/game_phase.dart';
import '../../models/game_role.dart';
import '../../models/game_state.dart';
import '../../models/player_model.dart';
import 'role_action_handler.dart';

/// Gestionnaire de rôle pour Le Joueur de Flûte.
/// Chaque nuit, il charme deux joueurs vivants.
/// S'il parvient à charmer l'intégralité des survivants, il remporte la partie seul.
class PiedPiperHandler extends RoleActionHandler {
  @override
  GameRole get role => GameRole.piedPiper;

  @override
  bool canAct(GameState state, String playerId) {
    return state.isAlive(playerId) &&
        (state.currentPhase == GamePhase.nightPiper ||
            state.currentPhase.isNight);
  }

  @override
  GameState executeAction(
    GameState state, {
    required String actorId,
    required Map<String, dynamic> actionPayload,
  }) {
    final targets = (actionPayload['targetIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    if (targets.isEmpty) return state;

    final acknowledged = Set<String>.from(state.nightAcknowledgedPlayerIds)..add(actorId);

    // Mettre à jour les joueurs charmés dans l'état
    final updatedPlayers = Map<String, PlayerModel>.from(state.players);
    for (final tid in targets) {
      if (updatedPlayers.containsKey(tid)) {
        final p = state.players[tid]!;
        updatedPlayers[tid] = p.copyWith(isCharmed: true);
      }
    }

    return state.copyWith(
      players: updatedPlayers,
      nightAcknowledgedPlayerIds: acknowledged,
    );
  }

  @override
  RoleUIControls getUIControls(GameState state, String playerId) {
    final uncharmedTargets = state.alivePlayerIds.where((id) {
      if (id == playerId) return false;
      final p = state.players[id];
      return p?.isCharmed != true;
    }).toList();

    return RoleUIControls(
      title: 'Le Joueur de Flûte',
      instruction: 'Sélectionnez deux villageois à envoûter par votre mélodie cette nuit.',
      inputType: RoleActionInputType.multipleTargets,
      availableTargetIds: uncharmedTargets,
      confirmButtonLabel: 'Envoûter les cibles',
      canSkip: false,
    );
  }
}
