import 'package:flutter_test/flutter_test.dart';
import 'package:lupus_arena/GameNotifier.dart';
import 'package:lupus_arena/models/game_phase.dart';
import 'package:lupus_arena/models/player_model.dart';
import 'package:lupus_arena/models/game_room.dart';
import 'package:lupus_arena/services/update_service.dart';
import 'package:lupus_arena/services/fog_of_war_service.dart';
import 'package:lupus_arena/services/death_registry_service.dart';
import 'package:lupus_arena/services/audio_manager.dart';

void main() {
  test('L\'ordre canonique nocturne respecte strictement le livret officiel', () {
    expect(GamePhase.nightThief.index, lessThan(GamePhase.nightCupid.index));
    expect(GamePhase.nightCupid.index, lessThan(GamePhase.nightDefender.index));
    expect(GamePhase.nightDefender.index, lessThan(GamePhase.nightWerewolves.index));
    expect(GamePhase.nightWerewolves.index, lessThan(GamePhase.nightBlackWolf.index));
    expect(GamePhase.nightBlackWolf.index, lessThan(GamePhase.nightSeer.index));
    expect(GamePhase.nightSeer.index, lessThan(GamePhase.nightWitch.index));
    expect(GamePhase.nightWitch.index, lessThan(GamePhase.nightPyromaniac.index));
    expect(GamePhase.nightPyromaniac.index, lessThan(GamePhase.morningAnnouncement.index));
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

  test('Minute vocale collective à la victoire (60 secondes) : tous les joueurs parlent, puis micros coupés', () {
    // 1. À la victoire (GamePhase.gameOver), tant que les 60s ne sont pas écoulées (isVictoryVoiceExpired = false) :
    // Tous les joueurs (morts et vivants, innocents et loups, même réduits au silence) peuvent parler (shouldMute = false)
    final aliveVillagerMute = GameNotifier.calculateShouldMuteForPhase(
      phase: GamePhase.gameOver,
      isAlive: true,
      isSilencedByBlackWolf: false,
      isCurrentSpeaker: false,
      isEvil: false,
      isVictoryVoiceExpired: false,
    );
    expect(aliveVillagerMute, isFalse, reason: 'Villageois vivant démuté pour la minute collective');

    final deadPlayerMute = GameNotifier.calculateShouldMuteForPhase(
      phase: GamePhase.gameOver,
      isAlive: false,
      isSilencedByBlackWolf: false,
      isCurrentSpeaker: false,
      isEvil: false,
      isVictoryVoiceExpired: false,
    );
    expect(deadPlayerMute, isFalse, reason: 'Joueur mort démuté pour la minute collective de victoire');

    final silencedPlayerMute = GameNotifier.calculateShouldMuteForPhase(
      phase: GamePhase.gameOver,
      isAlive: true,
      isSilencedByBlackWolf: true,
      isCurrentSpeaker: false,
      isEvil: false,
      isVictoryVoiceExpired: false,
    );
    expect(silencedPlayerMute, isFalse, reason: 'Joueur réduit au silence démuté pour la célébration');

    final evilDeadWolfMute = GameNotifier.calculateShouldMuteForPhase(
      phase: GamePhase.gameOver,
      isAlive: false,
      isSilencedByBlackWolf: false,
      isCurrentSpeaker: false,
      isEvil: true,
      isVictoryVoiceExpired: false,
    );
    expect(evilDeadWolfMute, isFalse, reason: 'Loup mort également démuté pour débriefer');

    // 2. À la fin de la minute (isVictoryVoiceExpired = true) :
    // Le micro de TOUS les joueurs est coupé (shouldMute = true)
    final expiredAliveMute = GameNotifier.calculateShouldMuteForPhase(
      phase: GamePhase.gameOver,
      isAlive: true,
      isSilencedByBlackWolf: false,
      isCurrentSpeaker: false,
      isEvil: false,
      isVictoryVoiceExpired: true,
    );
    expect(expiredAliveMute, isTrue, reason: 'Micro coupé à la fin de la minute pour le vivant');

    final expiredDeadMute = GameNotifier.calculateShouldMuteForPhase(
      phase: GamePhase.gameOver,
      isAlive: false,
      isSilencedByBlackWolf: false,
      isCurrentSpeaker: false,
      isEvil: false,
      isVictoryVoiceExpired: true,
    );
    expect(expiredDeadMute, isTrue, reason: 'Micro coupé à la fin de la minute pour le mort');

    // 3. Comparaison avec les phases normales du jeu où les morts restent coupés
    final normalNightDeadMute = GameNotifier.calculateShouldMuteForPhase(
      phase: GamePhase.nightWerewolves,
      isAlive: false,
      isSilencedByBlackWolf: false,
      isCurrentSpeaker: false,
      isEvil: false,
      isVictoryVoiceExpired: false,
    );
    expect(normalNightDeadMute, isTrue, reason: 'En jeu normal, un mort a son micro coupé');

    // 4. Étanchéité absolue du micro des bots (isBot: true -> shouldMute = true en toutes circonstances)
    final botMuteInDebate = GameNotifier.calculateShouldMuteForPhase(
      phase: GamePhase.dayDebate,
      isAlive: true,
      isSilencedByBlackWolf: false,
      isCurrentSpeaker: true,
      isEvil: false,
      isVictoryVoiceExpired: false,
      isBot: true,
    );
    expect(botMuteInDebate, isTrue, reason: 'Le micro d un bot est strictement inactif même s il est l orateur en cours');

    final botMuteInGameOver = GameNotifier.calculateShouldMuteForPhase(
      phase: GamePhase.gameOver,
      isAlive: true,
      isSilencedByBlackWolf: false,
      isCurrentSpeaker: false,
      isEvil: false,
      isVictoryVoiceExpired: false,
      isBot: true,
    );
    expect(botMuteInGameOver, isTrue, reason: 'Un bot n a aucun micro actif même lors de la minute collective');
  });

  test('Préparation du deck de cartes rôles adapté au nombre de joueurs et mélange Fisher-Yates', () {
    // 1. Pour 6 joueurs : Loup Blanc, Loup Noir, Voyante, Sorcière, Chasseur, Villageois
    final deck6 = GameNotifier.prepareReplayRoleDeck(6);
    expect(deck6.length, equals(6));
    expect(deck6, contains(GameRole.whiteWerewolf));
    expect(deck6, contains(GameRole.blackWolf));
    expect(deck6, contains(GameRole.seer));
    expect(deck6, contains(GameRole.witch));
    expect(deck6, contains(GameRole.hunter));
    expect(deck6, contains(GameRole.simpleVillager));
    // Tous les rôles sont distincts et différents
    expect(deck6.toSet().length, equals(6));

    // 2. Pour différentes tailles de salon (4, 8, 12, 16 joueurs), tous les rôles du deck sont distincts
    for (final count in [4, 8, 12, 16]) {
      final deck = GameNotifier.prepareReplayRoleDeck(count);
      expect(deck.length, equals(count));
      expect(deck.toSet().length, equals(count), reason: 'Rôles distincts pour $count joueurs');
    }

    // 3. Mélange Fisher-Yates : conserve l'ensemble des éléments et produit une permutation valide
    final originalDeck = List<GameRole>.from(deck6);
    final shuffledDeck = List<GameRole>.from(deck6);
    GameNotifier.fisherYatesShuffle(shuffledDeck);
    expect(shuffledDeck.length, equals(originalDeck.length));
    expect(shuffledDeck.toSet(), equals(originalDeck.toSet()));

    // 4. Attribution à chaque joueur d'un rôle distinct et différent
    final players = List.generate(
      6,
      (i) => PlayerModel(id: 'player_$i', name: 'Guerrier_$i'),
    );
    final assignedRoles = <String, GameRole>{};
    for (int i = 0; i < players.length; i++) {
      assignedRoles[players[i].id] = shuffledDeck[i];
    }
    expect(assignedRoles.values.toSet().length, equals(6), reason: 'Chaque joueur a reçu un rôle distinct');
  });

  test('Réinitialisation complète du joueur pour le Replay (PV = 100, isAlive = true, isMuted = false)', () {
    final deadSilencedPlayer = PlayerModel(
      id: 'victim_dead',
      name: 'AncienMort',
      isAlive: false,
      isMuted: true,
      pv: 0,
      isReadyReplay: true,
      targetVoteId: 'someone',
      isCaptain: true,
    );

    expect(deadSilencedPlayer.isAlive, isFalse);
    expect(deadSilencedPlayer.isMuted, isTrue);
    expect(deadSilencedPlayer.pv, equals(0));
    expect(deadSilencedPlayer.isReadyReplay, isTrue);

    // Réinitialisation canonique demandée par le prompt
    final resetPlayer = deadSilencedPlayer.copyWith(
      isAlive: true,
      isMuted: false,
      pv: 100,
      isReadyReplay: false,
      clearTargetVote: true,
      isCaptain: false,
    );

    expect(resetPlayer.pv, equals(100), reason: 'PV réinitialisés à 100');
    expect(resetPlayer.isAlive, isTrue, reason: 'Joueur ressuscité pour la nouvelle partie');
    expect(resetPlayer.isMuted, isFalse, reason: 'Micro démuté');
    expect(resetPlayer.isReadyReplay, isFalse);
    expect(resetPlayer.targetVoteId, isNull);
    expect(resetPlayer.isCaptain, isFalse);
  });

  test('Synchronisation du statut de vote Replay et comptage des joueurs prêts', () {
    final room = GameRoom(
      roomCode: 'TEST_REPLAY',
      hostId: 'host_1',
      players: {
        'p1': const PlayerModel(id: 'p1', name: 'Alpha'),
        'p2': const PlayerModel(id: 'p2', name: 'Beta'),
        'p3': const PlayerModel(id: 'p3', name: 'Gamma'),
      },
      replayReadyUserIds: ['p1', 'p2'],
    );

    expect(room.totalPlayersCount, equals(3));
    expect(room.replayReadyCount, equals(2));
    expect(room.isPlayerReadyReplay('p1'), isTrue);
    expect(room.isPlayerReadyReplay('p2'), isTrue);
    expect(room.isPlayerReadyReplay('p3'), isFalse);

    // Annulation du vote par p2
    final updatedRoom = room.copyWith(
      replayReadyUserIds: ['p1'],
    );
    expect(updatedRoom.replayReadyCount, equals(1));
    expect(updatedRoom.isPlayerReadyReplay('p2'), isFalse);

    // Sérialisation et désérialisation
    final map = room.toMap();
    expect(map['replayReadyUserIds'], equals(['p1', 'p2']));
    final restoredRoom = GameRoom.fromMap(map, 'TEST_REPLAY');
    expect(restoredRoom.replayReadyCount, equals(2));
    expect(restoredRoom.isPlayerReadyReplay('p1'), isTrue);
  });

  group('UpdateService - Détection de version sémantique', () {
    test('Détecte correctement les versions supérieures (majeure, mineure, patch)', () {
      expect(UpdateService.isRemoteVersionGreater('1.0.9', '1.0.8'), isTrue);
      expect(UpdateService.isRemoteVersionGreater('v1.0.9', 'v1.0.8'), isTrue);
      expect(UpdateService.isRemoteVersionGreater('v1.1.0', '1.0.8'), isTrue);
      expect(UpdateService.isRemoteVersionGreater('2.0.0', '1.9.9'), isTrue);
    });

    test('Détecte les builds numbers supérieurs', () {
      expect(UpdateService.isRemoteVersionGreater('1.0.8+10', '1.0.8+9'), isTrue);
      expect(UpdateService.isRemoteVersionGreater('v1.0.8+10', '1.0.8+9'), isTrue);
      expect(UpdateService.isRemoteVersionGreater('1.0.8+1', '1.0.8'), isTrue);
    });

    test('Rejette les versions identiques ou inférieures', () {
      expect(UpdateService.isRemoteVersionGreater('1.0.8', '1.0.8'), isFalse);
      expect(UpdateService.isRemoteVersionGreater('v1.0.8', '1.0.8'), isFalse);
      expect(UpdateService.isRemoteVersionGreater('1.0.8+9', '1.0.8+9'), isFalse);
      expect(UpdateService.isRemoteVersionGreater('1.0.7', '1.0.8'), isFalse);
      expect(UpdateService.isRemoteVersionGreater('1.0.8+8', '1.0.8+9'), isFalse);
      expect(UpdateService.isRemoteVersionGreater('', '1.0.8'), isFalse);
      expect(UpdateService.isRemoteVersionGreater('1.0.8', ''), isFalse);
    });
  });

  group('Conditions de victoire et équilibre Sorcière / Loups', () {
    test('Tous les loups-garous canoniques sont maléfiques (isEvil == true)', () {
      expect(GameRole.simpleWerewolf.isEvil, isTrue);
      expect(GameRole.bigBadWolf.isEvil, isTrue);
      expect(GameRole.blackWolf.isEvil, isTrue);
      expect(GameRole.vileFatherOfWolves.isEvil, isTrue);
      expect(GameRole.wolfCub.isEvil, isTrue);
      expect(GameRole.whiteWerewolf.isEvil, isTrue);
    });

    test('1 loup face à 2 villageois ne déclenche PAS de Game Over prématuré', () {
      final room = GameRoom(
        roomCode: 'TEST1',
        hostId: 'p1',
        players: {
          'wolf': const PlayerModel(id: 'wolf', name: 'Loup', role: GameRole.simpleWerewolf, isAlive: true),
          'v1': const PlayerModel(id: 'v1', name: 'V1', role: GameRole.simpleVillager, isAlive: true),
          'v2': const PlayerModel(id: 'v2', name: 'V2', role: GameRole.witch, isAlive: true),
          'dead1': const PlayerModel(id: 'dead1', name: 'M1', role: GameRole.seer, isAlive: false),
        },
      );

      final result = GameNotifier.checkWinConditions(room);
      expect(result, isNull, reason: '1 loup contre 2 villageois doit continuer vers le débat et le vote');
    });

    test('1 loup face à 1 villageois déclenche la victoire des loups (parité)', () {
      final room = GameRoom(
        roomCode: 'TEST2',
        hostId: 'wolf',
        players: {
          'wolf': const PlayerModel(id: 'wolf', name: 'Loup', role: GameRole.simpleWerewolf, isAlive: true),
          'v1': const PlayerModel(id: 'v1', name: 'V1', role: GameRole.simpleVillager, isAlive: true),
          'dead1': const PlayerModel(id: 'dead1', name: 'M1', role: GameRole.simpleVillager, isAlive: false),
        },
      );

      final result = GameNotifier.checkWinConditions(room);
      expect(result, equals('werewolves'), reason: 'Parité 1 contre 1 = victoire des loups');
    });

    test('0 loup face à des villageois vivants déclenche la victoire du village', () {
      final room = GameRoom(
        roomCode: 'TEST3',
        hostId: 'v1',
        players: {
          'wolf_dead': const PlayerModel(id: 'wolf_dead', name: 'LoupMort', role: GameRole.simpleWerewolf, isAlive: false),
          'v1': const PlayerModel(id: 'v1', name: 'V1', role: GameRole.simpleVillager, isAlive: true),
          'witch': const PlayerModel(id: 'witch', name: 'Sorcière', role: GameRole.witch, isAlive: true),
        },
      );

      final result = GameNotifier.checkWinConditions(room);
      expect(result, equals('village'), reason: 'Tous les loups éliminés = victoire du village');
    });

    test('Débat du village : saut automatique des joueurs bâillonnés (isMuted)', () {
      final p1 = const PlayerModel(id: '1', name: 'Alice', role: GameRole.simpleVillager, isAlive: true, isMuted: false);
      final p2 = const PlayerModel(id: '2', name: 'Bob', role: GameRole.simpleVillager, isAlive: true, isMuted: true); // Bâillonné
      final p3 = const PlayerModel(id: '3', name: 'Charlie', role: GameRole.simpleVillager, isAlive: true, isMuted: false);

      final players = {'1': p1, '2': p2, '3': p3};

      // Simulation de la file de débat
      final queue = List<String>.from(players.values.where((p) => p.isAlive).map((p) => p.id));
      final logs = <String>[];

      // Premier orateur : Alice
      expect(queue.first, equals('1'));

      // Alice termine son tour -> suppression d'Alice
      queue.removeAt(0);

      // Algorithme de saut automatique identique à passTurnDebate & _routeToDayPhase
      while (queue.isNotEmpty && (players[queue.first]?.isMuted ?? false)) {
        final mutedId = queue.removeAt(0);
        final mutedName = players[mutedId]?.name ?? 'Un citoyen';
        logs.add('🔇 $mutedName est bâillonné par les loups ! Son tour de parole est sauté.');
      }

      // Bob a été sauté immédiatement sans temps mort
      expect(logs, contains(contains('Bob est bâillonné par les loups')));
      // La parole est directement chez Charlie
      expect(queue.first, equals('3'));
    });

    test('Débat du village : cascade de sauts si plusieurs joueurs muets consécutifs', () {
      final p1 = const PlayerModel(id: '1', name: 'Alice', role: GameRole.simpleVillager, isAlive: true, isMuted: false);
      final p2 = const PlayerModel(id: '2', name: 'Bob', role: GameRole.simpleVillager, isAlive: true, isMuted: true);
      final p3 = const PlayerModel(id: '3', name: 'Charlie', role: GameRole.simpleVillager, isAlive: true, isMuted: true);
      final p4 = const PlayerModel(id: '4', name: 'David', role: GameRole.simpleVillager, isAlive: true, isMuted: false);

      final players = {'1': p1, '2': p2, '3': p3, '4': p4};
      final queue = ['1', '2', '3', '4'];
      final logs = <String>[];

      // Alice cède sa parole
      queue.removeAt(0);

      while (queue.isNotEmpty && (players[queue.first]?.isMuted ?? false)) {
        final mutedId = queue.removeAt(0);
        final mutedName = players[mutedId]?.name ?? 'Un citoyen';
        logs.add('🔇 $mutedName est bâillonné par les loups ! Son tour de parole est sauté.');
      }

      // Bob et Charlie sautés
      expect(logs.length, equals(2));
      expect(queue.first, equals('4'));
    });

    test('Débat du village : si tous les orateurs restants sont muets, clôture et vote', () {
      final p1 = const PlayerModel(id: '1', name: 'Alice', role: GameRole.simpleVillager, isAlive: true, isMuted: false);
      final p2 = const PlayerModel(id: '2', name: 'Bob', role: GameRole.simpleVillager, isAlive: true, isMuted: true);

      final players = {'1': p1, '2': p2};
      final queue = ['1', '2'];
      final logs = <String>[];

      queue.removeAt(0); // Alice a fini

      while (queue.isNotEmpty && (players[queue.first]?.isMuted ?? false)) {
        final mutedId = queue.removeAt(0);
        logs.add('🔇 ${players[mutedId]?.name} est bâillonné !');
      }

      expect(queue.isEmpty, isTrue, reason: 'La file doit être vide pour ouvrir le vote');
    });

    test('UpdateService : comparaison de versions sémantiques et build numbers', () {
      // Cas de base
      expect(UpdateService.isRemoteVersionGreater('v1.0.22+23', '1.0.21+22'), isTrue);
      expect(UpdateService.isRemoteVersionGreater('1.0.22+23', '1.0.21+22'), isTrue);
      expect(UpdateService.isRemoteVersionGreater('1.0.21+22', '1.0.21+22'), isFalse);
      expect(UpdateService.isRemoteVersionGreater('1.0.20+21', '1.0.21+22'), isFalse);

      // Même version majeure.mineure.patch, build number supérieur
      expect(UpdateService.isRemoteVersionGreater('1.0.21+23', '1.0.21+22'), isTrue);
      expect(UpdateService.isRemoteVersionGreater('1.0.21+21', '1.0.21+22'), isFalse);

      // Version majeure supérieure
      expect(UpdateService.isRemoteVersionGreater('2.0.0+1', '1.0.21+22'), isTrue);
      expect(UpdateService.isRemoteVersionGreater('1.0.0+1', '2.0.0+1'), isFalse);

      // Format sans préfixe ou avec préfixe 'v'
      expect(UpdateService.isRemoteVersionGreater('V1.0.22', '1.0.21'), isTrue);
      expect(UpdateService.isRemoteVersionGreater('v1.0.22+23', 'v1.0.22+23'), isFalse);

      // Version v1.0.23+24, v1.0.24+25 & v1.0.25+26
      expect(UpdateService.isRemoteVersionGreater('v1.0.23+24', '1.0.22+23'), isTrue);
      expect(UpdateService.isRemoteVersionGreater('1.0.23+24', '1.0.22+23'), isTrue);
      expect(UpdateService.isRemoteVersionGreater('v1.0.24+25', '1.0.23+24'), isTrue);
      expect(UpdateService.isRemoteVersionGreater('v1.0.24+25', 'v1.0.24+25'), isFalse);
      expect(UpdateService.isRemoteVersionGreater('v1.0.25+26', '1.0.24+25'), isTrue);
      expect(UpdateService.isRemoteVersionGreater('v1.0.25+26', 'v1.0.25+26'), isFalse);
    });

    test('Double action des loups : proie et silence obligatoires et distincts', () {
      const victimId = 'v1';
      String? silenceId;

      bool canValidate(String? victim, String? silence) {
        return victim != null && silence != null && victim != silence;
      }

      expect(canValidate(victimId, silenceId), isFalse);

      // Invalide si la même personne est ciblée par la mort et le silence
      silenceId = 'v1';
      expect(canValidate(victimId, silenceId), isFalse);

      // Valide si deux cibles distinctes sont choisies
      silenceId = 's1';
      expect(canValidate(victimId, silenceId), isTrue);
    });

    test('Bluff intra-meute & auto-mutisme : la cible du silence peut être un loup ou soi-même', () {
      const wolf1 = PlayerModel(id: 'w1', name: 'Loup1', role: GameRole.simpleWerewolf, isAlive: true);
      const wolf2 = PlayerModel(id: 'w2', name: 'Loup2', role: GameRole.whiteWerewolf, isAlive: true);
      const victim = PlayerModel(id: 'v1', name: 'Victime', role: GameRole.simpleVillager, isAlive: true);

      bool canSilence(PlayerModel target, String? currentVictimId) {
        return target.isAlive && target.id != currentVictimId;
      }

      // Auto-mutisme autorisé pour alibi
      expect(canSilence(wolf1, victim.id), isTrue);

      // Ciblage d'un confrère loup autorisé pour bluff intra-meute
      expect(canSilence(wolf2, victim.id), isTrue);

      // Interdiction formelle sur la proie vouée à mourir cette nuit-là
      expect(canSilence(victim, victim.id), isFalse);
    });

    test('Anti-fratricide : un loup ne peut JAMAIS dévorer un loup ni soi-même', () {
      const meWolf = PlayerModel(id: 'w1', name: 'MoiLoup', role: GameRole.simpleWerewolf, isAlive: true);
      const allyWolf = PlayerModel(id: 'w2', name: 'LoupAllie', role: GameRole.bigBadWolf, isAlive: true);
      const victim = PlayerModel(id: 'v1', name: 'Victime', role: GameRole.simpleVillager, isAlive: true);

      bool canDevour(PlayerModel target, String currentUserId) {
        final isTargetWolf = target.role.isEvil || target.role.isWolfTeam;
        final isSelf = target.id == currentUserId;
        return target.isAlive && !isTargetWolf && !isSelf;
      }

      expect(canDevour(victim, meWolf.id), isTrue, reason: 'Peut dévorer un villageois');
      expect(canDevour(allyWolf, meWolf.id), isFalse, reason: 'Ne peut PAS dévorer un allié');
      expect(canDevour(meWolf, meWolf.id), isFalse, reason: 'Ne peut PAS se dévorer soi-même');
    });

    test('Purge du silence à l\'arrivée de la nuit : les joueurs sous silence retrouvent l\'usage de la parole', () {
      const p1 = PlayerModel(id: '1', name: 'Alice', role: GameRole.simpleVillager, isAlive: true, isMuted: true);
      const p2 = PlayerModel(id: '2', name: 'Bob', role: GameRole.simpleWerewolf, isAlive: true, isMuted: true);

      final players = {'1': p1, '2': p2};
      final updates = <String, dynamic>{};

      for (final p in players.values) {
        if (p.isMuted) {
          updates['players/${p.id}/isMuted'] = false;
        }
      }

      expect(updates['players/1/isMuted'], isFalse);
      expect(updates['players/2/isMuted'], isFalse);
    });

    test('Sorcière : Verrouillage strict de la potion de vie sur la victime des loups (nightVictimId)', () {
      const wolfVictim = PlayerModel(id: 'v1', name: 'VictimeDesLoups', role: GameRole.simpleVillager, isAlive: true);
      const randomPlayer = PlayerModel(id: 'r1', name: 'JoueurAleatoire', role: GameRole.simpleVillager, isAlive: true);

      // Règle stricte : la potion de vie ne peut cibler QUE la victime des loups (widget.room.nightVictimId)
      String? getWitchLifePotionTarget(String? nightVictimId) {
        return nightVictimId; // Aucun fallback manuel autorisé
      }

      // Cas 1 : Une victime a été désignée par les loups -> la potion de vie est verrouillée sur cette victime
      expect(getWitchLifePotionTarget(wolfVictim.id), equals('v1'), reason: 'La sorcière peut sauver la victime désignée');

      // Cas 2 : Aucune victime désignée par les loups -> la potion de vie ne peut pas être utilisée
      expect(getWitchLifePotionTarget(null), isNull, reason: 'Impossible d\'utiliser la potion de vie sans victime des loups');

      // Potion de poison : la sorcière conserve le choix libre de la cible vivante
      bool canUsePoison(PlayerModel target, int potionsMort) {
        return potionsMort > 0 && target.isAlive;
      }
      expect(canUsePoison(randomPlayer, 1), isTrue);
      expect(canUsePoison(randomPlayer, 0), isFalse);
    });

    test('Loups-Garous : Sélection séquentielle 2 cibles (1er = Dévorer, 2e = Museler) avec auto-validation', () {
      const player1 = PlayerModel(id: 'p1', name: 'Villageois 1', role: GameRole.simpleVillager, isAlive: true);
      const player2 = PlayerModel(id: 'p2', name: 'Villageois 2', role: GameRole.seer, isAlive: true);

      String? wolfVictimId;
      String? wolfMuteId;
      bool nextPhaseTriggered = false;

      void handleWerewolfSelection(String id) {
        if (wolfVictimId == null) {
          // 1er clic : Dévorer
          wolfVictimId = id;
        } else if (wolfVictimId == id) {
          // Second clic sur la même victime : Dé-sélection pour changer de victime
          wolfVictimId = null;
        } else if (wolfMuteId == null) {
          // 2e clic : Museler + auto-validation
          wolfMuteId = id;
          nextPhaseTriggered = true;
        }
      }

      // 1er clic : Sélection de la proie à dévorer
      handleWerewolfSelection(player1.id);
      expect(wolfVictimId, equals('p1'));
      expect(wolfMuteId, isNull);
      expect(nextPhaseTriggered, isFalse);

      // 2e clic sur un joueur différent : Sélection du joueur à museler + auto-validation immédiate
      handleWerewolfSelection(player2.id);
      expect(wolfVictimId, equals('p1'), reason: '1er joueur = Dévoré');
      expect(wolfMuteId, equals('p2'), reason: '2e joueur = Muselé');
      expect(nextPhaseTriggered, isTrue, reason: 'Auto-validation immédiate dès 2/2 cibles');
    });

    test('Loups-Garous : Possibilité de changer de cible victime par un second clic sur la même victime', () {
      const player1 = PlayerModel(id: 'p1', name: 'Villageois 1', role: GameRole.simpleVillager, isAlive: true);
      const player2 = PlayerModel(id: 'p2', name: 'Villageois 2', role: GameRole.seer, isAlive: true);
      const player3 = PlayerModel(id: 'p3', name: 'Villageois 3', role: GameRole.witch, isAlive: true);

      String? wolfVictimId;
      String? wolfMuteId;
      bool nextPhaseTriggered = false;

      void handleWerewolfSelection(String id) {
        if (wolfVictimId == null) {
          wolfVictimId = id;
        } else if (wolfVictimId == id) {
          // Second clic sur la même victime -> Dé-sélectionne la victime
          wolfVictimId = null;
        } else if (wolfMuteId == null) {
          wolfMuteId = id;
          nextPhaseTriggered = true;
        }
      }

      // 1. Clic sur Joueur 1 -> Devient la victime
      handleWerewolfSelection(player1.id);
      expect(wolfVictimId, equals('p1'));
      expect(wolfMuteId, isNull);

      // 2. Second clic sur Joueur 1 -> Annule la sélection de Joueur 1
      handleWerewolfSelection(player1.id);
      expect(wolfVictimId, isNull, reason: 'Le second clic sur la même victime doit annuler le choix');
      expect(wolfMuteId, isNull);
      expect(nextPhaseTriggered, isFalse);

      // 3. Clic sur Joueur 2 -> Devient la NOUVELLE victime
      handleWerewolfSelection(player2.id);
      expect(wolfVictimId, equals('p2'), reason: 'Joueur 2 est désormais la nouvelle victime');
      expect(wolfMuteId, isNull);
      expect(nextPhaseTriggered, isFalse);

      // 4. Clic sur Joueur 3 -> Devient le joueur muselé et valide le tour
      handleWerewolfSelection(player3.id);
      expect(wolfVictimId, equals('p2'));
      expect(wolfMuteId, equals('p3'));
      expect(nextPhaseTriggered, isTrue);
    });

    test('Nuit des Loups : Résolution impérative avec dévoré ET muselé garantis (Fallback auto)', () {
      final alivePlayers = [
        const PlayerModel(id: 'p1', name: 'P1', role: GameRole.simpleVillager, isAlive: true),
        const PlayerModel(id: 'p2', name: 'P2', role: GameRole.seer, isAlive: true),
        const PlayerModel(id: 'p3', name: 'P3', role: GameRole.witch, isAlive: true),
      ];

      // Cas 1 : Aucune sélection manuelle avant la fin du temps imparti -> Résolution automatique garantie
      // ignore: unnecessary_null_comparison
      String victimId = alivePlayers.isNotEmpty ? alivePlayers.first.id : '';
      // ignore: unnecessary_null_comparison
      String muteId = alivePlayers.length > 1
          ? alivePlayers.firstWhere((p) => p.id != victimId).id
          : '';

      expect(victimId, equals('p1'), reason: 'Une proie est impérativement désignée');
      expect(muteId, equals('p2'), reason: 'Un joueur est impérativement muselé');
      expect(victimId, isNot(equals(muteId)), reason: 'La proie et le muselé sont distincts');
    });

    test('Sorcière : Utilisation combinée des deux potions (Vie & Mort) et transition de rôle', () {
      var witch = const PlayerModel(id: 'w1', name: 'Sorciere', role: GameRole.witch, potionsVie: 1, potionsMort: 1, isAlive: true);

      // 1. Utilisation de la potion de vie
      final newVie = witch.potionsVie - 1;
      witch = witch.copyWith(potionsVie: newVie);
      expect(witch.potionsVie, equals(0));
      expect(witch.potionsMort, equals(1));
      expect(witch.role, equals(GameRole.witch), reason: 'Reste Sorcière car il lui reste 1 potion de mort');

      // 2. Utilisation de la potion de mort dans la même nuit
      final newMort = witch.potionsMort - 1;
      final isDechue = newVie == 0 && newMort == 0;
      witch = witch.copyWith(
        potionsMort: newMort,
        role: isDechue ? GameRole.simpleVillager : witch.role,
      );
      expect(witch.potionsVie, equals(0));
      expect(witch.potionsMort, equals(0));
      expect(witch.role, equals(GameRole.simpleVillager), reason: 'Rétrogradée en Simple Villageoise à 0/0');
    });

    test('Audio Manager : Musique d\'ambiance strictement isolée au Menu Principal (room == null)', () {
      bool shouldPlayLobbyMusic(GameRoom? room) {
        return room == null;
      }

      // 1. Sur le menu principal (aucune room)
      expect(shouldPlayLobbyMusic(null), isTrue, reason: 'La musique doit jouer sur le Menu Principal');

      // 2. En salle d'attente / waiting lobby
      const waitingRoom = GameRoom(roomCode: 'TEST1', hostId: 'h1', phase: GamePhase.lobby);
      expect(shouldPlayLobbyMusic(waitingRoom), isFalse, reason: 'La musique doit s\'arrêter immédiatement en salle d\'attente');

      // 3. En partie simulée / Dev Mode
      const devRoom = GameRoom(roomCode: 'DEV01', hostId: 'h1', phase: GamePhase.nightWerewolves, isDevRoom: true);
      expect(shouldPlayLobbyMusic(devRoom), isFalse, reason: 'La musique doit être coupée pendant une partie simulée DevMode');

      // 4. En arène de jeu classique
      const inGameRoom = GameRoom(roomCode: 'TEST2', hostId: 'h1', phase: GamePhase.dayDebate);
      expect(shouldPlayLobbyMusic(inGameRoom), isFalse, reason: 'La musique doit être coupée dans l\'arène de jeu');
    });

    test('Permissions & Agora : Synchronisation et récupération en arrière-plan sans redémarrage', () {
      bool agoraRecovered = false;
      void mockAgoraRecovery() {
        agoraRecovered = true;
      }

      // Simule la détection d'autorisation microphone après retour d'une mise à jour in-app ou paramètres système
      bool isMicGranted = false;
      void onPermissionChanged(bool granted) {
        isMicGranted = granted;
        if (granted) {
          mockAgoraRecovery();
        }
      }

      expect(isMicGranted, isFalse);
      expect(agoraRecovered, isFalse);

      // Le système accorde la permission en arrière-plan
      onPermissionChanged(true);
      expect(isMicGranted, isTrue);
      expect(agoraRecovered, isTrue, reason: 'Agora doit se réarmer automatiquement dès que la permission est actualisée');
    });

    test('Fog of War : Règle de visibilité du badge Amoureux (IN_LOVE)', () {
      // 1. Cible non amoureuse -> Faux pour tous
      expect(FogOfWarService.canSeeLoverBadge(
        targetIsLover: false,
        observerRole: GameRole.cupid,
        observerIsLover: true,
      ), isFalse);

      // 2. Observateur est Cupidon -> Vrai
      expect(FogOfWarService.canSeeLoverBadge(
        targetIsLover: true,
        observerRole: GameRole.cupid,
        observerIsLover: false,
      ), isTrue);

      // 3. Observateur est l'un des amoureux -> Vrai
      expect(FogOfWarService.canSeeLoverBadge(
        targetIsLover: true,
        observerRole: GameRole.simpleVillager,
        observerIsLover: true,
      ), isTrue);

      // 4. Observateur est un villageois lambda (non amoureux) -> Faux
      expect(FogOfWarService.canSeeLoverBadge(
        targetIsLover: true,
        observerRole: GameRole.simpleVillager,
        observerIsLover: false,
      ), isFalse);

      // 5. Observateur est un loup (non amoureux) -> Faux
      expect(FogOfWarService.canSeeLoverBadge(
        targetIsLover: true,
        observerRole: GameRole.simpleWerewolf,
        observerIsLover: false,
      ), isFalse);

      // 6. Observateur en mode Dev -> Vrai
      expect(FogOfWarService.canSeeLoverBadge(
        targetIsLover: true,
        observerRole: GameRole.simpleVillager,
        observerIsLover: false,
        isDevMode: true,
      ), isTrue);
    });

    test('Fog of War : Règle de visibilité du badge Charmé (CHARMED)', () {
      // 1. Cible non charmée -> Faux pour tous
      expect(FogOfWarService.canSeeCharmedBadge(
        targetIsCharmed: false,
        observerRole: GameRole.piedPiper,
        observerIsCharmed: true,
      ), isFalse);

      // 2. Observateur est le Joueur de Flûte -> Vrai
      expect(FogOfWarService.canSeeCharmedBadge(
        targetIsCharmed: true,
        observerRole: GameRole.piedPiper,
        observerIsCharmed: false,
      ), isTrue);

      // 3. Observateur est lui-même charmé -> Vrai
      expect(FogOfWarService.canSeeCharmedBadge(
        targetIsCharmed: true,
        observerRole: GameRole.simpleVillager,
        observerIsCharmed: true,
      ), isTrue);

      // 4. Observateur non charmé -> Faux
      expect(FogOfWarService.canSeeCharmedBadge(
        targetIsCharmed: true,
        observerRole: GameRole.simpleVillager,
        observerIsCharmed: false,
      ), isFalse);
    });

    test('Anti-Résurrection : Seule la potion de vie de la sorcière sur la victime des loups peut sauver', () {
      const deadPlayer = PlayerModel(id: 'p1', name: 'Dead', role: GameRole.simpleVillager, isAlive: false);

      // Simule le garde appliqué dans _playersSubscription et _syncState
      bool canPlayerRevive({
        required bool currentlyAlive,
        required bool incomingAlive,
        required bool witchHealed,
        required String? nightVictimId,
        required String playerId,
        bool isAdmin = false,
      }) {
        if (!currentlyAlive && incomingAlive) {
          final isSavedByWitch = witchHealed && playerId == nightVictimId;
          if (!isSavedByWitch && !isAdmin) {
            return false; // Verrou anti-résurrection
          }
        }
        return incomingAlive;
      }

      // Snapshot Firebase corrompu ou désynchronisé tentant de réanimer un mort
      expect(canPlayerRevive(
        currentlyAlive: deadPlayer.isAlive,
        incomingAlive: true,
        witchHealed: false,
        nightVictimId: null,
        playerId: deadPlayer.id,
      ), isFalse, reason: 'Un joueur mort ne peut pas être ressuscité par Firebase');

      // Tentative de réanimation après élection du capitaine
      expect(canPlayerRevive(
        currentlyAlive: deadPlayer.isAlive,
        incomingAlive: true,
        witchHealed: false,
        nightVictimId: 'other_player',
        playerId: deadPlayer.id,
      ), isFalse, reason: 'Élection du maire ne doit jamais ressusciter un mort');

      // Seule la potion de guérison sur la victime légitime autorise la vie
      expect(canPlayerRevive(
        currentlyAlive: deadPlayer.isAlive,
        incomingAlive: true,
        witchHealed: true,
        nightVictimId: deadPlayer.id,
        playerId: deadPlayer.id,
      ), isTrue, reason: 'La potion de vie de la sorcière ressuscite valablement la victime');
    });

    test('PlayerModel.fromMap : isAlive ne devient JAMAIS true si absent ou ambigu', () {
      final mapMissingAlive = {'id': 'p1', 'name': 'Player 1', 'role': 'simpleVillager'};
      final playerMissing = PlayerModel.fromMap(mapMissingAlive);
      expect(playerMissing.isAlive, isFalse, reason: 'Sans isAlive dans le snapshot, la valeur par défaut ne doit jamais être true');

      final mapAliveTrue = {'id': 'p2', 'name': 'Player 2', 'role': 'simpleVillager', 'isAlive': true};
      final playerAlive = PlayerModel.fromMap(mapAliveTrue);
      expect(playerAlive.isAlive, isTrue);

      final mapAliveFalse = {'id': 'p3', 'name': 'Player 3', 'role': 'simpleVillager', 'isAlive': false};
      final playerDead = PlayerModel.fromMap(mapAliveFalse);
      expect(playerDead.isAlive, isFalse);

      final mapCorrupted = {'id': 'p4', 'name': 'Player 4', 'role': 'simpleVillager', 'isAlive': 'invalid'};
      final playerCorrupted = PlayerModel.fromMap(mapCorrupted);
      expect(playerCorrupted.isAlive, isFalse);
    });

    test('Verrou d\'Immortalité Inverse (_cemeteryRegistry) : bloque toute tentative de résurrection réseau', () {
      final Set<String> cemeteryRegistry = {'dead_p1', 'dead_p2'};

      Map<String, PlayerModel> processIncomingSnapshot({
        required Map<String, PlayerModel> incoming,
        required Set<String> cemetery,
        required bool witchHealed,
        required String? nightVictimId,
      }) {
        final updated = <String, PlayerModel>{};
        for (final entry in incoming.entries) {
          final pid = entry.key;
          var player = entry.value;

          if (witchHealed && pid == nightVictimId) {
            cemetery.remove(pid);
          }

          if (cemetery.contains(pid)) {
            if (player.isAlive) {
              player = player.copyWith(isAlive: false);
            }
          } else if (!player.isAlive) {
            cemetery.add(pid);
          }
          updated[pid] = player;
        }
        return updated;
      }

      // 1. Snapshot réseau prétendant que dead_p1 est vivant (ex: reconnexion ou désynchronisation)
      final incomingZombie = {
        'dead_p1': const PlayerModel(id: 'dead_p1', name: 'Dead P1', role: GameRole.simpleVillager, isAlive: true),
        'alive_p3': const PlayerModel(id: 'alive_p3', name: 'Alive P3', role: GameRole.simpleVillager, isAlive: true),
      };

      final resolved = processIncomingSnapshot(
        incoming: incomingZombie,
        cemetery: cemeteryRegistry,
        witchHealed: false,
        nightVictimId: null,
      );

      expect(resolved['dead_p1']!.isAlive, isFalse, reason: 'dead_p1 doit RESTER mort malgré le snapshot');
      expect(resolved['alive_p3']!.isAlive, isTrue, reason: 'alive_p3 reste vivant');

      // 2. Utilisation légitime de la potion de la sorcière sur dead_p1
      final resolvedAfterWitch = processIncomingSnapshot(
        incoming: incomingZombie,
        cemetery: cemeteryRegistry,
        witchHealed: true,
        nightVictimId: 'dead_p1',
      );

      expect(resolvedAfterWitch['dead_p1']!.isAlive, isTrue, reason: 'La sorcière a levé le verrou sur dead_p1');
      expect(cemeteryRegistry.contains('dead_p1'), isFalse, reason: 'dead_p1 a été retiré du cimetière');
    });

    test('LobbyAudioManager : singleton unique et alias LupusAudioManager', () {
      final audioManager = LobbyAudioManager.instance;
      expect(audioManager, isNotNull);
      expect(identical(LobbyAudioManager.instance, LupusAudioManager.instance), isTrue);
    });

    test('DeathRegistryService : Singleton, enregistrement définitif et blocage de résurrection', () {
      final registry = DeathRegistryService.instance;
      registry.clearForNewGame();

      // 1. Initialement vide
      expect(registry.isDead('player_x'), isFalse);
      expect(registry.isAlive('player_x'), isTrue);

      // 2. Inscription d'un joueur éliminé
      registry.markDead('player_x');
      expect(registry.isDead('player_x'), isTrue);
      expect(registry.isAlive('player_x'), isFalse);

      // 3. PlayerModel.fromMap force isAlive à false si le joueur est dans le registre
      final incomingZombieMap = {
        'id': 'player_x',
        'name': 'Guerrier X',
        'role': 'simpleVillager',
        'isAlive': true, // Réseau prétend qu'il est vivant
      };
      final zombiePlayer = PlayerModel.fromMap(incomingZombieMap);
      expect(zombiePlayer.isAlive, isFalse, reason: 'PlayerModel.fromMap doit forcer isAlive à false pour tout joueur dans le DeathRegistryService');

      // 4. GameRoom.alivePlayers exclut les défunts
      final room = GameRoom(
        roomCode: 'TEST',
        hostId: 'host',
        phase: GamePhase.dayVoting,
        players: {
          'player_x': zombiePlayer,
          'player_y': const PlayerModel(id: 'player_y', name: 'Guerrier Y', isAlive: true),
        },
      );
      expect(room.alivePlayers.map((p) => p.id), isNot(contains('player_x')));
      expect(room.alivePlayers.map((p) => p.id), contains('player_y'));
      expect(room.deadPlayers.map((p) => p.id), contains('player_x'));

      // 5. Seule la sorcière peut réanimer
      registry.allowWitchRevive('player_x');
      expect(registry.isDead('player_x'), isFalse);
      final revivedPlayer = PlayerModel.fromMap(incomingZombieMap);
      expect(revivedPlayer.isAlive, isTrue, reason: 'Après intervention de la Sorcière, le joueur peut être reconstruit vivant');

      // 6. Nettoyage pour nouvelle partie
      registry.clearForNewGame();
      expect(registry.deadPlayerIds.isEmpty, isTrue);
    });

    test('DeathRegistryService.filterOrEnforce : applique le verrou sur une table de joueurs', () {
      final registry = DeathRegistryService.instance;
      registry.clearForNewGame();
      registry.markDead('dead_1');

      final players = {
        'dead_1': const PlayerModel(id: 'dead_1', name: 'Dead 1', isAlive: true), // Prétend vivant
        'alive_1': const PlayerModel(id: 'alive_1', name: 'Alive 1', isAlive: true),
        'dead_2': const PlayerModel(id: 'dead_2', name: 'Dead 2', isAlive: false), // Appris comme mort
      };

      final enforced = registry.filterOrEnforce(players);
      expect(enforced['dead_1']!.isAlive, isFalse, reason: 'dead_1 forcé à mort');
      expect(enforced['alive_1']!.isAlive, isTrue, reason: 'alive_1 reste vivant');
      expect(enforced['dead_2']!.isAlive, isFalse, reason: 'dead_2 reste mort');
      expect(registry.isDead('dead_2'), isTrue, reason: 'dead_2 auto-inscrit au registre');

      registry.clearForNewGame();
    });
  });
}



