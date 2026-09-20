import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../GameNotifier.dart';
import '../../models/game_phase.dart';
import '../../models/game_room.dart';
import '../../models/player_model.dart';
import '../../services/app_translations.dart';
import '../../services/lupus_permission_service.dart';
import '../bento/bento_card.dart';
import '../bento/lupus_permission_dialog.dart';
import '../bento/role_card_image.dart';
import '../theme/lupus_theme.dart';

/// Feuille de contrôle Maître du Jeu (DEV-MOD / Debug Panel) stylisée Dark Medieval Modern
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
  int _selectedTab = 0; // 0: Dev View, 1: Sandbox, 2: Phases, 3: Joueurs, 4: Audio

  // Variables de sélection pour les actions rapides Sandbox
  String? _selectedWolfVictimId;
  String? _selectedSeerTargetId;
  String? _selectedPoisonTargetId;
  String? _selectedGuardTargetId;
  String? _selectedCupid1Id;
  String? _selectedCupid2Id;
  String? _selectedHunterTargetId;
  GameRole? _inspectedSeerResult;

  // Variables pour le configurateur Dev-Mode Sandbox
  int? _lobbyPlayerCount;
  Map<GameRole, int>? _lobbyRoleCounts;

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
          // Poignée et En-tête DEV-MOD
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
                            '👑 DEV-MOD • MAÎTRE DU JEU',
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
                            'DEV-MOD • Mutations Directes Firebase',
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
      {'icon': '👁️', 'label': 'Dev View'},
      {'icon': '🎮', 'label': 'Sandbox'},
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
                          fontSize: 10.5,
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
        return _buildDevView(room, gameState);
      case 1:
        return _buildSandboxTab(room);
      case 2:
        return _buildPhasesForcing(room);
      case 3:
        return _buildPlayerManagement(room);
      case 4:
        return _buildAudioControl(room, gameState);
      default:
        return const SizedBox.shrink();
    }
  }

  // ==========================================
  // --- 2. SIMULATION SANDBOX & POUVOIRS FORCÉS ---
  // ==========================================
  Widget _buildSandboxTab(GameRoom room) {
    final notifier = ref.read(gameNotifierProvider.notifier);
    final alivePlayers = room.alivePlayers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Bouton Maître : Lever du jour immédiat
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF78350F), Color(0xFF451A03), Color(0xFF1E1405)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: LupusColors.arcaneGold, width: 1.5),
            boxShadow: LupusTheme.glowGold(opacity: 0.35),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(Icons.wb_sunny_rounded, color: LupusColors.arcaneGold, size: 24),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RÉSOLUTION INSTANTANÉE DU CYCLE',
                          style: TextStyle(
                            fontFamily: 'serif',
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: LupusColors.arcaneGold,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Text(
                          'Calcule les morts, protections et amours sans aucun timer réseau',
                          style: TextStyle(fontSize: 10.5, color: LupusColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: LupusColors.arcaneGold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 4,
                ),
                onPressed: () async {
                  await notifier.devResolveNight();
                  _showToast('🌅 Aube résolue instantanément !');
                },
                icon: const Icon(Icons.flash_on_rounded, size: 20),
                label: const Text(
                  '🌅 RÉSOUDRE L\'AUBE / LEVER DU JOUR',
                  style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.9, fontSize: 12.5),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 2. Actions forcées des rôles de Nuit
        const Text(
          'DÉCLENCHEURS DIRECTS DES POUVOIRS (DEV-MODE)',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: LupusColors.arcaneGold,
          ),
        ),
        const SizedBox(height: 8),

        // Carte : Meute des Loups-Garous
        BentoCard(
          borderColor: LupusColors.bloodRed.withValues(alpha: 0.6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('🐺', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  const Text(
                    'PROIE DE LA MEUTE DES LOUPS',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      color: LupusColors.bloodRed,
                    ),
                  ),
                  const Spacer(),
                  if (room.nightVictimId != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: LupusColors.bloodRed.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Cible: ${room.players[room.nightVictimId]?.name ?? room.nightVictimId}',
                        style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _selectedWolfVictimId ?? (alivePlayers.isNotEmpty ? alivePlayers.first.id : null),
                dropdownColor: const Color(0xFF1E1405),
                decoration: InputDecoration(
                  labelText: context.tr('admin_choose_wolf_victim'),
                  labelStyle: const TextStyle(color: LupusColors.textSecondary, fontSize: 12),
                  filled: true,
                  fillColor: const Color(0x66000000),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: alivePlayers.map((p) => DropdownMenuItem(
                  value: p.id,
                  child: Text('${p.name} (${p.role.getDisplayName(context)})', style: const TextStyle(color: Colors.white, fontSize: 12)),
                )).toList(),
                onChanged: (val) => setState(() => _selectedWolfVictimId = val),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LupusColors.bloodRed,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    final target = _selectedWolfVictimId ?? (alivePlayers.isNotEmpty ? alivePlayers.first.id : null);
                    if (target != null) {
                      notifier.devSetNightVictim(target);
                      _showToast('🐺 Proie des loups fixée sur ${room.players[target]?.name}');
                    }
                  },
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: Text(context.tr('admin_force_wolf_victim'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Carte : Voyante (Sonde Immédiate)
        BentoCard(
          borderColor: LupusColors.arcanePurple.withValues(alpha: 0.6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('🔮', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  const Text(
                    'SONDE DE LA VOYANTE',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      color: LupusColors.arcanePurple,
                    ),
                  ),
                  const Spacer(),
                  if (_inspectedSeerResult != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: LupusColors.arcanePurple.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Rôle: ${_inspectedSeerResult!.displayNameFr}',
                        style: const TextStyle(fontSize: 10, color: LupusColors.arcaneGold, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _selectedSeerTargetId ?? (alivePlayers.isNotEmpty ? alivePlayers.first.id : null),
                dropdownColor: const Color(0xFF1E1405),
                decoration: InputDecoration(
                  labelText: context.tr('admin_choose_seer_target'),
                  labelStyle: const TextStyle(color: LupusColors.textSecondary, fontSize: 12),
                  filled: true,
                  fillColor: const Color(0x66000000),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: alivePlayers.map((p) => DropdownMenuItem(
                  value: p.id,
                  child: Text('${p.name} (${context.tr('seat_number', {'index': p.seatIndex >= 0 ? p.seatIndex : 0})})', style: const TextStyle(color: Colors.white, fontSize: 12)),
                )).toList(),
                onChanged: (val) => setState(() => _selectedSeerTargetId = val),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    final target = _selectedSeerTargetId ?? (alivePlayers.isNotEmpty ? alivePlayers.first.id : null);
                    if (target != null) {
                      final role = await notifier.devSeerInspect(target);
                      setState(() => _inspectedSeerResult = role);
                      _showToast('🔮 ${room.players[target]?.name} est [${role?.getDisplayName(context) ?? "Inconnu"}] !');
                    }
                  },
                  icon: const Icon(Icons.visibility_rounded, size: 16),
                  label: Text(context.tr('admin_probe_role_instantly'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Carte : Sorcière (Potions)
        BentoCard(
          borderColor: LupusColors.poisonGreen.withValues(alpha: 0.6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('🧪', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  const Text(
                    'POTIONS DE LA SORCIÈRE',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      color: LupusColors.poisonGreen,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF047857),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        notifier.devWitchHeal();
                        _showToast('✨ Potion de soin appliquée sur la victime des loups !');
                      },
                      icon: const Icon(Icons.healing_rounded, size: 16),
                      label: Text(context.tr('admin_heal_prey'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedPoisonTargetId ?? (alivePlayers.isNotEmpty ? alivePlayers.first.id : null),
                dropdownColor: const Color(0xFF1E1405),
                decoration: InputDecoration(
                  labelText: context.tr('admin_choose_poison_target'),
                  labelStyle: const TextStyle(color: LupusColors.textSecondary, fontSize: 12),
                  filled: true,
                  fillColor: const Color(0x66000000),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: alivePlayers.map((p) => DropdownMenuItem(
                  value: p.id,
                  child: Text('${p.name} (${p.role.getDisplayName(context)})', style: const TextStyle(color: Colors.white, fontSize: 12)),
                )).toList(),
                onChanged: (val) => setState(() => _selectedPoisonTargetId = val),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB91C1C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    final target = _selectedPoisonTargetId ?? (alivePlayers.isNotEmpty ? alivePlayers.first.id : null);
                    if (target != null) {
                      notifier.devWitchPoison(target);
                      _showToast('☠️ Potion de poison versée sur ${room.players[target]?.name} !');
                    }
                  },
                  icon: const Icon(Icons.science_rounded, size: 16),
                  label: Text(context.tr('admin_poison_player'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Carte : Salvateur / Garde (Bouclier)
        BentoCard(
          borderColor: LupusColors.sunAmber.withValues(alpha: 0.6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('🛡️', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  const Text(
                    'BOUCLIER DU SALVATEUR / GARDE',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      color: LupusColors.sunAmber,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _selectedGuardTargetId ?? (alivePlayers.isNotEmpty ? alivePlayers.first.id : null),
                dropdownColor: const Color(0xFF1E1405),
                decoration: InputDecoration(
                  labelText: context.tr('admin_choose_protect_target'),
                  labelStyle: const TextStyle(color: LupusColors.textSecondary, fontSize: 12),
                  filled: true,
                  fillColor: const Color(0x66000000),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: alivePlayers.map((p) => DropdownMenuItem(
                  value: p.id,
                  child: Text('${p.name} (${p.role.getDisplayName(context)})', style: const TextStyle(color: Colors.white, fontSize: 12)),
                )).toList(),
                onChanged: (val) => setState(() => _selectedGuardTargetId = val),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    final target = _selectedGuardTargetId ?? (alivePlayers.isNotEmpty ? alivePlayers.first.id : null);
                    if (target != null) {
                      notifier.devGuardProtect(target);
                      _showToast('🛡️ ${room.players[target]?.name} est protégé par le Salvateur !');
                    }
                  },
                  icon: const Icon(Icons.shield_rounded, size: 16),
                  label: Text(context.tr('admin_activate_shield'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Carte : Cupidon (Amoureux)
        BentoCard(
          borderColor: const Color(0xFFEC4899),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('💘', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  const Text(
                    'LIAISON DES AMOUREUX (CUPIDON)',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      color: Color(0xFFEC4899),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedCupid1Id ?? (alivePlayers.isNotEmpty ? alivePlayers.first.id : null),
                      dropdownColor: const Color(0xFF1E1405),
                      decoration: InputDecoration(
                        labelText: context.tr('admin_lover_1'),
                        labelStyle: const TextStyle(color: LupusColors.textSecondary, fontSize: 11),
                        filled: true,
                        fillColor: const Color(0x66000000),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      items: alivePlayers.map((p) => DropdownMenuItem(
                        value: p.id,
                        child: Text(p.name, style: const TextStyle(color: Colors.white, fontSize: 11)),
                      )).toList(),
                      onChanged: (val) => setState(() => _selectedCupid1Id = val),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedCupid2Id ?? (alivePlayers.length > 1 ? alivePlayers[1].id : null),
                      dropdownColor: const Color(0xFF1E1405),
                      decoration: InputDecoration(
                        labelText: context.tr('admin_lover_2'),
                        labelStyle: const TextStyle(color: LupusColors.textSecondary, fontSize: 11),
                        filled: true,
                        fillColor: const Color(0x66000000),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      items: alivePlayers.map((p) => DropdownMenuItem(
                        value: p.id,
                        child: Text(p.name, style: const TextStyle(color: Colors.white, fontSize: 11)),
                      )).toList(),
                      onChanged: (val) => setState(() => _selectedCupid2Id = val),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDB2777),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    final p1 = _selectedCupid1Id ?? (alivePlayers.isNotEmpty ? alivePlayers.first.id : null);
                    final p2 = _selectedCupid2Id ?? (alivePlayers.length > 1 ? alivePlayers[1].id : null);
                    if (p1 != null && p2 != null && p1 != p2) {
                      notifier.devCupidLink(p1, p2);
                      _showToast('💘 ${room.players[p1]?.name} et ${room.players[p2]?.name} sont liés !');
                    }
                  },
                  icon: const Icon(Icons.favorite_rounded, size: 16),
                  label: Text(context.tr('admin_link_lovers'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Carte : Chasseur (Riposte)
        BentoCard(
          borderColor: const Color(0xFFF97316),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('🎯', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  const Text(
                    'TIR DU CHASSEUR (RIPOSTE)',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      color: Color(0xFFF97316),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _selectedHunterTargetId ?? (alivePlayers.isNotEmpty ? alivePlayers.first.id : null),
                dropdownColor: const Color(0xFF1E1405),
                decoration: InputDecoration(
                  labelText: context.tr('admin_choose_hunter_target'),
                  labelStyle: const TextStyle(color: LupusColors.textSecondary, fontSize: 12),
                  filled: true,
                  fillColor: const Color(0x66000000),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: alivePlayers.map((p) => DropdownMenuItem(
                  value: p.id,
                  child: Text('${p.name} (${p.role.getDisplayName(context)})', style: const TextStyle(color: Colors.white, fontSize: 12)),
                )).toList(),
                onChanged: (val) => setState(() => _selectedHunterTargetId = val),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEA580C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    final target = _selectedHunterTargetId ?? (alivePlayers.isNotEmpty ? alivePlayers.first.id : null);
                    if (target != null) {
                      notifier.devHunterShoot(target);
                      _showToast('🎯 Tir du Chasseur exécuté sur ${room.players[target]?.name} !');
                    }
                  },
                  icon: const Icon(Icons.crisis_alert_rounded, size: 16),
                  label: Text(context.tr('admin_trigger_retaliation'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 3. Gestion individuelle directe des 12 Joueurs / Bots
        const Text(
          'ROSTER DU PLATEAU • CONTRÔLE INDIVIDUEL (12 JOUEURS)',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: LupusColors.arcaneGold,
          ),
        ),
        const SizedBox(height: 8),

        ...room.playerList.map((player) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xAA12172A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: player.isAlive
                    ? (player.role.isEvil ? LupusColors.bloodRed : LupusColors.arcanePurple.withValues(alpha: 0.5))
                    : Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              children: [
                RoleCardImage(
                  role: player.role,
                  width: 38,
                  height: 50,
                  borderRadius: BorderRadius.circular(8),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              player.name,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: player.isAlive ? Colors.white : LupusColors.textMuted,
                                decoration: player.isAlive ? null : TextDecoration.lineThrough,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (player.isCaptain) const Text(' ⭐'),
                          if (player.isLover) const Text(' 💖'),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${player.role.getDisplayName(context)} • ${player.isAlive ? context.tr('alive') : context.tr('eliminated')}',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: player.isAlive ? player.role.accentColor : LupusColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                // Actions directes
                IconButton(
                  icon: Icon(
                    player.isAlive ? Icons.dangerous_rounded : Icons.favorite_rounded,
                    color: player.isAlive ? LupusColors.bloodRed : Colors.greenAccent,
                    size: 20,
                  ),
                  tooltip: player.isAlive ? 'Éliminer (devKill)' : 'Ressusciter (devRevive)',
                  onPressed: () {
                    if (player.isAlive) {
                      notifier.devKill(player.id, reason: 'décision du Maître du Jeu');
                      _showToast('💀 ${player.name} a été éliminé(e) !');
                    } else {
                      notifier.devRevive(player.id);
                      _showToast('✨ ${player.name} a été ressuscité(e) !');
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.edit_note_rounded, color: LupusColors.arcaneGold, size: 22),
                  tooltip: context.tr('admin_change_role_tooltip'),
                  onPressed: () => _showRoleSelector(player),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ==========================================
  // --- 1. VISION TOTALE DES RÔLES & INCARNATION (DEV VIEW) ---
  // ==========================================
  Widget _buildDevView(GameRoom room, LupusGameState gameState) {
    final notifier = ref.read(gameNotifierProvider.notifier);
    final effectivePlayer = room.players[gameState.effectiveUserId];
    final isImpersonating = gameState.isImpersonating;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // PANNEAU D'INCARNATION DYNAMIQUE DEV-MODE
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2E1065), Color(0xFF1E1B4B), Color(0xFF0F172A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isImpersonating ? LupusColors.arcaneGold : const Color(0xFF818CF8).withValues(alpha: 0.5),
              width: isImpersonating ? 1.5 : 1.0,
            ),
            boxShadow: isImpersonating ? LupusTheme.glowGold(opacity: 0.3) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text('🎭', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Text(
                        'INCARNATION DYNAMIQUE',
                        style: TextStyle(
                          fontFamily: 'serif',
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.9,
                          color: isImpersonating ? LupusColors.arcaneGold : Colors.white,
                        ),
                      ),
                    ],
                  ),
                  if (isImpersonating)
                    InkWell(
                      onTap: () {
                        notifier.impersonatePlayer(null);
                        _showToast('Identité réelle rétablie');
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: LupusColors.arcaneGold.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: LupusColors.arcaneGold, width: 0.8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.refresh_rounded, size: 12, color: LupusColors.arcaneGold),
                            SizedBox(width: 4),
                            Text(
                              'Réinitialiser',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: LupusColors.arcaneGold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                isImpersonating
                    ? 'Vous incarnez actuellement : ${effectivePlayer?.name ?? gameState.effectiveUserId} (${effectivePlayer?.role.displayName ?? "Inconnu"})'
                    : 'Sélectionnez un joueur ou bot ci-dessous pour agir sous son identité réelle avec le moteur officiel.',
                style: TextStyle(
                  fontSize: 10.5,
                  color: isImpersonating ? const Color(0xFFFDE68A) : LupusColors.textSecondary,
                  fontWeight: isImpersonating ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              const SizedBox(height: 10),

              // Sélecteur horizontal de joueurs à incarner
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: room.playerList.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final p = room.playerList[index];
                    final isCurrentIncarnated = p.id == gameState.effectiveUserId;
                    final isRealMe = p.id == gameState.currentUserId;

                    return GestureDetector(
                      onTap: () {
                        if (isCurrentIncarnated && isImpersonating) {
                          notifier.impersonatePlayer(null);
                          _showToast('Identité rétablie : ${gameState.currentUserName}');
                        } else {
                          notifier.impersonatePlayer(p.id);
                          _showToast('🎭 Incarnation active : ${p.name} (${p.role.displayName})');
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 110,
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                        decoration: BoxDecoration(
                          color: isCurrentIncarnated
                              ? LupusColors.arcaneGold.withValues(alpha: 0.25)
                              : const Color(0x660F172A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isCurrentIncarnated
                                ? LupusColors.arcaneGold
                                : (p.isAlive
                                    ? Colors.white.withValues(alpha: 0.15)
                                    : Colors.white.withValues(alpha: 0.05)),
                            width: isCurrentIncarnated ? 1.6 : 0.8,
                          ),
                          boxShadow: isCurrentIncarnated
                              ? [
                                  BoxShadow(
                                    color: LupusColors.arcaneGold.withValues(alpha: 0.4),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    p.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: isCurrentIncarnated ? FontWeight.w900 : FontWeight.w700,
                                      color: isCurrentIncarnated
                                          ? LupusColors.arcaneGold
                                          : (p.isAlive ? Colors.white : LupusColors.textMuted),
                                    ),
                                  ),
                                ),
                                if (p.isBot) ...[
                                  const SizedBox(width: 2),
                                  const Text('🤖', style: TextStyle(fontSize: 8)),
                                ],
                                if (isRealMe) ...[
                                  const SizedBox(width: 2),
                                  const Text('👑', style: TextStyle(fontSize: 8)),
                                ],
                              ],
                            ),
                            const SizedBox(height: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: p.role.accentColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                p.role.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w700,
                                  color: p.role.accentColor,
                                ),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              isCurrentIncarnated
                                  ? '✨ ACTIF'
                                  : (p.isAlive ? 'Incarner' : '💀 Mort'),
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                                color: isCurrentIncarnated
                                    ? LupusColors.arcaneGold
                                    : (p.isAlive ? const Color(0xFF94A3B8) : LupusColors.arcaneCrimson),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        // Carte d'état de la Double Action des Loups (si Nuit en cours)
        if (room.phase == GamePhase.nightWerewolves || room.phase.isNight) ...[
          _buildNightWerewolfStatusCard(room),
          const SizedBox(height: 12),
        ],

        const Text(
          'ROSTER SECRET DES JOUEURS (DEV-MODE)',
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
          final isPlayerIncarnated = player.id == gameState.effectiveUserId;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isPlayerIncarnated
                  ? const Color(0xCC2A1B4E)
                  : const Color(0xAA12172A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isPlayerIncarnated
                    ? LupusColors.arcaneGold
                    : (player.isAlive
                        ? (player.role.isEvil
                            ? LupusColors.arcaneCrimson.withValues(alpha: 0.5)
                            : LupusColors.arcanePurple.withValues(alpha: 0.35))
                        : Colors.white.withValues(alpha: 0.08)),
                width: isPlayerIncarnated ? 1.5 : 1.0,
              ),
              boxShadow: isPlayerIncarnated
                  ? [
                      BoxShadow(
                        color: LupusColors.arcaneGold.withValues(alpha: 0.35),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
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
                          Flexible(
                            child: Text(
                              player.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                          ),
                          if (player.isBot) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFF334155),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'BOT',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ),
                          ],
                          if (player.isCaptain) ...[
                            const SizedBox(width: 4),
                            const Text('⭐', style: TextStyle(fontSize: 12)),
                          ],
                          if (player.isLover) ...[
                            const SizedBox(width: 4),
                            const Text('💖', style: TextStyle(fontSize: 12)),
                          ],
                          if (player.isMuted) ...[
                            const SizedBox(width: 4),
                            const Text('🔇', style: TextStyle(fontSize: 12)),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        player.estDechu
                            ? '${player.role.displayName} (Déchu de ${player.roleInitial.displayName}) • ${player.role.defaultTeam.name.toUpperCase()}'
                            : '${player.role.displayName} • ${player.role.defaultTeam.name.toUpperCase()}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: player.role.accentColor,
                        ),
                      ),
                      if (player.roleInitial == GameRole.witch) ...[
                        const SizedBox(height: 2),
                        Text(
                          '🧪 Vie: ${player.potionsVie} | ☠️ Mort: ${player.potionsMort}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: LupusColors.poisonGreen,
                          ),
                        ),
                      ],
                      if (player.roleInitial == GameRole.seer) ...[
                        const SizedBox(height: 2),
                        Text(
                          '🔮 Visions restantes : ${player.visionsRestantes}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFC084FC),
                          ),
                        ),
                      ],
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

                const SizedBox(width: 8),

                // Colonne Actions (Incarner + Statut)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
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
                    const SizedBox(height: 6),
                    // Bouton Incarner
                    InkWell(
                      onTap: () {
                        if (isPlayerIncarnated && isImpersonating) {
                          notifier.impersonatePlayer(null);
                          _showToast('Identité rétablie : ${gameState.currentUserName}');
                        } else {
                          notifier.impersonatePlayer(player.id);
                          _showToast('🎭 Incarnation active : ${player.name} (${player.role.displayName})');
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: isPlayerIncarnated
                              ? LupusColors.arcaneGold
                              : const Color(0x33818CF8),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isPlayerIncarnated
                                ? LupusColors.arcaneGold
                                : const Color(0xFF818CF8).withValues(alpha: 0.5),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isPlayerIncarnated ? '✨' : '🎭',
                              style: const TextStyle(fontSize: 9),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              isPlayerIncarnated ? 'ACTIF' : 'Incarner',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: isPlayerIncarnated
                                    ? Colors.black
                                    : const Color(0xFFC7D2FE),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildNightWerewolfStatusCard(GameRoom room) {
    final victim = room.nightVictimId != null ? room.players[room.nightVictimId] : null;
    final silenced = room.blackWolfTargetId != null ? room.players[room.blackWolfTargetId] : null;
    final isComplete = victim != null && silenced != null && victim.id != silenced.id;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x339333EA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isComplete
              ? LupusColors.poisonGreen.withValues(alpha: 0.6)
              : const Color(0xFFC084FC).withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Text('🐺', style: TextStyle(fontSize: 14)),
                  SizedBox(width: 6),
                  Text(
                    'DOUBLE ACTION DES LOUPS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      color: Color(0xFFE9D5FF),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isComplete
                      ? const Color(0x3306D6A0)
                      : const Color(0x33E63946),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isComplete ? 'COMPLÈTE' : 'INCOMPLÈTE',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: isComplete
                        ? LupusColors.poisonGreen
                        : const Color(0xFFFCA5A5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Proie (Morsure) :',
                      style: TextStyle(fontSize: 10, color: LupusColors.textMuted),
                    ),
                    Text(
                      victim != null ? '🥩 ${victim.name}' : '❌ Aucune cible',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: victim != null ? const Color(0xFFFECDD3) : LupusColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Silence (Intimidation/Bluff) :',
                      style: TextStyle(fontSize: 10, color: LupusColors.textMuted),
                    ),
                    Text(
                      silenced != null
                          ? '🔇 ${silenced.name} ${(silenced.role.isEvil || silenced.role == GameRole.whiteWerewolf) ? "(Allié/Bluff)" : ""}'
                          : '❌ Aucune cible',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: silenced != null ? const Color(0xFFE9D5FF) : LupusColors.textMuted,
                      ),
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
        'label': 'Nuit des Loups (Proie & Silence)',
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
        'label': 'Élection Maire',
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

        // Section dédiée Dev-Mode : GESTION DU DÉBAT DU VILLAGE (si phase active)
        if (room.phase == GamePhase.dayDebate) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0x3300FF88),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFF00FF88),
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Text('🎙️', style: TextStyle(fontSize: 14)),
                        SizedBox(width: 6),
                        Text(
                          'DÉBAT EN DIRECT (RONDE DE PAROLE)',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            color: Color(0xFF00FF88),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF070B1D),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'File: ${room.debateQueue.length}',
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  room.currentSpeakerId != null
                      ? 'Orateur actuel : ${room.players[room.currentSpeakerId]?.name ?? "Inconnu"}'
                      : 'Aucun orateur en cours',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00FF88),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          notifier.passTurnDebate();
                          _showToast('Parole avancée (saut auto des bâillonnés)');
                        },
                        icon: const Icon(Icons.skip_next_rounded, size: 16),
                        label: const Text(
                          'SUIVANT (SAUT AUTO)',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: LupusColors.arcaneGold,
                          side: const BorderSide(color: LupusColors.arcaneGold),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          notifier.adminForcePhase(GamePhase.dayVoting);
                          _showToast('Débat clos ➔ Votes ouverts');
                        },
                        icon: const Icon(Icons.how_to_vote_rounded, size: 16),
                        label: const Text(
                          'OUVRIR LES VOTES',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            player.estDechu
                                ? '${player.name} (${player.role.displayName} • Ex-${player.roleInitial.displayName})'
                                : '${player.name} (${player.role.displayName})',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: player.isAlive
                                  ? Colors.white
                                  : LupusColors.textMuted,
                            ),
                          ),
                          if (player.roleInitial == GameRole.witch)
                            Text(
                              '🧪 Vie: ${player.potionsVie} | ☠️ Mort: ${player.potionsMort}',
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: LupusColors.poisonGreen,
                              ),
                            ),
                          if (player.roleInitial == GameRole.seer)
                            Text(
                              '🔮 Visions restantes : ${player.visionsRestantes}',
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFC084FC),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        if (player.isCaptain)
                          const Text('⭐ ', style: TextStyle(fontSize: 12)),
                        if (player.isMuted) ...[
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0x33FF3333),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: const Color(0xFFFF3333), width: 0.8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.mic_off_rounded,
                                    size: 10, color: Color(0xFFFF3333)),
                                SizedBox(width: 3),
                                Text(
                                  'BÂILLONNÉ',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFFFF5252),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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

                    // Nommer Maire
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
                          _showToast('${player.name} est Maire');
                        },
                        child: const Text(
                          '⭐ Maire',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Ligne Silence & Rôle
                Row(
                  children: [
                    // Réduire au silence / Rétablir parole
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          notifier.adminTogglePlayerMute(player.id);
                          _showToast(player.isMuted
                              ? '${player.name} : parole rétablie'
                              : '${player.name} : réduit(e) au silence');
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: player.isMuted
                                ? const Color(0x669333EA)
                                : const Color(0x661E243D),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: player.isMuted
                                  ? const Color(0xFFC084FC)
                                  : Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(player.isMuted ? '🔇' : '🎙️',
                                  style: const TextStyle(fontSize: 12)),
                              const SizedBox(width: 4),
                              Text(
                                player.isMuted
                                    ? 'Silencé (Actif)'
                                    : 'Silence Loup',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: player.isMuted
                                      ? const Color(0xFFE9D5FF)
                                      : LupusColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Changer de rôle
                    Expanded(
                      child: InkWell(
                        onTap: () => _showRoleSelector(player),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0x661E243D),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: LupusColors.arcanePurple
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('🎭', style: TextStyle(fontSize: 12)),
                              SizedBox(width: 4),
                              Text(
                                'Changer Rôle...',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: LupusColors.arcaneGlow,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Contrôles Dev-Mode Nuit des Loups (Double action : Dévorer + Silence)
                if ((room.phase == GamePhase.nightWerewolves || room.phase.isNight) && player.isAlive) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      // Fixer comme Proie
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            notifier.adminSetNightVictim(
                                room.nightVictimId == player.id ? null : player.id);
                            _showToast(room.nightVictimId == player.id
                                ? 'Proie retirée'
                                : '${player.name} désigné(e) comme proie des loups');
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: room.nightVictimId == player.id
                                  ? const Color(0x66991B1B)
                                  : const Color(0x332B1010),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: room.nightVictimId == player.id
                                    ? LupusColors.arcaneCrimson
                                    : Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('🥩', style: TextStyle(fontSize: 12)),
                                const SizedBox(width: 4),
                                Text(
                                  room.nightVictimId == player.id
                                      ? 'Proie (Active)'
                                      : 'Dévorer',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: room.nightVictimId == player.id
                                        ? const Color(0xFFFECDD3)
                                        : LupusColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Fixer comme Cible de Silence (autorise aussi les loups et soi-même pour le bluff)
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            notifier.adminSetNightSilence(
                                room.blackWolfTargetId == player.id ? null : player.id);
                            _showToast(room.blackWolfTargetId == player.id
                                ? 'Silence retiré'
                                : '${player.name} désigné(e) pour le silence nocturne');
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: room.blackWolfTargetId == player.id
                                  ? const Color(0x66581C87)
                                  : const Color(0x33311042),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: room.blackWolfTargetId == player.id
                                    ? const Color(0xFF9333EA)
                                    : Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('🔇', style: TextStyle(fontSize: 12)),
                                const SizedBox(width: 4),
                                Text(
                                  room.blackWolfTargetId == player.id
                                      ? 'Silence (Actif)'
                                      : 'Silence Nuit',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: room.blackWolfTargetId == player.id
                                        ? const Color(0xFFE9D5FF)
                                        : LupusColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
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
                itemCount: GameRole.playableRoles.length,
                itemBuilder: (context, index) {
                  final role = GameRole.playableRoles[index];
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

          // En-tête DEV-MOD
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
                              '👑 DEV-MOD • CONTRÔLE ADMIN',
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
                              'CODE SECRET 03031994 ACTIF • PARTIES 100% HUMAINES',
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
            child: StatefulBuilder(
              builder: (context, setModalState) {
                // Initialisation par défaut si nécessaire
                _lobbyPlayerCount ??= 12;
                if (_lobbyRoleCounts == null) {
                  _lobbyRoleCounts = {};
                  final defaultRoles = GameNotifier.generateBalancedRoles(_lobbyPlayerCount!);
                  for (final r in defaultRoles) {
                    _lobbyRoleCounts![r] = (_lobbyRoleCounts![r] ?? 0) + 1;
                  }
                }

                int totalSelectedRoles = 0;
                for (final count in _lobbyRoleCounts!.values) {
                  totalSelectedRoles += count;
                }

                final isDeckValid = totalSelectedRoles == _lobbyPlayerCount;

                List<GameRole> buildRoleDeck() {
                  final list = <GameRole>[];
                  _lobbyRoleCounts!.forEach((role, count) {
                    for (int i = 0; i < count; i++) {
                      list.add(role);
                    }
                  });
                  return list;
                }

                void applyBalancedPreset(int count) {
                  _lobbyPlayerCount = count;
                  _lobbyRoleCounts = {};
                  final roles = GameNotifier.generateBalancedRoles(count);
                  for (final r in roles) {
                    _lobbyRoleCounts![r] = (_lobbyRoleCounts![r] ?? 0) + 1;
                  }
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Carte 1 : CONFIGURATEUR DEV-MODE (SANDBOX AVEC BOTS & RÈGLES RÉELLES)
                      BentoCard(
                        borderColor: LupusColors.arcaneGold,
                        gradient: const LinearGradient(
                          colors: [
                            Color(0x44581C87),
                            Color(0x332E1065),
                            Color(0x330F0B1E),
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
                                    border: Border.all(color: LupusColors.arcaneGold),
                                  ),
                                  child: const Icon(Icons.smart_toy_rounded,
                                      color: LupusColors.arcaneGold, size: 28),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '🎮 SALLE DEV-MODE (MOTEUR RÉEL + BOTS)',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 13,
                                          color: LupusColors.arcaneGold,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        '1 Hôte Développeur + Bots passifs (Règles & minuteurs réels)',
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
                            const SizedBox(height: 14),

                            // Sélecteur de Nombre de Participants (6 à 18)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0x660F172A),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(Icons.groups_rounded, size: 16, color: LupusColors.arcaneGold),
                                          SizedBox(width: 6),
                                          Text(
                                            'NOMBRE DE PARTICIPANTS',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.9,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: LupusColors.arcaneGold.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: LupusColors.arcaneGold, width: 0.8),
                                        ),
                                        child: Text(
                                          '$_lobbyPlayerCount Joueurs',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w900,
                                            color: LupusColors.arcaneGold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  // Stepper et boutons rapides
                                  Row(
                                    children: [
                                      IconButton(
                                        style: IconButton.styleFrom(
                                          backgroundColor: const Color(0xFF1E293B),
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: _lobbyPlayerCount! > 6
                                            ? () {
                                                setModalState(() {
                                                  applyBalancedPreset(_lobbyPlayerCount! - 1);
                                                });
                                              }
                                            : null,
                                        icon: const Icon(Icons.remove_rounded, size: 18),
                                      ),
                                      Expanded(
                                        child: SliderTheme(
                                          data: SliderTheme.of(context).copyWith(
                                            activeTrackColor: LupusColors.arcaneGold,
                                            inactiveTrackColor: const Color(0xFF334155),
                                            thumbColor: LupusColors.arcaneGold,
                                            overlayColor: LupusColors.arcaneGold.withValues(alpha: 0.2),
                                            trackHeight: 4,
                                          ),
                                          child: Slider(
                                            value: _lobbyPlayerCount!.toDouble(),
                                            min: 6,
                                            max: 18,
                                            divisions: 12,
                                            onChanged: (val) {
                                              setModalState(() {
                                                applyBalancedPreset(val.round());
                                              });
                                            },
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        style: IconButton.styleFrom(
                                          backgroundColor: const Color(0xFF1E293B),
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: _lobbyPlayerCount! < 18
                                            ? () {
                                                setModalState(() {
                                                  applyBalancedPreset(_lobbyPlayerCount! + 1);
                                                });
                                              }
                                            : null,
                                        icon: const Icon(Icons.add_rounded, size: 18),
                                      ),
                                    ],
                                  ),

                                  // Raccourcis rapides
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [6, 8, 10, 12, 14, 16, 18].map((n) {
                                      final isSelected = _lobbyPlayerCount == n;
                                      return InkWell(
                                        onTap: () {
                                          setModalState(() {
                                            applyBalancedPreset(n);
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? LupusColors.arcaneGold
                                                : const Color(0xFF1E293B),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: isSelected
                                                  ? LupusColors.arcaneGold
                                                  : Colors.white.withValues(alpha: 0.1),
                                            ),
                                          ),
                                          child: Text(
                                            '$n J',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: isSelected ? Colors.black : Colors.white,
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 12),

                            // Configuration & Personnalisation du Deck de Rôles
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0x660F172A),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isDeckValid
                                      ? const Color(0xFF10B981).withValues(alpha: 0.5)
                                      : const Color(0xFFEF4444).withValues(alpha: 0.5),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(Icons.style_rounded, size: 16, color: Color(0xFFC084FC)),
                                          SizedBox(width: 6),
                                          Text(
                                            'COMPOSITION DES RÔLES',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.9,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isDeckValid
                                              ? const Color(0x3310B981)
                                              : const Color(0x33EF4444),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '$totalSelectedRoles / $_lobbyPlayerCount rôles',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w800,
                                            color: isDeckValid
                                                ? const Color(0xFF34D399)
                                                : const Color(0xFFF87171),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  // Presets rapides
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    physics: const BouncingScrollPhysics(),
                                    child: Row(
                                      children: [
                                        _buildPresetButton(
                                          label: '⚖️ Équilibré Standard',
                                          onTap: () {
                                            setModalState(() {
                                              applyBalancedPreset(_lobbyPlayerCount!);
                                            });
                                          },
                                        ),
                                        const SizedBox(width: 6),
                                        _buildPresetButton(
                                          label: '🐺 Meute Sanglante',
                                          onTap: () {
                                            setModalState(() {
                                              _lobbyRoleCounts = {
                                                GameRole.seer: 1,
                                                GameRole.witch: 1,
                                                GameRole.hunter: 1,
                                                GameRole.simpleWerewolf: 2,
                                                GameRole.bigBadWolf: 1,
                                                GameRole.vileFatherOfWolves: (_lobbyPlayerCount! >= 10) ? 1 : 0,
                                                GameRole.whiteWerewolf: (_lobbyPlayerCount! >= 12) ? 1 : 0,
                                                GameRole.simpleVillager: 0,
                                              };
                                              int currentSum = _lobbyRoleCounts!.values.fold(0, (a, b) => a + b);
                                              if (currentSum < _lobbyPlayerCount!) {
                                                _lobbyRoleCounts![GameRole.simpleVillager] = _lobbyPlayerCount! - currentSum;
                                              }
                                            });
                                          },
                                        ),
                                        const SizedBox(width: 6),
                                        _buildPresetButton(
                                          label: '✨ Chaos Arcanique',
                                          onTap: () {
                                            setModalState(() {
                                              _lobbyRoleCounts = {
                                                GameRole.seer: 1,
                                                GameRole.witch: 1,
                                                GameRole.cupid: 1,
                                                GameRole.defender: 1,
                                                GameRole.piedPiper: 1,
                                                GameRole.pyromaniac: 1,
                                                GameRole.simpleWerewolf: 2,
                                                GameRole.simpleVillager: 0,
                                              };
                                              int currentSum = _lobbyRoleCounts!.values.fold(0, (a, b) => a + b);
                                              if (currentSum < _lobbyPlayerCount!) {
                                                _lobbyRoleCounts![GameRole.simpleVillager] = _lobbyPlayerCount! - currentSum;
                                              }
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 10),

                                  // Liste complète de toutes les cartes et rôles configurables
                                  ...[
                                    // Meute des Loups
                                    GameRole.simpleWerewolf,
                                    GameRole.bigBadWolf,
                                    GameRole.whiteWerewolf,
                                    GameRole.blackWolf,
                                    GameRole.vileFatherOfWolves,
                                    GameRole.wolfCub,
                                    // Villageois à Pouvoirs
                                    GameRole.seer,
                                    GameRole.witch,
                                    GameRole.hunter,
                                    GameRole.defender,
                                    GameRole.cupid,
                                    GameRole.littleGirl,
                                    GameRole.thief,
                                    GameRole.elder,
                                    GameRole.scapegoat,
                                    GameRole.idiot,
                                    GameRole.twoSisters,
                                    GameRole.threeBrothers,
                                    GameRole.fox,
                                    GameRole.bearTamer,
                                    GameRole.stutteringJudge,
                                    GameRole.knightRustySword,
                                    GameRole.servantMaid,
                                    GameRole.actor,
                                    // Rôles Spéciaux & Solitaires
                                    GameRole.wildChild,
                                    GameRole.pyromaniac,
                                    GameRole.raven,
                                    GameRole.angel,
                                    GameRole.piedPiper,
                                    GameRole.sectLeader,
                                    GameRole.thiefOfHearts,
                                    // Villageois Simple
                                    GameRole.simpleVillager,
                                  ].map((role) {
                                    final currentCount = _lobbyRoleCounts![role] ?? 0;
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 3),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 18,
                                            height: 18,
                                            decoration: BoxDecoration(
                                              color: role.accentColor.withValues(alpha: 0.2),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Center(
                                              child: Text(
                                                role.isEvil ? '🐺' : (role == GameRole.seer ? '🔮' : (role == GameRole.witch ? '🧪' : '👤')),
                                                style: const TextStyle(fontSize: 10),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              role.displayName,
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w600,
                                                color: currentCount > 0 ? Colors.white : LupusColors.textMuted,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            visualDensity: VisualDensity.compact,
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                            onPressed: currentCount > 0
                                                ? () {
                                                    setModalState(() {
                                                      _lobbyRoleCounts![role] = currentCount - 1;
                                                    });
                                                  }
                                                : null,
                                            icon: const Icon(Icons.remove_circle_outline, size: 18, color: LupusColors.textSecondary),
                                          ),
                                          Container(
                                            constraints: const BoxConstraints(minWidth: 20),
                                            alignment: Alignment.center,
                                            child: Text(
                                              '$currentCount',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                                color: currentCount > 0 ? LupusColors.arcaneGold : LupusColors.textMuted,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            visualDensity: VisualDensity.compact,
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                            onPressed: totalSelectedRoles < _lobbyPlayerCount!
                                                ? () {
                                                    setModalState(() {
                                                      _lobbyRoleCounts![role] = currentCount + 1;
                                                    });
                                                  }
                                                : null,
                                            icon: const Icon(Icons.add_circle_outline, size: 18, color: LupusColors.arcaneGold),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),

                            const SizedBox(height: 12),

                            // Note sur la conformité de production
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0x331E1B4B),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF818CF8).withValues(alpha: 0.3)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.timer_outlined, size: 16, color: Color(0xFFC084FC)),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Moteur réel multijoueur : minuteurs authentiques de phase (20s/30s/40s/60s), résolutions canoniques et incarnation interactive de chaque rôle.',
                                      style: TextStyle(fontSize: 10, color: Color(0xFFE2E8F0)),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 14),

                            // Bouton de lancement Dev-Mode
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDeckValid ? LupusColors.arcaneGold : const Color(0xFF475569),
                                  foregroundColor: isDeckValid ? Colors.black : Colors.white60,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: isDeckValid ? 4 : 0,
                                ),
                                onPressed: isDeckValid
                                    ? () async {
                                        Navigator.pop(context);
                                        await ref
                                            .read(gameNotifierProvider.notifier)
                                            .startSandboxGame(
                                              playerCount: _lobbyPlayerCount!,
                                              customRoles: buildRoleDeck(),
                                            );
                                      }
                                    : null,
                                icon: const Icon(Icons.play_circle_fill_rounded, size: 22),
                                label: Text(
                                  isDeckValid
                                      ? 'LANCER LA SALLE DEV-MODE ($_lobbyPlayerCount JOUEURS)'
                                      : 'AJUSTEZ LES RÔLES ($totalSelectedRoles/$_lobbyPlayerCount)',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.9,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF475569)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Color(0xFFE2E8F0),
          ),
        ),
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
