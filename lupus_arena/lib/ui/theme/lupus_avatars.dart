import 'package:flutter/material.dart';

/// Définition d'un avatar thématique Dark Fantasy pour Lupus Arena
class LupusAvatarItem {
  final int id;
  final String name;
  final String emoji;
  final IconData icon;
  final List<Color> gradientColors;
  final Color borderColor;
  final Color glowColor;

  const LupusAvatarItem({
    required this.id,
    required this.name,
    required this.emoji,
    required this.icon,
    required this.gradientColors,
    required this.borderColor,
    required this.glowColor,
  });
}

/// Collection officielle des 12 Avatars Dark Fantasy du jeu
class LupusAvatars {
  static const List<LupusAvatarItem> all = [
    LupusAvatarItem(
      id: 0,
      name: 'Loup Alpha',
      emoji: '🐺',
      icon: Icons.nights_stay_rounded,
      gradientColors: [Color(0xFF881337), Color(0xFF4C0519), Color(0xFF1E0108)],
      borderColor: Color(0xFFFB7185),
      glowColor: Color(0x66E11D48),
    ),
    LupusAvatarItem(
      id: 1,
      name: 'Chevalier à l\'Épée',
      emoji: '⚔️',
      icon: Icons.shield_rounded,
      gradientColors: [Color(0xFF854D0E), Color(0xFF451A03), Color(0xFF1F0C02)],
      borderColor: Color(0xFFFDE047),
      glowColor: Color(0x66EAB308),
    ),
    LupusAvatarItem(
      id: 2,
      name: 'Grande Sorcière',
      emoji: '🧪',
      icon: Icons.auto_fix_high_rounded,
      gradientColors: [Color(0xFF581C87), Color(0xFF2E1065), Color(0xFF120329)],
      borderColor: Color(0xFFC084FC),
      glowColor: Color(0x66A855F7),
    ),
    LupusAvatarItem(
      id: 3,
      name: 'Voyante Céleste',
      emoji: '🔮',
      icon: Icons.visibility_rounded,
      gradientColors: [Color(0xFF312E81), Color(0xFF1E1B4B), Color(0xFF0C0A29)],
      borderColor: Color(0xFF818CF8),
      glowColor: Color(0x666366F1),
    ),
    LupusAvatarItem(
      id: 4,
      name: 'Chasseur Embusqué',
      emoji: '🏹',
      icon: Icons.crisis_alert_rounded,
      gradientColors: [Color(0xFF991B1B), Color(0xFF530A0A), Color(0xFF230303)],
      borderColor: Color(0xFFF87171),
      glowColor: Color(0x66EF4444),
    ),
    LupusAvatarItem(
      id: 5,
      name: 'Protecteur / Salvateur',
      emoji: '🛡️',
      icon: Icons.security_rounded,
      gradientColors: [Color(0xFF075985), Color(0xFF082F49), Color(0xFF031420)],
      borderColor: Color(0xFF38BDF8),
      glowColor: Color(0x660EA5E9),
    ),
    LupusAvatarItem(
      id: 6,
      name: 'Pyromancien',
      emoji: '🔥',
      icon: Icons.local_fire_department_rounded,
      gradientColors: [Color(0xFF9A3412), Color(0xFF431407), Color(0xFF1C0602)],
      borderColor: Color(0xFFFB923C),
      glowColor: Color(0x66F97316),
    ),
    LupusAvatarItem(
      id: 7,
      name: 'Joueur de Flûte',
      emoji: '🪈',
      icon: Icons.music_note_rounded,
      gradientColors: [Color(0xFF065F46), Color(0xFF022C22), Color(0xFF01120E)],
      borderColor: Color(0xFF34D399),
      glowColor: Color(0x6610B981),
    ),
    LupusAvatarItem(
      id: 8,
      name: 'Voleur d\'Âmes',
      emoji: '🎭',
      icon: Icons.masks_rounded,
      gradientColors: [Color(0xFF27272A), Color(0xFF18181B), Color(0xFF09090B)],
      borderColor: Color(0xFFA1A1AA),
      glowColor: Color(0x6671717A),
    ),
    LupusAvatarItem(
      id: 9,
      name: 'Enfant Sauvage',
      emoji: '🌲',
      icon: Icons.pets_rounded,
      gradientColors: [Color(0xFF166534), Color(0xFF052E16), Color(0xFF021309)],
      borderColor: Color(0xFF4ADE80),
      glowColor: Color(0x6622C55E),
    ),
    LupusAvatarItem(
      id: 10,
      name: 'Maire',
      emoji: '👑',
      icon: Icons.military_tech_rounded,
      gradientColors: [Color(0xFFB45309), Color(0xFF78350F), Color(0xFF321303)],
      borderColor: Color(0xFFFBBF24),
      glowColor: Color(0x66F59E0B),
    ),
    LupusAvatarItem(
      id: 11,
      name: 'Grand Ancien',
      emoji: '📜',
      icon: Icons.menu_book_rounded,
      gradientColors: [Color(0xFF3730A3), Color(0xFF1E1B4B), Color(0xFF0A0724)],
      borderColor: Color(0xFFA5B4FC),
      glowColor: Color(0x66818CF8),
    ),
  ];

  /// Récupère un avatar par index avec boucle circulaire sécurisée
  static LupusAvatarItem getByIndex(int index) {
    if (all.isEmpty) {
      return const LupusAvatarItem(
        id: 0,
        name: 'Loup Alpha',
        emoji: '🐺',
        icon: Icons.nights_stay_rounded,
        gradientColors: [Color(0xFF881337), Color(0xFF4C0519)],
        borderColor: Color(0xFFFB7185),
        glowColor: Color(0x66E11D48),
      );
    }
    final safeIndex = (index >= 0 ? index : 0) % all.length;
    return all[safeIndex];
  }

  /// Liste des icônes pour compatibilité descendante
  static List<IconData> get icons => all.map((a) => a.icon).toList();
}
