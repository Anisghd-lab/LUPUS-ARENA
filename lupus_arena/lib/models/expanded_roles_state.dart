import 'game_role.dart';

/// Modèle d'état étendu pour les 17 rôles additionnels
/// Sérialisable et rétrocompatible avec Firebase RTDB
class ExpandedRolesState {
  final String? infectedPlayerId;
  final String? wildChildModelId;
  final bool wildChildTransformed;
  final String? crowTargetId;
  final Map<String, int> ancientLives; // playerId -> vies restantes (2 par défaut)
  final bool ancientPowerLost; // Si l'Ancien a été tué par le village
  final bool cubDiedYesterday; // Les loups tuent 2 fois cette nuit
  final String? rustyKnightContaminatedWolfId;
  final int? rustyKnightDeathNight;
  final bool judgeSecondVoteAvailable;
  final bool isSecondVoteTriggered;
  final Map<String, List<String>> sectarianTeams; // 'teamA' -> [ids], 'teamB' -> [ids]
  final Map<String, List<GameRole>> actorAvailableRoles; // playerId -> [rôles restants]
  final Set<String> bannedVotersForToday; // Choisi par le Bouc Émissaire
  final bool angelWon;
  final bool foxPowerActive;
  final bool? lastFoxCheckResult;
  final bool bearGrowledThisMorning;
  final bool scapegoatNeedsToBan;
  final bool hasUsedInfection;

  const ExpandedRolesState({
    this.infectedPlayerId,
    this.wildChildModelId,
    this.wildChildTransformed = false,
    this.crowTargetId,
    this.ancientLives = const {},
    this.ancientPowerLost = false,
    this.cubDiedYesterday = false,
    this.rustyKnightContaminatedWolfId,
    this.rustyKnightDeathNight,
    this.judgeSecondVoteAvailable = true,
    this.isSecondVoteTriggered = false,
    this.sectarianTeams = const {},
    this.actorAvailableRoles = const {},
    this.bannedVotersForToday = const {},
    this.angelWon = false,
    this.foxPowerActive = true,
    this.lastFoxCheckResult,
    this.bearGrowledThisMorning = false,
    this.scapegoatNeedsToBan = false,
    this.hasUsedInfection = false,
  });

  List<String> get sectarianTeamA => sectarianTeams['teamA'] ?? const [];
  List<String> get sectarianTeamB => sectarianTeams['teamB'] ?? const [];

  ExpandedRolesState copyWith({
    String? infectedPlayerId,
    String? wildChildModelId,
    bool? wildChildTransformed,
    String? crowTargetId,
    Map<String, int>? ancientLives,
    bool? ancientPowerLost,
    bool? cubDiedYesterday,
    String? rustyKnightContaminatedWolfId,
    int? rustyKnightDeathNight,
    bool? judgeSecondVoteAvailable,
    bool? isSecondVoteTriggered,
    Map<String, List<String>>? sectarianTeams,
    Map<String, List<GameRole>>? actorAvailableRoles,
    Set<String>? bannedVotersForToday,
    bool? angelWon,
    bool? foxPowerActive,
    bool? lastFoxCheckResult,
    bool? bearGrowledThisMorning,
    bool? scapegoatNeedsToBan,
    bool? hasUsedInfection,
  }) {
    return ExpandedRolesState(
      infectedPlayerId: infectedPlayerId ?? this.infectedPlayerId,
      wildChildModelId: wildChildModelId ?? this.wildChildModelId,
      wildChildTransformed: wildChildTransformed ?? this.wildChildTransformed,
      crowTargetId: crowTargetId ?? this.crowTargetId,
      ancientLives: ancientLives ?? this.ancientLives,
      ancientPowerLost: ancientPowerLost ?? this.ancientPowerLost,
      cubDiedYesterday: cubDiedYesterday ?? this.cubDiedYesterday,
      rustyKnightContaminatedWolfId:
          rustyKnightContaminatedWolfId ?? this.rustyKnightContaminatedWolfId,
      rustyKnightDeathNight:
          rustyKnightDeathNight ?? this.rustyKnightDeathNight,
      judgeSecondVoteAvailable:
          judgeSecondVoteAvailable ?? this.judgeSecondVoteAvailable,
      isSecondVoteTriggered:
          isSecondVoteTriggered ?? this.isSecondVoteTriggered,
      sectarianTeams: sectarianTeams ?? this.sectarianTeams,
      actorAvailableRoles: actorAvailableRoles ?? this.actorAvailableRoles,
      bannedVotersForToday: bannedVotersForToday ?? this.bannedVotersForToday,
      angelWon: angelWon ?? this.angelWon,
      foxPowerActive: foxPowerActive ?? this.foxPowerActive,
      lastFoxCheckResult: lastFoxCheckResult ?? this.lastFoxCheckResult,
      bearGrowledThisMorning:
          bearGrowledThisMorning ?? this.bearGrowledThisMorning,
      scapegoatNeedsToBan: scapegoatNeedsToBan ?? this.scapegoatNeedsToBan,
      hasUsedInfection: hasUsedInfection ?? this.hasUsedInfection,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'infectedPlayerId': infectedPlayerId,
      'wildChildModelId': wildChildModelId,
      'wildChildTransformed': wildChildTransformed,
      'crowTargetId': crowTargetId,
      'ancientLives': ancientLives,
      'ancientPowerLost': ancientPowerLost,
      'cubDiedYesterday': cubDiedYesterday,
      'rustyKnightContaminatedWolfId': rustyKnightContaminatedWolfId,
      'rustyKnightDeathNight': rustyKnightDeathNight,
      'judgeSecondVoteAvailable': judgeSecondVoteAvailable,
      'isSecondVoteTriggered': isSecondVoteTriggered,
      'sectarianTeams': sectarianTeams,
      'actorAvailableRoles': actorAvailableRoles.map(
        (key, roles) => MapEntry(key, roles.map((r) => r.id).toList()),
      ),
      'bannedVotersForToday': bannedVotersForToday.toList(),
      'angelWon': angelWon,
      'foxPowerActive': foxPowerActive,
      'lastFoxCheckResult': lastFoxCheckResult,
      'bearGrowledThisMorning': bearGrowledThisMorning,
      'scapegoatNeedsToBan': scapegoatNeedsToBan,
      'hasUsedInfection': hasUsedInfection,
    };
  }

  factory ExpandedRolesState.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return const ExpandedRolesState();

    // Parsing ancientLives
    final parsedAncientLives = <String, int>{};
    if (map['ancientLives'] is Map) {
      (map['ancientLives'] as Map).forEach((k, v) {
        if (k != null && v is num) {
          parsedAncientLives[k.toString()] = v.toInt();
        }
      });
    }

    // Parsing sectarianTeams
    final parsedSectarianTeams = <String, List<String>>{};
    if (map['sectarianTeams'] is Map) {
      (map['sectarianTeams'] as Map).forEach((k, v) {
        if (k != null && v is Iterable) {
          parsedSectarianTeams[k.toString()] =
              v.map((e) => e.toString()).toList();
        }
      });
    }

    // Parsing actorAvailableRoles
    final parsedActorRoles = <String, List<GameRole>>{};
    if (map['actorAvailableRoles'] is Map) {
      (map['actorAvailableRoles'] as Map).forEach((k, v) {
        if (k != null && v is Iterable) {
          parsedActorRoles[k.toString()] = v
              .map((roleId) => GameRole.fromId(roleId.toString()))
              .toList();
        }
      });
    }

    // Parsing bannedVotersForToday
    final parsedBannedVoters = <String>{};
    if (map['bannedVotersForToday'] is Iterable) {
      for (final id in map['bannedVotersForToday'] as Iterable) {
        if (id != null) parsedBannedVoters.add(id.toString());
      }
    }

    return ExpandedRolesState(
      infectedPlayerId: map['infectedPlayerId']?.toString(),
      wildChildModelId: map['wildChildModelId']?.toString(),
      wildChildTransformed: map['wildChildTransformed'] as bool? ?? false,
      crowTargetId: map['crowTargetId']?.toString(),
      ancientLives: parsedAncientLives,
      ancientPowerLost: map['ancientPowerLost'] as bool? ?? false,
      cubDiedYesterday: map['cubDiedYesterday'] as bool? ?? false,
      rustyKnightContaminatedWolfId:
          map['rustyKnightContaminatedWolfId']?.toString(),
      rustyKnightDeathNight: (map['rustyKnightDeathNight'] is num)
          ? (map['rustyKnightDeathNight'] as num).toInt()
          : null,
      judgeSecondVoteAvailable:
          map['judgeSecondVoteAvailable'] as bool? ?? true,
      isSecondVoteTriggered: map['isSecondVoteTriggered'] as bool? ?? false,
      sectarianTeams: parsedSectarianTeams,
      actorAvailableRoles: parsedActorRoles,
      bannedVotersForToday: parsedBannedVoters,
      angelWon: map['angelWon'] as bool? ?? false,
      foxPowerActive: map['foxPowerActive'] as bool? ?? true,
      lastFoxCheckResult: map['lastFoxCheckResult'] as bool?,
      bearGrowledThisMorning:
          map['bearGrowledThisMorning'] as bool? ?? false,
      scapegoatNeedsToBan: map['scapegoatNeedsToBan'] as bool? ?? false,
      hasUsedInfection: map['hasUsedInfection'] as bool? ?? false,
    );
  }
}
