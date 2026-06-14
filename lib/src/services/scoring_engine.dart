import 'dart:math';

import '../config/app_constants.dart';
import '../models/prediction.dart';
import '../models/usage_log.dart';

/// Per-day behavioural factors, each normalized to 0..1.
class _DayFactors {
  _DayFactors({
    required this.screenRisk,
    required this.pickupRisk,
    required this.distractRisk,
    required this.nightRisk,
    required this.fragPenalty,
    required this.productiveShare,
  });

  final double screenRisk;
  final double pickupRisk;
  final double distractRisk;
  final double nightRisk;
  final double fragPenalty;
  final double productiveShare;
}

/// Transparent, on-device heuristic model that turns raw screen-time data
/// into wellness scores and actionable insights. Stands in for the optional
/// FastAPI ML backend described in the roadmap.
class ScoringEngine {
  ScoringEngine._();

  static double _c(double v) => v.clamp(0.0, 1.0).toDouble();

  static _DayFactors _factors(DailyUsage day) {
    final total = day.totalMinutes;
    final pickups = day.pickups;
    final share = total == 0 ? 0.0 : day.distractingMinutes / total;
    final avgSession = pickups == 0 ? 0.0 : total / pickups;

    final productiveMinutes = (day.categoryMinutes[AppCategory.productivity] ??
            0) +
        (day.categoryMinutes[AppCategory.education] ?? 0) +
        (day.categoryMinutes[AppCategory.health] ?? 0);

    return _DayFactors(
      screenRisk: _c((total - 120) / 360),
      pickupRisk: _c((pickups - 40) / 100),
      distractRisk: _c((share - 0.35) / 0.5),
      nightRisk: _c(day.nightMinutes / 90),
      fragPenalty: pickups == 0 ? 0.0 : _c((8 - avgSession) / 8),
      productiveShare: total == 0 ? 0.0 : productiveMinutes / total,
    );
  }

  static double _addiction(_DayFactors f) {
    return 100 *
        (0.34 * f.screenRisk +
            0.26 * f.pickupRisk +
            0.24 * f.distractRisk +
            0.16 * f.nightRisk);
  }

  static double _focus(_DayFactors f) {
    final penalty =
        0.40 * f.pickupRisk + 0.35 * f.fragPenalty + 0.25 * f.distractRisk;
    final score = 100 - 100 * penalty + 12 * f.productiveShare;
    return score.clamp(0.0, 100.0).toDouble();
  }

  /// Runs a full scoring pass over [history] (ordered oldest -> newest).
  static Prediction evaluate(
    List<DailyUsage> history, {
    int dailyLimitMinutes = AppConstants.defaultDailyLimitMinutes,
  }) {
    if (history.isEmpty) {
      return _empty();
    }

    final today = history.last;
    final todayFactors = _factors(today);

    // Trailing window (up to 7 days incl. today) and the window before it.
    final recent = history.length <= 7
        ? history
        : history.sublist(history.length - 7);
    final prior = history.length <= 7
        ? <DailyUsage>[]
        : history.sublist(
            max(0, history.length - 14),
            history.length - 7,
          );

    final recentFactors = recent.map(_factors).toList();
    final priorFactors = prior.map(_factors).toList();

    final addictionToday = _addiction(todayFactors);
    final focusToday = _focus(todayFactors);

    // Deltas: today vs the average of the other recent days.
    final otherRecent = recentFactors.length > 1
        ? recentFactors.sublist(0, recentFactors.length - 1)
        : <_DayFactors>[];
    final prevAddiction = _avg(otherRecent.map(_addiction));
    final prevFocus = _avg(otherRecent.map(_focus));

    final sleepRecent = _sleepImpact(recent);
    final sleepPrior = prior.isEmpty ? sleepRecent : _sleepImpact(prior);

    final burnoutRecent = _burnout(recent, recentFactors, prior);
    final burnoutPrior = prior.isEmpty
        ? burnoutRecent
        : _burnout(prior, priorFactors, const []);

    final addiction = ScoreMetric(
      label: 'Addiction risk',
      score: addictionToday.round(),
      delta: otherRecent.isEmpty ? 0 : addictionToday - prevAddiction,
      higherIsBetter: false,
    );
    final focus = ScoreMetric(
      label: 'Focus score',
      score: focusToday.round(),
      delta: otherRecent.isEmpty ? 0 : focusToday - prevFocus,
      higherIsBetter: true,
    );
    final sleep = ScoreMetric(
      label: 'Sleep impact',
      score: sleepRecent.round(),
      delta: prior.isEmpty ? 0 : sleepRecent - sleepPrior,
      higherIsBetter: false,
    );
    final burnout = ScoreMetric(
      label: 'Burnout risk',
      score: burnoutRecent.round(),
      delta: prior.isEmpty ? 0 : burnoutRecent - burnoutPrior,
      higherIsBetter: false,
    );

    final wellness = (0.35 * (100 - addictionToday) +
            0.30 * focusToday +
            0.20 * (100 - sleepRecent) +
            0.15 * (100 - burnoutRecent))
        .clamp(0.0, 100.0)
        .round();

    return Prediction(
      generatedAt: DateTime.now(),
      addiction: addiction,
      focus: focus,
      sleepImpact: sleep,
      burnoutRisk: burnout,
      wellnessScore: wellness,
      insights: _insights(
        today: today,
        factors: todayFactors,
        addiction: addiction,
        focus: focus,
        burnout: burnout,
        sleep: sleep,
        dailyLimitMinutes: dailyLimitMinutes,
      ),
    );
  }

  static double _sleepImpact(List<DailyUsage> days) {
    if (days.isEmpty) return 0;
    final avgNight = _avg(days.map((d) => _c(d.nightMinutes / 120)));
    final latePeakDays = days
        .where((d) =>
            d.nightMinutes > 10 && (d.peakHour >= 22 || d.peakHour <= 1))
        .length;
    final latePeakFrac = latePeakDays / days.length;
    return (100 * (0.7 * avgNight + 0.3 * latePeakFrac))
        .clamp(0.0, 100.0)
        .toDouble();
  }

  static double _burnout(
    List<DailyUsage> recent,
    List<_DayFactors> factors,
    List<DailyUsage> prior,
  ) {
    if (factors.isEmpty) return 0;
    final avgScreen = _avg(factors.map((f) => f.screenRisk));
    final avgDistract = _avg(factors.map((f) => f.distractRisk));

    var rising = 0.0;
    if (prior.isNotEmpty) {
      final recentAvg = _avg(recent.map((d) => d.totalMinutes.toDouble()));
      final priorAvg = _avg(prior.map((d) => d.totalMinutes.toDouble()));
      rising = _c((recentAvg - priorAvg) / 120);
    }
    return (100 * (0.45 * avgScreen + 0.30 * avgDistract + 0.25 * rising))
        .clamp(0.0, 100.0)
        .toDouble();
  }

  /// Recommended focus-block length (minutes) given today's fragmentation.
  static int suggestedFocusMinutes(DailyUsage day) {
    final avgSession =
        day.pickups == 0 ? 30.0 : day.totalMinutes / day.pickups;
    if (avgSession < 3) return 15;
    if (avgSession < 6) return 25;
    return 35;
  }

  static List<Insight> _insights({
    required DailyUsage today,
    required _DayFactors factors,
    required ScoreMetric addiction,
    required ScoreMetric focus,
    required ScoreMetric burnout,
    required ScoreMetric sleep,
    required int dailyLimitMinutes,
  }) {
    final insights = <Insight>[];

    // Dopamine loop: distracting apps opened often in very short bursts.
    final loopApps = today.apps
        .where((a) =>
            a.category.isDistracting &&
            a.opens >= 12 &&
            a.minutes >= 15 &&
            a.averageSessionMinutes < 4)
        .toList()
      ..sort((a, b) => b.opens.compareTo(a.opens));
    if (loopApps.isNotEmpty) {
      final worst = loopApps.first;
      insights.add(Insight(
        kind: InsightKind.dopamineLoop,
        title: 'Dopamine loop with ${worst.appName}',
        description:
            'You opened ${worst.appName} ${worst.opens} times today in '
            'sessions averaging ${worst.averageSessionMinutes.toStringAsFixed(1)} '
            'minutes — a classic compulsive-checking pattern.',
        recommendation:
            'Move ${worst.appName} off your home screen and turn off its '
            'notifications for a day.',
        priority: worst.opens >= 25 ? Severity.high : Severity.moderate,
      ));
    }

    // Screen time vs daily limit.
    if (today.totalMinutes > dailyLimitMinutes) {
      final over = today.totalMinutes - dailyLimitMinutes;
      insights.add(Insight(
        kind: InsightKind.screenTime,
        title: 'Over your daily limit',
        description:
            'Today\'s ${_hm(today.totalMinutes)} is ${_hm(over)} past your '
            '${_hm(dailyLimitMinutes)} target.',
        recommendation:
            'Schedule a screen-free block this evening to reset the balance.',
        priority: over > 120 ? Severity.high : Severity.moderate,
      ));
    }

    // Late-night usage.
    if (today.nightMinutes >= 30) {
      insights.add(Insight(
        kind: InsightKind.nightUsage,
        title: 'Late-night screen time',
        description:
            '${_hm(today.nightMinutes)} of usage landed in the 10pm-5am '
            'window, which delays sleep onset and lowers sleep quality.',
        recommendation:
            'Set a wind-down reminder 30 minutes before bed and charge your '
            'phone outside the bedroom.',
        priority: today.nightMinutes >= 75 ? Severity.high : Severity.moderate,
      ));
    }

    // Frequent pickups.
    if (today.pickups >= 90) {
      insights.add(Insight(
        kind: InsightKind.pickups,
        title: 'Frequent phone checks',
        description:
            'You picked up your phone ${today.pickups} times today — roughly '
            'once every ${(960 / today.pickups).toStringAsFixed(0)} waking '
            'minutes.',
        recommendation:
            'Batch notifications and try leaving your phone in another room '
            'during focused work.',
        priority: today.pickups >= 130 ? Severity.high : Severity.moderate,
      ));
    }

    // Fragmented focus.
    if (focus.score < 55) {
      insights.add(Insight(
        kind: InsightKind.focus,
        title: 'Focus is fragmented',
        description:
            'Frequent switching is breaking your attention into small pieces, '
            'which makes deep work much harder.',
        recommendation:
            'Try a ${suggestedFocusMinutes(today)}-minute focus block with '
            'notifications silenced, then take a short break.',
        priority: focus.score < 35 ? Severity.high : Severity.moderate,
      ));
    }

    // Burnout risk.
    if (burnout.score >= 60) {
      insights.add(Insight(
        kind: InsightKind.burnout,
        title: 'Digital burnout building up',
        description:
            'Sustained heavy use across the week with little recovery time is '
            'pushing your burnout risk into the ${burnout.severity.label} band.',
        recommendation:
            'Plan one low-screen day this week and protect it like an '
            'appointment.',
        priority: burnout.score >= 75 ? Severity.high : Severity.moderate,
      ));
    }

    // Category imbalance.
    final total = today.totalMinutes;
    if (total > 0 && today.distractingMinutes / total > 0.6) {
      final pct = (today.distractingMinutes / total * 100).round();
      insights.add(Insight(
        kind: InsightKind.balance,
        title: 'Lopsided app balance',
        description:
            '$pct% of today\'s screen time went to social, entertainment and '
            'games.',
        recommendation:
            'Swap one scroll session for a 10-minute walk or a learning app.',
        priority: Severity.moderate,
      ));
    }

    // Positive reinforcement.
    if (today.totalMinutes <= dailyLimitMinutes) {
      insights.add(Insight(
        kind: InsightKind.achievement,
        title: 'Under your daily limit',
        description:
            'Nice work — today\'s ${_hm(today.totalMinutes)} stayed within '
            'your ${_hm(dailyLimitMinutes)} target.',
        priority: Severity.low,
        positive: true,
      ));
    }
    if (addiction.isImproving && addiction.delta <= -3) {
      insights.add(Insight(
        kind: InsightKind.achievement,
        title: 'Addiction risk trending down',
        description:
            'Your addiction risk dropped ${addiction.delta.abs().round()} '
            'points versus your recent average. Keep the streak going.',
        priority: Severity.low,
        positive: true,
      ));
    }
    if (insights.every((i) => i.positive)) {
      insights.add(const Insight(
        kind: InsightKind.balance,
        title: 'Healthy digital balance',
        description:
            'No risky patterns stood out today. Your habits look balanced.',
        priority: Severity.low,
        positive: true,
      ));
    }

    return insights;
  }

  static double _avg(Iterable<double> values) {
    final list = values.toList();
    if (list.isEmpty) return 0;
    return list.reduce((a, b) => a + b) / list.length;
  }

  static String _hm(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  static Prediction _empty() {
    ScoreMetric zero(String label, bool higherIsBetter) => ScoreMetric(
          label: label,
          score: higherIsBetter ? 100 : 0,
          delta: 0,
          higherIsBetter: higherIsBetter,
        );
    return Prediction(
      generatedAt: DateTime.now(),
      addiction: zero('Addiction risk', false),
      focus: zero('Focus score', true),
      sleepImpact: zero('Sleep impact', false),
      burnoutRisk: zero('Burnout risk', false),
      wellnessScore: 100,
      insights: const [],
    );
  }
}
