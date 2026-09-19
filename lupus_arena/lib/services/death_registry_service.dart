import 'package:flutter/foundation.dart';
import '../models/player_model.dart';

/// Service dédié au verrouillage inviolable de la mort (Anti-Résurrection)
/// Règle d'or : "Celui qui meurt meurt".
/// Un joueur enregistré comme défunt ne peut JAMAIS revenir à la vie,
/// que ce soit via un snapshot réseau Firebase, un événement de vote, une reconnexion,
/// ou une désynchronisation locale.
///
/// La seule exception canonique autorisée par le jeu est la potion de vie de la Sorcière
/// (utilisée avant la levée du jour).
class DeathRegistryService {
  DeathRegistryService._internal();
  static final DeathRegistryService _instance = DeathRegistryService._internal();
  static DeathRegistryService get instance => _instance;
  factory DeathRegistryService() => _instance;

  /// Registre en mémoire des identifiants (UIDs) des joueurs éliminés.
  final Set<String> _cemeteryUids = <String>{};

  /// Obtenir une vue immuable des UIDs des défunts
  Set<String> get deadPlayerIds => Set.unmodifiable(_cemeteryUids);

  /// Indique si un joueur est inscrit au registre des morts
  bool isDead(String? playerId) {
    if (playerId == null || playerId.isEmpty) return false;
    return _cemeteryUids.contains(playerId);
  }

  /// Indique si un joueur est vivant selon le registre
  bool isAlive(String? playerId) {
    if (playerId == null || playerId.isEmpty) return false;
    return !_cemeteryUids.contains(playerId);
  }

  /// Enregistre un joueur comme mort de façon irréversible.
  void markDead(String? playerId) {
    if (playerId == null || playerId.isEmpty) return;
    if (_cemeteryUids.add(playerId)) {
      debugPrint('[DeathRegistryService] 💀 Joueur inscrit au cimetière définitif: $playerId');
    }
  }

  /// Enregistre un lot de joueurs défunts
  void markDeadBatch(Iterable<String?> playerIds) {
    for (final id in playerIds) {
      if (id != null && id.isNotEmpty) {
        markDead(id);
      }
    }
  }

  /// Seule et unique porte de sortie du cimetière :
  /// La potion de guérison miraculeuse de la Sorcière.
  void allowWitchRevive(String? victimId) {
    if (victimId == null || victimId.isEmpty) return;
    if (_cemeteryUids.remove(victimId)) {
      debugPrint('[DeathRegistryService] ✨ Potion de la Sorcière : joueur $victimId réanimé du cimetière.');
    }
  }

  /// Réinitialisation complète lors du lancement d'une nouvelle partie ou retour au lobby
  void clearForNewGame() {
    debugPrint('[DeathRegistryService] 🔄 Réinitialisation du registre de mort pour une nouvelle partie.');
    _cemeteryUids.clear();
  }

  /// Forçage de l'état d'un modèle joueur individuel
  PlayerModel enforcePlayer(PlayerModel player) {
    if (isDead(player.id)) {
      if (player.isAlive) {
        debugPrint('[DeathRegistryService] 🛡️ Tentative de résurrection bloquée pour ${player.id} (${player.name})');
        return player.copyWith(isAlive: false);
      }
      return player;
    } else if (!player.isAlive) {
      // Si le modèle est mort mais pas encore dans le registre, on l'inscrit automatiquement
      markDead(player.id);
    }
    return player;
  }

  /// Filtre et applique le verrou de mort sur une collection de joueurs (ex: reçue depuis Firebase)
  Map<String, PlayerModel> filterOrEnforce(Map<String, PlayerModel> players) {
    final Map<String, PlayerModel> enforced = {};
    for (final entry in players.entries) {
      final pid = entry.key;
      final player = entry.value;

      if (isDead(pid)) {
        // Déjà mort dans le registre : doit rester mort
        enforced[pid] = player.isAlive ? player.copyWith(isAlive: false) : player;
      } else if (!player.isAlive) {
        // Appris comme mort depuis les données : inscrire au registre
        markDead(pid);
        enforced[pid] = player;
      } else {
        enforced[pid] = player;
      }
    }
    return enforced;
  }

  /// Synchronise le registre depuis le sous-nœud `cemetery` ou `morningVictims` de Firebase
  void syncFromFirebase(dynamic rawCemetery, [dynamic rawMorningVictims]) {
    if (rawCemetery is Map) {
      rawCemetery.forEach((key, val) {
        if (val == true || val == 1 || val == 'true') {
          markDead(key.toString());
        }
      });
    } else if (rawCemetery is List) {
      for (final id in rawCemetery) {
        if (id != null) markDead(id.toString());
      }
    }

    if (rawMorningVictims is List) {
      for (final id in rawMorningVictims) {
        if (id != null) markDead(id.toString());
      }
    }
  }

  /// Génère les paires clés/valeurs à synchroniser avec Firebase pour garantir l'état de mort
  Map<String, dynamic> generateFirebaseCemeteryUpdates() {
    final updates = <String, dynamic>{};
    for (final pid in _cemeteryUids) {
      updates['players/$pid/isAlive'] = false;
      updates['cemetery/$pid'] = true;
    }
    return updates;
  }
}
