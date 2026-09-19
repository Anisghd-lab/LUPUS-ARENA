import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'game_engine_models.dart';
import '../services/death_registry_service.dart';

class GameController extends ChangeNotifier {
  // --- ÉTAT DU JEU ---
  GamePhase _currentPhase = GamePhase.initialization;
  int _currentTurn = 0;
  final List<Player> _players = [];
  final Queue<GameStep> _stepQueue = Queue<GameStep>();
  GameStep? _activeStep;

  // --- ACTIONS & BUFFERS ---
  final NightActionBuffer _nightBuffer = NightActionBuffer();
  List<String> _pendingDeathsAnnouncement = [];
  final Map<String, String> _votes = {}; // voterId -> targetId

  // --- ÉTATS PERSISTANTS DES RÔLES ---
  String? _lastBodyguardProtectedId;
  bool _foxPowerActive = true;
  String? _crowTargetId;
  bool _fatherOfWolvesInfectionUsed = false;
  bool _witchLifePotionUsed = false;
  bool _witchDeathPotionUsed = false;
  bool _stutteringJudgeSignUsed = false;
  bool _stutteringJudgeTriggeredThisDay = false;
  int _wolvesCasualtiesCount = 0;

  // --- TIMERS ---
  Timer? _turnTimer;
  int _secondsRemaining = 0;

  // --- GETTERS PUBLICS ---
  GamePhase get currentPhase => _currentPhase;
  int get currentTurn => _currentTurn;
  List<Player> get players => List.unmodifiable(_players);
  GameStep? get activeStep => _activeStep;
  int get secondsRemaining => _secondsRemaining;
  List<String> get pendingDeathsAnnouncement => List.unmodifiable(_pendingDeathsAnnouncement);
  String? get crowTargetId => _crowTargetId;

  // ===========================================================================
  // 1. GESTION DU CYCLE DE VIE ET DES TIMERS
  // ===========================================================================

  void _startTimer(int seconds, VoidCallback onTimeout) {
    _turnTimer?.cancel();
    _secondsRemaining = seconds;
    notifyListeners();

    _turnTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 1) {
        _secondsRemaining--;
        notifyListeners();
      } else {
        _turnTimer?.cancel();
        _secondsRemaining = 0;
        notifyListeners();
        onTimeout();
      }
    });
  }

  void _stopTimer() {
    _turnTimer?.cancel();
    _turnTimer = null;
  }

  // ===========================================================================
  // 2. VÉRIFICATION DE PRÉSENCE & SURVIE (Moteur d'initiation)
  // ===========================================================================

  /// Vérifie si un rôle est configuré dans la partie ET qu'au moins un détenteur est vivant.
  bool _isRolePresentAndAlive(RoleType role) {
    return _players.any((p) =>
        p.role == role &&
        p.isAlive &&
        !DeathRegistryService.instance.isDead(p.id));
  }

  /// Vérifie si au moins un membre de la meute des loups est vivant
  bool _areWerewolvesPresentAndAlive() {
    return _players.any((p) =>
        (p.role == RoleType.werewolf ||
         p.role == RoleType.fatherOfWolves ||
         p.role == RoleType.bigBadWolf ||
         p.faction == Faction.werewolves) &&
        p.isAlive &&
        !DeathRegistryService.instance.isDead(p.id));
  }

  // ===========================================================================
  // 3. CONSTRUCTION DYNAMIQUE DE LA FILE D'ATTENTE DE NUIT
  // ===========================================================================

  void _buildNightStepQueue() {
    _stepQueue.clear();

    if (_currentTurn == 0) {
      // Nuit préliminaire
      if (_isRolePresentAndAlive(RoleType.stealer)) {
        _stepQueue.add(GameStep.preStealer);
      }
      if (_isRolePresentAndAlive(RoleType.cupid)) {
        _stepQueue.add(GameStep.preCupid);
      }
      return;
    }

    // Nuit Régulière : Ordre strict d'activation
    if (_isRolePresentAndAlive(RoleType.actor)) {
      _stepQueue.add(GameStep.roleActor);
    }
    if (_isRolePresentAndAlive(RoleType.seer)) {
      _stepQueue.add(GameStep.roleSeer);
    }
    if (_isRolePresentAndAlive(RoleType.fox) && _foxPowerActive) {
      _stepQueue.add(GameStep.roleFox);
    }
    if (_isRolePresentAndAlive(RoleType.crow)) {
      _stepQueue.add(GameStep.roleCrow);
    }
    if (_isRolePresentAndAlive(RoleType.pyromaniac)) {
      _stepQueue.add(GameStep.rolePyromaniac);
    }
    if (_isRolePresentAndAlive(RoleType.bodyguard)) {
      _stepQueue.add(GameStep.roleBodyguard);
    }
    if (_areWerewolvesPresentAndAlive()) {
      _stepQueue.add(GameStep.roleWerewolves);
    }
    // Grand Méchant Loup : vivant ET aucun loup n'est mort depuis le début
    if (_isRolePresentAndAlive(RoleType.bigBadWolf) && _wolvesCasualtiesCount == 0) {
      _stepQueue.add(GameStep.roleBigBadWolf);
    }
    // Loup Blanc : vivant ET nuit paire
    if (_isRolePresentAndAlive(RoleType.whiteWolf) && (_currentTurn % 2 == 0)) {
      _stepQueue.add(GameStep.roleWhiteWolf);
    }
    if (_isRolePresentAndAlive(RoleType.witch)) {
      _stepQueue.add(GameStep.roleWitch);
    }
  }

  // ===========================================================================
  // 4. TRANSITIONS DE PHASES & DÉPILAGE DE LA FILE
  // ===========================================================================

  void startGame(List<Player> initialPlayers) {
    _players.clear();
    _players.addAll(initialPlayers);
    _currentTurn = 0;
    _wolvesCasualtiesCount = 0;
    _foxPowerActive = true;
    _lastBodyguardProtectedId = null;
    _crowTargetId = null;
    _fatherOfWolvesInfectionUsed = false;
    _witchLifePotionUsed = false;
    _witchDeathPotionUsed = false;
    _stutteringJudgeSignUsed = false;
    _stutteringJudgeTriggeredThisDay = false;
    _startPreliminaryNight();
  }

  void _startPreliminaryNight() {
    _currentPhase = GamePhase.preliminaryNight;
    _buildNightStepQueue();
    _executeNextNightStep();
  }

  void _startRegularNight() {
    _currentTurn++;
    _currentPhase = GamePhase.night;
    _nightBuffer.clear();
    _buildNightStepQueue();
    _executeNextNightStep();
  }

  void _executeNextNightStep() {
    if (_stepQueue.isNotEmpty) {
      _activeStep = _stepQueue.removeFirst();
      // Timeout automatique de 20s par sous-phase
      _startTimer(20, () => actionPass());
      notifyListeners();
    } else {
      _stopTimer();
      _activeStep = null;
      if (_currentPhase == GamePhase.preliminaryNight) {
        _startRegularNight();
      } else {
        _resolveNightActionsAndWakeUp();
      }
    }
  }

  /// Passe l'étape actuelle par défaut (fallback en cas d'expiration du timer)
  void actionPass() {
    _stopTimer();
    _executeNextNightStep();
  }

  // ===========================================================================
  // 5. ACTIONS DES RÔLES PENDANT LA NUIT (BUFFERISATION)
  // ===========================================================================

  void actionStealerStealRole(String stealerId, String targetPlayerId) {
    if (_activeStep != GameStep.preStealer) return;
    final stealerIndex = _players.indexWhere((p) => p.id == stealerId);
    final targetIndex = _players.indexWhere((p) => p.id == targetPlayerId);

    if (stealerIndex != -1 && targetIndex != -1) {
      final stolenRole = _players[targetIndex].role;
      final stolenFaction = _players[targetIndex].faction;

      _players[targetIndex].role = RoleType.villager;
      _players[targetIndex].faction = Faction.village;

      _players[stealerIndex].role = stolenRole;
      _players[stealerIndex].faction = stolenFaction;
    }

    _stopTimer();
    _executeNextNightStep();
  }

  void actionCupidLinkLovers(String player1Id, String player2Id) {
    if (_activeStep != GameStep.preCupid) return;
    for (var p in _players) {
      if (p.id == player1Id || p.id == player2Id) {
        p.loversIds.add(player1Id);
        p.loversIds.add(player2Id);
      }
    }
    _executeNextNightStep();
  }

  void actionFoxSmell(String centerPlayerId) {
    if (_activeStep != GameStep.roleFox) return;

    // Identification de la cible et de ses voisins vivants
    final aliveList = _players.where((p) => p.isAlive).toList();
    final index = aliveList.indexWhere((p) => p.id == centerPlayerId);

    if (index != -1) {
      final leftNeighbor = aliveList[(index - 1 + aliveList.length) % aliveList.length];
      final rightNeighbor = aliveList[(index + 1) % aliveList.length];
      final target = aliveList[index];

      final trio = [target, leftNeighbor, rightNeighbor];
      final wolfFound = trio.any((p) =>
          p.faction == Faction.werewolves ||
          p.role == RoleType.werewolf ||
          p.role == RoleType.bigBadWolf ||
          p.role == RoleType.fatherOfWolves ||
          p.role == RoleType.whiteWolf);

      if (!wolfFound) {
        _foxPowerActive = false; // Pouvoir perdu définitivement
      }
    }
    _executeNextNightStep();
  }

  void actionCrowTarget(String targetId) {
    if (_activeStep != GameStep.roleCrow) return;
    _crowTargetId = targetId;
    _executeNextNightStep();
  }

  void actionBodyguardProtect(String targetId) {
    if (_activeStep != GameStep.roleBodyguard) return;
    if (targetId == _lastBodyguardProtectedId) {
      return; // Interdiction de cibler le même joueur 2 nuits de suite
    }
    _nightBuffer.protectedPlayerId = targetId;
    _lastBodyguardProtectedId = targetId;
    _executeNextNightStep();
  }

  void actionPyromaniac({List<String>? douseTargets, bool ignite = false}) {
    if (_activeStep != GameStep.rolePyromaniac) return;
    if (ignite) {
      for (var p in _players.where((p) => p.isAlive && p.isDousedWithGas)) {
        _nightBuffer.killIntents.add(
          KillIntent(targetPlayerId: p.id, source: KillSource.pyromaniacFire),
        );
      }
    } else if (douseTargets != null) {
      for (var id in douseTargets.take(2)) {
        final p = _players.where((pl) => pl.id == id).firstOrNull;
        if (p != null) {
          p.isDousedWithGas = true;
        }
      }
    }
    _executeNextNightStep();
  }

  void actionWerewolvesVote(String targetId, {bool infect = false}) {
    if (_activeStep != GameStep.roleWerewolves) return;
    if (infect && !_fatherOfWolvesInfectionUsed && _isRolePresentAndAlive(RoleType.fatherOfWolves)) {
      _nightBuffer.isInfected = true;
      _fatherOfWolvesInfectionUsed = true;
    }
    _nightBuffer.killIntents.add(
      KillIntent(targetPlayerId: targetId, source: KillSource.werewolves),
    );
    _executeNextNightStep();
  }

  void actionBigBadWolfKill(String targetId) {
    if (_activeStep != GameStep.roleBigBadWolf) return;
    _nightBuffer.killIntents.add(
      KillIntent(targetPlayerId: targetId, source: KillSource.bigBadWolf),
    );
    _executeNextNightStep();
  }

  void actionWhiteWolfKill(String targetId) {
    if (_activeStep != GameStep.roleWhiteWolf) return;
    _nightBuffer.killIntents.add(
      KillIntent(targetPlayerId: targetId, source: KillSource.whiteWolf),
    );
    _executeNextNightStep();
  }

  void actionWitchDecide({bool useLifePotion = false, String? killTargetId}) {
    if (_activeStep != GameStep.roleWitch) return;

    if (useLifePotion && !_witchLifePotionUsed) {
      // Sauve la victime principale des loups
      final wolfVictim = _nightBuffer.killIntents
          .where((k) => k.source == KillSource.werewolves)
          .map((k) => k.targetPlayerId)
          .firstOrNull;

      if (wolfVictim != null) {
        _nightBuffer.healedPlayerId = wolfVictim;
        _witchLifePotionUsed = true;
      }
    }

    if (killTargetId != null && !_witchDeathPotionUsed) {
      _nightBuffer.killIntents.add(
        KillIntent(targetPlayerId: killTargetId, source: KillSource.witchPoison),
      );
      _witchDeathPotionUsed = true;
    }
    _executeNextNightStep();
  }

  // ===========================================================================
  // 6. ACTION BUFFER & RÉSOLUTION DU MATIN
  // ===========================================================================

  void _resolveNightActionsAndWakeUp() {
    final Set<String> resolvedDeaths = {};

    // 1. Traitement de l'Infection
    String? infectedVictimId;
    if (_nightBuffer.isInfected) {
      final wolfAttack = _nightBuffer.killIntents.firstWhere(
        (k) => k.source == KillSource.werewolves,
        orElse: () => const KillIntent(targetPlayerId: '', source: KillSource.werewolves),
      );
      if (wolfAttack.targetPlayerId.isNotEmpty) {
        infectedVictimId = wolfAttack.targetPlayerId;
        final target = _players.where((p) => p.id == infectedVictimId).firstOrNull;
        if (target != null) {
          target.faction = Faction.werewolves;
        }
      }
    }

    // 2. Traitement des attaques et protections
    for (final intent in _nightBuffer.killIntents) {
      final targetId = intent.targetPlayerId;
      if (targetId.isEmpty) continue;

      // Si le joueur est infecté, il ne meurt pas de l'attaque des loups
      if (intent.source == KillSource.werewolves && targetId == infectedVictimId) {
        continue;
      }

      // Si guéri par la Sorcière
      if (_nightBuffer.healedPlayerId == targetId) {
        continue;
      }

      // Bouclier du Salvateur : annule les attaques des loups uniquement
      if (_nightBuffer.protectedPlayerId == targetId &&
          (intent.source == KillSource.werewolves ||
           intent.source == KillSource.bigBadWolf ||
           intent.source == KillSource.whiteWolf)) {
        continue;
      }

      // Poison Sorcière, Feu Pyromane ou Attaque physique non bloquée
      resolvedDeaths.add(targetId);
    }

    // 3. Propagation du Chagrin d'Amour
    final loversDying = <String>{};
    for (final victimId in resolvedDeaths) {
      final victim = _players.where((p) => p.id == victimId).firstOrNull;
      if (victim != null && victim.loversIds.isNotEmpty) {
        loversDying.addAll(victim.loversIds);
      }
    }
    resolvedDeaths.addAll(loversDying);

    // 4. Application effective de l'élimination (inviolable)
    for (final p in _players) {
      if (resolvedDeaths.contains(p.id) && p.isAlive) {
        p.isAlive = false;
        DeathRegistryService.instance.markDead(p.id);
        if (p.role == RoleType.werewolf ||
            p.role == RoleType.bigBadWolf ||
            p.role == RoleType.fatherOfWolves ||
            p.role == RoleType.whiteWolf) {
          _wolvesCasualtiesCount++;
        }
      }
    }

    _pendingDeathsAnnouncement = resolvedDeaths.toList();
    _startDayAnnouncements();
  }

  // ===========================================================================
  // 7. PHASES DE JOUR & VOTE
  // ===========================================================================

  void _startDayAnnouncements() {
    _currentPhase = GamePhase.dayAnnounceDeaths;
    notifyListeners();

    // Hook Servante Dévouée : si vivante et qu'il y a des morts
    if (_isRolePresentAndAlive(RoleType.dedicatedMaid) && _pendingDeathsAnnouncement.isNotEmpty) {
      _activeStep = GameStep.hookDedicatedMaid;
      _startTimer(10, () => _endAnnouncementsAndDiscuss());
    } else {
      _startTimer(5, () => _endAnnouncementsAndDiscuss());
    }
  }

  void actionDedicatedMaidTakeRole(String targetDeadId) {
    if (_activeStep != GameStep.hookDedicatedMaid) return;
    final deadPlayer = _players.where((p) => p.id == targetDeadId).firstOrNull;
    final maid = _players.where((p) => p.role == RoleType.dedicatedMaid && p.isAlive).firstOrNull;

    if (deadPlayer != null && maid != null) {
      maid.role = deadPlayer.role;
    }
    _stopTimer();
    _endAnnouncementsAndDiscuss();
  }

  void _endAnnouncementsAndDiscuss() {
    _activeStep = null;
    _currentPhase = GamePhase.dayDiscussion;
    // Débat : 120 secondes
    _startTimer(120, () => startDayVoting());
    notifyListeners();
  }

  void startDayVoting() {
    _stopTimer();
    _currentPhase = GamePhase.dayVoting;
    _votes.clear();
    // Vote : 30 secondes
    _startTimer(30, () => resolveVotesAndExecute());
    notifyListeners();
  }

  void castVote(String voterId, String targetId) {
    if (_currentPhase != GamePhase.dayVoting) return;

    // Règle inviolable : Un joueur mort ne peut pas voter
    if (DeathRegistryService.instance.isDead(voterId)) return;
    final voter = _players.where((p) => p.id == voterId).firstOrNull;
    if (voter == null || !voter.isAlive) return;

    // Règle inviolable : Impossible de voter contre un joueur mort
    if (DeathRegistryService.instance.isDead(targetId)) return;
    final target = _players.where((p) => p.id == targetId).firstOrNull;
    if (target == null || !target.isAlive) return;

    _votes[voterId] = targetId;

    // Si tous les joueurs vivants ont voté, résolution immédiate
    final aliveCount = _players.where((p) => p.isAlive).length;
    if (_votes.length >= aliveCount) {
      resolveVotesAndExecute();
    }
  }

  void resolveVotesAndExecute() {
    _stopTimer();
    _currentPhase = GamePhase.dayExecution;

    // Calcul des scores
    final Map<String, int> scores = {};
    for (var p in _players.where((p) => p.isAlive)) {
      scores[p.id] = 0;
    }

    // Corbeau : +2 votes automatiques sur la cible
    if (_crowTargetId != null && scores.containsKey(_crowTargetId)) {
      scores[_crowTargetId!] = scores[_crowTargetId!]! + 2;
    }

    // Dépouillement avec prise en compte du Capitaine (2 voix)
    _votes.forEach((voterId, targetId) {
      if (scores.containsKey(targetId)) {
        final voter = _players.where((p) => p.id == voterId).firstOrNull;
        if (voter != null) {
          scores[targetId] = scores[targetId]! + (voter.isCaptain ? 2 : 1);
        }
      }
    });

    // Recherche de la majorité
    int highestScore = -1;
    List<String> highestVotedIds = [];

    scores.forEach((playerId, score) {
      if (score > highestScore) {
        highestScore = score;
        highestVotedIds = [playerId];
      } else if (score == highestScore) {
        highestVotedIds.add(playerId);
      }
    });

    String? executedPlayerId;
    if (highestVotedIds.length == 1 && highestScore > 0) {
      executedPlayerId = highestVotedIds.first;
    } else if (highestVotedIds.length > 1) {
      // Égalité stricte : choix arbitré par le Capitaine s'il est vivant
      final captain = _players.where((p) => p.isCaptain && p.isAlive).firstOrNull;
      if (captain != null) {
        final captainVote = _votes[captain.id];
        if (captainVote != null && highestVotedIds.contains(captainVote)) {
          executedPlayerId = captainVote;
        }
      }
    }

    // Élimination et mort par amour si applicable
    if (executedPlayerId != null) {
      final executed = _players.where((p) => p.id == executedPlayerId).firstOrNull;
      if (executed != null) {
        executed.isAlive = false;
        DeathRegistryService.instance.markDead(executed.id);

        if (executed.loversIds.isNotEmpty) {
          for (var loverId in executed.loversIds) {
            final lover = _players.where((p) => p.id == loverId).firstOrNull;
            if (lover != null) {
              lover.isAlive = false;
              DeathRegistryService.instance.markDead(lover.id);
            }
          }
        }
      }
    }

    // Reset du Corbeau pour le jour suivant
    _crowTargetId = null;

    // Hook Juge Bègue : Si signe déclenché ce jour-là, on relance un vote
    if (_stutteringJudgeTriggeredThisDay) {
      _stutteringJudgeTriggeredThisDay = false;
      startDayVoting();
      return;
    }

    _checkWinConditionsOrContinue();
  }

  void triggerStutteringJudgeSign() {
    if (_stutteringJudgeSignUsed) return;
    if (_isRolePresentAndAlive(RoleType.stutteringJudge)) {
      _stutteringJudgeSignUsed = true;
      _stutteringJudgeTriggeredThisDay = true;
    }
  }

  // ===========================================================================
  // 8. CONDITIONS DE VICTOIRE
  // ===========================================================================

  void _checkWinConditionsOrContinue() {
    _currentPhase = GamePhase.checkWinConditions;
    notifyListeners();

    final alivePlayers = _players.where((p) => p.isAlive).toList();

    // 1. Victoire Loup Blanc (seul survivant)
    if (alivePlayers.length == 1 && alivePlayers.first.role == RoleType.whiteWolf) {
      _endGame(Faction.whiteWolf);
      return;
    }

    // 2. Victoire des Amoureux (seuls survivants du jeu)
    if (alivePlayers.length == 2 &&
        alivePlayers.first.loversIds.contains(alivePlayers.last.id)) {
      _endGame(Faction.lovers);
      return;
    }

    final aliveWolves = alivePlayers.where((p) =>
        p.faction == Faction.werewolves ||
        p.role == RoleType.werewolf ||
        p.role == RoleType.bigBadWolf ||
        p.role == RoleType.fatherOfWolves ||
        p.role == RoleType.whiteWolf).length;

    final aliveVillagers = alivePlayers.length - aliveWolves;

    // 3. Victoire des Loups
    if (aliveWolves >= aliveVillagers && aliveWolves > 0) {
      _endGame(Faction.werewolves);
      return;
    }

    // 4. Victoire du Village
    if (aliveWolves == 0) {
      _endGame(Faction.village);
      return;
    }

    // La partie continue -> cycle suivant (Nuit)
    _startRegularNight();
  }

  void _endGame(Faction winningFaction) {
    _stopTimer();
    _currentPhase = GamePhase.gameOver;
    notifyListeners();
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }
}
