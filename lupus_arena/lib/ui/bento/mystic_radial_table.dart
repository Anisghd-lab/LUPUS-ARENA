import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../models/player_model.dart';
import '../../services/app_translations.dart';
import '../theme/lupus_theme.dart';
import 'revealed_death_card_overlay.dart';

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
  final bool isGodModeActive;
  final bool isDevRoom;
  final GameRole myRole;
  final Map<String, GameRole> seerInspectedRoles;
  final Set<String> wolfPlayerIds;
  final ValueChanged<String> onPlayerSelected;
  final Map<String, int>? voteCounts;
  final String? centerActionTitle;
  final String? centerActionSubtitle;
  final String? captainTargetVoteId;
  final List<DeathAnnouncementEvent>? deathQueue;
  final VoidCallback? onDeathSequenceCompleted;

  const MysticRadialTable({
    super.key,
    required this.players,
    required this.selectedPlayerId,
    required this.currentUserId,
    required this.speakingAgoraUids,
    this.currentSpeakerId,
    this.revealRoles = false,
    this.isMeEvil = false,
    this.isGodModeActive = false,
    this.isDevRoom = false,
    this.myRole = GameRole.simpleVillager,
    this.seerInspectedRoles = const {},
    this.wolfPlayerIds = const {},
    required this.onPlayerSelected,
    this.voteCounts,
    this.centerActionTitle,
    this.centerActionSubtitle,
    this.captainTargetVoteId,
    this.deathQueue,
    this.onDeathSequenceCompleted,
  });

  @override
  State<MysticRadialTable> createState() => _MysticRadialTableState();
}

class _MysticRadialTableState extends State<MysticRadialTable>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Animation de clignotement doré lors de la passation de pouvoir du Capitaine
  String? _currentCaptainId;
  String? _animatingNewCaptainId;
  late AnimationController _captainFlashController;
  late Animation<double> _captainFlashAnimation;

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

    _currentCaptainId = _findCurrentCaptainId(widget.players);
    _captainFlashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _captainFlashAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.0), weight: 25),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.2), weight: 25),
      TweenSequenceItem(tween: Tween<double>(begin: 0.2, end: 1.0), weight: 25),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.0), weight: 25),
    ]).animate(CurvedAnimation(
      parent: _captainFlashController,
      curve: Curves.easeInOut,
    ));

    _captainFlashController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          setState(() {
            _animatingNewCaptainId = null;
          });
        }
      }
    });
  }

  @override
  void didUpdateWidget(covariant MysticRadialTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newCaptainId = _findCurrentCaptainId(widget.players);
    if (newCaptainId != null &&
        _currentCaptainId != null &&
        newCaptainId != _currentCaptainId) {
      // Passation autoritaire détectée : clignotement doré du nouvel élu
      _animatingNewCaptainId = newCaptainId;
      _captainFlashController.forward(from: 0.0);
    }
    _currentCaptainId = newCaptainId;
  }

  String? _findCurrentCaptainId(List<PlayerModel> players) {
    for (final p in players) {
      if (p.isCaptain && p.isAlive) {
        return p.id;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _captainFlashController.dispose();
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

            // 4. Carte d'état de cible OU Séquence cinématique 3D des défunts au centre
            if (widget.deathQueue != null && widget.deathQueue!.isNotEmpty)
              RevealedDeathCardOverlay(
                key: ValueKey(widget.deathQueue!.map((e) => e.playerId).join('_')),
                queue: widget.deathQueue!,
                onSequenceCompleted: widget.onDeathSequenceCompleted,
              )
            else
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
                  widget.centerActionTitle ?? context.tr('target'),
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
                : (widget.centerActionSubtitle ?? context.tr('no_target')),
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

          // Affichage sécurisé du rôle de la cible (uniquement si autorisé)
          if (selectedPlayer != null) ...[
            Builder(
              builder: (context) {
                final isTargetMe = selectedPlayer.id == widget.currentUserId;
                final isTargetDead = !selectedPlayer.isAlive;
                final isTargetGodMode =
                    widget.isGodModeActive && widget.isDevRoom;
                final isTargetWolf = (widget.isMeEvil ||
                        widget.myRole.isEvil ||
                        (widget.currentUserId != null &&
                            widget.wolfPlayerIds
                                .contains(widget.currentUserId))) &&
                    (selectedPlayer.role.isEvil ||
                        widget.wolfPlayerIds.contains(selectedPlayer.id));
                final targetSeerRole =
                    widget.seerInspectedRoles[selectedPlayer.id];

                String? roleText;
                Color? roleColor;

                if (isTargetMe) {
                  roleText = context.tr('my_role_label',
                      {'role': selectedPlayer.role.displayName});
                  roleColor = selectedPlayer.role.accentColor;
                } else if (isTargetDead) {
                  roleText = selectedPlayer.roleInitial.displayName;
                  roleColor = selectedPlayer.roleInitial.accentColor;
                } else if (targetSeerRole != null) {
                  roleText = '🔮 ${targetSeerRole.displayName}';
                  roleColor = targetSeerRole.accentColor;
                } else if (isTargetWolf) {
                  final wolfName = (selectedPlayer.role == GameRole.whiteWerewolf)
                      ? 'Loup Blanc'
                      : (selectedPlayer.role.isEvil && selectedPlayer.role != GameRole.simpleVillager)
                          ? selectedPlayer.role.displayName
                          : 'Loup-Garou';
                  roleText = '🐺 $wolfName';
                  roleColor = const Color(0xFFFF8B8B);
                } else if (isTargetGodMode) {
                  roleText = selectedPlayer.estDechu
                      ? '${selectedPlayer.role.displayName} (Ex-${selectedPlayer.roleInitial.displayName})'
                      : selectedPlayer.role.displayName;
                  roleColor = selectedPlayer.role.accentColor;
                }

                if (roleText != null) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      roleText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: roleColor,
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],

          // Message d'aide
          Text(
            selectedPlayer != null
                ? (selectedPlayer.isAlive
                    ? context.tr('ready_to_act')
                    : context.tr('eliminated'))
                : context.tr('tap_a_player'),
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
    final isGodMode = widget.isGodModeActive && widget.isDevRoom;
    final isWolfPeer = (player.role.isEvil ||
            widget.wolfPlayerIds.contains(player.id)) &&
        (widget.isMeEvil ||
            widget.myRole.isEvil ||
            (widget.currentUserId != null &&
                widget.wolfPlayerIds.contains(widget.currentUserId)) ||
            isGodMode);
    final seerDiscoveredRole = widget.seerInspectedRoles[player.id];
    final isDead = !player.isAlive;
    final votes = widget.voteCounts?[player.id] ?? 0;
    final isNewCaptainFlashing =
        (player.id == _animatingNewCaptainId) && _captainFlashController.isAnimating;

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
        behavior: HitTestBehavior.opaque,
        onTap: player.isAlive ? () => widget.onPlayerSelected(player.id) : null,
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

                  AnimatedBuilder(
                    animation: _captainFlashAnimation,
                    builder: (context, child) {
                      final flash = isNewCaptainFlashing ? _captainFlashAnimation.value : 0.0;
                      return Transform.scale(
                        scale: 1.0 + (0.08 * flash),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: avatarSize,
                          height: avatarSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: isDead
                                ? const LinearGradient(
                                    colors: [Color(0xFF1E212D), Color(0xFF12141C)],
                                  )
                                : ((isWolfPeer && !isMe)
                                    ? const LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [Color(0xFF8B1E1E), Color(0xFF3F0B0B)],
                                      )
                                    : (seerDiscoveredRole != null && !isMe)
                                        ? const LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [Color(0xFF312E81), Color(0xFF1E1B4B)],
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
                              color: isNewCaptainFlashing
                                  ? Color.lerp(LupusColors.arcaneGold, Colors.white, flash)!
                                  : (isSpeaking
                                      ? const Color(0xFF00FF88) // Tour de néon électrique vibrant si parle
                                      : ((isWolfPeer && !isMe)
                                          ? const Color(0xFFFF2A4B) // Bordure rouge sang néon pour les loups
                                          : (seerDiscoveredRole != null && !isMe)
                                              ? const Color(0xFF818CF8) // Bordure violette néon pour rôle sondé
                                              : (isSelected
                                                  ? LupusColors.arcaneGold
                                                  : (isDead
                                                      ? LupusColors.arcaneCrimson.withValues(alpha: 0.45)
                                                      : (isMe
                                                          ? LupusColors.arcaneGold.withValues(alpha: 0.6)
                                                          : LupusColors.arcanePurple.withValues(alpha: 0.35)))))),
                              width: isNewCaptainFlashing
                                  ? (2.5 + (1.5 * flash))
                                  : ((isSpeaking || ((isWolfPeer || seerDiscoveredRole != null) && !isMe))
                                      ? 3.0 // Contour néon / rouge sang bien affirmé
                                      : (isSelected
                                          ? 2.5
                                          : 1.2)),
                            ),
                            boxShadow: isNewCaptainFlashing
                                ? [
                                    BoxShadow(
                                      color: LupusColors.arcaneGold.withValues(alpha: 0.9 * flash),
                                      blurRadius: 18 * flash,
                                      spreadRadius: 3.5 * flash,
                                    ),
                                    if (isSelected)
                                      BoxShadow(
                                        color: LupusColors.arcaneGold.withValues(alpha: 0.7),
                                        blurRadius: 16,
                                        spreadRadius: 3,
                                      ),
                                  ]
                                : (isSpeaking
                                    ? [
                                        const BoxShadow(
                                          color: Color(0xFF00FF88),
                                          blurRadius: 12,
                                          spreadRadius: 2,
                                        ),
                                        if (isWolfPeer && !isMe)
                                          const BoxShadow(
                                            color: Color(0xFFFF2A4B),
                                            blurRadius: 14,
                                            spreadRadius: 2,
                                          ),
                                        if (seerDiscoveredRole != null && !isMe)
                                          const BoxShadow(
                                            color: Color(0xFF6366F1),
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
                                    : ((isWolfPeer && !isMe)
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
                                        : (seerDiscoveredRole != null && !isMe)
                                            ? [
                                                const BoxShadow(
                                                  color: Color(0xFF6366F1),
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
                                                : null))),
                          ),
                          child: child,
                        ),
                      );
                    },
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
                                color: (isWolfPeer && !isMe)
                                    ? const Color(0xFFFFD4D4)
                                    : ((seerDiscoveredRole != null && !isMe)
                                        ? const Color(0xFFC7D2FE)
                                        : (isMe ? const Color(0xFFFFF0D0) : Colors.white)),
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

                  // Badge Micro Barré Rouge si Bâillonné (silence forcé)
                  if (player.isMuted && player.isAlive)
                    Positioned(
                      bottom: -4,
                      left: -4,
                      child: Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF200A10),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFFF3333),
                            width: 1.5,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x99FF3333),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.mic_off_rounded,
                          size: 9,
                          color: Color(0xFFFF3333),
                        ),
                      ),
                    ),

                  // Badge Hors-Ligne si Déconnecté en cours de partie
                  if (!player.isOnline && player.isAlive)
                    Positioned(
                      bottom: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E212D),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.amber,
                            width: 1.2,
                          ),
                        ),
                        child: const Icon(
                          Icons.wifi_off_rounded,
                          size: 8.5,
                          color: Colors.amber,
                        ),
                      ),
                    ),


                  // Badge Allié Loup-Garou (visible pour les loups)
                  if (isWolfPeer && !isMe && (player.isAlive || isGodMode))
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

                  // Badge Rôle Sondé par la Voyante (visible uniquement par la voyante)
                  if (seerDiscoveredRole != null && !isMe && (player.isAlive || isGodMode))
                    Positioned(
                      top: -7,
                      right: -7,
                      child: Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1B4B),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF818CF8), width: 1.2),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0xFF6366F1),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: const Text('🔮', style: TextStyle(fontSize: 10)),
                      ),
                    ),

                  // Badge Capitaine (Étoile dorée uniquement si vivant)
                  if (player.isCaptain && player.isAlive)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: isNewCaptainFlashing
                          ? AnimatedBuilder(
                              animation: _captainFlashAnimation,
                              builder: (context, child) {
                                final flash = _captainFlashAnimation.value;
                                return Transform.scale(
                                  scale: 1.0 + (0.35 * flash),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: LupusColors.arcaneGold,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: LupusColors.arcaneGold.withValues(alpha: 0.85 * flash),
                                          blurRadius: 10 * flash,
                                          spreadRadius: 2 * flash,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(Icons.star_rounded, size: 10, color: Colors.black),
                                  ),
                                );
                              },
                            )
                          : Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: LupusColors.arcaneGold,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.star_rounded, size: 9, color: Colors.black),
                            ),
                    ),

                  // Badge Amoureux (Cœur - masqué hors local, godmode ou mort)
                  if (player.isLover && (isMe || isGodMode || isDead))
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
                  if (player.isDoused && (isMe || widget.myRole == GameRole.pyromaniac || isGodMode || isDead))
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

              // Nom et numéro de siège avec icône loup si allié ou boule de cristal si sondé
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isWolfPeer && !isMe) ...[
                    const Text('🐺', style: TextStyle(fontSize: 8.5)),
                    const SizedBox(width: 2),
                  ],
                  if (seerDiscoveredRole != null && !isMe) ...[
                    const Text('🔮', style: TextStyle(fontSize: 8.5)),
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
                        fontWeight: (isSelected || (isWolfPeer && !isMe) || (seerDiscoveredRole != null && !isMe))
                            ? FontWeight.w800
                            : FontWeight.w500,
                        color: (isWolfPeer && !isMe)
                            ? const Color(0xFFFF5252)
                            : ((seerDiscoveredRole != null && !isMe)
                                ? const Color(0xFFA5B4FC)
                                : (isDead
                                    ? LupusColors.textMuted
                                    : (isSelected ? LupusColors.arcaneGold : LupusColors.textSecondary))),
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
