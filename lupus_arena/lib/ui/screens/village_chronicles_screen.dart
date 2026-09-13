import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../GameNotifier.dart';
import '../bento/bento_card.dart';
import '../theme/lupus_theme.dart';

/// Page distincte et immersive dédiée aux Chroniques et événements du Village
class VillageChroniclesScreen extends ConsumerStatefulWidget {
  final List<String> logs;
  final String roomCode;

  const VillageChroniclesScreen({
    super.key,
    required this.logs,
    required this.roomCode,
  });

  static Future<void> show(BuildContext context, List<String> logs, String roomCode) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VillageChroniclesScreen(logs: logs, roomCode: roomCode),
      ),
    );
  }

  @override
  ConsumerState<VillageChroniclesScreen> createState() => _VillageChroniclesScreenState();
}

class _VillageChroniclesScreenState extends ConsumerState<VillageChroniclesScreen> {
  String _selectedFilter = 'Tous'; // 'Tous', 'Morts', 'Nuit', 'Débat', 'Pouvoirs'

  List<String> get _currentLogs {
    final liveRoom = ref.watch(gameNotifierProvider).room;
    return liveRoom?.logs ?? widget.logs;
  }

  List<String> get _filteredLogs {
    final reversed = _currentLogs.reversed.toList();
    if (_selectedFilter == 'Tous') return reversed;

    return reversed.where((log) {
      final l = log.toLowerCase();
      if (_selectedFilter == 'Morts') {
        return l.contains('💀') || l.contains('mort') || l.contains('succombé') || l.contains('bûcher') || l.contains('chagrin') || l.contains('flammes') || l.contains('abattu');
      }
      if (_selectedFilter == 'Nuit') {
        return l.contains('🐺') || l.contains('nuit') || l.contains('sombre') || l.contains('meute') || l.contains('victime');
      }
      if (_selectedFilter == 'Débat') {
        return l.contains('🎙️') || l.contains('débat') || l.contains('parole') || l.contains('vote') || l.contains('scrutin') || l.contains('capitaine');
      }
      if (_selectedFilter == 'Pouvoirs') {
        return l.contains('🛡️') || l.contains('voyante') || l.contains('sorcière') || l.contains('potion') || l.contains('salvateur') || l.contains('chasseur') || l.contains('cupidon') || l.contains('pyromane');
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final displayLogs = _filteredLogs;

    return Scaffold(
      backgroundColor: LupusColors.background,
      body: Stack(
        children: [
          // Fond atmosphérique
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF0A0F1E),
                    Color(0xFF05070F),
                    Color(0xFF030408),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // En-tête de navigation
                _buildHeader(context),

                // Filtres thématiques
                _buildFilters(),

                const SizedBox(height: 10),

                // Liste chronologique des chroniques
                Expanded(
                  child: displayLogs.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('📜', style: TextStyle(fontSize: 40)),
                              const SizedBox(height: 12),
                              Text(
                                _selectedFilter == 'Tous'
                                    ? 'Les Chroniques sont encore vierges.'
                                    : 'Aucun événement dans cette catégorie.',
                                style: const TextStyle(
                                  color: LupusColors.textMuted,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: displayLogs.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final log = displayLogs[index];
                            final isLatest = index == 0;
                            return _buildChronicleCard(log, isLatest);
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Bouton retour
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xC012182E),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: LupusColors.textPrimary,
              ),
            ),
          ),

          // Titre central
          Column(
            children: [
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('📜 ', style: TextStyle(fontSize: 16)),
                  Text(
                    'CHRONIQUES DU VILLAGE',
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Salon #${widget.roomCode} • ${widget.logs.length} faits consignés',
                style: const TextStyle(
                  fontSize: 11,
                  color: LupusColors.arcaneGold,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          // Bouton fermer / croix
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xC012182E),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 18,
                color: LupusColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final filters = ['Tous', 'Morts', 'Nuit', 'Débat', 'Pouvoirs'];

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final f = filters[index];
          final isSelected = _selectedFilter == f;

          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: isSelected
                    ? LupusColors.arcaneGold.withValues(alpha: 0.2)
                    : const Color(0x9912182E),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? LupusColors.arcaneGold
                      : Colors.white.withValues(alpha: 0.12),
                  width: isSelected ? 1.3 : 0.8,
                ),
                boxShadow: isSelected
                    ? LupusTheme.glowGold(opacity: 0.25)
                    : null,
              ),
              child: Text(
                f,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                  color: isSelected
                      ? LupusColors.arcaneGold
                      : LupusColors.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChronicleCard(String log, bool isLatest) {
    Color accentColor = LupusColors.textSecondary;
    IconData leadingIcon = Icons.auto_stories_rounded;

    final lower = log.toLowerCase();
    if (lower.contains('💀') || lower.contains('mort') || lower.contains('succombé') || lower.contains('bûcher')) {
      accentColor = LupusColors.bloodRed;
      leadingIcon = Icons.dangerous_rounded;
    } else if (lower.contains('🐺') || lower.contains('loup')) {
      accentColor = const Color(0xFFFF4D6D);
      leadingIcon = Icons.nightlight_round;
    } else if (lower.contains('🎙️') || lower.contains('débat') || lower.contains('parole')) {
      accentColor = LupusColors.voiceActive;
      leadingIcon = Icons.mic_rounded;
    } else if (lower.contains('🎖️') || lower.contains('capitaine')) {
      accentColor = LupusColors.arcaneGold;
      leadingIcon = Icons.military_tech_rounded;
    } else if (lower.contains('🛡️') || lower.contains('salvateur') || lower.contains('potion') || lower.contains('guérison')) {
      accentColor = const Color(0xFF38BDF8);
      leadingIcon = Icons.shield_rounded;
    } else if (lower.contains('🌅') || lower.contains('aube')) {
      accentColor = LupusColors.sunAmber;
      leadingIcon = Icons.wb_sunny_rounded;
    }

    return BentoCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderColor: isLatest ? accentColor.withValues(alpha: 0.6) : LupusColors.border,
      glowing: isLatest,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: accentColor.withValues(alpha: 0.4), width: 1),
            ),
            child: Icon(leadingIcon, size: 14, color: accentColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isLatest)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'DERNIER ÉVÉNEMENT',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          color: accentColor,
                        ),
                      ),
                    ),
                  ),
                Text(
                  log,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: isLatest ? Colors.white : const Color(0xFFE2E8F0),
                    fontWeight: isLatest ? FontWeight.w700 : FontWeight.w400,
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
