import 'package:flutter/material.dart';
import '../../models/game_role.dart';
import '../theme/lupus_theme.dart';
import 'bento_card.dart';
import 'role_card_image.dart';

/// Carte secrète du joueur avec fonction de masquage / révélation
class BentoRoleCard extends StatefulWidget {
  final GameRole role;
  final bool isAlive;
  final bool isCaptain;
  final bool isLover;
  final String? loverName;

  const BentoRoleCard({
    super.key,
    required this.role,
    this.isAlive = true,
    this.isCaptain = false,
    this.isLover = false,
    this.loverName,
  });

  @override
  State<BentoRoleCard> createState() => _BentoRoleCardState();
}

class _BentoRoleCardState extends State<BentoRoleCard> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final role = widget.role;
    final color = role.accentColor;

    return BentoCard(
      padding: const EdgeInsets.all(16),
      borderColor: _revealed ? color.withValues(alpha: 0.5) : LupusColors.border,
      gradient: LinearGradient(
        colors: [
          _revealed ? color.withValues(alpha: 0.18) : LupusColors.surfaceLight.withValues(alpha: 0.3),
          LupusColors.surface,
        ],
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    _revealed ? role.icon : Icons.lock_outline_rounded,
                    color: _revealed ? color : LupusColors.textMuted,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'VOTRE RÔLE SECRET',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: _revealed ? color : LupusColors.textSecondary,
                    ),
                  ),
                ],
              ),
              // Bouton pour afficher/masquer
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => setState(() => _revealed = !_revealed),
                icon: Icon(
                  _revealed ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  size: 20,
                  color: LupusColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (_revealed) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Illustration officielle de la carte (LOUP GAROU ENHANCED)
                GestureDetector(
                  onTap: () => _showFullCardDialog(context, role),
                  child: Hero(
                    tag: 'role_card_${role.name}',
                    child: RoleCardImage(
                      role: role,
                      width: 72,
                      height: 100,
                      fit: BoxFit.cover,
                      showGlow: true,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        role.displayName,
                        style: TextStyle(
                          fontFamily: 'serif',
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (role.isEvil ? LupusColors.arcaneCrimson : LupusColors.arcaneCyan)
                              .withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: (role.isEvil ? LupusColors.arcaneCrimson : LupusColors.arcaneCyan)
                                .withValues(alpha: 0.5),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          role.isEvil ? 'CAMP DES LOUPS' : 'CAMP DU VILLAGE',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: role.isEvil ? LupusColors.arcaneCrimson : LupusColors.arcaneCyan,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        role.description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: LupusColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (widget.isCaptain) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.5)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.military_tech_rounded, size: 14, color: Color(0xFFFFD700)),
                    SizedBox(width: 5),
                    Text(
                      'CAPITAINE DU VILLAGE (VOTE DOUBLE)',
                      style: TextStyle(
                        color: Color(0xFFFFD700),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (widget.isLover) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: LupusColors.bloodRed.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: LupusColors.bloodRed.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.favorite_rounded, size: 14, color: LupusColors.bloodRed),
                    const SizedBox(width: 5),
                    Text(
                      widget.loverName != null
                          ? 'LIÉ PAR AMOUR À ${widget.loverName!.toUpperCase()}'
                          : 'LIÉ PAR AMOUR',
                      style: const TextStyle(
                        color: LupusColors.bloodRed,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ] else ...[
            GestureDetector(
              onTap: () => setState(() => _revealed = true),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: LupusColors.surfaceElevated.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: LupusColors.border,
                    style: BorderStyle.solid,
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.touch_app_rounded, size: 18, color: LupusColors.textMuted),
                    SizedBox(width: 8),
                    Text(
                      'Toucher pour révéler discrètement',
                      style: TextStyle(
                        fontSize: 13,
                        color: LupusColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showFullCardDialog(BuildContext context, GameRole role) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Hero(
              tag: 'role_card_${role.name}',
              child: RoleCardImage(
                role: role,
                width: 280,
                height: 420,
                fit: BoxFit.contain,
                showGlow: true,
              ),
            ),
            const SizedBox(height: 14),
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: const Color(0x9912182E),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              icon: const Icon(Icons.close_rounded, size: 18),
              label: const Text('Fermer', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}
