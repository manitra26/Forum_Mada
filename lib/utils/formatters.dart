import 'package:intl/intl.dart';

String formatDateShort(DateTime date) {
  return DateFormat.yMMMd().format(date);
}

String timeAgo(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inDays >= 1) return '${diff.inDays}j';
  if (diff.inHours >= 1) return '${diff.inHours}h';
  if (diff.inMinutes >= 1) return '${diff.inMinutes}m';
  return 'now';
}
