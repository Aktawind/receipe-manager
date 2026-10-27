import '../../l10n/app_localizations.dart';

/// « 45 min », « 1 h », « 1 h 30 ».
String formatMinutes(AppLocalizations l10n, int minutes) {
  if (minutes < 60) return l10n.minutesShort(minutes);
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (rest == 0) return l10n.hoursShort(hours);
  return l10n.hoursMinutesShort(hours, rest.toString().padLeft(2, '0'));
}
