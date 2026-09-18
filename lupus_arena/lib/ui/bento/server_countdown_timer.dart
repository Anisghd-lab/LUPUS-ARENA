import 'dart:math';
import 'package:flutter/material.dart';

import '../../services/server_time_service.dart';
import '../theme/lupus_theme.dart';

/// Widget d'affichage réactif du compte à rebours de phase
/// Fonction PURE du temps serveur Firebase RTDB :
/// remaining = max(0, phaseEndsAt - currentServerEstimatedTime)
///
/// Aucun Timer persistant dans le build(), aucune dépendance au thread de l'hôte,
/// immunisé contre le Doze mode, les mises en veille et les re-renders intempestifs.
class ServerCountdownTimerBadge extends StatefulWidget {
  final int? phaseEndsAt;
  final int fallbackSeconds;
  final bool isNight;
  final VoidCallback? onTimerExpired;
  final ValueChanged<int>? onTick;

  const ServerCountdownTimerBadge({
    super.key,
    required this.phaseEndsAt,
    this.fallbackSeconds = 30,
    required this.isNight,
    this.onTimerExpired,
    this.onTick,
  });

  @override
  State<ServerCountdownTimerBadge> createState() => _ServerCountdownTimerBadgeState();
}

class _ServerCountdownTimerBadgeState extends State<ServerCountdownTimerBadge> {
  late Stream<int> _timeStream;
  int _lastDispatchedSecond = -1;
  bool _expiredCalled = false;

  @override
  void initState() {
    super.initState();
    _initStream();
  }

  @override
  void didUpdateWidget(covariant ServerCountdownTimerBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.phaseEndsAt != widget.phaseEndsAt ||
        oldWidget.fallbackSeconds != widget.fallbackSeconds) {
      _expiredCalled = false;
      _initStream();
    }
  }

  void _initStream() {
    _lastDispatchedSecond = -1;
    _timeStream = ServerTimeService().streamRemainingSeconds(
      widget.phaseEndsAt,
      fallbackSeconds: widget.fallbackSeconds,
    );
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: StreamBuilder<int>(
        stream: _timeStream,
        initialData: ServerTimeService().calculateRemainingSeconds(
          widget.phaseEndsAt,
          fallbackSeconds: widget.fallbackSeconds,
        ),
        builder: (context, snapshot) {
          final remainingSeconds = max(0, snapshot.data ?? 0);

          // Notification de tick et d'expiration asynchrone
          if (remainingSeconds != _lastDispatchedSecond) {
            _lastDispatchedSecond = remainingSeconds;
            if (widget.onTick != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) widget.onTick!(remainingSeconds);
              });
            }
          }

          if (remainingSeconds <= 0 && !_expiredCalled) {
            _expiredCalled = true;
            if (widget.onTimerExpired != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) widget.onTimerExpired!();
              });
            }
          }

          final isUrgent = remainingSeconds <= 10;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: isUrgent
                  ? const Color(0xE0380B0B)
                  : const Color(0xE005070F),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isUrgent
                    ? LupusColors.arcaneCrimson
                    : LupusColors.arcaneGold.withValues(alpha: 0.5),
                width: isUrgent ? 1.6 : 1.0,
              ),
              boxShadow: isUrgent
                  ? LupusTheme.glowCrimson(opacity: 0.6)
                  : LupusTheme.glowGold(opacity: 0.25),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isUrgent ? '⏳' : (widget.isNight ? '🌙' : '☀️'),
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(width: 7),
                Text(
                  '${remainingSeconds}s',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                    color: isUrgent
                        ? const Color(0xFFFFA4A4)
                        : LupusColors.arcaneGold,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Constructeur réactif générique basé sur le temps serveur
class ServerCountdownBuilder extends StatefulWidget {
  final int? phaseEndsAt;
  final int fallbackSeconds;
  final Widget Function(BuildContext context, int remainingSeconds) builder;
  final VoidCallback? onTimerExpired;

  const ServerCountdownBuilder({
    super.key,
    required this.phaseEndsAt,
    this.fallbackSeconds = 30,
    required this.builder,
    this.onTimerExpired,
  });

  @override
  State<ServerCountdownBuilder> createState() => _ServerCountdownBuilderState();
}

class _ServerCountdownBuilderState extends State<ServerCountdownBuilder> {
  late Stream<int> _stream;
  bool _expiredCalled = false;

  @override
  void initState() {
    super.initState();
    _stream = ServerTimeService().streamRemainingSeconds(
      widget.phaseEndsAt,
      fallbackSeconds: widget.fallbackSeconds,
    );
  }

  @override
  void didUpdateWidget(covariant ServerCountdownBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.phaseEndsAt != widget.phaseEndsAt ||
        oldWidget.fallbackSeconds != widget.fallbackSeconds) {
      _expiredCalled = false;
      _stream = ServerTimeService().streamRemainingSeconds(
        widget.phaseEndsAt,
        fallbackSeconds: widget.fallbackSeconds,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _stream,
      initialData: ServerTimeService().calculateRemainingSeconds(
        widget.phaseEndsAt,
        fallbackSeconds: widget.fallbackSeconds,
      ),
      builder: (context, snapshot) {
        final remaining = max(0, snapshot.data ?? 0);
        if (remaining <= 0 && !_expiredCalled) {
          _expiredCalled = true;
          if (widget.onTimerExpired != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) widget.onTimerExpired!();
            });
          }
        }
        return widget.builder(context, remaining);
      },
    );
  }
}
