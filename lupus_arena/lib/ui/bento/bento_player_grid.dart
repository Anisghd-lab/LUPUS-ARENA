import 'package:flutter/material.dart';

import '../../models/player_model.dart';
import '../../services/app_translations.dart';
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
  final Set<String> wolfPlayerIds;

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
    this.wolfPlayerIds = const {},
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
        final isDevMode = isDevModeActive || isDevRoom;
        final isMeWolfTeam = isMeEvil ||
            myRole.isEvil ||
            myRole.isWolfTeam ||
            wolfPlayerIds.contains(currentUserId);
        final isOtherWolf = player.role.isEvil ||
            player.role.isWolfTeam ||
            wolfPlayerIds.contains(player.id);
        final isWolfPeer = isMeWolfTeam && isOtherWolf;
        final seerRole = seerInspectedRoles[player.id];

        final me = players.cast<PlayerModel?>().firstWhere(
              (p) => p?.id == currentUserId,
              orElse: () => null,
            );
        final myIsLover = me?.isLover ?? false;
        final myIsCharmed = me?.isCharmed ?? false;

        return BentoPlayerTile(
          player: player,
          isMe: isMe,
          isSpeaking: isSpeaking,
          isSelected: isSelected,
          votesCount: votes,
          showRole: revealRoles || (!player.isAlive) || isDevMode,
          isWolfPeer: isWolfPeer,
          seerDiscoveredRole: seerRole,
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
