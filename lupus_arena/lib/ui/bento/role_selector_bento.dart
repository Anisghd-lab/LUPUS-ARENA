import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../GameNotifier.dart';
import '../../models/game_role.dart';
import '../../models/game_room.dart';
import '../theme/lupus_theme.dart';
import 'bento_card.dart';
import 'role_card_image.dart';

/// Panneau Bento Grid de Composition du Deck de Rôles (Deck Builder)
/// Permet à l'Hôte d'ajuster les quantités de chaque carte en temps réel sur Firebase.
/// Affiche pour tous les joueurs le compteur d'équilibre (Cartes / Joueurs connectés).
class RoleSelectorBento extends ConsumerStatefulWidget {
  final GameRoom room;
  final bool isHost;

  const RoleSelectorBento({
    super.key,
    required this.room,
    required this.isHost,
  });

  @override
  ConsumerState<RoleSelectorBento> createState() => _RoleSelectorBentoState();
}

class _RoleSelectorBentoState extends ConsumerState<RoleSelectorBento> {
  // Filtre de camp actif : 0 = Tous, 1 = Loups, 2 = Village, 3 = Solitaires
  int _activeFilter = 0;

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final isHost = widget.isHost;
    final totalRoles = room.totalRolesInPool;
    final playersCount = room.playerList.length;
    final isBalanced = totalRoles == playersCount;

    // Rôles filtrés
    final filteredRoles = _getFilteredRoles(_activeFilter);

    return BentoCard(
      borderColor: isBalanced
          ? LupusColors.poisonGreen.withValues(alpha: 0.6)
          : LupusColors.sunAmber.withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. En-tête : Titre + Badge Hôte / Invité
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1B4B),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: LupusColors.arcanePurple.withValues(alpha: 0.6),
                      ),
                    ),
                    child: const Icon(
                      Icons.style_rounded,
                      color: LupusColors.arcaneGold,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'COMPOSITION DU DECK',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                          color: LupusColors.textPrimary,
                        ),
                      ),
                      Text(
                        isHost
                            ? 'Ajustez les cartes pour la partie'
                            : 'Composition choisie par l\'Hôte',
                        style: const TextStyle(
                          fontSize: 10,
                          color: LupusColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isHost
                      ? LupusColors.arcaneGold.withValues(alpha: 0.15)
                      : LupusColors.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isHost
                        ? LupusColors.arcaneGold.withValues(alpha: 0.5)
                        : LupusColors.border,
                  ),
                ),
                child: Text(
                  isHost ? '👑 HÔTE' : '👁️ LECTURE',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: isHost ? LupusColors.arcaneGold : LupusColors.textMuted,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 2. Compteur Global d'Équilibre (Cartes choisies : X / Y joueurs connectés)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isBalanced
                  ? const Color(0x2210B981)
                  : (totalRoles < playersCount
                      ? const Color(0x22F59E0B)
                      : const Color(0x22EF4444)),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isBalanced
                    ? LupusColors.poisonGreen
                    : (totalRoles < playersCount
                        ? LupusColors.sunAmber
                        : LupusColors.bloodRed),
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isBalanced
                          ? Icons.check_circle_rounded
                          : (totalRoles < playersCount
                              ? Icons.hourglass_top_rounded
                              : Icons.warning_amber_rounded),
                      size: 18,
                      color: isBalanced
                          ? LupusColors.poisonGreen
                          : (totalRoles < playersCount
                              ? LupusColors.sunAmber
                              : LupusColors.bloodRed),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Cartes : $totalRoles / $playersCount joueurs',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        color: isBalanced
                            ? LupusColors.poisonGreen
                            : (totalRoles < playersCount
                                ? LupusColors.sunAmber
                                : LupusColors.bloodRed),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isBalanced
                        ? 'PRÊT POUR L\'ARÈNE'
                        : (totalRoles < playersCount
                            ? 'MANQUE ${playersCount - totalRoles}'
                            : 'SURPLUS +${totalRoles - playersCount}'),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isBalanced
                          ? LupusColors.poisonGreen
                          : (totalRoles < playersCount
                              ? LupusColors.sunAmber
                              : LupusColors.bloodRed),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 3. Filtres rapides de Camp (Tous, Loups, Village, Neutres)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(0, 'Tous (${GameRole.values.length})'),
                const SizedBox(width: 6),
                _buildFilterChip(1, '🐺 Loups'),
                const SizedBox(width: 6),
                _buildFilterChip(2, '👥 Village'),
                const SizedBox(width: 6),
                _buildFilterChip(3, '✨ Solitaires'),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // 4. Liste / Grille des Rôles
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 340),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              itemCount: filteredRoles.length,
              separatorBuilder: (_, _) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final role = filteredRoles[index];
                final qty = room.rolePool[role.id] ?? 0;
                final isMultiple = (role == GameRole.simpleWerewolf ||
                    role == GameRole.simpleVillager);

                return _buildRoleRow(
                  context: context,
                  role: role,
                  quantity: qty,
                  isHost: isHost,
                  isMultiple: isMultiple,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(int index, String label) {
    final isSelected = _activeFilter == index;
    return GestureDetector(
      onTap: () => setState(() => _activeFilter = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? LupusColors.moonIndigo.withValues(alpha: 0.3)
              : LupusColors.surfaceLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? LupusColors.moonIndigo : LupusColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? LupusColors.moonIndigo : LupusColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildRoleRow({
    required BuildContext context,
    required GameRole role,
    required int quantity,
    required bool isHost,
    required bool isMultiple,
  }) {
    final teamColor = role.isEvil
        ? LupusColors.bloodRed
        : (role.defaultTeam == Team.village
            ? const Color(0xFF38BDF8)
            : LupusColors.arcaneViolet);

    final teamLabel = role.isEvil
        ? 'Loup'
        : (role.defaultTeam == Team.village ? 'Village' : 'Solitaire');

    final isSelected = quantity > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected
            ? teamColor.withValues(alpha: 0.12)
            : LupusColors.surfaceLight.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? teamColor.withValues(alpha: 0.5) : LupusColors.border,
          width: isSelected ? 1.2 : 0.8,
        ),
      ),
      child: Row(
        children: [
          // Illustration miniature (zoomable au tap)
          RoleCardImage(
            role: role,
            width: 38,
            height: 48,
            borderRadius: BorderRadius.circular(6),
          ),
          const SizedBox(width: 10),

          // Nom et badge de camp
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        role.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? Colors.white : LupusColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: teamColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: teamColor.withValues(alpha: 0.4), width: 0.6),
                      ),
                      child: Text(
                        teamLabel,
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: teamColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isMultiple
                      ? 'Rôle multiple (quantité illimitée)'
                      : 'Rôle unique (1 max)',
                  style: TextStyle(
                    fontSize: 9.5,
                    color: LupusColors.textMuted.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),

          // Sélecteur numérique [-] [ Quantité ] [+]
          if (isHost) ...[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Bouton Décrémenter [-]
                _buildQuantityButton(
                  icon: Icons.remove_rounded,
                  enabled: quantity > 0,
                  onTap: () => ref
                      .read(gameNotifierProvider.notifier)
                      .updateRolePool(role.id, -1),
                ),

                // Quantité affichée
                Container(
                  constraints: const BoxConstraints(minWidth: 26),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '$quantity',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: quantity > 0 ? LupusColors.arcaneGold : LupusColors.textMuted,
                    ),
                  ),
                ),

                // Bouton Incrémenter [+]
                _buildQuantityButton(
                  icon: Icons.add_rounded,
                  enabled: isMultiple || quantity < 1,
                  onTap: () => ref
                      .read(gameNotifierProvider.notifier)
                      .updateRolePool(role.id, 1),
                ),
              ],
            ),
          ] else ...[
            // Mode Invité : Badge lecture seule
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: quantity > 0
                    ? teamColor.withValues(alpha: 0.25)
                    : LupusColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: quantity > 0 ? teamColor.withValues(alpha: 0.6) : LupusColors.border,
                ),
              ),
              child: Text(
                'x$quantity',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: quantity > 0 ? Colors.white : LupusColors.textMuted,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuantityButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: enabled
                ? LupusColors.surfaceElevated
                : LupusColors.surfaceLight.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: enabled ? LupusColors.border : Colors.white10,
            ),
          ),
          child: Icon(
            icon,
            size: 16,
            color: enabled ? LupusColors.textPrimary : LupusColors.textMuted.withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }

  List<GameRole> _getFilteredRoles(int filter) {
    switch (filter) {
      case 1: // Loups
        return GameRole.values.where((r) => r.isEvil).toList();
      case 2: // Village
        return GameRole.values
            .where((r) => !r.isEvil && r.defaultTeam == Team.village)
            .toList();
      case 3: // Solitaires / Neutres
        return GameRole.values
            .where((r) => !r.isEvil && r.defaultTeam != Team.village)
            .toList();
      default:
        return GameRole.values;
    }
  }
}
