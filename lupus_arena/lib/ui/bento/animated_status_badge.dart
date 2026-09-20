import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Throttler pour éviter la saturation du moteur haptique lors du montage simultané de badges multiples.
class HapticThrottler {
  static int _lastHapticTimestamp = 0;
  static const int minIntervalMs = 120;

  static void selectionClickThrottled() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastHapticTimestamp >= minIntervalMs) {
      _lastHapticTimestamp = now;
      HapticFeedback.selectionClick();
    }
  }
}

/// Micro-animation d'entrée douce (ScaleTransition + FadeIn, 280ms)
/// accompagnée d'un retour haptique léger pour l'apparition des badges de statut.
class AnimatedStatusBadge extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final bool enableHaptic;

  const AnimatedStatusBadge({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 280),
    this.enableHaptic = true,
  });

  @override
  State<AnimatedStatusBadge> createState() => _AnimatedStatusBadgeState();
}

class _AnimatedStatusBadgeState extends State<AnimatedStatusBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _scaleAnimation = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    _controller.forward();

    if (widget.enableHaptic) {
      // Retour haptique léger et throttlé pour prévenir la congestion de la file haptique
      HapticThrottler.selectionClickThrottled();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: widget.child,
        ),
      ),
    );
  }
}
