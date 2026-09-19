import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Gestionnaire audio exclusif du Lobby (LobbyAudioManager).
/// Implémente un verrou atomique (_isExplicitlyStopped) empêchant toute résurgence sonore fantôme
/// lors des transitions d'écrans ou des réveils du cycle de vie Android / iOS.
class LobbyAudioManager {
  static final LobbyAudioManager instance = LobbyAudioManager._internal();
  factory LobbyAudioManager() => instance;
  LobbyAudioManager._internal();

  AudioPlayer? _player;
  bool _isExplicitlyStopped = false;
  double _volume = 0.70;
  bool _isMuted = false;

  static const String lobbyMusicAsset = 'audio/son-lupus.mp3';

  bool get isExplicitlyStopped => _isExplicitlyStopped;
  bool get isPlaying => _player?.state == PlayerState.playing;
  bool get isMuted => _isMuted;
  double get volume => _volume;

  Future<void> init() async {
    if (_player == null) {
      final player = AudioPlayer();
      try {
        await player.setAudioContext(
          AudioContext(
            android: const AudioContextAndroid(
              isSpeakerphoneOn: true,
              stayAwake: false,
              contentType: AndroidContentType.music,
              usageType: AndroidUsageType.media,
              audioFocus: AndroidAudioFocus.none,
            ),
            iOS: AudioContextIOS(
              category: AVAudioSessionCategory.ambient,
              options: {
                AVAudioSessionOptions.mixWithOthers,
              },
            ),
          ),
        );
        await player.setReleaseMode(ReleaseMode.loop);
        await player.setVolume(_isMuted ? 0.0 : _volume);
        _player = player;
      } catch (e) {
        debugPrint('[LobbyAudioManager] Configuration AudioPlayer: $e');
        _player = player;
      }
    }
  }

  /// Démarre la lecture de la musique d'ambiance du Lobby en boucle
  Future<void> playLobbyMusic({bool resetPosition = false}) async {
    _isExplicitlyStopped = false;
    await init();

    // Si le moteur audio est déjà en lecture, ne pas re-déclencher
    if (_player != null && _player!.state == PlayerState.playing) return;

    try {
      if (_player != null) {
        await _player!.stop(); // Nettoie tout buffer résiduel
      }
      if (!_isExplicitlyStopped && _player != null) {
        await _player!.setReleaseMode(ReleaseMode.loop);
        await _player!.setVolume(_isMuted ? 0.0 : _volume);
        if (resetPosition) {
          try {
            await _player!.seek(Duration.zero);
          } catch (_) {}
        }
        try {
          await _player!.play(AssetSource(lobbyMusicAsset));
        } catch (e) {
          debugPrint('[LobbyAudioManager] Fallback asset play: $e');
          await _player!.play(AssetSource('assets/audio/son-lupus.mp3'));
        }
        debugPrint('[LobbyAudioManager] 🎵 Musique du lobby lancée en boucle.');
      }
    } catch (e) {
      debugPrint('[LobbyAudioManager] Erreur playLobbyMusic: $e');
    }
  }

  /// Arrêt FORCÉ, SYNCHRONE de l'intention et verrouillé
  Future<void> stopLobbyMusic() async {
    _isExplicitlyStopped = true;
    if (_player != null) {
      try {
        await _player!.stop();
        debugPrint('[LobbyAudioManager] ⏹️ Musique du lobby arrêtée proprement.');
      } catch (e) {
        debugPrint('[LobbyAudioManager] Erreur stopLobbyMusic: $e');
      }
    }
  }

  /// Met en pause temporairement la musique
  Future<void> pauseLobbyMusic() async {
    if (_player != null && _player!.state == PlayerState.playing) {
      try {
        await _player!.pause();
        debugPrint('[LobbyAudioManager] ⏸️ Musique du lobby mise en pause.');
      } catch (e) {
        debugPrint('[LobbyAudioManager] Erreur pauseLobbyMusic: $e');
      }
    }
  }

  /// Reprend la musique UNIQUEMENT si l'arrêt forcé n'a pas été demandé
  Future<void> resumeLobbyMusic() async {
    // Ne reprend JAMAIS si l'arrêt a été explicitement demandé (ex: entrée dans une room / partie)
    if (!_isExplicitlyStopped && _player != null) {
      try {
        await _player!.resume();
        debugPrint('[LobbyAudioManager] ▶️ Musique du lobby reprise.');
      } catch (e) {
        debugPrint('[LobbyAudioManager] Erreur resumeLobbyMusic: $e');
      }
    }
  }

  /// Ajuste le volume sonore (0.0 à 1.0)
  Future<void> setVolume(double newVolume) async {
    _volume = newVolume.clamp(0.0, 1.0);
    if (_player != null && !_isMuted) {
      try {
        await _player!.setVolume(_volume);
      } catch (e) {
        debugPrint('[LobbyAudioManager] Erreur setVolume: $e');
      }
    }
  }

  /// Active ou désactive le mode muet
  Future<void> toggleMute() async {
    _isMuted = !_isMuted;
    if (_player != null) {
      try {
        await _player!.setVolume(_isMuted ? 0.0 : _volume);
      } catch (e) {
        debugPrint('[LobbyAudioManager] Erreur toggleMute: $e');
      }
    }
  }

  /// Libère les ressources
  void dispose() {
    try {
      _isExplicitlyStopped = true;
      _player?.stop();
      _player?.dispose();
      _player = null;
    } catch (e) {
      debugPrint('[LobbyAudioManager] Erreur dispose: $e');
    }
  }
}
