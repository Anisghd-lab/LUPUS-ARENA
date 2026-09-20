import '../../models/game_phase.dart';
import '../../models/game_role.dart';
import '../../models/game_state.dart';
import 'role_action_handler.dart';

/// Gestionnaire de rôle pour Le Loup-Garou Blanc.
/// Il se réveille une nuit sur deux (nuits paires) pour éliminer un autre loup en secret,
/// ou passer son tour pour ne pas éveiller les soupçons.
class WhiteWerewolfHandler extends RoleActionHandler {
  @override
  GameRole get role => GameRole.whiteWerewolf;

  @override
  bool canAct(GameState state, String playerId) {
    if (!state.isAlive(playerId)) return false;
    final isEvenNight = state.currentTurn > 1 && (state.currentTurn % 2 == 0);
    final isWhiteWolfPhase = state.currentPhase == GamePhase.nightWhiteWerewolf ||
        (isEvenNight && state.currentPhase == GamePhase.nightWerewolves);
    return isWhiteWolfPhase;
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

    final targetId = actionPayload['targetId'] as String?;
    if (targetId == null || !state.isAlive(targetId)) return state;

    // La cible doit être un loup
    final targetRole = state.playerRoles[targetId];
    final isWolf = targetRole?.camp == Camp.wolves ||
        targetId == state.expandedRolesState.infectedPlayerId;

    if (!isWolf) return state;

    final secondaryDeaths = List<String>.from(state.nightSecondaryDeaths)..add(targetId);
    final acknowledged = Set<String>.from(state.nightAcknowledgedPlayerIds)..add(actorId);

    return state.copyWith(
      nightSecondaryDeaths: secondaryDeaths,
      nightAcknowledgedPlayerIds: acknowledged,
    );
  }

  @override
  RoleUIControls getUIControls(GameState state, String playerId) {
    // Liste des autres loups vivants éligibles
    final wolfTargets = state.alivePlayerIds.where((id) {
      if (id == playerId) return false;
      final r = state.playerRoles[id];
      return r?.camp == Camp.wolves || id == state.expandedRolesState.infectedPlayerId;
    }).toList();

    return RoleUIControls(
      title: 'Loup-Garou Blanc',
      instruction: 'Nuit paire : vous pouvez dévorer un loup de votre meute ou passer.',
      inputType: RoleActionInputType.singleTarget,
      availableTargetIds: wolfTargets,
      confirmButtonLabel: 'Dévorer ce loup',
      skipButtonLabel: 'Épargner la meute cette nuit',
      canSkip: true,
    );
  }
}
