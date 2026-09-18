import 'dart:math';

import '../models/expanded_roles_state.dart';
import '../models/game_role.dart';
import '../models/player_model.dart';
import 'expanded_roles_coordinator.dart';

/// Stratégie et exécution des pouvoirs spécifiques de la Voyante
class SeerActionHandler {
  const SeerActionHandler();

  /// Quota de visions scalant selon le nombre total de joueurs
  int calculateInitialVisions(int totalPlayers) {
    if (totalPlayers <= 4) return 1;
    if (totalPlayers <= 9) return 2;
    if (totalPlayers <= 14) return 3;
    return totalPlayers ~/ 4;
  }

  /// Masquage canonique absolu : le Loup Blanc apparaît comme Simple Villageois
  GameRole getPerceivedRole(GameRole realRole) {
    if (realRole == GameRole.whiteWerewolf) {
      return GameRole.simpleVillager;
    }
    return realRole;
  }

  bool canInspect({required PlayerModel seer, bool isAdmin = false}) {
    if (isAdmin) return true;
    return seer.isAlive && seer.visionsRestantes > 0;
  }
}

/// Stratégie et exécution des pouvoirs spécifiques de la Sorcière
class WitchActionHandler {
  const WitchActionHandler();

  /// Quota de potions scalant selon le nombre total de joueurs : max(1, N ÷ 10)
  int calculateInitialPotions(int totalPlayers) {
    return max(1, totalPlayers ~/ 10);
  }

  bool canSave({
    required PlayerModel witch,
    required String? wolfVictimId,
    required bool alreadyHealedThisNight,
    bool isAdmin = false,
  }) {
    if (wolfVictimId == null || alreadyHealedThisNight) return false;
    if (isAdmin) return true;
    return witch.isAlive && witch.potionsVie > 0;
  }

  bool canPoison({
    required PlayerModel witch,
    required PlayerModel? target,
    required String? alreadyPoisonedThisNight,
    bool isAdmin = false,
  }) {
    if (target == null || !target.isAlive || alreadyPoisonedThisNight != null) {
      return false;
    }
    if (isAdmin) return true;
    return witch.isAlive && witch.potionsMort > 0;
  }
}

/// Stratégie de gestion de la mort des Amoureux (Cupidon)
class LoverActionHandler {
  const LoverActionHandler();

  /// Si le joueur décédé est en couple, retourne l'ID de son partenaire qui meurt de chagrin
  String? handleLoverDeath(
    String deadPlayerId,
    Map<String, PlayerModel> players,
    List<String> logs,
  ) {
    final dead = players[deadPlayerId];
    if (dead == null || !dead.isLover || dead.loverId == null) return null;

    final partnerId = dead.loverId!;
    final partner = players[partnerId];
    if (partner != null && partner.isAlive) {
      logs.add(
        '💔 Amour brisé : ${partner.name} ne peut survivre à la perte de son âme sœur ${dead.name} et meurt de chagrin !',
      );
      return partnerId;
    }
    return null;
  }
}

/// Dispatcher central des actions de rôles (Strategy Pattern)
class RoleActionDispatcher {
  final SeerActionHandler seer = const SeerActionHandler();
  final WitchActionHandler witch = const WitchActionHandler();
  final LoverActionHandler lover = const LoverActionHandler();

  const RoleActionDispatcher();

  /// Résout le flair du Renard
  FoxSniffResult resolveFoxSniff({
    required String targetPlayerId,
    required Map<String, PlayerModel> players,
    Map<String, GameRole>? realRoles,
    required List<String> seatingOrder,
  }) {
    return ExpandedRolesCoordinator.resolveFoxSniff(
      targetPlayerId: targetPlayerId,
      players: players,
      realRoles: realRoles,
      seatingOrder: seatingOrder,
    );
  }

  /// Résout le grognement du Montreur d'Ours
  bool resolveBearTamerGrowl({
    required Map<String, PlayerModel> players,
    Map<String, GameRole>? realRoles,
    required List<String> seatingOrder,
    required bool bearTamerInfected,
  }) {
    return ExpandedRolesCoordinator.resolveBearTamerGrowl(
      players: players,
      realRoles: realRoles,
      seatingOrder: seatingOrder,
      bearTamerInfected: bearTamerInfected,
    );
  }
}
