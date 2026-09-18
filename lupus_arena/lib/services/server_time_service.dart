import 'dart:async';
import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

/// Service de Synchronisation Temporelle Absolue avec Firebase Realtime Database
/// Utilise le canal système `.info/serverTimeOffset` pour déterminer avec une précision
/// sub-seconde le décalage (clock drift) entre l'horloge locale du terminal et le serveur Firebase.
class ServerTimeService {
  static final ServerTimeService _instance = ServerTimeService._internal();
  factory ServerTimeService() => _instance;
  ServerTimeService._internal();

  int _serverTimeOffsetMs = 0;
  bool _isInitialized = false;
  StreamSubscription<DatabaseEvent>? _offsetSubscription;
  final ValueNotifier<int> offsetNotifier = ValueNotifier<int>(0);

  /// Décalage d'horloge mesuré par Firebase en millisecondes
  int get offsetMs => _serverTimeOffsetMs;

  /// Heure serveur estimée en millisecondes depuis l'Epoch Unix (UTC)
  /// pure fonction : DateTime.now().millisecondsSinceEpoch + serverTimeOffset
  int get currentServerEstimatedTime =>
      DateTime.now().millisecondsSinceEpoch + _serverTimeOffsetMs;

  /// Initialise l'écoute continue du canal .info/serverTimeOffset de Firebase
  void initialize(FirebaseDatabase database) {
    if (_isInitialized) return;
    _isInitialized = true;

    try {
      _offsetSubscription =
          database.ref('.info/serverTimeOffset').onValue.listen((event) {
        final val = event.snapshot.value;
        if (val is num) {
          _serverTimeOffsetMs = val.toInt();
          offsetNotifier.value = _serverTimeOffsetMs;
          debugPrint(
            '[ServerTimeService] Dérive d\'horloge Firebase RTDB synchronisée : ${_serverTimeOffsetMs}ms',
          );
        }
      }, onError: (err) {
        debugPrint('[ServerTimeService] Erreur d\'écoute offset : $err');
      });
    } catch (e) {
      debugPrint('[ServerTimeService] Exception initialisation : $e');
    }
  }

  /// Calcule le temps restant en millisecondes de façon pure :
  /// max(0, phaseEndsAt - currentServerEstimatedTime)
  int calculateRemainingMs(int? phaseEndsAt, {int fallbackDurationMs = 30000}) {
    if (phaseEndsAt == null) {
      return fallbackDurationMs;
    }
    final remaining = phaseEndsAt - currentServerEstimatedTime;
    return max(0, remaining);
  }

  /// Calcule le temps restant en secondes entières de façon pure :
  /// ceil(max(0, phaseEndsAt - currentServerEstimatedTime) / 1000)
  int calculateRemainingSeconds(int? phaseEndsAt, {int fallbackSeconds = 30}) {
    final remMs = calculateRemainingMs(
      phaseEndsAt,
      fallbackDurationMs: fallbackSeconds * 1000,
    );
    return (remMs / 1000.0).ceil();
  }

  /// Flux réactif générant les secondes restantes à chaque tick de 500ms
  /// Garanti sans effet de bord, indépendant de tout rebuild de l'arbre widget.
  Stream<int> streamRemainingSeconds(int? phaseEndsAt, {int fallbackSeconds = 30}) async* {
    int lastValue = calculateRemainingSeconds(phaseEndsAt, fallbackSeconds: fallbackSeconds);
    yield lastValue;

    while (true) {
      await Future.delayed(const Duration(milliseconds: 500));
      final current = calculateRemainingSeconds(phaseEndsAt, fallbackSeconds: fallbackSeconds);
      if (current != lastValue) {
        lastValue = current;
        yield current;
      }
      if (current <= 0) {
        yield 0;
        break;
      }
    }
  }

  void dispose() {
    _offsetSubscription?.cancel();
    _offsetSubscription = null;
    _isInitialized = false;
  }
}
