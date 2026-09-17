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
        .map((e) => int.tryParse(RegExp(r'\d+').firstMatch(e)?.group(0) ?? '') ?? 0)
        .toList();
    final localSemver = localParts[0]
        .split('.')
        .map((e) => int.tryParse(RegExp(r'\d+').firstMatch(e)?.group(0) ?? '') ?? 0)
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
      final rBuild = int.tryParse(RegExp(r'\d+').firstMatch(remoteParts[1])?.group(0) ?? '') ?? 0;
      final lBuild = int.tryParse(RegExp(r'\d+').firstMatch(localParts[1])?.group(0) ?? '') ?? 0;
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

      // 1. Essai API GitHub sur le dépôt principal
      AppUpdateInfo? update = await _fetchRelease(owner, repo, localVersion);

      // 2. Secours miroir si dépôt principal échoue
      if (update == null && owner == defaultOwner && repo == defaultRepo) {
        debugPrint('[UpdateService] Tentative de secours sur le miroir zakghd/LUPUS_ARENA...');
        update = await _fetchRelease('zakghd', 'LUPUS_ARENA', localVersion);
      }

      // 3. Secours via redirection Web GitHub (contourne la limite de taux API GitHub HTTP 403)
      if (update == null && owner == defaultOwner && repo == defaultRepo) {
        debugPrint('[UpdateService] Tentative de secours via redirection Web...');
        update = await _fetchReleaseFromWeb(owner, repo, localVersion);
        update ??= await _fetchReleaseFromWeb('zakghd', 'LUPUS_ARENA', localVersion);
      }

      return update;
    } catch (e) {
      debugPrint('[UpdateService Error] $e');
      return null;
    }
  }

  Future<AppUpdateInfo?> _fetchRelease(
    String owner,
    String repo,
    String localVersion,
  ) async {
    try {
      final url = Uri.parse('https://api.github.com/repos/$owner/$repo/releases/latest');
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'LupusArena-App',
        },
      );

      if (response.statusCode != 200) {
        debugPrint('[UpdateService] Réponse GitHub non-200 pour $owner/$repo : ${response.statusCode}');
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
        debugPrint('[UpdateService] Aucun asset APK trouvé dans la release $rawTag sur $owner/$repo');
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

      debugPrint('[UpdateService] Nouvelle version disponible sur $owner/$repo : $remoteVersion ($fileName, ${(fileSize / (1024 * 1024)).toStringAsFixed(1)} Mo, ABI: $abi)');
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
      debugPrint('[UpdateService Fetch Error] $e');
      return null;
    }
  }

  /// Secours en cas de limitation de taux API GitHub : interroge l'URL web qui redirige vers le tag
  Future<AppUpdateInfo?> _fetchReleaseFromWeb(
    String owner,
    String repo,
    String localVersion,
  ) async {
    try {
      final client = http.Client();
      final request = http.Request(
        'GET',
        Uri.parse('https://github.com/$owner/$repo/releases/latest'),
      )..followRedirects = false;
      final streamedResponse = await client.send(request);
      final location = streamedResponse.headers['location'];
      if (location == null || !location.contains('/releases/tag/')) {
        return null;
      }
      final rawTag = location.split('/releases/tag/').last.trim();
      if (rawTag.isEmpty) return null;

      final remoteVersion = rawTag.replaceFirst(RegExp(r'^[vV]'), '');
      if (!isRemoteVersionGreater(remoteVersion, localVersion)) {
        debugPrint('[UpdateService Web] L\'application est à jour ($localVersion >= $remoteVersion)');
        return null;
      }

      final abi = await getTargetAbi();
      final fileName = abi == 'arm64'
          ? 'LupusArena-arm64.apk'
          : (abi == 'arm32' ? 'LupusArena-arm32.apk' : 'LupusArena.apk');
      final downloadUrl =
          'https://github.com/$owner/$repo/releases/download/$rawTag/$fileName';

      debugPrint('[UpdateService Web] Nouvelle version détectée via Web : $remoteVersion ($fileName)');
      return AppUpdateInfo(
        version: remoteVersion,
        rawTag: rawTag,
        releaseNotes: 'Mise à jour de performance, corrections de bugs et nouvelles fonctionnalités de jeu.',
        downloadUrl: downloadUrl,
        fileName: fileName,
        fileSize: 0,
        currentVersion: localVersion,
        matchedAbi: abi,
        hasUpdate: true,
      );
    } catch (e) {
      debugPrint('[UpdateService Web Fallback Error] $e');
      return null;
    }
  }

  /// Dossier de téléchargement optimisé (cache externe Android pour éviter les restrictions de bac à sable)
  static Future<Directory> getDownloadDirectory() async {
    if (Platform.isAndroid) {
      try {
        final extDirs = await getExternalCacheDirectories();
        if (extDirs != null && extDirs.isNotEmpty) {
          return extDirs.first;
        }
      } catch (_) {}
    }
    return await getTemporaryDirectory();
  }

  /// Vérifie si un APK déjà téléchargé correspond exactement à la version et à la taille attendues
  static Future<File?> getExistingApkFile(
    String fileName,
    String version,
    int expectedSize,
  ) async {
    try {
      final dir = await getDownloadDirectory();
      final baseName = fileName.replaceAll('.apk', '');
      final safeName = '${baseName}_$version.apk';
      final file = File('${dir.path}/$safeName');
      if (await file.exists()) {
        final length = await file.length();
        if (expectedSize > 0 && length == expectedSize) {
          return file;
        } else if (expectedSize <= 0 && length > 10 * 1024 * 1024) {
          return file;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Nettoie les anciens fichiers APK de mises à jour précédentes pour économiser l'espace disque
  static Future<void> _cleanupOldApks(Directory dir, String currentApkName) async {
    try {
      final entities = await dir.list().toList();
      for (final entity in entities) {
        if (entity is File &&
            entity.path.endsWith('.apk') &&
            !entity.path.endsWith(currentApkName)) {
          try {
            await entity.delete();
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  /// Déclenche l'installation native d'un fichier APK
  static Future<String> launchApkInstallation(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      debugPrint('[UpdateService] Le fichier APK n\'existe pas à $filePath');
      return 'FILE_NOT_FOUND';
    }

    // 0. Vérifier si l'autorisation d'installer depuis des sources inconnues est accordée (Android 8.0+)
    if (Platform.isAndroid) {
      final canInstall = await canRequestPackageInstalls();
      if (!canInstall) {
        debugPrint('[UpdateService] Demande d\'autorisation REQUEST_INSTALL_PACKAGES...');
        await openInstallPermissionSettings();
        return 'PERMISSION_REQUIRED';
      }
    }

    // 1. Essayer d'abord le MethodChannel natif Android (haute fiabilité avec FileProvider interne et permissions explicites)
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

  /// Télécharge l'APK avec reprise sécurisée (.part), vérification de taille et lancement de l'installateur
  Future<String> downloadAndInstall({
    required String downloadUrl,
    required String fileName,
    String? version,
    int? expectedSize,
    required void Function(double progress, int received, int total) onProgress,
    void Function(String error)? onError,
  }) async {
    try {
      final dir = await getDownloadDirectory();
      final versionSuffix = version != null ? '_$version' : '';
      final baseName = fileName.replaceAll('.apk', '');
      final safeApkName = '$baseName$versionSuffix.apk';
      final apkFile = File('${dir.path}/$safeApkName');
      final partFile = File('${dir.path}/$safeApkName.part');

      // Nettoyer les anciens APKs périmés pour libérer l'espace
      await _cleanupOldApks(dir, safeApkName);

      // Si l'APK complet valide existe déjà sur l'appareil, le lancer immédiatement
      if (await apkFile.exists()) {
        final existingFullLength = await apkFile.length();
        final isValidSize = expectedSize != null && expectedSize > 0
            ? existingFullLength == expectedSize
            : existingFullLength > 10 * 1024 * 1024;
        if (isValidSize) {
          debugPrint('[UpdateService] APK déjà téléchargé et valide ($existingFullLength octets). Lancement direct...');
          onProgress(1.0, existingFullLength, existingFullLength);
          return await launchApkInstallation(apkFile.path);
        } else {
          try {
            await apkFile.delete();
          } catch (_) {}
        }
      }

      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(minutes: 5),
          sendTimeout: const Duration(seconds: 30),
          followRedirects: true,
          maxRedirects: 5,
        ),
      );

      const maxRetries = 5;
      int retryCount = 0;
      int totalBytes = expectedSize ?? -1;

      while (retryCount < maxRetries) {
        int existingBytes = 0;
        if (await partFile.exists()) {
          existingBytes = await partFile.length();
        }

        // Si le fichier partiel dépasse la taille attendue, réinitialiser
        if (totalBytes > 0 && existingBytes >= totalBytes) {
          try {
            await partFile.delete();
          } catch (_) {}
          existingBytes = 0;
        }

        try {
          debugPrint(
            '[UpdateService] Téléchargement essai ${retryCount + 1}/$maxRetries (offset: $existingBytes octets)...',
          );

          final headers = <String, dynamic>{
            'User-Agent': 'LupusArena-App',
          };
          if (existingBytes > 0) {
            headers['Range'] = 'bytes=$existingBytes-';
          }

          final response = await dio.get<ResponseBody>(
            downloadUrl,
            options: Options(
              responseType: ResponseType.stream,
              headers: headers,
              validateStatus: (status) =>
                  status != null &&
                  ((status >= 200 && status < 300) || status == 206 || status == 416),
            ),
          );

          if (response.statusCode == 416) {
            // Range non valide -> Réinitialiser le fichier partiel
            debugPrint('[UpdateService] Code 416 reçu, réinitialisation du fichier partiel...');
            try {
              await partFile.delete();
            } catch (_) {}
            existingBytes = 0;
            retryCount++;
            continue;
          }

          final responseBody = response.data;
          if (responseBody == null) {
            throw Exception('Flux de données vide reçu du serveur');
          }

          final isPartial = response.statusCode == 206;
          final contentRange = response.headers.value('content-range');
          final contentLength = response.headers.value('content-length');

          if (contentRange != null && contentRange.contains('/')) {
            final totalStr = contentRange.split('/').last.trim();
            totalBytes = int.tryParse(totalStr) ?? totalBytes;
          } else if (contentLength != null) {
            final parsedLength = int.tryParse(contentLength) ?? 0;
            if (isPartial) {
              totalBytes = existingBytes + parsedLength;
            } else {
              totalBytes = parsedLength;
            }
          }

          final shouldAppend = isPartial && existingBytes > 0;
          if (!shouldAppend && existingBytes > 0) {
            existingBytes = 0;
            if (await partFile.exists()) {
              try {
                await partFile.delete();
              } catch (_) {}
            }
          }

          final sink = partFile.openWrite(
            mode: shouldAppend ? FileMode.append : FileMode.write,
          );

          int received = existingBytes;
          try {
            await for (final chunk in responseBody.stream) {
              sink.add(chunk);
              received += chunk.length;
              if (totalBytes > 0) {
                final progress = (received / totalBytes).clamp(0.0, 1.0);
                onProgress(progress, received, totalBytes);
              } else {
                onProgress(0.5, received, totalBytes);
              }
            }
          } finally {
            await sink.flush();
            await sink.close();
          }

          final downloadedLength = await partFile.length();
          if (totalBytes > 0 && downloadedLength < totalBytes) {
            throw DioException(
              requestOptions: response.requestOptions,
              error:
                  'Téléchargement incomplet ($downloadedLength / $totalBytes octets)',
            );
          }

          debugPrint(
            '[UpdateService] Téléchargement complété ($downloadedLength octets). Finalisation de l\'APK...',
          );

          if (await apkFile.exists()) {
            try {
              await apkFile.delete();
            } catch (_) {}
          }
          await partFile.rename(apkFile.path);
          break; // Succès
        } catch (e) {
          retryCount++;
          debugPrint(
            '[UpdateService Warning] Coupure/Erreur téléchargement ($retryCount/$maxRetries): $e',
          );
          if (retryCount >= maxRetries) {
            rethrow;
          }
          await Future.delayed(Duration(seconds: retryCount * 2));
        }
      }

      if (!await apkFile.exists()) {
        throw Exception('Le fichier APK final n\'a pas pu être enregistré sur l\'appareil.');
      }

      // Lancement immédiat de l'installation de l'APK téléchargé
      final installResult = await launchApkInstallation(apkFile.path);
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
