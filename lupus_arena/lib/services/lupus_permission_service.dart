import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service gérant les autorisations système requises par Lupus Arena :
/// 1. Microphone (Agora RTC Voice Chat)
/// 2. Baffles / Enceintes / Bluetooth Audio (BLUETOOTH_CONNECT)
/// 3. Notifications de jeu (POST_NOTIFICATIONS)
///
/// Intègre un rafraîchisseur en arrière-plan et un observateur de cycle de vie (AppLifecycleState)
/// pour détecter immédiatement les changements d'autorisations (ex: après mise à jour in-app,
/// retour depuis les Paramètres Android ou bascule d'application) sans forcer l'utilisateur à
/// redémarrer l'application.
class LupusPermissionService with WidgetsBindingObserver {
  static final LupusPermissionService _instance =
      LupusPermissionService._internal();
  factory LupusPermissionService() => _instance;
  LupusPermissionService._internal();

  static const String _keyPermissionsRequested =
      'lupus_permissions_requested_once';
  static const String _keyMicGranted = 'lupus_permission_mic_granted';
  static const String _keyNotificationGranted =
      'lupus_permission_notification_granted';
  static const String _keyBluetoothGranted =
      'lupus_permission_bluetooth_granted';
  static const String _keyLastRequested = 'lupus_permissions_timestamp';

  // Notifiers d'état réactifs en arrière-plan
  final ValueNotifier<bool> isMicGrantedNotifier = ValueNotifier(false);
  final ValueNotifier<bool> isNotificationGrantedNotifier = ValueNotifier(false);
  final ValueNotifier<bool> isBluetoothGrantedNotifier = ValueNotifier(false);

  // Hook de rappel global pour la synchronisation Agora RTC
  static void Function()? onPermissionsRefreshed;

  Timer? _backgroundTimer;
  bool _isMonitoring = false;

  /// Démarre le moniteur et rafraîchisseur d'autorisations en arrière-plan
  void startBackgroundPermissionMonitor() {
    if (_isMonitoring) return;
    _isMonitoring = true;

    try {
      WidgetsBinding.instance.addObserver(this);
    } catch (e) {
      debugPrint('[LupusPermissionService] Erreur ajout observateur: $e');
    }

    // Premier rafraîchissement silencieux immédiat
    refreshPermissionsSilently();

    // Rafraîchissement périodique non-intrusif toutes les 15 secondes
    _backgroundTimer?.cancel();
    _backgroundTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      refreshPermissionsSilently();
    });

    debugPrint('[LupusPermissionService] Moniteur de permissions en arrière-plan démarré.');
  }

  /// Arrête le moniteur d'arrière-plan
  void stopBackgroundPermissionMonitor() {
    _isMonitoring = false;
    _backgroundTimer?.cancel();
    _backgroundTimer = null;
    try {
      WidgetsBinding.instance.removeObserver(this);
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('[LupusPermissionService] Application reprise (resumed) -> Rafraîchissement des autorisations...');
      refreshPermissionsSilently();
    }
  }

  /// Liste des permissions requises selon la plateforme (Web vs Mobile/Desktop)
  static List<Permission> get requiredPermissions {
    if (kIsWeb) {
      // Sur le Web, BluetoothConnect n'existe pas dans l'API W3C Permissions
      return const [
        Permission.microphone,
        Permission.notification,
      ];
    }
    return const [
      Permission.microphone,
      Permission.notification,
      Permission.bluetoothConnect,
    ];
  }

  /// Vérifie si l'application a déjà sollicité les autorisations au moins une fois
  Future<bool> hasRequestedPermissions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyPermissionsRequested) ?? false;
    } catch (e) {
      debugPrint('[LupusPermissionService] Erreur lecture SharedPreferences: $e');
      return false;
    }
  }

  /// Sollicite toutes les permissions nécessaires UNE SEULE FOIS.
  /// Si elles ont déjà été demandées, vérifie silencieusement les statuts
  /// sans réafficher de dialogues système intempestifs.
  Future<Map<Permission, PermissionStatus>> requestAllPermissionsOnce({
    bool force = false,
  }) async {
    final alreadyRequested = await hasRequestedPermissions();

    if (alreadyRequested && !force) {
      debugPrint(
        '[LupusPermissionService] Permissions déjà demandées précédemment. '
        'Synchronisation silencieuse sans ré-interpeller l\'utilisateur.',
      );
      return await refreshPermissionsSilently();
    }

    debugPrint('[LupusPermissionService] Première demande groupée des permissions...');
    final Map<Permission, PermissionStatus> statuses = {};
    try {
      // Demande individuelle sécurisée pour tolérer les spécificités de chaque plateforme/navigateur
      for (final perm in requiredPermissions) {
        try {
          final status = await perm.request();
          statuses[perm] = status;
        } catch (e) {
          debugPrint('[LupusPermissionService] Permission non gérée ou ignorée pour $perm: $e');
          statuses[perm] = PermissionStatus.denied;
        }
      }

      // Sauvegarde des choix dans SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyPermissionsRequested, true);

      final micGranted = statuses[Permission.microphone]?.isGranted ?? false;
      final notifGranted = statuses[Permission.notification]?.isGranted ?? false;
      final btGranted = kIsWeb
          ? true
          : (statuses[Permission.bluetoothConnect]?.isGranted ?? false);

      await prefs.setBool(_keyMicGranted, micGranted);
      await prefs.setBool(_keyNotificationGranted, notifGranted);
      await prefs.setBool(_keyBluetoothGranted, btGranted);
      await prefs.setString(
        _keyLastRequested,
        DateTime.now().toIso8601String(),
      );

      isMicGrantedNotifier.value = micGranted;
      isNotificationGrantedNotifier.value = notifGranted;
      isBluetoothGrantedNotifier.value = btGranted;

      onPermissionsRefreshed?.call();

      debugPrint(
        '[LupusPermissionService] Choix sauvegardés avec succès -> '
        'Micro: $micGranted, Notif: $notifGranted, Bluetooth/Baffles: $btGranted',
      );
    } catch (e) {
      debugPrint('[LupusPermissionService] Erreur lors de la demande: $e');
    }

    return statuses;
  }

  /// Synchronise et rafraîchit en arrière-plan les statuts réels actuels auprès de l'OS
  /// sans jamais bloquer l'UI ni afficher de boîte de dialogue intrusive.
  Future<Map<Permission, PermissionStatus>> refreshPermissionsSilently() async {
    final statuses = <Permission, PermissionStatus>{};
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final permission in requiredPermissions) {
        try {
          final status = await permission.status;
          statuses[permission] = status;
        } catch (_) {
          statuses[permission] = PermissionStatus.denied;
        }
      }

      final micGranted = statuses[Permission.microphone]?.isGranted ?? false;
      final notifGranted = statuses[Permission.notification]?.isGranted ?? false;
      final btGranted = kIsWeb
          ? true
          : (statuses[Permission.bluetoothConnect]?.isGranted ?? false);

      await prefs.setBool(_keyMicGranted, micGranted);
      await prefs.setBool(_keyNotificationGranted, notifGranted);
      if (!kIsWeb) {
        await prefs.setBool(_keyBluetoothGranted, btGranted);
      }

      final bool micChanged = isMicGrantedNotifier.value != micGranted;
      isMicGrantedNotifier.value = micGranted;
      isNotificationGrantedNotifier.value = notifGranted;
      isBluetoothGrantedNotifier.value = btGranted;

      if (micChanged) {
        debugPrint('[LupusPermissionService] Statut Microphone actualisé: $micGranted');
      }

      onPermissionsRefreshed?.call();
    } catch (e) {
      debugPrint('[LupusPermissionService] Erreur synchronisation silencieuse: $e');
    }
    return statuses;
  }

  /// Assure l'accès au microphone pour Agora Voice Service.
  /// Si non encore accordé, sollicite l'autorisation auprès du système ou navigateur.
  Future<bool> ensureMicrophonePermission() async {
    try {
      final micStatus = await Permission.microphone.status;
      if (micStatus.isGranted) {
        isMicGrantedNotifier.value = true;
        return true;
      }

      // Solliciter la permission microphone (déclenche la popup navigateur ou système)
      final requestStatus = await Permission.microphone.request();
      final isGranted = requestStatus.isGranted;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyMicGranted, isGranted);
      isMicGrantedNotifier.value = isGranted;

      onPermissionsRefreshed?.call();
      return isGranted;
    } catch (e) {
      debugPrint('[LupusPermissionService] Erreur ensureMicrophonePermission: $e');
      return false;
    }
  }

  /// Vérifie si le microphone est autorisé
  Future<bool> isMicGranted() async {
    try {
      final status = await Permission.microphone.status;
      isMicGrantedNotifier.value = status.isGranted;
      return status.isGranted;
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      final val = prefs.getBool(_keyMicGranted) ?? false;
      isMicGrantedNotifier.value = val;
      return val;
    }
  }

  /// Vérifie si les notifications sont autorisées
  Future<bool> isNotificationGranted() async {
    try {
      final status = await Permission.notification.status;
      isNotificationGrantedNotifier.value = status.isGranted;
      return status.isGranted;
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      final val = prefs.getBool(_keyNotificationGranted) ?? false;
      isNotificationGrantedNotifier.value = val;
      return val;
    }
  }

  /// Vérifie si la connexion aux baffles / casques bluetooth est autorisée
  Future<bool> isBluetoothGranted() async {
    try {
      final status = await Permission.bluetoothConnect.status;
      isBluetoothGrantedNotifier.value = status.isGranted;
      return status.isGranted;
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      final val = prefs.getBool(_keyBluetoothGranted) ?? false;
      isBluetoothGrantedNotifier.value = val;
      return val;
    }
  }

  /// Réinitialise l'état mémorisé (pour tests ou réinitialisation par l'utilisateur)
  Future<void> resetPermissionsChoice() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPermissionsRequested);
    await prefs.remove(_keyMicGranted);
    await prefs.remove(_keyNotificationGranted);
    await prefs.remove(_keyBluetoothGranted);
    await prefs.remove(_keyLastRequested);
    isMicGrantedNotifier.value = false;
    isNotificationGrantedNotifier.value = false;
    isBluetoothGrantedNotifier.value = false;
    debugPrint('[LupusPermissionService] Choix des permissions réinitialisé.');
  }
}
