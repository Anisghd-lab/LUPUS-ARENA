import 'package:flutter/material.dart';
import '../theme/lupus_theme.dart';
import 'bento_card.dart';

/// Journal des événements et chroniques de la partie
class BentoEventLog extends StatelessWidget {
  final List<String> logs;

  const BentoEventLog({
    super.key,
    required this.logs,
  });

  @override
  Widget build(BuildContext context) {
    final reversedLogs = logs.reversed.toList();

    return BentoCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.history_edu_rounded, size: 18, color: LupusColors.textSecondary),
              SizedBox(width: 8),
              Text(
                'CHRONIQUES DU VILLAGE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: LupusColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            constraints: const BoxConstraints(maxHeight: 120),
            child: reversedLogs.isEmpty
                ? const Center(
                    child: Text(
                      'Aucun événement pour l\'instant.',
                      style: TextStyle(color: LupusColors.textMuted, fontSize: 12),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: reversedLogs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final log = reversedLogs[index];
                      final isFirst = index == 0;
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isFirst ? LupusColors.moonIndigo : LupusColors.border,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              log,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.3,
                                color: isFirst ? LupusColors.textPrimary : LupusColors.textSecondary,
                                fontWeight: isFirst ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
