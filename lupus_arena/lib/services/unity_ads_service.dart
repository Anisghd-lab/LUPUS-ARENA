import 'package:flutter/foundation.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';

/// Service singleton pour la monétisation Unity Ads de Lupus Arena.
/// Configuré pour diffuser strictement une seule publicité interstitielle
/// au lancement/lobby, sans perturber l'expérience de jeu par la suite.
class UnityAdsService {
  static const String gameIdAndroid = '800370259';
  static const String interstitialPlacement = 'Interstitial_Android';

  static bool _isInitialized = false;
  static bool _hasShownStartupAd = false;
  static bool _isAdReady = false;
  static bool _requestedToShow = false;

  /// Initialise Unity Ads (uniquement sur mobile natif Android/iOS, ignoré sur Web)
  static Future<void> initialize({bool testMode = true}) async {
    if (kIsWeb) {
      debugPrint('[Unity Ads] Plateforme Web détectée : Unity Ads désactivé.');
      return;
    }

    try {
      await UnityAds.init(
        gameId: gameIdAndroid,
        testMode: testMode, // true en développement, false pour la release
        onComplete: () {
          _isInitialized = true;
          debugPrint('[Unity Ads] Initialisé avec succès.');
          _loadInterstitial();
        },
        onFailed: (error, message) {
          debugPrint('[Unity Ads] Erreur initialisation: $error - $message');
        },
      );
    } catch (e) {
      debugPrint('[Unity Ads] Exception lors de l\'initialisation: $e');
    }
  }

  /// Précharge l'interstitiel
  static void _loadInterstitial() {
    if (!_isInitialized || kIsWeb) return;

    UnityAds.load(
      placementId: interstitialPlacement,
      onComplete: (placementId) {
        debugPrint('[Unity Ads] Publicité d\'entrée prête : $placementId');
        _isAdReady = true;
        // Si l'écran d'accueil attendait déjà la pub, on la lance immédiatement
        if (_requestedToShow && !_hasShownStartupAd) {
          _displayAd();
        }
      },
      onFailed: (placementId, error, message) {
        debugPrint('[Unity Ads] Échec du chargement pub: $message');
      },
    );
  }

  /// Demande l'affichage de l'interstitiel à l'entrée (1 seule fois)
  static void showStartupAdOnce() {
    if (kIsWeb || _hasShownStartupAd) return;

    _requestedToShow = true;

    if (_isAdReady) {
      _displayAd();
    } else {
      debugPrint('[Unity Ads] Annonce en cours de buffer, affichage dès réception...');
    }
  }

  static void _displayAd() {
    if (_hasShownStartupAd) return;
    _hasShownStartupAd = true;

    UnityAds.showVideoAd(
      placementId: interstitialPlacement,
      onComplete: (placementId) =>
          debugPrint('[Unity Ads] Pub de bienvenue terminée.'),
      onFailed: (placementId, error, message) =>
          debugPrint('[Unity Ads] Échec de diffusion pub: $message'),
      onSkipped: (placementId) =>
          debugPrint('[Unity Ads] Pub passée par le joueur.'),
    );
  }
}
