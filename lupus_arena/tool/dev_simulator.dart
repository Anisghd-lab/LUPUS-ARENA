// Moteur de simulation Dev Mode intégrant 30 rôles complets (extensions Loups-Garous)

enum Camp { village, werewolves, solo, neutral }

enum Role {
  // --- Le Village (Innocents & Spéciaux) ---
  villager,          // Simple Villageois
  seer,              // Voyante
  witch,             // Sorcière
  hunter,            // Chasseur
  cupid,             // Cupidon
  littleGirl,        // Petite Fille
  guard,             // Salvateur / Garde
  elder,             // Ancien
  idiot,             // Idiot du Village
  fox,               // Renard
  bearTamer,         // Montreur d'Ours
  knightWithRustySword, // Chevalier à l'Épée Rouillée
  servant,           // Servante Dévouée
  twoSisters,        // Deux Sœurs
  threeBrothers,     // Trois Frères
  stutteringJudge,   // Juge Bègue
  raven,             // Corbeau
  pyromaniac,        // Pyromane (version villageoise/artificier)

  // --- Les Loups-Garous & Alliés ---
  werewolf,          // Loup-Garou classique
  bigBadWolf,        // Grand Méchant Loup
  whiteWerewolf,     // Loup-Garou Blanc
  wolfHound,         // Chien-Loup
  wildChild,         // Enfant Sauvage
  infectedFatherOfWolves, // Infect Père des Loups

  // --- Rôles Solitaires & Neutres ---
  piper,             // Joueur de Flûte
  angel,             // Ange
  thief,             // Voleur
  actor,             // Comédien
  abominableSectarian, // Abominable Sectaire
  charlatan,         // Charlatan
}

class Player {
  final String id;
  final String name;
  Role role;
  Camp camp;
  bool isAlive;
  bool isProtected;
  bool isCharmed;
  bool isInfected;
  int lives;
  String? inLoveWithId;

  Player({
    required this.id,
    required this.name,
    required this.role,
    required this.camp,
    this.isAlive = true,
    this.isProtected = false,
    this.isCharmed = false,
    this.isInfected = false,
    this.lives = 1,
    this.inLoveWithId,
  });

  @override
  String toString() =>
      '[$id] $name | ${role.name.padRight(22)} | Camp: ${camp.name.padRight(10)} | '
      'Vivant: $isAlive | Charmé: $isCharmed | Protégé: $isProtected';
}

class FullGameSimulator {
  final Map<String, Player> players = {};
  int currentNight = 1;

  // Mémoires d'actions de nuit
  String? werewolfVictimId;
  String? whiteWolfVictimId;
  String? bigBadWolfVictimId;
  String? witchHealedId;
  String? witchKilledId;
  String? guardProtectedId;
  String? ravenAccusedId;
  final Set<String> charmedTonight = {};
  bool witchHasHeal = true;
  bool witchHasDeath = true;
  bool infectionAvailable = true;

  FullGameSimulator(List<Player> playerList) {
    for (var p in playerList) {
      players[p.id] = p;
    }
  }

  Player _p(String id) => players[id] ?? (throw Exception('ID invalide: $id'));

  // ===================== CONTRÔLES DEV =====================

  void devSetRole(String id, Role newRole, Camp newCamp) {
    final p = _p(id);
    p.role = newRole;
    p.camp = newCamp;
    // ignore: avoid_print
    print('[DEV] Rôle forcé: ${p.name} -> ${newRole.name} (${newCamp.name})');
  }

  void devKill(String id, {required String reason}) {
    final p = _p(id);
    if (!p.isAlive) return;

    // Gestion des vies (ex: Ancien)
    if (p.lives > 1 && reason == 'attaque des loups') {
      p.lives--;
      // ignore: avoid_print
      print('[DEV RESISTANCE] ${p.name} survit à l\'assaut (Vies restantes: ${p.lives}).');
      return;
    }

    p.isAlive = false;
    // ignore: avoid_print
    print('[DEV MORT] ${p.name} (${p.role.name}) est éliminé -> Raison: $reason');

    // Réaction Amoureux
    if (p.inLoveWithId != null) {
      final lover = _p(p.inLoveWithId!);
      if (lover.isAlive) {
        // ignore: avoid_print
        print('[AMOUR] ${lover.name} succombe au chagrin.');
        devKill(lover.id, reason: 'chagrin d\'amour');
      }
    }

    // Réaction Chasseur
    if (p.role == Role.hunter) {
      // ignore: avoid_print
      print('[POUVOIR] Le Chasseur ${p.name} doit tirer avant de sombrer.');
    }

    // Réaction Chevalier à l'Épée Rouillée
    if (p.role == Role.knightWithRustySword && reason.contains('loup')) {
      // ignore: avoid_print
      print('[POUVOIR] Le Chevalier empoisonne un loup avec sa rouille pour la nuit suivante.');
    }
  }

  // ===================== ACTIONS DE NUIT (POUVOIRS) =====================

  // 1. Voleur
  void powerThief(String thiefId, Role chosenRole, Camp chosenCamp) {
    final p = _p(thiefId);
    if (p.role != Role.thief || !p.isAlive) return;
    p.role = chosenRole;
    p.camp = chosenCamp;
    // ignore: avoid_print
    print('[NUIT 0 - VOLEUR] ${p.name} vole le rôle : ${chosenRole.name}');
  }

  // 2. Cupidon
  void powerCupid(String cupidId, String id1, String id2) {
    final c = _p(cupidId);
    if (c.role != Role.cupid || !c.isAlive) return;
    final p1 = _p(id1);
    final p2 = _p(id2);
    p1.inLoveWithId = p2.id;
    p2.inLoveWithId = p1.id;
    // ignore: avoid_print
    print('[NUIT - CUPIDON] ${p1.name} et ${p2.name} sont liés.');
  }

  // 3. Salvateur / Garde
  void powerGuard(String guardId, String targetId) {
    final g = _p(guardId);
    if (g.role != Role.guard || !g.isAlive) return;
    guardProtectedId = targetId;
    _p(targetId).isProtected = true;
    // ignore: avoid_print
    print('[NUIT - SALVATEUR] ${g.name} déploie son bouclier sur ${_p(targetId).name}.');
  }

  // 4. Voyante
  void powerSeer(String seerId, String targetId) {
    final s = _p(seerId);
    if (s.role != Role.seer || !s.isAlive) return;
    final target = _p(targetId);
    // ignore: avoid_print
    print('[NUIT - VOYANTE] ${s.name} découvre que ${target.name} est [${target.role.name}].');
  }

  // 5. Renard
  void powerFox(String foxId, String idA, String idB, String idC) {
    final f = _p(foxId);
    if (f.role != Role.fox || !f.isAlive) return;
    final group = [idA, idB, idC].map((id) => _p(id));
    final hasWolf = group.any((p) => p.camp == Camp.werewolves);
    // ignore: avoid_print
    print('[NUIT - RENARD] ${f.name} flaire le trio : ${hasWolf ? "Loup détecté !" : "Aucun loup, pouvoir perdu."}');
  }

  // 6. Loups-Garous (Attaque commune)
  void powerWerewolvesVote(String victimId) {
    werewolfVictimId = victimId;
    // ignore: avoid_print
    print('[NUIT - MEUTE] Cible désignée par la meute : ${_p(victimId).name}');
  }

  // 7. Grand Méchant Loup (Double attaque si aucun loup mort)
  void powerBigBadWolf(String wolfId, String victimId) {
    final b = _p(wolfId);
    if (b.role != Role.bigBadWolf || !b.isAlive) return;
    bigBadWolfVictimId = victimId;
    // ignore: avoid_print
    print('[NUIT - GRAND MÉCHANT LOUP] Deuxième victime ciblée : ${_p(victimId).name}');
  }

  // 8. Infect Père des Loups
  void powerInfectFather(String fatherId) {
    final f = _p(fatherId);
    if (f.role != Role.infectedFatherOfWolves || !f.isAlive || !infectionAvailable) return;
    if (werewolfVictimId != null) {
      final victim = _p(werewolfVictimId!);
      victim.isInfected = true;
      victim.camp = Camp.werewolves;
      infectionAvailable = false;
      werewolfVictimId = null; // Sauvé de la morsure mortelle
      // ignore: avoid_print
      print('[NUIT - INFECTION] Le Père des Loups infecte ${victim.name} qui rejoint la meute.');
    }
  }

  // 9. Loup-Garou Blanc (Tue un loup tous les deux tours)
  void powerWhiteWolf(String whiteWolfId, String wolfTargetId) {
    final w = _p(whiteWolfId);
    if (w.role != Role.whiteWerewolf || !w.isAlive) return;
    final target = _p(wolfTargetId);
    if (target.camp == Camp.werewolves) {
      whiteWolfVictimId = target.id;
      // ignore: avoid_print
      print('[NUIT - LOUP BLANC] Trahison : ${w.name} vise ${target.name}');
    }
  }

  // 10. Sorcière
  void powerWitch({
    required String witchId,
    bool heal = false,
    String? poisonTargetId,
  }) {
    final w = _p(witchId);
    if (w.role != Role.witch || !w.isAlive) return;

    if (heal && witchHasHeal && werewolfVictimId != null) {
      witchHealedId = werewolfVictimId;
      witchHasHeal = false;
      // ignore: avoid_print
      print('[NUIT - SORCIÈRE] Potion de vie utilisée sur ${_p(werewolfVictimId!).name}.');
    }
    if (poisonTargetId != null && witchHasDeath) {
      witchKilledId = poisonTargetId;
      witchHasDeath = false;
      // ignore: avoid_print
      print('[NUIT - SORCIÈRE] Potion de mort versée sur ${_p(poisonTargetId).name}.');
    }
  }

  // 11. Joueur de Flûte
  void powerPiper(String piperId, List<String> targetIds) {
    final p = _p(piperId);
    if (p.role != Role.piper || !p.isAlive) return;
    for (var id in targetIds) {
      charmedTonight.add(id);
      _p(id).isCharmed = true;
    }
    // ignore: avoid_print
    print('[NUIT - FLÛTE] Joueurs enchantés cette nuit: ${targetIds.map((id) => _p(id).name).join(", ")}');
  }

  // 12. Corbeau
  void powerRaven(String ravenId, String targetId) {
    final r = _p(ravenId);
    if (r.role != Role.raven || !r.isAlive) return;
    ravenAccusedId = targetId;
    // ignore: avoid_print
    print('[NUIT - CORBEAU] Affiche anonyme clouée contre ${_p(targetId).name} (+2 votes demain).');
  }

  // 13. Tir du Chasseur (Hors cycle direct de nuit)
  void triggerHunterShot(String hunterId, String targetId) {
    final h = _p(hunterId);
    // ignore: avoid_print
    print('[CHASSEUR] ${h.name} fait feu sur ${_p(targetId).name} !');
    devKill(targetId, reason: 'tir de riposte du chasseur');
  }

  // ===================== RÉSOLUTION DE L'AUBE =====================

  void resolveNight() {
    // ignore: avoid_print
    print('\n==================== AUBE (FIN NUIT $currentNight) ====================');

    // Résolution attaque meute
    if (werewolfVictimId != null) {
      final victim = _p(werewolfVictimId!);
      if (victim.id == witchHealedId || victim.isProtected) {
        // ignore: avoid_print
        print('[RÉSOLU] L\'attaque de la meute a été contrée (soin/bouclier).');
      } else {
        devKill(victim.id, reason: 'attaque des loups');
      }
    }

    // Attaque du Grand Méchant Loup
    if (bigBadWolfVictimId != null) {
      final victim = _p(bigBadWolfVictimId!);
      if (!victim.isProtected) {
        devKill(victim.id, reason: 'attaque du Grand Méchant Loup');
      }
    }

    // Attaque Loup Blanc
    if (whiteWolfVictimId != null) {
      devKill(whiteWolfVictimId!, reason: 'carnage du Loup Blanc');
    }

    // Poison Sorcière
    if (witchKilledId != null) {
      devKill(witchKilledId!, reason: 'poison de la sorcière');
    }

    // Réinitialisation des états temporaires
    if (guardProtectedId != null) {
      _p(guardProtectedId!).isProtected = false;
      guardProtectedId = null;
    }
    werewolfVictimId = null;
    whiteWolfVictimId = null;
    bigBadWolfVictimId = null;
    witchHealedId = null;
    witchKilledId = null;
    charmedTonight.clear();
    currentNight++;
    // ignore: avoid_print
    print('===============================================================\n');
  }

  void printStatus() {
    // ignore: avoid_print
    print('\n--- STATUT GLOBAL DU PLATEAU (30 JOUEURS) ---');
    // ignore: avoid_print
    players.values.forEach(print);
    // ignore: avoid_print
    print('--------------------------------------------\n');
  }
}

void main() {
  // Définition directe des 30 rôles attribués à 30 joueurs uniques
  final initial30Players = [
    // --- 18 Joueurs Village & Spéciaux ---
    Player(id: '01', name: 'Alice', role: Role.villager, camp: Camp.village),
    Player(id: '02', name: 'Bob', role: Role.seer, camp: Camp.village),
    Player(id: '03', name: 'Charlie', role: Role.witch, camp: Camp.village),
    Player(id: '04', name: 'David', role: Role.hunter, camp: Camp.village),
    Player(id: '05', name: 'Emma', role: Role.cupid, camp: Camp.village),
    Player(id: '06', name: 'Fiona', role: Role.littleGirl, camp: Camp.village),
    Player(id: '07', name: 'Gabriel', role: Role.guard, camp: Camp.village),
    Player(id: '08', name: 'Helena', role: Role.elder, camp: Camp.village, lives: 2),
    Player(id: '09', name: 'Isaac', role: Role.idiot, camp: Camp.village),
    Player(id: '10', name: 'Julia', role: Role.fox, camp: Camp.village),
    Player(id: '11', name: 'Kevin', role: Role.bearTamer, camp: Camp.village),
    Player(id: '12', name: 'Liam', role: Role.knightWithRustySword, camp: Camp.village),
    Player(id: '13', name: 'Mia', role: Role.servant, camp: Camp.village),
    Player(id: '14', name: 'Nora', role: Role.twoSisters, camp: Camp.village),
    Player(id: '15', name: 'Oscar', role: Role.threeBrothers, camp: Camp.village),
    Player(id: '16', name: 'Paul', role: Role.stutteringJudge, camp: Camp.village),
    Player(id: '17', name: 'Quentin', role: Role.raven, camp: Camp.village),
    Player(id: '18', name: 'Rose', role: Role.pyromaniac, camp: Camp.village),

    // --- 6 Joueurs Loups-Garous ---
    Player(id: '19', name: 'Sam', role: Role.werewolf, camp: Camp.werewolves),
    Player(id: '20', name: 'Tom', role: Role.werewolf, camp: Camp.werewolves),
    Player(id: '21', name: 'Ulysse', role: Role.bigBadWolf, camp: Camp.werewolves),
    Player(id: '22', name: 'Victor', role: Role.whiteWerewolf, camp: Camp.werewolves),
    Player(id: '23', name: 'Wendy', role: Role.wolfHound, camp: Camp.village), // Choisira son camp
    Player(id: '24', name: 'Xavier', role: Role.infectedFatherOfWolves, camp: Camp.werewolves),

    // --- 6 Joueurs Neutres / Ambigus / Solo ---
    Player(id: '25', name: 'Yann', role: Role.wildChild, camp: Camp.village),
    Player(id: '26', name: 'Zoe', role: Role.piper, camp: Camp.solo),
    Player(id: '27', name: 'Arthur', role: Role.angel, camp: Camp.solo),
    Player(id: '28', name: 'Bastien', role: Role.thief, camp: Camp.neutral),
    Player(id: '29', name: 'Chloe', role: Role.actor, camp: Camp.neutral),
    Player(id: '30', name: 'Damien', role: Role.abominableSectarian, camp: Camp.solo),
  ];

  final engine = FullGameSimulator(initial30Players);
  engine.printStatus();

  // === SIMULATION D'UN TOUR DE TEST DEV (NUIT 1) ===

  // 1. Initialisations
  engine.powerThief('28', Role.villager, Camp.village);
  engine.powerCupid('05', '04', '19'); // Chasseur lié à un Loup (Amour impossible)
  engine.powerGuard('07', '02');        // Salvateur protège la Voyante

  // 2. Détections
  engine.powerSeer('02', '21');         // Voyante sonde le Grand Méchant Loup
  engine.powerFox('10', '18', '19', '20'); // Renard flaire un groupe avec des loups

  // 3. Attaques nocturnes
  engine.powerWerewolvesVote('08');     // La meute attaque l'Ancien (qui a 2 vies)
  engine.powerBigBadWolf('21', '01');   // Le Grand Méchant Loup croque Alice
  engine.powerWhiteWolf('22', '20');    // Le Loup Blanc élimine Tom

  // 4. Sorts et malédictions
  engine.powerWitch(witchId: '03', heal: false, poisonTargetId: '30'); // Sorcière empoisonne le Sectaire
  engine.powerPiper('26', ['06', '09', '11']); // Le joueur de flûte charme 3 joueurs
  engine.powerRaven('17', '19');        // Le Corbeau désigne Sam

  // 5. Lever du jour
  engine.resolveNight();

  engine.printStatus();
}
