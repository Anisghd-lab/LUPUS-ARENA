import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../GameNotifier.dart';
import '../../models/game_role.dart';
import '../bento/bento_card.dart';
import '../theme/lupus_theme.dart';

/// Dialogue / Feuille de Configuration Avancée du Mode Sandbox & Bots
/// Permet à l'Hôte / Maître du Jeu de configurer précisément les bots, leurs rôles et de lancer la partie.
class SandboxBotConfigDialog extends ConsumerStatefulWidget {
  const SandboxBotConfigDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const SandboxBotConfigDialog(),
    );
  }

  @override
  ConsumerState<SandboxBotConfigDialog> createState() => _SandboxBotConfigDialogState();
}

class _SandboxBotConfigDialogState extends ConsumerState<SandboxBotConfigDialog> {
  int _botCount = 7; // Nombre de bots (par défaut 7 bots + 1 hôte = 8 joueurs)
  GameRole _hostRole = GameRole.seer; // Rôle de l'hôte
  final Map<int, GameRole> _botRoles = {}; // Rôles assignés aux bots (index 1 à _botCount)

  // Cartes additionnelles pour le Voleur
  GameRole _thiefCard1 = GameRole.simpleVillager;
  GameRole _thiefCard2 = GameRole.simpleWerewolf;

  // Liste des rôles configurables dans le sélecteur
  static const List<GameRole> _availableRoles = [
    GameRole.seer,
    GameRole.witch,
    GameRole.defender,
    GameRole.hunter,
    GameRole.cupid,
    GameRole.thief,
    GameRole.simpleWerewolf,
    GameRole.vileFatherOfWolves,
    GameRole.blackWolf,
    GameRole.whiteWerewolf,
    GameRole.piedPiper,
    GameRole.pyromaniac,
    GameRole.simpleVillager,
    GameRole.elder,
    GameRole.idiot,
    GameRole.fox,
    GameRole.bearTamer,
    GameRole.littleGirl,
  ];

  @override
  void initState() {
    super.initState();
    _applyPresetSpecialNights();
  }

  void _applyPresetSpecialNights() {
    setState(() {
      _botCount = 9;
      _hostRole = GameRole.seer;
      _botRoles[1] = GameRole.thief;
      _botRoles[2] = GameRole.cupid;
      _botRoles[3] = GameRole.defender;
      _botRoles[4] = GameRole.vileFatherOfWolves;
      _botRoles[5] = GameRole.blackWolf;
      _botRoles[6] = GameRole.witch;
      _botRoles[7] = GameRole.piedPiper;
      _botRoles[8] = GameRole.pyromaniac;
      _botRoles[9] = GameRole.simpleVillager;
      _thiefCard1 = GameRole.simpleVillager;
      _thiefCard2 = GameRole.simpleWerewolf;
    });
  }

  void _applyPresetPackVsVillage() {
    setState(() {
      _botCount = 7;
      _hostRole = GameRole.seer;
      _botRoles[1] = GameRole.simpleWerewolf;
      _botRoles[2] = GameRole.vileFatherOfWolves;
      _botRoles[3] = GameRole.witch;
      _botRoles[4] = GameRole.defender;
      _botRoles[5] = GameRole.hunter;
      _botRoles[6] = GameRole.cupid;
      _botRoles[7] = GameRole.simpleVillager;
    });
  }

  void _applyPresetSoloChaos() {
    setState(() {
      _botCount = 6;
      _hostRole = GameRole.piedPiper;
      _botRoles[1] = GameRole.pyromaniac;
      _botRoles[2] = GameRole.whiteWerewolf;
      _botRoles[3] = GameRole.vileFatherOfWolves;
      _botRoles[4] = GameRole.witch;
      _botRoles[5] = GameRole.seer;
      _botRoles[6] = GameRole.defender;
    });
  }

  void _applyPresetExpressTest() {
    setState(() {
      _botCount = 4;
      _hostRole = GameRole.seer;
      _botRoles[1] = GameRole.simpleWerewolf;
      _botRoles[2] = GameRole.vileFatherOfWolves;
      _botRoles[3] = GameRole.witch;
      _botRoles[4] = GameRole.defender;
    });
  }

  String _getRoleEmoji(GameRole role) {
    switch (role) {
      case GameRole.simpleWerewolf: return '🐺';
      case GameRole.whiteWerewolf: return '⚪🐺';
      case GameRole.blackWolf: return '🔇🐺';
      case GameRole.vileFatherOfWolves: return '🩸🐺';
      case GameRole.seer: return '🔮';
      case GameRole.witch: return '🧙‍♀️';
      case GameRole.hunter: return '🏹';
      case GameRole.cupid: return '💘';
      case GameRole.thief: return '🃏';
      case GameRole.defender: return '🛡️';
      case GameRole.piedPiper: return '🎵';
      case GameRole.pyromaniac: return '🔥';
      case GameRole.simpleVillager: return '👨‍🌾';
      case GameRole.elder: return '👴';
      case GameRole.idiot: return '🤪';
      case GameRole.littleGirl: return '👧';
      case GameRole.fox: return '🦊';
      case GameRole.bearTamer: return '🐻';
      default: return '🎭';
    }
  }

  bool get _hasThiefInGame {
    if (_hostRole == GameRole.thief) return true;
    for (int i = 1; i <= _botCount; i++) {
      if ((_botRoles[i] ?? GameRole.simpleVillager) == GameRole.thief) {
        return true;
      }
    }
    return false;
  }

  Map<String, GameRole> _buildRoleAssignments(String currentUserId) {
    final Map<String, GameRole> assignments = {
      currentUserId: _hostRole,
    };
    for (int i = 1; i <= _botCount; i++) {
      assignments['bot_$i'] = _botRoles[i] ?? GameRole.simpleVillager;
    }
    return assignments;
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameNotifierProvider);
    final room = gameState.room;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.90,
      decoration: BoxDecoration(
        color: const Color(0xF80A0F1E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: LupusColors.arcaneGold.withValues(alpha: 0.7),
          width: 1.5,
        ),
        boxShadow: LupusTheme.glowGold(opacity: 0.4),
      ),
      child: Column(
        children: [
          // Poignée dorée
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 6),
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: LupusColors.arcaneGold.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // En-tête
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF422006),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: LupusColors.arcaneGold, width: 1.2),
                          boxShadow: LupusTheme.glowGold(opacity: 0.3),
                        ),
                        child: const Text('🤖', style: TextStyle(fontSize: 18)),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CONFIGURATION SANDBOX & BOTS',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'serif',
                                fontWeight: FontWeight.w900,
                                fontSize: 13.5,
                                letterSpacing: 1.0,
                                color: LupusColors.arcaneGold,
                              ),
                            ),
                            Text(
                              'Assignation Manuelle des Rôles Spéciaux & IA',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                color: LupusColors.textSecondary,
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- 1. PRESETS RAPIDES ---
                  _buildPresetsSection(),
                  const SizedBox(height: 14),

                  // --- 2. RÉGLAGE DU NOMBRE DE BOTS ---
                  _buildBotCountSlider(),
                  const SizedBox(height: 14),

                  // --- 3. RÔLE DE L'ADMIN / HÔTE ---
                  _buildHostRoleCard(gameState.currentUserName),
                  const SizedBox(height: 14),

                  // --- 4. CARTES DU VOLEUR (si présent) ---
                  if (_hasThiefInGame) ...[
                    _buildThiefCardsSection(),
                    const SizedBox(height: 14),
                  ],

                  // --- 5. ASSIGNATION DES RÔLES PAR BOT ---
                  _buildBotAssignmentsSection(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // Barre d'actions en bas
          _buildBottomActionButtons(context, gameState, room),
        ],
      ),
    );
  }

  Widget _buildPresetsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PRESETS RECOMMANDÉS',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: LupusColors.arcaneGold,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _buildPresetChip(
                label: '✨ Nuits Spéciales (10j)',
                desc: 'Voleur, Cupidon, Infect, Flûte...',
                color: LupusColors.arcaneGold,
                onTap: _applyPresetSpecialNights,
              ),
              const SizedBox(width: 8),
              _buildPresetChip(
                label: '🐺 Meute vs Village (8j)',
                desc: 'Infect, Simple Loup, Sorcière...',
                color: LupusColors.bloodRed,
                onTap: _applyPresetPackVsVillage,
              ),
              const SizedBox(width: 8),
              _buildPresetChip(
                label: '⚔️ Chaos Solitaires (7j)',
                desc: 'Flûte, Pyromane, Loup Blanc...',
                color: LupusColors.arcanePurple,
                onTap: _applyPresetSoloChaos,
              ),
              const SizedBox(width: 8),
              _buildPresetChip(
                label: '⚡ Test Express (5j)',
                desc: 'Voyante, Sorcière, Loup...',
                color: LupusColors.poisonGreen,
                onTap: _applyPresetExpressTest,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPresetChip({
    required String label,
    required String desc,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            Text(
              desc,
              style: TextStyle(
                fontSize: 9.5,
                color: LupusColors.textSecondary.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBotCountSlider() {
    final totalPlayers = _botCount + 1;
    return BentoCard(
      borderColor: LupusColors.arcaneGold.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'NOMBRE TOTAL DE JOUEURS DANS L\'ARÈNE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: LupusColors.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: LupusColors.arcaneGold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: LupusColors.arcaneGold),
                ),
                child: Text(
                  '$totalPlayers Joueurs (1 Hôte + $_botCount Bots)',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    color: LupusColors.arcaneGold,
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: LupusColors.arcaneGold,
              thumbColor: LupusColors.arcaneGold,
              inactiveTrackColor: Colors.white12,
              valueIndicatorColor: LupusColors.arcaneGold,
            ),
            child: Slider(
              value: _botCount.toDouble(),
              min: 3,
              max: 14,
              divisions: 11,
              label: '$_botCount Bots ($totalPlayers joueurs)',
              onChanged: (val) {
                setState(() {
                  _botCount = val.round();
                  // Remplir les rôles par défaut si non définis
                  for (int i = 1; i <= _botCount; i++) {
                    _botRoles[i] ??= GameRole.simpleVillager;
                  }
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHostRoleCard(String hostName) {
    return BentoCard(
      borderColor: LupusColors.arcaneGold,
      gradient: const LinearGradient(
        colors: [Color(0x33B45309), Color(0x221E1405)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: LupusColors.arcaneGold.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(color: LupusColors.arcaneGold, width: 1.5),
            ),
            child: const Text('👑', style: TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VOTRE RÔLE ($hostName)',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: LupusColors.arcaneGold,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                _buildRoleDropdown(
                  value: _hostRole,
                  onChanged: (newRole) {
                    if (newRole != null) {
                      setState(() => _hostRole = newRole);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThiefCardsSection() {
    return BentoCard(
      borderColor: const Color(0xFF6366F1),
      gradient: const LinearGradient(
        colors: [Color(0x224338CA), Color(0x111E1B4B)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('🃏', style: TextStyle(fontSize: 16)),
              SizedBox(width: 6),
              Text(
                'CARTES SUPPLÉMENTAIRES DU VOLEUR (CENTRE DE LA TABLE)',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFA5B4FC),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Deux rôles secrets déposés au centre par le Maître du Jeu que le Voleur découvrira la première nuit.',
            style: TextStyle(fontSize: 10.5, color: LupusColors.textSecondary),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Carte 1 :', style: TextStyle(fontSize: 10, color: Colors.white70)),
                    const SizedBox(height: 4),
                    _buildRoleDropdown(
                      value: _thiefCard1,
                      onChanged: (r) {
                        if (r != null) setState(() => _thiefCard1 = r);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Carte 2 :', style: TextStyle(fontSize: 10, color: Colors.white70)),
                    const SizedBox(height: 4),
                    _buildRoleDropdown(
                      value: _thiefCard2,
                      onChanged: (r) {
                        if (r != null) setState(() => _thiefCard2 = r);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBotAssignmentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'RÔLES DES BOTS SIMULÉS',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: LupusColors.arcaneGold,
              ),
            ),
            Text(
              '$_botCount Bots à configurer',
              style: const TextStyle(fontSize: 10, color: LupusColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 8),

        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _botCount,
          itemBuilder: (context, index) {
            final botIndex = index + 1;
            final currentRole = _botRoles[botIndex] ?? GameRole.simpleVillager;
            final isWolf = currentRole.isEvil;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xCC12172A),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isWolf
                      ? LupusColors.bloodRed.withValues(alpha: 0.5)
                      : (currentRole == GameRole.thief || currentRole == GameRole.piedPiper
                          ? LupusColors.arcanePurple.withValues(alpha: 0.5)
                          : Colors.white.withValues(alpha: 0.1)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isWolf
                          ? LupusColors.bloodRed.withValues(alpha: 0.2)
                          : LupusColors.arcaneGold.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '#$botIndex',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: isWolf ? LupusColors.bloodRed : LupusColors.arcaneGold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Bot $botIndex',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 190,
                    child: _buildRoleDropdown(
                      value: currentRole,
                      onChanged: (newRole) {
                        if (newRole != null) {
                          setState(() => _botRoles[botIndex] = newRole);
                        }
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRoleDropdown({
    required GameRole value,
    required ValueChanged<GameRole?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: value.isEvil
              ? LupusColors.bloodRed.withValues(alpha: 0.7)
              : LupusColors.arcaneGold.withValues(alpha: 0.5),
          width: 1.1,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<GameRole>(
          value: value,
          isExpanded: true,
          dropdownColor: const Color(0xFF0A0F1E),
          icon: const Icon(Icons.arrow_drop_down_rounded, color: LupusColors.arcaneGold),
          style: const TextStyle(fontSize: 11.5, color: Colors.white),
          onChanged: onChanged,
          items: _availableRoles.map((role) {
            return DropdownMenuItem<GameRole>(
              value: role,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_getRoleEmoji(role), style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      role.displayNameFr,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: role.isEvil ? FontWeight.w800 : FontWeight.w600,
                        color: role.isEvil
                            ? const Color(0xFFFF6B6B)
                            : (role.defaultTeam == Team.solo
                                ? const Color(0xFFC084FC)
                                : Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildBottomActionButtons(
    BuildContext context,
    LupusGameState gameState,
    dynamic room,
  ) {
    final bool isInLobby = room != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F1E),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Bouton Principal : Lancer la partie Sandbox
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: LupusColors.arcaneGold,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 4,
            ),
            onPressed: () async {
              Navigator.pop(context);
              final roleAssignments = _buildRoleAssignments(gameState.currentUserId);
              final thiefExtraCards = _hasThiefInGame ? [_thiefCard1, _thiefCard2] : null;

              await ref.read(gameNotifierProvider.notifier).startSandboxGame(
                    roleAssignments: roleAssignments,
                    hostRole: _hostRole,
                    thiefExtraCards: thiefExtraCards,
                  );
            },
            icon: const Icon(Icons.play_circle_filled_rounded, size: 20),
            label: const Text(
              'LANCER LA PARTIE SANDBOX DIRECTE',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12.5,
                letterSpacing: 0.8,
              ),
            ),
          ),

          if (isInLobby) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: LupusColors.arcaneCyan,
                      side: const BorderSide(color: LupusColors.arcaneCyan),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      Navigator.pop(context);
                      final roleAssignments = _buildRoleAssignments(gameState.currentUserId);
                      await ref.read(gameNotifierProvider.notifier).populateRoomWithBots(
                            totalCount: _botCount + 1,
                            customRoleAssignments: roleAssignments,
                          );
                    },
                    icon: const Icon(Icons.group_add_rounded, size: 16),
                    label: const Text(
                      'INJECTER DANS LE SALON',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: LupusColors.bloodRed,
                      side: const BorderSide(color: LupusColors.bloodRed),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      Navigator.pop(context);
                      await ref.read(gameNotifierProvider.notifier).removeBotsFromRoom();
                    },
                    icon: const Icon(Icons.person_remove_rounded, size: 16),
                    label: const Text(
                      'VIDER LES BOTS',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
