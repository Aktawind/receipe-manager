import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';

/// Ce qui fait sonner un minuteur à l'heure dite, même app fermée : une
/// alarme et une notification Android (voir `TimerAlarms.kt`).
abstract class TimerAlarmScheduler {
  Future<void> requestPermission();

  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required String channelName,
  });

  /// Annule l'alarme, et arrête la sonnerie si elle a commencé.
  Future<void> cancel(int id);
}

class AndroidTimerAlarms implements TimerAlarmScheduler {
  const AndroidTimerAlarms();

  static const _channel = MethodChannel('recettes/timers');

  Future<void> _call(String method, [Map<String, Object?>? args]) async {
    try {
      await _channel.invokeMethod<void>(method, args);
    } on MissingPluginException {
      // Pas d'Android (tests, autres plateformes) : le minuteur reste à l'écran.
    } on PlatformException catch (error) {
      debugPrint('TimerAlarms.$method: $error');
    }
  }

  @override
  Future<void> requestPermission() => _call('requestPermission');

  @override
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required String channelName,
  }) => _call('schedule', {
    'id': id,
    'at': at.millisecondsSinceEpoch,
    'title': title,
    'body': body,
    'channelName': channelName,
  });

  @override
  Future<void> cancel(int id) => _call('cancel', {'id': id});
}

final timerAlarmSchedulerProvider = Provider<TimerAlarmScheduler>(
  (ref) => const AndroidTimerAlarms(),
);

/// Un minuteur : en marche (il finit à [endsAt]) ou en pause (il lui reste
/// [remaining]).
@immutable
class CookingTimer {
  const CookingTimer({
    required this.id,
    required this.label,
    required this.total,
    this.endsAt,
    this.pausedRemaining,
  });

  final int id;

  /// « Crêpes · étape 3 ».
  final String label;
  final Duration total;
  final DateTime? endsAt;
  final Duration? pausedRemaining;

  bool get isPaused => endsAt == null;

  Duration remaining([DateTime? now]) {
    final end = endsAt;
    if (end == null) return pausedRemaining ?? total;
    final left = end.difference(now ?? clock.now());
    return left.isNegative ? Duration.zero : left;
  }

  bool isDone([DateTime? now]) => remaining(now) == Duration.zero;

  CookingTimer copyWith({
    DateTime? Function()? endsAt,
    Duration? Function()? pausedRemaining,
    Duration? total,
  }) => CookingTimer(
    id: id,
    label: label,
    total: total ?? this.total,
    endsAt: endsAt != null ? endsAt() : this.endsAt,
    pausedRemaining: pausedRemaining != null
        ? pausedRemaining()
        : this.pausedRemaining,
  );
}

/// Les minuteurs en cours, pour toute l'application : ils continuent quand on
/// quitte le mode cuisine, et la notification sonne même app fermée.
final cookingTimersProvider =
    NotifierProvider<CookingTimers, List<CookingTimer>>(CookingTimers.new);

class CookingTimers extends Notifier<List<CookingTimer>> {
  var _nextId = 0;

  /// Les textes de la notification (titre, nom du canal Android), donnés par
  /// l'interface au lancement.
  ({String title, String channel}) _texts = (
    title: 'Minuteur',
    channel: 'Minuteurs',
  );

  TimerAlarmScheduler get _alarms => ref.read(timerAlarmSchedulerProvider);

  @override
  List<CookingTimer> build() => const [];

  Future<void> start(
    String label,
    Duration duration, {
    required String alarmTitle,
    required String channelName,
  }) async {
    _texts = (title: alarmTitle, channel: channelName);
    // Un identifiant propre à ce lancement de l'application, pour ne pas
    // retrouver une alarme d'une session précédente.
    final id =
        (clock.now().millisecondsSinceEpoch ~/ 1000 % 1000000) * 100 +
        (_nextId++ % 100);
    final timer = CookingTimer(
      id: id,
      label: label,
      total: duration,
      endsAt: clock.now().add(duration),
    );
    state = [...state, timer];
    await _alarms.requestPermission();
    await _schedule(timer);
  }

  Future<void> pause(int id) async {
    final timer = _find(id);
    if (timer == null || timer.isPaused || timer.isDone()) return;
    _replace(
      timer.copyWith(
        endsAt: () => null,
        pausedRemaining: () => timer.remaining(),
      ),
    );
    await _alarms.cancel(id);
  }

  Future<void> resume(int id) async {
    final timer = _find(id);
    if (timer == null || !timer.isPaused) return;
    final resumed = timer.copyWith(
      endsAt: () => clock.now().add(timer.remaining()),
      pausedRemaining: () => null,
    );
    _replace(resumed);
    await _schedule(resumed);
  }

  /// Une minute de plus (aussi pour relancer un minuteur qui a sonné).
  Future<void> addMinute(int id) async {
    final timer = _find(id);
    if (timer == null) return;
    const minute = Duration(minutes: 1);
    final CookingTimer updated;
    if (timer.isPaused) {
      updated = timer.copyWith(
        pausedRemaining: () => timer.remaining() + minute,
      );
    } else {
      updated = timer.copyWith(
        endsAt: () => clock.now().add(timer.remaining() + minute),
      );
      await _alarms.cancel(id);
    }
    _replace(updated);
    if (!updated.isPaused) await _schedule(updated);
  }

  /// Arrête un minuteur (et sa sonnerie) et le retire.
  Future<void> stop(int id) async {
    state = [
      for (final t in state)
        if (t.id != id) t,
    ];
    await _alarms.cancel(id);
  }

  CookingTimer? _find(int id) {
    for (final t in state) {
      if (t.id == id) return t;
    }
    return null;
  }

  void _replace(CookingTimer timer) =>
      state = [for (final t in state) t.id == timer.id ? timer : t];

  Future<void> _schedule(CookingTimer timer) async {
    final end = timer.endsAt;
    if (end == null) return;
    await _alarms.schedule(
      id: timer.id,
      at: end,
      title: _texts.title,
      body: timer.label,
      channelName: _texts.channel,
    );
  }
}

/// « 4:05 », « 1:02:30 ».
String formatCountdown(Duration d) {
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$minutes:$seconds' : '${d.inMinutes}:$seconds';
}

/// « 20 min », « 1 h 30 », « 45 s » : la durée d'un bouton de minuteur.
String formatTimerDuration(AppLocalizations l10n, Duration d) {
  if (d.inMinutes == 0) return l10n.timerSeconds(d.inSeconds);
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60);
  final seconds = d.inSeconds.remainder(60);
  if (hours == 0) {
    return seconds == 0
        ? l10n.timerMinutes(minutes)
        : '${l10n.timerMinutes(minutes)} ${l10n.timerSeconds(seconds)}';
  }
  return minutes == 0
      ? l10n.timerHours(hours)
      : '${l10n.timerHours(hours)} ${minutes.toString().padLeft(2, '0')}';
}

/// Les minuteurs en cours, en bas du mode cuisine : temps restant, pause,
/// une minute de plus, arrêt. Se redessine chaque seconde.
class CookingTimersPanel extends ConsumerStatefulWidget {
  const CookingTimersPanel({super.key});

  @override
  ConsumerState<CookingTimersPanel> createState() => _CookingTimersPanelState();
}

class _CookingTimersPanelState extends ConsumerState<CookingTimersPanel> {
  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _syncTicker(bool needed) {
    if (needed && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!needed) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final timers = ref.watch(cookingTimersProvider);
    final controller = ref.read(cookingTimersProvider.notifier);
    final now = clock.now();
    _syncTicker(timers.any((t) => !t.isPaused && !t.isDone(now)));
    if (timers.isEmpty) return const SizedBox.shrink();

    return Material(
      color: scheme.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final timer in timers)
                _TimerRow(
                  key: ValueKey('timer-${timer.id}'),
                  timer: timer,
                  now: now,
                  l10n: l10n,
                  controller: controller,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimerRow extends StatelessWidget {
  const _TimerRow({
    super.key,
    required this.timer,
    required this.now,
    required this.l10n,
    required this.controller,
  });

  final CookingTimer timer;
  final DateTime now;
  final AppLocalizations l10n;
  final CookingTimers controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final done = timer.isDone(now);
    final color = done ? scheme.error : scheme.onSurface;
    return Row(
      children: [
        Icon(
          done ? Icons.alarm_on : Icons.timer_outlined,
          color: done ? scheme.error : scheme.primary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                done ? l10n.timerDone : formatCountdown(timer.remaining(now)),
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                timer.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (!done)
          IconButton(
            key: ValueKey('timer-pause-${timer.id}'),
            tooltip: timer.isPaused ? l10n.timerResume : l10n.timerPause,
            icon: Icon(timer.isPaused ? Icons.play_arrow : Icons.pause),
            onPressed: () => timer.isPaused
                ? controller.resume(timer.id)
                : controller.pause(timer.id),
          ),
        IconButton(
          key: ValueKey('timer-plus-${timer.id}'),
          tooltip: l10n.timerAddMinute,
          icon: const Icon(Icons.more_time),
          onPressed: () => controller.addMinute(timer.id),
        ),
        IconButton(
          key: ValueKey('timer-stop-${timer.id}'),
          tooltip: l10n.timerStop,
          icon: Icon(Icons.close, color: done ? scheme.error : null),
          onPressed: () => controller.stop(timer.id),
        ),
      ],
    );
  }
}

/// Un minuteur d'une durée choisie (pas citée dans une étape) : renvoie la
/// durée, `null` si on annule.
Future<Duration?> showCustomTimerDialog(BuildContext context) =>
    showDialog<Duration>(
      context: context,
      builder: (context) => const _CustomTimerDialog(),
    );

class _CustomTimerDialog extends StatefulWidget {
  const _CustomTimerDialog();

  @override
  State<_CustomTimerDialog> createState() => _CustomTimerDialogState();
}

class _CustomTimerDialogState extends State<_CustomTimerDialog> {
  final _minutes = TextEditingController();

  @override
  void dispose() {
    _minutes.dispose();
    super.dispose();
  }

  void _submit() {
    final value = int.tryParse(_minutes.text.trim());
    if (value == null || value <= 0) return;
    Navigator.pop(context, Duration(minutes: value));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.timerNew),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in const [1, 3, 5, 10, 15, 20, 30, 45, 60])
                ActionChip(
                  key: ValueKey('timer-quick-$m'),
                  label: Text(formatTimerDuration(l10n, Duration(minutes: m))),
                  onPressed: () => Navigator.pop(context, Duration(minutes: m)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('timer-minutes'),
            controller: _minutes,
            autofocus: false,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: l10n.timerMinutesField),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          key: const ValueKey('timer-start'),
          onPressed: _submit,
          child: Text(l10n.timerStart),
        ),
      ],
    );
  }
}
