import 'package:flutter/material.dart';

import '../../AgoraVoiceService.dart';
import '../../models/game_phase.dart';
import '../../services/app_translations.dart';
import '../theme/lupus_theme.dart';
import 'bento_card.dart';

/// Barre de contrôle vocal Bento pour Agora RTC
class BentoVoiceControls extends StatelessWidget {
  final AgoraVoiceService voiceService = AgoraVoiceService();
  final bool isAlive;
  final bool isCurrentSpeaker;
  final String? currentSpeakerName;
  final GamePhase? phase;
  final bool isMutedByBlackWolf;
  final bool isVictoryVoiceExpired;
  final bool isWolf;

  BentoVoiceControls({
    super.key,
    this.isAlive = true,
    this.isCurrentSpeaker = false,
    this.currentSpeakerName,
    this.phase,
    this.isMutedByBlackWolf = false,
    this.isVictoryVoiceExpired = false,
    this.isWolf = false,
  });

  @override
  Widget build(BuildContext context) {
    final isGameOver = phase == GamePhase.gameOver;
    final isDebateOrDefense =
        phase == GamePhase.dayDebate || phase == GamePhase.dayDefense;

    return ValueListenableBuilder<String?>(
      valueListenable: voiceService.lastErrorMessage,
      builder: (context, lastError, _) {
        return ValueListenableBuilder<String?>(
          valueListenable: voiceService.currentChannel,
          builder: (context, channel, _) {
            final isWolfChannel = channel != null && channel.endsWith('_wolves');

            return ValueListenableBuilder<bool>(
              valueListenable: voiceService.isConnected,
              builder: (context, connected, _) {
                return ValueListenableBuilder<bool>(
                  valueListenable: voiceService.isMuted,
                  builder: (context, muted, _) {
                    return ValueListenableBuilder<bool>(
                      valueListenable: voiceService.isDeafened,
                      builder: (context, deafened, _) {
                        // Calcul des couleurs et libellés selon les priorités du jeu
                        Color statusColor;
                        Color borderColor;
                        String statusText;
                        String subtitleText;

                        if (isGameOver) {
                          if (isVictoryVoiceExpired || muted) {
                            statusColor = LupusColors.bloodRed;
                            borderColor = LupusColors.border;
                            statusText = context.tr('minute_collective_end');
                            subtitleText = context.tr('mic_cut_game_over');
                          } else {
                            statusColor = const Color(0xFF00FF88);
                            borderColor =
                                const Color(0xFF00FF88).withValues(alpha: 0.6);
                            statusText = context.tr('minute_collective');
                            subtitleText = context.tr('minute_collective_desc');
                          }
                        } else if (!isAlive) {
                          statusColor = LupusColors.bloodRed;
                          borderColor = LupusColors.border;
                          statusText = context.tr('shadow_silence');
                          subtitleText = context.tr('shadow_silence_desc');
                        } else if (isMutedByBlackWolf) {
                          statusColor = LupusColors.bloodRed;
                          borderColor = LupusColors.bloodRed.withValues(alpha: 0.8);
                          statusText = context.tr('silence_forced_black_wolf');
                          subtitleText = context.tr('silence_forced_desc');
                        } else if (lastError != null && !connected) {
                          statusColor = LupusColors.bloodRed;
                          borderColor = LupusColors.bloodRed.withValues(alpha: 0.6);
                          statusText = context.tr('error_audio_agora');
                          subtitleText =
                              '${context.tr("audio_channel_error")} • ${context.tr("retry")}';
                        } else if (isWolfChannel) {
                          statusColor = muted
                              ? const Color(0xFFFF2A4B)
                              : const Color(0xFF00FF88);
                          borderColor = const Color(0xFFFF2A4B);
                          statusText = connected
                              ? (muted
                                  ? context.tr('pack_channel_muted')
                                  : context.tr('pack_channel'))
                              : context.tr('pack_channel_connecting');
                          subtitleText = context.tr('pack_channel_desc');
                        } else if (isDebateOrDefense) {
                          if (isCurrentSpeaker) {
                            statusColor = muted
                                ? LupusColors.sunAmber
                                : LupusColors.voiceActive;
                            borderColor = muted
                                ? LupusColors.sunAmber
                                : LupusColors.voiceActive;
                            statusText = muted
                                ? context.tr('you_have_speaking_turn_muted')
                                : context.tr('you_have_speaking_turn_live');
                            subtitleText = muted
                                ? context.tr('press_mic_to_speak')
                                : context.tr('mic_live_listening');
                          } else {
                            statusColor = LupusColors.textMuted;
                            borderColor = LupusColors.border;
                            final name = currentSpeakerName ?? context.tr('speaker');
                            statusText = context.tr('debate_speaker', {'name': name.toUpperCase()});
                            subtitleText = context.tr('listen_attentively');
                          }
                        } else if (phase == GamePhase.nightWerewolves && !isWolf) {
                          statusColor = LupusColors.textMuted;
                          borderColor = LupusColors.border;
                          statusText = 'Nuit des Loups (Silence total)';
                          subtitleText = 'Micro et écoute coupés';
                        } else {
                          // Phases normales (Lobby, Votes, etc.)
                          if (connected) {
                            statusColor = muted
                                ? LupusColors.sunAmber
                                : LupusColors.voiceActive;
                            borderColor = muted
                                ? LupusColors.border
                                : LupusColors.voiceActive.withValues(alpha: 0.4);
                            statusText = muted ? context.tr('mic_muted') : context.tr('mic_live');
                            subtitleText = '${context.tr("village_channel")} : ${channel ?? context.tr("arena")}';
                          } else {
                            statusColor = LupusColors.sunAmber;
                            borderColor = LupusColors.border;
                            statusText = context.tr('voice_waiting');
                            subtitleText = context.tr('voice_connecting');
                          }
                        }

                        final isNightWerewolves = phase == GamePhase.nightWerewolves;
                        final bool canToggleMic = isGameOver
                            ? !isVictoryVoiceExpired
                            : (isAlive &&
                                !isMutedByBlackWolf &&
                                (!isNightWerewolves || isWolf) &&
                                (!isDebateOrDefense || isCurrentSpeaker));

                        return BentoCard(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          borderColor: borderColor,
                          glowing: (isCurrentSpeaker && !muted) ||
                              (isGameOver && !muted && !isVictoryVoiceExpired),
                          child: Row(
                            children: [
                              // Indicateur LED de statut
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: statusColor,
                                  boxShadow: [
                                    BoxShadow(
                                      color: statusColor.withValues(alpha: 0.7),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Libellé d'état
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        if (isWolfChannel)
                                          const Text('🐺 ',
                                              style: TextStyle(fontSize: 12)),
                                        if (isDebateOrDefense && isCurrentSpeaker)
                                          const Text('🎙️ ',
                                              style: TextStyle(fontSize: 12)),
                                        if (isGameOver && !isVictoryVoiceExpired)
                                          const Text('🎉 ',
                                              style: TextStyle(fontSize: 12)),
                                        Flexible(
                                          child: Text(
                                            statusText,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.5,
                                              color: statusColor,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      subtitleText,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: LupusColors.textSecondary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),

                              // Bouton Réessayer si déconnecté ou erreur
                              if (!connected)
                                IconButton.filled(
                                  style: IconButton.styleFrom(
                                    backgroundColor: LupusColors.sunAmber
                                        .withValues(alpha: 0.2),
                                    side: const BorderSide(
                                      color: LupusColors.sunAmber,
                                      width: 1.0,
                                    ),
                                  ),
                                  onPressed: () => voiceService.retryJoin(),
                                  tooltip: context.tr('retry_audio_connection'),
                                  icon: const Icon(
                                    Icons.refresh_rounded,
                                    color: LupusColors.sunAmber,
                                    size: 20,
                                  ),
                                ),

                              if (!connected) const SizedBox(width: 8),

                              // Bouton Activer / Couper Micro
                              IconButton.filled(
                                style: IconButton.styleFrom(
                                  backgroundColor: canToggleMic
                                      ? (muted
                                          ? LupusColors.voiceMuted
                                              .withValues(alpha: 0.2)
                                          : LupusColors.voiceActive
                                              .withValues(alpha: 0.2))
                                      : LupusColors.surfaceLight
                                          .withValues(alpha: 0.5),
                                  side: BorderSide(
                                    color: canToggleMic
                                        ? (muted
                                            ? LupusColors.voiceMuted
                                            : LupusColors.voiceActive)
                                        : LupusColors.border,
                                    width: 1.2,
                                  ),
                                ),
                                onPressed: canToggleMic
                                    ? () async {
                                        if (!connected) {
                                          await voiceService.retryJoin();
                                        } else {
                                          await voiceService.toggleMute();
                                        }
                                      }
                                    : null,
                                icon: Icon(
                                  muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                                  color: canToggleMic
                                      ? (muted
                                          ? LupusColors.voiceMuted
                                          : LupusColors.voiceActive)
                                      : LupusColors.textMuted,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Bouton Couper le son des autres (Deafen)
                              IconButton.filled(
                                style: IconButton.styleFrom(
                                  backgroundColor: deafened
                                      ? LupusColors.bloodRed.withValues(alpha: 0.2)
                                      : LupusColors.surfaceLight,
                                  side: BorderSide(
                                    color: deafened
                                        ? LupusColors.bloodRed
                                        : LupusColors.border,
                                    width: 1.0,
                                  ),
                                ),
                                onPressed: () => voiceService.toggleDeafen(),
                                icon: Icon(
                                  deafened
                                      ? Icons.headset_off_rounded
                                      : Icons.headset_rounded,
                                  color: deafened
                                      ? LupusColors.bloodRed
                                      : LupusColors.textSecondary,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
