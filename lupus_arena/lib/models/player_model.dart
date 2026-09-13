import 'game_role.dart';
export 'game_role.dart';

class PlayerModel {
  final String id;
  final String name;
  final int avatarIndex;
  final GameRole role;
  final bool isAlive;
  final bool isHost;
  final bool isReady;
  final bool isSpeaking;
  final bool isMuted;
  final String? targetVoteId;
  final bool isLover;
  final String? loverId;
  final bool isCaptain; // Capitaine / Maire élu (voix double)
  final bool isCharmed; // Envoûté par le Joueur de Flûte
  final bool isDoused; // Aspergé d'huile/essence par le Pyromane
  final bool hasUsedHealPotion;
  final bool hasUsedPoisonPotion;
  final int agoraUid;

  const PlayerModel({
    required this.id,
    required this.name,
    this.avatarIndex = 0,
    this.role = GameRole.simpleVillager,
    this.isAlive = true,
    this.isHost = false,
    this.isReady = false,
    this.isSpeaking = false,
    this.isMuted = false,
    this.targetVoteId,
    this.isLover = false,
    this.loverId,
    this.isCaptain = false,
    this.isCharmed = false,
    this.isDoused = false,
    this.hasUsedHealPotion = false,
    this.hasUsedPoisonPotion = false,
    this.agoraUid = 0,
  });

  PlayerModel copyWith({
    String? id,
    String? name,
    int? avatarIndex,
    GameRole? role,
    bool? isAlive,
    bool? isHost,
    bool? isReady,
    bool? isSpeaking,
    bool? isMuted,
    String? targetVoteId,
    bool? isLover,
    String? loverId,
    bool? isCaptain,
    bool? isCharmed,
    bool? isDoused,
    bool? hasUsedHealPotion,
    bool? hasUsedPoisonPotion,
    int? agoraUid,
  }) {
    return PlayerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarIndex: avatarIndex ?? this.avatarIndex,
      role: role ?? this.role,
      isAlive: isAlive ?? this.isAlive,
      isHost: isHost ?? this.isHost,
      isReady: isReady ?? this.isReady,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      isMuted: isMuted ?? this.isMuted,
      targetVoteId: targetVoteId,
      isLover: isLover ?? this.isLover,
      loverId: loverId ?? this.loverId,
      isCaptain: isCaptain ?? this.isCaptain,
      isCharmed: isCharmed ?? this.isCharmed,
      isDoused: isDoused ?? this.isDoused,
      hasUsedHealPotion: hasUsedHealPotion ?? this.hasUsedHealPotion,
      hasUsedPoisonPotion: hasUsedPoisonPotion ?? this.hasUsedPoisonPotion,
      agoraUid: agoraUid ?? this.agoraUid,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'avatarIndex': avatarIndex,
      'role': role.name,
      'isAlive': isAlive,
      'isHost': isHost,
      'isReady': isReady,
      'isSpeaking': isSpeaking,
      'isMuted': isMuted,
      'targetVoteId': targetVoteId,
      'isLover': isLover,
      'loverId': loverId,
      'isCaptain': isCaptain,
      'isCharmed': isCharmed,
      'isDoused': isDoused,
      'hasUsedHealPotion': hasUsedHealPotion,
      'hasUsedPoisonPotion': hasUsedPoisonPotion,
      'agoraUid': agoraUid,
    };
  }

  factory PlayerModel.fromMap(Map<dynamic, dynamic> map, [String? docId]) {
    return PlayerModel(
      id: (docId ?? map['id'] ?? '').toString(),
      name: (map['name'] ?? 'Inconnu').toString(),
      avatarIndex: (map['avatarIndex'] is int)
          ? map['avatarIndex'] as int
          : int.tryParse(map['avatarIndex']?.toString() ?? '0') ?? 0,
      role: GameRole.fromString(map['role']?.toString()),
      isAlive: map['isAlive'] != false,
      isHost: map['isHost'] == true,
      isReady: map['isReady'] == true,
      isSpeaking: map['isSpeaking'] == true,
      isMuted: map['isMuted'] == true,
      targetVoteId: map['targetVoteId']?.toString(),
      isLover: map['isLover'] == true,
      loverId: map['loverId']?.toString(),
      isCaptain: map['isCaptain'] == true,
      isCharmed: map['isCharmed'] == true,
      isDoused: map['isDoused'] == true,
      hasUsedHealPotion: map['hasUsedHealPotion'] == true,
      hasUsedPoisonPotion: map['hasUsedPoisonPotion'] == true,
      agoraUid: (map['agoraUid'] is int)
          ? map['agoraUid'] as int
          : int.tryParse(map['agoraUid']?.toString() ?? '0') ?? 0,
    );
  }
}
