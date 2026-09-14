import 'dart:convert';
import 'package:crypto/crypto.dart';

import '../models/game_role.dart';

/// Service de chiffrement et de sécurisation des données de rôles sensibles.
/// Empêche l'interception et l'inspection des rôles secrets des joueurs vivants
/// sur le réseau ou dans les snapshots Firebase Realtime Database.
class RoleSecurityService {
  static const String _globalSalt = 'LupusArena_Secure_2026_Key';

  /// Obscurcit / chiffre un rôle de manière déterministe pour un joueur spécifique
  static String encryptRole(String roleId, String playerId, String roomCode) {
    final keyBytes = sha256
        .convert(utf8.encode('$playerId:$_globalSalt:${roomCode.toUpperCase()}'))
        .bytes;
    final payloadBytes = utf8.encode(roleId);
    final encrypted = List<int>.generate(
      payloadBytes.length,
      (i) => payloadBytes[i] ^ keyBytes[i % keyBytes.length],
    );
    return base64Url.encode(encrypted);
  }

  /// Déchiffre le rôle uniquement si le playerId et le roomCode correspondent
  static GameRole? decryptRole(
    String? encryptedToken,
    String playerId,
    String roomCode,
  ) {
    if (encryptedToken == null || encryptedToken.isEmpty) return null;
    try {
      final keyBytes = sha256
          .convert(utf8.encode('$playerId:$_globalSalt:${roomCode.toUpperCase()}'))
          .bytes;
      final encryptedBytes = base64Url.decode(encryptedToken);
      final decryptedBytes = List<int>.generate(
        encryptedBytes.length,
        (i) => encryptedBytes[i] ^ keyBytes[i % keyBytes.length],
      );
      final decryptedRoleId = utf8.decode(decryptedBytes);
      return GameRole.fromString(decryptedRoleId);
    } catch (_) {
      return null;
    }
  }

  /// Chiffre la liste des IDs des loups pour le canal meute
  static String encryptWolfRoster(List<String> wolfPlayerIds, String roomCode) {
    final keyBytes = sha256
        .convert(utf8.encode('WOLF_PACK:$_globalSalt:${roomCode.toUpperCase()}'))
        .bytes;
    final jsonString = jsonEncode(wolfPlayerIds);
    final payloadBytes = utf8.encode(jsonString);
    final encrypted = List<int>.generate(
      payloadBytes.length,
      (i) => payloadBytes[i] ^ keyBytes[i % keyBytes.length],
    );
    return base64Url.encode(encrypted);
  }

  /// Déchiffre la liste des IDs des loups
  static Set<String> decryptWolfRoster(String? encryptedRoster, String roomCode) {
    if (encryptedRoster == null || encryptedRoster.isEmpty) return {};
    try {
      final keyBytes = sha256
          .convert(utf8.encode('WOLF_PACK:$_globalSalt:${roomCode.toUpperCase()}'))
          .bytes;
      final encryptedBytes = base64Url.decode(encryptedRoster);
      final decryptedBytes = List<int>.generate(
        encryptedBytes.length,
        (i) => encryptedBytes[i] ^ keyBytes[i % keyBytes.length],
      );
      final jsonString = utf8.decode(decryptedBytes);
      final List<dynamic> list = jsonDecode(jsonString);
      return list.map((e) => e.toString()).toSet();
    } catch (_) {
      return {};
    }
  }
}
