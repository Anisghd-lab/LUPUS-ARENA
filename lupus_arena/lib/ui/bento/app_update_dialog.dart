import 'package:flutter/material.dart';

import '../../services/app_translations.dart';
import '../../services/update_service.dart';
import '../theme/lupus_theme.dart';
import 'bento_card.dart';

/// Boîte de dialogue modale présentant les détails d'une nouvelle version
/// et gérant le téléchargement en temps réel avec installation automatique de l'APK.
class AppUpdateDialog extends StatefulWidget {
  final AppUpdateInfo updateInfo;

  const AppUpdateDialog({super.key, required this.updateInfo});

  static Future<void> show(BuildContext context, AppUpdateInfo updateInfo) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (_) => AppUpdateDialog(updateInfo: updateInfo),
    );
  }

  @override
  State<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<AppUpdateDialog> {
  bool _isDownloading = false;
  bool _isDownloaded = false;
  String? _downloadedFilePath;
  double _progress = 0.0;
  int _receivedBytes = 0;
  int _totalBytes = 0;
  String? _errorMessage;
  String? _infoMessage;

  @override
  void initState() {
    super.initState();
    _checkExistingApk();
  }

  Future<void> _checkExistingApk() async {
    final existingFile = await UpdateService.getExistingApkFile(
      widget.updateInfo.fileName,
      widget.updateInfo.version,
      widget.updateInfo.fileSize,
    );
    if (existingFile != null && mounted) {
      setState(() {
        _isDownloaded = true;
        _downloadedFilePath = existingFile.path;
        _progress = 1.0;
      });
    }
  }

  Future<void> _startDownloadOrInstall() async {
    // Si l'APK est déjà téléchargé, lancer directement l'installateur
    if (_isDownloaded && _downloadedFilePath != null) {
      setState(() {
        _errorMessage = null;
        _infoMessage = null;
      });
      final result = await UpdateService.launchApkInstallation(_downloadedFilePath!);
      if (!mounted) return;
      if (result == 'PERMISSION_REQUIRED') {
        setState(() {
          _infoMessage = context.tr('update_permission_hint');
        });
      } else if (result != 'INSTALLER_LAUNCHED') {
        setState(() {
          _errorMessage = result;
        });
      }
      return;
    }

    setState(() {
      _isDownloading = true;
      _errorMessage = null;
      _infoMessage = null;
      _progress = 0.0;
      _receivedBytes = 0;
      _totalBytes = widget.updateInfo.fileSize;
    });

    try {
      final installResult = await UpdateService().downloadAndInstall(
        downloadUrl: widget.updateInfo.downloadUrl,
        fileName: widget.updateInfo.fileName,
        version: widget.updateInfo.version,
        expectedSize: widget.updateInfo.fileSize,
        onProgress: (progress, received, total) {
          if (!mounted) return;
          setState(() {
            _progress = progress.clamp(0.0, 1.0);
            _receivedBytes = received;
            _totalBytes = total;
          });
        },
        onError: (err) {
          if (!mounted) return;
          setState(() {
            _isDownloading = false;
            _errorMessage = context.tr('update_failed', [err.toString()]);
          });
        },
      );

      if (!mounted) return;

      final downloadDir = await UpdateService.getDownloadDirectory();
      final versionSuffix = '_${widget.updateInfo.version}';
      final baseName = widget.updateInfo.fileName.replaceAll('.apk', '');
      final safeApkName = '$baseName$versionSuffix.apk';
      final path = '${downloadDir.path}/$safeApkName';

      if (installResult.startsWith('ERROR:') || installResult == 'FILE_NOT_FOUND') {
        setState(() {
          _isDownloading = false;
          _errorMessage = installResult;
        });
      } else {
        setState(() {
          _isDownloading = false;
          _isDownloaded = true;
          _downloadedFilePath = path;
          _progress = 1.0;
          if (installResult == 'PERMISSION_REQUIRED') {
            _infoMessage = context.tr('update_permission_hint');
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDownloading = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.updateInfo;
    final percent = (_progress * 100).toInt();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: BentoCard(
          borderColor: LupusColors.arcaneCyan,
          glowing: true,
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // En-tête avec icône animée
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: LupusColors.arcaneCyan.withValues(alpha: 0.18),
                      border: Border.all(
                        color: LupusColors.arcaneCyan,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: LupusColors.arcaneCyan.withValues(alpha: 0.4),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.system_update_rounded,
                      color: LupusColors.arcaneCyan,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('update_version_title'),
                          style: const TextStyle(
                            fontFamily: 'serif',
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.tr('update_version_sub', [info.version, info.currentVersion]),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: LupusColors.arcaneCyan,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Zone de Changelog / Notes de version
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: LupusColors.border.withValues(alpha: 0.6),
                  ),
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.article_rounded,
                          size: 16,
                          color: LupusColors.arcaneGold,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          context.tr('update_notes_title'),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: LupusColors.arcaneGold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 160),
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Text(
                          info.releaseNotes.trim().isNotEmpty
                              ? info.releaseNotes.trim()
                              : context.tr('update_default_notes'),
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.45,
                            color: LupusColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Barre de progression si téléchargement en cours
              if (_isDownloading) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00FF88).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF00FF88).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _progress >= 1.0
                                ? context.tr('update_installing')
                                : context.tr('update_downloading'),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF00FF88),
                            ),
                          ),
                          Text(
                            '$percent%',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'monospace',
                              color: Color(0xFF00FF88),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: _progress,
                          minHeight: 8,
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF00FF88),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (_totalBytes > 0)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '${(_receivedBytes / (1024 * 1024)).toStringAsFixed(1)} Mo / ${(_totalBytes / (1024 * 1024)).toStringAsFixed(1)} Mo',
                            style: const TextStyle(
                              fontSize: 10,
                              color: LupusColors.textMuted,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],

              // Message d'information / permission
              if (_infoMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF10B981)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: Color(0xFF10B981),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _infoMessage!,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Message d'erreur
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: LupusColors.bloodRed.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: LupusColors.bloodRed),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: LupusColors.bloodRed,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Boutons d'action
              Row(
                children: [
                  if (!_isDownloading)
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: LupusColors.textSecondary,
                          side: BorderSide(
                            color: LupusColors.border.withValues(alpha: 0.8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          context.tr('update_later'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  if (!_isDownloading) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isDownloading
                            ? LupusColors.surfaceLight
                            : (_isDownloaded
                                ? const Color(0xFF10B981)
                                : LupusColors.arcaneCyan),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: _isDownloading ? 0 : 4,
                      ),
                      icon: _isDownloading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.black,
                                ),
                              ),
                            )
                          : Icon(
                              _isDownloaded
                                  ? Icons.system_security_update_good_rounded
                                  : Icons.download_rounded,
                              size: 20,
                              color: Colors.black,
                            ),
                      label: Text(
                        _isDownloading
                            ? context.tr('update_downloading')
                            : (_isDownloaded
                                ? context.tr('update_install_now')
                                : context.tr('update_download').toUpperCase()),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                        ),
                      ),
                      onPressed: _isDownloading ? null : _startDownloadOrInstall,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
