import '../models/player_model.dart';

/// Coordinateur et Arbitre pour les 17 Rôles Élargis de Lupus Arena
/// Contient l'ensemble des algorithmes purs d'arbitrage canonique
class ExpandedRolesCoordinator {
  /// 1. CONSTRUCTION DE LA SÉQUENCE NOCTURNE DYNAMIQUE
  static List<GameRole> computeNightSequence({
    required int currentTurn,
    required List<GameRole> activeRolesInGame,
    required bool hasDeadWolves,
    required bool wolfCubDiedYesterday,
  }) {
    final sequence = <GameRole>[];

    for (final role in GameRole.values) {
      if (!activeRolesInGame.contains(role)) continue;

      // Filtrage des rôles jouables uniquement la nuit 1
      if (role.actionType == ActionType.firstNightOnly && currentTurn > 1) {
        continue;
      }

      // Grand Méchant Loup ne joue plus si un loup est mort
      if (role == GameRole.bigBadWolf && hasDeadWolves) {
        continue;
      }

      if (role.nightPriority != null) {
        sequence.add(role);
      }
    }

    sequence.sort((a, b) => a.nightPriority!.compareTo(b.nightPriority!));
    return sequence;
  }

  /// 2. POUVOIR DU RENARD : Vérifie si un loup est dans le trio (cible + ses 2 voisins vivants)
  static bool resolveFoxSniff({
    required String targetPlayerId,
    required List<String> alivePlayerIdsInOrder,
    required Map<String, GameRole> playerRoles,
    required String? infectedPlayerId,
  }) {
    final targetIndex = alivePlayerIdsInOrder.indexOf(targetPlayerId);
    if (targetIndex == -1) return false;

    final n = alivePlayerIdsInOrder.length;
    final leftNeighborId = alivePlayerIdsInOrder[(targetIndex - 1 + n) % n];
    final rightNeighborId = alivePlayerIdsInOrder[(targetIndex + 1) % n];

    final trio = [targetPlayerId, leftNeighborId, rightNeighborId];

    return trio.any((id) {
      final role = playerRoles[id];
      final isWolf = role?.camp == Camp.wolves || id == infectedPlayerId;
      return isWolf;
    });
  }

  /// 3. MONTREUR D'OURS : Déclenché à l'aube
  static bool shouldBearGrowl({
    required String bearTamerPlayerId,
    required List<String> alivePlayerIdsInOrder,
    required Map<String, GameRole> playerRoles,
    required String? infectedPlayerId,
  }) {
    if (bearTamerPlayerId == infectedPlayerId) return true; // Infecté -> Grognement

    final index = alivePlayerIdsInOrder.indexOf(bearTamerPlayerId);
    if (index == -1) return false;

    final n = alivePlayerIdsInOrder.length;
    final leftId = alivePlayerIdsInOrder[(index - 1 + n) % n];
    final rightId = alivePlayerIdsInOrder[(index + 1) % n];

    for (final neighborId in [leftId, rightId]) {
      final role = playerRoles[neighborId];
      if (role?.camp == Camp.wolves || neighborId == infectedPlayerId) {
        return true;
      }
    }
    return false;
  }

  /// Alias de compatibilité pour le Montreur d'Ours
  static bool resolveBearTamerGrowl({
    required String bearTamerPlayerId,
    required List<String> alivePlayerIdsInOrder,
    required Map<String, GameRole> playerRoles,
    required String? infectedPlayerId,
  }) {
    return shouldBearGrowl(
      bearTamerPlayerId: bearTamerPlayerId,
      alivePlayerIdsInOrder: alivePlayerIdsInOrder,
      playerRoles: playerRoles,
      infectedPlayerId: infectedPlayerId,
    );
  }

  /// 4. DÉPOUILLEMENT DU VOTE DU JOUR : Intégration Corbeau & Bouc Émissaire
  static Map<String, int> applyCrowBonusVotes({
    required Map<String, int> baseVoteCounts,
    required String? crowTargetId,
  }) {
    final result = Map<String, int>.from(baseVoteCounts);
    if (crowTargetId != null) {
      result[crowTargetId] = (result[crowTargetId] ?? 0) + 2;
    }
    return result;
  }

  /// Arbitrage de l'égalité : si un Bouc Émissaire est vivant, il est sacrifié
  static String? resolveScapegoatTie({
    required List<PlayerModel> alivePlayers,
    Map<String, GameRole>? realRoles,
    required List<String> tiedCandidates,
  }) {
    if (tiedCandidates.length <= 1) return null;
    final scapegoat = alivePlayers.where((p) {
      final role = realRoles?[p.id] ?? p.role;
      return role == GameRole.scapegoat;
    }).firstOrNull;
    return scapegoat?.id;
  }

  static Map<String, dynamic> tallyDayVotes({
    required Map<String, String> playerVotes, // voterId -> targetId
    required String? crowTargetId,
    required String? scapegoatPlayerId,
    required List<String> alivePlayerIds,
  }) {
    final scores = <String, int>{};
    for (final id in alivePlayerIds) {
      scores[id] = 0;
    }

    // Report des votes standards
    playerVotes.forEach((_, target) {
      if (scores.containsKey(target)) {
        scores[target] = scores[target]! + 1;
      }
    });

    // Bonus de 2 voix du Corbeau
    if (crowTargetId != null && scores.containsKey(crowTargetId)) {
      scores[crowTargetId] = scores[crowTargetId]! + 2;
    }

    // Détermination de l'éliminé
    int highestScore = -1;
    final candidates = <String>[];

    scores.forEach((playerId, score) {
      if (score > highestScore) {
        highestScore = score;
        candidates
          ..clear()
          ..add(playerId);
      } else if (score == highestScore && score > 0) {
        candidates.add(playerId);
      }
    });

    if (candidates.length > 1) {
      // ÉGALITÉ : Si le Bouc Émissaire est en vie, c'est lui qui trépasse immédiatement
      if (scapegoatPlayerId != null && alivePlayerIds.contains(scapegoatPlayerId)) {
        return {
          'eliminatedPlayerId': scapegoatPlayerId,
          'reason': 'scapegoat_sacrifice',
          'scores': scores,
        };
      }
      return {
        'eliminatedPlayerId': null,
        'reason': 'tie_no_death',
        'scores': scores,
      };
    }

    return {
      'eliminatedPlayerId': candidates.isNotEmpty ? candidates.first : null,
      'reason': 'majority_vote',
      'scores': scores,
    };
  }

  /// 5. MORT DE L'ANCIEN : Déchéance des pouvoirs du village
  static bool checkElderDeathConsequences({
    required String killedPlayerId,
    required GameRole killedRole,
    required String eliminationSource, // 'vote', 'witch', 'hunter', 'wolves'
  }) {
    if (killedRole == GameRole.elder && eliminationSource != 'wolves') {
      // Tué par le village : tous les villageois perdent leurs pouvoirs
      return true;
    }
    return false;
  }

  /// 6. CHEVALIER À L'ÉPÉE ROUparameters : Contamination du premier loup à gauche
  static String? findWolfToContaminate({
    required String knightPlayerId,
    required List<String> alivePlayerIdsInOrder,
    required Map<String, GameRole> playerRoles,
    required String? infectedPlayerId,
  }) {
    final startIndex = alivePlayerIdsInOrder.indexOf(knightPlayerId);
    if (startIndex == -1) return null;

    final n = alivePlayerIdsInOrder.length;
    // Parcours circulaire vers la gauche (indices décroissants)
    for (int i = 1; i < n; i++) {
      final candidateId = alivePlayerIdsInOrder[(startIndex - i + n) % n];
      final role = playerRoles[candidateId];
      if (role?.camp == Camp.wolves || candidateId == infectedPlayerId) {
        return candidateId;
      }
    }
    return null;
  }

  /// 7. GESTION DE LA CONDITION DE VICTOIRE DE L'ABOMINABLE SECTAIRE
  static bool checkSectarianVictory({
    required String sectarianPlayerId,
    required List<String> alivePlayerIds,
    required Map<String, List<String>> sectarianTeams,
  }) {
    if (!alivePlayerIds.contains(sectarianPlayerId)) return false;

    final teamA = sectarianTeams['teamA'] ?? [];
    final teamB = sectarianTeams['teamB'] ?? [];

    final isSectarianInA = teamA.contains(sectarianPlayerId);
    final opposingTeam = isSectarianInA ? teamB : teamA;

    // Victoire si aucun membre de l'équipe adverse n'est en vie
    return opposingTeam.every((id) => !alivePlayerIds.contains(id));
  }

  /// Vérifie la victoire de la secte via les joueurs en vie
  static String? checkSectarianWin({
    required List<PlayerModel> alivePlayers,
    required List<String> sectarianTeamA,
    required List<String> sectarianTeamB,
  }) {
    final sectarian = alivePlayers.where((p) => p.role == GameRole.sectLeader).firstOrNull;
    if (sectarian == null) return null;
    final aliveIds = alivePlayers.map((p) => p.id).toSet();
    final isInA = sectarianTeamA.contains(sectarian.id);
    final opposingTeam = isInA ? sectarianTeamB : sectarianTeamA;
    if (opposingTeam.isNotEmpty && opposingTeam.every((id) => !aliveIds.contains(id))) {
      return 'abominableSectarian';
    }
    return null;
  }
}
