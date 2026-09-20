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

  /// 5. Règle de visibilité du flairage du Renard (Fox Sniff)
  /// Le résultat du flairage (joueurs inspectés et présence de loup) ne doit être
  /// visible QUE par le Renard lui-même (vivant) ou en Mode Développeur / Admin.
  static bool canSeeFoxSniff({
    required GameRole observerRole,
    bool isDevMode = false,
  }) {
    if (isDevMode) return true;
    if (observerRole == GameRole.fox) return true;
    return false;
  }

  /// 6. Règle de visibilité du bouclier du Salvateur (Defender Shield)
  /// La cible protégée ne doit être visible que par le Salvateur lui-même (ou DevMode)
  /// afin que les Loups-Garous ne puissent pas savoir qui est invulnérable cette nuit.
  static bool canSeeDefenderShield({
    required bool targetIsProtected,
    required GameRole observerRole,
    bool isDevMode = false,
  }) {
    if (!targetIsProtected) return false;
    if (isDevMode) return true;
    if (observerRole == GameRole.defender) return true;
    return false;
  }

  /// 7. Règle de visibilité de la victime des Loups pour la Sorcière
  /// Lors de la phase de la Sorcière, la victime désignée des loups est visible
  /// par la Sorcière afin qu'elle puisse décider d'utiliser sa potion de vie.
  static bool canSeeWitchWolfVictim({
    required bool targetIsVictim,
    required GameRole observerRole,
    required bool isNightWitch,
    bool isDevMode = false,
  }) {
    if (!targetIsVictim) return false;
    if (isDevMode) return true;
    if (observerRole == GameRole.witch && isNightWitch) return true;
    return false;
  }

  /// 8. Règle de visibilité de la potion de vie de la Sorcière (Witch Healed)
  /// Le joueur sauvé par la potion de vie ne doit être visible que par la Sorcière
  /// (ou DevMode) pendant la nuit.
  static bool canSeeWitchHealed({
    required bool targetIsHealed,
    required GameRole observerRole,
    bool isDevMode = false,
  }) {
    if (!targetIsHealed) return false;
    if (isDevMode) return true;
    if (observerRole == GameRole.witch) return true;
    return false;
  }

  /// 9. Règle de visibilité de la potion de mort de la Sorcière (Witch Poisoned)
  /// Le joueur empoisonné ne doit être visible que par la Sorcière (ou DevMode)
  /// pendant la nuit avant l'annonce du matin.
  static bool canSeeWitchPoisoned({
    required bool targetIsPoisoned,
    required GameRole observerRole,
    bool isDevMode = false,
  }) {
    if (!targetIsPoisoned) return false;
    if (isDevMode) return true;
    if (observerRole == GameRole.witch) return true;
    return false;
  }

  /// 10. Règle de visibilité du modèle de l'Enfant Sauvage (Wild Child Model)
  /// Le modèle choisi la première nuit n'est visible QUE par l'Enfant Sauvage
  /// (ou DevMode), restant totalement anonyme pour le modèle et le reste du village.
  static bool canSeeWildChildModel({
    required bool targetIsModel,
    required GameRole observerRole,
    bool isDevMode = false,
  }) {
    if (!targetIsModel) return false;
    if (isDevMode) return true;
    if (observerRole == GameRole.wildChild) return true;
    return false;
  }

  /// 11. Règle de visibilité du grognement du Montreur d'Ours (Bear Tamer Growl)
  /// Au lever du jour, le grognement est une information publique partagée
  /// avec tout le village réuni.
  static bool canSeeBearGrowl({
    required bool targetIsBearTamer,
    required bool bearGrowledThisMorning,
    required bool isDayTime,
    bool isDevMode = false,
  }) {
    if (!targetIsBearTamer) return false;
    if (!bearGrowledThisMorning) return false;
    if (isDevMode) return true;
    return isDayTime;
  }

  /// 12. Règle de visibilité de la contamination de l'Épée Rouillée (Rusty Knight Contamination)
  /// Le loup infecté par l'épée rouillée est au courant de sa condamnation,
  /// ainsi que la meute de loups qui a vu la blessure (ou DevMode).
  static bool canSeeRustyKnightContamination({
    required bool targetIsContaminated,
    required bool isObserverWolf,
    required bool isObserverContaminated,
    bool isDevMode = false,
  }) {
    if (!targetIsContaminated) return false;
    if (isDevMode) return true;
    if (isObserverContaminated) return true;
    if (isObserverWolf) return true;
    return false;
  }

  /// 13. Règle de visibilité de l'inspection de la Voyante (Seer Inspected Role)
  /// Le rôle découvert par la Voyante et l'icône de la boule de cristal (🔮)
  /// ne doivent être visibles QUE par la Voyante elle-même ou en Mode Développeur / Admin.
  static bool canSeeSeerInspection({
    required GameRole observerRole,
    bool isDevMode = false,
  }) {
    if (isDevMode) return true;
    if (observerRole == GameRole.seer) return true;
    return false;
  }
}

