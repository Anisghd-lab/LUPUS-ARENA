/// Rôles supportés par Lupus Arena
enum RoleType {
  villager,
  werewolf,
  stealer,          // Voleur
  cupid,            // Cupidon
  actor,            // Comédien
  seer,             // Voyante
  fox,              // Renard
  crow,             // Corbeau
  pyromaniac,       // Pyromane
  bodyguard,        // Salvateur
  fatherOfWolves,   // Infect Père des Loups
  bigBadWolf,       // Grand Méchant Loup
  whiteWolf,        // Loup Blanc
  witch,            // Sorcière
  dedicatedMaid,    // Servante Dévouée
  stutteringJudge,  // Juge Bègue
  hunter,           // Chasseur
}

/// Camps d'allégeance
enum Faction {
  village,
  werewolves,
  whiteWolf,
  lovers,
}

/// Macro-États du jeu
enum GamePhase {
  initialization,
  preliminaryNight,
  night,
  dayAnnounceDeaths,
  dayDiscussion,
  dayVoting,
  dayExecution,
  checkWinConditions,
  gameOver,
}

/// Étapes de rôle (file d'attente dynamique)
enum GameStep {
  // Nuit Préliminaire (Nuit 0)
  preStealer,
  preCupid,
  // Nuit Régulière
  roleActor,
  roleSeer,
  roleFox,
  roleCrow,
  rolePyromaniac,
  roleBodyguard,
  roleWerewolves,
  roleBigBadWolf,
  roleWhiteWolf,
  roleWitch,
  // Hooks de transition
  hookDedicatedMaid,
}

/// Types d'attaques / éliminations pour le buffer
enum KillSource {
  werewolves,
  bigBadWolf,
  whiteWolf,
  witchPoison,
  pyromaniacFire,
  brokenHeart,
  villageExecution,
}

/// Représentation d'une tentative d'élimination
class KillIntent {
  final String targetPlayerId;
  final KillSource source;

  const KillIntent({required this.targetPlayerId, required this.source});
}

/// Buffer des actions de nuit non résolues
class NightActionBuffer {
  final List<KillIntent> killIntents = [];
  String? protectedPlayerId; // Protection du Salvateur
  String? healedPlayerId;    // Soin de la Sorcière
  bool isInfected = false;   // Infection du Père des Loups

  void clear() {
    killIntents.clear();
    protectedPlayerId = null;
    healedPlayerId = null;
    isInfected = false;
  }
}

/// Modèle du Joueur
class Player {
  final String id;
  final String name;
  RoleType role;
  Faction faction;
  bool isAlive;
  bool isCaptain;
  bool isDousedWithGas; // Marqué par le Pyromane
  Set<String> loversIds;

  Player({
    required this.id,
    required this.name,
    required this.role,
    this.faction = Faction.village,
    this.isAlive = true,
    this.isCaptain = false,
    this.isDousedWithGas = false,
    Set<String>? loversIds,
  }) : loversIds = loversIds ?? {};

  Player copyWith({
    String? id,
    String? name,
    RoleType? role,
    Faction? faction,
    bool? isAlive,
    bool? isCaptain,
    bool? isDousedWithGas,
    Set<String>? loversIds,
  }) {
    return Player(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      faction: faction ?? this.faction,
      isAlive: isAlive ?? this.isAlive,
      isCaptain: isCaptain ?? this.isCaptain,
      isDousedWithGas: isDousedWithGas ?? this.isDousedWithGas,
      loversIds: loversIds ?? Set.from(this.loversIds),
    );
  }
}
