import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../GameNotifier.dart';
import '../theme/lupus_theme.dart';
import 'admin_control_sheet.dart';

/// Boîte de dialogue secrète demandant le code PIN à 8 chiffres ("03031994")
/// pour déverrouiller le statut Maître du Jeu / God Mode.
class AdminSecretDialog extends ConsumerStatefulWidget {
  const AdminSecretDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (_) => const AdminSecretDialog(),
    );
  }

  @override
  ConsumerState<AdminSecretDialog> createState() => _AdminSecretDialogState();
}

class _AdminSecretDialogState extends ConsumerState<AdminSecretDialog> {
  String _enteredPin = '';
  String? _errorMessage;

  void _onDigitPressed(String digit) {
    if (_enteredPin.length >= 8) return;
    setState(() {
      _errorMessage = null;
      _enteredPin += digit;
    });

    if (_enteredPin.length == 8) {
      _validatePin();
    }
  }

  void _onBackspace() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _errorMessage = null;
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
    }
  }

  void _onClear() {
    setState(() {
      _errorMessage = null;
      _enteredPin = '';
    });
  }

  void _validatePin() {
    final success =
        ref.read(gameNotifierProvider.notifier).unlockAdmin(_enteredPin);

    if (success) {
      Navigator.of(context).pop();
      AdminControlSheet.show(context);
    } else {
      setState(() {
        _errorMessage = 'Code administrateur invalide';
        _enteredPin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: 340,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xF00A0F1E),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: LupusColors.arcaneGold.withValues(alpha: 0.6),
            width: 1.5,
          ),
          boxShadow: LupusTheme.glowGold(opacity: 0.4),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // En-tête avec couronne dorée
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [Color(0xFF422006), Color(0xFF1B172A)],
                ),
                border: Border.all(
                  color: LupusColors.arcaneGold,
                  width: 1.5,
                ),
                boxShadow: LupusTheme.glowGold(opacity: 0.35),
              ),
              child: const Center(
                child: Text('👑', style: TextStyle(fontSize: 24)),
              ),
            ),
            const SizedBox(height: 12),

            const Text(
              'ACCÈS MAÎTRE DU JEU',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'serif',
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: LupusColors.arcaneGold,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Saisissez le code d\'autorisation secret (8 chiffres)',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: LupusColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),

            // Indicateurs de chiffres (8 cercles / tirets)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(8, (index) {
                final isFilled = index < _enteredPin.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFilled
                        ? LupusColors.arcaneGold
                        : const Color(0xFF1E243D),
                    border: Border.all(
                      color: isFilled
                          ? LupusColors.arcaneGold
                          : LupusColors.arcanePurple.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                    boxShadow: isFilled
                        ? LupusTheme.glowGold(opacity: 0.5)
                        : null,
                  ),
                );
              }),
            ),
            const SizedBox(height: 14),

            // Message d'erreur éventuel
            if (_errorMessage != null) ...[
              Text(
                _errorMessage!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: LupusColors.arcaneCrimson,
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Pavé numérique compact
            _buildKeypad(),
            const SizedBox(height: 10),

            // Bouton Annuler
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Annuler',
                style: TextStyle(
                  color: LupusColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['C', '0', '⌫'],
    ];

    return Column(
      children: keys.map((row) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((key) {
              final isAction = key == 'C' || key == '⌫';
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: InkWell(
                  onTap: () {
                    if (key == 'C') {
                      _onClear();
                    } else if (key == '⌫') {
                      _onBackspace();
                    } else {
                      _onDigitPressed(key);
                    }
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 58,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isAction
                          ? const Color(0x661E243D)
                          : const Color(0xCC12172A),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        key,
                        style: TextStyle(
                          fontSize: isAction ? 14 : 18,
                          fontWeight: FontWeight.w800,
                          color: isAction
                              ? LupusColors.arcaneGold
                              : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}
