import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../GameNotifier.dart';
import '../../models/game_phase.dart';
import '../../models/game_room.dart';
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
  bool _isNavigatingToArena = false;

  @override
  void initState() {
    super.initState();
    final state = ref.read(gameNotifierProvider);
    _nameController.text = state.currentUserName;

    // Déclenche le dialogue d'autorisations si c'est la toute première utilisation du jeu
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      LupusPermissionDialog.showIfNeeded(context);
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
      if (!_isNavigatingToArena) {
        _isNavigatingToArena = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const ArenaGameScreen()),
            );
          }
        });
      }
    } else {
      _isNavigatingToArena = false;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF04060E),
      resizeToAvoidBottomInset: false,
      body: room == null
          ? _buildMainMenu(context, gameState)
          : _buildWaitingLobby(context, gameState, room),
    );
  }

  /// Écran d'accueil principal identique à la maquette de référence (IMG_20260915_170230)
  Widget _buildMainMenu(BuildContext context, GameState gameState) {
    return Stack(
      children: [
        // Fond sombre de secours couvrant tout l'écran
        Positioned.fill(
          child: Container(
            color: const Color(0xFF04060E),
          ),
        ),
        // Fond d'ambiance avec estompage doux pour adapter tous les formats d'écran
        Positioned.fill(
          child: Image.asset(
            LupusAssets.lobbyMainMenuAsset,
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
        ),
        Positioned.fill(
          child: Container(
            color: Colors.black.withValues(alpha: 0.25),
          ),
        ),

        // Canvas interactif 688x1436 calqué au pixel près sur la maquette officielle
        SafeArea(
          child: Center(
            child: FittedBox(
              fit: BoxFit.contain,
              alignment: Alignment.center,
              child: SizedBox(
                width: 688,
                height: 1436,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // 1. Fond principal Stitch officiel
                    Positioned.fill(
                      child: Image.asset(
                        LupusAssets.lobbyMainMenuAsset,
                        fit: BoxFit.fill,
                      ),
                    ),

                    // 2. Déclencheur Secret Admin sur le Sceau du Loup (Double tap ou Appui long)
                    Positioned(
                      left: 240,
                      top: 30,
                      width: 208,
                      height: 165,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onDoubleTap: () => _openAdminTrigger(context),
                        onLongPress: () => _openAdminTrigger(context),
                      ),
                    ),

                    // 3. Indicateur / Badge Admin si le God Mode est activé
                    if (gameState.isAdmin)
                      Positioned(
                        top: 28,
                        right: 28,
                        child: GestureDetector(
                          onTap: () => AdminControlSheet.show(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1405),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: LupusColors.arcaneGold, width: 1.5),
                              boxShadow: LupusTheme.glowGold(opacity: 0.45),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('👑', style: TextStyle(fontSize: 16)),
                                SizedBox(width: 6),
                                Text(
                                  'GOD MODE',
                                  style: TextStyle(
                                    color: LupusColors.arcaneGold,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 11,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // 4. Message d'erreur éventuel
                    if (gameState.errorMessage != null)
                      Positioned(
                        left: 36,
                        right: 36,
                        top: 285,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: LupusColors.bloodRed.withValues(alpha: 0.90),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white30),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black87,
                                blurRadius: 14,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  gameState.errorMessage!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                                onPressed: () => ref.read(gameNotifierProvider.notifier).clearError(),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // 5. Icône Avatar personnalisée (dans la carte centrale)
                    Positioned(
                      left: 58,
                      top: 604,
                      width: 68,
                      height: 68,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _showAvatarSelector(context),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: gameState.currentUserAvatar != 0
                                ? const Color(0xFF1E2138)
                                : Colors.transparent,
                          ),
                          child: Center(
                            child: Icon(
                              BentoPlayerTile.avatarIcons[gameState.currentUserAvatar],
                              color: Colors.white70,
                              size: 34,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // 6. Champ de saisie du Nom de joueur (Guerrier_...)
                    Positioned(
                      left: 142,
                      top: 610,
                      width: 470,
                      height: 58,
                      child: Center(
                        child: TextField(
                          controller: _nameController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                          cursorColor: const Color(0xFFA855F7),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            hintText: 'Guerrier_...',
                            hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.35),
                              fontSize: 26,
                            ),
                          ),
                          onChanged: (val) {
                            ref.read(gameNotifierProvider.notifier).updateProfile(name: val);
                          },
                          onSubmitted: (val) {
                            ref.read(gameNotifierProvider.notifier).updateProfile(name: val);
                          },
                        ),
                      ),
                    ),

                    // 7. Bouton "CRÉER UN SALON" (zone gauche du panneau inférieur)
                    Positioned(
                      left: 28,
                      top: 775,
                      width: 335,
                      height: 235,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(24),
                            bottomLeft: Radius.circular(24),
                          ),
                          splashColor: const Color(0xFFA855F7).withValues(alpha: 0.35),
                          highlightColor: const Color(0xFFA855F7).withValues(alpha: 0.15),
                          onTap: gameState.isLoading
                              ? null
                              : () => ref.read(gameNotifierProvider.notifier).createRoom(),
                          child: Center(
                            child: gameState.isLoading
                                ? const CircularProgressIndicator(
                                    color: Color(0xFFA855F7),
                                    strokeWidth: 3,
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ),

                    // 8. Bouton / Saisie "CODE" (zone supérieure droite du panneau inférieur)
                    // Si un code est saisi, on masque le 'CODE' gravé avec un fond pierre discret
                    if (_codeController.text.isNotEmpty)
                      Positioned(
                        left: 415,
                        top: 812,
                        width: 190,
                        height: 52,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF353348),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    Positioned(
                      left: 375,
                      top: 785,
                      width: 270,
                      height: 105,
                      child: Center(
                        child: SizedBox(
                          width: 230,
                          height: 60,
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _codeController,
                                  textAlign: TextAlign.center,
                                  textCapitalization: TextCapitalization.characters,
                                  maxLength: 8,
                                  cursorColor: const Color(0xFFA855F7),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 3.5,
                                  ),
                                  decoration: const InputDecoration(
                                    counterText: '',
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  onChanged: (_) => setState(() {}),
                                  onSubmitted: (_) => _handleJoinOrAdmin(),
                                ),
                              ),
                              if (_codeController.text.isNotEmpty)
                                GestureDetector(
                                  onTap: () {
                                    _codeController.clear();
                                    setState(() {});
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 4),
                                    child: Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // 9. Bouton "REJOINDRE" (zone inférieure droite du panneau inférieur, pierre rouge)
                    Positioned(
                      left: 375,
                      top: 898,
                      width: 270,
                      height: 105,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          splashColor: const Color(0xFFEF4444).withValues(alpha: 0.40),
                          highlightColor: const Color(0xFFEF4444).withValues(alpha: 0.20),
                          onTap: gameState.isLoading
                              ? null
                              : () {
                                  if (_codeController.text.trim().isEmpty) {
                                    _showEnterCodeDialog(context);
                                  } else {
                                    _handleJoinOrAdmin();
                                  }
                                },
                          child: Center(
                            child: gameState.isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 3,
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Écran d'attente du Salon quand une partie a été créée ou rejointe
  Widget _buildWaitingLobby(BuildContext context, GameState gameState, GameRoom room) {
    return Stack(
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
                // Sceau / Médaillon du Loup Stitch
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

                // Carte Code du Salon
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
                const BentoVoiceControls(),

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

                // Panneau Bento de composition du Deck de rôles (Deck Builder)
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
            ),
          ),
        ),
      ],
    );
  }

  /// Boîte de dialogue de saisie du Code Salon
  void _showEnterCodeDialog(BuildContext context) {
    final localController = TextEditingController(text: _codeController.text);
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F111E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFA855F7), width: 1.5),
          ),
          title: const Text(
            'REJOINDRE UN SALON',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              fontSize: 16,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Saisissez le code du salon pour entrer dans la partie :',
                textAlign: TextAlign.center,
                style: TextStyle(color: LupusColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: localController,
                textAlign: TextAlign.center,
                textCapitalization: TextCapitalization.characters,
                autofocus: true,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4.0,
                  color: Colors.white,
                ),
                decoration: InputDecoration(
                  hintText: 'CODE',
                  hintStyle: const TextStyle(
                    color: LupusColors.textMuted,
                    letterSpacing: 3,
                  ),
                  filled: true,
                  fillColor: const Color(0xFF1E2138),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFA855F7)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0x55A855F7)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFA855F7), width: 2),
                  ),
                ),
                onSubmitted: (val) {
                  _codeController.text = val;
                  Navigator.of(ctx).pop();
                  _handleJoinOrAdmin();
                },
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('ANNULER', style: TextStyle(color: LupusColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: LupusColors.bloodRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                _codeController.text = localController.text;
                Navigator.of(ctx).pop();
                _handleJoinOrAdmin();
              },
              child: const Text('REJOINDRE', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        );
      },
    );
  }

  /// Sélecteur d'Avatar en modal bottom sheet
  void _showAvatarSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F111E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: Color(0xFFA855F7), width: 1.2),
      ),
      builder: (ctx) {
        final currentAvatar = ref.watch(gameNotifierProvider).currentUserAvatar;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'CHOISISSEZ VOTRE AVATAR',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: List.generate(BentoPlayerTile.avatarIcons.length, (index) {
                  final isSelected = currentAvatar == index;
                  return GestureDetector(
                    onTap: () {
                      ref.read(gameNotifierProvider.notifier).updateProfile(avatarIndex: index);
                      Navigator.of(ctx).pop();
                    },
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? const Color(0xFFA855F7).withValues(alpha: 0.3)
                            : const Color(0xFF1E2138),
                        border: Border.all(
                          color: isSelected ? const Color(0xFFA855F7) : Colors.white24,
                          width: isSelected ? 2.5 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: const Color(0xFFA855F7).withValues(alpha: 0.6),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                )
                              ]
                            : null,
                      ),
                      child: Icon(
                        BentoPlayerTile.avatarIcons[index],
                        color: isSelected ? Colors.white : Colors.white70,
                        size: 30,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
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
