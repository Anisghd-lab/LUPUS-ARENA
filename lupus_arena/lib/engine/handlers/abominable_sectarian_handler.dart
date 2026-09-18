import '../../models/game_role.dart';
import '../../models/game_state.dart';
import 'role_action_handler.dart';

class AbominableSectarianHandler implements RoleActionHandler {
  @override
  GameRole get role => GameRole.sectLeader;

  @override
  bool canAct(GameState state, String playerId) {
    return state.isAlive(playerId) &&
        state.currentTurn == 1 &&
        state.expandedRolesState.sectarianTeams.isEmpty;
  }

  @override
  GameState executeAction(
    GameState state, {
    required String actorId,
    required Map<String, dynamic> actionPayload,
  }) {
    final alive = state.alivePlayerIdsInOrder;
    final teamA = <String>[];
    final teamB = <String>[];

    // Répartition canonique équilibrée alternée
    for (int i = 0; i < alive.length; i++) {
      if (i.isEven) {
        teamA.add(alive[i]);
      } else {
        teamB.add(alive[i]);
      }
    }

    final updatedExpanded = state.expandedRolesState.copyWith(
      sectarianTeams: {'teamA': teamA, 'teamB': teamB},
    );
    return state.copyWith(expandedRolesState: updatedExpanded);
  }

  @override
  RoleUIControls getUIControls(GameState state, String playerId) {
    return const RoleUIControls(
      title: 'L\'Abominable Sectaire',
      instruction:
          'Créez les deux clans du village. Vous ne gagnerez que si votre clan survit à l\'autre.',
      inputType: RoleActionInputType.confirmation,
      confirmButtonLabel: 'Scinder le village en deux factions',
      canSkip: false,
    );
  }
}
