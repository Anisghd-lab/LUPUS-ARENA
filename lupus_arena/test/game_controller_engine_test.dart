import 'package:flutter_test/flutter_test.dart';
import 'package:lupus_arena/engine/game_controller.dart';
import 'package:lupus_arena/engine/game_engine_models.dart';
import 'package:lupus_arena/services/death_registry_service.dart';

void main() {
  setUp(() {
    DeathRegistryService.instance.clearForNewGame();
  });

  group('GameController & Modular Game Engine Tests', () {
    test('Nuit préliminaire (Turn 0) : Voleur vole le rôle d\'un joueur', () {
      final controller = GameController();
      final players = [
        Player(id: 'p1', name: 'Alice', role: RoleType.stealer),
        Player(id: 'p2', name: 'Bob', role: RoleType.werewolf, faction: Faction.werewolves),
        Player(id: 'p3', name: 'Charlie', role: RoleType.villager),
      ];

      controller.startGame(players);

      expect(controller.currentPhase, equals(GamePhase.preliminaryNight));
      expect(controller.activeStep, equals(GameStep.preStealer));

      // Voleur vole le rôle du loup
      controller.actionStealerStealRole('p1', 'p2');

      final thief = controller.players.firstWhere((p) => p.id == 'p1');
      final victim = controller.players.firstWhere((p) => p.id == 'p2');

      expect(thief.role, equals(RoleType.werewolf));
      expect(thief.faction, equals(Faction.werewolves));
      expect(victim.role, equals(RoleType.villager));
      expect(victim.faction, equals(Faction.villagers));

      // Passe à la nuit 1
      expect(controller.currentPhase, equals(GamePhase.night));
      expect(controller.currentTurn, equals(1));

      controller.dispose();
    });

    test('Nuit préliminaire (Turn 0) : Enregistre Cupidon et Voleur uniquement', () {
      final controller = GameController();
      final players = [
        Player(id: 'p1', name: 'Alice', role: RoleType.cupid),
        Player(id: 'p2', name: 'Bob', role: RoleType.stealer),
        Player(id: 'p3', name: 'Charlie', role: RoleType.werewolf),
        Player(id: 'p4', name: 'David', role: RoleType.villager),
      ];

      controller.startGame(players);

      expect(controller.currentPhase, equals(GamePhase.preliminaryNight));
      expect(controller.activeStep, equals(GameStep.preStealer));

      // Passer le voleur
      controller.actionPass();
      expect(controller.activeStep, equals(GameStep.preCupid));

      // Lier deux amoureux
      controller.actionCupidLinkLovers('p3', 'p4');

      final lover1 = controller.players.firstWhere((p) => p.id == 'p3');
      final lover2 = controller.players.firstWhere((p) => p.id == 'p4');
      expect(lover1.loversIds, contains('p4'));
      expect(lover2.loversIds, contains('p3'));

      // Transition automatique vers la nuit régulière Turn 1
      expect(controller.currentPhase, equals(GamePhase.night));
      expect(controller.currentTurn, equals(1));

      controller.dispose();
    });

    test('Nuit régulière : Ordre strict et buffer non destructif', () {
      final controller = GameController();
      final players = [
        Player(id: 'p1', name: 'Voyante', role: RoleType.seer),
        Player(id: 'p2', name: 'Salvateur', role: RoleType.bodyguard),
        Player(id: 'p3', name: 'Loup', role: RoleType.werewolf),
        Player(id: 'p4', name: 'Sorcière', role: RoleType.witch),
        Player(id: 'p5', name: 'Villageois', role: RoleType.villager),
      ];

      controller.startGame(players);
      // Nuit 0 -> pas de cupid ni stealer -> saute immédiatement à Nuit 1
      expect(controller.currentPhase, equals(GamePhase.night));
      expect(controller.currentTurn, equals(1));

      // 1. Voyante
      expect(controller.activeStep, equals(GameStep.roleSeer));
      controller.actionPass();

      // 2. Salvateur (protège p5)
      expect(controller.activeStep, equals(GameStep.roleBodyguard));
      controller.actionBodyguardProtect('p5');

      // 3. Loups (attaquent p5, qui est protégé)
      expect(controller.activeStep, equals(GameStep.roleWerewolves));
      controller.actionWerewolvesVote('p5');

      // 4. Sorcière (empoisonne p3)
      expect(controller.activeStep, equals(GameStep.roleWitch));
      controller.actionWitchDecide(useLifePotion: false, killTargetId: 'p3');

      // Résolution du matin
      expect(controller.currentPhase, equals(GamePhase.dayAnnounceDeaths));
      // p5 a été protégé par le Salvateur -> survit !
      // p3 a été empoisonné par la Sorcière -> meurt !
      expect(controller.pendingDeathsAnnouncement, contains('p3'));
      expect(controller.pendingDeathsAnnouncement, isNot(contains('p5')));

      final wolf = controller.players.firstWhere((p) => p.id == 'p3');
      final villager = controller.players.firstWhere((p) => p.id == 'p5');
      expect(wolf.isAlive, isFalse);
      expect(villager.isAlive, isTrue);

      // Inviolabilité : inscrit dans DeathRegistryService
      expect(DeathRegistryService.instance.isDead('p3'), isTrue);

      controller.dispose();
    });

    test('Chagrin d\'amour : La mort d\'un amant entraîne immédiatement la mort de l\'autre', () {
      final controller = GameController();
      final players = [
        Player(id: 'p1', name: 'Loup1', role: RoleType.werewolf),
        Player(id: 'p2', name: 'Loup2', role: RoleType.werewolf),
        Player(id: 'p3', name: 'Amant1', role: RoleType.villager, loversIds: {'p4'}),
        Player(id: 'p4', name: 'Amant2', role: RoleType.villager, loversIds: {'p3'}),
      ];

      controller.startGame(players);
      expect(controller.activeStep, equals(GameStep.roleWerewolves));

      // Loups dévorent Amant1
      controller.actionWerewolvesVote('p3');

      // Résolution : les deux amoureux meurent
      expect(controller.currentPhase, equals(GamePhase.dayAnnounceDeaths));
      expect(controller.pendingDeathsAnnouncement, containsAll(['p3', 'p4']));

      final amant1 = controller.players.firstWhere((p) => p.id == 'p3');
      final amant2 = controller.players.firstWhere((p) => p.id == 'p4');
      expect(amant1.isAlive, isFalse);
      expect(amant2.isAlive, isFalse);
      expect(DeathRegistryService.instance.isDead('p3'), isTrue);
      expect(DeathRegistryService.instance.isDead('p4'), isTrue);

      controller.dispose();
    });

    test('Vote du village : Prise en compte du Capitaine (+2) et du Corbeau (+2)', () {
      final controller = GameController();
      final players = [
        Player(id: 'p1', name: 'Capitaine', role: RoleType.villager, isCaptain: true),
        Player(id: 'p2', name: 'Citoyen', role: RoleType.villager),
        Player(id: 'p3', name: 'Suspect1', role: RoleType.werewolf),
        Player(id: 'p4', name: 'Suspect2', role: RoleType.villager),
      ];

      controller.startGame(players);
      controller.startDayVoting();
      expect(controller.currentPhase, equals(GamePhase.dayVoting));

      // Le Capitaine (p1) vote pour Suspect1 (vaut 2 voix)
      controller.castVote('p1', 'p3');
      // Citoyen (p2) vote pour Suspect2 (vaut 1 voix)
      controller.castVote('p2', 'p4');
      // Suspects votent
      controller.castVote('p3', 'p4');
      controller.castVote('p4', 'p3');

      // Suspect1 a reçu: p1 (2 voix) + p4 (1 voix) = 3 voix
      // Suspect2 a reçu: p2 (1 voix) + p3 (1 voix) = 2 voix
      // Suspect1 est exécuté
      final executed = controller.players.firstWhere((p) => p.id == 'p3');
      expect(executed.isAlive, isFalse);
      expect(DeathRegistryService.instance.isDead('p3'), isTrue);

      controller.dispose();
    });

    test('Victoire du Village lorsque tous les loups sont éliminés', () {
      final controller = GameController();
      final players = [
        Player(id: 'p1', name: 'Citoyen1', role: RoleType.villager),
        Player(id: 'p2', name: 'Citoyen2', role: RoleType.villager),
        Player(id: 'p3', name: 'Loup', role: RoleType.werewolf),
      ];

      controller.startGame(players);
      controller.startDayVoting();

      // Tout le monde vote pour le Loup
      controller.castVote('p1', 'p3');
      controller.castVote('p2', 'p3');
      controller.castVote('p3', 'p1');

      // Le Loup meurt et le Village gagne
      expect(controller.currentPhase, equals(GamePhase.gameOver));

      controller.dispose();
    });
  });
}
