import 'package:flutter/material.dart';
import '../../services/locale_provider.dart';
import '../theme/lupus_theme.dart';

/// Boîte de dialogue de sélection de langue proposant le Français, l'Arabe et l'Anglais
/// avec drapeaux natifs et design Dark Gothic néon.
/// Utilisable tant au premier démarrage (non dismissible) que depuis le lobby (dismissible).
class LanguageDialog extends StatelessWidget {
  final bool dismissible;
  final Function(String langCode) onSelect;

  const LanguageDialog({
    super.key,
    required this.dismissible,
    required this.onSelect,
  });

  /// Affiche la boîte de dialogue si c'est le tout premier démarrage de l'application
  static Future<void> showFirstLaunchIfNeeded(
    BuildContext context,
    LocaleProvider localeProvider,
  ) async {
    final isFirst = await LocaleProvider.isFirstLaunch();
    if (isFirst && context.mounted) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 0.88),
        builder: (_) => LanguageDialog(
          dismissible: false,
          onSelect: (code) async {
            await localeProvider.setLocale(code);
          },
        ),
      );
    }
  }

  /// Ouvre la boîte de dialogue pour changer la langue en cours d'utilisation
  static Future<void> show(
    BuildContext context,
    LocaleProvider localeProvider,
  ) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (_) => LanguageDialog(
        dismissible: true,
        onSelect: (code) async {
          await localeProvider.setLocale(code);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentCode = LocaleProvider.instance.languageCode;

    return PopScope(
      canPop: dismissible,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xF20F1428),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: LupusColors.arcaneGold.withValues(alpha: 0.6),
              width: 1.5,
            ),
            boxShadow: [
              ...LupusTheme.glowGold(opacity: 0.4),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.7),
                blurRadius: 25,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icône d'en-tête
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: LupusColors.arcanePurple.withValues(alpha: 0.25),
                  border: Border.all(
                    color: LupusColors.arcaneGold.withValues(alpha: 0.7),
                    width: 1.5,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.language_rounded,
                    color: LupusColors.arcaneGold,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Titre trilingue
              const Text(
                'Langue / اللغة / Language',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Choisissez votre langue de jeu\nاختر لغة اللعبة\nChoose your game language',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: LupusColors.textSecondary.withValues(alpha: 0.9),
                  fontSize: 11.5,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 18),

              // Options de langue
              _buildLangTile(
                context,
                label: 'Français',
                flag: '🇫🇷',
                code: 'fr',
                isSelected: currentCode == 'fr',
              ),
              const SizedBox(height: 10),
              _buildLangTile(
                context,
                label: 'العربية',
                flag: '🇩🇿',
                code: 'ar',
                isSelected: currentCode == 'ar',
              ),
              const SizedBox(height: 10),
              _buildLangTile(
                context,
                label: 'English',
                flag: '🇬🇧',
                code: 'en',
                isSelected: currentCode == 'en',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLangTile(
    BuildContext context, {
    required String label,
    required String flag,
    required String code,
    required bool isSelected,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          onSelect(code);
          Navigator.of(context).pop();
        },
        child: Ink(
          decoration: BoxDecoration(
            color: isSelected
                ? LupusColors.arcanePurple.withValues(alpha: 0.35)
                : const Color(0xFF181E38),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? LupusColors.arcaneGold
                  : LupusColors.border.withValues(alpha: 0.6),
              width: isSelected ? 1.6 : 1.0,
            ),
            boxShadow: isSelected ? LupusTheme.glowGold(opacity: 0.3) : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Text(flag, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? LupusColors.arcaneGold : Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: LupusColors.arcaneGold,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
