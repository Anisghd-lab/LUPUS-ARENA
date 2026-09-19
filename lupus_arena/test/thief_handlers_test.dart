import 'package:flutter_test/flutter_test.dart';
import 'package:lupus_arena/models/game_role.dart';
import 'package:lupus_arena/models/game_state.dart';
import 'package:lupus_arena/models/player_model.dart';
import 'package:lupus_arena/engine/handlers/role_handlers_registry.dart';
import 'package:lupus_arena/engine/handlers/thief_handler.dart';
import 'package:lupus_arena/engine/handlers/soul_stealer_handler.dart';
import 'package:lupus_arena/engine/handlers/role_action_handler.dart';
import 'package:lupus_arena/services/death_registry_service.dart';

void main() {
  setUp(() {
    DeathRegistryService.instance.clearForNewGame();
  });

  group('ThiefHandler & SoulStealerHandler Tests', () {
    test('Registry contains ThiefHandler and SoulStealerHandler', () {
      final thiefHandler = RoleHandlersRegistry.getHandlerFor(GameRole.thief);
      expect(thiefHandler, isNotNull);
      expect(thiefHandler, isA<ThiefHandler>());

      final soulStealerHandler =
          RoleHandlersRegistry.getHandlerFor(GameRole.thiefOfHearts);
      expect(soulStealerHandler, isNotNull);
      expect(soulStealerHandler, isA<SoulStealerHandler>());
    });

    test('ThiefHandler: canAct validates turn and alive status', () {
      final handler = ThiefHandler();

      final stateTurn1 = GameState(
        currentTurn: 1,
        players: {
          'p1': PlayerModel(id: 'p1', name: 'Alice', isAlive: true, role: GameRole.thief),
          'p2': PlayerModel(id: 'p2', name: 'Bob', isAlive: false, role: GameRole.thief),
        },
      );

      expect(handler.canAct(stateTurn1, 'p1'), isTrue);
      expect(handler.canAct(stateTurn1, 'p2'), isFalse);

      final stateTurn2 = GameState(
        currentTurn: 2,
        players: {
          'p1': PlayerModel(id: 'p1', name: 'Alice', isAlive: true, role: GameRole.thief),
        },
      );

      expect(handler.canAct(stateTurn2, 'p1'), isFalse);
    });

    test('ThiefHandler: steals role and assigns simpleVillager to victim', () {
      final state = GameState(
        currentTurn: 1,
        players: {
          'thief': PlayerModel(id: 'thief', name: 'Thief', isAlive: true, role: GameRole.thief),
          'victim': PlayerModel(id: 'victim', name: 'Seer', isAlive: true, role: GameRole.seer),
        },
        playerRoles: {
          'thief': GameRole.thief,
          'victim': GameRole.seer,
        },
      );

      final nextState = RoleHandlersRegistry.dispatchAction(
        state,
        role: GameRole.thief,
        actorId: 'thief',
        payload: {'targetId': 'victim'},
      );

      expect(nextState.playerRoles['thief'], equals(GameRole.seer));
      expect(nextState.playerRoles['victim'], equals(GameRole.simpleVillager));
    });

    test('ThiefHandler: chooses role from available cards', () {
      final state = GameState(
        currentTurn: 1,
        players: {
          'thief': PlayerModel(id: 'thief', name: 'Thief', isAlive: true, role: GameRole.thief),
        },
        playerRoles: {
          'thief': GameRole.thief,
        },
      );

      final nextState = RoleHandlersRegistry.dispatchAction(
        state,
        role: GameRole.thief,
        actorId: 'thief',
        payload: {'chosenRole': GameRole.werewolf},
      );

      expect(nextState.playerRoles['thief'], equals(GameRole.werewolf));
    });

    test('ThiefHandler: skip preserves current role', () {
      final state = GameState(
        currentTurn: 1,
        players: {
          'thief': PlayerModel(id: 'thief', name: 'Thief', isAlive: true, role: GameRole.thief),
          'victim': PlayerModel(id: 'victim', name: 'Seer', isAlive: true, role: GameRole.seer),
        },
        playerRoles: {
          'thief': GameRole.thief,
          'victim': GameRole.seer,
        },
      );

      final nextState = RoleHandlersRegistry.dispatchAction(
        state,
        role: GameRole.thief,
        actorId: 'thief',
        payload: {'skip': true, 'targetId': 'victim'},
      );

      expect(nextState.playerRoles['thief'], equals(GameRole.thief));
      expect(nextState.playerRoles['victim'], equals(GameRole.seer));
    });

    test('SoulStealerHandler: steals role and assigns simpleVillager to victim', () {
      final state = GameState(
        currentTurn: 1,
        players: {
          'soul_stealer': PlayerModel(id: 'soul_stealer', name: 'Stealer', isAlive: true, role: GameRole.thiefOfHearts),
          'victim': PlayerModel(id: 'victim', name: 'Hunter', isAlive: true, role: GameRole.hunter),
        },
        playerRoles: {
          'soul_stealer': GameRole.thiefOfHearts,
          'victim': GameRole.hunter,
        },
      );

      final nextState = RoleHandlersRegistry.dispatchAction(
        state,
        role: GameRole.thiefOfHearts,
        actorId: 'soul_stealer',
        payload: {'targetId': 'victim'},
      );

      expect(nextState.playerRoles['soul_stealer'], equals(GameRole.hunter));
      expect(nextState.playerRoles['victim'], equals(GameRole.simpleVillager));
    });

    test('UI controls are provided for both Thief and SoulStealer', () {
      final state = GameState(
        currentTurn: 1,
        players: {
          'p1': PlayerModel(id: 'p1', name: 'Thief', isAlive: true, role: GameRole.thief),
          'p2': PlayerModel(id: 'p2', name: 'Target', isAlive: true, role: GameRole.villager),
        },
        playerRoles: {
          'p1': GameRole.thief,
          'p2': GameRole.villager,
        },
      );

      final controlsThief = RoleHandlersRegistry.getControls(state, 'p1');
      expect(controlsThief.inputType, equals(RoleActionInputType.singleTarget));
      expect(controlsThief.canSkip, isTrue);
      expect(controlsThief.availableTargetIds, contains('p2'));

      final state2 = state.copyWith(
        playerRoles: {
          'p1': GameRole.thiefOfHearts,
          'p2': GameRole.villager,
        },
      );
      final controlsSoulStealer = RoleHandlersRegistry.getControls(state2, 'p1');
      expect(controlsSoulStealer.inputType, equals(RoleActionInputType.singleTarget));
      expect(controlsSoulStealer.canSkip, isTrue);
      expect(controlsSoulStealer.availableTargetIds, contains('p2'));
    });
  });
}
