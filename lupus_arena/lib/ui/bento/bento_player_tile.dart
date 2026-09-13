import 'package:flutter/material.dart';

import '../../models/player_model.dart';
import '../theme/lupus_theme.dart';
import 'bento_card.dart';

/// Tuile individuelle représentant un joueur dans la grille Bento
class BentoPlayerTile extends StatelessWidget {
  final PlayerModel player;
  final bool isMe;
  final bool isSpeaking;
  final bool isSelected;
  final int votesCount;
  final bool showRole;
  final bool isWolfPeer;
  final VoidCallback? onTap;

  const BentoPlayerTile({
    super.key,
    required this.player,
    this.isMe = false,
    this.isSpeaking = false,
    this.isSelected = false,
    this.votesCount = 0,
    this.showRole = false,
    this.isWolfPeer = false,
    this.onTap,
  });

  // Liste d'avatars thématiques
  static const List<IconData> avatarIcons = [
    Icons.face_retouching_natural_rounded,
    Icons.military_tech_rounded,
    Icons.psychology_rounded,
    Icons.smart_toy_rounded,
    Icons.masks_rounded,
    Icons.person_pin_circle_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final isDead = !player.isAlive;
    final icon = avatarIcons[player.avatarIndex % avatarIcons.length];

    Color borderColor;
    if (isSpeaking && player.isAlive) {
      borderColor = const Color(0xFF00FF88);
    } else if (isSelected) {
      borderColor = LupusColors.bloodRed;
    } else if (isDead) {
      borderColor = Colors.black45;
    } else if (isWolfPeer && player.isAlive) {
      borderColor = LupusColors.bloodRed.withValues(alpha: 0.7);
    } else {
      borderColor = LupusColors.border;
    }

    return BentoCard(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      onTap: onTap,
      borderColor: borderColor,
      glowing: isSpeaking && player.isAlive,
      backgroundColor: isDead
          ? const Color(0xFF0F1117)
          : (isSelected
              ? LupusColors.bloodRed.withValues(alpha: 0.15)
              : LupusColors.surface),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Avatar avec badge parole / badge mort
          SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // Halo lumineux si le joueur parle
                if (isSpeaking && player.isAlive)
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF00FF88),
                        width: 2.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFF00FF88).withValues(alpha: 0.8),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),

                // Rond d'avatar principal
                CircleAvatar(
                  radius: 18,
                  backgroundColor: isDead
                      ? const Color(0xFF202025)
                      : (isMe
                          ? LupusColors.moonIndigo.withValues(alpha: 0.3)
                          : LupusColors.surfaceLight),
                  child: Icon(
                    isDead ? Icons.sentiment_very_dissatisfied_rounded : icon,
                    color: isDead
                        ? LupusColors.textMuted
                        : (isMe
                            ? LupusColors.moonIndigo
                            : LupusColors.textPrimary),
                    size: 20,
                  ),
                ),

                // Indicateur mort (tête de mort rouge)
                if (isDead)
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(1.5),
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.cancel_rounded,
                        color: LupusColors.bloodRed,
                        size: 14,
                      ),
                    ),
                  ),

                // Indicateur micro actif (ondes vertes)
                if (isSpeaking && player.isAlive)
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF070B1D),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF00FF88),
                          width: 1.2,
                        ),
                      ),
                      child: const Icon(
                        Icons.graphic_eq_rounded,
                        color: Color(0xFF00FF88),
                        size: 11,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 2. Nom du joueur et badges de statut
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (player.isHost) ...[
                  const Icon(Icons.star_rounded,
                      size: 12, color: LupusColors.sunAmber),
                  const SizedBox(width: 2),
                ],
                if (player.isCaptain) ...[
                  const Icon(Icons.military_tech_rounded,
                      size: 12, color: Color(0xFFFFD700)),
                  const SizedBox(width: 2),
                ],
                if (isWolfPeer && !isMe) ...[
                  const Text('🐺', style: TextStyle(fontSize: 10)),
                  const SizedBox(width: 2),
                ],
                if (player.isLover && (isMe || showRole)) ...[
                  const Icon(Icons.favorite_rounded,
                      size: 11, color: LupusColors.bloodRed),
                  const SizedBox(width: 2),
                ],
                if (player.isDoused && (isMe || showRole)) ...[
                  const Icon(Icons.local_fire_department_rounded,
                      size: 11, color: Color(0xFFFF4800)),
                  const SizedBox(width: 2),
                ],
                Flexible(
                  child: Text(
                    player.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isMe ? FontWeight.w800 : FontWeight.w600,
                      color: isDead
                          ? LupusColors.textMuted
                          : (isWolfPeer && !isMe
                              ? const Color(0xFFFF8B8B)
                              : (isMe
                                  ? LupusColors.moonIndigo
                                  : LupusColors.textPrimary)),
                      decoration: isDead ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. Rôle ou État de Vie
          if (showRole || isDead || isMe || isWolfPeer) ...[
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: (isWolfPeer && !isMe && !showRole)
                    ? LupusColors.bloodRed.withValues(alpha: 0.25)
                    : player.role.accentColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: (isWolfPeer && !isMe && !showRole)
                      ? LupusColors.bloodRed.withValues(alpha: 0.6)
                      : player.role.accentColor.withValues(alpha: 0.4),
                  width: 0.8,
                ),
              ),
              child: Text(
                (isWolfPeer && !isMe && !showRole)
                    ? '🐺 ${player.role.displayName}'
                    : player.role.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  color: (isWolfPeer && !isMe && !showRole)
                      ? const Color(0xFFFF8B8B)
                      : player.role.accentColor,
                ),
              ),
            ),
          ] else ...[
            Text(
              isDead ? 'ÉLIMINÉ' : 'VIVANT',
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
                color: isDead ? LupusColors.textMuted : LupusColors.poisonGreen,
                letterSpacing: 0.6,
              ),
            ),
          ],

          // 4. Badge du nombre de votes reçus (s'il y en a)
          if (votesCount > 0)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: LupusColors.bloodRed,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$votesCount ${votesCount > 1 ? "votes" : "vote"}',
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
