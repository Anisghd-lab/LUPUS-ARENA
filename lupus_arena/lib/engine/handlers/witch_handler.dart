import '../../models/game_phase.dart';
import '../../models/game_role.dart';
import '../../models/game_state.dart';
import 'role_action_handler.dart';

/// Gestionnaire de rôle pour La Sorcière.
/// Possède deux potions : une de vie (sauver la victime des loups) et une de mort (empoisonner un suspect).
class WitchHandler extends RoleActionHandler {
  @override
  GameRole get role => GameRole.witch;

  @override
  bool canAct(GameState state, String playerId) {
    return state.isAlive(playerId) &&
        (state.currentPhase == GamePhase.nightWitch || state.currentPhase.isNight);
  }

  @override
  GameState executeAction(
    GameState state, {
    required String actorId,
    required Map<String, dynamic> actionPayload,
  }) {
    final save = actionPayload['save'] as bool? ?? false;
    final poisonTargetId = actionPayload['poisonTargetId'] as String?;
    final skip = actionPayload['skip'] as bool? ?? false;

    if (skip) {
      final acknowledged = Set<String>.from(state.nightAcknowledgedPlayerIds)..add(actorId);
      return state.copyWith(nightAcknowledgedPlayerIds: acknowledged);
    }

    String? primaryVictim = state.nightPrimaryVictimId;
    final secondaryDeaths = List<String>.from(state.nightSecondaryDeaths);

    if (save) {
      primaryVictim = null;
    }

    if (poisonTargetId != null && state.isAlive(poisonTargetId)) {
      secondaryDeaths.add(poisonTargetId);
    }

    final acknowledged = Set<String>.from(state.nightAcknowledgedPlayerIds)..add(actorId);

    return state.copyWith(
      nightPrimaryVictimId: primaryVictim,
      clearNightPrimaryVictimId: save,
      nightSecondaryDeaths: secondaryDeaths,
      nightAcknowledgedPlayerIds: acknowledged,
    );
  }

  @override
  RoleUIControls getUIControls(GameState state, String playerId) {
    final victim = state.nightPrimaryVictimId;
    final victimName = victim != null ? state.getPlayerName(victim) : null;

    final instruction = victimName != null
        ? 'Les loups ont attaqué $victimName. Sauvez-le ou empoisonnez un autre suspect.'
        : 'Aucune victime des loups cette nuit. Vous pouvez utiliser votre poison ou passer.';

    return RoleUIControls(
      title: 'La Sorcière',
      instruction: instruction,
      inputType: RoleActionInputType.singleTarget,
      availableTargetIds: state.alivePlayerIds.where((id) => id != playerId).toList(),
      confirmButtonLabel: 'Appliquer les potions',
      skipButtonLabel: 'Passer mon tour',
      canSkip: true,
    );
  }
}
