import 'package:flutter_test/flutter_test.dart';

import 'package:loopaware/src/models/prediction.dart';
import 'package:loopaware/src/services/demo_data.dart';
import 'package:loopaware/src/services/scoring_engine.dart';

void main() {
  group('DemoData', () {
    test('generates the requested number of days', () {
      final days = DemoData.generate(days: 14);
      expect(days.length, 14);
      // Days are ordered oldest to newest.
      for (var i = 1; i < days.length; i++) {
        expect(days[i].date.isAfter(days[i - 1].date), isTrue);
      }
    });

    test('every day has at least one app and a 24-slot hourly array', () {
      for (final day in DemoData.generate(days: 7)) {
        expect(day.apps, isNotEmpty);
        expect(day.hourlyMinutes.length, 24);
        expect(day.totalMinutes, greaterThan(0));
      }
    });
  });

  group('ScoringEngine', () {
    test('returns scores within the 0..100 band', () {
      final prediction = ScoringEngine.evaluate(DemoData.generate(days: 14));
      for (final metric in [
        prediction.addiction,
        prediction.focus,
        prediction.sleepImpact,
        prediction.burnoutRisk,
      ]) {
        expect(metric.score, inInclusiveRange(0, 100));
      }
      expect(prediction.wellnessScore, inInclusiveRange(0, 100));
    });

    test('produces at least one insight for typical demo days', () {
      final prediction = ScoringEngine.evaluate(DemoData.generate(days: 14));
      expect(prediction.insights, isNotEmpty);
    });

    test('handles an empty history gracefully', () {
      final prediction = ScoringEngine.evaluate(const []);
      expect(prediction.wellnessScore, 100);
      expect(prediction.insights, isEmpty);
    });
  });

  group('Severity', () {
    test('higher risk scores produce more severe bands', () {
      expect(Severity.fromScore(10), Severity.low);
      expect(Severity.fromScore(40), Severity.moderate);
      expect(Severity.fromScore(80), Severity.high);
    });

    test('higherIsBetter flips the thresholds', () {
      expect(Severity.fromScore(85, higherIsBetter: true), Severity.low);
      expect(Severity.fromScore(20, higherIsBetter: true), Severity.high);
    });
  });
}
