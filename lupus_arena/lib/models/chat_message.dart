class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final int senderAvatar;
  final String content;
  final int timestamp;
  final bool isWolfChat;
  final String? senderRole;
  final String? targetVoteId;
  final String? targetVoteName;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderAvatar = 0,
    required this.content,
    required this.timestamp,
    this.isWolfChat = false,
    this.senderRole,
    this.targetVoteId,
    this.targetVoteName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'content': content,
      'timestamp': timestamp,
      'isWolfChat': isWolfChat,
      'senderRole': senderRole,
      'targetVoteId': targetVoteId,
      'targetVoteName': targetVoteName,
    };
  }

  factory ChatMessage.fromMap(Map<dynamic, dynamic> map, [String? id]) {
    return ChatMessage(
      id: (id ?? map['id'] ?? '').toString(),
      senderId: (map['senderId'] ?? '').toString(),
      senderName: (map['senderName'] ?? 'Anonyme').toString(),
      senderAvatar: (map['senderAvatar'] is int)
          ? map['senderAvatar'] as int
          : int.tryParse(map['senderAvatar']?.toString() ?? '0') ?? 0,
      content: (map['content'] ?? '').toString(),
      timestamp: (map['timestamp'] is int)
          ? map['timestamp'] as int
          : int.tryParse(map['timestamp']?.toString() ?? '0') ?? 0,
      isWolfChat: map['isWolfChat'] == true,
      senderRole: map['senderRole']?.toString(),
      targetVoteId: map['targetVoteId']?.toString(),
      targetVoteName: map['targetVoteName']?.toString(),
    );
  }
}
