import 'dart:async';
import 'package:flutter/material.dart';

import '../../models/player_model.dart';
import '../theme/lupus_theme.dart';
import 'role_card_image.dart';

/// Modale holographique confidentielle réservée exclusivement à la Voyante.
/// Révèle l'identité et la carte officielle de la cible pendant 6 secondes ou jusqu'à confirmation.
class SeerVisionModal extends StatefulWidget {
  final PlayerModel target;
  final VoidCallback onConfirmed;

  const SeerVisionModal({
    super.key,
    required this.target,
    required this.onConfirmed,
  });

  static Future<void> show({
    required BuildContext context,
    required PlayerModel target,
    required VoidCallback onConfirmed,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (_) => SeerVisionModal(
        target: target,
        onConfirmed: onConfirmed,
      ),
    );
  }

  @override
  State<SeerVisionModal> createState() => _SeerVisionModalState();
}

class _SeerVisionModalState extends State<SeerVisionModal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _timerController;
  Timer? _countdownTimer;
  int _secondsRemaining = 6;
  bool _confirmed = false;

  @override
  void initState() {
    super.initState();
    _timerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..forward();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_secondsRemaining > 1) {
          _secondsRemaining--;
        } else {
          _closeAndConfirm();
        }
      });
    });
  }

  void _closeAndConfirm() {
    if (_confirmed) return;
    _confirmed = true;
    _countdownTimer?.cancel();
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    widget.onConfirmed();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _timerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.target.role;
    final teamColor = role.isEvil
        ? LupusColors.bloodRed
        : (role.defaultTeam == Team.village
            ? const Color(0xFF38BDF8)
            : LupusColors.arcaneViolet);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xF2080D1D),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: LupusColors.arcaneViolet, width: 1.8),
          boxShadow: [
            ...LupusTheme.glowPurple(opacity: 0.5),
            BoxShadow(
              color: teamColor.withValues(alpha: 0.25),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // En-tête : Oeil omniscient & Titre
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: LupusColors.arcanePurple.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: LupusColors.arcanePurple),
                  ),
                  child: const Text('🔮', style: TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'VISION SECRÈTE DE L\'ÂME',
                      style: TextStyle(
                        fontFamily: 'serif',
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: Color(0xFFE9D5FF),
                      ),
                    ),
                    Text(
                      'Révélé à la Voyante uniquement',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontFamily: 'monospace',
                        color: LupusColors.arcaneGold.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Nom de la cible
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: LupusColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: LupusColors.border),
              ),
              child: Text(
                'Cible sondée : ${widget.target.name}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Carte d'illustration officielle issue de LOUP GAROU ENHANCED
            RoleCardImage(
              role: role,
              width: 140,
              height: 190,
              borderRadius: BorderRadius.circular(16),
            ),

            const SizedBox(height: 14),

            // Rôle & Badge de camp
            Text(
              role.displayName,
              style: TextStyle(
                fontFamily: 'serif',
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
                color: teamColor,
              ),
            ),
            const SizedBox(height: 4),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: teamColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: teamColor.withValues(alpha: 0.6)),
              ),
              child: Text(
                role.isEvil
                    ? 'CAMP DES LOUPS-GAROUS 🐺'
                    : (role.defaultTeam == Team.village
                        ? 'CAMP DU VILLAGE 👥'
                        : 'SOLITAIRE / NEUTRE ✨'),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: teamColor,
                ),
              ),
            ),

            const SizedBox(height: 12),

            Text(
              role.description,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                color: LupusColors.textSecondary,
                height: 1.3,
              ),
            ),

            const SizedBox(height: 16),

            // Barre animée de compte à rebours
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: AnimatedBuilder(
                animation: _timerController,
                builder: (context, _) {
                  return LinearProgressIndicator(
                    value: 1.0 - _timerController.value,
                    minHeight: 5,
                    backgroundColor: LupusColors.surfaceLight,
                    valueColor: const AlwaysStoppedAnimation(LupusColors.arcanePurple),
                  );
                },
              ),
            ),

            const SizedBox(height: 14),

            // Bouton de confirmation immédiate
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: LupusColors.mysticPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 4,
                ),
                onPressed: _closeAndConfirm,
                icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                label: Text(
                  'J\'AI VU • CONTINUER ($_secondsRemaining s)',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
