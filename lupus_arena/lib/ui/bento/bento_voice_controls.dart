import 'package:flutter/material.dart';

import '../../AgoraVoiceService.dart';
import '../../models/game_phase.dart';
import '../theme/lupus_theme.dart';
import 'bento_card.dart';

/// Barre de contrôle vocal Bento pour Agora RTC
class BentoVoiceControls extends StatelessWidget {
  final AgoraVoiceService voiceService = AgoraVoiceService();
  final bool isAlive;
  final bool isCurrentSpeaker;
  final String? currentSpeakerName;
  final GamePhase? phase;

  BentoVoiceControls({
    super.key,
    this.isAlive = true,
    this.isCurrentSpeaker = false,
    this.currentSpeakerName,
    this.phase,
  });

  @override
  Widget build(BuildContext context) {
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

                        if (!isAlive) {
                          statusColor = LupusColors.bloodRed;
                          borderColor = LupusColors.border;
                          statusText = 'SILENCE DES OMBRES';
                          subtitleText = 'Vous êtes éliminé(e) • Micro verrouillé';
                        } else if (lastError != null && !connected) {
                          statusColor = LupusColors.bloodRed;
                          borderColor = LupusColors.bloodRed.withValues(alpha: 0.6);
                          statusText = 'ERREUR AUDIO AGORA';
                          subtitleText = '$lastError • Touchez pour réessayer';
                        } else if (isWolfChannel) {
                          statusColor = muted
                              ? const Color(0xFFFF2A4B)
                              : const Color(0xFF00FF88);
                          borderColor = const Color(0xFFFF2A4B);
                          statusText = connected
                              ? (muted
                                  ? 'CANAL MEUTE (MICRO COUPÉ)'
                                  : 'CANAL PRIVÉ DE LA MEUTE')
                              : 'CONNEXION MEUTE...';
                          subtitleText =
                              'Salon secret des loups • Insonorisé pour le village';
                        } else if (isDebateOrDefense) {
                          if (isCurrentSpeaker) {
                            statusColor = muted
                                ? LupusColors.sunAmber
                                : LupusColors.voiceActive;
                            borderColor = muted
                                ? LupusColors.sunAmber
                                : LupusColors.voiceActive;
                            statusText = muted
                                ? 'VOUS AVEZ LA PAROLE (MICRO COUPÉ)'
                                : 'VOUS AVEZ LA PAROLE (EN DIRECT)';
                            subtitleText = muted
                                ? 'Appuyez sur le micro pour parler au village'
                                : 'Micro ouvert • Tout le village vous écoute';
                          } else {
                            statusColor = LupusColors.textMuted;
                            borderColor = LupusColors.border;
                            final name = currentSpeakerName ?? 'L\'orateur';
                            statusText = 'DÉBAT : ${name.toUpperCase()} S\'EXPRIME';
                            subtitleText =
                                'Écoutez attentivement • Votre micro est temporisé';
                          }
                        } else {
                          // Phases normales (Lobby, Votes, etc.)
                          if (connected) {
                            statusColor = muted
                                ? LupusColors.sunAmber
                                : LupusColors.voiceActive;
                            borderColor = muted
                                ? LupusColors.border
                                : LupusColors.voiceActive.withValues(alpha: 0.4);
                            statusText = muted ? 'MICRO COUPÉ' : 'MICRO EN DIRECT';
                            subtitleText = 'Salon du village : ${channel ?? "Arène"}';
                          } else {
                            statusColor = LupusColors.sunAmber;
                            borderColor = LupusColors.border;
                            statusText = 'VOCAL EN ATTENTE';
                            subtitleText = 'Connexion automatique au salon...';
                          }
                        }

                        final bool canToggleMic =
                            isAlive && (!isDebateOrDefense || isCurrentSpeaker);

                        return BentoCard(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          borderColor: borderColor,
                          glowing: isCurrentSpeaker && !muted,
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
                                  tooltip: 'Réessayer la connexion audio',
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
