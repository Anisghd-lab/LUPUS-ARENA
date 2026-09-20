import 'package:flutter/material.dart';

import '../../models/player_model.dart';
import '../../services/app_translations.dart';
import '../../services/fog_of_war_service.dart';
import '../theme/lupus_theme.dart';
import 'bento_player_tile.dart';

/// Grille Bento réactive organisant les joueurs autour de l'arène
class BentoPlayerGrid extends StatelessWidget {
  final List<PlayerModel> players;
  final String currentUserId;
  final Set<int> speakingAgoraUids;
  final String? currentSpeakerId;
  final String? selectedPlayerId;
  final ValueChanged<String>? onPlayerSelected;
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
  final String? hunterShotTargetId;
  final Set<String>? pyroIgnitedPlayerIds;

  const BentoPlayerGrid({
    super.key,
    required this.players,
    required this.currentUserId,
    required this.speakingAgoraUids,
    this.currentSpeakerId,
    this.selectedPlayerId,
    this.onPlayerSelected,
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
    this.hunterShotTargetId,
    this.pyroIgnitedPlayerIds,
  });

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: Text(
          context.tr('waiting_villagers'),
          style: const TextStyle(
            fontSize: 12,
            color: LupusColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    // Calculer le total des votes reçus par chaque joueur
    final Map<String, int> votesPerPlayer = {};
    for (final p in players) {
      if (p.targetVoteId != null) {
        votesPerPlayer[p.targetVoteId!] =
            (votesPerPlayer[p.targetVoteId!] ?? 0) + 1;
      }
    }

    final screenWidth = MediaQuery.of(context).size.width;
    // Ratio vertical équilibré pour garantir l'espace nécessaire à l'avatar et au nom sans dépassement
    final double ratio = screenWidth < 380
        ? 0.64
        : (screenWidth < 500 ? 0.70 : 0.78);

    // Pré-calculs uniques O(1) hors-boucle pour le rendu de la grille
    final isDevMode = isDevModeActive || isDevRoom;
    final isMeWolfTeam = isMeEvil ||
        myRole.isEvil ||
        myRole.isWolfTeam ||
        wolfPlayerIds.contains(currentUserId);

    PlayerModel? me;
    for (final p in players) {
      if (p.id == currentUserId) {
        me = p;
        break;
      }
    }
    final myIsLover = me?.isLover ?? false;
    final myIsCharmed = me?.isCharmed ?? false;

    return GridView.builder(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      itemCount: players.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: ratio,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (context, index) {
        final player = players[index];
        final isMe = player.id == currentUserId;
        final isVoiceActive = !player.isBot &&
            player.agoraUid > 0 &&
            speakingAgoraUids.contains(player.agoraUid);
        final hasFloor = currentSpeakerId != null && currentSpeakerId == player.id;
        final isSpeaking = (isVoiceActive || hasFloor) && player.isAlive;
        final isSelected = selectedPlayerId == player.id;
        final votes = votesPerPlayer[player.id] ?? 0;
        final isOtherWolf = player.role.isEvil ||
            player.role.isWolfTeam ||
            wolfPlayerIds.contains(player.id);
        final isWolfPeer = isMeWolfTeam && isOtherWolf;
        final seerRole = seerInspectedRoles[player.id];

        final isProtected = FogOfWarService.canSeeDefenderShield(
          targetIsProtected: currentProtectedPlayerId == player.id,
          observerRole: myRole,
          isDevMode: isDevMode,
        );
        final isWitchVictim = FogOfWarService.canSeeWitchWolfVictim(
          targetIsVictim: nightVictimId == player.id,
          observerRole: myRole,
          isNightWitch: isNightWitch,
          isDevMode: isDevMode,
        );
        final isWitchHealed = FogOfWarService.canSeeWitchHealed(
          targetIsHealed: witchHealed && (nightVictimId == player.id),
          observerRole: myRole,
          isDevMode: isDevMode,
        );
        final isWitchPoisoned = FogOfWarService.canSeeWitchPoisoned(
          targetIsPoisoned: witchPoisonVictimId == player.id,
          observerRole: myRole,
          isDevMode: isDevMode,
        );
        final isCrowTarget = FogOfWarService.canSeeCrowTarget(
          targetIsCrowTarget: crowTargetId == player.id,
          isDayTime: isDayTime,
          observerRole: myRole,
          isDevMode: isDevMode,
        );
        final isWildChildModel = FogOfWarService.canSeeWildChildModel(
          targetIsModel: wildChildModelId == player.id,
          observerRole: myRole,
          isDevMode: isDevMode,
        );
        final isContaminatedWolf = FogOfWarService.canSeeRustyKnightContamination(
          targetIsContaminated: rustyKnightContaminatedWolfId == player.id,
          isObserverWolf: isMeWolfTeam,
          isObserverContaminated: rustyKnightContaminatedWolfId == currentUserId,
          isDevMode: isDevMode,
        );
        final isBearTamerGrowling = FogOfWarService.canSeeBearGrowl(
          targetIsBearTamer: player.role == GameRole.bearTamer || player.roleInitial == GameRole.bearTamer,
          bearGrowledThisMorning: bearGrowledThisMorning,
          isDayTime: isDayTime,
          isDevMode: isDevMode,
        );

        return BentoPlayerTile(
          key: ValueKey('player_tile_${player.id}'),
          player: player,
          isMe: isMe,
          isSpeaking: isSpeaking,
          isSelected: isSelected,
          votesCount: votes,
          showRole: revealRoles || (!player.isAlive) || isDevMode,
          isWolfPeer: isWolfPeer,
          seerDiscoveredRole: seerRole,
          isSniffed: foxSniffedPlayerIds.contains(player.id) || player.isSniffed,
          hasWolfSmell: foxWolfDetected ?? player.hasWolfSmell,
          isProtected: isProtected,
          isWitchVictim: isWitchVictim,
          isWitchHealed: isWitchHealed,
          isWitchPoisoned: isWitchPoisoned,
          isCrowTarget: isCrowTarget,
          isWildChildModel: isWildChildModel,
          isContaminatedWolf: isContaminatedWolf,
          isBearTamerGrowling: isBearTamerGrowling,
          isHunterImpact: hunterShotTargetId == player.id,
          isPyroIgnited: pyroIgnitedPlayerIds?.contains(player.id) == true,
          isDevMode: isDevMode,
          myRole: myRole,
          myIsLover: myIsLover,
          myIsCharmed: myIsCharmed,
          onTap: onPlayerSelected != null
              ? () => onPlayerSelected!(player.id)
              : null,
        );
      },
    );
  }
}
