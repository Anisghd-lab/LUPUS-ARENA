import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../AgoraVoiceService.dart';
import '../../GameNotifier.dart';
import '../../models/game_role.dart';
import '../../models/game_room.dart';
import '../../models/player_model.dart';
import '../../services/app_translations.dart';
import '../bento/bento_card.dart';
import '../bento/role_card_image.dart';
import '../theme/lupus_theme.dart';

/// Configuration visuelle du vainqueur
class VictoryThemeConfig {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color primaryColor;
  final Color secondaryColor;
  final List<BoxShadow> glowShadows;

  const VictoryThemeConfig({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.primaryColor,
    required this.secondaryColor,
    required this.glowShadows,
  });
}

/// Écran complet de Fin de Partie (« GameOver / Débriefing » de 60 secondes)
/// Respecte rigoureusement la charte graphique officielle de Lupus Arena (thème obsidienne, or, carmin, verre teinté).
class GameOverScreen extends ConsumerStatefulWidget {
  final GameRoom room;
  final LupusGameState gameState;

  const GameOverScreen({
    super.key,
    required this.room,
    required this.gameState,
  });

  @override
  ConsumerState<GameOverScreen> createState() => _GameOverScreenState();
}

class _GameOverScreenState extends ConsumerState<GameOverScreen>
    with SingleTickerProviderStateMixin {
  final AgoraVoiceService _voiceService = AgoraVoiceService();
  Timer? _debriefingTimer;
  int _secondsRemaining = 60;
  late AnimationController _bannerAnimController;
  late Animation<double> _bannerScaleAnimation;
  late Animation<double> _bannerGlowAnimation;

  @override
  void initState() {
    super.initState();

    // Animation cinématique d'apparition du bandeau vainqueur
    _bannerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _bannerScaleAnimation = CurvedAnimation(
      parent: _bannerAnimController,
      curve: Curves.easeOutBack,
    );

    _bannerGlowAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(
        parent: _bannerAnimController,
        curve: Curves.easeInOut,
      ),
    );

    _bannerAnimController.forward();

    // Démarrage du compte à rebours de 60 secondes
    _secondsRemaining = widget.room.timerSeconds > 0 && widget.room.timerSeconds <= 60
        ? widget.room.timerSeconds
        : 60;

    _startDebriefingTimer();

    // Rejoindre le salon vocal global pour tous les joueurs
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _joinGlobalVoiceChannel();
    });
  }

  void _startDebriefingTimer() {
    _debriefingTimer?.cancel();
    _debriefingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        timer.cancel();
        _onTimeExpired();
      }
    });
  }

  void _onTimeExpired() {
    // Redirection automatique vers le lobby à l'expiration des 60 secondes
    ref.read(gameNotifierProvider.notifier).leaveRoom();
  }

  Future<void> _joinGlobalVoiceChannel() async {
    final roomCode = widget.room.roomCode;
    final uid = widget.gameState.agoraUid;
    // Canal global ouvert à tous les UIDs (morts et vivants)
    final globalChannel = 'lupus_$roomCode';

    try {
      await _voiceService.joinChannel(
        channelId: globalChannel,
        uid: uid > 0 ? uid : null,
        initialMute: false,
      );
      // S'assurer que le son entrant est actif pour entendre tout le monde
      _voiceService.muteSpeaker(false);
    } catch (e) {
      debugPrint('[GameOverVoice] Erreur connexion canal global: $e');
    }
  }

  @override
  void dispose() {
    _debriefingTimer?.cancel();
    _bannerAnimController.dispose();
    super.dispose();
  }

  /// Détermine la configuration visuelle du camp vainqueur
  VictoryThemeConfig _resolveVictoryConfig(BuildContext context, String? winner) {
    final w = winner?.toLowerCase().trim() ?? '';

    if (w == 'werewolves' || w == 'wolves') {
      return VictoryThemeConfig(
        title: 'VICTOIRE DE LA MEUTE !',
        subtitle: 'Les loups ont dévoré Thiercelieux dans un bain de sang.',
        icon: Icons.pets_rounded,
        primaryColor: const Color(0xFFDC2626), // Rouge carmin
        secondaryColor: const Color(0xFF7F1D1D),
        glowShadows: [
          const BoxShadow(
            color: Color(0x99DC2626),
            blurRadius: 28,
            spreadRadius: 2,
          ),
          const BoxShadow(
            color: Color(0x667F1D1D),
            blurRadius: 40,
            spreadRadius: 4,
          ),
        ],
      );
    } else if (w == 'lovers') {
      return VictoryThemeConfig(
        title: 'VICTOIRE DES AMOUREUX !',
        subtitle: 'Leur passion triomphe de la mort et transcende toutes les allégeances.',
        icon: Icons.favorite_rounded,
        primaryColor: const Color(0xFFF43F5E), // Rose pourpre
        secondaryColor: const Color(0xFF881337),
        glowShadows: [
          const BoxShadow(
            color: Color(0x99F43F5E),
            blurRadius: 28,
            spreadRadius: 2,
          ),
        ],
      );
    } else if (w == 'piedpiper' || w == 'piper') {
      return VictoryThemeConfig(
        title: 'VICTOIRE DU JOUEUR DE FLÛTE !',
        subtitle: 'La mélodie mystique a subjugué la totalité des survivants.',
        icon: Icons.music_note_rounded,
        primaryColor: const Color(0xFFA855F7), // Violet spectral
        secondaryColor: const Color(0xFF581C87),
        glowShadows: [
          const BoxShadow(
            color: Color(0x99A855F7),
            blurRadius: 28,
            spreadRadius: 2,
          ),
        ],
      );
    } else if (w == 'whitewerewolf') {
      return VictoryThemeConfig(
        title: 'VICTOIRE DU LOUP BLANC !',
        subtitle: 'L\'unique bête solitaire a massacré meute et village sans pitié.',
        icon: Icons.nightlight_round,
        primaryColor: const Color(0xFFE2E8F0), // Blanc lune glacial
        secondaryColor: const Color(0xFF64748B),
        glowShadows: [
          const BoxShadow(
            color: Color(0xCCFFFFFF),
            blurRadius: 26,
            spreadRadius: 2,
          ),
          const BoxShadow(
            color: Color(0x6694A3B8),
            blurRadius: 36,
            spreadRadius: 3,
          ),
        ],
      );
    } else if (w == 'angel') {
      return VictoryThemeConfig(
        title: 'VICTOIRE DE L\'ANGE !',
        subtitle: 'Son martyre immaculé dès l\'aube lui ouvre les cieux divins.',
        icon: Icons.auto_awesome_rounded,
        primaryColor: const Color(0xFFF59E0B), // Or divin
        secondaryColor: const Color(0xFFB45309),
        glowShadows: [
          const BoxShadow(
            color: Color(0xAAF59E0B),
            blurRadius: 28,
            spreadRadius: 2,
          ),
        ],
      );
    } else if (w == 'pyromaniac' || w == 'pyro') {
      return VictoryThemeConfig(
        title: 'VICTOIRE DU PYROMANE !',
        subtitle: 'Le village entier n\'est plus qu\'un tas de cendres fumantes.',
        icon: Icons.local_fire_department_rounded,
        primaryColor: const Color(0xFFF97316), // Orange ardent
        secondaryColor: const Color(0xFF9A3412),
        glowShadows: [
          const BoxShadow(
            color: Color(0xAAF97316),
            blurRadius: 28,
            spreadRadius: 2,
          ),
        ],
      );
    } else if (w == 'abominablesectarian' || w == 'sectleader') {
      return VictoryThemeConfig(
        title: 'VICTOIRE DE LA SECTE !',
        subtitle: 'Les hérétiques ont été purgés sous le signe de l\'Abominable Sectaire.',
        icon: Icons.all_inclusive_rounded,
        primaryColor: const Color(0xFF10B981), // Vert sombre
        secondaryColor: const Color(0xFF064E3B),
        glowShadows: [
          const BoxShadow(
            color: Color(0xAA10B981),
            blurRadius: 26,
            spreadRadius: 2,
          ),
        ],
      );
    } else if (w == 'draw') {
      return VictoryThemeConfig(
        title: 'ÉGALITÉ FUNESTE !',
        subtitle: 'Aucun survivant n\'a réchappé au massacre. Le silence règne sur les ruines.',
        icon: Icons.balance_rounded,
        primaryColor: const Color(0xFF94A3B8), // Gris acier
        secondaryColor: const Color(0xFF334155),
        glowShadows: [
          const BoxShadow(
            color: Color(0x6694A3B8),
            blurRadius: 20,
            spreadRadius: 1,
          ),
        ],
      );
    } else {
      // Victoire par défaut : Village
      return VictoryThemeConfig(
        title: 'VICTOIRE DU VILLAGE !',
        subtitle: 'Les ténèbres ont été repoussées. Les villageois célèbrent la paix retrouvée.',
        icon: Icons.shield_rounded,
        primaryColor: const Color(0xFF06B6D4), // Cyan / Émeraude
        secondaryColor: const Color(0xFF0E7490),
        glowShadows: [
          const BoxShadow(
            color: Color(0xAA06B6D4),
            blurRadius: 28,
            spreadRadius: 2,
          ),
          const BoxShadow(
            color: Color(0x55F59E0B),
            blurRadius: 36,
            spreadRadius: 3,
          ),
        ],
      );
    }
  }

  /// Vérifie si un joueur fait partie du camp victorieux
  bool _isPlayerInWinningCamp(PlayerModel player, String? winner) {
    final w = winner?.toLowerCase().trim() ?? '';
    final role = player.trueOriginalRole;

    if (w == 'werewolves' || w == 'wolves') {
      return role.isEvil;
    } else if (w == 'lovers') {
      return player.isLover;
    } else if (w == 'piedpiper' || w == 'piper') {
      return role == GameRole.piedPiper;
    } else if (w == 'whitewerewolf') {
      return role == GameRole.whiteWerewolf;
    } else if (w == 'angel') {
      return role == GameRole.angel;
    } else if (w == 'pyromaniac' || w == 'pyro') {
      return role == GameRole.pyromaniac;
    } else if (w == 'abominablesectarian' || w == 'sectleader') {
      return role == GameRole.sectLeader;
    } else if (w == 'village' || w == 'villagers') {
      return !role.isEvil && !role.defaultTeam.isSolo;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final gameState = widget.gameState;
    final winner = room.winner;
    final victoryConfig = _resolveVictoryConfig(context, winner);
    final allPlayers = room.playerList;
    final totalPlayers = allPlayers.length;
    final readyCount = room.replayReadyCount;
    final isMeReady = room.isPlayerReadyReplay(gameState.currentUserId);
    final isHost = gameState.isHost;

    final minutes = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');
    final timeFormatted = '$minutes:$seconds';
    final progress = (_secondsRemaining / 60.0).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0612), // Obsidienne pure
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Arrière-plan gothique avec dégradés mystiques profonds
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.0, -0.4),
                  radius: 1.2,
                  colors: [
                    Color(0xFF1E1035), // Violet nuit profond
                    Color(0xFF120A24),
                    Color(0xFF0A0612), // Obsidienne
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // En-tête HUD avec Compte à Rebours 60s & Audio Bar
                _buildTopHeader(timeFormatted, progress),

                // Contenu scrollable : Bannière de Victoire + Tableau d'Honneur (Rôles & UIDs)
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Column(
                      children: [
                        // 2. BANNIÈRE CINÉMATIQUE DU VAINQUEUR
                        _buildCinematicVictoryBanner(victoryConfig),

                        const SizedBox(height: 16),

                        // 3. TABLEAU D'HONNEUR & RÉVÉLATION TOTALE DES RÔLES (par UID)
                        _buildHonorBoard(allPlayers, winner, gameState.currentUserId),

                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),

                // 4. BARRE INFÉRIEURE : BOUTON REJOUER & ACTIONS IMMÉDIATES
                _buildBottomActionDock(
                  context: context,
                  isMeReady: isMeReady,
                  readyCount: readyCount,
                  totalPlayers: totalPlayers,
                  isHost: isHost,
                  room: room,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// En-tête HUD avec Compte à Rebours doré et Contrôles Vocaux Globaux
  Widget _buildTopHeader(String timeFormatted, double progress) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Capsule de minuteur 60s (Design identique aux timers de phase)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xCC140E24), // Glassmorphism sombre
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.6), // Bordure dorée
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.timer_rounded,
                  color: Color(0xFFFBBF24),
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  timeFormatted,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: Color(0xFFFDE68A), // Or clair
                  ),
                ),
              ],
            ),
          ),

          // Titre central subtil
          const Row(
            children: [
              Icon(
                Icons.record_voice_over_rounded,
                color: Color(0xFF10B981),
                size: 16,
              ),
              SizedBox(width: 6),
              Text(
                'DÉBRIEFING VOCAL LIBRE',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: Color(0xFFCBD5E1),
                ),
              ),
            ],
          ),

          // Bouton flottant autonome de Microphone
          ValueListenableBuilder<bool>(
            valueListenable: _voiceService.isMuted,
            builder: (context, isMuted, _) {
              final micColor = isMuted ? const Color(0xFFEF4444) : const Color(0xFF10B981);

              return GestureDetector(
                onTap: () => _voiceService.toggleMute(),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xCC140E24),
                    border: Border.all(
                      color: micColor.withValues(alpha: 0.8),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: micColor.withValues(alpha: 0.35),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Icon(
                    isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    color: micColor,
                    size: 20,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// 2. Bandeau Cinématique Imposant du Vainqueur
  Widget _buildCinematicVictoryBanner(VictoryThemeConfig config) {
    return ScaleTransition(
      scale: _bannerScaleAnimation,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xE6160F2B), // Verre sombre teinté
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: config.primaryColor.withValues(alpha: 0.8),
            width: 1.8,
          ),
          boxShadow: config.glowShadows,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icône avec cercle radiant
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    config.primaryColor.withValues(alpha: 0.3),
                    config.secondaryColor.withValues(alpha: 0.1),
                  ],
                ),
                border: Border.all(
                  color: config.primaryColor.withValues(alpha: 0.6),
                  width: 1.5,
                ),
              ),
              child: Icon(
                config.icon,
                color: config.primaryColor,
                size: 36,
              ),
            ),
            const SizedBox(height: 12),

            // Titre Solennel de la Victoire
            Text(
              config.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'serif',
                fontSize: 21,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: config.primaryColor,
                shadows: [
                  Shadow(
                    color: config.primaryColor.withValues(alpha: 0.6),
                    blurRadius: 14,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Sous-titre narratif
            Text(
              config.subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFFCBD5E1),
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 3. Tableau d'Honneur : Révélation de tous les Rôles et UIDs
  Widget _buildHonorBoard(
    List<PlayerModel> players,
    String? winner,
    String currentUserId,
  ) {
    return BentoCard(
      borderColor: const Color(0xFFF59E0B).withValues(alpha: 0.35),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.workspace_premium_rounded,
                color: Color(0xFFF59E0B),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'TABLEAU D\'HONNEUR & RÔLES VÉRITABLES',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                  color: Color(0xFFFDE68A),
                ),
              ),
              const Spacer(),
              Text(
                '${players.length} Joueurs',
                style: const TextStyle(
                  fontSize: 11,
                  color: LupusColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Grille responsive des cartes joueurs (jusqu'à 16 joueurs)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: players.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.32,
            ),
            itemBuilder: (context, index) {
              final player = players[index];
              final isWinner = _isPlayerInWinningCamp(player, winner);
              final isMe = player.id == currentUserId;
              final originalRole = player.trueOriginalRole;
              final isDegraded = player.estDechu ||
                  (player.role == GameRole.simpleVillager &&
                      originalRole != GameRole.simpleVillager);

              return _buildPlayerHonorTile(
                player: player,
                originalRole: originalRole,
                isWinner: isWinner,
                isMe: isMe,
                isDegraded: isDegraded,
              );
            },
          ),
        ],
      ),
    );
  }

  /// Tuile individuelle pour un joueur révélé
  Widget _buildPlayerHonorTile({
    required PlayerModel player,
    required GameRole originalRole,
    required bool isWinner,
    required bool isMe,
    required bool isDegraded,
  }) {
    final borderColor = isWinner
        ? const Color(0xFFF59E0B) // Or pour les vainqueurs
        : (player.isAlive
            ? const Color(0x38A855F7)
            : const Color(0x22FFFFFF));

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isWinner
            ? const Color(0x26F59E0B)
            : const Color(0x99130D24), // Glassmorphism sombre
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
          width: isWinner ? 1.5 : 1.0,
        ),
        boxShadow: isWinner
            ? [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          // Carte miniature haute définition
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 48,
              height: 68,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  RoleCardImage(
                    role: originalRole,
                    showBorder: false,
                  ),
                  if (!player.isAlive)
                    Container(
                      color: Colors.black.withValues(alpha: 0.65),
                      child: const Center(
                        child: Text(
                          '💀',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Informations détaillées du joueur
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Nom + Badge Vainqueur / Vous
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        player.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: isMe ? const Color(0xFF38BDF8) : Colors.white,
                        ),
                      ),
                    ),
                    if (isWinner) ...[
                      const SizedBox(width: 4),
                      const Text('🏆', style: TextStyle(fontSize: 11)),
                    ],
                    if (player.isCaptain) ...[
                      const SizedBox(width: 3),
                      const Text('👑', style: TextStyle(fontSize: 10)),
                    ],
                    if (player.isLover) ...[
                      const SizedBox(width: 3),
                      const Text('💖', style: TextStyle(fontSize: 10)),
                    ],
                  ],
                ),
                const SizedBox(height: 3),

                // Rôle véritable révélé
                Text(
                  originalRole.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: originalRole.accentColor,
                  ),
                ),

                // Statut de déchéance (ex: Sorcière sans potions)
                if (isDegraded) ...[
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0x3364748B),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Rôle déchu ➔ Villageois',
                      style: TextStyle(
                        fontSize: 8,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],

                // Statut de survie
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: player.isAlive
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      player.isAlive ? 'Survivant' : 'Éliminé(e)',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: player.isAlive
                            ? const Color(0xFF10B981)
                            : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 4. Barre d'Action Inférieure (Boutons Rejouer & Quitter)
  Widget _buildBottomActionDock({
    required BuildContext context,
    required bool isMeReady,
    required int readyCount,
    required int totalPlayers,
    required bool isHost,
    required GameRoom room,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xF20E081A),
        border: Border(
          top: BorderSide(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
            width: 1.0,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Bouton Principal REJOUER (Or / Ambre Impérial)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isMeReady
                    ? const Color(0xFF10B981) // Vert émeraude validé
                    : const Color(0xFFD97706), // Or ambré
                foregroundColor: Colors.white,
                elevation: 6,
                shadowColor: const Color(0xFFF59E0B).withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: isMeReady
                        ? const Color(0xFF34D399)
                        : const Color(0xFFFBBF24),
                    width: 1.5,
                  ),
                ),
              ),
              icon: Icon(
                isMeReady ? Icons.check_circle_rounded : Icons.replay_rounded,
                size: 22,
                color: Colors.white,
              ),
              label: Text(
                isMeReady
                    ? 'PRÊT POUR LA REVANCHE ! ($readyCount/$totalPlayers)'
                    : 'REJOUER ($readyCount/$totalPlayers)',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
              onPressed: () {
                final uid = widget.gameState.currentUserId;
                final roomCode = room.roomCode;
                if (isMeReady) {
                  ref.read(gameNotifierProvider.notifier).playerCancelReplay(
                        userId: uid,
                        roomId: roomCode,
                      );
                } else {
                  ref.read(gameNotifierProvider.notifier).playerReadyReplay(
                        userId: uid,
                        roomId: roomCode,
                      );
                }
              },
            ),
          ),
          const SizedBox(height: 8),

          // Bouton secondaire Retour au Salon
          SizedBox(
            width: double.infinity,
            height: 40,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF94A3B8),
                side: BorderSide(
                  color: const Color(0x38A855F7).withValues(alpha: 0.5),
                  width: 1.0,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                ref.read(gameNotifierProvider.notifier).leaveRoom();
              },
              child: const Text(
                'Quitter l\'Arène / Retour au Menu',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
