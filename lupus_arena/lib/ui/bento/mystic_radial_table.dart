import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../models/player_model.dart';
import '../../services/app_translations.dart';
import '../theme/lupus_theme.dart';
import 'revealed_death_card_overlay.dart';

/// Dimensions calculées dynamiquement pour l'agencement radial de la table
class _TableDimensions {
  final double radius;
  final double innerRadius;
  final double avatarSize;
  final double nodeWidth;
  final double fontSize;
  final bool isDoubleRing;
  final int outerCount;
  final int innerCount;
  final double innerRadiusFactor;

  const _TableDimensions({
    required this.radius,
    required this.innerRadius,
    required this.avatarSize,
    required this.nodeWidth,
    required this.fontSize,
    required this.isDoubleRing,
    required this.outerCount,
    required this.innerCount,
    required this.innerRadiusFactor,
  });
}

/// Table mystique circulaire adaptative inspirée du design Stitch.
/// Dispose les joueurs (de 4 jusqu'à 30 participants) de façon réactive :
/// - Dimensionnement dynamique par [LayoutBuilder] / [MediaQuery] pour s'adapter à l'écran.
/// - Double anneau concentrique avec interfoliage angulaire pour N > 16 joueurs.
/// - Hitbox tactile garantie d'au moins 48x48 dp pour chaque joueur ([HitTestBehavior.opaque]).
/// - Transitions de repositionnement fluides via [AnimatedPositioned].
/// - Optimisation Skia/Impeller avec [RepaintBoundary] et contrôleur de pulsation audio conditionnel.
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

  bool _hasActiveSpeaker() {
    if (widget.currentSpeakerId != null && widget.currentSpeakerId!.isNotEmpty) {
      return true;
    }
    for (final player in widget.players) {
      if (widget.speakingAgoraUids.contains(player.agoraUid) && player.isAlive) {
        return true;
      }
    }
    return false;
  }

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
    );

    _pulseAnimation = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Ne lancer l'animation de pulsation que si un joueur a effectivement la parole
    if (_hasActiveSpeaker()) {
      _pulseController.repeat(reverse: true);
    }

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

    // Gestion intelligente du contrôleur de pulsation audio pour économiser la batterie
    final hasSpeaker = _hasActiveSpeaker();
    if (hasSpeaker && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!hasSpeaker && _pulseController.isAnimating) {
      _pulseController.stop();
    }
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

  _TableDimensions _computeDimensions({
    required double tableSize,
    required int totalPlayers,
    required bool isDoubleRing,
  }) {
    final double maxRadius = (tableSize / 2) - 28.0;

    if (isDoubleRing) {
      final outerCount = (totalPlayers + 1) ~/ 2;
      final innerCount = totalPlayers ~/ 2;
      const double innerFactor = 0.62;
      final double outerRadius = maxRadius;
      final double innerRadius = maxRadius * innerFactor;

      return _TableDimensions(
        radius: outerRadius,
        innerRadius: innerRadius,
        avatarSize: 28.0,
        nodeWidth: 34.0,
        fontSize: 8.0,
        isDoubleRing: true,
        outerCount: outerCount,
        innerCount: innerCount,
        innerRadiusFactor: innerFactor,
      );
    }

    // Single ring
    final double avatarSize;
    final double nodeWidth;
    final double fontSize;

    if (totalPlayers <= 8) {
      avatarSize = 44.0;
      nodeWidth = 50.0;
      fontSize = 11.0;
    } else if (totalPlayers <= 12) {
      avatarSize = 38.0;
      nodeWidth = 44.0;
      fontSize = 9.5;
    } else {
      // 13..16
      avatarSize = 32.0;
      nodeWidth = 38.0;
      fontSize = 8.5;
    }

    return _TableDimensions(
      radius: maxRadius,
      innerRadius: 0.0,
      avatarSize: avatarSize,
      nodeWidth: nodeWidth,
      fontSize: fontSize,
      isDoubleRing: false,
      outerCount: totalPlayers,
      innerCount: 0,
      innerRadiusFactor: 1.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalPlayers = widget.players.length;
    final bool isDoubleRing = totalPlayers > 16;

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

    return LayoutBuilder(
      builder: (context, constraints) {
        final double screenWidth =
            MediaQuery.maybeSizeOf(context)?.width ?? 360.0;
        final double screenHeight =
            MediaQuery.maybeSizeOf(context)?.height ?? 640.0;

        final double availableWidth =
            constraints.maxWidth.isFinite && constraints.maxWidth > 0
                ? constraints.maxWidth
                : (screenWidth - 20).clamp(280.0, 480.0);
        final double availableHeight =
            constraints.maxHeight.isFinite && constraints.maxHeight > 0
                ? constraints.maxHeight
                : availableWidth;

        // Dimensionnement adaptatif de la table
        final double tableSize =
            math.min(availableWidth, availableHeight).clamp(280.0, 480.0);
        final double center = tableSize / 2;

        final dimensions = _computeDimensions(
          tableSize: tableSize,
          totalPlayers: totalPlayers,
          isDoubleRing: isDoubleRing,
        );

        return Center(
          child: SizedBox(
            width: tableSize,
            height: tableSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 1, 2, 3. Couche d'arrière-plan avec dégradé et anneaux runiques animés (Isolée)
                _MysticRadialBackgroundLayer(
                  tableSize: tableSize,
                  isDoubleRing: isDoubleRing,
                  innerRadiusFactor: dimensions.innerRadiusFactor,
                  rotationAnimation: _rotationController,
                ),

                // 4. Carte d'état de cible OU Séquence cinématique 3D des défunts au centre (Isolée)
                RepaintBoundary(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    switchInCurve: Curves.easeInOut,
                    switchOutCurve: Curves.easeInOut,
                    child: (widget.deathQueue != null &&
                            widget.deathQueue!.isNotEmpty)
                        ? RevealedDeathCardOverlay(
                            key: ValueKey(widget.deathQueue!
                                .map((e) => e.key)
                                .join('_')),
                            queue: widget.deathQueue!,
                            onSequenceCompleted: widget.onDeathSequenceCompleted,
                          )
                        : KeyedSubtree(
                            key: const ValueKey('center_target_card'),
                            child: _buildCenterTargetCard(
                              selectedPlayer,
                              isCompact: isDoubleRing,
                            ),
                          ),
                  ),
                ),

                // 5. Noeuds radiaux des joueurs disposés à 360° (avec transitions AnimatedPositioned et Hitbox 48x48)
                for (int i = 0; i < totalPlayers; i++)
                  _buildRadialPlayerNode(
                    player: widget.players[i],
                    index: i,
                    total: totalPlayers,
                    dimensions: dimensions,
                    center: center,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCenterTargetCard(
    PlayerModel? selectedPlayer, {
    bool isCompact = false,
  }) {
    final double cardWidth = isCompact ? 104.0 : 126.0;
    final double hPadding = isCompact ? 6.0 : 8.0;
    final double vPadding = isCompact ? 6.0 : 10.0;
    final double nameFontSize = isCompact ? 10.0 : 11.5;
    final double badgeFontSize = isCompact ? 7.5 : 8.5;

    return Container(
      width: cardWidth,
      padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: vPadding),
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
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
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
                  width: 4.5,
                  height: 4.5,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: LupusColors.arcaneCrimson,
                  ),
                ),
                const SizedBox(width: 3.5),
                Text(
                  widget.centerActionTitle ?? context.tr('target'),
                  style: TextStyle(
                    fontSize: badgeFontSize,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: const Color(0xFFFCA5A5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // Nom de la cible sélectionnée
          Text(
            selectedPlayer != null
                ? selectedPlayer.name
                : (widget.centerActionSubtitle ?? context.tr('no_target')),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: nameFontSize,
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
                        fontSize: isCompact ? 8.0 : 9.0,
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
            style: TextStyle(
              fontSize: isCompact ? 7.5 : 8.5,
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
    required _TableDimensions dimensions,
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

    final double nodeWidth = dimensions.nodeWidth;
    final double avatarSize = isSelected
        ? (dimensions.avatarSize + 4.0)
        : dimensions.avatarSize;

    // Calcul de l'angle et du rayon (mode simple anneau ou double anneau imbriqué)
    final double angle;
    final double currentRadius;

    if (dimensions.isDoubleRing) {
      final bool isOuter = (index % 2 == 0);
      if (isOuter) {
        final int outerIdx = index ~/ 2;
        angle = (2 * math.pi * outerIdx / dimensions.outerCount) - (math.pi / 2);
        currentRadius = dimensions.radius;
      } else {
        final int innerIdx = index ~/ 2;
        // Décalage angulaire de pi / innerCount pour intercaler parfaitement entre les joueurs extérieurs
        angle = (2 * math.pi * innerIdx / dimensions.innerCount) -
            (math.pi / 2) +
            (math.pi / dimensions.innerCount);
        currentRadius = dimensions.innerRadius;
      }
    } else {
      angle = (2 * math.pi * index / total) - (math.pi / 2);
      currentRadius = dimensions.radius;
    }

    // Zone d'interaction tactile garantie minimale de 48x48 dp
    final double hitWidth = math.max(48.0, nodeWidth);
    final double hitHeight = math.max(48.0, nodeWidth + 16.0);

    final double x = center + (currentRadius * math.cos(angle)) - (hitWidth / 2);
    final double y = center + (currentRadius * math.sin(angle)) - (hitHeight / 2);

    // Initiales
    final initials = player.name.trim().isNotEmpty
        ? (player.name.trim().length >= 2
            ? player.name.trim().substring(0, 2).toUpperCase()
            : player.name.trim().substring(0, 1).toUpperCase())
        : '??';

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
      left: x,
      top: y,
      width: hitWidth,
      height: hitHeight,
      child: RepaintBoundary(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: player.isAlive ? () => widget.onPlayerSelected(player.id) : null,
          child: Center(
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
                      // 1. Onde de choc et halo néon pulsant pour celui qui a la parole (Isolé)
                      if (isSpeaking)
                        _SpeakingPulseHalo(
                          pulseAnimation: _pulseAnimation,
                          avatarSize: avatarSize,
                        ),

                      // 2. Avatar du joueur avec décoration et animation de flash Capitaine conditionnelle
                      _buildAvatarToken(
                        player: player,
                        isDead: isDead,
                        isMe: isMe,
                        isSpeaking: isSpeaking,
                        isWolfPeer: isWolfPeer,
                        seerDiscoveredRole: seerDiscoveredRole,
                        isSelected: isSelected,
                        isNewCaptainFlashing: isNewCaptainFlashing,
                        avatarSize: avatarSize,
                        initials: initials,
                        fontSize: dimensions.fontSize + 1.5,
                      ),

                      // Badge Micro Néon pour celui qui a la parole
                      if (isSpeaking)
                        Positioned(
                          bottom: -4,
                          right: -4,
                          child: Container(
                            padding: const EdgeInsets.all(2.0),
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
                              style: TextStyle(fontSize: 8.0),
                            ),
                          ),
                        ),

                      // Badge Micro Barré Rouge si Bâillonné (silence forcé)
                      if (player.isMuted && player.isAlive)
                        Positioned(
                          bottom: -4,
                          left: -4,
                          child: Container(
                            padding: const EdgeInsets.all(2.0),
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
                              size: 8.5,
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
                            padding: const EdgeInsets.all(2.0),
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
                              size: 8.0,
                              color: Colors.amber,
                            ),
                          ),
                        ),

                      // Badge Allié Loup-Garou (visible pour les loups)
                      if (isWolfPeer && !isMe && (player.isAlive || isGodMode))
                        Positioned(
                          top: -6,
                          left: -6,
                          child: Container(
                            padding: const EdgeInsets.all(2.0),
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
                            child: const Text('🐺', style: TextStyle(fontSize: 9.0)),
                          ),
                        ),

                      // Badge Rôle Sondé par la Voyante (visible uniquement par la voyante)
                      if (seerDiscoveredRole != null && !isMe && (player.isAlive || isGodMode))
                        Positioned(
                          top: -6,
                          right: -6,
                          child: Container(
                            padding: const EdgeInsets.all(2.0),
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
                            child: const Text('🔮', style: TextStyle(fontSize: 9.0)),
                          ),
                        ),

                      // Badge Capitaine (Étoile dorée uniquement si vivant)
                      if (player.isCaptain && player.isAlive)
                        Positioned(
                          top: -4,
                          right: -4,
                          child: isNewCaptainFlashing
                              ? RepaintBoundary(
                                  child: AnimatedBuilder(
                                    animation: _captainFlashAnimation,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: LupusColors.arcaneGold,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: LupusColors.arcaneGold
                                                .withValues(alpha: 0.85),
                                            blurRadius: 10,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                      child: const Icon(Icons.star_rounded,
                                          size: 9.5, color: Colors.black),
                                    ),
                                    builder: (context, child) {
                                      final flash =
                                          _captainFlashAnimation.value;
                                      return Transform.scale(
                                        scale: 1.0 + (0.35 * flash),
                                        child: child,
                                      );
                                    },
                                  ),
                                )
                              : Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: LupusColors.arcaneGold,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.star_rounded,
                                      size: 8.5, color: Colors.black),
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
                            child: const Icon(Icons.favorite_rounded,
                                size: 8.5, color: Colors.white),
                          ),
                        ),

                      // Badge Maison Imbibée de Carburant (Pyromane)
                      if (player.isDoused &&
                          (isMe ||
                              widget.myRole == GameRole.pyromaniac ||
                              isGodMode ||
                              isDead))
                        Positioned(
                          bottom: -4,
                          left: -4,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF4800),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.local_fire_department_rounded,
                                size: 8.5, color: Colors.white),
                          ),
                        ),

                      // Badge Envoûté (Joueur de Flûte)
                      if (player.isCharmed &&
                          (isMe ||
                              widget.myRole == GameRole.piper ||
                              isGodMode ||
                              isDead))
                        Positioned(
                          bottom: -4,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF06D6A0),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF06D6A0)
                                      .withValues(alpha: 0.7),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.music_note_rounded,
                                size: 8.5, color: Colors.black87),
                          ),
                        ),

                      // Badge Infecté (Loup Infect)
                      if (player.isInfected &&
                          (isMe ||
                              widget.myRole.isEvil ||
                              isGodMode ||
                              isDead))
                        Positioned(
                          top: 10,
                          right: -4,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF84CC16),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF84CC16)
                                      .withValues(alpha: 0.7),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.pest_control_rounded,
                                size: 8.5, color: Colors.black),
                          ),
                        ),

                      // Badge Bâillonné / Muté (Loup Noir)
                      if (player.isMuted)
                        Positioned(
                          top: 10,
                          left: -4,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF9333EA),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF9333EA)
                                      .withValues(alpha: 0.7),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.volume_off_rounded,
                                size: 8.5, color: Colors.white),
                          ),
                        ),

                      // Badge de votes reçus (avec étoile dorée si ciblé par le vote du Maire)
                      if (votes > 0)
                        Positioned(
                          bottom: -4,
                          right: -4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: (widget.captainTargetVoteId == player.id)
                                  ? const Color(0xFFD97706) // Doré/Ambre pour vote du Maire
                                  : LupusColors.arcaneCrimson,
                              borderRadius: BorderRadius.circular(6),
                              border: (widget.captainTargetVoteId == player.id)
                                  ? Border.all(
                                      color: LupusColors.arcaneGold, width: 1.2)
                                  : null,
                              boxShadow: (widget.captainTargetVoteId == player.id)
                                  ? [
                                      BoxShadow(
                                        color: LupusColors.arcaneGold
                                            .withValues(alpha: 0.6),
                                        blurRadius: 6,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (widget.captainTargetVoteId == player.id) ...[
                                  const Icon(Icons.star_rounded,
                                      size: 7.5, color: Colors.white),
                                  const SizedBox(width: 1),
                                ],
                                Text(
                                  '$votes',
                                  style: const TextStyle(
                                    fontSize: 7.5,
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
                        const Text('🐺', style: TextStyle(fontSize: 8.0)),
                        const SizedBox(width: 1.5),
                      ],
                      if (seerDiscoveredRole != null && !isMe) ...[
                        const Text('🔮', style: TextStyle(fontSize: 8.0)),
                        const SizedBox(width: 1.5),
                      ],
                      if (player.isInfected &&
                          (isMe || isWolfPeer || isGodMode || isDead)) ...[
                        const Text('🩸', style: TextStyle(fontSize: 8.0)),
                        const SizedBox(width: 1.5),
                      ],
                      if (player.isCharmed &&
                          (isMe ||
                              widget.myRole == GameRole.piper ||
                              isGodMode ||
                              isDead)) ...[
                        const Text('🎵', style: TextStyle(fontSize: 8.0)),
                        const SizedBox(width: 1.5),
                      ],
                      if (player.isMuted) ...[
                        const Text('🤫', style: TextStyle(fontSize: 8.0)),
                        const SizedBox(width: 1.5),
                      ],
                      Flexible(
                        child: Text(
                          '#${index + 1} ${player.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: dimensions.fontSize,
                            fontWeight: (isSelected ||
                                    (isWolfPeer && !isMe) ||
                                    (seerDiscoveredRole != null && !isMe))
                                ? FontWeight.w800
                                : FontWeight.w500,
                            color: (isWolfPeer && !isMe)
                                ? const Color(0xFFFF5252)
                                : ((seerDiscoveredRole != null && !isMe)
                                    ? const Color(0xFFA5B4FC)
                                    : (isDead
                                        ? LupusColors.textMuted
                                        : (isSelected
                                            ? LupusColors.arcaneGold
                                            : LupusColors.textSecondary))),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarToken({
    required PlayerModel player,
    required bool isDead,
    required bool isMe,
    required bool isSpeaking,
    required bool isWolfPeer,
    required GameRole? seerDiscoveredRole,
    required bool isSelected,
    required bool isNewCaptainFlashing,
    required double avatarSize,
    required String initials,
    required double fontSize,
  }) {
    final avatarContent = Center(
      child: isDead
          ? const Text(
              '✕',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: LupusColors.arcaneCrimson,
              ),
            )
          : Text(
              initials,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
                color: (isWolfPeer && !isMe)
                    ? const Color(0xFFFFD4D4)
                    : ((seerDiscoveredRole != null && !isMe)
                        ? const Color(0xFFC7D2FE)
                        : (isMe ? const Color(0xFFFFF0D0) : Colors.white)),
              ),
            ),
    );

    BoxDecoration getAvatarDecoration(double flash) {
      return BoxDecoration(
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
          color: (isNewCaptainFlashing && flash > 0)
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
          width: (isNewCaptainFlashing && flash > 0)
              ? (2.5 + (1.5 * flash))
              : ((isSpeaking || ((isWolfPeer || seerDiscoveredRole != null) && !isMe))
                  ? 2.6 // Contour néon / rouge sang bien affirmé
                  : (isSelected
                      ? 2.2
                      : 1.2)),
        ),
        boxShadow: (isNewCaptainFlashing && flash > 0)
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
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                    if (isWolfPeer && !isMe)
                      const BoxShadow(
                        color: Color(0xFFFF2A4B),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    if (seerDiscoveredRole != null && !isMe)
                      const BoxShadow(
                        color: Color(0xFF6366F1),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    if (isSelected)
                      BoxShadow(
                        color: LupusColors.arcaneGold.withValues(alpha: 0.7),
                        blurRadius: 14,
                        spreadRadius: 2.5,
                      ),
                  ]
                : ((isWolfPeer && !isMe)
                    ? [
                        const BoxShadow(
                          color: Color(0xFFFF2A4B),
                          blurRadius: 12,
                          spreadRadius: 2.0,
                        ),
                        if (isSelected)
                          BoxShadow(
                            color: LupusColors.arcaneGold.withValues(alpha: 0.7),
                            blurRadius: 14,
                            spreadRadius: 2.5,
                          ),
                      ]
                    : (seerDiscoveredRole != null && !isMe)
                        ? [
                            const BoxShadow(
                              color: Color(0xFF6366F1),
                              blurRadius: 12,
                              spreadRadius: 2.0,
                            ),
                            if (isSelected)
                              BoxShadow(
                                color: LupusColors.arcaneGold.withValues(alpha: 0.7),
                                blurRadius: 14,
                                spreadRadius: 2.5,
                              ),
                          ]
                        : (isSelected
                            ? LupusTheme.glowGold(opacity: 0.6)
                            : null))),
      );
    }

    if (isNewCaptainFlashing) {
      return RepaintBoundary(
        child: AnimatedBuilder(
          animation: _captainFlashAnimation,
          child: avatarContent,
          builder: (context, child) {
            final flash = _captainFlashAnimation.value;
            return Transform.scale(
              scale: 1.0 + (0.08 * flash),
              child: Container(
                width: avatarSize,
                height: avatarSize,
                decoration: getAvatarDecoration(flash),
                child: child,
              ),
            );
          },
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: avatarSize,
      height: avatarSize,
      decoration: getAvatarDecoration(0.0),
      child: avatarContent,
    );
  }
}

/// Couche d'arrière-plan du sceau magique avec rotation runique et anneaux dorés.
/// Entièrement isolée dans un [RepaintBoundary] avec réutilisation des widgets enfants.
class _MysticRadialBackgroundLayer extends StatelessWidget {
  final double tableSize;
  final bool isDoubleRing;
  final double innerRadiusFactor;
  final Animation<double> rotationAnimation;

  const _MysticRadialBackgroundLayer({
    required this.tableSize,
    required this.isDoubleRing,
    required this.innerRadiusFactor,
    required this.rotationAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
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

          // 2. Anneau runique extérieur animé en rotation douce (child pré-alloué réutilisé)
          AnimatedBuilder(
            animation: rotationAnimation,
            child: Container(
              width: tableSize - 56,
              height: tableSize - 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: LupusColors.arcaneCyan.withValues(alpha: 0.20),
                  width: 1.5,
                  strokeAlign: BorderSide.strokeAlignCenter,
                ),
              ),
            ),
            builder: (context, child) {
              return Transform.rotate(
                angle: rotationAnimation.value * 2 * math.pi,
                child: child,
              );
            },
          ),

          // 3. Anneau runique intérieur secondaire pour mode double anneau (N > 16)
          if (isDoubleRing)
            AnimatedBuilder(
              animation: rotationAnimation,
              child: Container(
                width: (tableSize - 56) * innerRadiusFactor,
                height: (tableSize - 56) * innerRadiusFactor,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: LupusColors.arcaneCyan.withValues(alpha: 0.14),
                    width: 1.0,
                    strokeAlign: BorderSide.strokeAlignCenter,
                  ),
                ),
              ),
              builder: (context, child) {
                return Transform.rotate(
                  // Rotation en sens inverse pour un effet mystique saisissant
                  angle: -rotationAnimation.value * 2 * math.pi,
                  child: child,
                );
              },
            ),

          // 4. Anneau doré intérieur délimitant le centre
          Container(
            width: isDoubleRing ? (tableSize * 0.38) : (tableSize - 120),
            height: isDoubleRing ? (tableSize * 0.38) : (tableSize - 120),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: LupusColors.arcaneGold.withValues(alpha: 0.20),
                width: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Onde de choc et halo néon pulsant pour le joueur actif / en cours de parole.
/// Isolé dans son propre [RepaintBoundary] pour éviter d'invalider le reste de la table ou de l'avatar.
class _SpeakingPulseHalo extends StatelessWidget {
  final Animation<double> pulseAnimation;
  final double avatarSize;

  const _SpeakingPulseHalo({
    required this.pulseAnimation,
    required this.avatarSize,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: pulseAnimation,
        builder: (context, _) {
          final pulse = pulseAnimation.value;
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
    );
  }
}
