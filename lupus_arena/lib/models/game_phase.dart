import 'package:flutter/material.dart';

enum GamePhase {
  lobby,

  // --- PHASES NOCTURNES (ORDRE SÉQUENTIEL STRICT) ---
  nightThief, // Voleur (Nuit 1 uniquement)
  nightCupid, // Cupidon (Nuit 1 uniquement)
  nightSeer, // Voyante
  nightDefender, // Salvateur / Protecteur
  nightWerewolves, // Loups-Garous & Petite Fille
  nightWitch, // Sorcière
  nightPyromaniac, // Pyromane (Asperger ou Brûler)

  // --- MATIN & RÉSOLUTIONS DES DÉCÈS ---
  morningAnnouncement, // Annonce des morts & mort de chagrin des amoureux
  hunterDeathChoice, // Ultime tir du Chasseur
  captainSuccession, // Passation de pouvoir du Capitaine éliminé

  // --- PHASES DIURNES ---
  captainElection, // Élection du Capitaine (Jour 1 uniquement)
  dayDebate, // Débat ordonné tour par tour (orateur unique)
  dayVoting, // Scrutin d'élimination du village
  dayDefense, // Plaidoirie des accusés en cas d'égalité
  dayTieBreakVote, // Second vote restreint aux accusés
  dayResolution, // Exécution du verdict

  gameOver;

  static GamePhase fromString(String? phase) {
    if (phase == null) return GamePhase.lobby;
    // Compatibilité rétroactive
    if (phase == 'dayDiscussion') return GamePhase.dayDebate;
    if (phase == 'hunterTurn') return GamePhase.hunterDeathChoice;

    for (final p in GamePhase.values) {
      if (p.name == phase) return p;
    }
    return GamePhase.lobby;
  }

  String get displayName => titleFr;

  String get titleFr {
    switch (this) {
      case GamePhase.lobby:
        return 'Salon d\'attente';
      case GamePhase.nightThief:
        return 'Nuit - Le Voleur choisit sa carte';
      case GamePhase.nightCupid:
        return 'Nuit - Tour de Cupidon';
      case GamePhase.nightDefender:
        return 'Nuit - Le Salvateur protège un villageois';
      case GamePhase.nightSeer:
        return 'Nuit - La Voyante sonde une âme';
      case GamePhase.nightWerewolves:
        return 'Nuit - Les Loups-Garous chassent';
      case GamePhase.nightWitch:
        return 'Nuit - La Sorcière utilise ses potions';
      case GamePhase.nightPyromaniac:
        return 'Nuit - Tour du Pyromane';
      case GamePhase.morningAnnouncement:
        return 'Aube - Le Village découvre les victimes';
      case GamePhase.hunterDeathChoice:
        return 'Dernier Souffle du Chasseur !';
      case GamePhase.captainSuccession:
        return 'Succession du Capitaine';
      case GamePhase.captainElection:
        return 'Élection du Capitaine du Village';
      case GamePhase.dayDebate:
        return 'Débat du Village (Tour par Tour)';
      case GamePhase.dayVoting:
        return 'Scrutin du Bûcher';
      case GamePhase.dayDefense:
        return 'Plaidoirie des Accusés';
      case GamePhase.dayTieBreakVote:
        return 'Vote Décisif de Départage';
      case GamePhase.dayResolution:
        return 'Verdict du Tribunal';
      case GamePhase.gameOver:
        return 'Fin de Partie';
    }
  }

  String get descriptionFr {
    switch (this) {
      case GamePhase.lobby:
        return 'Rassemblement des guerriers... Préparez vos micros pour l\'arène !';
      case GamePhase.nightThief:
        return 'Le voleur dérobe l\'identité d\'un autre joueur en secret.';
      case GamePhase.nightCupid:
        return 'Deux destins sont liés à jamais : si l\'un trépasse, l\'autre meurt de chagrin.';
      case GamePhase.nightDefender:
        return 'Le salvateur immunise un habitant cette nuit (interdiction de répéter deux nuits de suite).';
      case GamePhase.nightSeer:
        return 'La voyante perce à jour la carte d\'un habitant de son choix.';
      case GamePhase.nightWerewolves:
        return 'Les loups votent et débattent en secret. La petite fille écoute passivement.';
      case GamePhase.nightWitch:
        return 'La sorcière découvre la victime des loups et choisit d\'utiliser guérison ou poison.';
      case GamePhase.nightPyromaniac:
        return 'Le pyromane choisit d\'asperger d\'huile une demeure ou d\'embraser tous les foyers aspergés.';
      case GamePhase.morningAnnouncement:
        return 'Le tocsin sonne. Les âmes perdues et les amants brisés quittent la partie.';
      case GamePhase.hunterDeathChoice:
        return 'Le chasseur abat une cible de son choix dans son dernier souffle.';
      case GamePhase.captainSuccession:
        return 'Le capitaine défunt nomme son successeur avant de rejoindre l\'au-delà.';
      case GamePhase.captainElection:
        return 'Le village vote pour élire son chef (sa voix comptera double).';
      case GamePhase.dayDebate:
        return 'Chaque orateur dispose d\'un temps de parole exclusif au micro.';
      case GamePhase.dayVoting:
        return 'Désignez par votre vote qui doit être sacrifié au bûcher.';
      case GamePhase.dayDefense:
        return 'Égalité parfaite ! Les suspects disposent de 30 secondes pour se défendre.';
      case GamePhase.dayTieBreakVote:
        return 'Second vote restreint exclusivement aux accusés ex æquo.';
      case GamePhase.dayResolution:
        return 'La sentence est exécutée sur le condamné désigné.';
      case GamePhase.gameOver:
        return 'L\'arène s\'apaise. Découvrez les identités et les vainqueurs !';
    }
  }

  bool get isNight {
    return this == GamePhase.nightThief ||
        this == GamePhase.nightCupid ||
        this == GamePhase.nightDefender ||
        this == GamePhase.nightSeer ||
        this == GamePhase.nightWerewolves ||
        this == GamePhase.nightWitch ||
        this == GamePhase.nightPyromaniac;
  }

  bool get isDay {
    return this == GamePhase.captainElection ||
        this == GamePhase.dayDebate ||
        this == GamePhase.dayVoting ||
        this == GamePhase.dayDefense ||
        this == GamePhase.dayTieBreakVote ||
        this == GamePhase.dayResolution;
  }

  IconData get icon {
    switch (this) {
      case GamePhase.lobby:
        return Icons.group_rounded;
      case GamePhase.nightThief:
        return Icons.pan_tool_rounded;
      case GamePhase.nightCupid:
        return Icons.favorite_rounded;
      case GamePhase.nightDefender:
        return Icons.security_rounded;
      case GamePhase.nightSeer:
        return Icons.visibility_rounded;
      case GamePhase.nightWerewolves:
        return Icons.nights_stay_rounded;
      case GamePhase.nightWitch:
        return Icons.science_rounded;
      case GamePhase.nightPyromaniac:
        return Icons.local_fire_department_rounded;
      case GamePhase.morningAnnouncement:
        return Icons.wb_twilight_rounded;
      case GamePhase.hunterDeathChoice:
        return Icons.crisis_alert_rounded;
      case GamePhase.captainSuccession:
      case GamePhase.captainElection:
        return Icons.military_tech_rounded;
      case GamePhase.dayDebate:
        return Icons.record_voice_over_rounded;
      case GamePhase.dayVoting:
      case GamePhase.dayTieBreakVote:
        return Icons.how_to_vote_rounded;
      case GamePhase.dayDefense:
        return Icons.speaker_notes_rounded;
      case GamePhase.dayResolution:
        return Icons.gavel_rounded;
      case GamePhase.gameOver:
        return Icons.emoji_events_rounded;
    }
  }

  Color get bannerColor {
    if (isNight) {
      return const Color(0xFF161233);
    } else if (isDay) {
      return const Color(0xFF2C1810);
    } else if (this == GamePhase.gameOver) {
      return const Color(0xFF24102F);
    }
    return const Color(0xFF10162A);
  }
}
