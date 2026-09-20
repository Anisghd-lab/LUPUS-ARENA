import 'package:flutter_test/flutter_test.dart';
import 'package:lupus_arena/models/game_phase.dart';
import 'package:lupus_arena/models/game_role.dart';
import 'package:lupus_arena/models/game_state.dart';
import 'package:lupus_arena/models/player_model.dart';
import 'package:lupus_arena/models/expanded_roles_state.dart';
import 'package:lupus_arena/services/game_phase_coordinator.dart';
import 'package:lupus_arena/services/death_registry_service.dart';
import 'package:lupus_arena/engine/handlers/role_handlers_registry.dart';
import 'package:lupus_arena/engine/handlers/fox_handler.dart';
import 'package:lupus_arena/engine/handlers/little_girl_handler.dart';
import 'package:lupus_arena/engine/handlers/white_werewolf_handler.dart';
import 'package:lupus_arena/engine/handlers/black_wolf_handler.dart';
import 'package:lupus_arena/engine/handlers/angel_handler.dart';
import 'package:lupus_arena/engine/handlers/idiot_handler.dart';
import 'package:lupus_arena/engine/handlers/pied_piper_handler.dart';
import 'package:lupus_arena/engine/handlers/pyromaniac_handler.dart';

void main() {
  setUp(() {
    DeathRegistryService.instance.clearForNewGame();
  });

  group('Phase Night Monotonicity & Ordering', () {
    test('Ordre nocturne strict et indices ordonnés', () {
      expect(GamePhase.nightThief.nightOrderIndex, equals(1));
      expect(GamePhase.nightCupid.nightOrderIndex, equals(2));
      expect(GamePhase.nightDefender.nightOrderIndex, equals(3));
      expect(GamePhase.nightWerewolves.nightOrderIndex, equals(4));
      expect(GamePhase.nightBlackWolf.nightOrderIndex, equals(5));
      expect(GamePhase.nightWhiteWerewolf.nightOrderIndex, equals(6));
      expect(GamePhase.nightSeer.nightOrderIndex, equals(7));
      expect(GamePhase.nightFox.nightOrderIndex, equals(8));
      expect(GamePhase.nightWitch.nightOrderIndex, equals(9));
      expect(GamePhase.nightPiper.nightOrderIndex, equals(10));
      expect(GamePhase.nightPyromaniac.nightOrderIndex, equals(11));
      expect(GamePhase.morningAnnouncement.nightOrderIndex, equals(12));

      expect(GamePhase.nightFox.isNight, isTrue);
      expect(GamePhase.nightWhiteWerewolf.isNight, isTrue);
    });

    test('GamePhaseCoordinator séquence le Renard et le Loup Blanc correctement', () {
      const coordinator = GamePhaseCoordinator();

      final players = {
        'p1': PlayerModel(id: 'p1', name: 'Wolf', isAlive: true, role: GameRole.simpleWerewolf),
        'p2': PlayerModel(id: 'p2', name: 'WhiteWolf', isAlive: true, role: GameRole.whiteWerewolf),
        'p3': PlayerModel(id: 'p3', name: 'Fox', isAlive: true, role: GameRole.fox),
        'p4': PlayerModel(id: 'p4', name: 'Villager', isAlive: true, role: GameRole.simpleVillager),
      };

      // Tour 2 (nuit paire) : Loup Blanc doit se réveiller après les loups
      final afterWolves = coordinator.getNextNightPhase(
        current: GamePhase.nightBlackWolf,
        round: 2,
        players: players,
        expandedRolesState: const ExpandedRolesState(foxPowerActive: true),
      );
      expect(afterWolves, equals(GamePhase.nightWhiteWerewolf));

      // Après Loup Blanc : Renard actif doit se réveiller
      final afterWhiteWolf = coordinator.getNextNightPhase(
        current: GamePhase.nightWhiteWerewolf,
        round: 2,
        players: players,
        expandedRolesState: const ExpandedRolesState(foxPowerActive: true),
      );
      expect(afterWhiteWolf, equals(GamePhase.nightFox));

      // Si le renard a perdu son flair, il est sauté
      final afterWhiteWolfNoFox = coordinator.getNextNightPhase(
        current: GamePhase.nightWhiteWerewolf,
        round: 2,
        players: players,
        expandedRolesState: const ExpandedRolesState(foxPowerActive: false),
      );
      expect(afterWhiteWolfNoFox, equals(GamePhase.morningAnnouncement));
    });
  });

  group('Role Handlers Registry Tests', () {
    test('Tous les rôles ont un handler enregistré', () {
      expect(RoleHandlersRegistry.getHandlerFor(GameRole.fox), isA<FoxHandler>());
      expect(RoleHandlersRegistry.getHandlerFor(GameRole.littleGirl), isA<LittleGirlHandler>());
      expect(RoleHandlersRegistry.getHandlerFor(GameRole.whiteWerewolf), isA<WhiteWerewolfHandler>());
      expect(RoleHandlersRegistry.getHandlerFor(GameRole.blackWolf), isA<BlackWolfHandler>());
      expect(RoleHandlersRegistry.getHandlerFor(GameRole.angel), isA<AngelHandler>());
      expect(RoleHandlersRegistry.getHandlerFor(GameRole.idiot), isA<IdiotHandler>());
      expect(RoleHandlersRegistry.getHandlerFor(GameRole.piedPiper), isA<PiedPiperHandler>());
      expect(RoleHandlersRegistry.getHandlerFor(GameRole.pyromaniac), isA<PyromaniacHandler>());
    });
  });

  group('FoxHandler Strategic Actions', () {
    test('Le Renard conserve son flair si au moins un loup est dans le trio', () {
      final handler = FoxHandler();
      final state = GameState(
        currentTurn: 1,
        alivePlayerIdsInOrder: ['p1', 'p2', 'p3', 'p4'],
        players: {
          'p1': PlayerModel(id: 'p1', name: 'Fox', isAlive: true, role: GameRole.fox),
          'p2': PlayerModel(id: 'p2', name: 'Innocent', isAlive: true, role: GameRole.simpleVillager),
          'p3': PlayerModel(id: 'p3', name: 'Wolf', isAlive: true, role: GameRole.simpleWerewolf),
          'p4': PlayerModel(id: 'p4', name: 'Innocent2', isAlive: true, role: GameRole.simpleVillager),
        },
        playerRoles: {
          'p1': GameRole.fox,
          'p2': GameRole.simpleVillager,
          'p3': GameRole.simpleWerewolf,
          'p4': GameRole.simpleVillager,
        },
        expandedRolesState: const ExpandedRolesState(foxPowerActive: true),
      );

      // Cible p2 -> trio = p1, p2, p3. p3 est un loup !
      final nextState = handler.executeAction(
        state,
        actorId: 'p1',
        actionPayload: {'targetId': 'p2'},
      );

      expect(nextState.expandedRolesState.foxPowerActive, isTrue);
      expect(nextState.expandedRolesState.lastFoxCheckResult, isTrue);
    });

    test('Le Renard perd son flair si aucun loup n\'est dans le trio', () {
      final handler = FoxHandler();
      final state = GameState(
        currentTurn: 1,
        alivePlayerIdsInOrder: ['p1', 'p2', 'p3', 'p4', 'p5'],
        players: {
          'p1': PlayerModel(id: 'p1', name: 'Fox', isAlive: true, role: GameRole.fox),
          'p2': PlayerModel(id: 'p2', name: 'V1', isAlive: true, role: GameRole.simpleVillager),
          'p3': PlayerModel(id: 'p3', name: 'V2', isAlive: true, role: GameRole.simpleVillager),
          'p4': PlayerModel(id: 'p4', name: 'V3', isAlive: true, role: GameRole.simpleVillager),
          'p5': PlayerModel(id: 'p5', name: 'Wolf', isAlive: true, role: GameRole.simpleWerewolf),
        },
        playerRoles: {
          'p1': GameRole.fox,
          'p2': GameRole.simpleVillager,
          'p3': GameRole.simpleVillager,
          'p4': GameRole.simpleVillager,
          'p5': GameRole.simpleWerewolf,
        },
        expandedRolesState: const ExpandedRolesState(foxPowerActive: true),
      );

      // Cible p3 -> trio = p2, p3, p4. Aucun loup !
      final nextState = handler.executeAction(
        state,
        actorId: 'p1',
        actionPayload: {'targetId': 'p3'},
      );

      expect(nextState.expandedRolesState.foxPowerActive, isFalse);
      expect(nextState.expandedRolesState.lastFoxCheckResult, isFalse);
    });

    test('Le Renard peut passer son tour et préserver son pouvoir', () {
      final handler = FoxHandler();
      const state = GameState(
        currentTurn: 1,
        expandedRolesState: ExpandedRolesState(foxPowerActive: true),
      );

      final nextState = handler.executeAction(
        state,
        actorId: 'p1',
        actionPayload: {'skip': true},
      );

      expect(nextState.expandedRolesState.foxPowerActive, isTrue);
    });
  });

  group('LittleGirlHandler Tests', () {
    test('canAct valide la nuit des loups et la survie', () {
      final handler = LittleGirlHandler();

      final state = GameState(
        currentPhase: GamePhase.nightWerewolves,
        players: {
          'lg': PlayerModel(id: 'lg', name: 'Petite Fille', isAlive: true, role: GameRole.littleGirl),
          'dead': PlayerModel(id: 'dead', name: 'Morte', isAlive: false, role: GameRole.littleGirl),
        },
      );

      expect(handler.canAct(state, 'lg'), isTrue);
      expect(handler.canAct(state, 'dead'), isFalse);
    });

    test('Fournit les contrôles UI avec télémétrie de la proie des loups', () {
      final handler = LittleGirlHandler();

      final state = GameState(
        currentPhase: GamePhase.nightWerewolves,
        nightPrimaryVictimId: 'victim1',
        players: {
          'lg': PlayerModel(id: 'lg', name: 'Petite Fille', isAlive: true, role: GameRole.littleGirl),
          'victim1': PlayerModel(id: 'victim1', name: 'Thomas', isAlive: true, role: GameRole.simpleVillager),
        },
      );

      final controls = handler.getUIControls(state, 'lg');
      expect(controls.title, equals('La Petite Fille'));
      expect(controls.instruction, contains('Thomas'));
      expect(controls.canSkip, isTrue);
    });
  });

  group('WhiteWerewolfHandler Strategic Actions', () {
    test('Ne peut agir que lors des tours pairs', () {
      final handler = WhiteWerewolfHandler();

      final stateOdd = GameState(
        currentTurn: 1,
        currentPhase: GamePhase.nightWhiteWerewolf,
        players: {
          'ww': PlayerModel(id: 'ww', name: 'Loup Blanc', isAlive: true, role: GameRole.whiteWerewolf),
        },
      );
      expect(handler.canAct(stateOdd, 'ww'), isFalse);

      final stateEven = GameState(
        currentTurn: 2,
        currentPhase: GamePhase.nightWhiteWerewolf,
        players: {
          'ww': PlayerModel(id: 'ww', name: 'Loup Blanc', isAlive: true, role: GameRole.whiteWerewolf),
        },
      );
      expect(handler.canAct(stateEven, 'ww'), isTrue);
    });

    test('Élimine un membre de la meute et l\'ajoute aux morts secondaires', () {
      final handler = WhiteWerewolfHandler();

      final state = GameState(
        currentTurn: 2,
        currentPhase: GamePhase.nightWhiteWerewolf,
        players: {
          'ww': PlayerModel(id: 'ww', name: 'Loup Blanc', isAlive: true, role: GameRole.whiteWerewolf),
          'wolf': PlayerModel(id: 'wolf', name: 'Loup Simple', isAlive: true, role: GameRole.simpleWerewolf),
        },
        playerRoles: {
          'ww': GameRole.whiteWerewolf,
          'wolf': GameRole.simpleWerewolf,
        },
      );

      final nextState = handler.executeAction(
        state,
        actorId: 'ww',
        actionPayload: {'targetId': 'wolf'},
      );

      expect(nextState.nightSecondaryDeaths, contains('wolf'));
    });
  });
}
