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

  test('La Voyante inspecte le Loup Blanc comme un Simple Villageois', () {
    // 1. Test via la fonction statique d'inspection
    expect(GameNotifier.getSeerPerceivedRole(GameRole.whiteWerewolf), equals(GameRole.simpleVillager));
    expect(GameNotifier.getSeerPerceivedRole(Role.loupBlanc), equals(Role.simpleVillageois));

    // 2. Les autres rôles conservent leur identité
    expect(GameNotifier.getSeerPerceivedRole(GameRole.simpleWerewolf), equals(GameRole.simpleWerewolf));
    expect(GameNotifier.getSeerPerceivedRole(GameRole.witch), equals(GameRole.witch));
    expect(GameNotifier.getSeerPerceivedRole(GameRole.simpleVillager), equals(GameRole.simpleVillager));

    // 3. Test via le getter de perception de rôle
    expect(GameRole.whiteWerewolf.seerPerception, equals(GameRole.simpleVillager));
    expect(Role.loupBlanc.seerPerception, equals(Role.simpleVillageois));
    expect(GameRole.seer.seerPerception, equals(GameRole.seer));
  });

  test('Le Loup Noir (loupNoir / blackWolf) est un rôle maléfique avec phase nocturne dédiée', () {
    expect(GameRole.blackWolf.isEvil, isTrue);
    expect(Role.loupNoir, equals(GameRole.blackWolf));
    expect(GameRole.blackWolf.id, equals('black_wolf'));
    expect(GameRole.blackWolf.displayName, equals('Loup Noir'));
    expect(GamePhase.nightBlackWolf.isNight, isTrue);
  });

  test('La synchronisation du ciblage du Loup Noir dans GameRoom (blackWolfTargetId)', () {
    final room = GameRoom(
      roomCode: 'TEST_BLACK_WOLF',
      hostId: 'host1',
      blackWolfTargetId: 'target_player_1',
    );

    expect(room.blackWolfTargetId, equals('target_player_1'));

    final map = room.toMap();
    expect(map['blackWolfTargetId'], equals('target_player_1'));

    final restoredRoom = GameRoom.fromMap(map, 'TEST_BLACK_WOLF');
    expect(restoredRoom.blackWolfTargetId, equals('target_player_1'));

    final clearedRoom = restoredRoom.copyWith(clearBlackWolfTargetId: true);
    expect(clearedRoom.blackWolfTargetId, isNull);
  });

  test('La coupure de parole (isMuted = true) persiste sur le joueur ciblé', () {
    final player = PlayerModel(
      id: 'victim_1',
      name: 'SilencedVillager',
      role: GameRole.simpleVillager,
      isMuted: false,
    );

    expect(player.isMuted, isFalse);

    final silencedPlayer = player.copyWith(isMuted: true);
    expect(silencedPlayer.isMuted, isTrue);

    final playerMap = silencedPlayer.toMap();
    expect(playerMap['isMuted'], isTrue);

    final deserializedPlayer = PlayerModel.fromMap(playerMap, 'victim_1');
    expect(deserializedPlayer.isMuted, isTrue);
  });

  test('Anti-doublon et remplacement de socket lors de la reconnexion d\'un joueur', () {
    // 1. Joueur initialement connecté avec un premier socket
    final initialPlayer = PlayerModel(
      id: 'user_unique_123',
      name: 'Lancelot',
      role: GameRole.defender,
      isAlive: true,
      agoraUid: 1001,
      socketId: 'sock_init_abc',
    );

    expect(initialPlayer.id, equals('user_unique_123'));
    expect(initialPlayer.socketId, equals('sock_init_abc'));

    final initialMap = initialPlayer.toMap();
    expect(initialMap['socketId'], equals('sock_init_abc'));

    // 2. Vérification de présence (hasPlayer) dans le salon
    final room = GameRoom(
      roomCode: 'TEST_ROOM',
      hostId: 'host_1',
      players: {'user_unique_123': initialPlayer},
      seatingOrder: ['user_unique_123', 'user_unique_123'], // Tentative de doublon de siège
    );

    expect(room.hasPlayer('user_unique_123'), isTrue);
    expect(room.hasPlayer('user_unknown_999'), isFalse);

    // playerList élimine strictement les doublons
    expect(room.playerList.length, equals(1));
    expect(room.playerList.first.id, equals('user_unique_123'));

    // 3. Reconnexion : remplacement du socket au lieu de dupliquer l'entrée
    const newSocketId = 'sock_reconnected_xyz';
    const newAgoraUid = 1002;

    final reconnectedPlayer = initialPlayer.copyWith(
      socketId: newSocketId,
      agoraUid: newAgoraUid,
    );

    final updatedRoom = room.copyWith(
      players: {
        ...room.players,
        reconnectedPlayer.id: reconnectedPlayer,
      },
    );

    // Le nombre de joueurs n'a pas augmenté (aucune duplication)
    expect(updatedRoom.players.length, equals(1));
    expect(updatedRoom.playerList.length, equals(1));
    expect(updatedRoom.players['user_unique_123']?.socketId, equals(newSocketId));
    expect(updatedRoom.players['user_unique_123']?.agoraUid, equals(newAgoraUid));
    // Le rôle et l'état de vie sont strictement conservés
    expect(updatedRoom.players['user_unique_123']?.role, equals(GameRole.defender));
    expect(updatedRoom.players['user_unique_123']?.isAlive, isTrue);
  });
}

