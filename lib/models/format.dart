/// "19:42".
String timeLabel(DateTime at) {
  final t = at.toLocal();
  return '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';
}

/// "2:14" for a wait in seconds, "1:02:14" past the hour.
String countdown(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  final h = s ~/ 3600, m = s % 3600 ~/ 60;
  final ss = (s % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$ss' : '$m:$ss';
}

/// "Just now", "4 min ago", "2 h ago".
String agoLabel(DateTime at, DateTime now) {
  final d = now.difference(at);
  if (d.inSeconds < 45) return 'Just now';
  if (d.inMinutes < 60) return '${d.inMinutes < 1 ? 1 : d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  return '${d.inDays} d ago';
}

/// "63%".
String percent(double share) => '${(share * 100).round()}%';
