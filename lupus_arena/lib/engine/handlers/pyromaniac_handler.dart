import '../../models/game_phase.dart';
import '../../models/game_state.dart';
import '../../models/player_model.dart';
import 'role_action_handler.dart';

/// Gestionnaire de rôle pour Le Pyromane.
/// Chaque nuit, il choisit d'asperger une maison d'essence ou d'enflammer toutes les maisons aspergées.
class PyromaniacHandler extends RoleActionHandler {
  @override
  GameRole get role => GameRole.pyromaniac;

  @override
  bool canAct(GameState state, String playerId) {
    return state.isAlive(playerId) &&
        (state.currentPhase == GamePhase.nightPyromaniac ||
            state.currentPhase.isNight);
  }

  @override
  GameState executeAction(
    GameState state, {
    required String actorId,
    required Map<String, dynamic> actionPayload,
  }) {
    final skip = actionPayload['skip'] as bool? ?? false;
    if (skip) {
      final acknowledged = Set<String>.from(state.nightAcknowledgedPlayerIds)..add(actorId);
      return state.copyWith(nightAcknowledgedPlayerIds: acknowledged);
    }

    final action = actionPayload['action'] as String?;
    final targetId = actionPayload['targetId'] as String?;

    if (action == 'ignite') {
      // Éliminer tous les joueurs aspergés
      final dousedIds = state.alivePlayerIds.where((id) {
        return state.players[id]?.isDoused == true;
      }).toList();

      final secondaryDeaths = List<String>.from(state.nightSecondaryDeaths)..addAll(dousedIds);
      final acknowledged = Set<String>.from(state.nightAcknowledgedPlayerIds)..add(actorId);

      return state.copyWith(
        nightSecondaryDeaths: secondaryDeaths,
        nightAcknowledgedPlayerIds: acknowledged,
      );
    } else if (action == 'douse' && targetId != null && state.isAlive(targetId)) {
      final updatedPlayers = Map<String, PlayerModel>.from(state.players);
      if (updatedPlayers.containsKey(targetId)) {
        updatedPlayers[targetId] = updatedPlayers[targetId]!.copyWith(isDoused: true);
      }
      final acknowledged = Set<String>.from(state.nightAcknowledgedPlayerIds)..add(actorId);
      return state.copyWith(
        players: updatedPlayers,
        nightAcknowledgedPlayerIds: acknowledged,
      );
    }

    return state;
  }

  @override
  RoleUIControls getUIControls(GameState state, String playerId) {
    final targets = state.alivePlayerIds.where((id) => id != playerId).toList();

    return RoleUIControls(
      title: 'Le Pyromane',
      instruction: 'Aspergez une demeure d\'essence ou embrasez tous les foyers imbibés.',
      inputType: RoleActionInputType.singleTarget,
      availableTargetIds: targets,
      confirmButtonLabel: 'Asperger d\'essence',
      skipButtonLabel: 'Passer cette nuit',
      canSkip: true,
    );
  }
}
