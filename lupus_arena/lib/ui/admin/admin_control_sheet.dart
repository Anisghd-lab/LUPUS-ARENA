import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../GameNotifier.dart';
import '../../models/game_phase.dart';
import '../../models/game_room.dart';
import '../../models/player_model.dart';
import '../../services/lupus_permission_service.dart';
import '../bento/bento_card.dart';
import '../bento/lupus_permission_dialog.dart';
import '../bento/role_card_image.dart';
import '../theme/lupus_theme.dart';

/// Feuille de contrôle Maître du Jeu (God Mode / Debug Panel) stylisée Dark Medieval Modern
/// Permet de visualiser tous les secrets de la partie et de forcer les états en direct sur Firebase.
class AdminControlSheet extends ConsumerStatefulWidget {
  const AdminControlSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const AdminControlSheet(),
    );
  }

  @override
  ConsumerState<AdminControlSheet> createState() => _AdminControlSheetState();
}

class _AdminControlSheetState extends ConsumerState<AdminControlSheet> {
  int _selectedTab = 0; // 0: God View, 1: Phases, 2: Joueurs, 3: Audio

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameNotifierProvider);
    final room = gameState.room;

    if (room == null) {
      return _buildLobbyAdminHub(context, gameState);
    }

    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.88,
      decoration: BoxDecoration(
        color: const Color(0xF80A0F1E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: LupusColors.arcaneGold.withValues(alpha: 0.65),
          width: 1.5,
        ),
        boxShadow: LupusTheme.glowGold(opacity: 0.4),
      ),
      child: Column(
        children: [
          // Poignée et En-tête God Mode
          _buildHeader(context, room),

          // Barre d'onglets Bento
          _buildTabs(),
          const SizedBox(height: 8),

          // Contenu selon l'onglet sélectionné
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: _buildTabContent(room, gameState),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, GameRoom room) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          // Poignée de glissement dorée
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: LupusColors.arcaneGold.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF422006),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: LupusColors.arcaneGold,
                          width: 1.2,
                        ),
                        boxShadow: LupusTheme.glowGold(opacity: 0.3),
                      ),
                      child: const Text('👑', style: TextStyle(fontSize: 14)),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PANNEAU MAÎTRE DU JEU',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'serif',
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                              color: LupusColors.arcaneGold,
                            ),
                          ),
                          Text(
                            'God Mode • Mutations Directes Firebase',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: LupusColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: LupusColors.textSecondary),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    final tabs = [
      {'icon': '👁️', 'label': 'God View'},
      {'icon': '⏳', 'label': 'Phases'},
      {'icon': '👥', 'label': 'Joueurs'},
      {'icon': '🎙️', 'label': 'Audio'},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: const Color(0x9912172A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: List.generate(tabs.length, (index) {
            final isSelected = _selectedTab == index;
            final tab = tabs[index];
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedTab = index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? LupusColors.arcaneGold.withValues(alpha: 0.25)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(13),
                    border: isSelected
                        ? Border.all(color: LupusColors.arcaneGold)
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(tab['icon']!, style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Text(
                        tab['label']!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              isSelected ? FontWeight.w800 : FontWeight.w500,
                          color: isSelected
                              ? LupusColors.arcaneGold
                              : LupusColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildTabContent(GameRoom room, LupusGameState gameState) {
    switch (_selectedTab) {
      case 0:
        return _buildGodView(room);
      case 1:
        return _buildPhasesForcing(room);
      case 2:
        return _buildPlayerManagement(room);
      case 3:
        return _buildAudioControl(room, gameState);
      default:
        return const SizedBox.shrink();
    }
  }

  // ==========================================
  // --- 1. VISION TOTALE DES RÔLES (GOD VIEW) ---
  // ==========================================
  Widget _buildGodView(GameRoom room) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ROSTER SECRET DES JOUEURS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: LupusColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),

        ...room.playerList.map((player) {
          final targetPlayer = (player.targetVoteId != null &&
                  player.targetVoteId!.isNotEmpty)
              ? room.players[player.targetVoteId]
              : null;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xAA12172A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: player.isAlive
                    ? (player.role.isEvil
                        ? LupusColors.arcaneCrimson.withValues(alpha: 0.5)
                        : LupusColors.arcanePurple.withValues(alpha: 0.35))
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              children: [
                // Illustration officielle de la carte (LOUP GAROU ENHANCED)
                RoleCardImage(
                  role: player.role,
                  width: 44,
                  height: 58,
                  borderRadius: BorderRadius.circular(10),
                  showGlow: player.isAlive,
                ),
                const SizedBox(width: 12),

                // Informations du joueur
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            player.name,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: player.isAlive
                                  ? Colors.white
                                  : LupusColors.textMuted,
                              decoration: player.isAlive
                                  ? null
                                  : TextDecoration.lineThrough,
                            ),
                          ),
                          if (player.isCaptain) ...[
                            const SizedBox(width: 4),
                            const Text('⭐', style: TextStyle(fontSize: 12)),
                          ],
                          if (player.isLover) ...[
                            const SizedBox(width: 4),
                            const Text('💖', style: TextStyle(fontSize: 12)),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${player.role.displayName} • ${player.role.defaultTeam.name.toUpperCase()}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: player.role.accentColor,
                        ),
                      ),
                      if (targetPlayer != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          '🎯 Vise : ${targetPlayer.name}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                            color: LupusColors.arcaneGold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Statut de vie
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: player.isAlive
                        ? const Color(0x3306D6A0)
                        : const Color(0x33E63946),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: player.isAlive
                          ? LupusColors.poisonGreen
                          : LupusColors.arcaneCrimson,
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    player.isAlive ? 'VIVANT' : 'MORT',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      color: player.isAlive
                          ? LupusColors.poisonGreen
                          : LupusColors.arcaneCrimson,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ==========================================
  // --- 2. FORÇAGE DES PHASES DE JEU ---
  // ==========================================
  Widget _buildPhasesForcing(GameRoom room) {
    final notifier = ref.read(gameNotifierProvider.notifier);

    final keyPhases = [
      {
        'phase': GamePhase.nightCupid,
        'label': 'Tour de Cupidon',
        'icon': '💘',
        'color': const Color(0xFFFF70A6),
      },
      {
        'phase': GamePhase.nightPyromaniac,
        'label': 'Tour du Pyromane',
        'icon': '🔥',
        'color': const Color(0xFFFF4800),
      },
      {
        'phase': GamePhase.dayDebate,
        'label': 'Débat du Village',
        'icon': '🗣️',
        'color': LupusColors.daylightCyan,
      },
      {
        'phase': GamePhase.dayVoting,
        'label': 'Vote du Village',
        'icon': '🗳️',
        'color': LupusColors.arcaneGold,
      },
      {
        'phase': GamePhase.nightWerewolves,
        'label': 'Nuit des Loups',
        'icon': '🐺',
        'color': LupusColors.arcaneCrimson,
      },
      {
        'phase': GamePhase.nightSeer,
        'label': 'Tour de la Voyante',
        'icon': '🔮',
        'color': LupusColors.arcanePurple,
      },
      {
        'phase': GamePhase.nightDefender,
        'label': 'Tour du Salvateur',
        'icon': '🛡️',
        'color': const Color(0xFF38BDF8),
      },
      {
        'phase': GamePhase.nightWitch,
        'label': 'Tour de la Sorcière',
        'icon': '🧪',
        'color': LupusColors.poisonGreen,
      },
      {
        'phase': GamePhase.captainElection,
        'label': 'Élection Capitaine',
        'icon': '⭐',
        'color': LupusColors.arcaneGold,
      },
      {
        'phase': GamePhase.hunterDeathChoice,
        'label': 'Tir du Chasseur',
        'icon': '🏹',
        'color': const Color(0xFFF97316),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Phase actuelle
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xCC12172A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: LupusColors.arcaneGold),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PHASE ACTUELLE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: LupusColors.textMuted,
                    ),
                  ),
                  Text(
                    room.phase.displayName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: room.phase.isNight
                      ? const Color(0x99450A0A)
                      : const Color(0x99422006),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  room.phase.isNight ? 'NUIT' : 'JOUR',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Bouton spécial : Résolution Matinale
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEAB308),
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: () {
            notifier.adminForceMorningResolution();
            _showToast('Résolution matinale des morts déclenchée');
          },
          icon: const Text('🌅', style: TextStyle(fontSize: 16)),
          label: const Text(
            'FORCER LA RÉSOLUTION MATINALE',
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.8),
          ),
        ),
        const SizedBox(height: 14),

        const Text(
          'SAUTS DIRECTS DE PHASES',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: LupusColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),

        // Grille de phases rapides
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.2,
          ),
          itemCount: keyPhases.length,
          itemBuilder: (context, index) {
            final p = keyPhases[index];
            final phase = p['phase'] as GamePhase;
            final isCurrent = room.phase == phase;

            return InkWell(
              onTap: () {
                notifier.adminForcePhase(phase);
                _showToast('Phase forcée : ${phase.displayName}');
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? (p['color'] as Color).withValues(alpha: 0.3)
                      : const Color(0xAA12172A),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isCurrent
                        ? (p['color'] as Color)
                        : Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Row(
                  children: [
                    Text(p['icon'] as String,
                        style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        p['label'] as String,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isCurrent
                              ? (p['color'] as Color)
                              : Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ==========================================
  // --- 3. GESTION MANUELLE DES JOUEURS ---
  // ==========================================
  Widget _buildPlayerManagement(GameRoom room) {
    final notifier = ref.read(gameNotifierProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CONTRÔLE TOTAL DES JOUEURS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: LupusColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),

        ...room.playerList.map((player) {
          final isSpeaker = room.currentSpeakerId == player.id;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xAA12172A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSpeaker
                    ? LupusColors.voiceActive
                    : Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${player.name} (${player.role.displayName})',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: player.isAlive
                            ? Colors.white
                            : LupusColors.textMuted,
                      ),
                    ),
                    Row(
                      children: [
                        if (player.isCaptain)
                          const Text('⭐ ', style: TextStyle(fontSize: 12)),
                        Text(
                          player.isAlive ? 'Vivant' : 'Mort',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: player.isAlive
                                ? LupusColors.poisonGreen
                                : LupusColors.arcaneCrimson,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Barre d'actions rapides par joueur
                Row(
                  children: [
                    // Tuer / Ressusciter
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: player.isAlive
                              ? LupusColors.arcaneCrimson
                              : LupusColors.poisonGreen,
                          side: BorderSide(
                            color: player.isAlive
                                ? LupusColors.arcaneCrimson
                                : LupusColors.poisonGreen,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          notifier.adminTogglePlayerLife(player.id);
                          _showToast(
                              '${player.name} ${player.isAlive ? "éliminé(e)" : "ressuscité(e)"}');
                        },
                        child: Text(
                          player.isAlive ? '💀 Tuer' : '💚 Revivre',
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Donner la parole
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isSpeaker
                              ? LupusColors.arcaneGold
                              : LupusColors.daylightCyan,
                          side: BorderSide(
                            color: isSpeaker
                                ? LupusColors.arcaneGold
                                : LupusColors.daylightCyan,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          notifier.adminForceSpeaker(
                              isSpeaker ? null : player.id);
                          _showToast(isSpeaker
                              ? 'Parole retirée'
                              : 'Parole donnée à ${player.name}');
                        },
                        child: Text(
                          isSpeaker ? '🔇 Couper' : '🎙️ Parole',
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Nommer Capitaine
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: LupusColors.arcaneGold,
                          side: const BorderSide(color: LupusColors.arcaneGold),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          notifier.adminForceCaptain(player.id);
                          _showToast('${player.name} est Capitaine');
                        },
                        child: const Text(
                          '⭐ Capitaine',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Changer de rôle
                InkWell(
                  onTap: () => _showRoleSelector(player),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0x661E243D),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: LupusColors.arcanePurple
                              .withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('🎭', style: TextStyle(fontSize: 12)),
                        SizedBox(width: 6),
                        Text(
                          'Changer de Rôle Secret...',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: LupusColors.arcaneGlow,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ==========================================
  // --- 4. CONTRÔLE AUDIO AGORA ---
  // ==========================================
  Widget _buildAudioControl(GameRoom room, LupusGameState gameState) {
    final notifier = ref.read(gameNotifierProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ESPIONNAGE & CONTRÔLE AUDIO AGORA',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: LupusColors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),

        // Carte Écoute Omnisciente Meute
        BentoCard(
          borderColor: gameState.isOmniscientVoice
              ? LupusColors.arcaneCrimson
              : LupusColors.border,
          glowing: gameState.isOmniscientVoice,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Text('🐺', style: TextStyle(fontSize: 20)),
                      SizedBox(width: 8),
                      Text(
                        'Écoute Omnisciente de Nuit',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  Switch(
                    value: gameState.isOmniscientVoice,
                    activeThumbColor: LupusColors.arcaneCrimson,
                    onChanged: (val) {
                      notifier.adminToggleOmniscientVoice();
                      _showToast(val
                          ? 'Mode espion loup activé'
                          : 'Mode espion désactivé');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Permet au Maître du Jeu de rejoindre le canal vocal secret des Loups-Garous la nuit sans être loup pour surveiller les échanges.',
                style: TextStyle(
                  fontSize: 11,
                  color: LupusColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Couper la parole générale
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF991B1B),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: () {
            notifier.adminForceSpeaker(null);
            _showToast('Silence imposé à tous les orateurs');
          },
          icon: const Icon(Icons.mic_off_rounded, size: 18),
          label: const Text(
            'IMPOSER LE SILENCE GÉNÉRAL',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.8),
          ),
        ),
        const SizedBox(height: 10),

        // Re-tester le dialogue de permissions du premier lancement
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: LupusColors.arcanePurple,
            side: const BorderSide(color: LupusColors.arcanePurple),
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: () async {
            await LupusPermissionService().resetPermissionsChoice();
            if (mounted) {
              LupusPermissionDialog.showForce(context);
            }
          },
          icon: const Icon(Icons.security_update_good, size: 18),
          label: const Text(
            'RE-TESTER LE DIALOGUE PERMISSIONS DU 1ER LANCEMENT',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.8),
          ),
        ),
      ],
    );
  }

  void _showRoleSelector(PlayerModel player) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.75,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xF80A0F1E),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: LupusColors.arcaneGold),
        ),
        child: Column(
          children: [
            Text(
              'ATTRIBUER UN RÔLE À ${player.name.toUpperCase()}',
              style: const TextStyle(
                fontFamily: 'serif',
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: LupusColors.arcaneGold,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: GameRole.values.length,
                itemBuilder: (context, index) {
                  final role = GameRole.values[index];
                  final isCurrent = player.role == role;

                  return ListTile(
                    leading: RoleCardImage(
                      role: role,
                      width: 36,
                      height: 50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    title: Text(
                      role.displayName,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: isCurrent ? LupusColors.arcaneGold : Colors.white,
                      ),
                    ),
                    subtitle: Text(
                      role.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10, color: LupusColors.textMuted),
                    ),
                    onTap: () {
                      ref
                          .read(gameNotifierProvider.notifier)
                          .adminForceRole(player.id, role);
                      Navigator.of(ctx).pop();
                      _showToast('Rôle changé pour ${player.name} : ${role.displayName}');
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLobbyAdminHub(BuildContext context, LupusGameState gameState) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.78,
      decoration: BoxDecoration(
        color: const Color(0xF80A0F1E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: LupusColors.arcaneGold.withValues(alpha: 0.75),
          width: 1.5,
        ),
        boxShadow: LupusTheme.glowGold(opacity: 0.4),
      ),
      child: Column(
        children: [
          // Poignée dorée
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: LupusColors.arcaneGold.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // En-tête God Mode
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF422006),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: LupusColors.arcaneGold, width: 1.2),
                          boxShadow: LupusTheme.glowGold(opacity: 0.3),
                        ),
                        child: const Text('👑', style: TextStyle(fontSize: 18)),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PANNEAU MAÎTRE DU JEU',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'serif',
                                fontWeight: FontWeight.w900,
                                fontSize: 14.5,
                                letterSpacing: 1.1,
                                color: LupusColors.arcaneGold,
                              ),
                            ),
                            Text(
                              'CODE SECRET 03031994 ACTIF',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.9,
                                color: Color(0xCCFFD700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: LupusColors.textSecondary),
                ),
              ],
            ),
          ),

          const Divider(color: Color(0x33B45309), height: 1),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Carte 1 : SIMULATION TEST 15 JOUEURS
                  BentoCard(
                    borderColor: LupusColors.arcaneGold,
                    gradient: const LinearGradient(
                      colors: [
                        Color(0x33B45309),
                        Color(0x221E1405),
                        Color(0x330F0B02),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: LupusColors.arcaneGold.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.play_circle_filled_rounded,
                                  color: LupusColors.arcaneGold, size: 28),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'LANCER UNE PARTIE DE TEST (15 JOUEURS)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                      color: LupusColors.arcaneGold,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Test instantané du God Mode sans attendre d\'autres joueurs',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: LupusColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Génère 14 guerriers simulés avec rôles attribués (Loups, Voyante, Sorcière, Chasseur, Cupidon, etc.), lance la Nuit 1 et ouvre immédiatement l\'Arène avec le God Mode complet.',
                          style: TextStyle(
                            fontSize: 12,
                            color: LupusColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: LupusColors.arcaneGold,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () async {
                              Navigator.pop(context);
                              await ref
                                  .read(gameNotifierProvider.notifier)
                                  .createTestRoom();
                            },
                            icon: const Icon(Icons.flash_on_rounded, size: 20),
                            label: const Text(
                              'LANCER LA SIMULATION MAINTENANT',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Carte 2 : Créer un salon multijoueur réel
                  BentoCard(
                    borderColor: LupusColors.moonIndigo.withValues(alpha: 0.5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: LupusColors.moonIndigo.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.group_add_rounded,
                                  color: LupusColors.moonIndigo, size: 28),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'CRÉER UN SALON MULTIJOUEUR',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      color: LupusColors.textPrimary,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Pour faire jouer de vrais joueurs avec vous',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: LupusColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: LupusColors.moonIndigo,
                              side: const BorderSide(color: LupusColors.moonIndigo),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () async {
                              Navigator.pop(context);
                              await ref
                                  .read(gameNotifierProvider.notifier)
                                  .createRoom();
                            },
                            child: const Text(
                              'CRÉER UN NOUVEAU SALON',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1E1B4B),
        content: Text(
          message,
          style: const TextStyle(
            color: LupusColors.arcaneGold,
            fontWeight: FontWeight.w700,
          ),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
