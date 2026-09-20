import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Secousse d'écran physique brève avec amortissement (Screen Shake)
class ScreenShakeWrapper extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const ScreenShakeWrapper({
    super.key,
    required this.animation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, c) {
        final val = animation.value;
        if (val == 0.0) return c!;
        // Oscillation sinusoïdale amortie multi-axes
        final dx = math.sin(val * math.pi * 6.0) * (1.0 - val) * 9.0;
        final dy = math.cos(val * math.pi * 4.0) * (1.0 - val) * 5.0;
        return Transform.translate(
          offset: Offset(dx, dy),
          child: c,
        );
      },
      child: RepaintBoundary(child: child),
    );
  }
}

/// Flash d'impact visuel sur la cible abattue par le Chasseur (500ms)
class HunterImpactEffect extends StatefulWidget {
  final double size;
  final VoidCallback? onCompleted;

  const HunterImpactEffect({
    super.key,
    required this.size,
    this.onCompleted,
  });

  @override
  State<HunterImpactEffect> createState() => _HunterImpactEffectState();
}

class _HunterImpactEffectState extends State<HunterImpactEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );

    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.0), weight: 15),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.9), weight: 25),
      TweenSequenceItem(tween: Tween<double>(begin: 0.9, end: 0.0), weight: 60),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward().then((_) {
      if (mounted) {
        widget.onCompleted?.call();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final scale = _scaleAnimation.value;
            final opacity = _opacityAnimation.value;

            return Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: scale,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Onde de choc d'impact éclatante
                    Container(
                      width: widget.size * 1.3,
                      height: widget.size * 1.3,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFEF4444),
                          width: 2.5,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0xFFFF0033),
                            blurRadius: 18,
                            spreadRadius: 4,
                          ),
                          BoxShadow(
                            color: Color(0xFFFFFFFF),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    // Réticule d'impact
                    const Text(
                      '🎯',
                      style: TextStyle(
                        fontSize: 16,
                        shadows: [
                          Shadow(color: Color(0xFFFF0033), blurRadius: 12),
                        ],
                      ),
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
}

/// Éclatement / propagation radiale de flammes luminescentes du Pyromane (750ms)
class PyroFlameBurstEffect extends StatefulWidget {
  final double size;
  final VoidCallback? onCompleted;

  const PyroFlameBurstEffect({
    super.key,
    required this.size,
    this.onCompleted,
  });

  @override
  State<PyroFlameBurstEffect> createState() => _PyroFlameBurstEffectState();
}

class _PyroFlameBurstEffectState extends State<PyroFlameBurstEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _burstScale;
  late final Animation<double> _burstOpacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );

    _burstScale = Tween<double>(begin: 0.5, end: 2.3).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutExpo),
    );

    _burstOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.0), weight: 10),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.7), weight: 35),
      TweenSequenceItem(tween: Tween<double>(begin: 0.7, end: 0.0), weight: 55),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward().then((_) {
      if (mounted) {
        widget.onCompleted?.call();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final scale = _burstScale.value;
            final opacity = _burstOpacity.value.clamp(0.0, 1.0);

            return Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: scale,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // Onde de choc thermique radiale
                    Container(
                      width: widget.size * 1.5,
                      height: widget.size * 1.5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFFFFFBEB).withValues(alpha: 0.9),
                            const Color(0xFFF59E0B).withValues(alpha: 0.75),
                            const Color(0xFFEF4444).withValues(alpha: 0.5),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.35, 0.75, 1.0],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF97316).withValues(alpha: 0.9),
                            blurRadius: 20,
                            spreadRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    // Flammes incandescentes en expansion
                    const Text(
                      '🔥',
                      style: TextStyle(
                        fontSize: 18,
                        shadows: [
                          Shadow(color: Color(0xFFF97316), blurRadius: 16),
                        ],
                      ),
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
}

/// Halo pulsant fluide en fondu (fade + pulse glow) pour les joueurs charmés par la Flûte
class CharmedPulsingHalo extends StatefulWidget {
  final double size;
  final Widget? child;

  const CharmedPulsingHalo({
    super.key,
    required this.size,
    this.child,
  });

  @override
  State<CharmedPulsingHalo> createState() => _CharmedPulsingHaloState();
}

class _CharmedPulsingHaloState extends State<CharmedPulsingHalo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOutSine,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, c) {
          final t = _pulseAnimation.value;
          final glowOpacity = 0.35 + 0.55 * t;
          final blur = 10.0 + 8.0 * t;
          final spread = 1.5 + 2.5 * t;

          return Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF38BDF8).withValues(alpha: glowOpacity),
                  blurRadius: blur,
                  spreadRadius: spread,
                ),
                BoxShadow(
                  color: const Color(0xFFA855F7).withValues(alpha: glowOpacity * 0.5),
                  blurRadius: blur * 1.3,
                  spreadRadius: spread * 1.2,
                ),
              ],
            ),
            child: c,
          );
        },
        child: widget.child,
      ),
    );
  }
}
