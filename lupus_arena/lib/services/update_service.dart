import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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

  const AppUpdateInfo({
    required this.version,
    required this.rawTag,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.fileName,
    required this.fileSize,
    required this.currentVersion,
  });
}

/// Service autonome d'auto-mise à jour in-app connecté directement à l'API GitHub Releases
class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  static const String defaultOwner = 'Anisghd-lab';
  static const String defaultRepo = 'LUPUS-ARENA';

  /// Compare deux versions sémantiques (avec support optionnel du build number, ex: "1.0.8+9").
  /// Retourne `true` si `remote` est strictement supérieure à `local`.
  static bool isRemoteVersionGreater(String remote, String local) {
    final cleanRemote = remote.trim().replaceFirst(RegExp(r'^[vV]'), '');
    final cleanLocal = local.trim().replaceFirst(RegExp(r'^[vV]'), '');

    if (cleanRemote.isEmpty || cleanLocal.isEmpty) return false;
    if (cleanRemote == cleanLocal) return false;

    // Séparer version et build number (ex: 1.0.8+9 -> ["1.0.8", "9"])
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

  /// Vérifie la présence d'une nouvelle version sur GitHub Releases
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

      // Recherche du fichier .apk dans les assets
      final assets = data['assets'] as List<dynamic>? ?? [];
      String? apkDownloadUrl;
      String? apkFileName;
      int apkSize = 0;

      // 1. Chercher en priorité LupusArena.apk
      for (final item in assets) {
        if (item is Map) {
          final name = (item['name'] ?? '').toString();
          if (name == 'LupusArena.apk') {
            apkDownloadUrl = item['browser_download_url']?.toString();
            apkFileName = name;
            apkSize = (item['size'] is int) ? item['size'] as int : 0;
            break;
          }
        }
      }

      // 2. Sinon, prendre le premier fichier se terminant par .apk
      if (apkDownloadUrl == null) {
        for (final item in assets) {
          if (item is Map) {
            final name = (item['name'] ?? '').toString();
            if (name.toLowerCase().endsWith('.apk')) {
              apkDownloadUrl = item['browser_download_url']?.toString();
              apkFileName = name;
              apkSize = (item['size'] is int) ? item['size'] as int : 0;
              break;
            }
          }
        }
      }

      if (apkDownloadUrl == null) {
        debugPrint('[UpdateService] Aucun asset APK trouvé dans la release $rawTag');
        return null;
      }

      // Comparer avec la version locale
      final isNewer = isRemoteVersionGreater(remoteVersion, localVersion);
      if (!isNewer) {
        debugPrint('[UpdateService] L\'application est à jour ($localVersion >= $remoteVersion)');
        return null;
      }

      debugPrint('[UpdateService] Nouvelle version disponible : $remoteVersion (actuelle : $localVersion)');
      return AppUpdateInfo(
        version: remoteVersion,
        rawTag: rawTag,
        releaseNotes: releaseNotes,
        downloadUrl: apkDownloadUrl,
        fileName: apkFileName ?? 'LupusArena.apk',
        fileSize: apkSize,
        currentVersion: localVersion,
      );
    } catch (e) {
      debugPrint('[UpdateService Error] $e');
      return null;
    }
  }

  /// Télécharge l'APK avec suivi du stream d'octets et lance automatiquement l'installateur de paquets
  Future<void> downloadAndInstall({
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

      // Dès que le téléchargement atteint 100%, appelle immédiatement OpenFilex.open(filePath)
      final result = await OpenFilex.open(filePath);
      debugPrint('[UpdateService] Lancement installation APK: ${result.message} (${result.type})');
    } catch (e) {
      debugPrint('[UpdateService Error] Téléchargement / Installation: $e');
      onError?.call(e.toString());
    }
  }
}
