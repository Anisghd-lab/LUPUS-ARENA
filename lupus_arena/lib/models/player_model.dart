import '../services/death_registry_service.dart';
import '../services/role_security_service.dart';
import 'game_role.dart';
export 'game_role.dart';

class PlayerModel {
  final String id;
  final String name;
  final int avatarIndex;
  final GameRole role;
  final bool estDechu; // Si le rôle spécial (Sorcière, Voyante) est devenu Simple Villageois
  final bool isAlive;
  final bool isHost;
  final bool isReady;
  final bool isOnline;
  final bool isBot; // Vrai si le joueur est un bot passif (Mode Dev / Sandbox)
  final int? lastSeen;
  final bool isSpeaking;
  final bool isMuted;
  final String? targetVoteId;
  final bool isLover;
  final String? loverId;
  final bool isCaptain; // Capitaine / Maire élu (voix double)
  final bool isCharmed; // Envoûté par le Joueur de Flûte
  final bool isDoused; // Aspergé d'huile/essence par le Pyromane
  final bool isInfected; // Transformé en Loup par l'Infect Père des Loups
  final bool isSniffed; // Ciblé par le flairage du Renard
  final bool hasWolfSmell; // Présence d'un loup dans le trio flairé
  final bool hasUsedHealPotion;
  final bool hasUsedPoisonPotion;
  final int agoraUid;
  final String? encryptedRole;
  final int seatIndex;
  final String? socketId;
  final int pv;
  final bool isReadyReplay;
  final bool wantsRematch;
  final GameRole? initialRole; // Rôle initial immuable (carte de départ)
  final int potionsVie; // Stock indépendant de potions de vie (Sorcière)
  final int potionsMort; // Stock indépendant de potions de mort (Sorcière)
  final int visionsRestantes; // Quota dynamique de visions (Voyante)

  const PlayerModel({
    required this.id,
    required this.name,
    this.avatarIndex = 0,
    this.role = GameRole.simpleVillager,
    this.estDechu = false,
    this.isAlive = true,
    this.isHost = false,
    this.isReady = false,
    this.isOnline = true,
    this.isBot = false,
    this.lastSeen,
    this.isSpeaking = false,
    this.isMuted = false,
    this.targetVoteId,
    this.isLover = false,
    this.loverId,
    this.isCaptain = false,
    this.isCharmed = false,
    this.isDoused = false,
    this.isInfected = false,
    this.isSniffed = false,
    this.hasWolfSmell = false,
    this.hasUsedHealPotion = false,
    this.hasUsedPoisonPotion = false,
    this.agoraUid = 0,
    this.encryptedRole,
    this.seatIndex = -1,
    this.socketId,
    this.pv = 100,
    this.isReadyReplay = false,
    this.wantsRematch = false,
    this.initialRole,
    this.potionsVie = 1,
    this.potionsMort = 1,
    this.visionsRestantes = 1,
  });

  /// Rôle initial de référence (préservé même si le rôle actif est déchu)
  GameRole get roleInitial => initialRole ?? role;
  GameRole get trueOriginalRole => initialRole ?? role;

  /// Unification du titre de Maire
  bool get isMayor => isCaptain;

  PlayerModel copyWith({
    String? id,
    String? name,
    int? avatarIndex,
    GameRole? role,
    GameRole? roleInitial,
    bool? estDechu,
    bool? isAlive,
    bool? isHost,
    bool? isReady,
    bool? isOnline,
    bool? isBot,
    int? lastSeen,
    bool? isSpeaking,
    bool? isMuted,
    String? targetVoteId,
    bool clearTargetVote = false,
    bool clearTargetVoteId = false,
    bool? isLover,
    String? loverId,
    bool? isCaptain,
    bool? isCharmed,
    bool? isDoused,
    bool? isInfected,
    bool? isSniffed,
    bool? hasWolfSmell,
    bool clearFoxSniff = false,
    bool? hasUsedHealPotion,
    bool? hasUsedPoisonPotion,
    int? agoraUid,
    String? encryptedRole,
    int? seatIndex,
    String? socketId,
    int? pv,
    bool? isReadyReplay,
    bool? wantsRematch,
    GameRole? initialRole,
    int? potionsVie,
    int? potionsMort,
    int? visionsRestantes,
  }) {
    return PlayerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarIndex: avatarIndex ?? this.avatarIndex,
      role: role ?? this.role,
      estDechu: estDechu ?? this.estDechu,
      isAlive: isAlive ?? this.isAlive,
      isHost: isHost ?? this.isHost,
      isReady: isReady ?? this.isReady,
      isOnline: isOnline ?? this.isOnline,
      isBot: isBot ?? this.isBot,
      lastSeen: lastSeen ?? this.lastSeen,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      isMuted: isMuted ?? this.isMuted,
      targetVoteId: (clearTargetVote || clearTargetVoteId) ? null : (targetVoteId ?? this.targetVoteId),
      isLover: isLover ?? this.isLover,
      loverId: loverId ?? this.loverId,
      isCaptain: isCaptain ?? this.isCaptain,
      isCharmed: isCharmed ?? this.isCharmed,
      isDoused: isDoused ?? this.isDoused,
      isInfected: isInfected ?? this.isInfected,
      isSniffed: clearFoxSniff ? false : (isSniffed ?? this.isSniffed),
      hasWolfSmell: clearFoxSniff ? false : (hasWolfSmell ?? this.hasWolfSmell),
      hasUsedHealPotion: hasUsedHealPotion ?? this.hasUsedHealPotion,
      hasUsedPoisonPotion: hasUsedPoisonPotion ?? this.hasUsedPoisonPotion,
      agoraUid: agoraUid ?? this.agoraUid,
      encryptedRole: encryptedRole ?? this.encryptedRole,
      seatIndex: seatIndex ?? this.seatIndex,
      socketId: socketId ?? this.socketId,
      pv: pv ?? this.pv,
      isReadyReplay: isReadyReplay ?? wantsRematch ?? this.isReadyReplay,
      wantsRematch: wantsRematch ?? isReadyReplay ?? this.wantsRematch,
      initialRole: initialRole ?? roleInitial ?? this.initialRole,
      potionsVie: potionsVie ?? this.potionsVie,
      potionsMort: potionsMort ?? this.potionsMort,
      visionsRestantes: visionsRestantes ?? this.visionsRestantes,
    );
  }

  /// Indique si le joueur fait partie du camp des loups (incluant le Loup Blanc et les Infectés)
  bool get isWolf => role.isEvil || role == GameRole.whiteWerewolf || isInfected;
  bool get isWolfTeam => isWolf;

  /// Déchiffre et résout le rôle véritable du joueur de façon déterministe
  GameRole resolveRealRole(String roomCode) {
    if (encryptedRole != null && encryptedRole!.isNotEmpty) {
      final decrypted = RoleSecurityService.decryptRole(
        encryptedRole!,
        id,
        roomCode,
      );
      if (decrypted != null) return decrypted;
    }
    return initialRole ?? role;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'avatarIndex': avatarIndex,
      'role': role.name,
      if (initialRole != null) 'roleInitial': initialRole!.name,
      if (initialRole != null) 'initialRole': initialRole!.name,
      'estDechu': estDechu,
      'isAlive': isAlive,
      'isHost': isHost,
      'isReady': isReady,
      'isOnline': isOnline,
      'isBot': isBot,
      if (lastSeen != null) 'lastSeen': lastSeen,
      'isSpeaking': isSpeaking,
      'isMuted': isMuted,
      'targetVoteId': targetVoteId,
      'isLover': isLover,
      'loverId': loverId,
      'isCaptain': isCaptain,
      'isCharmed': isCharmed,
      'isDoused': isDoused,
      'isInfected': isInfected,
      'isSniffed': isSniffed,
      'hasWolfSmell': hasWolfSmell,
      'hasUsedHealPotion': hasUsedHealPotion,
      'hasUsedPoisonPotion': hasUsedPoisonPotion,
      'agoraUid': agoraUid,
      if (encryptedRole != null) 'encryptedRole': encryptedRole,
      if (seatIndex >= 0) 'seatIndex': seatIndex,
      if (socketId != null) 'socketId': socketId,
      'pv': pv,
      'isReadyReplay': isReadyReplay || wantsRematch,
      'wantsRematch': wantsRematch || isReadyReplay,
      'potionsVie': potionsVie,
      'potionsMort': potionsMort,
      'visionsRestantes': visionsRestantes,
    };
  }

  factory PlayerModel.fromMap(
    Map<dynamic, dynamic> map, [
    String? docId,
    String? currentUserId,
    String? roomCode,
  ]) {
    final rawRole = map['role']?.toString();
    final encryptedRoleToken = map['encryptedRole']?.toString();
    final playerId = (docId ?? map['id'] ?? '').toString();

    GameRole resolvedRole;
    if (rawRole == 'masked' || rawRole == 'unknown') {
      if (currentUserId != null &&
          roomCode != null &&
          playerId == currentUserId &&
          encryptedRoleToken != null) {
        resolvedRole = RoleSecurityService.decryptRole(
              encryptedRoleToken,
              currentUserId,
              roomCode,
            ) ??
            GameRole.simpleVillager;
      } else {
        resolvedRole = GameRole.simpleVillager;
      }
    } else {
      resolvedRole = GameRole.fromString(rawRole);
    }

    final rawInitialRole = map['initialRole']?.toString() ?? map['roleInitial']?.toString();
    final GameRole? initialRole =
        rawInitialRole != null ? GameRole.fromString(rawInitialRole) : null;
    final isReadyReplayVal = map['isReadyReplay'] == true || map['wantsRematch'] == true;

    return PlayerModel(
      id: playerId,
      name: (map['name'] ?? 'Inconnu').toString(),
      avatarIndex: (map['avatarIndex'] is int)
          ? map['avatarIndex'] as int
          : int.tryParse(map['avatarIndex']?.toString() ?? '0') ?? 0,
      role: resolvedRole,
      estDechu: map['estDechu'] == true ||
          (resolvedRole == GameRole.simpleVillager &&
              (initialRole != null && initialRole != GameRole.simpleVillager)),
      isAlive: DeathRegistryService.instance.isDead(playerId)
          ? false
          : ((map['isAlive'] == false ||
                  map['isAlive'] == 'false' ||
                  map['isAlive'] == 0 ||
                  map['isAlive'] == '0')
              ? false
              : (map['isAlive'] == true ||
                      map['isAlive'] == 'true' ||
                      map['isAlive'] == 1 ||
                      map['isAlive'] == '1')
                  ? true
                  : (map['isAlive'] is bool ? map['isAlive'] as bool : false)),
      isHost: map['isHost'] == true,
      isReady: map['isReady'] == true,
      isOnline: map['isOnline'] != false,
      isBot: map['isBot'] == true,
      lastSeen: (map['lastSeen'] is int)
          ? map['lastSeen'] as int
          : int.tryParse(map['lastSeen']?.toString() ?? ''),
      isSpeaking: map['isSpeaking'] == true,
      isMuted: map['isMuted'] == true,
      targetVoteId: map['targetVoteId']?.toString(),
      isLover: map['isLover'] == true,
      loverId: map['loverId']?.toString(),
      isCaptain: map['isCaptain'] == true,
      isCharmed: map['isCharmed'] == true,
      isDoused: map['isDoused'] == true,
      isInfected: map['isInfected'] == true,
      isSniffed: map['isSniffed'] == true,
      hasWolfSmell: map['hasWolfSmell'] == true,
      hasUsedHealPotion: map['hasUsedHealPotion'] == true,
      hasUsedPoisonPotion: map['hasUsedPoisonPotion'] == true,
      agoraUid: (map['agoraUid'] is int)
          ? map['agoraUid'] as int
          : int.tryParse(map['agoraUid']?.toString() ?? '0') ?? 0,
      encryptedRole: encryptedRoleToken,
      seatIndex: (map['seatIndex'] is int)
          ? map['seatIndex'] as int
          : int.tryParse(map['seatIndex']?.toString() ?? '-1') ?? -1,
      socketId: map['socketId']?.toString(),
      pv: (map['pv'] is int)
          ? map['pv'] as int
          : int.tryParse(map['pv']?.toString() ?? '100') ?? 100,
      isReadyReplay: isReadyReplayVal,
      wantsRematch: isReadyReplayVal,
      initialRole: initialRole ?? resolvedRole,
      potionsVie: (map['potionsVie'] is int)
          ? map['potionsVie'] as int
          : int.tryParse(map['potionsVie']?.toString() ?? '1') ?? 1,
      potionsMort: (map['potionsMort'] is int)
          ? map['potionsMort'] as int
          : int.tryParse(map['potionsMort']?.toString() ?? '1') ?? 1,
      visionsRestantes: (map['visionsRestantes'] is int)
          ? map['visionsRestantes'] as int
          : int.tryParse(map['visionsRestantes']?.toString() ?? '1') ?? 1,
    );
  }
}
