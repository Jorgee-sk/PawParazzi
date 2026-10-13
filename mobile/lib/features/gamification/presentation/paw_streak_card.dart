import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/paw_icon.dart';
import '../data/streak.dart';

/// PawParazzi/PawStreak. Active: butter + llama. Interrupted: lavanda + corazón,
/// "Una racha interrumpida no elimina insignias, fotografías ni PawPoints. Siempre hay un regreso sin culpa."
class PawStreakCard extends StatelessWidget {
  const PawStreakCard({super.key, required this.streak});

  final Streak streak;

  @override
  Widget build(BuildContext context) {
    final (icon, background, title, subtitle) = switch (streak) {
      Streak(isActive: true) => (
          PawIcons.flame,
          PawColors.butter,
          streak.current == 1 ? '1 día compartiendo' : '${streak.current} días compartiendo',
          'Tu mejor racha: ${_days(streak.best)} · sin prisa',
        ),
      Streak(best: > 0) => (
          PawIcons.heartStreak,
          PawColors.lavender,
          'Cada momento cuenta',
          'Tu mejor racha sigue contigo: ${_days(streak.best)}.',
        ),
      _ => (
          PawIcons.heartStreak,
          PawColors.lavender,
          'Tu primera racha empieza con un PawMoment',
          'Cada día que compartas tu PawMoment suma un día.',
        ),
    };
    return Semantics(
      container: true,
      label: 'PawStreak',
      child: Container(
        constraints: const BoxConstraints(minHeight: 66),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(PawRadius.r20)),
        child: Row(
          children: [
            PawIcon(icon),
            const SizedBox(width: PawSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: PawText.body15Semi),
                  Text(subtitle, style: PawText.caption12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _days(int n) => n == 1 ? '1 día' : '$n días';
}
