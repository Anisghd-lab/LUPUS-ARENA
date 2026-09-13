import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../GameNotifier.dart';
import '../../models/game_phase.dart';
import '../../services/unity_ads_service.dart';
import '../admin/admin_control_sheet.dart';
import '../admin/admin_secret_dialog.dart';
import '../bento/bento_card.dart';
import '../bento/bento_player_tile.dart';
import '../bento/bento_voice_controls.dart';
import '../bento/role_selector_bento.dart';
import '../bento/lupus_permission_dialog.dart';
import '../theme/lupus_assets.dart';
import '../theme/lupus_theme.dart';
import 'arena_game_screen.dart';

class LobbyScreen extends ConsumerStatefulWidget {
  const LobbyScreen({super.key});

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final state = ref.read(gameNotifierProvider);
    _nameController.text = state.currentUserName;

    // Déclenche le dialogue d'autorisations si c'est la toute première utilisation du jeu
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await UnityAdsService.initialize(testMode: true);
      if (!mounted) return;
      LupusPermissionDialog.showIfNeeded(context);

      // Affiche la pub interstitielle Unity Ads une seule fois à l'entrée
      Future.delayed(const Duration(milliseconds: 1200), () {
        UnityAdsService.showStartupAdOnce();
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameNotifierProvider);
    final room = gameState.room;

    // Navigation automatique vers l'arène dès que la partie commence
    if (room != null && room.phase != GamePhase.lobby) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ArenaGameScreen()),
        );
      });
    }

    return Scaffold(
      backgroundColor: LupusColors.background,
      body: Stack(
        children: [
          // Fond atmosphérique Stitch (Village nocturne sous la pleine lune)
          Positioned.fill(
            child: LupusAssets.adaptiveImage(
              assetPath: LupusAssets.villageNightBgAsset,
              networkUrl: LupusAssets.villageNightBgUrl,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          ),
          // Vignette sombre
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF060A18).withValues(alpha: 0.90),
                    const Color(0xFF070B1D).withValues(alpha: 0.55),
                    const Color(0xFF04060E).withValues(alpha: 0.95),
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Sceau / Médaillon du Loup Stitch (Déclencheur Secret Admin: Long press ou Double tap)
                  Center(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onLongPress: () => _openAdminTrigger(context),
                      onDoubleTap: () => _openAdminTrigger(context),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8.0, bottom: 12.0),
                        child: Column(
                          children: [
                            Container(
                              width: 84,
                              height: 84,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: LupusTheme.glowPurple(opacity: 0.55),
                              ),
                              child: ClipOval(
                                child: LupusAssets.adaptiveImage(
                                  assetPath: LupusAssets.wolfSealAsset,
                                  networkUrl: LupusAssets.wolfSealUrl,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'LUPUS ARENA',
                                  style: TextStyle(
                                    fontFamily: 'serif',
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2.2,
                                    color: Colors.white,
                                  ),
                                ),
                                if (gameState.isAdmin) ...[
                                  const SizedBox(width: 6),
                                  const Text('👑', style: TextStyle(fontSize: 16)),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'L\'ARÈNE MYSTIQUE DES LOUPS-GAROUS',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                                color: LupusColors.arcaneGold.withValues(alpha: 0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              // Message d'erreur éventuel
              if (gameState.errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: LupusColors.bloodRed.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: LupusColors.bloodRed.withValues(alpha: 0.6)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: LupusColors.bloodRed),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          gameState.errorMessage!,
                          style: const TextStyle(color: LupusColors.bloodRed, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

                  // Bannière Maître du Jeu (God Mode) si actif
                  if (gameState.isAdmin) ...[
                    GestureDetector(
                      onTap: () => AdminControlSheet.show(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF422006), Color(0xFF1E1405), Color(0xFF0F0B02)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: LupusColors.arcaneGold, width: 1.5),
                          boxShadow: LupusTheme.glowGold(opacity: 0.35),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: LupusColors.arcaneGold.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Text('👑', style: TextStyle(fontSize: 20)),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'PANNEAU MAÎTRE DU JEU ACTIF',
                                    style: TextStyle(
                                      color: LupusColors.arcaneGold,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Toucher pour ouvrir le God Mode & la simulation',
                                    style: TextStyle(color: LupusColors.textSecondary, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded,
                                color: LupusColors.arcaneGold, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Si le joueur n'est pas encore dans un salon : Écran d'accueil
                  if (room == null) ...[
                    // Carte Bento : Profil Joueur
                    BentoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PROFIL DU GUERRIER',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: LupusColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Sélection d'Avatar
                      SizedBox(
                        height: 60,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: BentoPlayerTile.avatarIcons.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 10),
                          itemBuilder: (context, index) {
                            final isSelected = gameState.currentUserAvatar == index;
                            return GestureDetector(
                              onTap: () => ref
                                  .read(gameNotifierProvider.notifier)
                                  .updateProfile(avatarIndex: index),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? LupusColors.moonIndigo.withValues(alpha: 0.3)
                                      : LupusColors.surfaceElevated,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? LupusColors.moonIndigo
                                        : LupusColors.border,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Icon(
                                  BentoPlayerTile.avatarIcons[index],
                                  color: isSelected
                                      ? LupusColors.moonIndigo
                                      : LupusColors.textSecondary,
                                  size: 26,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Pseudo
                      TextField(
                        controller: _nameController,
                        style: const TextStyle(color: LupusColors.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Nom de joueur',
                          labelStyle: const TextStyle(color: LupusColors.textMuted),
                          filled: true,
                          fillColor: LupusColors.surfaceLight,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: LupusColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: LupusColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: LupusColors.moonIndigo),
                          ),
                          prefixIcon: const Icon(Icons.person_rounded, color: LupusColors.textSecondary),
                        ),
                        onChanged: (val) => ref
                            .read(gameNotifierProvider.notifier)
                            .updateProfile(name: val),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Carte Bento : Créer ou Rejoindre
                Row(
                  children: [
                    // Bouton Créer Salon
                    Expanded(
                      child: BentoCard(
                        onTap: gameState.isLoading
                            ? null
                            : () => ref.read(gameNotifierProvider.notifier).createRoom(),
                        borderColor: LupusColors.moonIndigo.withValues(alpha: 0.5),
                        gradient: LinearGradient(
                          colors: [
                            LupusColors.moonIndigo.withValues(alpha: 0.2),
                            LupusColors.surface,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.add_circle_outline_rounded,
                                color: LupusColors.moonIndigo, size: 36),
                            const SizedBox(height: 10),
                            const Text(
                              'CRÉER UN SALON',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                color: LupusColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Devenez l\'hôte',
                              style: TextStyle(
                                fontSize: 11,
                                color: LupusColors.moonIndigo.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Rejoindre un salon
                    Expanded(
                      child: BentoCard(
                        child: Column(
                          children: [
                            TextField(
                              controller: _codeController,
                              textAlign: TextAlign.center,
                              textCapitalization: TextCapitalization.characters,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 3,
                                color: LupusColors.textPrimary,
                              ),
                              decoration: InputDecoration(
                                hintText: 'CODE',
                                hintStyle: const TextStyle(
                                  color: LupusColors.textMuted,
                                  letterSpacing: 2,
                                ),
                                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                filled: true,
                                fillColor: LupusColors.surfaceLight,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: LupusColors.border),
                                ),
                              ),
                              onSubmitted: (_) => _handleJoinOrAdmin(),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: LupusColors.bloodRed,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: gameState.isLoading
                                    ? null
                                    : _handleJoinOrAdmin,
                                child: const Text(
                                  'REJOINDRE',
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // Dans le salon d'attente (Lobby)
                BentoCard(
                  borderColor: LupusColors.sunAmber.withValues(alpha: 0.5),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'CODE DU SALON',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              color: LupusColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            room.roomCode,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 4.0,
                              color: LupusColors.sunAmber,
                            ),
                          ),
                        ],
                      ),
                      IconButton.filledTonal(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: room.roomCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Code du salon copié !')),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, size: 20),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Contrôles Vocaux en direct dans le Lobby
                BentoVoiceControls(),

                const SizedBox(height: 14),

                // Liste des Guerriers connectés
                BentoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'JOUEURS RASSEMBLÉS (${room.playerList.length}/30)',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                              color: LupusColors.textSecondary,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: (room.playerList.length >= 4 && room.playerList.length <= 30)
                                  ? LupusColors.poisonGreen.withValues(alpha: 0.2)
                                  : LupusColors.bloodRed.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              (room.playerList.length >= 4 && room.playerList.length <= 30)
                                  ? 'Prêt à lancer'
                                  : (room.playerList.length < 4 ? 'Min. 4 joueurs' : 'Max 30 joueurs'),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: (room.playerList.length >= 4 && room.playerList.length <= 30)
                                    ? LupusColors.poisonGreen
                                    : LupusColors.bloodRed,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: room.playerList.map((player) {
                          final isMe = player.id == gameState.currentUserId;
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? LupusColors.moonIndigo.withValues(alpha: 0.2)
                                  : LupusColors.surfaceLight,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isMe ? LupusColors.moonIndigo : LupusColors.border,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (player.isHost) ...[
                                  const Icon(Icons.star_rounded,
                                      size: 14, color: LupusColors.sunAmber),
                                  const SizedBox(width: 4),
                                ],
                                Text(
                                  player.name,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isMe ? FontWeight.w800 : FontWeight.w600,
                                    color: isMe ? LupusColors.moonIndigo : LupusColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // PANNEAU BENTO DE COMPOSITION DU DECK DE RÔLES (Deck Builder)
                RoleSelectorBento(
                  room: room,
                  isHost: gameState.isHost,
                ),

                const SizedBox(height: 16),

                // Boutons d'action du Lobby
                if (gameState.isHost) ...[
                  Builder(
                    builder: (context) {
                      final totalRoles = room.totalRolesInPool;
                      final totalPlayers = room.playerList.length;
                      final isBalanced = totalRoles == totalPlayers;
                      final hasMinPlayers = totalPlayers >= 4;
                      final isUnderMax = totalPlayers <= 30;
                      final isValidPlayerCount = hasMinPlayers && isUnderMax;
                      final canLaunch = isBalanced && isValidPlayerCount;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!hasMinPlayers) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: LupusColors.bloodRed.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: LupusColors.bloodRed.withValues(alpha: 0.5)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.group_rounded,
                                      color: LupusColors.bloodRed, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Il faut au moins 4 guerriers connectés pour lancer la partie ($totalPlayers/4, max 30)',
                                      style: const TextStyle(
                                        color: LupusColors.bloodRed,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else if (!isUnderMax) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: LupusColors.bloodRed.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: LupusColors.bloodRed.withValues(alpha: 0.5)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.warning_amber_rounded,
                                      color: LupusColors.bloodRed, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Le salon dépasse la limite de 30 guerriers ($totalPlayers/30)',
                                      style: const TextStyle(
                                        color: LupusColors.bloodRed,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else if (!isBalanced) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: LupusColors.sunAmber.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: LupusColors.sunAmber.withValues(alpha: 0.5)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline_rounded,
                                      color: LupusColors.sunAmber, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Le total des rôles ($totalRoles) doit correspondre au nombre de joueurs connectés ($totalPlayers)',
                                      style: const TextStyle(
                                        color: LupusColors.sunAmber,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          SizedBox(
                            height: 52,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: canLaunch
                                    ? LupusColors.bloodRed
                                    : LupusColors.surfaceLight,
                                foregroundColor: canLaunch
                                    ? Colors.white
                                    : LupusColors.textMuted,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: canLaunch ? 4 : 0,
                              ),
                              onPressed: canLaunch
                                  ? () => ref.read(gameNotifierProvider.notifier).startGame()
                                  : null,
                              icon: Icon(
                                canLaunch ? Icons.play_arrow_rounded : Icons.lock_rounded,
                                size: 22,
                              ),
                              label: Text(
                                canLaunch
                                    ? 'LANCER L\'ARÈNE'
                                    : 'LANCER L\'ARÈNE ($totalRoles / $totalPlayers)',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: LupusColors.surfaceLight,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: LupusColors.border),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: LupusColors.moonIndigo,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'En attente du lancement par l\'hôte...',
                          style: TextStyle(
                            color: LupusColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 10),

                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: LupusColors.textMuted,
                  ),
                  onPressed: () =>
                      ref.read(gameNotifierProvider.notifier).leaveRoom(),
                  icon: const Icon(Icons.exit_to_app_rounded, size: 18),
                  label: const Text('Quitter ce salon'),
                ),
              ],
            ],
          ),
        ),
      ),
    ],
  ),
);
  }

  void _handleJoinOrAdmin() {
    final inputCode = _codeController.text.trim();
    if (inputCode == '03031994') {
      ref.read(gameNotifierProvider.notifier).unlockAdmin('03031994');
      _codeController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Text('👑', style: TextStyle(fontSize: 18)),
              SizedBox(width: 8),
              Text(
                'ACCÈS GOD MODE DÉVERROUILLÉ !',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          backgroundColor: LupusColors.arcaneGold,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
      AdminControlSheet.show(context);
      return;
    }
    ref.read(gameNotifierProvider.notifier).joinRoom(inputCode);
  }

  void _openAdminTrigger(BuildContext context) {
    final isAdmin = ref.read(gameNotifierProvider).isAdmin;
    if (isAdmin) {
      AdminControlSheet.show(context);
    } else {
      AdminSecretDialog.show(context);
    }
  }
}
