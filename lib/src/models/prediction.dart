import 'package:flutter/material.dart';

/// Risk severity band shared by every metric and insight.
enum Severity {
  low('Low', Color(0xFF22C55E)),
  moderate('Moderate', Color(0xFFF59E0B)),
  high('High', Color(0xFFEF4444));

  const Severity(this.label, this.color);

  final String label;
  final Color color;

  /// Maps a 0-100 score to a band. [higherIsBetter] flips the thresholds so
  /// the same helper works for both risk scores and wellness scores.
  static Severity fromScore(int score, {bool higherIsBetter = false}) {
    final risk = higherIsBetter ? 100 - score : score;
    if (risk >= 66) return Severity.high;
    if (risk >= 33) return Severity.moderate;
    return Severity.low;
  }

  static Severity fromName(String? name) => Severity.values.firstWhere(
    (s) => s.name == name,
    orElse: () => Severity.low,
  );
}

/// A single 0-100 metric produced by the scoring engine.
class ScoreMetric {
  ScoreMetric({
    required this.label,
    required this.score,
    required this.delta,
    required this.higherIsBetter,
  });

  final String label;

  /// 0-100.
  final int score;

  /// Change versus the previous comparable period (signed, in points).
  final double delta;

  /// Whether a higher score is the desirable outcome.
  final bool higherIsBetter;

  Severity get severity =>
      Severity.fromScore(score, higherIsBetter: higherIsBetter);

  /// True when the metric moved in the desirable direction.
  bool get isImproving =>
      delta == 0 ? false : (delta > 0) == higherIsBetter;

  bool get isSteady => delta.abs() < 1;

  Map<String, dynamic> toJson() => {
    'label': label,
    'score': score,
    'delta': delta,
    'higherIsBetter': higherIsBetter,
  };

  factory ScoreMetric.fromJson(Map<String, dynamic> json) => ScoreMetric(
    label: json['label'] as String? ?? '',
    score: (json['score'] as num?)?.toInt() ?? 0,
    delta: (json['delta'] as num?)?.toDouble() ?? 0,
    higherIsBetter: json['higherIsBetter'] as bool? ?? false,
  );
}

/// The kind of behavioural pattern an insight describes. Drives iconography.
enum InsightKind {
  screenTime('Screen time', Icons.hourglass_bottom_rounded),
  pickups('Pickups', Icons.touch_app_rounded),
  dopamineLoop('Dopamine loop', Icons.refresh_rounded),
  nightUsage('Night usage', Icons.bedtime_rounded),
  focus('Focus', Icons.center_focus_strong_rounded),
  balance('Balance', Icons.balance_rounded),
  burnout('Burnout risk', Icons.battery_alert_rounded),
  achievement('Achievement', Icons.emoji_events_rounded);

  const InsightKind(this.label, this.icon);

  final String label;
  final IconData icon;

  static InsightKind fromName(String? name) => InsightKind.values.firstWhere(
    (k) => k.name == name,
    orElse: () => InsightKind.balance,
  );
}

/// A single AI-style insight / recommendation surfaced to the user.
class Insight {
  const Insight({
    required this.kind,
    required this.title,
    required this.description,
    required this.priority,
    this.recommendation,
    this.positive = false,
  });

  final InsightKind kind;
  final String title;
  final String description;
  final Severity priority;

  /// Actionable next step. Null when the insight is purely informational.
  final String? recommendation;

  /// True for celebratory / good-news insights.
  final bool positive;

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'title': title,
    'description': description,
    'priority': priority.name,
    'recommendation': recommendation,
    'positive': positive,
  };

  factory Insight.fromJson(Map<String, dynamic> json) => Insight(
    kind: InsightKind.fromName(json['kind'] as String?),
    title: json['title'] as String? ?? '',
    description: json['description'] as String? ?? '',
    priority: Severity.fromName(json['priority'] as String?),
    recommendation: json['recommendation'] as String?,
    positive: json['positive'] as bool? ?? false,
  );
}

/// The full result of an on-device scoring pass.
class Prediction {
  Prediction({
    required this.generatedAt,
    required this.addiction,
    required this.focus,
    required this.sleepImpact,
    required this.burnoutRisk,
    required this.wellnessScore,
    required this.insights,
  });

  final DateTime generatedAt;

  /// Compulsive-use risk (0-100, lower is better).
  final ScoreMetric addiction;

  /// Sustained-attention quality (0-100, higher is better).
  final ScoreMetric focus;

  /// Estimated sleep disruption from screen use (0-100, lower is better).
  final ScoreMetric sleepImpact;

  /// Digital burnout risk over the trailing week (0-100, lower is better).
  final ScoreMetric burnoutRisk;

  /// Overall wellness (0-100, higher is better).
  final int wellnessScore;

  final List<Insight> insights;

  Severity get wellnessSeverity =>
      Severity.fromScore(wellnessScore, higherIsBetter: true);

  String get wellnessLabel {
    if (wellnessScore >= 75) return 'Thriving';
    if (wellnessScore >= 55) return 'Balanced';
    if (wellnessScore >= 35) return 'Strained';
    return 'At risk';
  }

  List<Insight> get prioritisedInsights {
    final sorted = [...insights];
    int rank(Insight i) => i.positive ? 3 : (2 - i.priority.index);
    sorted.sort((a, b) => rank(a).compareTo(rank(b)));
    return sorted;
  }

  Map<String, dynamic> toJson() => {
    'generatedAt': generatedAt.toIso8601String(),
    'addiction': addiction.toJson(),
    'focus': focus.toJson(),
    'sleepImpact': sleepImpact.toJson(),
    'burnoutRisk': burnoutRisk.toJson(),
    'wellnessScore': wellnessScore,
    'insights': insights.map((i) => i.toJson()).toList(),
  };

  factory Prediction.fromJson(Map<String, dynamic> json) => Prediction(
    generatedAt:
        DateTime.tryParse(json['generatedAt'] as String? ?? '') ??
        DateTime.now(),
    addiction: ScoreMetric.fromJson(
      Map<String, dynamic>.from(json['addiction'] as Map),
    ),
    focus: ScoreMetric.fromJson(
      Map<String, dynamic>.from(json['focus'] as Map),
    ),
    sleepImpact: ScoreMetric.fromJson(
      Map<String, dynamic>.from(json['sleepImpact'] as Map),
    ),
    burnoutRisk: ScoreMetric.fromJson(
      Map<String, dynamic>.from(json['burnoutRisk'] as Map),
    ),
    wellnessScore: (json['wellnessScore'] as num?)?.toInt() ?? 0,
    insights: ((json['insights'] as List?) ?? const [])
        .map((e) => Insight.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
  );
}
