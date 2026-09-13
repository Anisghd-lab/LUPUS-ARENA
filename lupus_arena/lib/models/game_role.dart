import 'package:flutter/material.dart';

enum Team {
  village,
  werewolves,
  solo,
  lovers,
}

enum WakePhase {
  never,
  firstNightOnly,
  everyNight,
  onDeath,
  specialTrigger,
}

enum GameRole {
  // --- CAMP DES VILLAGEOIS ---
  simpleVillager,
  seer,
  witch,
  hunter,
  cupid,
  littleGirl,
  thief,
  defender, // Salvateur
  elder, // Ancien
  scapegoat, // Bouc Émissaire
  idiot, // Idiot du Village
  twoSisters, // Deux Sœurs
  threeBrothers, // Trois Frères
  fox, // Renard
  bearTamer, // Montreur d'Ours
  stutteringJudge, // Juge Bègue
  knightRustySword, // Chevalier à l'Épée Rouillée
  servantMaid, // Servante Dévouée
  actor, // Comédien

  // --- CAMP DES LOUPS-GAROUS ---
  simpleWerewolf,
  bigBadWolf, // Grand Méchant Loup
  whiteWerewolf, // Loup-Garou Blanc
  vileFatherOfWolves, // Infect Père des Loups
  wolfCub, // Chiot / Enfant Sauvage (mode loup)

  // --- RÔLES AMBIGUS & SOLITAIRES ---
  wildChild, // Enfant Sauvage (initial)
  pyromaniac, // Pyromane
  raven, // Corbeau
  angel, // Ange
  piedPiper, // Joueur de Flûte
  sectLeader, // Abominable Sectaire
  thiefOfHearts, // Voleur d'âmes

  // --- RÔLES DE RANG (TITRES) ---
  mayor; // Capitaine / Maire

  String get id => GameRoleExtension(this).id;
  String get displayName => GameRoleExtension(this).displayName;
  String get displayNameFr => GameRoleExtension(this).displayNameFr;
  String get description => GameRoleExtension(this).description;
  String get descriptionFr => GameRoleExtension(this).descriptionFr;
  Team get defaultTeam => GameRoleExtension(this).defaultTeam;
  bool get isEvil => GameRoleExtension(this).isEvil;
  WakePhase get wakePhase => GameRoleExtension(this).wakePhase;
  int get nightExecutionPriority => GameRoleExtension(this).nightExecutionPriority;
  Color get accentColor => GameRoleExtension(this).accentColor;
  IconData get icon => GameRoleExtension(this).icon;

  static GameRole fromId(String id) => GameRoleExtension.fromId(id);
  static GameRole fromString(String? role) => GameRoleExtension.fromString(role);
}

extension GameRoleExtension on GameRole {
  String get id {
    switch (this) {
      case GameRole.simpleVillager: return 'simple_villager';
      case GameRole.seer: return 'seer';
      case GameRole.witch: return 'witch';
      case GameRole.hunter: return 'hunter';
      case GameRole.cupid: return 'cupid';
      case GameRole.littleGirl: return 'little_girl';
      case GameRole.thief: return 'thief';
      case GameRole.defender: return 'defender';
      case GameRole.elder: return 'elder';
      case GameRole.scapegoat: return 'scapegoat';
      case GameRole.idiot: return 'idiot';
      case GameRole.twoSisters: return 'two_sisters';
      case GameRole.threeBrothers: return 'three_brothers';
      case GameRole.fox: return 'fox';
      case GameRole.bearTamer: return 'bear_tamer';
      case GameRole.stutteringJudge: return 'stuttering_judge';
      case GameRole.knightRustySword: return 'knight_rusty_sword';
      case GameRole.servantMaid: return 'servant_maid';
      case GameRole.actor: return 'actor';

      case GameRole.simpleWerewolf: return 'simple_werewolf';
      case GameRole.bigBadWolf: return 'big_bad_wolf';
      case GameRole.whiteWerewolf: return 'white_werewolf';
      case GameRole.vileFatherOfWolves: return 'vile_father_of_wolves';
      case GameRole.wolfCub: return 'wolf_cub';

      case GameRole.wildChild: return 'wild_child';
      case GameRole.pyromaniac: return 'pyromaniac';
      case GameRole.raven: return 'raven';
      case GameRole.angel: return 'angel';
      case GameRole.piedPiper: return 'pied_piper';
      case GameRole.sectLeader: return 'sect_leader';
      case GameRole.thiefOfHearts: return 'thief_of_hearts';

      case GameRole.mayor: return 'mayor';
    }
  }

  String get displayName {
    switch (this) {
      case GameRole.simpleVillager: return 'Simple Villageois';
      case GameRole.seer: return 'Voyante';
      case GameRole.witch: return 'Sorcière';
      case GameRole.hunter: return 'Chasseur';
      case GameRole.cupid: return 'Cupidon';
      case GameRole.littleGirl: return 'Petite Fille';
      case GameRole.thief: return 'Voleur';
      case GameRole.defender: return 'Salvateur';
      case GameRole.elder: return 'Ancien';
      case GameRole.scapegoat: return 'Bouc Émissaire';
      case GameRole.idiot: return 'Idiot du Village';
      case GameRole.twoSisters: return 'Deux Sœurs';
      case GameRole.threeBrothers: return 'Trois Frères';
      case GameRole.fox: return 'Renard';
      case GameRole.bearTamer: return 'Montreur d\'Ours';
      case GameRole.stutteringJudge: return 'Juge Bègue';
      case GameRole.knightRustySword: return 'Chevalier à l\'Épée Rouillée';
      case GameRole.servantMaid: return 'Servante Dévouée';
      case GameRole.actor: return 'Comédien';

      case GameRole.simpleWerewolf: return 'Loup-Garou';
      case GameRole.bigBadWolf: return 'Grand Méchant Loup';
      case GameRole.whiteWerewolf: return 'Loup-Garou Blanc';
      case GameRole.vileFatherOfWolves: return 'Infect Père des Loups';
      case GameRole.wolfCub: return 'Chiot Loup';

      case GameRole.wildChild: return 'Enfant Sauvage';
      case GameRole.pyromaniac: return 'Pyromane';
      case GameRole.raven: return 'Corbeau';
      case GameRole.angel: return 'Ange';
      case GameRole.piedPiper: return 'Joueur de Flûte';
      case GameRole.sectLeader: return 'Abominable Sectaire';
      case GameRole.thiefOfHearts: return 'Voleur d\'Âmes';

      case GameRole.mayor: return 'Capitaine';
    }
  }

  String get displayNameFr => displayName;

  String get description {
    switch (this) {
      case GameRole.simpleVillager:
        return 'Ne possède aucun pouvoir particulier. Utilise sa déduction lors des débats de jour.';
      case GameRole.seer:
        return 'Chaque nuit, découvre l\'identité secrète d\'un joueur de son choix.';
      case GameRole.witch:
        return 'Possède deux potions uniques : une pour sauver la victime des loups, une pour empoisonner un suspect.';
      case GameRole.hunter:
        return 'S\'il se fait éliminer, il tire immédiatement une ultime balle sur le joueur de son choix.';
      case GameRole.cupid:
        return 'Désigne deux amoureux la première nuit. Si l\'un trépasse, l\'autre meurt instantanément de chagrin.';
      case GameRole.littleGirl:
        return 'Espionne secrètement les loups pendant leur tour sans pouvoir parler.';
      case GameRole.thief:
        return 'La première nuit, vole définitivement la carte d\'un autre joueur et lui donne le rôle de Villageois.';
      case GameRole.defender:
        return 'Chaque nuit, protège un joueur contre l\'attaque des loups. Ne peut pas protéger le même deux nuits de suite.';
      case GameRole.elder:
        return 'Survit à la première morsure des loups. Si le village le condamne, tous perdent leurs pouvoirs.';
      case GameRole.scapegoat:
        return 'En cas d\'égalité parfaite au vote sans consensus, il est désigné coupable d\'office.';
      case GameRole.idiot:
        return 'S\'il est condamné par le village, il est gracié mais perd définitivement son droit de vote.';
      case GameRole.twoSisters:
        return 'Se réveillent ensemble la première nuit pour établir leur innocence réciproque.';
      case GameRole.threeBrothers:
        return 'Se réveillent ensemble la première nuit pour coordonner leurs votes.';
      case GameRole.fox:
        return 'Flaire un groupe de 3 joueurs adjacents. S\'il y a au moins un loup, il conserve son pouvoir.';
      case GameRole.bearTamer:
        return 'Grogne à l\'aube si au moins un de ses voisins directs vivants est un loup.';
      case GameRole.stutteringJudge:
        return 'Peut imposer un double vote au village une fois par partie.';
      case GameRole.knightRustySword:
        return 'S\'il est dévoré, il infecte le premier loup à sa gauche, qui mourra la nuit suivante.';
      case GameRole.servantMaid:
        return 'Peut échanger sa carte avec celle d\'un joueur éliminé juste avant sa révélation.';
      case GameRole.actor:
        return 'Choisit chaque nuit un pouvoir parmi trois cartes tirées au sort.';

      case GameRole.simpleWerewolf:
        return 'Dévore un villageois chaque nuit en meute et se dissimule le jour.';
      case GameRole.bigBadWolf:
        return 'Dévore une seconde victime chaque nuit tant qu\'aucun loup n\'est mort.';
      case GameRole.whiteWerewolf:
        return 'Se réveille avec les loups, mais se réveille une nuit sur deux pour éliminer un loup.';
      case GameRole.vileFatherOfWolves:
        return 'Une fois par partie, transforme la victime des loups en loup-garou au lieu de la tuer.';
      case GameRole.wolfCub:
        return 'Si le chiot est abattu, les loups dévorent deux victimes la nuit suivante.';

      case GameRole.wildChild:
        return 'Choisit un modèle vivant. Si ce modèle périt, l\'enfant sauvage devient un loup-garou.';
      case GameRole.pyromaniac:
        return 'Chaque nuit, asperge de pétrole un joueur ou allume le feu pour éliminer d\'un coup tous les suspects aspergés.';
      case GameRole.raven:
        return 'Chaque nuit, désigne un joueur qui aura automatiquement deux voix contre lui au vote.';
      case GameRole.angel:
        return 'Gagne immédiatement la partie s\'il se fait éliminer par le village dès le premier jour.';
      case GameRole.piedPiper:
        return 'Enchante deux joueurs chaque nuit. Remporte la victoire s\'il charme tous les vivants.';
      case GameRole.sectLeader:
        return 'Divise le village en deux clans et gagne si tout le clan opposé est éradiqué.';
      case GameRole.thiefOfHearts:
        return 'S\'infiltre dans un couple et prend la place de l\'un des deux amants.';

      case GameRole.mayor:
        return 'Élu par le village. Sa voix pèse double lors de tous les scrutins.';
    }
  }

  String get descriptionFr => description;

  Team get defaultTeam {
    switch (this) {
      case GameRole.simpleWerewolf:
      case GameRole.bigBadWolf:
      case GameRole.vileFatherOfWolves:
      case GameRole.wolfCub:
        return Team.werewolves;

      case GameRole.whiteWerewolf:
      case GameRole.piedPiper:
      case GameRole.angel:
      case GameRole.sectLeader:
      case GameRole.thiefOfHearts:
      case GameRole.pyromaniac:
        return Team.solo;

      default:
        return Team.village;
    }
  }

  bool get isEvil =>
      defaultTeam == Team.werewolves || this == GameRole.whiteWerewolf;

  WakePhase get wakePhase {
    switch (this) {
      case GameRole.thief:
      case GameRole.cupid:
      case GameRole.twoSisters:
      case GameRole.threeBrothers:
      case GameRole.wildChild:
        return WakePhase.firstNightOnly;

      case GameRole.seer:
      case GameRole.defender:
      case GameRole.simpleWerewolf:
      case GameRole.bigBadWolf:
      case GameRole.whiteWerewolf:
      case GameRole.vileFatherOfWolves:
      case GameRole.witch:
      case GameRole.fox:
      case GameRole.pyromaniac:
      case GameRole.raven:
      case GameRole.piedPiper:
      case GameRole.actor:
        return WakePhase.everyNight;

      case GameRole.hunter:
      case GameRole.knightRustySword:
      case GameRole.servantMaid:
        return WakePhase.onDeath;

      default:
        return WakePhase.never;
    }
  }

  /// Ordre séquentiel strict de réveil nocturne
  int get nightExecutionPriority {
    switch (this) {
      case GameRole.thief: return 10;
      case GameRole.cupid: return 20;
      case GameRole.wildChild: return 30;
      case GameRole.twoSisters: return 40;
      case GameRole.threeBrothers: return 50;
      case GameRole.defender: return 60;
      case GameRole.seer: return 70;
      case GameRole.fox: return 80;
      case GameRole.simpleWerewolf:
      case GameRole.littleGirl:
      case GameRole.vileFatherOfWolves:
      case GameRole.wolfCub: return 90;
      case GameRole.bigBadWolf: return 100;
      case GameRole.whiteWerewolf: return 110;
      case GameRole.witch: return 120;
      case GameRole.pyromaniac: return 130;
      case GameRole.raven: return 135;
      case GameRole.piedPiper: return 140;
      default: return 999;
    }
  }

  Color get accentColor {
    switch (this) {
      case GameRole.simpleWerewolf:
      case GameRole.bigBadWolf:
      case GameRole.vileFatherOfWolves:
      case GameRole.wolfCub:
        return const Color(0xFFFF2A55); // Neon crimson
      case GameRole.whiteWerewolf:
        return const Color(0xFFE0AAFF); // Mystic white/silver
      case GameRole.seer:
        return const Color(0xFF9D4EDD); // Violet mystic
      case GameRole.witch:
        return const Color(0xFF06D6A0); // Emerald poison
      case GameRole.hunter:
        return const Color(0xFFFFB703); // Amber gunfire
      case GameRole.cupid:
        return const Color(0xFFFF70A6); // Rose passion
      case GameRole.littleGirl:
        return const Color(0xFFFFC6FF); // Soft pink
      case GameRole.thief:
        return const Color(0xFF8338EC); // Deep purple
      case GameRole.defender:
        return const Color(0xFF3A86FF); // Protective blue
      case GameRole.elder:
        return const Color(0xFFE2B714); // Wisdom gold
      case GameRole.scapegoat:
        return const Color(0xFFDDA15E); // Earth ochre
      case GameRole.idiot:
        return const Color(0xFFF4A261); // Joyful orange
      case GameRole.twoSisters:
        return const Color(0xFFB5E48C); // Spring green
      case GameRole.threeBrothers:
        return const Color(0xFF76C893); // Mint green
      case GameRole.fox:
        return const Color(0xFFFB8500); // Fox bright orange
      case GameRole.bearTamer:
        return const Color(0xFFBC6C25); // Bear brown
      case GameRole.stutteringJudge:
        return const Color(0xFFE76F51); // Judicial terra-cotta
      case GameRole.knightRustySword:
        return const Color(0xFF9A8C98); // Rusty iron
      case GameRole.servantMaid:
        return const Color(0xFFC9ADA7); // Velvet dust
      case GameRole.actor:
        return const Color(0xFFFFD166); // Theatre yellow
      case GameRole.wildChild:
        return const Color(0xFF52B788); // Forest green
      case GameRole.pyromaniac:
        return const Color(0xFFFF4800); // Burning flame
      case GameRole.raven:
        return const Color(0xFF64748B); // Raven slate
      case GameRole.angel:
        return const Color(0xFFE9ECEF); // Holy white
      case GameRole.piedPiper:
        return const Color(0xFF7209B7); // Hypnotic purple
      case GameRole.sectLeader:
        return const Color(0xFF3F37C9); // Deep cult indigo
      case GameRole.thiefOfHearts:
        return const Color(0xFFFF0054); // Passion magenta
      case GameRole.mayor:
        return const Color(0xFFFFD700); // Imperial gold
      case GameRole.simpleVillager:
        return const Color(0xFF4CC9F0); // Azure daylight
    }
  }

  IconData get icon {
    switch (this) {
      case GameRole.simpleWerewolf:
      case GameRole.bigBadWolf:
      case GameRole.vileFatherOfWolves:
      case GameRole.wolfCub:
        return Icons.pets_rounded;
      case GameRole.whiteWerewolf:
        return Icons.brightness_7_rounded;
      case GameRole.seer:
        return Icons.visibility_rounded;
      case GameRole.witch:
        return Icons.science_rounded;
      case GameRole.hunter:
        return Icons.gps_fixed_rounded;
      case GameRole.cupid:
        return Icons.favorite_rounded;
      case GameRole.littleGirl:
        return Icons.visibility_outlined;
      case GameRole.thief:
        return Icons.pan_tool_rounded;
      case GameRole.defender:
        return Icons.security_rounded;
      case GameRole.elder:
        return Icons.elderly_rounded;
      case GameRole.scapegoat:
        return Icons.person_off_rounded;
      case GameRole.idiot:
        return Icons.sentiment_very_satisfied_rounded;
      case GameRole.twoSisters:
        return Icons.people_alt_rounded;
      case GameRole.threeBrothers:
        return Icons.groups_rounded;
      case GameRole.fox:
        return Icons.pest_control_rounded;
      case GameRole.bearTamer:
        return Icons.pets_outlined;
      case GameRole.stutteringJudge:
        return Icons.gavel_rounded;
      case GameRole.knightRustySword:
        return Icons.hardware_rounded;
      case GameRole.servantMaid:
        return Icons.clean_hands_rounded;
      case GameRole.actor:
        return Icons.theater_comedy_rounded;
      case GameRole.wildChild:
        return Icons.nature_people_rounded;
      case GameRole.pyromaniac:
        return Icons.local_fire_department_rounded;
      case GameRole.raven:
        return Icons.flutter_dash_rounded;
      case GameRole.angel:
        return Icons.wb_twilight_rounded;
      case GameRole.piedPiper:
        return Icons.music_note_rounded;
      case GameRole.sectLeader:
        return Icons.psychology_alt_rounded;
      case GameRole.thiefOfHearts:
        return Icons.heart_broken_rounded;
      case GameRole.mayor:
        return Icons.military_tech_rounded;
      case GameRole.simpleVillager:
        return Icons.shield_rounded;
    }
  }

  static GameRole fromId(String id) {
    return GameRole.values.firstWhere(
      (role) => role.id == id,
      orElse: () => GameRole.simpleVillager,
    );
  }

  static GameRole fromString(String? role) {
    if (role == null) return GameRole.simpleVillager;
    final clean = role.toLowerCase().trim();
    switch (clean) {
      case 'werewolf':
      case 'loup':
      case 'loup_garou':
      case 'simple_werewolf':
      case 'simplewerewolf':
        return GameRole.simpleWerewolf;
      case 'villager':
      case 'villageois':
      case 'simple_villager':
      case 'simplevillager':
        return GameRole.simpleVillager;
      case 'pyromaniac':
      case 'pyromane':
        return GameRole.pyromaniac;
      case 'raven':
      case 'corbeau':
        return GameRole.raven;
      default:
        for (final r in GameRole.values) {
          if (r.name.toLowerCase() == clean || r.id.toLowerCase() == clean) {
            return r;
          }
        }
        return GameRole.simpleVillager;
    }
  }
}
