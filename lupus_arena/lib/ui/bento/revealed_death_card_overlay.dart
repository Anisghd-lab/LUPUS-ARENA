import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../models/game_role.dart';
import '../theme/lupus_theme.dart';
import 'role_card_image.dart';

/// Modèle représentant un événement d'annonce de mort pour la file d'attente cinématique.
class DeathAnnouncementEvent {
  final String playerId;
  final String playerName;
  final GameRole role;
  final String cause;
  final int timestamp;

  const DeathAnnouncementEvent({
    required this.playerId,
    required this.playerName,
    required this.role,
    required this.cause,
    this.timestamp = 0,
  });

  String get key => '${playerId}_${cause}_$timestamp';

  String get causeLabel {
    switch (cause.toUpperCase()) {
      case 'MORSURE_LOUPS':
        return 'Morsure des Loups';
      case 'POISON_SORCIERE':
        return 'Poison de la Sorcière';
      case 'VOTE_VILLAGE':
        return 'Sentence du Bûcher';
      case 'CHASSEUR':
      case 'TIR_CHASSEUR':
        return 'Tir du Chasseur';
      case 'AMOUREUX':
      case 'CHAGRIN':
        return 'Mort de Chagrin';
      default:
        return 'Élimination';
    }
  }

  IconData get causeIcon {
    switch (cause.toUpperCase()) {
      case 'MORSURE_LOUPS':
        return Icons.pets_rounded;
      case 'POISON_SORCIERE':
        return Icons.science_rounded;
      case 'VOTE_VILLAGE':
        return Icons.local_fire_department_rounded;
      case 'CHASSEUR':
      case 'TIR_CHASSEUR':
        return Icons.track_changes_rounded;
      case 'AMOUREUX':
      case 'CHAGRIN':
        return Icons.favorite_rounded;
      default:
        return Icons.dangerous_rounded;
    }
  }

  Color get causeColor {
    switch (cause.toUpperCase()) {
      case 'MORSURE_LOUPS':
        return const Color(0xFFEF4444);
      case 'POISON_SORCIERE':
        return const Color(0xFFA855F7);
      case 'VOTE_VILLAGE':
        return const Color(0xFFF97316);
      case 'CHASSEUR':
      case 'TIR_CHASSEUR':
        return const Color(0xFFEAB308);
      case 'AMOUREUX':
      case 'CHAGRIN':
        return const Color(0xFFEC4899);
      default:
        return const Color(0xFF94A3B8);
    }
  }

  factory DeathAnnouncementEvent.fromMap(Map<dynamic, dynamic> map) {
    return DeathAnnouncementEvent(
      playerId: (map['joueurId'] ?? map['playerId'] ?? '').toString(),
      playerName: (map['nom'] ?? map['playerName'] ?? 'Inconnu').toString(),
      role: GameRole.fromString(map['role']?.toString()),
      cause: (map['cause'] ?? 'MORSURE_LOUPS').toString(),
      timestamp: (map['timestamp'] is int)
          ? map['timestamp'] as int
          : (int.tryParse(map['timestamp']?.toString() ?? '0') ?? 0),
    );
  }
}

/// Séquence cinématique 3D de révélation des défunts au centre de la table mystique.
///
/// Spécifications & Anti-bouclage Firebase :
/// 1. Confinement strict au centre du cercle pour ne jamais masquer les pastilles/avatars.
/// 2. Traitement FIFO séquentiel avec traçabilité stricte des clés déjà affichées ([_playedKeys]).
/// 3. Les snapshots et updates Firebase (speakerId, audio Agora) ne relancent JAMAIS les cartes déjà jouées.
/// 4. Animation de retournement 3D (0° à 180°) avec perspective (setEntry(3, 2, 0.002)).
/// 5. Temporisation d'exposition de 2.5 secondes par carte (3.5s durée totale par mort).
/// 6. Disparition fluide et clôture définitive via [onSequenceCompleted] dès épuisement de la file.
class RevealedDeathCardOverlay extends StatefulWidget {
  final List<DeathAnnouncementEvent> queue;
  final VoidCallback? onSequenceCompleted;
  final VoidCallback? onCompleted;
  final dynamic event;

  const RevealedDeathCardOverlay({
    super.key,
    List<DeathAnnouncementEvent>? queue,
    this.onSequenceCompleted,
    this.onCompleted,
    this.event,
  }) : queue = queue ?? const [];

  @override
  State<RevealedDeathCardOverlay> createState() =>
      _RevealedDeathCardOverlayState();
}

class _RevealedDeathCardOverlayState extends State<RevealedDeathCardOverlay>
    with TickerProviderStateMixin {
  final List<DeathAnnouncementEvent> _pendingQueue = [];
  final Set<String> _playedKeys = {};
  DeathAnnouncementEvent? _currentEvent;

  // Contrôleurs d'animation pour le cycle de vie de chaque carte
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  late AnimationController _exitController;
  late Animation<double> _exitFadeAnimation;
  late Animation<double> _exitScaleAnimation;

  Timer? _freezeTimer;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    if (widget.event != null) {
      final ev = widget.event;
      final deathEvent = DeathAnnouncementEvent(
        playerId: ev.joueurId?.toString() ?? '',
        playerName: ev.nomJoueur?.toString() ?? '',
        role: GameRole.fromString(ev.roleOriginal?.toString()),
        cause: ev.causeMort?.toString() ?? 'VOTE_VILLAGE',
      );
      if (deathEvent.playerId.isNotEmpty) {
        _pendingQueue.add(deathEvent);
      }
    } else {
      final seenIds = <String>{};
      for (final ev in widget.queue) {
        if (ev.playerId.isNotEmpty && seenIds.add(ev.playerId)) {
          _pendingQueue.add(ev);
        }
      }
    }

    // 1. Retournement 3D (0° -> 180°) en 700ms avec courbe fluide
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _flipAnimation = Tween<double>(begin: 0.0, end: math.pi).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutCubic),
    );

    // 2. Sortie (Fade out & scale down) en 280ms
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _exitFadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeInQuad),
    );
    _exitScaleAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeInQuad),
    );

    _flipController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // La carte est à 180° : Démarrage du gel d'exposition de 2.5 secondes
        _startTwoSecondsFreeze();
      }
    });

    _exitController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // La carte s'est effacée : passer à la suivante dans la file
        _advanceQueue();
      }
    });

    // Lancer la première carte de la file
    _playNextCard();
  }

  @override
  void didUpdateWidget(RevealedDeathCardOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Filtrage strict : Ne JAMAIS réinjecter les défunts déjà joués ou en cours de lecture
    for (final ev in widget.queue) {
      final isAlreadyHandled = _playedKeys.contains(ev.key) ||
          _playedKeys.contains(ev.playerId) ||
          _pendingQueue.any((e) => e.playerId == ev.playerId) ||
          (_currentEvent?.playerId == ev.playerId);
      if (!isAlreadyHandled && ev.playerId.isNotEmpty) {
        _pendingQueue.add(ev);
      }
    }
    if (_currentEvent == null && _pendingQueue.isNotEmpty) {
      _playNextCard();
    }
  }

  void _playNextCard() {
    if (_pendingQueue.isEmpty) {
      if (mounted) {
        setState(() {
          _currentEvent = null;
        });
        widget.onSequenceCompleted?.call();
        widget.onCompleted?.call();
      }
      return;
    }

    final nextEvent = _pendingQueue.removeAt(0);
    _playedKeys.add(nextEvent.key);
    _playedKeys.add(nextEvent.playerId);

    setState(() {
      _currentEvent = nextEvent;
    });

    _exitController.reset();
    _flipController.forward(from: 0.0);
  }

  void _startTwoSecondsFreeze() {
    _freezeTimer?.cancel();
    // Temporisation de 2.5 secondes pour une lecture claire et posée
    _freezeTimer = Timer(const Duration(milliseconds: 2500), () {
      if (_isDisposed || !mounted) return;
      _exitController.forward(from: 0.0);
    });
  }

  void _advanceQueue() {
    if (_isDisposed || !mounted) return;
    _playNextCard();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _freezeTimer?.cancel();
    _flipController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentEvent == null) {
      return const SizedBox.shrink();
    }

    final event = _currentEvent!;
    const double cardWidth = 70.0;
    const double cardHeight = 84.0;
    const double maxContainerWidth = 92.0;
    const double maxContainerHeight = 138.0;

    return Center(
      child: Container(
        key: const Key('death_card_container'),
        constraints: const BoxConstraints(
          maxWidth: maxContainerWidth,
          maxHeight: maxContainerHeight,
        ),
        child: AnimatedBuilder(
          animation: Listenable.merge([_flipAnimation, _exitController]),
          builder: (context, _) {
            final angle = _flipAnimation.value;
            final isFront = angle >= (math.pi / 2);
            final fade = _exitFadeAnimation.value;
            final scale = _exitScaleAnimation.value;

            return Opacity(
              opacity: fade,
              child: Transform.scale(
                scale: scale,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // CARTE 3D AVEC EFFET FLIP ET PERSPECTIVE
                    Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.002) // Perspective 3D
                        ..rotateY(angle),
                      child: isFront
                          ? Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()..rotateY(math.pi), // Inverse pour affichage à l'endroit
                              child: _buildCardFront(event, cardWidth, cardHeight),
                            )
                          : _buildCardBack(cardWidth, cardHeight),
                    ),

                    const SizedBox(height: 4),

                    // INFORMATIONS DU DÉFUNT (Visibles dès que la face est révélée)
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: isFront ? 1.0 : 0.0,
                      child: _buildVictimInfo(event, maxContainerWidth),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Face arrière : Dos de carte mystique (FOND officiel ou assets/cards/card_back.png)
  Widget _buildCardBack(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: LupusColors.arcanePurple.withValues(alpha: 0.6),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: LupusColors.arcanePurple.withValues(alpha: 0.35),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Image.asset(
          'assets/cards/card_back.png',
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // Fallback 1 : FOND officiel de LOUP GAROU ENHANCED
            return Image.asset(
              'LOUP GAROU ENHANCED/FOND.jpg',
              width: width,
              height: height,
              fit: BoxFit.cover,
              errorBuilder: (ctx, err, st) {
                // Fallback 2 : Sceau arcanique procédural
                return Container(
                  width: width,
                  height: height,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1E1035), Color(0xFF0D061A)],
                    ),
                  ),
                  child: Center(
                    child: Image.asset(
                      'assets/images/lupus_seal.png',
                      width: 42,
                      height: 42,
                      errorBuilder: (c, e, s) => const Icon(
                        Icons.shield_moon_rounded,
                        color: LupusColors.arcanePurple,
                        size: 36,
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  /// Face avant : Rôle d'origine révélé avec halo adapté au camp
  Widget _buildCardFront(
    DeathAnnouncementEvent event,
    double width,
    double height,
  ) {
    final role = event.role;
    final accentColor = role.isEvil ? LupusColors.arcaneCrimson : role.accentColor;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.85),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.45),
            blurRadius: 14,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Illustration officielle du rôle (LOUP GAROU ENHANCED ou assets/cards/)
            RoleCardImage(
              role: role,
              width: width,
              height: height,
              showBorder: false,
              fit: BoxFit.cover,
            ),

            // Filtre dégradé subtil en bas pour lisibilité
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: 24,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.75),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Section d'informations typographiques compactes sous la carte
  Widget _buildVictimInfo(DeathAnnouncementEvent event, double maxWidth) {
    return Container(
      width: maxWidth,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Nom du joueur
          Text(
            event.playerName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 0.3,
              shadows: [
                Shadow(color: Colors.black, blurRadius: 6),
              ],
            ),
          ),

          const SizedBox(height: 1),

          // 2. Rôle d'origine révélé
          Text(
            event.role.displayNameFr,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: event.role.isEvil
                  ? const Color(0xFFFCA5A5)
                  : LupusColors.arcaneGold,
              shadows: const [
                Shadow(color: Colors.black, blurRadius: 4),
              ],
            ),
          ),

          const SizedBox(height: 2),

          // 3. Badge Cause d'élimination compact
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: event.causeColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: event.causeColor.withValues(alpha: 0.5),
                width: 0.7,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  event.causeIcon,
                  size: 9,
                  color: event.causeColor,
                ),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    event.causeLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: event.causeColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
