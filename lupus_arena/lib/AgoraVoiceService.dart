// ignore_for_file: file_names

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import 'services/lupus_permission_service.dart';

/// Service gérant les communications vocales temps-réel via Agora RTC.
/// Contrôle l'état du micro, le mode sourdine, les permissions et la détection
/// des joueurs en train de parler pour animer l'interface Bento.
class AgoraVoiceService {
  static final AgoraVoiceService _instance = AgoraVoiceService._internal();
  factory AgoraVoiceService() => _instance;
  AgoraVoiceService._internal() {
    LupusPermissionService.onPermissionsRefreshed = refreshAndRecover;
  }

  RtcEngine? _engine;
  bool _isInitialized = false;

  // Notifiers pour l'UI réactive
  final ValueNotifier<bool> isConnected = ValueNotifier(false);
  final ValueNotifier<bool> isMuted = ValueNotifier(false);
  final ValueNotifier<bool> isDeafened = ValueNotifier(false);
  final ValueNotifier<Set<int>> speakingUids = ValueNotifier({});
  final ValueNotifier<String?> currentChannel = ValueNotifier(null);
  final ValueNotifier<int> localUid = ValueNotifier(0);
  final ValueNotifier<Set<int>> remoteUids = ValueNotifier({});
  final ValueNotifier<Map<int, int>> userVolumes = ValueNotifier({});
  final ValueNotifier<List<String>> diagnosticLogs = ValueNotifier([]);
  final ValueNotifier<ConnectionStateType> connectionState =
      ValueNotifier(ConnectionStateType.connectionStateDisconnected);
  final ValueNotifier<String?> lastErrorMessage = ValueNotifier(null);
  final ValueNotifier<String?> connectionError = ValueNotifier(null);

  // Machine d'état anti-boucle de reconnexion
  bool _isConnecting = false;
  bool get isConnecting => _isConnecting;
  bool _hasFailed = false;
  String? _targetChannelId;
  String? _failedChannelId;
  DateTime? _lastFailureTime;

  String? _lastChannelId;
  int? _lastUid;
  bool _lastInitialMute = false;

  // Mutex et file d'attente pour sérialiser switchChannel et éviter les conflits Agora
  bool _isSwitching = false;
  bool get isSwitching => _isSwitching;
  String? _pendingSwitchChannelId;
  int? _pendingSwitchUid;
  String? _pendingSwitchUserAccount;
  String? _pendingSwitchToken;
  bool _pendingSwitchInitialMute = false;

  RtcEngine? get engine => _engine;
  bool get isInitialized => _isInitialized;

  void addLog(String message) {
    final time = DateTime.now().toIso8601String().substring(11, 19);
    final entry = '[$time] $message';
    debugPrint('[AgoraVoiceService] $entry');
    final updated = List<String>.from(diagnosticLogs.value)..insert(0, entry);
    if (updated.length > 150) updated.removeLast();
    diagnosticLogs.value = updated;
  }

  void clearLogs() {
    diagnosticLogs.value = [];
  }

  // Configuration Agora RTC (Injectable via --dart-define ou repli par défaut)
  static const String defaultAppId = String.fromEnvironment(
    'AGORA_APP_ID',
    defaultValue: 'fba9116dce4648a8966952d7f4eba209',
  );
  static const String appCertificate = String.fromEnvironment(
    'AGORA_APP_CERTIFICATE',
    defaultValue: '9263c2350773468991e500b63e61d6e1',
  );

  /// Initialise le moteur Agora RTC avec gestion des permissions microphone
  Future<bool> initialize({String appId = defaultAppId}) async {
    if (_isInitialized && _engine != null) {
      addLog('Moteur déjà initialisé.');
      return true;
    }

    try {
      addLog('Vérification des autorisations microphone...');
      final hasMicPermission = await LupusPermissionService()
          .ensureMicrophonePermission();
      if (!hasMicPermission) {
        addLog('⚠️ Attention : Permission microphone non accordée.');
      } else {
        addLog('🎤 Permission microphone confirmée.');
      }

      addLog('Création du moteur Agora RTC...');
      _engine = createAgoraRtcEngine();
      final effectiveAppId = appId.isEmpty ? 'MOCK_AGORA_APP_ID' : appId;
      await _engine!.initialize(
        RtcEngineContext(
          appId: effectiveAppId,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          audioScenario: AudioScenarioType.audioScenarioGameStreaming,
        ),
      );
      addLog('Moteur initialisé (AppID: ${effectiveAppId.length > 6 ? effectiveAppId.substring(0, 6) : effectiveAppId}***)');

      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            final uid = connection.localUid ?? 0;
            final ch = connection.channelId ?? '';
            _isConnecting = false;
            _hasFailed = false;
            _failedChannelId = null;
            connectionError.value = null;
            isConnected.value = true;
            currentChannel.value = ch;
            localUid.value = uid;
            connectionState.value = ConnectionStateType.connectionStateConnected;
            lastErrorMessage.value = null;
            addLog('✅ Connecté avec succès au salon "$ch" (UID: $uid, délai: ${elapsed}ms)');
          },
          onLeaveChannel: (RtcConnection connection, RtcStats stats) {
            _isConnecting = false;
            isConnected.value = false;
            currentChannel.value = null;
            speakingUids.value = {};
            remoteUids.value = {};
            userVolumes.value = {};
            connectionState.value = ConnectionStateType.connectionStateDisconnected;
            addLog('🚪 Quitté le salon (Durée: ${stats.duration ?? 0}s, Packets perdus: ${stats.rxPacketLossRate ?? 0}%)');
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            final updated = Set<int>.from(remoteUids.value)..add(remoteUid);
            remoteUids.value = updated;
            addLog('👤 Utilisateur distant connecté: UID $remoteUid (${elapsed}ms)');
          },
          onUserOffline:
              (
                RtcConnection connection,
                int remoteUid,
                UserOfflineReasonType reason,
              ) {
                final updatedRemotes = Set<int>.from(remoteUids.value)..remove(remoteUid);
                remoteUids.value = updatedRemotes;
                final updatedSpeaking = Set<int>.from(speakingUids.value)
                  ..remove(remoteUid);
                speakingUids.value = updatedSpeaking;
                final updatedVols = Map<int, int>.from(userVolumes.value)..remove(remoteUid);
                userVolumes.value = updatedVols;
                addLog('👋 Utilisateur distant déconnecté: UID $remoteUid (Raison: ${reason.name})');
              },
          onConnectionStateChanged: (
            RtcConnection connection,
            ConnectionStateType state,
            ConnectionChangedReasonType reason,
          ) {
            connectionState.value = state;
            addLog('📶 Statut réseau: ${state.name} (${reason.name})');
            if (reason == ConnectionChangedReasonType.connectionChangedInvalidToken ||
                reason == ConnectionChangedReasonType.connectionChangedTokenExpired) {
              lastErrorMessage.value = 'Jeton Agora invalide ou expiré';
              connectionError.value = 'Jeton Agora invalide ou expiré';
            } else if (state == ConnectionStateType.connectionStateFailed) {
              lastErrorMessage.value = 'Échec de connexion Agora (${reason.name})';
              connectionError.value = 'Échec de connexion Agora (${reason.name})';
              _isConnecting = false;
              _hasFailed = true;
              _failedChannelId = _targetChannelId;
              _lastFailureTime = DateTime.now();
            } else if (state == ConnectionStateType.connectionStateConnected) {
              lastErrorMessage.value = null;
              connectionError.value = null;
              _isConnecting = false;
              _hasFailed = false;
              _failedChannelId = null;
            }
          },
          onAudioVolumeIndication:
              (
                RtcConnection connection,
                List<AudioVolumeInfo> speakers,
                int totalVolume,
                int speakerNumber,
              ) {
                final volMap = <int, int>{};
                final active = <int>{};
                for (final speaker in speakers) {
                  final uid = speaker.uid ?? 0;
                  final vol = speaker.volume ?? 0;
                  volMap[uid] = vol;
                  if (vol > 5) {
                    active.add(uid);
                  }
                }
                userVolumes.value = volMap;
                // Isole strictement les mises à jour : ne notifie QUE si la liste a réellement changé
                if (!setEquals(speakingUids.value, active)) {
                  speakingUids.value = active;
                }
              },
          onTokenPrivilegeWillExpire: (RtcConnection connection, String token) {
            addLog('⏳ Jeton RTC bientôt expiré, renouvellement...');
            final channelName =
                connection.channelId ?? currentChannel.value ?? '';
            final uid = connection.localUid ?? 0;
            if (channelName.isNotEmpty && appCertificate.isNotEmpty) {
              final newToken = AgoraTokenBuilder.build(
                appId: defaultAppId,
                appCertificate: appCertificate,
                channelName: channelName,
                uid: uid,
              );
              _engine?.renewToken(newToken);
            }
          },
          onError: (ErrorCodeType err, String msg) {
            final errorText = 'Erreur Agora ($err): $msg';
            addLog('❌ $errorText');
            lastErrorMessage.value = errorText;
            connectionError.value = errorText;
            _isConnecting = false;
            _hasFailed = true;
            _failedChannelId = _targetChannelId;
            _lastFailureTime = DateTime.now();
          },
        ),
      );

      await _engine!.enableAudio();
      await _engine!.setDefaultAudioRouteToSpeakerphone(true);
      await _engine!.setAudioProfile(
        profile: AudioProfileType.audioProfileSpeechStandard,
        scenario: AudioScenarioType.audioScenarioGameStreaming,
      );
      await _engine!.enableAudioVolumeIndication(
        interval: 250,
        smooth: 3,
        reportVad: true,
      );
      addLog('Module audio activé avec monitoring de volume.');

      _isInitialized = true;
      return true;
    } catch (e, stack) {
      addLog('❌ Exception initialisation Agora: $e');
      connectionError.value = 'Erreur initialisation Agora: $e';
      debugPrint(
        '[AgoraVoiceService] Erreur lors de l\'initialisation: $e\n$stack',
      );
      return false;
    }
  }

  /// Calcule un UID 32-bit entier positif déterministe et stable à partir de l'identifiant utilisateur unique
  static int deriveUid(String userId) {
    final hash = userId.hashCode.abs() % 100000000;
    return hash == 0 ? 1 : hash;
  }

  /// Rejoindre un canal vocal de jeu (UID int ou String userAccount) avec anti-boucle et purge des sessions fantômes
  Future<bool> joinChannel({
    required String channelId,
    int? uid,
    String? userAccount,
    String? token,
    bool initialMute = false,
  }) async {
    // Calcul ou résolution de l'UID 32-bit stable dérivé du userId
    int effectiveUid = (uid != null && uid > 0) ? uid : 0;
    if (effectiveUid <= 0 && userAccount != null && userAccount.isNotEmpty) {
      effectiveUid = deriveUid(userAccount);
    }

    // 1. Éviter toute reconnexion si déjà connecté sur ce salon précis avec le même UID
    if (isConnected.value && currentChannel.value == channelId && (localUid.value == effectiveUid || effectiveUid == 0)) {
      return true;
    }

    // 2. Éviter les tentatives concurrentes vers le même canal
    if (_isConnecting && _targetChannelId == channelId) {
      return false;
    }

    // 3. Temporisation anti-flood : si ce canal a échoué il y a moins de 8 secondes, ne pas boucler
    if (_failedChannelId == channelId && _hasFailed && _lastFailureTime != null) {
      final elapsed = DateTime.now().difference(_lastFailureTime!);
      if (elapsed.inSeconds < 8) {
        debugPrint('[AgoraVoiceService] Canal $channelId en attente après échec (${elapsed.inSeconds}s)');
        return false;
      }
    }

    // 4. PURGE DES SESSIONS FANTÔMES :
    // Vérifier si un canal est actif avant de forcer leaveChannel()
    try {
      if (currentChannel.value != null || isConnected.value) {
        addLog('Purge préalable d\'une session Agora active/fantôme (${currentChannel.value ?? "antérieure"})...');
        await _engine?.leaveChannel();
        isConnected.value = false;
        currentChannel.value = null;
        speakingUids.value = {};
        remoteUids.value = {};
        userVolumes.value = {};
        connectionState.value = ConnectionStateType.connectionStateDisconnected;
        await Future.delayed(const Duration(milliseconds: 80));
      }
    } catch (e) {
      debugPrint('[AgoraVoiceService] Exception lors du leaveChannel préalable: $e');
    }

    _lastChannelId = channelId;
    _lastUid = effectiveUid;
    _lastInitialMute = initialMute;
    lastErrorMessage.value = null;

    if (_engine == null) {
      final ok = await initialize();
      if (!ok || _engine == null) {
        _hasFailed = true;
        _failedChannelId = channelId;
        _lastFailureTime = DateTime.now();
        connectionError.value = 'Moteur Agora non disponible';
        return false;
      }
    }

    _isConnecting = true;
    _targetChannelId = channelId;
    connectionError.value = null;

    try {
      addLog('Tentative de connexion au canal "$channelId" (UID: $effectiveUid)...');
      final effectiveToken =
          token ??
          (appCertificate.isNotEmpty
              ? AgoraTokenBuilder.build(
                  appId: defaultAppId,
                  appCertificate: appCertificate,
                  channelName: channelId,
                  uid: effectiveUid,
                )
              : '');

      isMuted.value = initialMute;
      await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

      const options = ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileCommunication,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        publishMicrophoneTrack: true,
        autoSubscribeAudio: true,
      );

      if (effectiveUid > 0) {
        debugPrint('[AgoraVoiceService] Appel joinChannel: UID $effectiveUid -> $channelId');
        await _engine!.joinChannel(
          token: effectiveToken,
          channelId: channelId,
          uid: effectiveUid,
          options: options,
        );
      } else if (userAccount != null && userAccount.isNotEmpty) {
        debugPrint('[AgoraVoiceService] Appel joinChannelWithUserAccount: $userAccount -> $channelId');
        await _engine!.joinChannelWithUserAccount(
          token: effectiveToken,
          channelId: channelId,
          userAccount: userAccount,
          options: options,
        );
      } else {
        final safeUid = (uid != null && uid > 0) ? uid : 0;
        debugPrint('[AgoraVoiceService] Appel joinChannel: UID $safeUid -> $channelId');
        await _engine!.joinChannel(
          token: effectiveToken,
          channelId: channelId,
          uid: safeUid,
          options: options,
        );
      }

      await _engine?.muteLocalAudioStream(initialMute);
      return true;
    } catch (e) {
      final err = 'Erreur joinChannel: $e';
      addLog('❌ $err');
      _isConnecting = false;
      _hasFailed = true;
      _failedChannelId = channelId;
      _lastFailureTime = DateTime.now();
      connectionError.value = err;
      lastErrorMessage.value = err;
      debugPrint('[AgoraVoiceService] Impossible de rejoindre le canal: $e');
      return false;
    }
  }

  /// Relance manuelle de la connexion vocale au salon actuel
  Future<void> retryJoin() async {
    if (_lastChannelId != null && _lastUid != null) {
      addLog('🔄 Relance manuelle de la connexion vocale...');
      await joinChannel(
        channelId: _lastChannelId!,
        uid: _lastUid!,
        initialMute: _lastInitialMute,
      );
    }
  }

  /// Rafraîchit les autorisations en arrière-plan et répare/réarme le moteur Agora
  Future<void> refreshAndRecover() async {
    try {
      final isMicOk = await LupusPermissionService().isMicGranted();
      if (isMicOk) {
        if (!_isInitialized || _engine == null) {
          addLog('🎤 Permission micro confirmée en arrière-plan -> Initialisation du moteur Agora...');
          await initialize();
        } else {
          try {
            await _engine?.enableAudio();
            await _engine?.enableLocalAudio(true);
            await _engine?.muteLocalAudioStream(isMuted.value);
          } catch (_) {}
        }

        // Si une connexion précédente avait échoué, réinitialiser l'état d'échec
        if (_hasFailed) {
          _hasFailed = false;
          _failedChannelId = null;
          connectionError.value = null;
          lastErrorMessage.value = null;
        }

        // Si nous avons un canal cible mais que nous sommes déconnectés
        if (_lastChannelId != null && !isConnected.value && !_isConnecting) {
          addLog('🔄 Reconnexion automatique au canal vocal $_lastChannelId...');
          await retryJoin();
        }
      }
    } catch (e) {
      debugPrint('[AgoraVoiceService] Erreur refreshAndRecover: $e');
    }
  }

  /// Bascule propre et cadencée vers un autre canal avec mutex de concurrence
  Future<void> switchChannel({
    required String newChannelId,
    int? uid,
    String? userAccount,
    String? token,
    bool initialMute = false,
  }) async {
    if (currentChannel.value == newChannelId && isConnected.value) return;
    if (_isConnecting && _targetChannelId == newChannelId) return;
    if (_failedChannelId == newChannelId && _hasFailed && _lastFailureTime != null) {
      if (DateTime.now().difference(_lastFailureTime!).inSeconds < 8) return;
    }

    if (_isSwitching) {
      debugPrint('[AgoraVoiceService] switchChannel déjà en cours. Mise en attente de la cible: $newChannelId');
      _pendingSwitchChannelId = newChannelId;
      _pendingSwitchUid = uid;
      _pendingSwitchUserAccount = userAccount;
      _pendingSwitchToken = token;
      _pendingSwitchInitialMute = initialMute;
      return;
    }

    _isSwitching = true;
    try {
      addLog('🔄 Bascule vers le canal "$newChannelId"...');
      debugPrint(
        '[AgoraVoiceService] Bascule vocale : ${currentChannel.value} -> $newChannelId (initialMute: $initialMute)',
      );

      if (currentChannel.value != null || isConnected.value) {
        await leaveChannel();
        await Future.delayed(const Duration(milliseconds: 150));
      }

      await joinChannel(
        channelId: newChannelId,
        uid: uid,
        userAccount: userAccount,
        token: token,
        initialMute: initialMute,
      );
    } finally {
      _isSwitching = false;
      if (_pendingSwitchChannelId != null) {
        final nextTarget = _pendingSwitchChannelId!;
        final nextUid = _pendingSwitchUid;
        final nextAccount = _pendingSwitchUserAccount;
        final nextToken = _pendingSwitchToken;
        final nextMute = _pendingSwitchInitialMute;
        _pendingSwitchChannelId = null;
        _pendingSwitchUid = null;
        _pendingSwitchUserAccount = null;
        _pendingSwitchToken = null;
        if (nextTarget != currentChannel.value || !isConnected.value) {
          Future.microtask(() => switchChannel(
                newChannelId: nextTarget,
                uid: nextUid,
                userAccount: nextAccount,
                token: nextToken,
                initialMute: nextMute,
              ));
        }
      }
    }
  }

  Future<void> toggleMute() async {
    final nextState = !isMuted.value;
    await setMute(nextState);
  }

  Future<void> setMute(bool mute) async {
    try {
      await _engine?.muteLocalAudioStream(mute);
      isMuted.value = mute;
      addLog(mute ? '🔇 Micro coupé (Mute)' : '🎙️ Micro ouvert (Unmute)');
    } catch (e) {
      addLog('❌ Erreur setMute: $e');
      debugPrint('[AgoraVoiceService] Erreur setMute: $e');
    }
  }

  /// Active ou coupe le microphone local
  Future<void> muteMicrophone(bool mute) async => setMute(mute);

  /// Réactive immédiatement le microphone local
  Future<void> unmuteMicrophone() async => setMute(false);

  /// Coupe ou réactive la réception audio distante (Haut-parleur)
  Future<void> muteSpeaker(bool mute) async {
    try {
      await _engine?.muteAllRemoteAudioStreams(mute);
      isDeafened.value = mute;
      addLog(mute ? '🔕 Haut-parleur coupé (Mute Speaker)' : '🔔 Haut-parleur rétabli (Undeafen)');
    } catch (e) {
      addLog('❌ Erreur muteSpeaker: $e');
      debugPrint('[AgoraVoiceService] Erreur muteSpeaker: $e');
    }
  }

  Future<void> toggleDeafen() async {
    final nextState = !isDeafened.value;
    try {
      await _engine?.muteAllRemoteAudioStreams(nextState);
      isDeafened.value = nextState;
      addLog(nextState ? '🔕 Sourdine activée (Deafen)' : '🔔 Audio rétabli (Undeafen)');
    } catch (e) {
      addLog('❌ Erreur toggleDeafen: $e');
      debugPrint('[AgoraVoiceService] Erreur toggleDeafen: $e');
    }
  }

  Future<void> setEchoTest(bool enable) async {
    addLog(enable
        ? 'ℹ️ Mode vocal direct actif.'
        : '🛑 Test d\'écho inactif.');
  }

  Future<void> enforceGameVoiceRules({
    required bool isAlive,
    required bool canSpeakInCurrentPhase,
  }) async {
    if (!isAlive || !canSpeakInCurrentPhase) {
      await setMute(true);
    } else {
      await setMute(false);
    }
  }

  Future<void> leaveChannel() async {
    try {
      addLog('Déconnexion du canal en cours...');
      _isConnecting = false;
      await _engine?.leaveChannel();
      isConnected.value = false;
      currentChannel.value = null;
      speakingUids.value = {};
      remoteUids.value = {};
      userVolumes.value = {};
      connectionState.value = ConnectionStateType.connectionStateDisconnected;
    } catch (e) {
      addLog('❌ Erreur leaveChannel: $e');
      debugPrint('[AgoraVoiceService] Erreur leaveChannel: $e');
    }
  }

  Future<void> dispose() async {
    try {
      await leaveChannel();
      await _engine?.release();
      _engine = null;
      _isInitialized = false;
    } catch (e) {
      debugPrint('[AgoraVoiceService] Erreur dispose: $e');
    }
  }
}

/// Générateur de jeton RTC Agora (Format 006 HMAC-SHA256)
class AgoraTokenBuilder {
  static const int kJoinChannel = 1;
  static const int kPublishAudioStream = 2;
  static const int kPublishVideoStream = 3;
  static const int kPublishDataStream = 4;

  static String build({
    required String appId,
    required String appCertificate,
    required String channelName,
    required int uid,
    int expireSeconds = 86400,
  }) {
    if (appCertificate.isEmpty || appId.isEmpty) return '';

    final uidStr = uid == 0 ? '' : uid.toString();
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final expireTimestamp = nowSec + expireSeconds;
    final salt = Random().nextInt(0x7FFFFFFF);

    final messages = <int, int>{
      kJoinChannel: expireTimestamp,
      kPublishAudioStream: expireTimestamp,
      kPublishVideoStream: expireTimestamp,
      kPublishDataStream: expireTimestamp,
    };

    final mBytes = <int>[
      ..._packUint32(salt),
      ..._packUint32(expireTimestamp),
      ..._packMapUint32(messages),
    ];

    final toSign = <int>[
      ...utf8.encode(appId),
      ...utf8.encode(channelName),
      ...utf8.encode(uidStr),
      ...mBytes,
    ];

    final signature = Hmac(
      sha256,
      utf8.encode(appCertificate),
    ).convert(toSign).bytes;
    final crcChannel = _crc32(utf8.encode(channelName));
    final crcUid = _crc32(utf8.encode(uidStr));

    final content = <int>[
      ..._packBytes(signature),
      ..._packUint32(crcChannel),
      ..._packUint32(crcUid),
      ..._packBytes(mBytes),
    ];

    return '006$appId${base64Encode(content)}';
  }

  static Uint8List _packUint16(int val) {
    final bd = ByteData(2)..setUint16(0, val, Endian.little);
    return bd.buffer.asUint8List();
  }

  static Uint8List _packUint32(int val) {
    final bd = ByteData(4)..setUint32(0, val, Endian.little);
    return bd.buffer.asUint8List();
  }

  static List<int> _packBytes(List<int> bytes) {
    return [..._packUint16(bytes.length), ...bytes];
  }

  static List<int> _packMapUint32(Map<int, int> map) {
    final result = <int>[..._packUint16(map.length)];
    for (final entry in map.entries) {
      result.addAll(_packUint16(entry.key));
      result.addAll(_packUint32(entry.value));
    }
    return result;
  }

  static int _crc32(List<int> bytes) {
    int crc = 0xFFFFFFFF;
    for (final byte in bytes) {
      crc ^= byte;
      for (int j = 0; j < 8; j++) {
        if ((crc & 1) != 0) {
          crc = (crc >> 1) ^ 0xEDB88320;
        } else {
          crc >>= 1;
        }
      }
    }
    return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
  }
}
