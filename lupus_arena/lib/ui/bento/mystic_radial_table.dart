import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../models/player_model.dart';
import '../theme/lupus_theme.dart';

/// Table mystique circulaire inspirée directement du design Stitch (Screen 2: Table de Nuit Ultime).
/// Dispose les joueurs (jusqu'à 16) de façon radiale et symétrique autour d'un sceau arcanique
/// avec anneaux runiques, état de parole Agora, indicateurs de mort/capitaine/amoureux et sélection de cible.
class MysticRadialTable extends StatefulWidget {
  final List<PlayerModel> players;
  final String? selectedPlayerId;
  final String? currentUserId;
  final Set<int> speakingAgoraUids;
  final String? currentSpeakerId;
  final bool revealRoles;
  final bool isMeEvil;
  final ValueChanged<String> onPlayerSelected;
  final Map<String, int>? voteCounts;
  final String? centerActionTitle;
  final String? centerActionSubtitle;
  final String? captainTargetVoteId;

  const MysticRadialTable({
    super.key,
    required this.players,
    required this.selectedPlayerId,
    required this.currentUserId,
    required this.speakingAgoraUids,
    this.currentSpeakerId,
    this.revealRoles = false,
    this.isMeEvil = false,
    required this.onPlayerSelected,
    this.voteCounts,
    this.centerActionTitle,
    this.centerActionSubtitle,
    this.captainTargetVoteId,
  });

  @override
  State<MysticRadialTable> createState() => _MysticRadialTableState();
}

class _MysticRadialTableState extends State<MysticRadialTable>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 90),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double tableSize = 280.0;
    final radius = (tableSize / 2) - 28.0;
    final totalPlayers = widget.players.length;

    // Trouver le joueur actuellement sélectionné
    PlayerModel? selectedPlayer;
    if (widget.selectedPlayerId != null) {
      for (final p in widget.players) {
        if (p.id == widget.selectedPlayerId) {
          selectedPlayer = p;
          break;
        }
      }
    }

    return Center(
      child: SizedBox(
        width: tableSize,
        height: tableSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 1. Cercle magique d'arrière-plan avec dégradé radial
            Container(
              width: tableSize - 20,
              height: tableSize - 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    LupusColors.arcaneViolet.withValues(alpha: 0.18),
                    LupusColors.arcanePurple.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.65, 1.0],
                ),
                border: Border.all(
                  color: LupusColors.arcanePurple.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
            ),

            // 2. Anneau runique animé en rotation douce
            AnimatedBuilder(
              animation: _rotationController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _rotationController.value * 2 * math.pi,
                  child: Container(
                    width: tableSize - 60,
                    height: tableSize - 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: LupusColors.arcaneCyan.withValues(alpha: 0.20),
                        width: 1.5,
                        strokeAlign: BorderSide.strokeAlignCenter,
                      ),
                    ),
                  ),
                );
              },
            ),

            // 3. Anneau doré intérieur
            Container(
              width: tableSize - 120,
              height: tableSize - 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: LupusColors.arcaneGold.withValues(alpha: 0.20),
                  width: 1,
                ),
              ),
            ),

            // 4. Carte d'état de cible au centre de la table mystique
            _buildCenterTargetCard(selectedPlayer),

            // 5. Noeuds radiaux des joueurs disposés à 360°
            for (int i = 0; i < totalPlayers; i++)
              _buildRadialPlayerNode(
                player: widget.players[i],
                index: i,
                total: totalPlayers,
                radius: radius,
                center: tableSize / 2,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterTargetCard(PlayerModel? selectedPlayer) {
    return Container(
      width: 126,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xCC0A0F1E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selectedPlayer != null
              ? LupusColors.arcaneGold.withValues(alpha: 0.6)
              : LupusColors.arcanePurple.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: selectedPlayer != null
            ? LupusTheme.glowGold(opacity: 0.35)
            : LupusTheme.glowPurple(opacity: 0.25),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Badge CIBLE avec indicateur clignotant
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0x992B0D14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: LupusColors.arcaneCrimson.withValues(alpha: 0.45),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: LupusColors.arcaneCrimson,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  widget.centerActionTitle ?? 'CIBLE',
                  style: const TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: Color(0xFFFCA5A5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 5),

          // Nom de la cible sélectionnée
          Text(
            selectedPlayer != null
                ? selectedPlayer.name
                : (widget.centerActionSubtitle ?? 'Aucune cible'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: selectedPlayer != null ? Colors.white : LupusColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),

          // Message d'aide
          Text(
            selectedPlayer != null
                ? (selectedPlayer.isAlive ? 'Prêt à agir' : 'Éliminé(e)')
                : 'Touchez un joueur',
            style: const TextStyle(
              fontSize: 8.5,
              color: LupusColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadialPlayerNode({
    required PlayerModel player,
    required int index,
    required int total,
    required double radius,
    required double center,
  }) {
    final isSelected = player.id == widget.selectedPlayerId;
    final isMe = player.id == widget.currentUserId;
    final isVoiceActive = widget.speakingAgoraUids.contains(player.agoraUid);
    final hasFloor = widget.currentSpeakerId != null && widget.currentSpeakerId == player.id;
    final isSpeaking = (isVoiceActive || hasFloor) && player.isAlive;
    final isWolfPeer = player.role.isEvil && (widget.isMeEvil || widget.revealRoles);
    final isDead = !player.isAlive;
    final votes = widget.voteCounts?[player.id] ?? 0;

    final double nodeWidth = total > 20 ? 32.0 : (total > 14 ? 38.0 : 44.0);
    final double avatarSize = total > 20
        ? (isSelected ? 28.0 : 25.0)
        : (total > 14 ? (isSelected ? 36.0 : 32.0) : (isSelected ? 42.0 : 38.0));

    // Calcul de l'angle à partir du sommet (-pi/2)
    final double angle = (2 * math.pi * index / total) - (math.pi / 2);
    final double x = center + (radius * math.cos(angle)) - (nodeWidth / 2);
    final double y = center + (radius * math.sin(angle)) - (nodeWidth / 2);

    // Initiales
    final initials = player.name.trim().isNotEmpty
        ? (player.name.trim().length >= 2
            ? player.name.trim().substring(0, 2).toUpperCase()
            : player.name.trim().substring(0, 1).toUpperCase())
        : '??';

    return Positioned(
      left: x,
      top: y,
      child: GestureDetector(
        onTap: () => widget.onPlayerSelected(player.id),
        child: SizedBox(
          width: nodeWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Jeton de joueur
              Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // 1. Onde de choc et halo néon pulsant pour celui qui a la parole
                  if (isSpeaking)
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        final pulse = _pulseAnimation.value;
                        return Container(
                          width: avatarSize + 10 + (6 * pulse),
                          height: avatarSize + 10 + (6 * pulse),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF00FF88).withValues(alpha: 0.9 * pulse),
                              width: 2.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00FF88).withValues(alpha: 0.75 * pulse),
                                blurRadius: 14 + (6 * pulse),
                                spreadRadius: 3 + (3 * pulse),
                              ),
                              BoxShadow(
                                color: const Color(0xFF38BDF8).withValues(alpha: 0.45 * pulse),
                                blurRadius: 22,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: avatarSize,
                    height: avatarSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isDead
                          ? const LinearGradient(
                              colors: [Color(0xFF1E212D), Color(0xFF12141C)],
                            )
                          : (isWolfPeer
                              ? const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Color(0xFF8B1E1E), Color(0xFF3F0B0B)],
                                )
                              : (isMe
                                  ? const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [Color(0xFF8D705C), Color(0xFF5A4335)],
                                    )
                                  : const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [Color(0xFF3F4558), Color(0xFF232734)],
                                    ))),
                      border: Border.all(
                        color: isSpeaking
                            ? const Color(0xFF00FF88) // Tour de néon électrique vibrant si parle
                            : (isWolfPeer
                                ? const Color(0xFFFF2A4B) // Bordure rouge sang néon pour les loups
                                : (isSelected
                                    ? LupusColors.arcaneGold
                                    : (isDead
                                        ? LupusColors.arcaneCrimson.withValues(alpha: 0.45)
                                        : (isMe
                                            ? LupusColors.arcaneGold.withValues(alpha: 0.6)
                                            : LupusColors.arcanePurple.withValues(alpha: 0.35))))),
                        width: (isSpeaking || isWolfPeer)
                            ? 3.0 // Contour néon / rouge sang bien affirmé
                            : (isSelected
                                ? 2.5
                                : 1.2),
                      ),
                      boxShadow: isSpeaking
                          ? [
                              const BoxShadow(
                                color: Color(0xFF00FF88),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                              if (isWolfPeer)
                                const BoxShadow(
                                  color: Color(0xFFFF2A4B),
                                  blurRadius: 14,
                                  spreadRadius: 2,
                                ),
                              if (isSelected)
                                BoxShadow(
                                  color: LupusColors.arcaneGold.withValues(alpha: 0.7),
                                  blurRadius: 16,
                                  spreadRadius: 3,
                                ),
                            ]
                          : (isWolfPeer
                              ? [
                                  const BoxShadow(
                                    color: Color(0xFFFF2A4B),
                                    blurRadius: 14,
                                    spreadRadius: 2.5,
                                  ),
                                  if (isSelected)
                                    BoxShadow(
                                      color: LupusColors.arcaneGold.withValues(alpha: 0.7),
                                      blurRadius: 16,
                                      spreadRadius: 3,
                                    ),
                                ]
                              : (isSelected
                                  ? LupusTheme.glowGold(opacity: 0.6)
                                  : null)),
                    ),
                    child: Center(
                      child: isDead
                          ? const Text(
                              '✕',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: LupusColors.arcaneCrimson,
                              ),
                            )
                          : Text(
                              initials,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: isWolfPeer
                                    ? const Color(0xFFFFD4D4)
                                    : (isMe ? const Color(0xFFFFF0D0) : Colors.white),
                              ),
                            ),
                    ),
                  ),

                  // Badge Micro Néon pour celui qui a la parole
                  if (isSpeaking)
                    Positioned(
                      bottom: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF070B1D),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF00FF88),
                            width: 1.5,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0xFF00FF88),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: const Text(
                          '🎙️',
                          style: TextStyle(fontSize: 8.5),
                        ),
                      ),
                    ),

                  // Badge Allié Loup-Garou (visible pour les loups)
                  if (isWolfPeer)
                    Positioned(
                      top: -7,
                      left: -7,
                      child: Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B1E1E),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFFF5252), width: 1.2),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0xFFFF2A4B),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: const Text('🐺', style: TextStyle(fontSize: 10)),
                      ),
                    ),

                  // Badge Capitaine (Étoile dorée)
                  if (player.isCaptain)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: LupusColors.arcaneGold,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.star_rounded, size: 9, color: Colors.black),
                      ),
                    ),

                  // Badge Amoureux (Cœur)
                  if (player.isLover)
                    Positioned(
                      top: -4,
                      left: -4,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Color(0xFFE63946),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.favorite_rounded, size: 9, color: Colors.white),
                      ),
                    ),

                  // Badge Maison Imbibée de Carburant (Pyromane)
                  if (player.isDoused && (widget.revealRoles || isMe))
                    Positioned(
                      bottom: -4,
                      left: -4,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF4800),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.local_fire_department_rounded, size: 9, color: Colors.white),
                      ),
                    ),

                  // Badge de votes reçus (avec étoile dorée si ciblé par le vote du Maire)
                  if (votes > 0)
                    Positioned(
                      bottom: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: (widget.captainTargetVoteId == player.id)
                              ? const Color(0xFFD97706) // Doré/Ambre pour vote du Maire
                              : LupusColors.arcaneCrimson,
                          borderRadius: BorderRadius.circular(6),
                          border: (widget.captainTargetVoteId == player.id)
                              ? Border.all(color: LupusColors.arcaneGold, width: 1.2)
                              : null,
                          boxShadow: (widget.captainTargetVoteId == player.id)
                              ? [
                                  BoxShadow(
                                    color: LupusColors.arcaneGold.withValues(alpha: 0.6),
                                    blurRadius: 6,
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.captainTargetVoteId == player.id) ...[
                              const Icon(Icons.star_rounded, size: 8, color: Colors.white),
                              const SizedBox(width: 1),
                            ],
                            Text(
                              '$votes',
                              style: const TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),

              // Nom et numéro de siège avec icône loup si allié
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isWolfPeer) ...[
                    const Text('🐺', style: TextStyle(fontSize: 8.5)),
                    const SizedBox(width: 2),
                  ],
                  Flexible(
                    child: Text(
                      '#${index + 1} ${player.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: (isSelected || isWolfPeer) ? FontWeight.w800 : FontWeight.w500,
                        color: isWolfPeer
                            ? const Color(0xFFFF5252)
                            : (isDead
                                ? LupusColors.textMuted
                                : (isSelected ? LupusColors.arcaneGold : LupusColors.textSecondary)),
                      ),
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
