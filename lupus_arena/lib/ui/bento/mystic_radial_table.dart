import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/player_model.dart';
import '../../services/app_translations.dart';
import '../../services/fog_of_war_service.dart';
import '../theme/lupus_theme.dart';
import 'animated_status_badge.dart';
import 'game_action_visual_effects.dart';
import 'ghost_death_badge.dart';
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
  final bool isDevModeActive;
  final bool isDevRoom;
  final GameRole myRole;
  final Map<String, GameRole> seerInspectedRoles;
  final List<String> foxSniffedPlayerIds;
  final bool? foxWolfDetected;
  final Set<String> wolfPlayerIds;
  final String? currentProtectedPlayerId;
  final bool witchHealed;
  final String? witchPoisonVictimId;
  final String? nightVictimId;
  final bool isNightWitch;
  final String? crowTargetId;
  final String? wildChildModelId;
  final bool bearGrowledThisMorning;
  final String? rustyKnightContaminatedWolfId;
  final bool isDayTime;
  final ValueChanged<String> onPlayerSelected;
  final Map<String, int>? voteCounts;
  final String? centerActionTitle;
  final String? centerActionSubtitle;
  final String? captainTargetVoteId;
  final List<DeathAnnouncementEvent>? deathQueue;
  final VoidCallback? onDeathSequenceCompleted;
  final String? hunterShotTargetId;
  final Set<String>? pyroIgnitedPlayerIds;

  const MysticRadialTable({
    super.key,
    required this.players,
    required this.selectedPlayerId,
    required this.currentUserId,
    required this.speakingAgoraUids,
    this.currentSpeakerId,
    this.revealRoles = false,
    this.isMeEvil = false,
    this.isDevModeActive = false,
    this.isDevRoom = false,
    this.myRole = GameRole.simpleVillager,
    this.seerInspectedRoles = const {},
    this.foxSniffedPlayerIds = const [],
    this.foxWolfDetected,
    this.wolfPlayerIds = const {},
    this.currentProtectedPlayerId,
    this.witchHealed = false,
    this.witchPoisonVictimId,
    this.nightVictimId,
    this.isNightWitch = false,
    this.crowTargetId,
    this.wildChildModelId,
    this.bearGrowledThisMorning = false,
    this.rustyKnightContaminatedWolfId,
    this.isDayTime = false,
    required this.onPlayerSelected,
    this.voteCounts,
    this.centerActionTitle,
    this.centerActionSubtitle,
    this.captainTargetVoteId,
    this.deathQueue,
    this.onDeathSequenceCompleted,
    this.hunterShotTargetId,
    this.pyroIgnitedPlayerIds,
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
      if (!player.isBot &&
          player.agoraUid > 0 &&
          widget.speakingAgoraUids.contains(player.agoraUid) &&
          player.isAlive) {
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
    // Rayon orbital calibré proportionnellement (tableSize * 0.38) pour éviter tout débordement
    final double maxRadius = tableSize * 0.38;

    if (isDoubleRing) {
      final outerCount = (totalPlayers + 1) ~/ 2;
      final innerCount = totalPlayers ~/ 2;
      const double innerFactor = 0.65;
      final double outerRadius = maxRadius;
      final double innerRadius = maxRadius * innerFactor;

      return _TableDimensions(
        radius: outerRadius,
        innerRadius: innerRadius,
        avatarSize: 24.0,
        nodeWidth: 28.0,
        fontSize: 7.0,
        isDoubleRing: true,
        outerCount: outerCount,
        innerCount: innerCount,
        innerRadiusFactor: innerFactor,
      );
    }

    // Single ring (échelle 0.85-0.90)
    final double avatarSize;
    final double nodeWidth;
    final double fontSize;

    if (totalPlayers <= 8) {
      avatarSize = 36.0;
      nodeWidth = 42.0;
      fontSize = 9.5;
    } else if (totalPlayers <= 12) {
      avatarSize = 32.0;
      nodeWidth = 37.0;
      fontSize = 8.5;
    } else {
      // 13..16
      avatarSize = 28.0;
      nodeWidth = 33.0;
      fontSize = 7.5;
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

    // Table circulaire recalibrée (diamètre 260px) pour résoudre l'empiètement vertical
    const double tableSize = 260.0;
    const double center = tableSize / 2;

    final dimensions = _computeDimensions(
      tableSize: tableSize,
      totalPlayers: totalPlayers,
      isDoubleRing: isDoubleRing,
    );

    // Pré-calculs hors-boucle O(1) pour éviter O(N^2) dans le layout des noeuds
    final isDevMode = widget.isDevModeActive || widget.isDevRoom;
    final isMeWolfTeam = widget.isMeEvil ||
        widget.myRole.isEvil ||
        widget.myRole.isWolfTeam ||
        (widget.currentUserId != null && widget.wolfPlayerIds.contains(widget.currentUserId));
    final canSeeFoxSniff = FogOfWarService.canSeeFoxSniff(
      observerRole: widget.myRole,
      isDevMode: isDevMode,
    );

    PlayerModel? me;
    if (widget.currentUserId != null) {
      for (final p in widget.players) {
        if (p.id == widget.currentUserId) {
          me = p;
          break;
        }
      }
    }
    final myIsLover = me?.isLover ?? false;
    final myIsCharmed = me?.isCharmed ?? false;

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
                                .map((e) => e.playerId)
                                .join('_')),
                            queue: widget.deathQueue!,
                            onSequenceCompleted: widget.onDeathSequenceCompleted,
                          )
                        : KeyedSubtree(
                            key: const ValueKey('center_target_card'),
                            child: _buildCenterTargetCard(
                              selectedPlayer,
                              isCompact: isDoubleRing,
                              maxRadius: isDoubleRing
                                  ? dimensions.innerRadius
                                  : dimensions.radius,
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
                    isDevMode: isDevMode,
                    isMeWolfTeam: isMeWolfTeam,
                    canSeeFoxSniff: canSeeFoxSniff,
                    myIsLover: myIsLover,
                    myIsCharmed: myIsCharmed,
                  ),
              ],
            ),
          ),
        );
  }

  Widget _buildCenterTargetCard(
    PlayerModel? selectedPlayer, {
    bool isCompact = false,
    double maxRadius = 140.0,
  }) {
    final double baseWidth = isCompact ? 80.0 : 98.0;
    // Borner la boîte centrale pour qu'elle ne dépasse jamais 85% du rayon effectif
    final double cardWidth = math.min(baseWidth, maxRadius * 0.85);
    final double hPadding = isCompact ? 5.0 : 7.0;
    final double vPadding = isCompact ? 5.0 : 8.0;
    final double nameFontSize = isCompact ? 9.0 : 10.5;
    final double badgeFontSize = isCompact ? 6.8 : 7.5;

    return Container(
      constraints: BoxConstraints(maxWidth: cardWidth),
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
                final isTargetDevMode =
                    widget.isDevModeActive || widget.isDevRoom;
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
                      {'role': selectedPlayer.role.getDisplayName(context)});
                  roleColor = selectedPlayer.role.accentColor;
                } else if (isTargetDead) {
                  roleText = selectedPlayer.roleInitial.getDisplayName(context);
                  roleColor = selectedPlayer.roleInitial.accentColor;
                } else if (targetSeerRole != null) {
                  roleText = '🔮 ${targetSeerRole.getDisplayName(context)}';
                  roleColor = targetSeerRole.accentColor;
                } else if (isTargetWolf) {
                  final wolfName = (selectedPlayer.role == GameRole.whiteWerewolf)
                      ? context.tr('role_white_werewolf')
                      : (selectedPlayer.role.isEvil && selectedPlayer.role != GameRole.simpleVillager)
                          ? selectedPlayer.role.getDisplayName(context)
                          : context.tr('role_simple_werewolf');
                  roleText = '🐺 $wolfName';
                  roleColor = const Color(0xFFFF8B8B);
                } else if (isTargetDevMode) {
                  roleText = selectedPlayer.estDechu
                      ? '${selectedPlayer.role.getDisplayName(context)} (Ex-${selectedPlayer.roleInitial.getDisplayName(context)})'
                      : selectedPlayer.role.getDisplayName(context);
                  roleColor = selectedPlayer.role.accentColor;
                }

                final canSeeTargetFox = FogOfWarService.canSeeFoxSniff(
                  observerRole: widget.myRole,
                  isDevMode: isTargetDevMode,
                );
                final isTargetSniffed = (widget.foxSniffedPlayerIds.contains(selectedPlayer.id) || selectedPlayer.isSniffed) &&
                    canSeeTargetFox;
                final targetWolfDetected = (widget.foxWolfDetected ?? selectedPlayer.hasWolfSmell);

                if (isTargetSniffed && roleText == null) {
                  roleText = targetWolfDetected
                      ? '🐾 Odeur de loup dans le trio !'
                      : '🦊 Aucun loup dans ce trio';
                  roleColor = targetWolfDetected
                      ? const Color(0xFFFF5252)
                      : const Color(0xFFFB8500);
                }

                final canSeeTargetDefender = FogOfWarService.canSeeDefenderShield(
                  targetIsProtected: widget.currentProtectedPlayerId == selectedPlayer.id,
                  observerRole: widget.myRole,
                  isDevMode: isTargetDevMode,
                );
                final canSeeTargetWitchHealed = FogOfWarService.canSeeWitchHealed(
                  targetIsHealed: widget.witchHealed && widget.nightVictimId == selectedPlayer.id,
                  observerRole: widget.myRole,
                  isDevMode: isTargetDevMode,
                );
                final canSeeTargetWitchPoisoned = FogOfWarService.canSeeWitchPoisoned(
                  targetIsPoisoned: widget.witchPoisonVictimId == selectedPlayer.id,
                  observerRole: widget.myRole,
                  isDevMode: isTargetDevMode,
                );
                final canSeeTargetWitchVictim = FogOfWarService.canSeeWitchWolfVictim(
                  targetIsVictim: widget.nightVictimId == selectedPlayer.id,
                  observerRole: widget.myRole,
                  isNightWitch: widget.isNightWitch,
                  isDevMode: isTargetDevMode,
                );
                final canSeeTargetCrow = FogOfWarService.canSeeCrowTarget(
                  targetIsCrowTarget: widget.crowTargetId == selectedPlayer.id,
                  isDayTime: widget.isDayTime,
                  observerRole: widget.myRole,
                  isDevMode: isTargetDevMode,
                );
                final canSeeTargetWildModel = FogOfWarService.canSeeWildChildModel(
                  targetIsModel: widget.wildChildModelId == selectedPlayer.id,
                  observerRole: widget.myRole,
                  isDevMode: isTargetDevMode,
                );
                final canSeeTargetContamination = FogOfWarService.canSeeRustyKnightContamination(
                  targetIsContaminated: widget.rustyKnightContaminatedWolfId == selectedPlayer.id,
                  isObserverWolf: isTargetWolf,
                  isObserverContaminated: widget.rustyKnightContaminatedWolfId == widget.currentUserId,
                  isDevMode: isTargetDevMode,
                );
                final canSeeTargetBearGrowl = FogOfWarService.canSeeBearGrowl(
                  targetIsBearTamer: selectedPlayer.role == GameRole.bearTamer || selectedPlayer.roleInitial == GameRole.bearTamer,
                  bearGrowledThisMorning: widget.bearGrowledThisMorning,
                  isDayTime: widget.isDayTime,
                  isDevMode: isTargetDevMode,
                );

                if (roleText == null) {
                  if (canSeeTargetDefender) {
                    roleText = '🛡️ Protégé par le Salvateur';
                    roleColor = const Color(0xFF3A86FF);
                  } else if (canSeeTargetWitchHealed) {
                    roleText = '🧪 Sauvé par la potion de vie';
                    roleColor = const Color(0xFF06D6A0);
                  } else if (canSeeTargetWitchPoisoned) {
                    roleText = '☠️ Empoisonné par la potion de mort';
                    roleColor = const Color(0xFF9D4EDD);
                  } else if (canSeeTargetWitchVictim) {
                    roleText = '🩸 Victime désignée de la meute';
                    roleColor = const Color(0xFFFF2A4B);
                  } else if (canSeeTargetCrow) {
                    roleText = '🦅 Maudit par le Corbeau (+2 voix)';
                    roleColor = const Color(0xFF94A3B8);
                  } else if (canSeeTargetWildModel) {
                    roleText = '🌱 Modèle de l\'Enfant Sauvage';
                    roleColor = const Color(0xFF52B788);
                  } else if (canSeeTargetContamination) {
                    roleText = '🗡️ Contaminé par l\'Épée Rouillée';
                    roleColor = const Color(0xFFE5989B);
                  } else if (canSeeTargetBearGrowl) {
                    roleText = '🐻 L\'ours a grogné ce matin !';
                    roleColor = const Color(0xFFDDA15E);
                  }
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
    required bool isDevMode,
    required bool isMeWolfTeam,
    required bool canSeeFoxSniff,
    required bool myIsLover,
    required bool myIsCharmed,
  }) {
    final isSelected = player.id == widget.selectedPlayerId;
    final isMe = player.id == widget.currentUserId;
    final isVoiceActive = !player.isBot &&
        player.agoraUid > 0 &&
        widget.speakingAgoraUids.contains(player.agoraUid);
    final hasFloor = widget.currentSpeakerId != null &&
        widget.currentSpeakerId == player.id;
    final isSpeaking = (isVoiceActive || hasFloor) && player.isAlive;
    final isWolfPeer = (player.role.isEvil ||
            widget.wolfPlayerIds.contains(player.id)) &&
        (widget.isMeEvil ||
            widget.myRole.isEvil ||
            (widget.currentUserId != null &&
                widget.wolfPlayerIds.contains(widget.currentUserId)) ||
            isDevMode);

    final isProtected = FogOfWarService.canSeeDefenderShield(
      targetIsProtected: widget.currentProtectedPlayerId == player.id,
      observerRole: widget.myRole,
      isDevMode: isDevMode,
    ) && (player.isAlive || isDevMode);

    final isWitchVictim = FogOfWarService.canSeeWitchWolfVictim(
      targetIsVictim: widget.nightVictimId == player.id,
      observerRole: widget.myRole,
      isNightWitch: widget.isNightWitch,
      isDevMode: isDevMode,
    ) && (player.isAlive || isDevMode);

    final isWitchHealed = FogOfWarService.canSeeWitchHealed(
      targetIsHealed: widget.witchHealed && widget.nightVictimId == player.id,
      observerRole: widget.myRole,
      isDevMode: isDevMode,
    ) && (player.isAlive || isDevMode);

    final isWitchPoisoned = FogOfWarService.canSeeWitchPoisoned(
      targetIsPoisoned: widget.witchPoisonVictimId == player.id,
      observerRole: widget.myRole,
      isDevMode: isDevMode,
    ) && (player.isAlive || isDevMode);

    final isCrowTarget = FogOfWarService.canSeeCrowTarget(
      targetIsCrowTarget: widget.crowTargetId == player.id,
      isDayTime: widget.isDayTime,
      observerRole: widget.myRole,
      isDevMode: isDevMode,
    ) && (player.isAlive || isDevMode);

    final isWildChildModel = FogOfWarService.canSeeWildChildModel(
      targetIsModel: widget.wildChildModelId == player.id,
      observerRole: widget.myRole,
      isDevMode: isDevMode,
    ) && (player.isAlive || isDevMode);

    final isContaminatedWolf = FogOfWarService.canSeeRustyKnightContamination(
      targetIsContaminated: widget.rustyKnightContaminatedWolfId == player.id,
      isObserverWolf: isMeWolfTeam,
      isObserverContaminated: widget.rustyKnightContaminatedWolfId == widget.currentUserId,
      isDevMode: isDevMode,
    ) && (player.isAlive || isDevMode);

    final isBearTamerGrowling = FogOfWarService.canSeeBearGrowl(
      targetIsBearTamer: player.role == GameRole.bearTamer || player.roleInitial == GameRole.bearTamer,
      bearGrowledThisMorning: widget.bearGrowledThisMorning,
      isDayTime: widget.isDayTime,
      isDevMode: isDevMode,
    ) && (player.isAlive || isDevMode);

    final seerDiscoveredRole = widget.seerInspectedRoles[player.id];
    final isSniffed = (widget.foxSniffedPlayerIds.contains(player.id) || player.isSniffed) &&
        canSeeFoxSniff &&
        (player.isAlive || isDevMode);
    final isWolfDetectedInTrio = widget.foxWolfDetected ?? player.hasWolfSmell;
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
      key: ValueKey('radial_node_${player.id}'),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
      left: x,
      top: y,
      width: hitWidth,
      height: hitHeight,
      child: RepaintBoundary(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: player.isAlive
              ? () {
                  HapticFeedback.selectionClick();
                  widget.onPlayerSelected(player.id);
                }
              : null,
          child: Center(
            child: SizedBox(
              width: nodeWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Jeton de joueur avec animation spectrale de mort
                  GhostDeathBadge(
                    playerUid: player.id,
                    isAlive: player.isAlive,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        // 1. Onde de choc et halo néon pulsant pour celui qui a la parole (Isolé)
                        if (isSpeaking)
                        _SpeakingPulseHalo(
                          pulseAnimation: _pulseAnimation,
                          avatarSize: avatarSize,
                        ),

                      // 2. Halo pulsant fluide pour joueur charmé (Joueur de Flûte 🎵)
                      if (FogOfWarService.canSeeCharmedBadge(
                        targetIsCharmed: player.isCharmed,
                        observerRole: widget.myRole,
                        observerIsCharmed: myIsCharmed,
                        isDevMode: isDevMode,
                      ))
                        CharmedPulsingHalo(
                          size: avatarSize,
                          child: const SizedBox.shrink(),
                        ),

                      // 3. Avatar du joueur avec décoration et animation de flash Capitaine conditionnelle
                      _buildAvatarToken(
                        player: player,
                        isDead: isDead,
                        isMe: isMe,
                        isSpeaking: isSpeaking,
                        isWolfPeer: isWolfPeer,
                        seerDiscoveredRole: seerDiscoveredRole,
                        isSniffed: isSniffed,
                        isWolfDetectedInTrio: isWolfDetectedInTrio,
                        isProtected: isProtected,
                        isWitchHealed: isWitchHealed,
                        isWitchPoisoned: isWitchPoisoned,
                        isWitchVictim: isWitchVictim,
                        isCrowTarget: isCrowTarget,
                        isWildChildModel: isWildChildModel,
                        isContaminatedWolf: isContaminatedWolf,
                        isBearTamerGrowling: isBearTamerGrowling,
                        isSelected: isSelected,
                        isNewCaptainFlashing: isNewCaptainFlashing,
                        avatarSize: avatarSize,
                        initials: initials,
                        fontSize: dimensions.fontSize + 1.5,
                      ),

                      // 4. Flash d'impact et réticule du Chasseur 🎯
                      if (widget.hunterShotTargetId == player.id)
                        Positioned.fill(
                          child: HunterImpactEffect(size: avatarSize),
                        ),

                      // 5. Propagation radiale de flammes du Pyromane 🔥
                      if (widget.pyroIgnitedPlayerIds?.contains(player.id) == true)
                        Positioned.fill(
                          child: PyroFlameBurstEffect(size: avatarSize),
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

                      // Badge Flairage du Renard (visible uniquement pour le Renard ou DevMode)
                      if (isSniffed && !isMe)
                        Positioned(
                          top: -6,
                          left: (isWolfPeer || FogOfWarService.canSeeLoverBadge(
                            targetIsLover: player.isLover,
                            observerRole: widget.myRole,
                            observerIsLover: myIsLover,
                            isDevMode: isDevMode,
                          )) ? 14 : -6,
                          child: AnimatedStatusBadge(
                            child: Container(
                              padding: const EdgeInsets.all(2.0),
                              decoration: BoxDecoration(
                                color: isWolfDetectedInTrio
                                    ? const Color(0xFF4A0404)
                                    : const Color(0xFF2E1A05),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isWolfDetectedInTrio
                                      ? const Color(0xFFFF2A4B)
                                      : const Color(0xFFFB8500),
                                  width: 1.3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isWolfDetectedInTrio
                                        ? const Color(0xFFFF2A4B).withValues(alpha: 0.9)
                                        : const Color(0xFFFB8500).withValues(alpha: 0.8),
                                    blurRadius: 8,
                                    spreadRadius: 1.5,
                                  ),
                                ],
                              ),
                              child: Text(
                                isWolfDetectedInTrio ? '🐾' : '🦊',
                                style: const TextStyle(fontSize: 9.0),
                              ),
                            ),
                          ),
                        ),

                      // Badge Allié Loup-Garou (visible pour les loups)
                      if (isWolfPeer && !isMe && (player.isAlive || isDevMode))
                        Positioned(
                          top: -6,
                          left: -6,
                          child: AnimatedStatusBadge(
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
                        ),

                      // Badge Rôle Sondé par la Voyante (visible uniquement par la voyante)
                      if (seerDiscoveredRole != null && !isMe && (player.isAlive || isDevMode))
                        Positioned(
                          top: -6,
                          right: -6,
                          child: AnimatedStatusBadge(
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
                        ),

                      // Badge Bouclier du Salvateur (visible uniquement par le Salvateur ou DevMode)
                      if (isProtected && !isMe)
                        Positioned(
                          top: -6,
                          right: (seerDiscoveredRole != null || player.isCaptain) ? 14 : -6,
                          child: AnimatedStatusBadge(
                            child: Container(
                              padding: const EdgeInsets.all(2.0),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F1E36),
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF3A86FF), width: 1.3),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF3A86FF).withValues(alpha: 0.85),
                                    blurRadius: 8,
                                    spreadRadius: 1.5,
                                  ),
                                ],
                              ),
                              child: const Text('🛡️', style: TextStyle(fontSize: 9.0)),
                            ),
                          ),
                        ),

                      // Badge Potion de vie de la Sorcière (visible pour la Sorcière ou DevMode)
                      if (isWitchHealed && !isMe)
                        Positioned(
                          top: -6,
                          right: -6,
                          child: AnimatedStatusBadge(
                            child: Container(
                              padding: const EdgeInsets.all(2.0),
                              decoration: BoxDecoration(
                                color: const Color(0xFF063B2C),
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF06D6A0), width: 1.3),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF06D6A0).withValues(alpha: 0.85),
                                    blurRadius: 8,
                                    spreadRadius: 1.5,
                                  ),
                                ],
                              ),
                              child: const Text('🧪', style: TextStyle(fontSize: 9.0)),
                            ),
                          ),
                        ),

                      // Badge Potion de mort de la Sorcière (visible pour la Sorcière ou DevMode)
                      if (isWitchPoisoned && !isMe)
                        Positioned(
                          top: -6,
                          right: -6,
                          child: AnimatedStatusBadge(
                            child: Container(
                              padding: const EdgeInsets.all(2.0),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2E083B),
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF9D4EDD), width: 1.3),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF9D4EDD).withValues(alpha: 0.85),
                                    blurRadius: 8,
                                    spreadRadius: 1.5,
                                  ),
                                ],
                              ),
                              child: const Text('☠️', style: TextStyle(fontSize: 9.0)),
                            ),
                          ),
                        ),

                      // Badge Victime des Loups (visible pour la Sorcière pendant son tour)
                      if (isWitchVictim && !isWitchHealed && !isMe)
                        Positioned(
                          top: -6,
                          right: -6,
                          child: AnimatedStatusBadge(
                            child: Container(
                              padding: const EdgeInsets.all(2.0),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3B0808),
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFFFF2A4B), width: 1.3),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFF2A4B).withValues(alpha: 0.85),
                                    blurRadius: 8,
                                    spreadRadius: 1.5,
                                  ),
                                ],
                              ),
                              child: const Text('🩸', style: TextStyle(fontSize: 9.0)),
                            ),
                          ),
                        ),

                      // Badge Cible maudite du Corbeau (visible pour Corbeau la nuit, public le jour)
                      if (isCrowTarget && !isMe)
                        Positioned(
                          top: -6,
                          left: (isSniffed || isWolfPeer || player.isLover) ? 14 : -6,
                          child: AnimatedStatusBadge(
                            child: Container(
                              padding: const EdgeInsets.all(2.0),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF94A3B8), width: 1.3),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF64748B).withValues(alpha: 0.85),
                                    blurRadius: 8,
                                    spreadRadius: 1.5,
                                  ),
                                ],
                              ),
                              child: const Text('🦅', style: TextStyle(fontSize: 9.0)),
                            ),
                          ),
                        ),

                      // Badge Modèle de l'Enfant Sauvage (visible uniquement par l'Enfant Sauvage ou DevMode)
                      if (isWildChildModel && !isMe)
                        Positioned(
                          top: -6,
                          right: -6,
                          child: AnimatedStatusBadge(
                            child: Container(
                              padding: const EdgeInsets.all(2.0),
                              decoration: BoxDecoration(
                                color: const Color(0xFF112E1F),
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF52B788), width: 1.3),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF52B788).withValues(alpha: 0.85),
                                    blurRadius: 8,
                                    spreadRadius: 1.5,
                                  ),
                                ],
                              ),
                              child: const Text('🌱', style: TextStyle(fontSize: 9.0)),
                            ),
                          ),
                        ),

                      // Badge Loup contaminé par l'Épée Rouillée (visible pour les loups ou DevMode)
                      if (isContaminatedWolf && !isMe)
                        Positioned(
                          bottom: -4,
                          left: 10,
                          child: AnimatedStatusBadge(
                            child: Container(
                              padding: const EdgeInsets.all(2.0),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2C1E21),
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFFE5989B), width: 1.3),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFB5838D).withValues(alpha: 0.85),
                                    blurRadius: 8,
                                    spreadRadius: 1.5,
                                  ),
                                ],
                              ),
                              child: const Text('🗡️', style: TextStyle(fontSize: 9.0)),
                            ),
                          ),
                        ),

                      // Badge Grognement du Montreur d'Ours au matin
                      if (isBearTamerGrowling && !isMe)
                        Positioned(
                          top: -6,
                          right: -6,
                          child: AnimatedStatusBadge(
                            child: Container(
                              padding: const EdgeInsets.all(2.0),
                              decoration: BoxDecoration(
                                color: const Color(0xFF331C0E),
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFFDDA15E), width: 1.3),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFBC6C25).withValues(alpha: 0.85),
                                    blurRadius: 8,
                                    spreadRadius: 1.5,
                                  ),
                                ],
                              ),
                              child: const Text('🐻', style: TextStyle(fontSize: 9.0)),
                            ),
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
                              : AnimatedStatusBadge(
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: LupusColors.arcaneGold,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.star_rounded,
                                        size: 8.5, color: Colors.black),
                                  ),
                                ),
                        ),

                      // Badge Amoureux (Cœur - strictement filtré par FogOfWarService)
                      if (FogOfWarService.canSeeLoverBadge(
                        targetIsLover: player.isLover,
                        observerRole: widget.myRole,
                        observerIsLover: myIsLover,
                        isDevMode: isDevMode,
                      ))
                        Positioned(
                          top: -4,
                          left: -4,
                          child: AnimatedStatusBadge(
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
                        ),

                      // Badge Maison Imbibée de Carburant (Pyromane)
                      if (player.isDoused &&
                          (isMe ||
                              widget.myRole == GameRole.pyromaniac ||
                              isDevMode ||
                              isDead))
                        Positioned(
                          bottom: -4,
                          left: -4,
                          child: AnimatedStatusBadge(
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
                        ),

                      // Badge Envoûté (Joueur de Flûte - strictement filtré par FogOfWarService)
                      if (FogOfWarService.canSeeCharmedBadge(
                        targetIsCharmed: player.isCharmed,
                        observerRole: widget.myRole,
                        observerIsCharmed: myIsCharmed,
                        isDevMode: isDevMode,
                      ))
                        Positioned(
                          bottom: -4,
                          left: 10,
                          child: AnimatedStatusBadge(
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
                        ),

                      // Badge Infecté (Loup Infect)
                      if (player.isInfected &&
                          (isMe ||
                              widget.myRole.isEvil ||
                              isDevMode ||
                              isDead))
                        Positioned(
                          top: 10,
                          right: -4,
                          child: AnimatedStatusBadge(
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
                        ),

                      // Badge Bâillonné / Muté (Loup Noir)
                      if (player.isMuted)
                        Positioned(
                          top: 10,
                          left: -4,
                          child: AnimatedStatusBadge(
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
                      if (isSniffed && !isMe) ...[
                        Text(isWolfDetectedInTrio ? '🐾' : '🦊', style: const TextStyle(fontSize: 8.0)),
                        const SizedBox(width: 1.5),
                      ],
                      if (isProtected && !isMe) ...[
                        const Text('🛡️', style: TextStyle(fontSize: 8.0)),
                        const SizedBox(width: 1.5),
                      ],
                      if (isWitchHealed && !isMe) ...[
                        const Text('🧪', style: TextStyle(fontSize: 8.0)),
                        const SizedBox(width: 1.5),
                      ],
                      if (isWitchPoisoned && !isMe) ...[
                        const Text('☠️', style: TextStyle(fontSize: 8.0)),
                        const SizedBox(width: 1.5),
                      ],
                      if (isWitchVictim && !isMe) ...[
                        const Text('🩸', style: TextStyle(fontSize: 8.0)),
                        const SizedBox(width: 1.5),
                      ],
                      if (isCrowTarget && !isMe) ...[
                        const Text('🦅', style: TextStyle(fontSize: 8.0)),
                        const SizedBox(width: 1.5),
                      ],
                      if (isWildChildModel && !isMe) ...[
                        const Text('🌱', style: TextStyle(fontSize: 8.0)),
                        const SizedBox(width: 1.5),
                      ],
                      if (isContaminatedWolf && !isMe) ...[
                        const Text('🗡️', style: TextStyle(fontSize: 8.0)),
                        const SizedBox(width: 1.5),
                      ],
                      if (isBearTamerGrowling && !isMe) ...[
                        const Text('🐻', style: TextStyle(fontSize: 8.0)),
                        const SizedBox(width: 1.5),
                      ],
                      if (player.isInfected &&
                          (isMe || isWolfPeer || isDevMode || isDead)) ...[
                        const Text('🩸', style: TextStyle(fontSize: 8.0)),
                        const SizedBox(width: 1.5),
                      ],
                      if (player.isCharmed &&
                          (isMe ||
                              widget.myRole == GameRole.piedPiper ||
                              isDevMode ||
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
                                    (seerDiscoveredRole != null && !isMe) ||
                                    (isSniffed && !isMe))
                                ? FontWeight.w800
                                : FontWeight.w500,
                            color: (isWolfPeer && !isMe)
                                ? const Color(0xFFFF5252)
                                : ((seerDiscoveredRole != null && !isMe)
                                    ? const Color(0xFFA5B4FC)
                                    : ((isSniffed && !isMe)
                                        ? (isWolfDetectedInTrio
                                            ? const Color(0xFFFF5252)
                                            : const Color(0xFFFB8500))
                                        : (isDead
                                            ? LupusColors.textMuted
                                            : (isSelected
                                                ? LupusColors.arcaneGold
                                                : LupusColors.textSecondary)))),
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
    required bool isSniffed,
    required bool isWolfDetectedInTrio,
    required bool isProtected,
    required bool isWitchHealed,
    required bool isWitchPoisoned,
    required bool isWitchVictim,
    required bool isCrowTarget,
    required bool isWildChildModel,
    required bool isContaminatedWolf,
    required bool isBearTamerGrowling,
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
                color: (isSniffed && !isMe)
                    ? (isWolfDetectedInTrio
                        ? const Color(0xFFFFB4B4)
                        : const Color(0xFFFFE0B2))
                    : ((isWolfPeer && !isMe)
                        ? const Color(0xFFFFD4D4)
                        : ((seerDiscoveredRole != null && !isMe)
                            ? const Color(0xFFC7D2FE)
                            : (isMe ? const Color(0xFFFFF0D0) : Colors.white))),
              ),
            ),
    );

    Gradient _getAvatarGradient() {
      if (isDead) {
        return const LinearGradient(
          colors: [Color(0xFF1E212D), Color(0xFF12141C)],
        );
      }
      if (!isMe) {
        if (isProtected) {
          return const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1E3A8A), Color(0xFF0F172A)],
          );
        }
        if (isWitchHealed) {
          return const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF065F46), Color(0xFF022C22)],
          );
        }
        if (isWitchPoisoned) {
          return const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF581C87), Color(0xFF3B0764)],
          );
        }
        if (isWitchVictim) {
          return const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF881337), Color(0xFF4C0519)],
          );
        }
        if (isSniffed) {
          return isWolfDetectedInTrio
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF8B1E1E), Color(0xFF3F0B0B)],
                )
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF5A3A1A), Color(0xFF2E1A05)],
                );
        }
        if (isWolfPeer) {
          return const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF8B1E1E), Color(0xFF3F0B0B)],
          );
        }
        if (seerDiscoveredRole != null) {
          return const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF312E81), Color(0xFF1E1B4B)],
          );
        }
      }
      if (isMe) {
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF8D705C), Color(0xFF5A4335)],
        );
      }
      return const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF3F4558), Color(0xFF232734)],
      );
    }

    Color _getAvatarBorderColor(double flash) {
      if (isNewCaptainFlashing && flash > 0) {
        return Color.lerp(LupusColors.arcaneGold, Colors.white, flash)!;
      }
      if (isSpeaking) {
        return const Color(0xFF00FF88);
      }
      if (!isMe) {
        if (isProtected) return const Color(0xFF3A86FF);
        if (isWitchHealed) return const Color(0xFF06D6A0);
        if (isWitchPoisoned) return const Color(0xFF9D4EDD);
        if (isWitchVictim) return const Color(0xFFFF2A4B);
        if (isSniffed) {
          return isWolfDetectedInTrio
              ? const Color(0xFFFF1E46)
              : const Color(0xFFFB8500);
        }
        if (isCrowTarget) return const Color(0xFF94A3B8);
        if (isWildChildModel) return const Color(0xFF52B788);
        if (isContaminatedWolf) return const Color(0xFFE5989B);
        if (isBearTamerGrowling) return const Color(0xFFDDA15E);
        if (isWolfPeer) return const Color(0xFFFF2A4B);
        if (seerDiscoveredRole != null) return const Color(0xFF818CF8);
      }
      if (isSelected) return LupusColors.arcaneGold;
      if (isDead) return LupusColors.arcaneCrimson.withValues(alpha: 0.45);
      if (isMe) return LupusColors.arcaneGold.withValues(alpha: 0.6);
      return LupusColors.arcanePurple.withValues(alpha: 0.35);
    }

    double _getAvatarBorderWidth(double flash) {
      if (isNewCaptainFlashing && flash > 0) {
        return 2.5 + (1.5 * flash);
      }
      final hasSpecialStatus = isSpeaking ||
          ((isWolfPeer ||
                  seerDiscoveredRole != null ||
                  isSniffed ||
                  isProtected ||
                  isWitchHealed ||
                  isWitchPoisoned ||
                  isWitchVictim ||
                  isCrowTarget ||
                  isWildChildModel ||
                  isContaminatedWolf ||
                  isBearTamerGrowling) &&
              !isMe);
      if (hasSpecialStatus) return 2.6;
      if (isSelected) return 2.2;
      return 1.2;
    }

    List<BoxShadow>? _getAvatarBoxShadow(double flash) {
      if (isNewCaptainFlashing && flash > 0) {
        return [
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
        ];
      }
      if (isSpeaking) {
        return [
          const BoxShadow(
            color: Color(0xFF00FF88),
            blurRadius: 10,
            spreadRadius: 2,
          ),
          if (isSelected)
            BoxShadow(
              color: LupusColors.arcaneGold.withValues(alpha: 0.7),
              blurRadius: 14,
              spreadRadius: 2.5,
            ),
        ];
      }
      if (!isMe) {
        Color? glowColor;
        double blur = 14;
        double spread = 2.2;

        if (isProtected) {
          glowColor = const Color(0xFF3A86FF).withValues(alpha: 0.85);
        } else if (isWitchHealed) {
          glowColor = const Color(0xFF06D6A0).withValues(alpha: 0.85);
        } else if (isWitchPoisoned) {
          glowColor = const Color(0xFF9D4EDD).withValues(alpha: 0.85);
        } else if (isWitchVictim) {
          glowColor = const Color(0xFFFF2A4B).withValues(alpha: 0.85);
        } else if (isSniffed) {
          glowColor = isWolfDetectedInTrio
              ? const Color(0xFFFF1E46).withValues(alpha: 0.85)
              : const Color(0xFFFB8500).withValues(alpha: 0.75);
          blur = isWolfDetectedInTrio ? 14 : 12;
          spread = isWolfDetectedInTrio ? 2.5 : 2.0;
        } else if (isCrowTarget) {
          glowColor = const Color(0xFF64748B).withValues(alpha: 0.8);
          blur = 12;
          spread = 2.0;
        } else if (isWildChildModel) {
          glowColor = const Color(0xFF52B788).withValues(alpha: 0.8);
          blur = 12;
          spread = 2.0;
        } else if (isContaminatedWolf) {
          glowColor = const Color(0xFFB5838D).withValues(alpha: 0.8);
          blur = 12;
          spread = 2.0;
        } else if (isBearTamerGrowling) {
          glowColor = const Color(0xFFDDA15E).withValues(alpha: 0.8);
          blur = 12;
          spread = 2.0;
        } else if (isWolfPeer) {
          glowColor = const Color(0xFFFF2A4B);
          blur = 12;
          spread = 2.0;
        } else if (seerDiscoveredRole != null) {
          glowColor = const Color(0xFF6366F1);
          blur = 12;
          spread = 2.0;
        }

        if (glowColor != null) {
          return [
            BoxShadow(
              color: glowColor,
              blurRadius: blur,
              spreadRadius: spread,
            ),
            if (isSelected)
              BoxShadow(
                color: LupusColors.arcaneGold.withValues(alpha: 0.7),
                blurRadius: 14,
                spreadRadius: 2.5,
              ),
          ];
        }
      }

      if (isSelected) {
        return LupusTheme.glowGold(opacity: 0.6);
      }
      return null;
    }

    BoxDecoration getAvatarDecoration(double flash) {
      return BoxDecoration(
        shape: BoxShape.circle,
        gradient: _getAvatarGradient(),
        border: Border.all(
          color: _getAvatarBorderColor(flash),
          width: _getAvatarBorderWidth(flash),
        ),
        boxShadow: _getAvatarBoxShadow(flash),
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
