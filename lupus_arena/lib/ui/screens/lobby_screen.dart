import 'dart:math' as math;
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
import '../bento/bento_voice_controls.dart';
import '../bento/medieval_fantasy_button.dart';
import '../bento/role_selector_bento.dart';
import '../bento/lupus_permission_dialog.dart';
import '../bento/app_update_dialog.dart';
import '../../services/update_service.dart';
import '../theme/lupus_assets.dart';
import '../theme/lupus_avatars.dart';
import '../theme/lupus_theme.dart';
import '../../services/audio_manager.dart';
import '../../services/locale_provider.dart';
import '../../services/lupus_permission_service.dart';
import '../../services/app_translations.dart';
import '../bento/language_dialog.dart';
import 'arena_game_screen.dart';

class LobbyScreen extends ConsumerStatefulWidget {
  final LocaleProvider? localeProvider;

  const LobbyScreen({super.key, this.localeProvider});

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> with WidgetsBindingObserver {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  bool _isNavigatingToArena = false;
  AppUpdateInfo? _availableUpdate;
  bool _isCheckingUpdate = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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

    // Dialogue de langue obligatoire au tout premier lancement, puis autorisations
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await LanguageDialog.showFirstLaunchIfNeeded(
        context,
        widget.localeProvider ?? LocaleProvider.instance,
      );
      if (!mounted) return;
      LupusPermissionDialog.showIfNeeded(context);
    });

    // Vérification en arrière-plan d'une nouvelle mise à jour GitHub Releases
    _checkForUpdateInBackground();

    // Démarrage de la surveillance globale des permissions en arrière-plan
    LupusPermissionService().startBackgroundPermissionMonitor();

    // Démarrage de la musique d'ambiance STRICTEMENT sur l'accueil (Menu principal / room == null)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (ref.read(gameNotifierProvider).room == null) {
          LupusAudioManager.instance.playLobbyMusic();
        } else {
          LupusAudioManager.instance.stopLobbyMusic();
        }
      }
    });
  }

  Future<void> _checkForUpdateInBackground() async {
    if (_isCheckingUpdate) return;
    _isCheckingUpdate = true;
    try {
      final update = await UpdateService().checkForUpdate();
      if (mounted && update != null) {
        setState(() {
          _availableUpdate = update;
        });
      }
    } catch (_) {
      // Ignorer silencieusement pour ne pas bloquer l'expérience utilisateur
    } finally {
      _isCheckingUpdate = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      LobbyAudioManager.instance.pauseLobbyMusic();
    } else if (state == AppLifecycleState.resumed) {
      // Reprend UNIQUEMENT si on est encore dans le lobby et pas dans une salle active
      if (ref.read(gameNotifierProvider).room == null) {
        LobbyAudioManager.instance.resumeLobbyMusic();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    LobbyAudioManager.instance.stopLobbyMusic();
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<LupusGameState>(gameNotifierProvider, (previous, next) {
      if (next.room == null) {
        LobbyAudioManager.instance.playLobbyMusic();
      } else {
        LobbyAudioManager.instance.stopLobbyMusic();
      }
    });

    final gameState = ref.watch(gameNotifierProvider);
    final room = gameState.room;

    // Navigation automatique vers l'arène dès que la partie commence
    if (room != null && room.phase != GamePhase.lobby) {
      if (!_isNavigatingToArena) {
        _isNavigatingToArena = true;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          final nav = Navigator.of(context);
          // 1. COUPER D'ABORD ET ATTENDRE LE VERROU
          await LobbyAudioManager.instance.stopLobbyMusic();
          // 2. NAVIGUER ENSUITE
          if (mounted) {
            nav.pushReplacement(
              MaterialPageRoute(builder: (_) => const ArenaGameScreen()),
            );
          }
        });
      }
    } else {
      _isNavigatingToArena = false;
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF04060E),
        resizeToAvoidBottomInset: true,
        body: SizedBox.expand(
          child: room == null
              ? _buildMainMenu(context, gameState)
              : _buildWaitingLobby(context, gameState, room),
        ),
      ),
    );
  }

  /// Écran d'accueil principal (Menu) : Arrière-plan net + Composants natifs Flutter à 100%
  Widget _buildMainMenu(BuildContext context, LupusGameState gameState) {
    final media = MediaQuery.of(context);
    final screenSize = media.size;
    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Image d'arrière-plan en plein écran avec BoxFit.cover (garantit 0 vide noir)
          Positioned.fill(
            child: Image.asset(
              LupusAssets.lobbyBackdropAsset,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorBuilder: (context, error, stackTrace) => Image.asset(
                LupusAssets.lobbyFantasyBgFallbackAsset,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorBuilder: (context, error, stackTrace) => Image.asset(
                  LupusAssets.lobbyFantasyBgAltAsset,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  errorBuilder: (context, error, stackTrace) => Image.asset(
                    LupusAssets.lobbyCleanBgAsset,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    errorBuilder: (context, error, stackTrace) => Image.asset(
                      LupusAssets.villageNightBgAssetFallback,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 2. Déclencheur secret Admin sur le Sceau en haut (Double tap ou Appui long)
          Positioned(
            top: media.padding.top > 0 ? media.padding.top : 24,
            left: 0,
            right: 0,
            height: 140,
            child: Center(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onDoubleTap: () => _openAdminTrigger(context),
                onLongPress: () => _openAdminTrigger(context),
                child: const SizedBox(width: 170, height: 140),
          // 3. Boutons d'action positionnés en bas — à l'emplacement exact du "X"
          // Dégage totalement le corps du loup-garou et son socle rocheux,
          // positionné juste au-dessus du grand cercle runique violet au sol.
          Positioned(
            bottom: media.viewInsets.bottom > 0
                ? media.viewInsets.bottom + 16.0
                : math.max(110.0, (media.padding.bottom > 0 ? media.padding.bottom : 16.0) + 85.0),
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              bottom: false,
              child: Center(
                child: _buildActionButtonsColumn(context, gameState),
              ),
            ),
          ),

          // 4. Message d'erreur éventuel
          if (gameState.errorMessage != null)
            Positioned(
              left: 18,
              right: 18,
              top: (media.padding.top > 0 ? media.padding.top : 24) + 65,
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

          // 5. Barre supérieure (Top Bar) au PREMIER PLAN absolu du Stack
          // Capsule Joueur à gauche, Globe & MAJ à droite (au-dessus du ScrollView pour garantir 100% des clics)
          Positioned(
            top: (media.padding.top > 0 ? media.padding.top : 24) + 6,
            left: 18,
            right: 18,
            child: _buildTopBar(context, gameState),
          ),
        ],
      ),
    );
  }

  /// Boîte de dialogue pour modifier le pseudo depuis la capsule de la barre supérieure
  void _showNameEditDialog(BuildContext context, String currentName) {
    _nameController.text = currentName;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F1424),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: LupusColors.arcaneGold, width: 1.5),
        ),
        title: Text(
          context.tr('player_name'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        content: TextField(
          controller: _nameController,
          autofocus: true,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          cursorColor: LupusColors.arcaneGold,
          decoration: InputDecoration(
            hintText: context.tr('name_hint'),
            hintStyle: const TextStyle(color: Colors.white38),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: LupusColors.arcaneGold.withValues(alpha: 0.5),
              ),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: LupusColors.arcaneGold, width: 2),
            ),
          ),
          onSubmitted: (val) {
            final trimmed = val.trim();
            if (trimmed.isNotEmpty) {
              ref.read(gameNotifierProvider.notifier).updateProfile(name: trimmed);
            }
            Navigator.of(ctx).pop();
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              context.tr('cancel'),
              style: const TextStyle(color: Colors.white60),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: LupusColors.arcaneGold,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              final trimmed = _nameController.text.trim();
              if (trimmed.isNotEmpty) {
                ref.read(gameNotifierProvider.notifier).updateProfile(name: trimmed);
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// 1. Barre supérieure (Top Bar) — styles identiques au HUD de l'Arena (Room)
  ///
  /// ┌──────────────────────────────────────────────────────────┐
  /// │ [Avatar] Pseudo ✏️          [MAJ pill] [🌐 Globe arcaneGold] │
  /// └──────────────────────────────────────────────────────────┘
  ///
  /// • Capsule pseudo  : fond 0xCC12182E, border arcaneGold 0.6, radius 10 → identique à la room
  /// • Bouton Globe    : cercle 32×32, fond 0xC012182E, border arcaneGold 0.4, icône 16pt → identique à la room
  /// • Badge version   : pilule sombre 0xCC0D1F1A, liseré emerald runique
  Widget _buildTopBar(BuildContext context, LupusGameState gameState) {
    final displayName = gameState.currentUserName.isNotEmpty
        ? gameState.currentUserName
        : 'Loup-Garou';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ── À GAUCHE : Capsule Profil — Logo officiel tête de loup (28x28) + Pseudo ──
        // Fond 0xCC12182E · border arcaneGold 0.6 w=0.8 · radius 10
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _showNameEditDialog(context, gameState.currentUserName),
          child: Container(
            padding: const EdgeInsets.only(left: 4, right: 10, top: 3.5, bottom: 3.5),
            decoration: BoxDecoration(
              color: const Color(0xCC12182E),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: LupusColors.arcaneGold.withValues(alpha: 0.6),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: LupusColors.arcaneGold.withValues(alpha: 0.12),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Véritable logo officiel du jeu (icône de tête de loup) précisément en 28x28 dp
                ClipOval(
                  child: Image.asset(
                    LupusAssets.wolfSealAsset,
                    width: 28,
                    height: 28,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Image.network(
                      LupusAssets.wolfSealUrl,
                      width: 28,
                      height: 28,
                      fit: BoxFit.contain,
                      errorBuilder: (c, e, s) => const Icon(
                        Icons.pets_rounded,
                        color: LupusColors.arcaneGold,
                        size: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                // Nom du joueur en arcaneGold serif
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: Text(
                    displayName,
                    style: const TextStyle(
                      fontFamily: 'serif',
                      color: LupusColors.arcaneGold,
                      fontSize: 11.0,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),

        const Spacer(),

        // ── À DROITE : [Badge DEV] + [Pilule MAJ] + [Globe] ──
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Badge DEV (admin uniquement) — style harmonisé Arena
            if (gameState.isAdmin) ...[
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => AdminControlSheet.show(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF422006),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: LupusColors.arcaneGold.withValues(alpha: 0.6),
                      width: 0.8,
                    ),
                    boxShadow: LupusTheme.glowGold(opacity: 0.3),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('👑', style: TextStyle(fontSize: 11)),
                      SizedBox(width: 3),
                      Text(
                        'DEV',
                        style: TextStyle(
                          color: LupusColors.arcaneGold,
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],

            // Pilule MAJ — thème sombre runique, liseré doré-émeraude (si mise à jour disponible)
            if (_availableUpdate != null) ...[
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => AppUpdateDialog.show(context, _availableUpdate!),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xCC0D1F1A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF34D399).withValues(alpha: 0.7),
                      width: 0.9,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.system_update_rounded,
                        color: Color(0xFF34D399),
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'v${_availableUpdate!.version}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Text(
                          'NEW',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 7,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],

            // ── Bouton Globe — IDENTIQUE au HUD de l'Arena (_buildStitchTopHUD) ──
            // Cercle 32×32 · fond 0xC012182E · border arcaneGold 0.4 · icône language_rounded 16pt
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => LanguageDialog.show(
                context,
                widget.localeProvider ?? LocaleProvider.instance,
              ),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xC012182E),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: LupusColors.arcaneGold.withValues(alpha: 0.4),
                  ),
                ),
                child: const Icon(
                  Icons.language_rounded,
                  size: 16,
                  color: LupusColors.arcaneGold,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 2. Boutons d'action empilés verticalement dans une Column centrée
  /// - CRÉER UN SALON : Mauve néon mystique
  /// - CODE DU SALON : Sombre semi-transparent + bordure subtile
  /// - REJOINDRE : Vert électrique runique
  Widget _buildActionButtonsColumn(BuildContext context, LupusGameState gameState) {
    return LobbyActionButtons(
      gameState: gameState,
      codeController: _codeController,
      onJoin: _handleJoinOrAdmin,
      onCreate: () async {
        await LobbyAudioManager.instance.stopLobbyMusic();
        await ref.read(gameNotifierProvider.notifier).createRoom();
      },
    );
  }

  /// Écran d'attente du Salon quand une partie a été créée ou rejointe
  Widget _buildWaitingLobby(BuildContext context, LupusGameState gameState, GameRoom room) {
    // Coupe immédiatement la musique dès l'entrée dans le salon d'attente
    LupusAudioManager.instance.stopLobbyMusic();

    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
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
          Positioned.fill(
            child: SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Barre supérieure du Salon d'attente : Sélecteur de langue & Quitter
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              GestureDetector(
                                onTap: () => LanguageDialog.show(
                                  context,
                                  widget.localeProvider ?? LocaleProvider.instance,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10162A).withValues(alpha: 0.85),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: LupusColors.arcaneGold.withValues(alpha: 0.6),
                                      width: 1.2,
                                    ),
                                    boxShadow: LupusTheme.glowGold(opacity: 0.25),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.language_rounded,
                                        color: LupusColors.arcaneGold,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        LocaleProvider.instance.languageCode == 'ar'
                                            ? 'العربية 🇩🇿'
                                            : (LocaleProvider.instance.languageCode == 'en'
                                                ? 'EN 🇬🇧'
                                                : 'FR 🇫🇷'),
                                        style: const TextStyle(
                                          color: LupusColors.arcaneGold,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 11,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white70,
                                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                onPressed: () => ref.read(gameNotifierProvider.notifier).leaveRoom(),
                                icon: const Icon(Icons.logout_rounded, size: 16, color: LupusColors.bloodRed),
                                label: Text(
                                  context.tr('leave_room'),
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                        ),

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
                            context.tr('app_subtitle'),
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
                            context.tr(gameState.errorMessage!),
                            style: const TextStyle(color: LupusColors.bloodRed, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Bannière Maître du Jeu (DEV-MOD) si actif
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
                      child: const Row(
                        children: [
                          Text('👑', style: TextStyle(fontSize: 20)),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '👑 DEV-MOD MAÎTRE DU JEU ACTIF',
                                  style: TextStyle(
                                    color: LupusColors.arcaneGold,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Toucher pour ouvrir le panneau DEV-MOD',
                                  style: TextStyle(color: LupusColors.textSecondary, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios_rounded,
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
                          Text(
                            context.tr('enter_room_code').toUpperCase(),
                            style: const TextStyle(
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
                            SnackBar(content: Text(context.tr('copy_code'))),
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

                // Liste des Guerriers connectés (12 Joueurs stricts)
                BentoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'GUERRIERS RASSEMBLÉS (${room.playerList.length}/12)',
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
                              color: room.playerList.length == 12
                                  ? LupusColors.poisonGreen.withValues(alpha: 0.2)
                                  : LupusColors.bloodRed.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              room.playerList.length == 12
                                  ? '12/12 Prêt à lancer'
                                  : '${room.playerList.length}/12 Guerriers',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: room.playerList.length == 12
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
                      final is12Players = totalPlayers == 12;
                      final is12Roles = totalRoles == 12;
                      final canLaunch = is12Players && is12Roles;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (totalPlayers < 12) ...[
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
                                      'En attente de 12 guerriers connectés ($totalPlayers/12)',
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
                          ] else if (totalPlayers > 12) ...[
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
                                      'Le salon dépasse la limite de 12 guerriers ($totalPlayers/12)',
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
                          ] else if (!is12Roles) ...[
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
                                      'Le total des cartes de rôles ($totalRoles) doit être exactement de 12 cartes',
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
                            child: canLaunch
                                ? MedievalFantasyButton.ruby(
                                    borderRadius: 16,
                                    onTap: () => ref.read(gameNotifierProvider.notifier).startGame(),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.play_arrow_rounded,
                                          color: Colors.white,
                                          size: 22,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          context.tr('start_game').toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.8,
                                            shadows: [
                                              Shadow(
                                                color: Colors.black,
                                                blurRadius: 4,
                                                offset: Offset(0, 1),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : MedievalFantasyButton.stone(
                                    borderRadius: 16,
                                    enabled: false,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.lock_rounded,
                                          color: Color(0xFF94A3B8),
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${context.tr('start_game').toUpperCase()} ($totalRoles / $totalPlayers)',
                                          style: const TextStyle(
                                            color: Color(0xFF94A3B8),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                      ],
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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: LupusColors.moonIndigo,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          context.tr('waiting_players'),
                          style: const TextStyle(
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
                  label: Text(context.tr('leave_room')),
                ),
              ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Sélecteur d'Avatar en modal bottom sheet stylisé Dark Fantasy
  void _showAvatarSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0C0E1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: Color(0xFF6B4A8E), width: 1.5),
      ),
      builder: (ctx) {
        final currentAvatar = ref.watch(gameNotifierProvider).currentUserAvatar;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Text(
                  'CHOISISSEZ VOTRE INCARNATION',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14.5,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Sélectionnez votre avatar Dark Fantasy pour l\'arène',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.55,
                  ),
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: List.generate(LupusAvatars.all.length, (index) {
                        final avatarItem = LupusAvatars.all[index];
                        final isSelected = currentAvatar == index;
                        return GestureDetector(
                          onTap: () {
                            ref.read(gameNotifierProvider.notifier).updateProfile(avatarIndex: index);
                            Navigator.of(ctx).pop();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 76,
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? avatarItem.borderColor.withValues(alpha: 0.18)
                                  : const Color(0xFF141829),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? avatarItem.borderColor
                                    : Colors.white12,
                                width: isSelected ? 2.0 : 1.0,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: avatarItem.glowColor,
                                        blurRadius: 10,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: avatarItem.gradientColors,
                                    ),
                                    border: Border.all(
                                      color: avatarItem.borderColor.withValues(alpha: 0.7),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      avatarItem.icon,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  avatarItem.name,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                                    fontSize: 9.5,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleJoinOrAdmin() async {
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
                'ACCÈS DEV-MODE DÉVERROUILLÉ !',
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
    await LobbyAudioManager.instance.stopLobbyMusic();
    if (mounted) {
      ref.read(gameNotifierProvider.notifier).joinRoom(inputCode);
    }
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

/// Widget des boutons d'action du Lobby (Style Dark Fantasy & Runes)
/// Taille divisée par deux (largeur 110 dp, hauteur 32 dp, sans emoji/icône porte)
class LobbyActionButtons extends StatelessWidget {
  final LupusGameState gameState;
  final TextEditingController codeController;
  final VoidCallback onJoin;
  final VoidCallback onCreate;

  const LobbyActionButtons({
    super.key,
    required this.gameState,
    required this.codeController,
    required this.onJoin,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    const double buttonHeight = 42.0;
    const double buttonWidth = 144.0;
    final borderRadius = BorderRadius.circular(10);

    return Center(
      child: SizedBox(
        width: buttonWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Bouton "CRÉER UN SALON"
            // Dégradé profond violet/mauve lunaire (obsidienne violacée avec reflets néon mystiques)
            // Fine bordure ciselée runique dorée/bronze et icône lune nocturne
            Container(
              height: buttonHeight,
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF5A1E8A), // Reflet néon mystique améthyste
                    Color(0xFF2E0D4E), // Obsidienne violacée
                    Color(0xFF16062A), // Profondeur nuit lunaire sombre
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                border: Border.all(
                  color: const Color(0xFFE5C158).withValues(alpha: 0.85), // Bordure ciselée or/bronze
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B25C7).withValues(alpha: 0.38), // Lueur néon violette mystique
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                  BoxShadow(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.22), // Lueur bronze dorée
                    blurRadius: 4,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 7,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: borderRadius,
                  onTap: gameState.isLoading ? null : onCreate,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Center(
                      child: gameState.isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.0,
                                color: Color(0xFFFFD54F),
                              ),
                            )
                          : FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Icône thématique loup-garou / nuit lunaire
                                  const Icon(
                                    Icons.nights_stay_rounded,
                                    color: Color(0xFFFFD54F),
                                    size: 14,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    context.tr('create_room').toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.7,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black,
                                          blurRadius: 4,
                                          offset: Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // 2. Bouton / Champ "CODE DU SALON"
            // Style pierre runique sombre et sobre
            Container(
              height: buttonHeight,
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF1E2330), // Pierre taillée sombre
                    Color(0xFF121622), // Ardoise runique
                    Color(0xFF0A0D15), // Pierre noire profonde
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                border: Border.all(
                  color: const Color(0xFF64748B).withValues(alpha: 0.55), // Fer forgé runique sobre
                  width: 1.1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.65),
                    blurRadius: 7,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: TextField(
                  controller: codeController,
                  textAlign: TextAlign.center,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 8,
                  cursorColor: const Color(0xFFFFD700),
                  style: const TextStyle(
                    color: Color(0xFFF1F5F9),
                    fontSize: 12.0,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.4,
                    shadows: [
                      Shadow(
                        color: Colors.black,
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  decoration: InputDecoration(
                    hintText: context.tr('enter_room_code').toUpperCase(),
                    hintStyle: const TextStyle(
                      color: Color(0xFF788296),
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.6,
                    ),
                    counterText: '',
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  onSubmitted: (_) => onJoin(),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // 3. Bouton "REJOINDRE"
            // Dégradé sombre teinté de vert spectral (sang de loup / foudre runique)
            // Bordure émeraude/cuivre assortie et icône patte de loup (griffes)
            Container(
              height: buttonHeight,
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF14532D), // Reflet vert spectral sombre
                    Color(0xFF072E1B), // Vert sombre profond
                    Color(0xFF03190E), // Obsidienne verte spectrale
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                border: Border.all(
                  color: const Color(0xFF34D399).withValues(alpha: 0.80), // Liseré émeraude spectrale runique
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.35), // Halo vert spectral
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 7,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: borderRadius,
                  onTap: gameState.isLoading ? null : onJoin,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            // Icône thématique loup-garou (griffes / trace de loup)
                            Icon(
                              Icons.pets_rounded,
                              color: Color(0xFF6EE7B7),
                              size: 13,
                            ),
                            SizedBox(width: 5),
                            Text(
                              'REJOINDRE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                                shadows: [
                                  Shadow(
                                    color: Colors.black,
                                    blurRadius: 4,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                          ],
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
    );
  }
}
