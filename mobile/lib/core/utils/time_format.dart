import 'package:intl/intl.dart';

/// "Hace 18 min", "Hace 3 h", "Ayer", "12 oct".
String relativeTime(DateTime when, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final local = when.toLocal();
  final diff = current.difference(local);
  if (diff.inMinutes < 1) return 'Ahora mismo';
  if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
  if (diff.inHours < 24 && local.day == current.day) return 'Hace ${diff.inHours} h';
  final yesterday = DateTime(current.year, current.month, current.day - 1);
  if (local.year == yesterday.year && local.month == yesterday.month && local.day == yesterday.day) return 'Ayer';
  final sameYear = local.year == current.year;
  return DateFormat(sameYear ? 'd MMM' : 'd MMM y', 'es').format(local);
}

String hourMinute(DateTime when) => DateFormat.Hm('es').format(when.toLocal());
