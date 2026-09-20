import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/player_model.dart';
import '../../services/app_translations.dart';
import '../../services/fog_of_war_service.dart';
import '../theme/lupus_avatars.dart';
import '../theme/lupus_theme.dart';
import 'animated_status_badge.dart';
import 'bento_card.dart';
import 'game_action_visual_effects.dart';
import 'ghost_death_badge.dart';

/// Tuile individuelle représentant un joueur dans la grille Bento
class BentoPlayerTile extends StatelessWidget {
  final PlayerModel player;
  final bool isMe;
  final bool isSpeaking;
  final bool isSelected;
  final int votesCount;
  final bool showRole;
  final bool isWolfPeer;
  final GameRole? seerDiscoveredRole;
  final bool isDevMode;
  final GameRole myRole;
  final bool myIsLover;
  final bool myIsCharmed;
  final bool isSniffed;
  final bool hasWolfSmell;
  final bool isProtected;
  final bool isWitchVictim;
  final bool isWitchHealed;
  final bool isWitchPoisoned;
  final bool isCrowTarget;
  final bool isWildChildModel;
  final bool isContaminatedWolf;
  final bool isBearTamerGrowling;
  final bool isHunterImpact;
  final bool isPyroIgnited;
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
    this.seerDiscoveredRole,
    this.isDevMode = false,
    this.myRole = GameRole.simpleVillager,
    this.myIsLover = false,
    this.myIsCharmed = false,
    this.isSniffed = false,
    this.hasWolfSmell = false,
    this.isProtected = false,
    this.isWitchVictim = false,
    this.isWitchHealed = false,
    this.isWitchPoisoned = false,
    this.isCrowTarget = false,
    this.isWildChildModel = false,
    this.isContaminatedWolf = false,
    this.isBearTamerGrowling = false,
    this.isHunterImpact = false,
    this.isPyroIgnited = false,
    this.onTap,
  });

  // Liste d'avatars thématiques
  static List<IconData> get avatarIcons => LupusAvatars.icons;

  @override
  Widget build(BuildContext context) {
    final isDead = !player.isAlive;
    final avatarItem = LupusAvatars.getByIndex(player.avatarIndex);
    final icon = avatarItem.icon;

    // Seules exceptions autorisées pour afficher le rôle :
    // 1. Mon propre rôle (isMe)
    // 2. Joueur éliminé révélé au village (isDead)
    // 3. Voyante ayant personnellement sondé ce joueur (seerDiscoveredRole != null)
    // 4. Confrère Loup-Garou (isWolfPeer && player.isAlive)
    // 5. Dev-Mode strict (isDevMode => isDevModeActive && isDevRoom)
    final canSeeRole = isMe ||
        isDead ||
        isDevMode ||
        (isWolfPeer && player.isAlive) ||
        (seerDiscoveredRole != null && player.isAlive);

    final GameRole roleToDisplay =
        (seerDiscoveredRole != null && !isMe && !isDead)
            ? seerDiscoveredRole!
            : (isDead ? player.roleInitial : player.role);

    String roleLabel;
    if (isMe) {
      roleLabel = context.tr('my_role_label', {'role': player.role.getDisplayName(context)});
    } else if (isDead) {
      roleLabel = player.roleInitial.getDisplayName(context);
    } else if (seerDiscoveredRole != null) {
      roleLabel = '🔮 ${seerDiscoveredRole!.getDisplayName(context)}';
    } else if (isWolfPeer) {
      final wolfName = (player.role == GameRole.whiteWerewolf)
          ? context.tr('role_white_werewolf')
          : (player.role.isEvil && player.role != GameRole.simpleVillager)
              ? player.role.getDisplayName(context)
              : context.tr('role_simple_werewolf');
      roleLabel = '🐺 $wolfName';
    } else if (isDevMode) {
      roleLabel = player.estDechu
          ? '${player.role.getDisplayName(context)} (Ex-${player.roleInitial.getDisplayName(context)})'
          : player.role.getDisplayName(context);
    } else {
      roleLabel = context.tr('alive');
    }

    Color borderColor;
    if (isSpeaking && player.isAlive) {
      borderColor = const Color(0xFF00FF88);
    } else if (isSelected) {
      borderColor = LupusColors.bloodRed;
    } else if (isDead) {
      borderColor = Colors.black45;
    } else if (isWolfPeer && player.isAlive && !isMe) {
      borderColor = LupusColors.bloodRed.withValues(alpha: 0.7);
    } else {
      borderColor = LupusColors.border;
    }

    return RepaintBoundary(
      child: BentoCard(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      onTap: onTap != null
          ? () {
              HapticFeedback.selectionClick();
              onTap!();
            }
          : null,
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
          // 1. Avatar avec badge parole / badge mort et animation spectrale de trépas
          GhostDeathBadge(
            playerUid: player.id,
            isAlive: player.isAlive,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // 0. Halo néon pulsant Flûte
                  if (FogOfWarService.canSeeCharmed(
                    targetIsCharmed: player.isCharmed,
                    observerRole: myRole,
                    observerIsCharmed: myIsCharmed,
                    isDevMode: isDevMode,
                  ))
                    const CharmedPulsingHalo(size: 44),

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

                  // Rond d'avatar principal stylisé Dark Fantasy
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isDead
                          ? const LinearGradient(
                              colors: [Color(0xFF202025), Color(0xFF121214)],
                            )
                          : LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: avatarItem.gradientColors,
                            ),
                      border: Border.all(
                        color: isDead
                            ? Colors.white12
                            : avatarItem.borderColor.withValues(alpha: 0.8),
                        width: 1.2,
                      ),
                      boxShadow: isDead
                          ? null
                          : [
                              BoxShadow(
                                color: avatarItem.glowColor,
                                blurRadius: 6,
                              ),
                            ],
                    ),
                    child: Center(
                      child: Icon(
                        isDead ? Icons.sentiment_very_dissatisfied_rounded : icon,
                        color: isDead ? LupusColors.textMuted : Colors.white,
                        size: 20,
                      ),
                    ),
                  ),

                  // Effet d'impact du Chasseur 🎯
                  if (isHunterImpact)
                    const Positioned.fill(
                      child: HunterImpactEffect(size: 36),
                    ),

                  // Effet de flammes du Pyromane 🔥
                  if (isPyroIgnited)
                    const Positioned.fill(
                      child: PyroFlameBurstEffect(size: 36),
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

                  // Indicateur hors ligne (si déconnecté en cours de partie)
                  if (!player.isOnline && player.isAlive)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Color(0xFF1E212D),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.wifi_off_rounded,
                          color: Colors.amber,
                          size: 11,
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

                  // Indicateur micro barré rouge si bâillonné (silence forcé)
                  if (player.isMuted && player.isAlive)
                    Positioned(
                      bottom: -2,
                      left: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF200A10),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFFF3333),
                            width: 1.2,
                          ),
                        ),
                        child: const Icon(
                          Icons.mic_off_rounded,
                          color: Color(0xFFFF3333),
                          size: 11,
                        ),
                      ),
                    ),

                  // Badges de rôles actifs avec AnimatedStatusBadge
                  // Renard (Flairage)
                  if (isSniffed && !isMe)
                    Positioned(
                      top: -4,
                      left: -4,
                      child: AnimatedStatusBadge(
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: hasWolfSmell ? const Color(0xFFFF1E46) : const Color(0xFFFB8500),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 0.8),
                          ),
                          child: Text(
                            hasWolfSmell ? '🐺' : '🦊',
                            style: const TextStyle(fontSize: 8.5),
                          ),
                        ),
                      ),
                    ),

                  // Salvateur (Bouclier)
                  if (isProtected && !isMe)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: const AnimatedStatusBadge(
                        child: Text('🛡️', style: TextStyle(fontSize: 9.5)),
                      ),
                    ),

                  // Sorcière : Sauvé
                  if (isWitchHealed && !isMe)
                    Positioned(
                      bottom: -4,
                      left: -4,
                      child: const AnimatedStatusBadge(
                        child: Text('🧪', style: TextStyle(fontSize: 9.5)),
                      ),
                    ),

                  // Sorcière : Empoisonné
                  if (isWitchPoisoned && !isMe)
                    Positioned(
                      bottom: -4,
                      left: -4,
                      child: const AnimatedStatusBadge(
                        child: Text('☠️', style: TextStyle(fontSize: 9.5)),
                      ),
                    ),

                  // Sorcière : Cible des loups
                  if (isWitchVictim && !isMe)
                    Positioned(
                      bottom: -4,
                      right: -4,
                      child: const AnimatedStatusBadge(
                        child: Text('🩸', style: TextStyle(fontSize: 9.5)),
                      ),
                    ),

                  // Corbeau
                  if (isCrowTarget && !isMe)
                    Positioned(
                      top: -4,
                      left: -4,
                      child: const AnimatedStatusBadge(
                        child: Text('🦅', style: TextStyle(fontSize: 9.5)),
                      ),
                    ),

                  // Enfant Sauvage : Modèle
                  if (isWildChildModel && !isMe)
                    Positioned(
                      bottom: -4,
                      left: -4,
                      child: const AnimatedStatusBadge(
                        child: Text('🌱', style: TextStyle(fontSize: 9.5)),
                      ),
                    ),

                  // Chevalier à l'épée rouillée : Contaminé
                  if (isContaminatedWolf && !isMe)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: const AnimatedStatusBadge(
                        child: Text('🗡️', style: TextStyle(fontSize: 9.5)),
                      ),
                    ),

                  // Montreur d'ours : Grognement
                  if (isBearTamerGrowling && !isMe)
                    Positioned(
                      bottom: -4,
                      right: -4,
                      child: const AnimatedStatusBadge(
                        child: Text('🐻', style: TextStyle(fontSize: 9.5)),
                      ),
                    ),
                ],
              ),
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
                  const AnimatedStatusBadge(
                    child: Icon(Icons.star_rounded,
                        size: 12, color: LupusColors.sunAmber),
                  ),
                  const SizedBox(width: 2),
                ],
                if (player.isCaptain) ...[
                  const AnimatedStatusBadge(
                    child: Icon(Icons.military_tech_rounded,
                        size: 12, color: Color(0xFFFFD700)),
                  ),
                  const SizedBox(width: 2),
                ],
                if (isWolfPeer && !isMe && player.isAlive) ...[
                  const AnimatedStatusBadge(
                    child: Text('🐺', style: TextStyle(fontSize: 10)),
                  ),
                  const SizedBox(width: 2),
                ],
                if (seerDiscoveredRole != null && !isMe && player.isAlive) ...[
                  const AnimatedStatusBadge(
                    child: Text('🔮', style: TextStyle(fontSize: 10)),
                  ),
                  const SizedBox(width: 2),
                ],
                if (FogOfWarService.canSeeLoverBadge(
                  targetIsLover: player.isLover,
                  observerRole: myRole,
                  observerIsLover: myIsLover,
                  isDevMode: isDevMode,
                )) ...[
                  const AnimatedStatusBadge(
                    child: Icon(Icons.favorite_rounded,
                        size: 11, color: LupusColors.bloodRed),
                  ),
                  const SizedBox(width: 2),
                ],
                if (FogOfWarService.canSeeCharmedBadge(
                  targetIsCharmed: player.isCharmed,
                  observerRole: myRole,
                  observerIsCharmed: myIsCharmed,
                  isDevMode: isDevMode,
                )) ...[
                  const AnimatedStatusBadge(
                    child: Icon(Icons.music_note_rounded,
                        size: 11, color: Color(0xFF06D6A0)),
                  ),
                  const SizedBox(width: 2),
                ],
                if (player.isDoused && (isMe || myRole == GameRole.pyromaniac || isDevMode || isDead)) ...[
                  const AnimatedStatusBadge(
                    child: Icon(Icons.local_fire_department_rounded,
                        size: 11, color: Color(0xFFFF4800)),
                  ),
                  const SizedBox(width: 2),
                ],
                if (player.isMuted) ...[
                  const AnimatedStatusBadge(
                    child: Icon(Icons.mic_off_rounded,
                        size: 11, color: Color(0xFFFF3333)),
                  ),
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

          // 3. Rôle ou État de Vie (Masqué côté client hors exceptions)
          if (canSeeRole) ...[
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: (isWolfPeer && !isMe && !isDevMode && seerDiscoveredRole == null)
                    ? LupusColors.bloodRed.withValues(alpha: 0.25)
                    : roleToDisplay.accentColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: (isWolfPeer && !isMe && !isDevMode && seerDiscoveredRole == null)
                      ? LupusColors.bloodRed.withValues(alpha: 0.6)
                      : roleToDisplay.accentColor.withValues(alpha: 0.4),
                  width: 0.8,
                ),
              ),
              child: Text(
                roleLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  color: (isWolfPeer && !isMe && !isDevMode && seerDiscoveredRole == null)
                      ? const Color(0xFFFF8B8B)
                      : roleToDisplay.accentColor,
                ),
              ),
            ),
          ] else ...[
            Text(
              isDead ? context.tr('eliminated') : context.tr('alive'),
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
            AnimatedStatusBadge(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: LupusColors.bloodRed,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$votesCount ${votesCount > 1 ? context.tr("votes_suffix") : context.tr("vote_suffix")}',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
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
