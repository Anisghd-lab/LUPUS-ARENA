import '../models/game_role.dart';

/// Service centralisant les règles canoniques de visibilité des badges et statuts cachés (Fog of War).
class FogOfWarService {
  const FogOfWarService();

  /// 1. Règle de visibilité du badge Amoureux (IN_LOVE)
  /// Le badge Amoureux ne doit être visible sur la fiche d'un joueur A que si :
  /// - O est Cupidon (vivant ou mort, il connaît ses créations).
  /// - O est l'un des deux Amoureux (donc O voit son propre badge et celui de son partenaire).
  /// - Mode Développeur / Admin actif.
  static bool canSeeLoverBadge({
    required bool targetIsLover,
    required GameRole observerRole,
    required bool observerIsLover,
    bool isDevMode = false,
  }) {
    if (!targetIsLover) return false;
    if (isDevMode) return true;
    if (observerRole == GameRole.cupid) return true;
    if (observerIsLover) return true;
    return false;
  }

  /// 2. Règle de visibilité du badge Charmé (CHARMED)
  /// Le badge Charmé (envoûté par le Joueur de Flûte) ne doit être visible sur un joueur C que si :
  /// - O est le Joueur de Flûte (il doit suivre l'avancée de son charme vers la victoire).
  /// - O est lui-même Charmé (tous les charmés se reconnaissent et savent qui est sous hypnose).
  /// - Mode Développeur / Admin actif.
  static bool canSeeCharmedBadge({
    required bool targetIsCharmed,
    required GameRole observerRole,
    required bool observerIsCharmed,
    bool isDevMode = false,
  }) {
    if (!targetIsCharmed) return false;
    if (isDevMode) return true;
    if (observerRole == GameRole.piedPiper) return true;
    if (observerIsCharmed) return true;
    return false;
  }

  /// 3. Règle de visibilité de l'Infection (Infect Père des Loups)
  /// Visible par la cible elle-même ET par tous les Loups-Garous (ou DevMode).
  static bool canSeeInfectedBadge({
    required bool targetIsInfected,
    required bool isTargetMe,
    required bool observerIsEvil,
    bool isDevMode = false,
  }) {
    if (!targetIsInfected) return false;
    if (isDevMode) return true;
    if (isTargetMe) return true;
    if (observerIsEvil) return true;
    return false;
  }

  /// 4. Règle de visibilité de la Cible du Corbeau
  /// Invisible par le village la nuit (seul le Corbeau la connaît) ; devient publique au matin.
  static bool canSeeCrowTarget({
    required bool targetIsCrowTarget,
    required bool isDayTime,
    required GameRole observerRole,
    bool isDevMode = false,
  }) {
    if (!targetIsCrowTarget) return false;
    if (isDevMode) return true;
    if (isDayTime) return true;
    if (observerRole == GameRole.raven) return true;
    return false;
  }
}
