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
      LupusAudioManager.instance.pauseLobbyMusic();
    } else if (state == AppLifecycleState.resumed) {
      if (ref.read(gameNotifierProvider).room == null) {
        LupusAudioManager.instance.playLobbyMusic();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    LupusAudioManager.instance.stopLobbyMusic();
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<LupusGameState>(gameNotifierProvider, (previous, next) {
      if (next.room == null) {
        LupusAudioManager.instance.playLobbyMusic();
      } else {
        LupusAudioManager.instance.stopLobbyMusic();
      }
    });

    final gameState = ref.watch(gameNotifierProvider);
    final room = gameState.room;

    // Navigation automatique vers l'arène dès que la partie commence
    if (room != null && room.phase != GamePhase.lobby) {
      if (!_isNavigatingToArena) {
        _isNavigatingToArena = true;
        LupusAudioManager.instance.stopLobbyMusic();
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
    final isLandscape = screenSize.width > screenSize.height;

    // Calcul réactif et précis de l'échelle d'affichage de l'image de fond (704 x 1470)
    // L'image de fond est rendue en plein écran avec BoxFit.cover et Alignment.topCenter.
    final scale = math.max(screenSize.width / 704.0, screenSize.height / 1470.0);
    // Le bas du cadre de pierre du loup-garou se termine à y = 774 dans l'image 704x1470.
    final wolfFrameBottom = 774.0 * scale;

    // Espace au-dessus des cartes :
    // - En mode portrait : démarre harmonieusement juste sous le cadre du loup (+ marge esthétique de 10dp).
    // - En mode paysage ou écrans courts : s'adapte automatiquement pour que tout reste visible et accessible.
    final topSpacing = isLandscape
        ? 16.0
        : (wolfFrameBottom + 10.0).clamp(80.0, screenSize.height * 0.65);

    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Image d'arrière-plan en plein écran avec BoxFit.cover (garantit 0 vide noir)
          Positioned.fill(
            child: Image.asset(
              LupusAssets.lobbyFantasyBgAsset,
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
              ),
            ),
          ),

          // 3. Bouton sélecteur de langue dans le bandeau supérieur (position fixe calquée sur le modèle français)
          Positioned(
            left: 18,
            top: (media.padding.top > 0 ? media.padding.top : 24) + 6,
            child: GestureDetector(
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
          ),

          // 4. Indicateur / Badge DEV-MOD si l'Admin est activé (position fixe droite)
          if (gameState.isAdmin)
            Positioned(
              right: 18,
              top: (media.padding.top > 0 ? media.padding.top : 24) + 6,
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
                        'DEV-MOD',
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
              top: (media.padding.top > 0 ? media.padding.top : 24) + 160,
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
          Positioned.fill(
            child: SafeArea(
              top: false,
              bottom: true,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(height: topSpacing),
                          if (_availableUpdate != null) ...[
                            _buildUpdateBanner(context, _availableUpdate!),
                            const SizedBox(height: 12),
                          ],
                          _buildPlayerNameCard(gameState),
                          const SizedBox(height: 12),
                          _buildActionPanel(gameState),
                          const SizedBox(height: 24),
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
    );
  }

  /// Bandeau interactif moderne et élégant indiquant qu'une nouvelle version est disponible
  Widget _buildUpdateBanner(BuildContext context, AppUpdateInfo info) {
    final mb = (info.fileSize / (1024 * 1024)).toStringAsFixed(1);
    return GestureDetector(
      onTap: () => AppUpdateDialog.show(context, info),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xE61E1B4B), // Indigo dark
              Color(0xE6064E3B), // Emerald dark
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFF10B981).withValues(alpha: 0.85),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withValues(alpha: 0.35),
              blurRadius: 16,
              spreadRadius: 1,
            ),
            const BoxShadow(
              color: Colors.black87,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.20),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF10B981), width: 1.5),
              ),
              child: const Icon(
                Icons.system_update_rounded,
                color: Color(0xFF34D399),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Mise à jour v${info.version} disponible !',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'NOUVEAU',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Touchez pour installer (${mb != '0.0' ? '$mb Mo' : 'APK'})',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.80),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white30),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Installer',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 1. Carte native semi-transparente "Nom de joueur"
  Widget _buildPlayerNameCard(LupusGameState gameState) {
    return Container(
      margin: EdgeInsets.zero,
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
                Text(
                  context.tr('player_name'),
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                Text(
                  context.tr('language') == 'العربية'
                      ? 'المس لتغيير الصورة'
                      : (context.tr('language') == 'English'
                          ? 'Tap avatar to change'
                          : 'Toucher l\'avatar pour changer'),
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
                  child: () {
                    final avatarItem = LupusAvatars.getByIndex(gameState.currentUserAvatar);
                    return Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: avatarItem.gradientColors,
                        ),
                        border: Border.all(
                          color: avatarItem.borderColor,
                          width: 1.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: avatarItem.glowColor,
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          avatarItem.icon,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    );
                  }(),
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
                    decoration: InputDecoration(
                      hintText: context.tr('name_hint'),
                      hintStyle: const TextStyle(
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
  /// Réduit de 15%, bouton rejoindre ambre #F7B831, police 10 et label 'REJOINDRE'
  Widget _buildActionPanel(LupusGameState gameState) {
    return Container(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0B1E).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF6B4A8E).withValues(alpha: 0.7),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.20),
            blurRadius: 16,
            spreadRadius: 1,
          ),
          const BoxShadow(
            color: Colors.black87,
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // GAUCHE : Bouton "CRÉER UN SALON" (Améthyste Somptueux)
            Expanded(
              flex: 13,
              child: MedievalFantasyButton.amethyst(
                onTap: gameState.isLoading
                    ? null
                    : () => ref.read(gameNotifierProvider.notifier).createRoom(),
                enabled: !gameState.isLoading,
                borderRadius: 14,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Croix / Sceau runique doré et lumineux (format compact -15%)
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFA855F7).withValues(alpha: 0.85),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            '᛭',
                            style: TextStyle(
                              color: Color(0xFFF5E8FF),
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (gameState.isLoading)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.0,
                            color: Color(0xFFE9D5FF),
                          ),
                        )
                      else ...[
                        Text(
                          context.tr('create_room').toUpperCase(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                            shadows: [
                              Shadow(
                                color: Colors.black,
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.tr('become_host'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFD8B4FE),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(width: 6),

            // DROITE : Zone Code & Rejoindre (empilés)
            Expanded(
              flex: 11,
              child: Column(
                children: [
                  // Champ "CODE" dans le bouton Ardoise/Pierre taillée
                  Expanded(
                    child: MedievalFantasyButton.stone(
                      borderRadius: 10,
                      child: Center(
                        child: TextField(
                          controller: _codeController,
                          textAlign: TextAlign.center,
                          textCapitalization: TextCapitalization.characters,
                          maxLength: 8,
                          cursorColor: const Color(0xFFA855F7),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                            shadows: [
                              Shadow(
                                color: Colors.black87,
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          decoration: InputDecoration(
                            hintText: context.tr('enter_room_code').toUpperCase(),
                            hintStyle: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                            counterText: '',
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          ),
                          onSubmitted: (_) => _handleJoinOrAdmin(),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 4),

                  // Bouton "REJOINDRE" (Ambre / Or Éclatant F7B831 Biseauté)
                  Expanded(
                    child: MedievalFantasyButton.amber(
                      onTap: gameState.isLoading ? null : _handleJoinOrAdmin,
                      enabled: !gameState.isLoading,
                      borderRadius: 10,
                      child: const Center(
                        child: Text(
                          'REJOINDRE',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
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
