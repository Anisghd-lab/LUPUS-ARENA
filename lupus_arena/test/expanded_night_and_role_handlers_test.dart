import 'package:flutter_test/flutter_test.dart';
import 'package:lupus_arena/models/game_phase.dart';
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
import 'package:lupus_arena/engine/handlers/cupid_handler.dart';
import 'package:lupus_arena/engine/handlers/defender_handler.dart';
import 'package:lupus_arena/engine/handlers/hunter_handler.dart';
import 'package:lupus_arena/engine/handlers/seer_handler.dart';
import 'package:lupus_arena/engine/handlers/witch_handler.dart';
import 'package:lupus_arena/engine/handlers/crow_handler.dart';
import 'package:lupus_arena/engine/handlers/bear_tamer_handler.dart';
import 'package:lupus_arena/engine/handlers/rusty_sword_knight_handler.dart';
import 'package:lupus_arena/engine/handlers/elder_handler.dart';
import 'package:lupus_arena/engine/handlers/wild_child_handler.dart';
import 'package:lupus_arena/engine/handlers/infect_father_of_wolves_handler.dart';
import 'package:lupus_arena/engine/handlers/big_bad_wolf_handler.dart';
import 'package:lupus_arena/engine/handlers/wolf_cub_handler.dart';
import 'package:lupus_arena/engine/handlers/stuttering_judge_handler.dart';
import 'package:lupus_arena/engine/handlers/scapegoat_handler.dart';
import 'package:lupus_arena/engine/handlers/devoted_servant_handler.dart';
import 'package:lupus_arena/engine/handlers/actor_handler.dart';
import 'package:lupus_arena/engine/handlers/thief_handler.dart';
import 'package:lupus_arena/engine/handlers/abominable_sectarian_handler.dart';
import 'package:lupus_arena/engine/handlers/soul_stealer_handler.dart';
import 'package:lupus_arena/engine/handlers/two_sisters_handler.dart';
import 'package:lupus_arena/engine/handlers/three_brothers_handler.dart';
import 'package:lupus_arena/services/fog_of_war_service.dart';

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
      expect(nextState.players['p1']!.isSniffed, isTrue);
      expect(nextState.players['p1']!.hasWolfSmell, isTrue);
      expect(nextState.players['p2']!.isSniffed, isTrue);
      expect(nextState.players['p2']!.hasWolfSmell, isTrue);
      expect(nextState.players['p3']!.isSniffed, isTrue);
      expect(nextState.players['p3']!.hasWolfSmell, isTrue);
      expect(nextState.players['p4']!.isSniffed, isFalse);
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
      expect(nextState.players['p2']!.isSniffed, isTrue);
      expect(nextState.players['p2']!.hasWolfSmell, isFalse);
      expect(nextState.players['p3']!.isSniffed, isTrue);
      expect(nextState.players['p3']!.hasWolfSmell, isFalse);
      expect(nextState.players['p4']!.isSniffed, isTrue);
      expect(nextState.players['p4']!.hasWolfSmell, isFalse);
      expect(nextState.players['p1']!.isSniffed, isFalse);
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

  group('IdiotHandler Directive Tests', () {
    test('Gracié au premier vote et privé définitivement de vote', () {
      final handler = IdiotHandler();
      final state = GameState(
        currentTurn: 1,
        currentPhase: GamePhase.dayVoting,
        pendingExecutedPlayerId: 'idiot1',
        players: {
          'idiot1': const PlayerModel(id: 'idiot1', name: 'Idiot', isAlive: true, role: GameRole.idiot),
        },
      );

      final nextState = handler.executeAction(
        state,
        actorId: 'idiot1',
        actionPayload: {},
      );

      expect(nextState.pendingExecutedPlayerId, isNull, reason: 'L\'Idiot est gracié');
      expect(nextState.expandedRolesState.idiotPardoned, isTrue);
      expect(nextState.expandedRolesState.permanentlyBannedVoters, contains('idiot1'));
    });

    test('Exécuté au second vote si déjà gracié dans le passé', () {
      final handler = IdiotHandler();
      final state = GameState(
        currentTurn: 2,
        currentPhase: GamePhase.dayVoting,
        pendingExecutedPlayerId: 'idiot1',
        expandedRolesState: const ExpandedRolesState(
          idiotPardoned: true,
          permanentlyBannedVoters: {'idiot1'},
        ),
        players: {
          'idiot1': const PlayerModel(id: 'idiot1', name: 'Idiot', isAlive: true, role: GameRole.idiot),
        },
      );

      final nextState = handler.executeAction(
        state,
        actorId: 'idiot1',
        actionPayload: {},
      );

      expect(nextState.pendingExecutedPlayerId, equals('idiot1'), reason: 'La grâce est unique : il meurt');
    });
  });

  group('PiedPiperHandler Directive Tests', () {
    test('Envoûte deux joueurs et met à jour isCharmed dans players', () {
      final handler = PiedPiperHandler();
      final state = GameState(
        currentTurn: 1,
        currentPhase: GamePhase.nightPiper,
        players: {
          'piper': const PlayerModel(id: 'piper', name: 'Flûtiste', isAlive: true, role: GameRole.piedPiper),
          'p1': const PlayerModel(id: 'p1', name: 'Joueur 1', isAlive: true, role: GameRole.simpleVillager),
          'p2': const PlayerModel(id: 'p2', name: 'Joueur 2', isAlive: true, role: GameRole.simpleVillager),
        },
      );

      final nextState = handler.executeAction(
        state,
        actorId: 'piper',
        actionPayload: {'targetIds': ['p1', 'p2']},
      );

      expect(nextState.players['p1']?.isCharmed, isTrue);
      expect(nextState.players['p2']?.isCharmed, isTrue);
    });
  });

  group('PyromaniacHandler Directive Tests', () {
    test('Douse asperge un joueur et met à jour isDoused dans players', () {
      final handler = PyromaniacHandler();
      final state = GameState(
        currentTurn: 1,
        currentPhase: GamePhase.nightPyromaniac,
        players: {
          'pyro': const PlayerModel(id: 'pyro', name: 'Pyro', isAlive: true, role: GameRole.pyromaniac),
          'target': const PlayerModel(id: 'target', name: 'Cible', isAlive: true, role: GameRole.simpleVillager),
        },
      );

      final nextState = handler.executeAction(
        state,
        actorId: 'pyro',
        actionPayload: {'action': 'douse', 'targetId': 'target'},
      );

      expect(nextState.players['target']?.isDoused, isTrue);
    });

    test('Ignite enflamme tous les joueurs aspergés et les ajoute aux morts', () {
      final handler = PyromaniacHandler();
      final state = GameState(
        currentTurn: 2,
        currentPhase: GamePhase.nightPyromaniac,
        players: {
          'pyro': const PlayerModel(id: 'pyro', name: 'Pyro', isAlive: true, role: GameRole.pyromaniac),
          'doused1': const PlayerModel(id: 'doused1', name: 'Aspergé 1', isAlive: true, isDoused: true, role: GameRole.simpleVillager),
          'safe': const PlayerModel(id: 'safe', name: 'Non Aspergé', isAlive: true, isDoused: false, role: GameRole.simpleVillager),
        },
      );

      final nextState = handler.executeAction(
        state,
        actorId: 'pyro',
        actionPayload: {'action': 'ignite'},
      );

      expect(nextState.nightSecondaryDeaths, contains('doused1'));
      expect(nextState.nightSecondaryDeaths, isNot(contains('safe')));
    });
  });

  group('CupidHandler Directive Tests', () {
    test('Lie deux amoureux avec réciprocité des identifiants', () {
      final handler = CupidHandler();
      final state = GameState(
        currentTurn: 1,
        currentPhase: GamePhase.nightCupid,
        players: {
          'cupid': const PlayerModel(id: 'cupid', name: 'Cupidon', isAlive: true, role: GameRole.cupid),
          'p1': const PlayerModel(id: 'p1', name: 'Amoureux 1', isAlive: true, role: GameRole.simpleVillager),
          'p2': const PlayerModel(id: 'p2', name: 'Amoureux 2', isAlive: true, role: GameRole.simpleVillager),
        },
      );

      final nextState = handler.executeAction(
        state,
        actorId: 'cupid',
        actionPayload: {'lover1Id': 'p1', 'lover2Id': 'p2'},
      );

      expect(nextState.players['p1']?.isLover, isTrue);
      expect(nextState.players['p1']?.loverId, equals('p2'));
      expect(nextState.players['p2']?.isLover, isTrue);
      expect(nextState.players['p2']?.loverId, equals('p1'));
    });
  });

  group('DefenderHandler Directive Tests', () {
    test('Protège une cible et interdit de cibler le même joueur deux nuits de suite', () {
      final handler = DefenderHandler();
      final state = GameState(
        currentTurn: 2,
        currentPhase: GamePhase.nightDefender,
        lastProtectedPlayerId: 'target1',
        players: {
          'def': const PlayerModel(id: 'def', name: 'Salvateur', isAlive: true, role: GameRole.defender),
          'target1': const PlayerModel(id: 'target1', name: 'Cible 1', isAlive: true, role: GameRole.simpleVillager),
          'target2': const PlayerModel(id: 'target2', name: 'Cible 2', isAlive: true, role: GameRole.simpleVillager),
        },
      );

      // Rejet de target1 (protégé la nuit d'avant)
      final rejectedState = handler.executeAction(
        state,
        actorId: 'def',
        actionPayload: {'targetId': 'target1'},
      );
      expect(rejectedState.currentProtectedPlayerId, isNull);

      // Succès pour target2
      final validState = handler.executeAction(
        state,
        actorId: 'def',
        actionPayload: {'targetId': 'target2'},
      );
      expect(validState.currentProtectedPlayerId, equals('target2'));

      // UI controls excluent target1
      final controls = handler.getUIControls(state, 'def');
      expect(controls.availableTargetIds, contains('target2'));
      expect(controls.availableTargetIds, isNot(contains('target1')));
    });
  });

  group('BlackWolfHandler Directive Tests', () {
    test('Enregistre la cible du silence et refuse de cibler la victime des loups', () {
      final handler = BlackWolfHandler();
      final state = GameState(
        currentTurn: 1,
        currentPhase: GamePhase.nightBlackWolf,
        nightPrimaryVictimId: 'devoured',
        players: {
          'bw': const PlayerModel(id: 'bw', name: 'Loup Noir', isAlive: true, role: GameRole.blackWolf),
          'devoured': const PlayerModel(id: 'devoured', name: 'Dévoré', isAlive: true, role: GameRole.simpleVillager),
          'target': const PlayerModel(id: 'target', name: 'Cible', isAlive: true, role: GameRole.simpleVillager),
        },
      );

      // Refus de cibler devoured
      final rejected = handler.executeAction(
        state,
        actorId: 'bw',
        actionPayload: {'targetId': 'devoured'},
      );
      expect(rejected.blackWolfTargetId, isNull);

      // Succès sur target
      final valid = handler.executeAction(
        state,
        actorId: 'bw',
        actionPayload: {'targetId': 'target'},
      );
      expect(valid.blackWolfTargetId, equals('target'));
    });
  });

  group('HunterHandler Directive Tests', () {
    test('Seul le chasseur mourant peut agir pour abattre sa cible', () {
      final handler = HunterHandler();
      final state = GameState(
        currentTurn: 1,
        currentPhase: GamePhase.hunterDeathChoice,
        pendingExecutedPlayerId: 'hunter1',
        players: {
          'hunter1': const PlayerModel(id: 'hunter1', name: 'Chasseur', isAlive: false, role: GameRole.hunter),
          'other': const PlayerModel(id: 'other', name: 'Autre', isAlive: true, role: GameRole.simpleVillager),
          'target': const PlayerModel(id: 'target', name: 'Cible', isAlive: true, role: GameRole.simpleVillager),
        },
      );

      expect(handler.canAct(state, 'hunter1'), isTrue);
      expect(handler.canAct(state, 'other'), isFalse);

      final nextState = handler.executeAction(
        state,
        actorId: 'hunter1',
        actionPayload: {'targetId': 'target'},
      );

      expect(nextState.players['target']?.isAlive, isFalse);
    });
  });

  group('FogOfWarService Active Roles Canonical Visibility Tests', () {
    test('Bouclier du Salvateur : visible uniquement par le Salvateur ou DevMode', () {
      expect(
        FogOfWarService.canSeeDefenderShield(
          targetIsProtected: true,
          observerRole: GameRole.defender,
        ),
        isTrue,
      );
      expect(
        FogOfWarService.canSeeDefenderShield(
          targetIsProtected: true,
          observerRole: GameRole.simpleWerewolf,
        ),
        isFalse,
      );
      expect(
        FogOfWarService.canSeeDefenderShield(
          targetIsProtected: true,
          observerRole: GameRole.simpleVillager,
          isDevMode: true,
        ),
        isTrue,
      );
    });

    test('Sorcière : Sauvé, Empoisonné, Victime des loups', () {
      expect(
        FogOfWarService.canSeeWitchHealed(
          targetIsHealed: true,
          observerRole: GameRole.witch,
        ),
        isTrue,
      );
      expect(
        FogOfWarService.canSeeWitchHealed(
          targetIsHealed: true,
          observerRole: GameRole.simpleVillager,
        ),
        isFalse,
      );

      expect(
        FogOfWarService.canSeeWitchPoisoned(
          targetIsPoisoned: true,
          observerRole: GameRole.witch,
        ),
        isTrue,
      );
      expect(
        FogOfWarService.canSeeWitchPoisoned(
          targetIsPoisoned: true,
          observerRole: GameRole.simpleWerewolf,
        ),
        isFalse,
      );

      expect(
        FogOfWarService.canSeeWitchWolfVictim(
          targetIsVictim: true,
          observerRole: GameRole.witch,
          isNightWitch: true,
        ),
        isTrue,
      );
      expect(
        FogOfWarService.canSeeWitchWolfVictim(
          targetIsVictim: true,
          observerRole: GameRole.witch,
          isNightWitch: false,
        ),
        isFalse,
      );
    });

    test('Corbeau : invisible la nuit pour les villageois, public le jour', () {
      expect(
        FogOfWarService.canSeeCrowTarget(
          targetIsCrowTarget: true,
          isDayTime: false,
          observerRole: GameRole.raven,
        ),
        isTrue,
      );
      expect(
        FogOfWarService.canSeeCrowTarget(
          targetIsCrowTarget: true,
          isDayTime: false,
          observerRole: GameRole.simpleVillager,
        ),
        isFalse,
      );
      expect(
        FogOfWarService.canSeeCrowTarget(
          targetIsCrowTarget: true,
          isDayTime: true,
          observerRole: GameRole.simpleVillager,
        ),
        isTrue,
      );
    });

    test('Enfant Sauvage : Modèle visible uniquement par l\'enfant', () {
      expect(
        FogOfWarService.canSeeWildChildModel(
          targetIsModel: true,
          observerRole: GameRole.wildChild,
        ),
        isTrue,
      );
      expect(
        FogOfWarService.canSeeWildChildModel(
          targetIsModel: true,
          observerRole: GameRole.simpleVillager,
        ),
        isFalse,
      );
    });

    test('Épée Rouillée : Loup contaminé visible pour les loups et le contaminé', () {
      expect(
        FogOfWarService.canSeeRustyKnightContamination(
          targetIsContaminated: true,
          isObserverWolf: true,
          isObserverContaminated: false,
        ),
        isTrue,
      );
      expect(
        FogOfWarService.canSeeRustyKnightContamination(
          targetIsContaminated: true,
          isObserverWolf: false,
          isObserverContaminated: true,
        ),
        isTrue,
      );
      expect(
        FogOfWarService.canSeeRustyKnightContamination(
          targetIsContaminated: true,
          isObserverWolf: false,
          isObserverContaminated: false,
        ),
        isFalse,
      );
    });

    test('Montreur d\'Ours : Grognement public le jour', () {
      expect(
        FogOfWarService.canSeeBearGrowl(
          targetIsBearTamer: true,
          bearGrowledThisMorning: true,
          isDayTime: true,
        ),
        isTrue,
      );
      expect(
        FogOfWarService.canSeeBearGrowl(
          targetIsBearTamer: true,
          bearGrowledThisMorning: false,
          isDayTime: true,
        ),
        isFalse,
      );
      expect(
        FogOfWarService.canSeeBearGrowl(
          targetIsBearTamer: true,
          bearGrowledThisMorning: true,
          isDayTime: false,
        ),
        isFalse,
      );
    });
  });

  group('SeerHandler Strategic Actions', () {
    test('La Voyante peut agir pendant son tour nocturne et sonde une âme', () {
      final handler = SeerHandler();
      final state = GameState(
        currentTurn: 1,
        currentPhase: GamePhase.nightSeer,
        players: {
          'seer': const PlayerModel(id: 'seer', name: 'Voyante', isAlive: true, role: GameRole.seer),
          'target': const PlayerModel(id: 'target', name: 'Cible', isAlive: true, role: GameRole.simpleWerewolf),
        },
      );

      expect(handler.canAct(state, 'seer'), isTrue);
      expect(handler.canAct(state, 'target'), isFalse);

      final nextState = handler.executeAction(
        state,
        actorId: 'seer',
        actionPayload: {'targetId': 'target'},
      );

      expect(nextState.nightAcknowledgedPlayerIds, contains('seer'));

      final controls = handler.getUIControls(state, 'seer');
      expect(controls.availableTargetIds, contains('target'));
      expect(controls.availableTargetIds, isNot(contains('seer')));
    });
  });

  group('WitchHandler Strategic Actions', () {
    test('La Sorcière sauve la victime des loups avec sa potion de vie', () {
      final handler = WitchHandler();
      final state = GameState(
        currentTurn: 1,
        currentPhase: GamePhase.nightWitch,
        nightPrimaryVictimId: 'victim1',
        players: {
          'witch': const PlayerModel(id: 'witch', name: 'Sorcière', isAlive: true, role: GameRole.witch),
          'victim1': const PlayerModel(id: 'victim1', name: 'Victime', isAlive: true, role: GameRole.simpleVillager),
        },
      );

      final nextState = handler.executeAction(
        state,
        actorId: 'witch',
        actionPayload: {'save': true},
      );

      expect(nextState.nightPrimaryVictimId, isNull, reason: 'La victime est sauvée');
      expect(nextState.nightAcknowledgedPlayerIds, contains('witch'));
    });

    test('La Sorcière empoisonne un suspect avec sa potion de mort', () {
      final handler = WitchHandler();
      final state = GameState(
        currentTurn: 1,
        currentPhase: GamePhase.nightWitch,
        players: {
          'witch': const PlayerModel(id: 'witch', name: 'Sorcière', isAlive: true, role: GameRole.witch),
          'suspect': const PlayerModel(id: 'suspect', name: 'Suspect', isAlive: true, role: GameRole.simpleVillager),
        },
      );

      final nextState = handler.executeAction(
        state,
        actorId: 'witch',
        actionPayload: {'poisonTargetId': 'suspect'},
      );

      expect(nextState.nightSecondaryDeaths, contains('suspect'));
      expect(nextState.nightAcknowledgedPlayerIds, contains('witch'));
    });

    test('La Sorcière passe son tour sans utiliser de potion', () {
      final handler = WitchHandler();
      final state = GameState(
        currentTurn: 1,
        currentPhase: GamePhase.nightWitch,
        nightPrimaryVictimId: 'victim1',
        players: {
          'witch': const PlayerModel(id: 'witch', name: 'Sorcière', isAlive: true, role: GameRole.witch),
          'victim1': const PlayerModel(id: 'victim1', name: 'Victime', isAlive: true, role: GameRole.simpleVillager),
        },
      );

      final nextState = handler.executeAction(
        state,
        actorId: 'witch',
        actionPayload: {'skip': true},
      );

      expect(nextState.nightPrimaryVictimId, equals('victim1'));
      expect(nextState.nightSecondaryDeaths, isEmpty);
      expect(nextState.nightAcknowledgedPlayerIds, contains('witch'));
    });
  });

  group('CrowHandler Directive Tests', () {
    test('Le Corbeau désigne un suspect pour recevoir 2 votes d\'office', () {
      final handler = CrowHandler();
      final state = GameState(
        currentTurn: 1,
        players: {
          'crow': const PlayerModel(id: 'crow', name: 'Corbeau', isAlive: true, role: GameRole.raven),
          'suspect': const PlayerModel(id: 'suspect', name: 'Suspect', isAlive: true, role: GameRole.simpleVillager),
        },
      );

      expect(handler.canAct(state, 'crow'), isTrue);

      final nextState = handler.executeAction(
        state,
        actorId: 'crow',
        actionPayload: {'targetId': 'suspect'},
      );

      expect(nextState.expandedRolesState.crowTargetId, equals('suspect'));
    });
  });

  group('BearTamerHandler Dawn Growl Resolution', () {
    test('L\'ours grogne à l\'aube si au moins un voisin vivant est un loup', () {
      final state = GameState(
        alivePlayerIdsInOrder: ['p1', 'p2', 'p3', 'p4'],
        playerRoles: {
          'p1': GameRole.simpleVillager,
          'p2': GameRole.bearTamer,
          'p3': GameRole.simpleWerewolf,
          'p4': GameRole.simpleVillager,
        },
        players: {
          'p1': const PlayerModel(id: 'p1', name: 'V1', isAlive: true, role: GameRole.simpleVillager),
          'p2': const PlayerModel(id: 'p2', name: 'Tamer', isAlive: true, role: GameRole.bearTamer),
          'p3': const PlayerModel(id: 'p3', name: 'Wolf', isAlive: true, role: GameRole.simpleWerewolf),
          'p4': const PlayerModel(id: 'p4', name: 'V2', isAlive: true, role: GameRole.simpleVillager),
        },
      );

      final nextState = BearTamerHandler.resolveMorningGrowl(state);
      expect(nextState.expandedRolesState.bearGrowledThisMorning, isTrue);
    });

    test('L\'ours reste silencieux si aucun voisin vivant n\'est un loup', () {
      final state = GameState(
        alivePlayerIdsInOrder: ['p1', 'p2', 'p3', 'p4'],
        playerRoles: {
          'p1': GameRole.simpleVillager,
          'p2': GameRole.bearTamer,
          'p3': GameRole.simpleVillager,
          'p4': GameRole.simpleWerewolf,
        },
        players: {
          'p1': const PlayerModel(id: 'p1', name: 'V1', isAlive: true, role: GameRole.simpleVillager),
          'p2': const PlayerModel(id: 'p2', name: 'Tamer', isAlive: true, role: GameRole.bearTamer),
          'p3': const PlayerModel(id: 'p3', name: 'V2', isAlive: true, role: GameRole.simpleVillager),
          'p4': const PlayerModel(id: 'p4', name: 'Wolf', isAlive: true, role: GameRole.simpleWerewolf),
        },
      );

      final nextState = BearTamerHandler.resolveMorningGrowl(state);
      expect(nextState.expandedRolesState.bearGrowledThisMorning, isFalse);
    });

    test('L\'ours grogne systématiquement si le Montreur d\'Ours est infecté', () {
      final state = GameState(
        alivePlayerIdsInOrder: ['p1', 'p2', 'p3'],
        playerRoles: {
          'p1': GameRole.simpleVillager,
          'p2': GameRole.bearTamer,
          'p3': GameRole.simpleVillager,
        },
        players: {
          'p1': const PlayerModel(id: 'p1', name: 'V1', isAlive: true, role: GameRole.simpleVillager),
          'p2': const PlayerModel(id: 'p2', name: 'Tamer', isAlive: true, role: GameRole.bearTamer),
          'p3': const PlayerModel(id: 'p3', name: 'V2', isAlive: true, role: GameRole.simpleVillager),
        },
        expandedRolesState: const ExpandedRolesState(infectedPlayerId: 'p2'),
      );

      final nextState = BearTamerHandler.resolveMorningGrowl(state);
      expect(nextState.expandedRolesState.bearGrowledThisMorning, isTrue);
    });
  });

  group('RustySwordKnightHandler Devoured Resolution', () {
    test('Infecte le premier loup à sa gauche lors de sa mort', () {
      final state = GameState(
        currentTurn: 2,
        alivePlayerIdsInOrder: ['k', 'v1', 'w1', 'w2'],
        playerRoles: {
          'k': GameRole.knightRustySword,
          'v1': GameRole.simpleVillager,
          'w1': GameRole.simpleWerewolf,
          'w2': GameRole.simpleWerewolf,
        },
      );

      // Le chevalier est à l'index 0. À sa gauche (circulaire vers l'arrière) :
      // index - 1 -> index 3 qui est w2 !
      final nextState = RustySwordKnightHandler.onDevouredByWolves(state, 'k');
      expect(nextState.expandedRolesState.rustyKnightContaminatedWolfId, equals('w2'));
      expect(nextState.expandedRolesState.rustyKnightDeathNight, equals(2));
    });
  });

  group('ElderHandler Resistance and Curse Tests', () {
    test('L\'Ancien survit à la première attaque des loups', () {
      final state = GameState(
        alivePlayerIdsInOrder: ['elder'],
        players: {
          'elder': const PlayerModel(id: 'elder', name: 'Ancien', isAlive: true, role: GameRole.elder),
        },
        expandedRolesState: const ExpandedRolesState(ancientLives: {'elder': 2}),
      );

      final nextState = ElderHandler.handleWolfAttack(state, 'elder');
      expect(nextState.expandedRolesState.ancientLives['elder'], equals(1));
      expect(nextState.isAlive('elder'), isTrue);
    });

    test('L\'Ancien meurt à la seconde morsure des loups', () {
      final state = GameState(
        alivePlayerIdsInOrder: ['elder'],
        players: {
          'elder': const PlayerModel(id: 'elder', name: 'Ancien', isAlive: true, role: GameRole.elder),
        },
        expandedRolesState: const ExpandedRolesState(ancientLives: {'elder': 1}),
      );

      final nextState = ElderHandler.handleWolfAttack(state, 'elder');
      expect(nextState.isAlive('elder'), isFalse);
    });

    test('L\'élimination par le village fait perdre tous les pouvoirs au village', () {
      const state = GameState();
      final nextState = ElderHandler.handleVillageKill(state, 'elder');
      expect(nextState.expandedRolesState.ancientPowerLost, isTrue);
    });
  });

  group('WildChildHandler Model and Transformation', () {
    test('L\'Enfant Sauvage choisit son modèle la première nuit', () {
      final handler = WildChildHandler();
      final state = GameState(
        currentTurn: 1,
        players: {
          'wc': const PlayerModel(id: 'wc', name: 'Enfant', isAlive: true, role: GameRole.wildChild),
          'model': const PlayerModel(id: 'model', name: 'Modèle', isAlive: true, role: GameRole.simpleVillager),
        },
      );

      expect(handler.canAct(state, 'wc'), isTrue);

      final nextState = handler.executeAction(
        state,
        actorId: 'wc',
        actionPayload: {'modelPlayerId': 'model'},
      );

      expect(nextState.expandedRolesState.wildChildModelId, equals('model'));
    });

    test('L\'Enfant Sauvage mute en loup à la mort de son modèle', () {
      const state = GameState(
        expandedRolesState: ExpandedRolesState(
          wildChildModelId: 'model',
          wildChildTransformed: false,
        ),
      );

      final nextState = WildChildHandler.checkModelDeath(state, 'model');
      expect(nextState.expandedRolesState.wildChildTransformed, isTrue);
    });
  });

  group('InfectFatherOfWolvesHandler Infection Mechanics', () {
    test('L\'Infect Père des Loups transforme la victime en loup-garou', () {
      final handler = InfectFatherOfWolvesHandler();
      final state = GameState(
        currentTurn: 1,
        nightPrimaryVictimId: 'victim',
        players: {
          'father': const PlayerModel(id: 'father', name: 'Père', isAlive: true, role: GameRole.vileFatherOfWolves),
          'victim': const PlayerModel(id: 'victim', name: 'Victime', isAlive: true, role: GameRole.simpleVillager),
        },
      );

      expect(handler.canAct(state, 'father'), isTrue);

      final nextState = handler.executeAction(
        state,
        actorId: 'father',
        actionPayload: {'infect': true},
      );

      expect(nextState.nightPrimaryVictimId, isNull, reason: 'Victime sauvée de la mort');
      expect(nextState.expandedRolesState.infectedPlayerId, equals('victim'));
      expect(nextState.expandedRolesState.hasUsedInfection, isTrue);
    });
  });

  group('BigBadWolfHandler Double Attack Mechanics', () {
    test('Le Grand Méchant Loup peut agir tant qu\'aucun loup n\'est mort', () {
      final handler = BigBadWolfHandler();
      final state = GameState(
        alivePlayerIdsInOrder: ['bbw', 'w1', 'v1'],
        playerRoles: {
          'bbw': GameRole.bigBadWolf,
          'w1': GameRole.simpleWerewolf,
          'v1': GameRole.simpleVillager,
        },
        players: {
          'bbw': const PlayerModel(id: 'bbw', name: 'Grand Méchant', isAlive: true, role: GameRole.bigBadWolf),
          'w1': const PlayerModel(id: 'w1', name: 'Loup', isAlive: true, role: GameRole.simpleWerewolf),
          'v1': const PlayerModel(id: 'v1', name: 'Villageois', isAlive: true, role: GameRole.simpleVillager),
        },
      );

      expect(handler.canAct(state, 'bbw'), isTrue);

      final nextState = handler.executeAction(
        state,
        actorId: 'bbw',
        actionPayload: {'targetId': 'v1'},
      );

      expect(nextState.nightSecondaryDeaths, contains('v1'));
    });

    test('Le Grand Méchant Loup perd son pouvoir dès qu\'un loup meurt', () {
      final handler = BigBadWolfHandler();
      final state = GameState(
        alivePlayerIdsInOrder: ['bbw', 'v1'],
        playerRoles: {
          'bbw': GameRole.bigBadWolf,
          'w1': GameRole.simpleWerewolf,
          'v1': GameRole.simpleVillager,
        },
        players: {
          'bbw': const PlayerModel(id: 'bbw', name: 'Grand Méchant', isAlive: true, role: GameRole.bigBadWolf),
          'w1': const PlayerModel(id: 'w1', name: 'Loup Mort', isAlive: false, role: GameRole.simpleWerewolf),
          'v1': const PlayerModel(id: 'v1', name: 'Villageois', isAlive: true, role: GameRole.simpleVillager),
        },
      );

      expect(handler.canAct(state, 'bbw'), isFalse);
    });
  });

  group('WolfCubHandler Revenge Mechanics', () {
    test('La mort du Chiot Loup enregistre la double vengeance pour la nuit suivante', () {
      const state = GameState();
      final nextState = WolfCubHandler.onCubDeath(state);
      expect(nextState.expandedRolesState.cubDiedYesterday, isTrue);
    });
  });

  group('StutteringJudgeHandler Second Vote Mechanics', () {
    test('Le Juge Bègue déclenche un second vote consécutif le jour', () {
      final handler = StutteringJudgeHandler();
      final state = GameState(
        currentPhase: GamePhase.dayVoting,
        players: {
          'judge': const PlayerModel(id: 'judge', name: 'Juge', isAlive: true, role: GameRole.stutteringJudge),
        },
        expandedRolesState: const ExpandedRolesState(judgeSecondVoteAvailable: true),
      );

      expect(handler.canAct(state, 'judge'), isTrue);

      final nextState = handler.executeAction(
        state,
        actorId: 'judge',
        actionPayload: {},
      );

      expect(nextState.expandedRolesState.judgeSecondVoteAvailable, isFalse);
      expect(nextState.expandedRolesState.isSecondVoteTriggered, isTrue);
    });
  });

  group('ScapegoatHandler Tie Execution Mechanics', () {
    test('Le Bouc Émissaire désigne les joueurs interdits de vote après son sacrifice', () {
      final handler = ScapegoatHandler();
      const state = GameState(
        lastEliminatedPlayerId: 'goat',
        expandedRolesState: ExpandedRolesState(scapegoatNeedsToBan: true),
      );

      expect(handler.canAct(state, 'goat'), isTrue);

      final nextState = handler.executeAction(
        state,
        actorId: 'goat',
        actionPayload: {
          'bannedVoterIds': ['p1', 'p2'],
        },
      );

      expect(nextState.expandedRolesState.bannedVotersForToday, containsAll(['p1', 'p2']));
      expect(nextState.expandedRolesState.scapegoatNeedsToBan, isFalse);
    });
  });

  group('DevotedServantHandler Role Steal Mechanics', () {
    test('La Servante Dévouée échange son identité avec celle du condamné', () {
      final handler = DevotedServantHandler();
      final state = GameState(
        pendingExecutedPlayerId: 'condemned',
        playerRoles: {
          'servant': GameRole.servantMaid,
          'condemned': GameRole.seer,
        },
        players: {
          'servant': const PlayerModel(id: 'servant', name: 'Servante', isAlive: true, role: GameRole.servantMaid),
          'condemned': const PlayerModel(id: 'condemned', name: 'Condamné', isAlive: true, role: GameRole.seer),
        },
      );

      expect(handler.canAct(state, 'servant'), isTrue);

      final nextState = handler.executeAction(
        state,
        actorId: 'servant',
        actionPayload: {'swap': true},
      );

      expect(nextState.playerRoles['servant'], equals(GameRole.seer));
      expect(nextState.playerRoles['condemned'], equals(GameRole.simpleVillager));
    });
  });

  group('ActorHandler Role Choice Mechanics', () {
    test('Le Comédien consomme un rôle parmi les cartes écartées', () {
      final handler = ActorHandler();
      final state = GameState(
        players: {
          'actor': const PlayerModel(id: 'actor', name: 'Comédien', isAlive: true, role: GameRole.actor),
        },
        expandedRolesState: const ExpandedRolesState(
          actorAvailableRoles: {
            'actor': [GameRole.hunter, GameRole.witch, GameRole.defender],
          },
        ),
      );

      expect(handler.canAct(state, 'actor'), isTrue);

      final nextState = handler.executeAction(
        state,
        actorId: 'actor',
        actionPayload: {'chosenRole': 'hunter'},
      );

      final remaining = nextState.expandedRolesState.actorAvailableRoles['actor']!;
      expect(remaining, containsAll([GameRole.witch, GameRole.defender]));
      expect(remaining, isNot(contains(GameRole.hunter)));
    });
  });

  group('ThiefHandler Role Robbery Mechanics', () {
    test('Le Voleur subtilise le rôle d\'un citoyen actif', () {
      final handler = ThiefHandler();
      final state = GameState(
        currentTurn: 1,
        playerRoles: {
          'thief': GameRole.thief,
          'target': GameRole.cupid,
        },
        players: {
          'thief': const PlayerModel(id: 'thief', name: 'Voleur', isAlive: true, role: GameRole.thief),
          'target': const PlayerModel(id: 'target', name: 'Cible', isAlive: true, role: GameRole.cupid),
        },
      );

      expect(handler.canAct(state, 'thief'), isTrue);

      final nextState = handler.executeAction(
        state,
        actorId: 'thief',
        actionPayload: {'targetId': 'target'},
      );

      expect(nextState.playerRoles['thief'], equals(GameRole.cupid));
      expect(nextState.playerRoles['target'], equals(GameRole.simpleVillager));
    });
  });

  group('AbominableSectarianHandler Clan Partition Mechanics', () {
    test('Scinde le village équitablement en deux clans alternés', () {
      final handler = AbominableSectarianHandler();
      final state = GameState(
        currentTurn: 1,
        alivePlayerIdsInOrder: ['p1', 'p2', 'p3', 'p4'],
        players: {
          'sect': const PlayerModel(id: 'sect', name: 'Sectaire', isAlive: true, role: GameRole.sectLeader),
        },
      );

      expect(handler.canAct(state, 'sect'), isTrue);

      final nextState = handler.executeAction(
        state,
        actorId: 'sect',
        actionPayload: {},
      );

      final teams = nextState.expandedRolesState.sectarianTeams;
      expect(teams['teamA'], equals(['p1', 'p3']));
      expect(teams['teamB'], equals(['p2', 'p4']));
    });
  });

  group('SoulStealerHandler Soul Theft Mechanics', () {
    test('Le Voleur d\'Âmes échange son identité lors de la nuit 1', () {
      final handler = SoulStealerHandler();
      final state = GameState(
        currentTurn: 1,
        playerRoles: {
          'stealer': GameRole.thiefOfHearts,
          'target': GameRole.seer,
        },
        players: {
          'stealer': const PlayerModel(id: 'stealer', name: 'Voleur d\'Âmes', isAlive: true, role: GameRole.thiefOfHearts),
          'target': const PlayerModel(id: 'target', name: 'Cible', isAlive: true, role: GameRole.seer),
        },
      );

      expect(handler.canAct(state, 'stealer'), isTrue);

      final nextState = handler.executeAction(
        state,
        actorId: 'stealer',
        actionPayload: {'targetId': 'target'},
      );

      expect(nextState.playerRoles['stealer'], equals(GameRole.seer));
      expect(nextState.playerRoles['target'], equals(GameRole.simpleVillager));
    });
  });

  group('TwoSisters and ThreeBrothers Recognition Mechanics', () {
    test('Les Deux Sœurs s\'identifient mutuellement la 1re nuit', () {
      final handler = TwoSistersHandler();
      final state = GameState(
        currentTurn: 1,
        playerRoles: {
          's1': GameRole.twoSisters,
          's2': GameRole.twoSisters,
        },
        players: {
          's1': const PlayerModel(id: 's1', name: 'Sœur 1', isAlive: true, role: GameRole.twoSisters),
          's2': const PlayerModel(id: 's2', name: 'Sœur 2', isAlive: true, role: GameRole.twoSisters),
        },
      );

      expect(handler.canAct(state, 's1'), isTrue);
      final controls = handler.getUIControls(state, 's1');
      expect(controls.instruction, contains('Sœur 2'));
    });

    test('Les Trois Frères se reconnaissent la 1re nuit', () {
      final handler = ThreeBrothersHandler();
      final state = GameState(
        currentTurn: 1,
        playerRoles: {
          'b1': GameRole.threeBrothers,
          'b2': GameRole.threeBrothers,
          'b3': GameRole.threeBrothers,
        },
        players: {
          'b1': const PlayerModel(id: 'b1', name: 'Frère 1', isAlive: true, role: GameRole.threeBrothers),
          'b2': const PlayerModel(id: 'b2', name: 'Frère 2', isAlive: true, role: GameRole.threeBrothers),
          'b3': const PlayerModel(id: 'b3', name: 'Frère 3', isAlive: true, role: GameRole.threeBrothers),
        },
      );

      expect(handler.canAct(state, 'b1'), isTrue);
      final controls = handler.getUIControls(state, 'b1');
      expect(controls.instruction, contains('Frère 2'));
      expect(controls.instruction, contains('Frère 3'));
    });
  });

  group('AngelHandler Victory Condition Tests', () {
    test('L\'Ange remporte la victoire s\'il est éliminé le 1er jour', () {
      final handler = AngelHandler();
      final state = GameState(
        currentTurn: 1,
        players: {
          'angel': const PlayerModel(id: 'angel', name: 'Ange', isAlive: true, role: GameRole.angel),
        },
      );

      expect(handler.canAct(state, 'angel'), isTrue);

      final nextState = handler.executeAction(
        state,
        actorId: 'angel',
        actionPayload: {'eliminatedOnDay1': true},
      );

      expect(nextState.expandedRolesState.angelWon, isTrue);
    });
  });
}
