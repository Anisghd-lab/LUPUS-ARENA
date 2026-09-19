import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Gestionnaire audio global (AudioManager) isolé, robuste et non-intrusif.
/// Gère la musique d'ambiance du lobby ("assets/audio/son-lupus.mp3") en boucle infinie,
/// l'arrêt immédiat lors de l'entrée en salle / partie, et la reprise propre au retour au lobby.
class LupusAudioManager {
  static final LupusAudioManager _instance = LupusAudioManager._internal();
  factory LupusAudioManager() => _instance;
  static LupusAudioManager get instance => _instance;

  LupusAudioManager._internal();

  AudioPlayer? _player;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isMuted = false;
  double _volume = 0.70;

  static const String lobbyMusicAsset = 'audio/son-lupus.mp3';

  bool get isPlaying => _isPlaying;
  bool get isMuted => _isMuted;
  bool get isInitialized => _isInitialized;
  double get volume => _volume;

  Future<AudioPlayer> _getOrCreatePlayer() async {
    if (_player == null) {
      final player = AudioPlayer();
      try {
        await player.setAudioContext(
          const AudioContext(
            android: AudioContextAndroid(
              isSpeakerphoneOn: true,
              stayAwake: false,
              contentType: AndroidContentType.music,
              usageType: AndroidUsageType.media,
              audioFocus: AndroidAudioFocus.none,
            ),
            iOS: AudioContextIOS(
              category: AVAudioSessionCategory.ambient,
              options: [
                AVAudioSessionOptions.mixWithOthers,
              ],
            ),
          ),
        );
        await player.setReleaseMode(ReleaseMode.loop);
        await player.setVolume(_isMuted ? 0.0 : _volume);

        player.onPlayerStateChanged.listen((state) {
          _isPlaying = (state == PlayerState.playing);
        });

        _isInitialized = true;
        _player = player;
      } catch (e) {
        debugPrint('[LupusAudioManager] Configuration AudioPlayer: $e');
        _player = player;
        _isInitialized = true;
      }
    }
    return _player!;
  }

  /// Joue la musique d'ambiance du Lobby en boucle infinie
  Future<void> playLobbyMusic({bool resetPosition = false}) async {
    if (_isPlaying) return; // Zéro doublon
    try {
      final player = await _getOrCreatePlayer();
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setVolume(_isMuted ? 0.0 : _volume);
      if (resetPosition) {
        try {
          await player.seek(Duration.zero);
        } catch (_) {}
      }
      try {
        await player.play(AssetSource(lobbyMusicAsset));
      } catch (e) {
        debugPrint('[LupusAudioManager] Fallback play: $e');
        await player.play(AssetSource('assets/audio/son-lupus.mp3'));
      }
      _isPlaying = true;
      debugPrint('[LupusAudioManager] Musique du lobby lancée en boucle.');
    } catch (e) {
      debugPrint('[LupusAudioManager] Erreur lecture musique lobby: $e');
      _isPlaying = false;
    }
  }

  /// Arrête immédiatement et sans latence la musique du lobby lors de l'entrée dans une room
  Future<void> stopLobbyMusic() async {
    if (_player == null || !_isPlaying) return;
    try {
      await _player!.stop();
      _isPlaying = false;
      debugPrint('[LupusAudioManager] Musique du lobby arrêtée.');
    } catch (e) {
      debugPrint('[LupusAudioManager] Erreur arrêt musique lobby: $e');
    }
  }

  /// Met en pause temporairement la musique
  Future<void> pauseLobbyMusic() async {
    if (_player == null || !_isPlaying) return;
    try {
      await _player!.pause();
      _isPlaying = false;
    } catch (e) {
      debugPrint('[LupusAudioManager] Erreur pause: $e');
    }
  }

  /// Ajuste le volume sonore (0.0 à 1.0)
  Future<void> setVolume(double newVolume) async {
    _volume = newVolume.clamp(0.0, 1.0);
    if (_player != null && !_isMuted) {
      try {
        await _player!.setVolume(_volume);
      } catch (e) {
        debugPrint('[LupusAudioManager] Erreur setVolume: $e');
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
        debugPrint('[LupusAudioManager] Erreur toggleMute: $e');
      }
    }
  }

  /// Libère proprement les ressources lors de la fermeture
  void dispose() {
    try {
      _player?.stop();
      _player?.dispose();
      _player = null;
      _isInitialized = false;
      _isPlaying = false;
    } catch (e) {
      debugPrint('[LupusAudioManager] Erreur dispose: $e');
    }
  }
}
