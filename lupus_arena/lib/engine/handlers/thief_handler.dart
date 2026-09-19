import '../../models/game_role.dart';
import '../../models/game_state.dart';
import 'role_action_handler.dart';

/// Gestionnaire pour le Voleur standard
class ThiefHandler extends RoleActionHandler {
  @override
  GameRole get role => GameRole.thief;

  @override
  bool canAct(GameState state, String playerId) {
    return state.isAlive(playerId) && state.currentTurn == 1;
  }

  @override
  GameState executeAction(
    GameState state, {
    required String actorId,
    required Map<String, dynamic> actionPayload,
  }) {
    final skip = actionPayload['skip'] as bool? ?? false;
    if (skip) return state;

    final updatedRoles = Map<String, GameRole>.from(state.playerRoles);

    // Option 1 : Choix d'une carte parmi celles non distribuées
    final chosenRole = actionPayload['chosenRole'] as GameRole?;
    if (chosenRole != null) {
      updatedRoles[actorId] = chosenRole;
      return state.copyWith(playerRoles: updatedRoles);
    }

    // Option 2 : Vol d'identité ciblé d'un joueur actif
    final targetId = actionPayload['targetId'] as String?;
    if (targetId == null) return state;

    final targetRole = state.playerRoles[targetId] ?? GameRole.simpleVillager;

    // Échange des identités : le voleur prend le rôle dérobé, la victime devient Simple Villageois
    updatedRoles[actorId] = targetRole;
    updatedRoles[targetId] = GameRole.simpleVillager;

    return state.copyWith(playerRoles: updatedRoles);
  }

  @override
  RoleUIControls getUIControls(GameState state, String playerId) {
    return RoleUIControls(
      title: 'Le Voleur',
      instruction:
          'Dérobez le rôle d\'un citoyen pour vous approprier son destin, ou choisissez une carte.',
      inputType: RoleActionInputType.singleTarget,
      availableTargetIds:
          state.alivePlayerIds.where((id) => id != playerId).toList(),
      confirmButtonLabel: 'Voler la carte',
      skipButtonLabel: 'Rester Voleur',
      canSkip: true,
    );
  }
}
