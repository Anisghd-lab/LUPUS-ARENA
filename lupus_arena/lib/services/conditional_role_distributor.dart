import 'dart:math';

import '../models/game_phase.dart';
import '../models/game_role.dart';
import '../models/player_model.dart';
import 'role_security_service.dart';

/// Résultat complet de la redistribution conditionnelle des rôles
class RoleDistributionResult {
  final Map<String, PlayerModel> updatedPlayers;
  final Map<String, String> secretRoleTokens;
  final String encryptedWolfRoster;
  final List<String> seatingOrder;
  final GamePhase startingPhase;
  final int maxVisions;
  final int maxPotions;

  const RoleDistributionResult({
    required this.updatedPlayers,
    required this.secretRoleTokens,
    required this.encryptedWolfRoster,
    required this.seatingOrder,
    required this.startingPhase,
    required this.maxVisions,
    required this.maxPotions,
  });
}

/// Service de redistribution aléatoire conditionnelle des rôles
/// intégrant un double mélange Fisher-Yates cryptographique,
/// un algorithme anti-répétition consécutive par UID,
/// et le dimensionnement dynamique des quotas de visions et potions.
class ConditionalRoleDistributor {
  /// Calcule le quota dynamique de visions de la Voyante : max(1, nbJoueurs ~/ 4)
  static int computeVisionsQuota(int playerCount) {
    return max(1, playerCount ~/ 4);
  }

  /// Calcule le quota dynamique de potions de la Sorcière : max(1, nbJoueurs ~/ 10)
  static int computePotionsQuota(int playerCount) {
    return max(1, playerCount ~/ 10);
  }

  /// Génère une liste de rôles déployée à partir d'un pool de rôles (ex: {'seer': 1, 'simple_werewolf': 2})
  static List<GameRole> expandRolePool(Map<String, int> rolePool, int targetCount) {
    final List<GameRole> roles = [];
    rolePool.forEach((roleKey, count) {
      final role = GameRole.fromId(roleKey);
      for (int i = 0; i < count; i++) {
        roles.add(role);
      }
    });

    // Ajustement strict à targetCount
    while (roles.length < targetCount) {
      roles.add(GameRole.simpleVillager);
    }
    if (roles.length > targetCount) {
      roles.removeRange(targetCount, roles.length);
    }

    return roles;
  }

  /// Mélange de Fisher-Yates (Knuth) garanti O(N) avec générateur cryptographique sécurisé
  static void fisherYatesShuffle<T>(List<T> list, Random random) {
    for (int i = list.length - 1; i > 0; i--) {
      final j = random.nextInt(i + 1);
      final temp = list[i];
      list[i] = list[j];
      list[j] = temp;
    }
  }

  /// Exécute la redistribution conditionnelle complète
  static RoleDistributionResult distribute({
    required Map<String, PlayerModel> currentPlayers,
    required Map<String, int> rolePool,
    required String roomCode,
    Map<String, GameRole>? previousRoles,
  }) {
    final playerList = currentPlayers.values.toList();
    final int playerCount = playerList.length;
    final rand = Random.secure();

    // 1. Quotas dynamiques
    final maxVisions = computeVisionsQuota(playerCount);
    final maxPotions = computePotionsQuota(playerCount);

    // 2. Déploiement et double mélange du deck de cartes
    final expandedRoles = expandRolePool(rolePool, playerCount);
    fisherYatesShuffle(expandedRoles, rand);
    fisherYatesShuffle(expandedRoles, rand); // Double brassage cryptographique

    // 3. Optimisation anti-répétition consécutive par UID
    final playerUids = playerList.map((p) => p.id).toList();
    fisherYatesShuffle(playerUids, rand); // Mélange des places

    final assignedRoles = _optimizeRoleAssignment(
      playerUids: playerUids,
      availableRoles: List<GameRole>.from(expandedRoles),
      previousRoles: previousRoles ?? {},
      rand: rand,
    );

    // 4. Seating Order aléatoire
    final seatingOrder = List<String>.from(playerUids);
    fisherYatesShuffle(seatingOrder, rand);

    // 5. Chiffrement individuel et construction des PlayerModels
    final Map<String, PlayerModel> updatedPlayers = {};
    final Map<String, String> secretRoleTokens = {};
    final List<String> wolfUids = [];

    for (int i = 0; i < playerList.length; i++) {
      final oldPlayer = playerList[i];
      final uid = oldPlayer.id;
      final assignedRole = assignedRoles[uid] ?? GameRole.simpleVillager;
      final seatIndex = seatingOrder.indexOf(uid);

      if (assignedRole.isEvil) {
        wolfUids.add(uid);
      }

      final encryptedToken = RoleSecurityService.encryptRole(
        assignedRole.id,
        uid,
        roomCode,
      );
      secretRoleTokens[uid] = encryptedToken;

      final updatedPlayer = oldPlayer.copyWith(
        role: assignedRole,
        roleInitial: assignedRole,
        initialRole: assignedRole,
        estDechu: false,
        potionsVie: (assignedRole == GameRole.witch) ? maxPotions : 0,
        potionsMort: (assignedRole == GameRole.witch) ? maxPotions : 0,
        visionsRestantes: (assignedRole == GameRole.seer) ? maxVisions : 0,
        isAlive: true,
        isSpeaking: false,
        isMuted: false,
        clearTargetVote: true,
        isLover: false,
        loverId: null,
        isCaptain: false,
        isCharmed: false,
        isDoused: false,
        hasUsedHealPotion: false,
        hasUsedPoisonPotion: false,
        encryptedRole: encryptedToken,
        seatIndex: seatIndex,
        pv: 100,
        isReadyReplay: false,
        wantsRematch: false,
      );

      updatedPlayers[uid] = updatedPlayer;
    }

    // 6. Chiffrement du roster de la meute
    final encryptedWolfRoster = RoleSecurityService.encryptWolfRoster(
      wolfUids,
      roomCode,
    );

    // 7. Détermination de la première phase canonique
    final startingPhase = _resolveStartingPhase(updatedPlayers.values);

    return RoleDistributionResult(
      updatedPlayers: updatedPlayers,
      secretRoleTokens: secretRoleTokens,
      encryptedWolfRoster: encryptedWolfRoster,
      seatingOrder: seatingOrder,
      startingPhase: startingPhase,
      maxVisions: maxVisions,
      maxPotions: maxPotions,
    );
  }

  /// Algorithme glouton d'affectation anti-répétition minimisant les doublons consécutifs
  static Map<String, GameRole> _optimizeRoleAssignment({
    required List<String> playerUids,
    required List<GameRole> availableRoles,
    required Map<String, GameRole> previousRoles,
    required Random rand,
  }) {
    final Map<String, GameRole> assignments = {};
    final remainingRoles = List<GameRole>.from(availableRoles);

    // Première passe : attribuer un rôle différent du rôle précédent si possible
    for (final uid in playerUids) {
      final prev = previousRoles[uid];
      int candidateIndex = -1;

      if (prev != null) {
        // Chercher un rôle différent du rôle précédent
        for (int i = 0; i < remainingRoles.length; i++) {
          if (remainingRoles[i] != prev) {
            candidateIndex = i;
            break;
          }
        }
      }

      if (candidateIndex == -1 && remainingRoles.isNotEmpty) {
        candidateIndex = rand.nextInt(remainingRoles.length);
      }

      if (candidateIndex >= 0 && candidateIndex < remainingRoles.length) {
        assignments[uid] = remainingRoles.removeAt(candidateIndex);
      } else {
        assignments[uid] = GameRole.simpleVillager;
      }
    }

    return assignments;
  }

  /// Détermine la première phase nocturne active selon la composition
  static GamePhase _resolveStartingPhase(Iterable<PlayerModel> players) {
    bool hasRole(GameRole role) => players.any((p) => p.role == role);
    bool hasWolves() => players.any((p) => p.role.isEvil);

    if (hasRole(GameRole.thief)) return GamePhase.nightThief;
    if (hasRole(GameRole.cupid)) return GamePhase.nightCupid;
    if (hasRole(GameRole.defender)) return GamePhase.nightDefender;
    if (hasWolves()) return GamePhase.nightWerewolves;
    if (hasRole(GameRole.blackWolf)) return GamePhase.nightBlackWolf;
    if (hasRole(GameRole.seer)) return GamePhase.nightSeer;
    if (hasRole(GameRole.witch)) return GamePhase.nightWitch;
    if (hasRole(GameRole.pyromaniac)) return GamePhase.nightPyromaniac;
    return GamePhase.morningAnnouncement;
  }
}
