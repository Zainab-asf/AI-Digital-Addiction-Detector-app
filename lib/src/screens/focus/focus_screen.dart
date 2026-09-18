import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../models/focus_session.dart';
import '../../services/scoring_engine.dart';
import '../../state/app_state.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/page_scaffold.dart';
import '../../widgets/common/responsive_grid.dart';
import '../../widgets/cards/stat_card.dart';

enum _Phase { idle, running, paused, finished }

/// A countdown focus block. Time is measured against wall-clock timestamps,
/// so the countdown stays correct while the app is in the background.
class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const FocusScreen());

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  static const _presets = [15, 25, 35, 50];

  late int _minutes;
  _Phase _phase = _Phase.idle;
  DateTime? _startedAt;
  DateTime? _endsAt;
  Duration _remainingWhenPaused = Duration.zero;
  Duration _focusedBeforePause = Duration.zero;
  DateTime? _resumedAt;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    final today = context.read<AppState>().todayUsage;
    _minutes = today == null ? 25 : ScoringEngine.suggestedFocusMinutes(today);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Duration get _total => Duration(minutes: _minutes);

  Duration get _remaining {
    switch (_phase) {
      case _Phase.idle:
        return _total;
      case _Phase.paused:
        return _remainingWhenPaused;
      case _Phase.finished:
        return Duration.zero;
      case _Phase.running:
        final left = _endsAt!.difference(DateTime.now());
        return left.isNegative ? Duration.zero : left;
    }
  }

  Duration get _focused {
    final running =
        _phase == _Phase.running && _resumedAt != null
            ? DateTime.now().difference(_resumedAt!)
            : Duration.zero;
    final total = _focusedBeforePause + running;
    return total > _total ? _total : total;
  }

  void _start() {
    final now = DateTime.now();
    setState(() {
      _phase = _Phase.running;
      _startedAt = now;
      _resumedAt = now;
      _focusedBeforePause = Duration.zero;
      _endsAt = now.add(_total);
    });
    _scheduleAlert();
    _startTicker();
  }

  void _pause() {
    _ticker?.cancel();
    setState(() {
      _remainingWhenPaused = _remaining;
      _focusedBeforePause = _focused;
      _resumedAt = null;
      _phase = _Phase.paused;
    });
    context.read<AppState>().notifier.cancelFocusEnd();
  }

  void _resume() {
    final now = DateTime.now();
    setState(() {
      _phase = _Phase.running;
      _resumedAt = now;
      _endsAt = now.add(_remainingWhenPaused);
    });
    _scheduleAlert();
    _startTicker();
  }

  void _scheduleAlert() {
    final end = _endsAt;
    if (end == null) return;
    context.read<AppState>().notifier.scheduleFocusEnd(end, _minutes);
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_phase == _Phase.running && _remaining == Duration.zero) {
        _complete();
      } else {
        setState(() {});
      }
    });
  }

  Future<void> _complete() async {
    _ticker?.cancel();
    final state = context.read<AppState>();
    setState(() => _phase = _Phase.finished);
    await state.addFocusSession(
      FocusSession(
        startedAt: _startedAt ?? DateTime.now(),
        plannedMinutes: _minutes,
        focusedMinutes: _minutes,
        completed: true,
      ),
    );
  }

  /// Ends the session early, keeping whatever time was focused.
  Future<void> _endEarly() async {
    _ticker?.cancel();
    final state = context.read<AppState>();
    final focused = _focused.inMinutes;
    await state.notifier.cancelFocusEnd();
    if (focused > 0) {
      await state.addFocusSession(
        FocusSession(
          startedAt: _startedAt ?? DateTime.now(),
          plannedMinutes: _minutes,
          focusedMinutes: focused,
          completed: false,
        ),
      );
    }
    if (!mounted) return;
    setState(() {
      _phase = _Phase.idle;
      _startedAt = null;
      _endsAt = null;
      _resumedAt = null;
      _focusedBeforePause = Duration.zero;
    });
  }

  Future<bool> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('End this session?'),
            content: const Text(
              'Time focused so far is saved. The countdown stops.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Keep going'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('End session'),
              ),
            ],
          ),
    );
    if (leave == true) await _endEarly();
    return leave == true;
  }

  String _clock(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final active = _phase == _Phase.running || _phase == _Phase.paused;
    final suggested =
        state.todayUsage == null
            ? null
            : ScoringEngine.suggestedFocusMinutes(state.todayUsage!);

    return PopScope(
      canPop: !active,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmLeave() && mounted) navigator.pop();
      },
      child: PageScaffold(
        showBack: true,
        title: 'Focus session',
        subtitle:
            'Silence notifications, put the phone face down and work '
            'on one thing until the timer ends.',
        maxWidth: 880,
        builder:
            (context, layout) => [
              _TimerCard(
                phase: _phase,
                minutes: _minutes,
                presets: _presets,
                suggested: suggested,
                remaining: _remaining,
                progress:
                    _phase == _Phase.idle
                        ? 0
                        : 1 - _remaining.inMilliseconds / _total.inMilliseconds,
                clock: _clock(_remaining),
                compact: layout.compact,
                onPick: (m) => setState(() => _minutes = m),
                onStart: _start,
                onPause: _pause,
                onResume: _resume,
                onEnd: _endEarly,
                onReset: () => setState(() => _phase = _Phase.idle),
              ),
              SizedBox(height: layout.gap),
              _History(
                sessions: state.focusSessions,
                gap: layout.gap,
                columns: layout.width >= 360 ? 3 : 1,
              ),
            ],
      ),
    );
  }
}

class _TimerCard extends StatelessWidget {
  const _TimerCard({
    required this.phase,
    required this.minutes,
    required this.presets,
    required this.suggested,
    required this.remaining,
    required this.progress,
    required this.clock,
    required this.compact,
    required this.onPick,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onEnd,
    required this.onReset,
  });

  final _Phase phase;
  final int minutes;
  final List<int> presets;
  final int? suggested;
  final Duration remaining;
  final double progress;
  final String clock;
  final bool compact;
  final ValueChanged<int> onPick;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onEnd;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = AppColors.of(context);
    final ringSize = compact ? 220.0 : 260.0;

    final status = switch (phase) {
      _Phase.idle => 'Ready',
      _Phase.running => 'Focusing',
      _Phase.paused => 'Paused',
      _Phase.finished => 'Session complete',
    };

    final Widget controls = switch (phase) {
      _Phase.idle => FilledButton.icon(
        onPressed: onStart,
        icon: const Icon(Icons.play_arrow_rounded),
        label: Text('Start ${Formatters.duration(minutes)} session'),
        style: FilledButton.styleFrom(minimumSize: const Size(220, 48)),
      ),
      _Phase.running => Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.center,
        children: [
          FilledButton.icon(
            onPressed: onPause,
            icon: const Icon(Icons.pause_rounded),
            label: const Text('Pause'),
            style: FilledButton.styleFrom(minimumSize: const Size(140, 48)),
          ),
          OutlinedButton(
            onPressed: onEnd,
            style: OutlinedButton.styleFrom(minimumSize: const Size(140, 48)),
            child: const Text('End early'),
          ),
        ],
      ),
      _Phase.paused => Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.center,
        children: [
          FilledButton.icon(
            onPressed: onResume,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Resume'),
            style: FilledButton.styleFrom(minimumSize: const Size(140, 48)),
          ),
          OutlinedButton(
            onPressed: onEnd,
            style: OutlinedButton.styleFrom(minimumSize: const Size(140, 48)),
            child: const Text('End early'),
          ),
        ],
      ),
      _Phase.finished => FilledButton(
        onPressed: onReset,
        style: FilledButton.styleFrom(minimumSize: const Size(220, 48)),
        child: const Text('Start another'),
      ),
    };

    return AppCard(
      padding: EdgeInsets.all(compact ? 20 : 28),
      child: Column(
        children: [
          if (phase == _Phase.idle) ...[
            Text('Session length', style: theme.textTheme.labelMedium),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final p in presets)
                  ChoiceChip(
                    label: Text(
                      p == suggested
                          ? '${Formatters.duration(p)} · suggested'
                          : Formatters.duration(p),
                    ),
                    selected: p == minutes,
                    onSelected: (_) => onPick(p),
                    showCheckmark: false,
                  ),
              ],
            ),
            const SizedBox(height: 24),
          ],
          Semantics(
            label:
                '$status, ${remaining.inMinutes} minutes '
                '${remaining.inSeconds % 60} seconds remaining',
            excludeSemantics: true,
            child: SizedBox(
              width: ringSize,
              height: ringSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: Size.square(ringSize),
                    painter: _ProgressRing(
                      progress: progress.clamp(0.0, 1.0),
                      color:
                          phase == _Phase.finished ? c.good.solid : c.primary,
                      track: c.surfaceMuted,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        clock,
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontSize: compact ? 44 : 52,
                          fontFeatures: AppTheme.tabular,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(status, style: theme.textTheme.labelMedium),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          controls,
          if (phase == _Phase.finished) ...[
            const SizedBox(height: 12),
            Text(
              'Nice work. Take a short break before the next block.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}

class _ProgressRing extends CustomPainter {
  _ProgressRing({
    required this.progress,
    required this.color,
    required this.track,
  });

  final double progress;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 10.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    canvas.drawArc(
      rect,
      0,
      2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track,
    );
    if (progress <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressRing old) =>
      old.progress != progress || old.color != color || old.track != track;
}

class _History extends StatelessWidget {
  const _History({
    required this.sessions,
    required this.gap,
    required this.columns,
  });

  final int columns;

  final List<FocusSession> sessions;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = AppColors.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(const Duration(days: 6));

    final todayMinutes = sessions
        .where((s) => !s.startedAt.isBefore(today))
        .fold(0, (sum, s) => sum + s.focusedMinutes);
    final week = sessions.where((s) => !s.startedAt.isBefore(weekStart));
    final weekCompleted = week.where((s) => s.completed).length;
    final weekMinutes = week.fold(0, (sum, s) => sum + s.focusedMinutes);
    final recent = sessions.reversed.take(6).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ResponsiveGrid(
          columns: columns,
          spacing: gap,
          children: [
            StatCard(
              label: 'Today',
              value: Formatters.duration(todayMinutes),
              caption: 'Focused',
            ),
            StatCard(
              label: 'Last 7 days',
              value: Formatters.duration(weekMinutes),
              caption: 'Focused',
            ),
            StatCard(
              label: 'Completed',
              value: '$weekCompleted',
              caption: 'Last 7 days',
            ),
          ],
        ),
        SizedBox(height: gap),
        AppCard(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const CardHeader(title: 'Recent sessions'),
              const SizedBox(height: 8),
              if (recent.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Sessions you finish or end early appear here.',
                    style: theme.textTheme.bodyMedium,
                  ),
                )
              else
                for (var i = 0; i < recent.length; i++)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      border:
                          i == recent.length - 1
                              ? null
                              : Border(
                                bottom: BorderSide(color: c.borderSubtle),
                              ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          recent[i].completed
                              ? Icons.check_circle_outline_rounded
                              : Icons.timelapse_rounded,
                          size: 18,
                          color:
                              recent[i].completed
                                  ? c.good.solid
                                  : c.textTertiary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${Formatters.relativeDay(recent[i].startedAt)}, '
                            '${Formatters.time(recent[i].startedAt)}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 13,
                              color: c.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          recent[i].completed
                              ? Formatters.duration(recent[i].focusedMinutes)
                              : '${Formatters.duration(recent[i].focusedMinutes)}'
                                  ' of ${Formatters.duration(recent[i].plannedMinutes)}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontFeatures: AppTheme.tabular,
                          ),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}
