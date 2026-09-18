import '../models/expanded_roles_state.dart';
import '../models/game_phase.dart';
import '../models/player_model.dart';
import 'expanded_roles_coordinator.dart';
import 'mayor_coordinator.dart';

/// Résultat de la résolution des morts du matin
class MorningResolutionResult {
  final List<String> effectiveDeaths;
  final Map<String, dynamic> updates;
  final List<String> newLogs;
  final String? pendingHunterId;
  final String? pendingCaptainId;
  final bool cubDied;

  const MorningResolutionResult({
    required this.effectiveDeaths,
    required this.updates,
    required this.newLogs,
    this.pendingHunterId,
    this.pendingCaptainId,
    this.cubDied = false,
  });
}

/// Coordinateur d'arbitrage du cycle de vie et des phases de jeu (Automate d'états finis)
class GamePhaseCoordinator {
  final MayorCoordinator mayorCoordinator;

  const GamePhaseCoordinator({
    this.mayorCoordinator = const MayorCoordinator(),
  });

  /// Séquence canonique stricte des nuits :
  /// 1: Voleur (Nuit 1) -> 2: Cupidon (Nuit 1) -> 3: Salvateur -> 4: Loups-Garous ->
  /// 5: Loup Noir -> 6: Voyante -> 7: Sorcière -> 8: Joueur de Flûte -> 9: Pyromane -> 10: Aube
  GamePhase getNextNightPhase({
    required GamePhase current,
    required int round,
    required Map<String, PlayerModel> players,
    Map<String, GameRole>? realRoles,
  }) {
    GameRole getRole(PlayerModel p) => realRoles?[p.id] ?? p.role;

    bool hasAlive(GameRole role) =>
        players.values.any((p) => p.isAlive && getRole(p) == role);

    bool hasAliveWerewolves() =>
        players.values.any((p) => p.isAlive && getRole(p).isEvil);

    // RÈGLE CANONIQUE : Sorcière active si au moins 1 potion restante
    bool hasActiveWitch() {
      final witch = players.values.cast<PlayerModel?>().firstWhere(
            (p) =>
                p != null &&
                p.isAlive &&
                (getRole(p) == GameRole.witch ||
                    p.roleInitial == GameRole.witch),
            orElse: () => null,
          );
      if (witch == null) return false;
      final hasVie = witch.potionsVie > 0 && !witch.hasUsedHealPotion;
      final hasMort = witch.potionsMort > 0 && !witch.hasUsedPoisonPotion;
      return hasVie || hasMort;
    }

    // RÈGLE CANONIQUE : Voyante active si visions restantes > 0
    bool hasActiveSeer() {
      final seer = players.values.cast<PlayerModel?>().firstWhere(
            (p) =>
                p != null &&
                p.isAlive &&
                (getRole(p) == GameRole.seer ||
                    p.roleInitial == GameRole.seer),
            orElse: () => null,
          );
      return seer != null && seer.visionsRestantes > 0;
    }

    GamePhase findNext(int afterIndex) {
      if (afterIndex < 1 && round == 1 && hasAlive(GameRole.thief)) {
        return GamePhase.nightThief;
      }
      if (afterIndex < 2 && round == 1 && hasAlive(GameRole.cupid)) {
        return GamePhase.nightCupid;
      }
      if (afterIndex < 3 && hasAlive(GameRole.defender)) {
        return GamePhase.nightDefender;
      }
      if (afterIndex < 4 && hasAliveWerewolves()) {
        return GamePhase.nightWerewolves;
      }
      if (afterIndex < 6 && hasActiveSeer()) {
        return GamePhase.nightSeer;
      }
      if (afterIndex < 7 && hasActiveWitch()) {
        return GamePhase.nightWitch;
      }
      if (afterIndex < 8 && hasAlive(GameRole.piedPiper)) {
        return GamePhase.nightPiper;
      }
      if (afterIndex < 9 && hasAlive(GameRole.pyromaniac)) {
        return GamePhase.nightPyromaniac;
      }
      return GamePhase.morningAnnouncement;
    }

    final currentIndex = current.nightOrderIndex;
    return findNext(currentIndex);
  }

  /// Vérifie si une transition nocturne viole la règle de monotonie
  bool isNightRegression({
    required GamePhase current,
    required GamePhase next,
  }) {
    return current.isNight && next.isNight && next.nightOrderIndex <= current.nightOrderIndex;
  }

  /// Évalue les conditions de victoire pour tous les camps
  String? checkWinConditions({
    required Map<String, PlayerModel> players,
    required ExpandedRolesState expandedRolesState,
    Map<String, GameRole>? realRoles,
  }) {
    GameRole getRole(PlayerModel p) => realRoles?[p.id] ?? p.role;

    final alive = players.values.where((p) => p.isAlive).toList();
    if (alive.isEmpty) return 'draw';

    // 1. Victoire des Amoureux exclusifs
    final aliveLovers = alive.where((p) => p.isLover).toList();
    if (alive.length == 2 && aliveLovers.length == 2) {
      final r1 = getRole(aliveLovers[0]);
      final r2 = getRole(aliveLovers[1]);
      if (r1.isEvil != r2.isEvil) {
        return 'lovers';
      }
    }

    // 2. Victoire de la Secte / Sectaire
    final sectarianWin = ExpandedRolesCoordinator.checkSectarianWin(
      alivePlayers: alive,
      sectarianTeamA: expandedRolesState.sectarianTeamA,
      sectarianTeamB: expandedRolesState.sectarianTeamB,
    );
    if (sectarianWin != null) {
      return sectarianWin;
    }

    // 3. Victoire du Joueur de Flûte
    final piper = alive.firstWhere(
      (p) => getRole(p) == GameRole.piedPiper,
      orElse: () => PlayerModel(id: '', name: '', role: GameRole.simpleVillager),
    );
    if (piper.id.isNotEmpty) {
      final otherAlive = alive.where((p) => p.id != piper.id).toList();
      if (otherAlive.isNotEmpty && otherAlive.every((p) => p.isCharmed)) {
        return 'piedPiper';
      }
    }

    // 4. Victoire du Loup Blanc solitaire
    final whiteWolf = alive.firstWhere(
      (p) => getRole(p) == GameRole.whiteWerewolf,
      orElse: () => PlayerModel(id: '', name: '', role: GameRole.simpleVillager),
    );
    if (whiteWolf.id.isNotEmpty && alive.length == 1) {
      return 'whiteWolf';
    }

    // 5. Victoire du Pyromane solitaire
    final pyro = alive.firstWhere(
      (p) => getRole(p) == GameRole.pyromaniac,
      orElse: () => PlayerModel(id: '', name: '', role: GameRole.simpleVillager),
    );
    if (pyro.id.isNotEmpty && alive.length == 1) {
      return 'pyromaniac';
    }

    // 6. Victoire de l'Ange (si lynché au jour 1)
    if (expandedRolesState.angelWon) {
      return 'angel';
    }

    // 7. Camps standards : Village vs Loups
    final evilCount = alive.where((p) => getRole(p).isEvil).length;
    final innocentCount = alive.length - evilCount;

    if (evilCount == 0) return 'village';
    if (evilCount >= innocentCount) return 'werewolves';

    return null;
  }

  /// Ordonnancement automatique des phases diurnes (Maire, Débat, Vote, Résolution)
  GamePhase getNextDayPhase({
    required GamePhase current,
    required int round,
    required String? mayorId,
    required Map<String, PlayerModel> players,
    bool mayorOpeningDone = false,
    bool mayorClosingDone = false,
  }) {
    return mayorCoordinator.getNextDayPhase(
      current: current,
      round: round,
      mayorId: mayorId,
      players: players,
      mayorOpeningDone: mayorOpeningDone,
      mayorClosingDone: mayorClosingDone,
    );
  }

  /// Calcul du poids électoral d'un joueur (+2 pour le Maire / Capitaine, 1 si <= 3 survivants)
  int getVoteWeight({
    required String voterId,
    required String? mayorPlayerId,
    int livingCount = 0,
  }) {
    return mayorCoordinator.calculateVoteWeight(
      voterId: voterId,
      mayorPlayerId: mayorPlayerId,
      livingCount: livingCount,
    );
  }
}
