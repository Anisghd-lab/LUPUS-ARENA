import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

    // Chargement immédiat du pseudo persistant sauvegardé sur le téléphone
    SharedPreferences.getInstance().then((prefs) {
      final savedName = prefs.getString('player_nickname');
      if (savedName != null && savedName.trim().isNotEmpty && mounted) {
        setState(() {
          _nameController.text = savedName.trim();
        });
        ref.read(gameNotifierProvider.notifier).updateProfile(name: savedName.trim());
      }
    });

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
      resizeToAvoidBottomInset: true,
      body: room == null
          ? _buildMainMenu(context, gameState)
          : _buildWaitingLobby(context, gameState, room),
    );
  }

  /// Écran d'accueil principal (Menu) : Arrière-plan net + Composants natifs Flutter à 100%
  Widget _buildMainMenu(BuildContext context, LupusGameState gameState) {
    return Stack(
      children: [
        // 1. Image d'arrière-plan en plein écran avec BoxFit.cover
        Positioned.fill(
          child: Image.asset(
            LupusAssets.lobbyCleanBgAsset,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            errorBuilder: (_, __, ___) => Image.asset(
              LupusAssets.villageNightBgAssetFallback,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          ),
        ),

        // 2. Déclencheur secret Admin sur le Sceau en haut (Double tap ou Appui long)
        Positioned(
          top: 30,
          left: 0,
          right: 0,
          height: 150,
          child: Center(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onDoubleTap: () => _openAdminTrigger(context),
              onLongPress: () => _openAdminTrigger(context),
              child: const SizedBox(width: 170, height: 150),
            ),
          ),
        ),

        // 3. Indicateur / Badge Admin si le God Mode est activé
        if (gameState.isAdmin)
          Positioned(
            top: 36,
            right: 18,
            child: GestureDetector(
              onTap: () => AdminControlSheet.show(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1405),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: LupusColors.arcaneGold, width: 1.5),
                  boxShadow: LupusTheme.glowGold(opacity: 0.45),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('👑', style: TextStyle(fontSize: 14)),
                    SizedBox(width: 6),
                    Text(
                      'GOD MODE',
                      style: TextStyle(
                        color: LupusColors.arcaneGold,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        letterSpacing: 0.8,
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
            left: 18,
            right: 18,
            top: 220,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: LupusColors.bloodRed.withValues(alpha: 0.90),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white30),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black87,
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      gameState.errorMessage!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
                    onPressed: () => ref.read(gameNotifierProvider.notifier).clearError(),
                  ),
                ],
              ),
            ),
          ),

        // 5. Composants UI Natifs (Nom de joueur + Panneau d'action inférieur)
        SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: EdgeInsets.only(
                  top: constraints.maxHeight * 0.485,
                  bottom: 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildPlayerNameCard(gameState),
                    const SizedBox(height: 14),
                    _buildActionPanel(gameState),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// 1. Carte native semi-transparente "Nom de joueur"
  Widget _buildPlayerNameCard(LupusGameState gameState) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: const Color(0xD90B0E20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFA855F7).withValues(alpha: 0.70),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFA855F7).withValues(alpha: 0.30),
            blurRadius: 18,
            spreadRadius: 1,
          ),
          const BoxShadow(
            color: Colors.black87,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text(
                  'Nom de joueur',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                Text(
                  'Toucher l\'avatar pour changer',
                  style: TextStyle(
                    color: const Color(0xFFA855F7).withValues(alpha: 0.75),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                // Avatar interactif du joueur
                GestureDetector(
                  onTap: () => _showAvatarSelector(context),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: [Color(0xFF2E174D), Color(0xFF130924)],
                      ),
                      border: Border.all(
                        color: const Color(0xFFA855F7),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFA855F7).withValues(alpha: 0.45),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        BentoPlayerTile.avatarIcons[gameState.currentUserAvatar],
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Vrai TextField natif persistant
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                    cursorColor: const Color(0xFFA855F7),
                    decoration: const InputDecoration(
                      hintText: 'Guerrier...',
                      hintStyle: TextStyle(
                        color: Color(0x66FFFFFF),
                        fontSize: 18,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (val) {
                      ref.read(gameNotifierProvider.notifier).updateProfile(name: val);
                    },
                    onSubmitted: (val) {
                      ref.read(gameNotifierProvider.notifier).updateProfile(name: val);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 2. Panneau d'actions inférieur natif Flutter (CRÉER UN SALON + CODE / REJOINDRE)
  Widget _buildActionPanel(LupusGameState gameState) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF381559),
            Color(0xFF19092B),
            Color(0xFF0C0416),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFA855F7).withValues(alpha: 0.85),
          width: 1.8,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFA855F7).withValues(alpha: 0.45),
            blurRadius: 24,
            spreadRadius: 2,
          ),
          const BoxShadow(
            color: Colors.black87,
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // GAUCHE : Bouton "CRÉER UN SALON"
            Expanded(
              flex: 13,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: gameState.isLoading
                      ? null
                      : () => ref.read(gameNotifierProvider.notifier).createRoom(),
                  borderRadius: BorderRadius.circular(16),
                  splashColor: const Color(0xFFA855F7).withValues(alpha: 0.4),
                  highlightColor: const Color(0xFFA855F7).withValues(alpha: 0.2),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF4C1D82),
                          Color(0xFF280C4B),
                          Color(0xFF16042E),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFA855F7).withValues(alpha: 0.85),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFA855F7).withValues(alpha: 0.35),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Croix runique stylisée en violet lumineux
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFA855F7).withValues(alpha: 0.85),
                                blurRadius: 18,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              '᛭',
                              style: TextStyle(
                                color: Color(0xFFF3E8FF),
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (gameState.isLoading)
                          const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Color(0xFFA855F7),
                            ),
                          )
                        else ...[
                          const Text(
                            'CRÉER UN SALON',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Devenez l\'hôte',
                            style: TextStyle(
                              color: Color(0xFFC084FC),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 10),

            // DROITE : Zone Code & Rejoindre (empilés)
            Expanded(
              flex: 11,
              child: Column(
                children: [
                  // Champ "CODE" (vrai TextField fonctionnel, sans Text superposé, hintText effaçable)
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF33374B),
                            Color(0xFF222638),
                            Color(0xFF171926),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFF64748B),
                          width: 1.5,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black54,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: TextField(
                          controller: _codeController,
                          textAlign: TextAlign.center,
                          textCapitalization: TextCapitalization.characters,
                          maxLength: 8,
                          cursorColor: const Color(0xFFA855F7),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3.5,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'CODE',
                            hintStyle: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 3.5,
                            ),
                            counterText: '',
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                          ),
                          onSubmitted: (_) => _handleJoinOrAdmin(),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Bouton "REJOINDRE" (dégradé rouge bordeaux sombre et bordure)
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: gameState.isLoading ? null : _handleJoinOrAdmin,
                        borderRadius: BorderRadius.circular(14),
                        splashColor: const Color(0xFFEF4444).withValues(alpha: 0.4),
                        highlightColor: const Color(0xFFEF4444).withValues(alpha: 0.2),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFB91C1C),
                                Color(0xFF881313),
                                Color(0xFF530A0A),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFFEF4444),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFDC2626).withValues(alpha: 0.5),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: const Text(
                              'REJOINDRE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Écran d'attente du Salon quand une partie a été créée ou rejointe
  Widget _buildWaitingLobby(BuildContext context, LupusGameState gameState, GameRoom room) {
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
    if (inputCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Veuillez saisir le code du salon à rejoindre.'),
          backgroundColor: LupusColors.bloodRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
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
