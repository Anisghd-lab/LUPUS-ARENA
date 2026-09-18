import 'package:flutter_test/flutter_test.dart';
import 'package:lupus_arena/models/game_room.dart';

void main() {
  group('GameRoom - Déduplication & Robustesse Reconnexion', () {
    test('Dédoublonne un même utilisateur présent sous deux clés différentes', () {
      final rawPlayersMap = {
        'user_123': {
          'id': 'user_123',
          'name': 'Anis',
          'isHost': false,
          'isOnline': false,
          'lastSeen': 1000,
        },
        '-NyPushIdAleatoire': {
          'id': 'user_123',
          'name': '★ Anis',
          'isHost': true,
          'isOnline': true,
          'lastSeen': 2000,
        },
        'user_456': {
          'id': 'user_456',
          'name': 'Zakaria',
          'isHost': false,
          'isOnline': true,
          'lastSeen': 1500,
        }
      };

      final room = GameRoom.fromMap('GHPTA', {
        'code': 'GHPTA',
        'currentPhase': 'lobby',
        'players': rawPlayersMap,
      });

      // Doit contenir strictement 2 joueurs uniques et conserver la session la plus récente / en ligne
      expect(room.players.length, equals(2));
      
      final anis = room.players['user_123'] ?? room.players.values.firstWhere((p) => p.id == 'user_123');
      expect(anis.isOnline, isTrue);
      expect(anis.isHost, isTrue);
    });
  });
}
