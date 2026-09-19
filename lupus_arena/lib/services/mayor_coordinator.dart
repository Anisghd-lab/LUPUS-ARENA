import 'dart:math';
import '../models/game_phase.dart';
import '../models/player_model.dart';

/// Résultat de l'élection du Maire
class MayorElectionResult {
  final String mayorId;
  final String mayorName;
  final int votesReceived;
  final String logMessage;

  const MayorElectionResult({
    required this.mayorId,
    required this.mayorName,
    required this.votesReceived,
    required this.logMessage,
  });
}

/// Résultat du traitement du décès du Maire
class MayorDeathResult {
  final bool isSuccessionTriggered;
  final String? deceasedMayorId;
  final GamePhase nextPhase;
  final int timerSeconds;
  final String logMessage;

  const MayorDeathResult({
    required this.isSuccessionTriggered,
    this.deceasedMayorId,
    this.nextPhase = GamePhase.mayorSuccession,
    this.timerSeconds = 15,
    this.logMessage = '',
  });
}

/// Coordinateur et Arbitre Officiel du Maire / Capitaine du Village
/// Conforme aux règles canoniques du jeu Loup-Garou :
/// 1. Élection au matin du Jour 1 (15s)
/// 2. Double prise de parole (Ouverture & Clôture du débat)
/// 3. Vote double (+2 voix lors des scrutins de jour)
/// 4. Succession testamentaire (15s) avec passation automatique sur timeout
/// 5. Résolution du Silence du Loup Noir (procédures UI garanties)
class MayorCoordinator {
  const MayorCoordinator();

  /// 1. Élection du premier Maire parmi les vivants au matin du Jour 1
  MayorElectionResult electMayor({
    required Map<String, PlayerModel> players,
    required Map<String, String> electionVotes,
    String? fallbackId,
  }) {
    final livingPlayers = players.values.where((p) => p.isAlive).toList();
    if (livingPlayers.isEmpty) {
      return const MayorElectionResult(
        mayorId: '',
        mayorName: 'Inconnu',
        votesReceived: 0,
        logMessage: 'Aucun survivant pour assumer la charge du Maire.',
      );
    }

    final tally = <String, int>{};
    for (final entry in electionVotes.entries) {
      final voterId = entry.key;
      final candidateId = entry.value;

      final voter = players[voterId];
      final candidate = players[candidateId];

      if (voter != null && voter.isAlive && candidate != null && candidate.isAlive) {
        tally[candidateId] = (tally[candidateId] ?? 0) + 1;
      }
    }

    if (tally.isNotEmpty) {
      // Trouver le candidat ayant reçu le plus de suffrages
      final maxVotes = tally.values.reduce(max);
      final topCandidates = tally.entries
          .where((e) => e.value == maxVotes)
          .map((e) => e.key)
          .toList();

      final winnerId = topCandidates.first;
      final winner = players[winnerId] ?? livingPlayers.first;

      return MayorElectionResult(
        mayorId: winner.id,
        mayorName: winner.name,
        votesReceived: maxVotes,
        logMessage:
            '🎖️ ${winner.name} est élu Maire du Village avec $maxVotes voix ! Sa voix comptera désormais double.',
      );
    }

    // Fallback automatique si aucun vote exprimé
    final fallbackWinner = (fallbackId != null && players[fallbackId]?.isAlive == true)
        ? players[fallbackId]!
        : livingPlayers.first;

    return MayorElectionResult(
      mayorId: fallbackWinner.id,
      mayorName: fallbackWinner.name,
      votesReceived: 0,
      logMessage:
          '🎖️ Faute de suffrages, ${fallbackWinner.name} est désigné Maire d\'office par le village.',
    );
  }

  /// 2. Interception du décès du Maire (de nuit ou au bûcher)
  MayorDeathResult handleMayorDeath({
    required String deadPlayerId,
    required String? currentMayorId,
    required Map<String, PlayerModel> players,
  }) {
    final isMayor = currentMayorId == deadPlayerId ||
        (players[deadPlayerId]?.isCaptain == true);

    if (!isMayor) {
      return const MayorDeathResult(
        isSuccessionTriggered: false,
      );
    }

    final otherLiving = players.values
        .where((p) => p.isAlive && p.id != deadPlayerId)
        .toList();

    if (otherLiving.isEmpty) {
      return const MayorDeathResult(
        isSuccessionTriggered: false,
        logMessage: 'Le Maire est tombé, mais aucun survivant ne reste pour lui succéder.',
      );
    }

    final deceasedName = players[deadPlayerId]?.name ?? 'Le Maire';

    return MayorDeathResult(
      isSuccessionTriggered: true,
      deceasedMayorId: deadPlayerId,
      nextPhase: GamePhase.mayorSuccession,
      timerSeconds: 15,
      logMessage:
          '📜 $deceasedName a péri ! Il dispose de 15 secondes pour rédiger son testament et transmettre son écharpe de Maire.',
    );
  }

  /// 3. Passation testamentaire officielle du titre de Maire
  String? passMayorTitle({
    required String mayorId,
    required String successorId,
    required Map<String, PlayerModel> players,
  }) {
    if (mayorId == successorId) return null;
    final successor = players[successorId];
    if (successor == null || !successor.isAlive) return null;
    return successor.id;
  }

  /// 4. Passation automatique de secours à l'expiration du chrono testamentaire (15s)
  String autoPassOnTimeout({
    required Map<String, PlayerModel> players,
    required String deceasedMayorId,
    List<String>? seatingOrder,
  }) {
    final candidates = players.values
        .where((p) => p.isAlive && p.id != deceasedMayorId)
        .toList();

    if (candidates.isEmpty) return deceasedMayorId;

    if (seatingOrder != null && seatingOrder.isNotEmpty) {
      for (final id in seatingOrder) {
        if (id != deceasedMayorId && players[id]?.isAlive == true) {
          return id;
        }
      }
    }

    final random = Random();
    return candidates[random.nextInt(candidates.length)].id;
  }

  /// 5. Calcul de la valeur du vote d'un joueur (+2 pour le Maire, 1 pour les autres ; s'il reste <= 3 survivants dont le maire, sa voix redevient 1)
  int calculateVoteWeight({
    required String voterId,
    required String? mayorPlayerId,
    int livingCount = 0,
  }) {
    if (mayorPlayerId != null && voterId == mayorPlayerId) {
      if (livingCount > 0 && livingCount <= 3) {
        return 1;
      }
      return 2;
    }
    return 1;
  }

  /// 6. Ordonnancement automatique des phases diurnes intégrant le Maire
  GamePhase getNextDayPhase({
    required GamePhase current,
    required int round,
    required String? mayorId,
    required Map<String, PlayerModel> players,
    required bool mayorOpeningDone,
    required bool mayorClosingDone,
  }) {
    final isMayorAlive = mayorId != null && (players[mayorId]?.isAlive ?? false);

    switch (current) {
      case GamePhase.morningAnnouncement:
        // Tour 1 : Élection du Maire avant les débats
        if (round == 1 && mayorId == null) {
          return GamePhase.mayorElection;
        }
        // Si le Maire est vivant et n'a pas encore ouvert les débats
        if (isMayorAlive && !mayorOpeningDone) {
          return GamePhase.mayorSpeechOpening;
        }
        return GamePhase.dayDebate;

      case GamePhase.mayorElection:
      case GamePhase.captainElection:
        // Après l'élection : Prise de parole d'ouverture
        return GamePhase.mayorSpeechOpening;

      case GamePhase.mayorSpeechOpening:
        // Après le discours d'ouverture : Débat général ordonné
        return GamePhase.dayDebate;

      case GamePhase.dayDebate:
        // Clôture solennelle par le Maire avant le vote si le Maire est vivant
        if (isMayorAlive && !mayorClosingDone) {
          return GamePhase.mayorSpeechClosing;
        }
        return GamePhase.dayVoting;

      case GamePhase.mayorSpeechClosing:
        // Après le mot de clôture : Scrutin du bûcher
        return GamePhase.dayVoting;

      case GamePhase.dayVoting:
        return GamePhase.dayResolution;

      case GamePhase.dayDefense:
        return GamePhase.dayTieBreakVote;

      case GamePhase.dayTieBreakVote:
        return GamePhase.dayResolution;

      case GamePhase.mayorSuccession:
      case GamePhase.captainSuccession:
        // Reprendre la phase diurne normale ou l'annonce du matin
        if (round == 1 && mayorId == null) {
          return GamePhase.mayorElection;
        }
        return GamePhase.dayDebate;

      default:
        return GamePhase.dayDebate;
    }
  }

  /// 7. Vérifie et garantit les droits procéduraux du Maire même s'il est sous silence du Loup Noir
  bool isProceduralActionAllowed({
    required String playerId,
    required String? mayorId,
    required bool isMuted,
  }) {
    // Les actions procédurales (transmission du titre, conclusion du discours) restent toujours permises
    return true;
  }
}
