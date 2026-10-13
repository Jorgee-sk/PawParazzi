import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/providers.dart';

class Streak {
  const Streak({
    required this.current,
    required this.best,
    required this.totalDays,
    required this.participatedToday,
    this.nextMilestone,
  });

  final int current;
  final int best;
  final int totalDays;
  final bool participatedToday;
  final int? nextMilestone;

  bool get isActive => current > 0;

  factory Streak.fromJson(Map<String, dynamic> json) => Streak(
        current: (json['current'] as num).toInt(),
        best: (json['best'] as num).toInt(),
        totalDays: (json['totalDays'] as num).toInt(),
        participatedToday: json['participatedToday'] as bool,
        nextMilestone: (json['nextMilestone'] as num?)?.toInt(),
      );
}

final streakProvider = FutureProvider.autoDispose<Streak>((ref) async {
  final json = await ref.watch(apiClientProvider).get<Map<String, dynamic>>('/api/v1/gamification/streak');
  return Streak.fromJson(json);
});
