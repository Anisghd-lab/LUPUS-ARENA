import '../../models/game_role.dart';
import '../../models/game_state.dart';
import 'role_action_handler.dart';

class BigBadWolfHandler implements RoleActionHandler {
  @override
  GameRole get role => GameRole.bigBadWolf;

  @override
  bool canAct(GameState state, String playerId) {
    final hasDeadWolves = state.playerRoles.entries.any(
      (e) => e.value.camp == Camp.wolves && !state.isAlive(e.key),
    );
    return state.isAlive(playerId) && !hasDeadWolves;
  }

  @override
  GameState executeAction(
    GameState state, {
    required String actorId,
    required Map<String, dynamic> actionPayload,
  }) {
    final targetId = actionPayload['targetId'] as String?;
    if (targetId == null) return state;

    final secondaryDeaths = List<String>.from(state.nightSecondaryDeaths)..add(targetId);
    return state.copyWith(nightSecondaryDeaths: secondaryDeaths);
  }

  @override
  RoleUIControls getUIControls(GameState state, String playerId) {
    final nonWolfAliveTargets = state.alivePlayerIds.where((id) {
      final r = state.playerRoles[id];
      return r?.camp != Camp.wolves && id != state.expandedRolesState.infectedPlayerId;
    }).toList();

    return RoleUIControls(
      title: 'Le Grand Méchant Loup',
      instruction: 'Aucun loup n\'est mort. Dévorez une seconde victime cette nuit.',
      inputType: RoleActionInputType.singleTarget,
      availableTargetIds: nonWolfAliveTargets,
      confirmButtonLabel: 'Dévorer cette cible',
      canSkip: false,
    );
  }
}
