import '../../models/game_role.dart';
import '../../models/game_state.dart';
import 'role_action_handler.dart';

class ActorHandler implements RoleActionHandler {
  @override
  GameRole get role => GameRole.actor;

  @override
  bool canAct(GameState state, String playerId) {
    final available = state.expandedRolesState.actorAvailableRoles[playerId] ?? [];
    return state.isAlive(playerId) && available.isNotEmpty;
  }

  @override
  GameState executeAction(
    GameState state, {
    required String actorId,
    required Map<String, dynamic> actionPayload,
  }) {
    final skip = actionPayload['skip'] as bool? ?? false;
    if (skip) return state;

    final roleStr = actionPayload['chosenRole'] as String?;
    if (roleStr == null) return state;

    final chosenRole = GameRole.values.firstWhere(
      (r) => r.name == roleStr || r.id == roleStr,
      orElse: () => GameRole.simpleVillager,
    );

    final available = List<GameRole>.from(
      state.expandedRolesState.actorAvailableRoles[actorId] ?? [],
    )..remove(chosenRole);

    final updatedActorMap = Map<String, List<GameRole>>.from(
      state.expandedRolesState.actorAvailableRoles,
    );
    updatedActorMap[actorId] = available;

    return state.copyWith(
      expandedRolesState: state.expandedRolesState.copyWith(
        actorAvailableRoles: updatedActorMap,
      ),
    );
  }

  @override
  RoleUIControls getUIControls(GameState state, String playerId) {
    final available = state.expandedRolesState.actorAvailableRoles[playerId] ?? [];
    return RoleUIControls(
      title: 'Le Comédien',
      instruction: 'Choisissez un rôle à incarner pour cette nuit parmi les cartes écartées.',
      inputType: RoleActionInputType.roleChoice,
      availableRoles: available,
      confirmButtonLabel: 'Incarner ce rôle',
      skipButtonLabel: 'Ne rien jouer ce soir',
      canSkip: true,
    );
  }
}
