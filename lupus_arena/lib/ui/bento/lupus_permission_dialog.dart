import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../services/lupus_permission_service.dart';
import '../theme/lupus_assets.dart';
import '../theme/lupus_theme.dart';
import 'bento_card.dart';

/// Modal d'accueil Dark Fantasy demandant les autorisations indispensables
/// lors du tout premier lancement du jeu (Microphone Agora, Notifications, Audio/Bluetooth).
class LupusPermissionDialog extends StatefulWidget {
  final VoidCallback? onCompleted;

  const LupusPermissionDialog({super.key, this.onCompleted});

  /// Affiche automatiquement la boîte de dialogue si c'est la première utilisation (uniquement sur mobile natif)
  static Future<void> showIfNeeded(BuildContext context) async {
    if (kIsWeb) return;
    try {
      final service = LupusPermissionService();
      final alreadyRequested = await service.hasRequestedPermissions();
      if (!alreadyRequested && context.mounted) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          barrierColor: Colors.black.withValues(alpha: 0.85),
          builder: (_) => const LupusPermissionDialog(),
        );
      }
    } catch (e) {
      debugPrint('[LupusPermissionDialog] Erreur showIfNeeded: $e');
    }
  }

  /// Force l'affichage pour re-configurer les permissions
  static Future<void> showForce(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (_) => const LupusPermissionDialog(),
    );
  }

  @override
  State<LupusPermissionDialog> createState() => _LupusPermissionDialogState();
}

class _LupusPermissionDialogState extends State<LupusPermissionDialog> {
  final LupusPermissionService _service = LupusPermissionService();

  bool _isRequesting = false;
  bool? _micGranted;
  bool? _notifGranted;
  bool? _bluetoothGranted;

  @override
  void initState() {
    super.initState();
    _checkCurrentStatuses();
  }

  Future<void> _checkCurrentStatuses() async {
    final mic = await _service.isMicGranted();
    final notif = await _service.isNotificationGranted();
    final bt = await _service.isBluetoothGranted();

    if (mounted) {
      setState(() {
        _micGranted = mic;
        _notifGranted = notif;
        _bluetoothGranted = bt;
      });
    }
  }

  Future<void> _requestAll() async {
    setState(() => _isRequesting = true);

    try {
      final statuses = await _service.requestAllPermissionsOnce(force: true);

      final micOk = statuses[Permission.microphone]?.isGranted ?? false;
      final notifOk = statuses[Permission.notification]?.isGranted ?? false;
      final btOk = kIsWeb
          ? true
          : (statuses[Permission.bluetoothConnect]?.isGranted ?? false);

      if (mounted) {
        setState(() {
          _micGranted = micOk;
          _notifGranted = notifOk;
          _bluetoothGranted = btOk;
          _isRequesting = false;
        });

        // Fermer automatiquement après un court délai de confirmation visuelle
        await Future.delayed(const Duration(milliseconds: 900));
        if (mounted) {
          widget.onCompleted?.call();
          Navigator.of(context).pop();
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isRequesting = false);
      }
    }
  }

  void _skip() {
    widget.onCompleted?.call();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final allGranted = (_micGranted == true) &&
        (_notifGranted == true) &&
        (kIsWeb || _bluetoothGranted == true);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: BentoCard(
        padding: const EdgeInsets.all(22),
        backgroundColor: const Color(0xF50A0F1E),
        borderColor: LupusColors.arcanePurple,
        glowing: true,
        borderRadius: 24,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Médaillon d'en-tête
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: LupusTheme.glowPurple(opacity: 0.6),
                  ),
                  child: ClipOval(
                    child: LupusAssets.adaptiveImage(
                      assetPath: LupusAssets.wolfSealAsset,
                      networkUrl: LupusAssets.wolfSealUrl,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Titre gothique
              const Text(
                'BIENVENUE DANS L\'ARÈNE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Pour participer aux débats et entendre la meute de nuit, veuillez accorder les accès suivants :',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: 20),

              // 1. Microphone (Agora RTC)
              _buildPermissionTile(
                icon: Icons.mic_rounded,
                iconColor: LupusColors.voiceActive,
                title: 'Microphone (Agora RTC)',
                description:
                    'Indispensable pour débattre en journée et comploter la nuit.',
                isGranted: _micGranted,
                isRequired: true,
              ),
              const SizedBox(height: 10),

              // 2. Audio / Bluetooth
              if (!kIsWeb) ...[
                _buildPermissionTile(
                  icon: Icons.headset_rounded,
                  iconColor: LupusColors.arcaneCyan,
                  title: 'Casque & Bluetooth Audio',
                  description:
                      'Permet de connecter vos écouteurs sans fil pour une immersion sonore.',
                  isGranted: _bluetoothGranted,
                  isRequired: false,
                ),
                const SizedBox(height: 10),
              ],

              // 3. Notifications
              _buildPermissionTile(
                icon: Icons.notifications_active_rounded,
                iconColor: LupusColors.arcaneGold,
                title: 'Notifications du Conseil',
                description:
                    'Vous prévient dès que la nuit tombe ou quand c\'est à votre tour de voter.',
                isGranted: _notifGranted,
                isRequired: false,
              ),

              const SizedBox(height: 24),

              // Bouton principal d'action
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isRequesting ? null : _requestAll,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: allGranted
                        ? LupusColors.poisonGreen
                        : LupusColors.arcanePurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 6,
                  ),
                  icon: _isRequesting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(allGranted ? Icons.check_circle : Icons.security),
                  label: Text(
                    _isRequesting
                        ? 'AUTORISATION EN COURS...'
                        : (allGranted
                            ? 'ACCÈS CONFIRMÉS ! ENTRER'
                            : 'ACCORDER LES AUTORISATIONS'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Bouton passer / plus tard
              Center(
                child: TextButton(
                  onPressed: _skip,
                  child: Text(
                    allGranted ? 'Fermer' : 'Configurer plus tard',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required bool? isGranted,
    required bool isRequired,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: LupusColors.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isGranted == true
              ? LupusColors.poisonGreen.withValues(alpha: 0.6)
              : LupusColors.border,
          width: isGranted == true ? 1.4 : 1.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (isRequired)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: LupusColors.bloodRed.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'REQUIS',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: LupusColors.bloodRed,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.3,
                    color: Colors.white.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: isGranted == true
                ? const Icon(
                    Icons.check_circle,
                    color: LupusColors.poisonGreen,
                    size: 18,
                  )
                : Icon(
                    Icons.radio_button_unchecked,
                    color: Colors.white.withValues(alpha: 0.3),
                    size: 18,
                  ),
          ),
        ],
      ),
    );
  }
}
