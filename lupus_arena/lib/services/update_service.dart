import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// Informations détaillées sur une mise à jour disponible
class AppUpdateInfo {
  final String version;
  final String rawTag;
  final String releaseNotes;
  final String downloadUrl;
  final String fileName;
  final int fileSize;
  final String currentVersion;
  final String matchedAbi;
  final bool hasUpdate;

  // Getters compatibles avec le format FastUpdateService
  String get tagName => rawTag;
  String get changelog => releaseNotes;
  String get apkUrl => downloadUrl;

  const AppUpdateInfo({
    required this.version,
    required this.rawTag,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.fileName,
    required this.fileSize,
    required this.currentVersion,
    this.matchedAbi = 'universal',
    this.hasUpdate = true,
  });
}

/// Alias pour compatibilité
typedef UpdateInfo = AppUpdateInfo;

/// Service autonome d'auto-mise à jour in-app connecté directement à l'API GitHub Releases
/// avec sélection dynamique de l'architecture processeur (ABI) pour un téléchargement allégé.
class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  static const String defaultOwner = 'Anisghd-lab';
  static const String defaultRepo = 'LUPUS-ARENA';

  static const MethodChannel _nativeInstaller =
      MethodChannel('com.anisghdlab.lupusarena/installer');

  /// Vérifie si l'appareil a accordé la permission d'installer des packages inconnus (Android 8+)
  static Future<bool> canRequestPackageInstalls() async {
    if (!Platform.isAndroid) return true;
    try {
      final canInstall =
          await _nativeInstaller.invokeMethod<bool>('canRequestPackageInstalls');
      return canInstall ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Ouvre l'écran des paramètres système pour autoriser l'installation d'applications
  static Future<void> openInstallPermissionSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _nativeInstaller.invokeMethod('openInstallPermissionSettings');
    } catch (e) {
      debugPrint('[UpdateService] Erreur ouverture paramètres permissions: $e');
    }
  }

  /// Détecte l'architecture du processeur du téléphone via AndroidDeviceInfo.supportedAbis
  static Future<String> getTargetAbi() async {
    if (!Platform.isAndroid) return 'universal';

    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final supportedAbis = androidInfo.supportedAbis;

      debugPrint('[UpdateService] ABIs supportées par l\'appareil: $supportedAbis');

      // Priorité aux processeurs 64-bit récents (arm64-v8a)
      if (supportedAbis.contains('arm64-v8a')) {
        return 'arm64';
      }
      // Téléphones 32-bit (ex: itel A50c, armeabi-v7a)
      if (supportedAbis.contains('armeabi-v7a')) {
        return 'arm32';
      }
    } catch (e) {
      debugPrint('[UpdateService] Erreur lors de la détection de l\'ABI: $e');
    }
    return 'universal';
  }

  /// Compare deux versions sémantiques (avec support du build number, ex: "1.0.13+14").
  /// Retourne `true` si `remote` est strictement supérieure à `local`.
  static bool isRemoteVersionGreater(String remote, String local) {
    final cleanRemote = remote.trim().replaceFirst(RegExp(r'^[vV]'), '');
    final cleanLocal = local.trim().replaceFirst(RegExp(r'^[vV]'), '');

    if (cleanRemote.isEmpty || cleanLocal.isEmpty) return false;
    if (cleanRemote == cleanLocal) return false;

    // Séparer version et build number (ex: 1.0.13+14 -> ["1.0.13", "14"])
    final remoteParts = cleanRemote.split('+');
    final localParts = cleanLocal.split('+');

    final remoteSemver = remoteParts[0]
        .split('.')
        .map((e) => int.tryParse(e) ?? 0)
        .toList();
    final localSemver = localParts[0]
        .split('.')
        .map((e) => int.tryParse(e) ?? 0)
        .toList();

    final maxLen = math.max(remoteSemver.length, localSemver.length);
    for (int i = 0; i < maxLen; i++) {
      final r = i < remoteSemver.length ? remoteSemver[i] : 0;
      final l = i < localSemver.length ? localSemver[i] : 0;
      if (r > l) return true;
      if (r < l) return false;
    }

    // Si les versions de base sont identiques, comparer le build number
    if (remoteParts.length > 1 && localParts.length > 1) {
      final rBuild = int.tryParse(remoteParts[1]) ?? 0;
      final lBuild = int.tryParse(localParts[1]) ?? 0;
      return rBuild > lBuild;
    } else if (remoteParts.length > 1) {
      return true;
    }

    return false;
  }

  /// Récupère la dernière release GitHub et sélectionne l'APK le plus léger adapté à l'appareil
  Future<AppUpdateInfo?> checkForUpdate({
    String owner = defaultOwner,
    String repo = defaultRepo,
  }) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final localVersion = packageInfo.buildNumber.isNotEmpty
          ? '${packageInfo.version}+${packageInfo.buildNumber}'
          : packageInfo.version;

      final url = Uri.parse('https://api.github.com/repos/$owner/$repo/releases/latest');
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'LupusArena-App',
        },
      );

      if (response.statusCode != 200) {
        debugPrint('[UpdateService] Réponse GitHub non-200 : ${response.statusCode}');
        return null;
      }

      final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final rawTag = (data['tag_name'] ?? '').toString();
      if (rawTag.isEmpty) return null;

      final remoteVersion = rawTag.replaceFirst(RegExp(r'^[vV]'), '');
      final releaseNotes = (data['body'] ?? 'Mise à jour de performance et nouvelles fonctionnalités.').toString();
      final assets = data['assets'] as List<dynamic>? ?? [];

      // 1. Détection de l'architecture processeur (ABI)
      final abi = await getTargetAbi();
      debugPrint('[UpdateService] Architecture cible sélectionnée: $abi');

      // 2. Sélection dynamique de l'Asset GitHub ciblé et allégé
      dynamic targetAsset;
      if (abi == 'arm64') {
        targetAsset = assets.firstWhere(
          (a) => (a is Map) &&
                 (a['name'] as String? ?? '').contains('arm64') &&
                 (a['name'] as String? ?? '').endsWith('.apk'),
          orElse: () => null,
        );
      } else if (abi == 'arm32') {
        targetAsset = assets.firstWhere(
          (a) => (a is Map) &&
                 (a['name'] as String? ?? '').contains('arm32') &&
                 (a['name'] as String? ?? '').endsWith('.apk'),
          orElse: () => null,
        );
      }

      // Fallback 1: LupusArena.apk
      targetAsset ??= assets.firstWhere(
        (a) => (a is Map) && (a['name'] as String? ?? '') == 'LupusArena.apk',
        orElse: () => null,
      );

      // Fallback 2: N'importe quel APK disponible
      targetAsset ??= assets.firstWhere(
        (a) => (a is Map) && (a['name'] as String? ?? '').toLowerCase().endsWith('.apk'),
        orElse: () => null,
      );

      if (targetAsset == null) {
        debugPrint('[UpdateService] Aucun asset APK trouvé dans la release $rawTag');
        return null;
      }

      final downloadUrl = (targetAsset['browser_download_url'] ?? '').toString();
      final fileName = (targetAsset['name'] ?? 'LupusArena.apk').toString();
      final fileSize = (targetAsset['size'] is int) ? targetAsset['size'] as int : 0;

      if (downloadUrl.isEmpty) {
        debugPrint('[UpdateService] URL de téléchargement invalide pour $fileName');
        return null;
      }

      // Comparer avec la version locale
      final isNewer = isRemoteVersionGreater(remoteVersion, localVersion);
      if (!isNewer) {
        debugPrint('[UpdateService] L\'application est à jour ($localVersion >= $remoteVersion)');
        return null;
      }

      debugPrint('[UpdateService] Nouvelle version disponible : $remoteVersion ($fileName, ${(fileSize / (1024 * 1024)).toStringAsFixed(1)} Mo, ABI: $abi)');
      return AppUpdateInfo(
        version: remoteVersion,
        rawTag: rawTag,
        releaseNotes: releaseNotes,
        downloadUrl: downloadUrl,
        fileName: fileName,
        fileSize: fileSize,
        currentVersion: localVersion,
        matchedAbi: abi,
        hasUpdate: true,
      );
    } catch (e) {
      debugPrint('[UpdateService Error] $e');
      return null;
    }
  }

  /// Déclenche l'installation native d'un fichier APK
  static Future<String> launchApkInstallation(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      debugPrint('[UpdateService] Le fichier APK n\'existe pas à $filePath');
      return 'FILE_NOT_FOUND';
    }

    // 1. Essayer d'abord le MethodChannel natif Android (haute fiabilité avec FileProvider interne)
    if (Platform.isAndroid) {
      try {
        final result = await _nativeInstaller.invokeMethod<String>('installApk', {
          'filePath': filePath,
        });
        if (result != null) {
          debugPrint('[UpdateService Native] Résultat installation natif: $result');
          return result;
        }
      } catch (e) {
        debugPrint('[UpdateService Native Error] $e - Tentative fallback OpenFilex');
      }
    }

    // 2. Fallback avec OpenFilex en spécifiant explicitement le type MIME Android APK
    try {
      final openResult = await OpenFilex.open(
        filePath,
        type: 'application/vnd.android.package-archive',
      );
      debugPrint('[UpdateService OpenFilex] ${openResult.message} (${openResult.type})');
      return openResult.type == ResultType.done ? 'INSTALLER_LAUNCHED' : openResult.message;
    } catch (e) {
      debugPrint('[UpdateService OpenFilex Error] $e');
      return 'ERROR: $e';
    }
  }

  /// Télécharge l'APK avec suivi du stream d'octets et lance automatiquement l'installateur de paquets
  Future<String> downloadAndInstall({
    required String downloadUrl,
    required String fileName,
    required void Function(double progress, int received, int total) onProgress,
    void Function(String error)? onError,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/$fileName';

      final file = File(filePath);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }

      final dio = Dio();
      await dio.download(
        downloadUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress = received / total;
            onProgress(progress, received, total);
          }
        },
      );

      // Lancement immédiat de l'installation de l'APK téléchargé
      final installResult = await launchApkInstallation(filePath);
      return installResult;
    } catch (e) {
      debugPrint('[UpdateService Error] Téléchargement / Installation: $e');
      onError?.call(e.toString());
      return 'ERROR: $e';
    }
  }
}

/// Service rapide d'auto-mise à jour avec méthodes statiques
class FastUpdateService {
  static Future<String> getTargetAbi() => UpdateService.getTargetAbi();

  static Future<UpdateInfo?> checkForUpdate({
    String owner = UpdateService.defaultOwner,
    String repo = UpdateService.defaultRepo,
  }) => UpdateService().checkForUpdate(owner: owner, repo: repo);

  /// Lance directement l'installation d'un fichier APK déjà présent
  static Future<String> installApk(String filePath) =>
      UpdateService.launchApkInstallation(filePath);

  /// Télécharge le binaire ciblé et allégé puis lance l'installateur
  static Future<String> downloadAndInstall({
    required String apkUrl,
    required Function(double progress) onProgress,
    String fileName = 'lupus_quick_update.apk',
    void Function(String error)? onError,
  }) async {
    return UpdateService().downloadAndInstall(
      downloadUrl: apkUrl,
      fileName: fileName,
      onProgress: (progress, received, total) => onProgress(progress),
      onError: onError,
    );
  }
}
