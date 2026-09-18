import 'dart:math';

import '../models/expanded_roles_state.dart';
import '../models/game_role.dart';
import '../models/player_model.dart';
import 'expanded_roles_coordinator.dart';

/// Résultat du dépouillement des votes du jour
class VoteTallyResult {
  final Map<String, int> voteCounts;
  final List<String> topCandidates;
  final int maxVotes;
  final String? condemnedPlayerId;
  final bool isTie;
  final bool isScapegoatTriggered;
  final String? scapegoatId;

  const VoteTallyResult({
    required this.voteCounts,
    required this.topCandidates,
    required this.maxVotes,
    this.condemnedPlayerId,
    this.isTie = false,
    this.isScapegoatTriggered = false,
    this.scapegoatId,
  });
}

/// Coordinateur d'arbitrage et de dépouillement des votes (VoteCoordinator)
class VoteCoordinator {
  const VoteCoordinator();

  /// Compte les votes de la meute des loups pour la nuit
  String? tallyWerewolfVotes({
    required List<PlayerModel> alivePlayers,
    String? currentUserId,
    bool isAdmin = false,
  }) {
    final votes = <String, int>{};
    for (final p in alivePlayers) {
      if ((p.role.isEvil || (p.id == currentUserId && isAdmin)) &&
          p.targetVoteId != null) {
        votes[p.targetVoteId!] = (votes[p.targetVoteId!] ?? 0) + 1;
      }
    }
    if (votes.isEmpty) return null;
    return votes.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  /// Dépouille l'ensemble des votes du village pour la phase de vote de jour
  VoteTallyResult tallyDayVotes({
    required Map<String, PlayerModel> players,
    required ExpandedRolesState expandedRolesState,
    String? captainId,
    Map<String, GameRole>? realRoles,
  }) {
    GameRole getRole(PlayerModel p) => realRoles?[p.id] ?? p.role;

    final voteCounts = <String, int>{};

    for (final voter in players.values.where((p) => p.isAlive)) {
      // Ignorer les votants bannis par le Bouc Émissaire
      if (expandedRolesState.bannedVotersForToday.contains(voter.id)) {
        continue;
      }

      final target = voter.targetVoteId;
      if (target != null && players[target]?.isAlive == true) {
        // Le Capitaine a un vote double (poids 2)
        final weight = voter.isCaptain || voter.id == captainId ? 2 : 1;
        voteCounts[target] = (voteCounts[target] ?? 0) + weight;
      }
    }

    // Application des votes de menace du Corbeau (+2 votes sur la cible)
    final countsWithCrow = ExpandedRolesCoordinator.applyCrowBonusVotes(
      baseVoteCounts: voteCounts,
      crowTargetId: expandedRolesState.crowTargetId,
    );

    if (countsWithCrow.isEmpty) {
      return const VoteTallyResult(
        voteCounts: {},
        topCandidates: [],
        maxVotes: 0,
      );
    }

    final maxVotes = countsWithCrow.values.reduce(max);
    final topCandidates = countsWithCrow.entries
        .where((e) => e.value == maxVotes)
        .map((e) => e.key)
        .toList();

    // Cas d'égalité
    if (topCandidates.length > 1) {
      // Arbitrage canonique : Bouc Émissaire exécuté en cas d'égalité
      final scapegoatResolution = ExpandedRolesCoordinator.resolveScapegoatTie(
        alivePlayers: players.values.where((p) => p.isAlive).toList(),
        realRoles: realRoles,
        tiedCandidates: topCandidates,
      );

      if (scapegoatResolution != null) {
        return VoteTallyResult(
          voteCounts: countsWithCrow,
          topCandidates: topCandidates,
          maxVotes: maxVotes,
          condemnedPlayerId: scapegoatResolution,
          isTie: true,
          isScapegoatTriggered: true,
          scapegoatId: scapegoatResolution,
        );
      }

      // Égalité standard sans Bouc Émissaire : vote prépondérant du Capitaine
      final captain = players.values.cast<PlayerModel?>().firstWhere(
            (p) => p != null && p.isAlive && (p.isCaptain || p.id == captainId),
            orElse: () => null,
          );

      if (captain != null &&
          captain.targetVoteId != null &&
          topCandidates.contains(captain.targetVoteId)) {
        return VoteTallyResult(
          voteCounts: countsWithCrow,
          topCandidates: topCandidates,
          maxVotes: maxVotes,
          condemnedPlayerId: captain.targetVoteId,
          isTie: false,
        );
      }

      return VoteTallyResult(
        voteCounts: countsWithCrow,
        topCandidates: topCandidates,
        maxVotes: maxVotes,
        isTie: true,
      );
    }

    return VoteTallyResult(
      voteCounts: countsWithCrow,
      topCandidates: topCandidates,
      maxVotes: maxVotes,
      condemnedPlayerId: topCandidates.first,
    );
  }
}
