import 'package:flutter/material.dart';

import '../../models/player_model.dart';
import '../theme/lupus_theme.dart';

/// Carrousel horizontal de sélection de cibles inspiré du composant Stitch
/// ("Choisissez votre victime • Phase d'accord").
class BentoTargetCarousel extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String icon;
  final List<PlayerModel> players;
  final String? selectedPlayerId;
  final String? currentUserId;
  final ValueChanged<String> onPlayerSelected;
  final Map<String, int>? voteCounts;
  final String voteIcon;
  final Set<int> speakingAgoraUids;
  final String? currentSpeakerId;
  final bool isMeEvil;
  final String? captainTargetVoteId;

  const BentoTargetCarousel({
    super.key,
    this.title = 'Choisissez votre cible',
    this.subtitle = 'Action requise',
    this.icon = '🎯',
    required this.players,
    required this.selectedPlayerId,
    required this.currentUserId,
    required this.onPlayerSelected,
    this.voteCounts,
    this.voteIcon = '🐾',
    this.speakingAgoraUids = const {},
    this.currentSpeakerId,
    this.isMeEvil = false,
    this.captainTargetVoteId,
  });

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // En-tête de section Stitch sans overflow
        SafeArea(
          top: false,
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  flex: 3,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(icon, style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          title.toUpperCase(),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: LupusColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(width: 6),
                  Flexible(
                    flex: 2,
                    child: Text(
                      subtitle!,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: LupusColors.arcaneGold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),

        // Carrousel horizontal de cartes
        SizedBox(
          height: 116,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: players.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final player = players[index];
              final isSelected = player.id == selectedPlayerId;
              final isMe = player.id == currentUserId;
              final votes = voteCounts?[player.id] ?? 0;

              final initials = player.name.trim().isNotEmpty
                  ? (player.name.trim().length >= 2
                      ? player.name.trim().substring(0, 2).toUpperCase()
                      : player.name.trim().substring(0, 1).toUpperCase())
                  : '??';

              final isVoiceActive = speakingAgoraUids.contains(player.agoraUid);
              final hasFloor = currentSpeakerId != null && currentSpeakerId == player.id;
              final isSpeaking = (isVoiceActive || hasFloor) && player.isAlive;
              final isWolfPeer = player.role.isEvil && isMeEvil;

              return GestureDetector(
                onTap: () => onPlayerSelected(player.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 104,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  decoration: BoxDecoration(
                    color: isWolfPeer
                        ? const Color(0xEE2A0A0A)
                        : (isSelected
                            ? const Color(0xE012172A)
                            : const Color(0xAA0D1224)),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSpeaking
                          ? const Color(0xFF00FF88)
                          : (isWolfPeer
                              ? const Color(0xFFFF2A4B)
                              : (isSelected
                                  ? LupusColors.arcaneGold
                                  : LupusColors.arcanePurple.withValues(alpha: 0.25))),
                      width: (isSpeaking || isWolfPeer) ? 2.2 : (isSelected ? 1.8 : 1.0),
                    ),
                    boxShadow: isSpeaking
                        ? [
                            const BoxShadow(
                              color: Color(0xFF00FF88),
                              blurRadius: 14,
                              spreadRadius: 2,
                            ),
                            if (isWolfPeer)
                              const BoxShadow(
                                color: Color(0xFFFF2A4B),
                                blurRadius: 14,
                                spreadRadius: 2,
                              )
                            else if (isSelected)
                              BoxShadow(
                                color: LupusColors.arcaneGold.withValues(alpha: 0.6),
                                blurRadius: 16,
                                spreadRadius: 2,
                              ),
                          ]
                        : (isWolfPeer
                            ? [
                                const BoxShadow(
                                  color: Color(0xFFFF2A4B),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                                if (isSelected)
                                  BoxShadow(
                                    color: LupusColors.arcaneGold.withValues(alpha: 0.6),
                                    blurRadius: 16,
                                    spreadRadius: 2,
                                  ),
                              ]
                            : (isSelected
                                ? LupusTheme.glowGold(opacity: 0.35)
                                : [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ])),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Avatar circulaire avec néon si parle ou rouge si allié loup
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: isWolfPeer
                              ? const LinearGradient(
                                  colors: [Color(0xFF8B1E1E), Color(0xFF3F0B0B)],
                                )
                              : (isSelected
                                  ? const LinearGradient(
                                      colors: [Color(0xFF947761), Color(0xFF5B4437)],
                                    )
                                  : const LinearGradient(
                                      colors: [Color(0xFF3F4558), Color(0xFF232734)],
                                    )),
                          border: Border.all(
                            color: isSpeaking
                                ? const Color(0xFF00FF88)
                                : (isWolfPeer
                                    ? const Color(0xFFFF2A4B)
                                    : (isSelected
                                        ? LupusColors.arcaneGold
                                        : Colors.white.withValues(alpha: 0.2))),
                            width: (isSpeaking || isWolfPeer) ? 2.2 : 1.5,
                          ),
                          boxShadow: isSpeaking
                              ? const [
                                  BoxShadow(
                                    color: Color(0xFF00FF88),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : (isWolfPeer
                                  ? const [
                                      BoxShadow(
                                        color: Color(0xFFFF2A4B),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null),
                        ),
                        child: Center(
                          child: Text(
                            initials,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: isWolfPeer ? const Color(0xFFFFD4D4) : Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),

                      // Nom du joueur avec indicateur loup si allié
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isWolfPeer) ...[
                            const Text('🐺', style: TextStyle(fontSize: 9)),
                            const SizedBox(width: 2),
                          ],
                          Flexible(
                            child: Text(
                              isMe ? '${player.name} (Moi)' : player.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: (isSelected || isWolfPeer) ? FontWeight.w800 : FontWeight.w600,
                                color: isWolfPeer
                                    ? const Color(0xFFFF6B6B)
                                    : (isSelected ? Colors.white : LupusColors.textSecondary),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),

                      // Indicateur de votes
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(voteIcon, style: const TextStyle(fontSize: 9)),
                          const SizedBox(width: 3),
                          Text(
                            '$votes vote${votes > 1 ? 's' : ''}',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? LupusColors.arcaneCyan
                                  : LupusColors.textMuted,
                            ),
                          ),
                          if (player.id == captainTargetVoteId) ...[
                            const SizedBox(width: 3),
                            const Text(
                              '⭐',
                              style: TextStyle(fontSize: 10),
                            ),
                          ],
                        ],
                      ),
                      if (player.id == captainTargetVoteId) ...[
                        const SizedBox(height: 1),
                        const Text(
                          'VOIX DU MAIRE (+2)',
                          style: TextStyle(
                            fontSize: 7.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                            color: LupusColors.arcaneGold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
