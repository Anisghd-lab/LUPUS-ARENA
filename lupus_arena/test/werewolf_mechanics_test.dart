import 'package:flutter_test/flutter_test.dart';
import 'package:lupus_arena/GameNotifier.dart';
import 'package:lupus_arena/models/game_phase.dart';
import 'package:lupus_arena/models/player_model.dart';

void main() {
  test('L\'ordre canonique nocturne respecte strictement le livret officiel', () {
    expect(GamePhase.nightThief.index, lessThan(GamePhase.nightCupid.index));
    expect(GamePhase.nightCupid.index, lessThan(GamePhase.nightSeer.index));
    expect(GamePhase.nightSeer.index, lessThan(GamePhase.nightDefender.index));
    expect(GamePhase.nightDefender.index, lessThan(GamePhase.nightWerewolves.index));
    expect(GamePhase.nightWerewolves.index, lessThan(GamePhase.nightWitch.index));
    expect(GamePhase.nightWitch.index, lessThan(GamePhase.morningAnnouncement.index));
  });

  test('La distribution par défaut supporte entre 04 et 30 joueurs et respecte la table officielle', () {
    for (int count = 4; count <= 30; count++) {
      final pool = GameNotifier.generateDefaultRolePool(count);
      final totalRoles = pool.values.fold<int>(0, (a, b) => a + b);
      expect(totalRoles, equals(count), reason: 'Total des cartes pour $count joueurs');
      expect(pool['simple_werewolf'] ?? 0, greaterThanOrEqualTo(1), reason: 'Au moins un loup pour $count joueurs');
      expect(pool['seer'], equals(1), reason: 'Une voyante requise pour $count joueurs');
    }

    // Vérification spécifique table 4 joueurs
    final pool4 = GameNotifier.generateDefaultRolePool(4);
    expect(pool4['simple_werewolf'], equals(1));
    expect(pool4['seer'], equals(1));
    expect(pool4['witch'], equals(1));
    expect(pool4['simple_villager'], equals(1));

    // Vérification spécifique table officielle 8 joueurs
    final pool8 = GameNotifier.generateDefaultRolePool(8);
    expect(pool8['simple_werewolf'], equals(2));
    expect(pool8['seer'], equals(1));
    expect(pool8['witch'], equals(1));
    expect(pool8['hunter'], equals(1));
    expect(pool8['little_girl'], equals(1));
    expect(pool8['simple_villager'], equals(2));

    // Vérification spécifique table officielle 12 joueurs (3 loups)
    final pool12 = GameNotifier.generateDefaultRolePool(12);
    expect(pool12['simple_werewolf'], equals(3));
    expect(pool12['thief'], equals(1));
    expect(pool12['cupid'], equals(1));

    // Vérification spécifique table officielle 16 joueurs (4 loups)
    final pool16 = GameNotifier.generateDefaultRolePool(16);
    expect(pool16['simple_werewolf'], equals(4));
    expect(pool16['simple_villager'], equals(6));

    // Vérification table maximale 30 joueurs
    final pool30 = GameNotifier.generateDefaultRolePool(30);
    expect(pool30.values.fold<int>(0, (a, b) => a + b), equals(30));
    expect(pool30['simple_werewolf'], equals(7));
  });

  test('Les rôles de loups sont reconnus comme maléfiques (isEvil)', () {
    expect(GameRole.simpleWerewolf.isEvil, isTrue);
    expect(GameRole.bigBadWolf.isEvil, isTrue);
    expect(GameRole.whiteWerewolf.isEvil, isTrue);
    expect(GameRole.simpleVillager.isEvil, isFalse);
    expect(GameRole.seer.isEvil, isFalse);
    expect(GameRole.witch.isEvil, isFalse);
  });

  test('Reconnaissance mutuelle de la meute entre loups', () {
    final myPlayer = PlayerModel(
      id: 'p1',
      name: 'LoupAlpha',
      role: GameRole.simpleWerewolf,
      isAlive: true,
      agoraUid: 101,
    );

    final allyWolf = PlayerModel(
      id: 'p2',
      name: 'LoupBeta',
      role: GameRole.bigBadWolf,
      isAlive: true,
      agoraUid: 102,
    );

    final villager = PlayerModel(
      id: 'p3',
      name: 'VillageoisInnocent',
      role: GameRole.simpleVillager,
      isAlive: true,
      agoraUid: 103,
    );

    final isMeEvil = myPlayer.role.isEvil;
    expect(isMeEvil, isTrue);

    // Le loup reconnaît son allié
    expect(isMeEvil && allyWolf.role.isEvil, isTrue);

    // Le loup ne prend pas le villageois pour un loup
    expect(isMeEvil && villager.role.isEvil, isFalse);
  });
}
