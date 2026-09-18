import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../utils/formatters.dart';

/// Local (on-device) notifications: the nightly wind-down reminder, usage
/// alerts and the focus-session finish alert.
///
/// Android only. Everywhere else — web, desktop, widget tests — every call
/// is a no-op, so callers never need to check the platform themselves.
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  Future<bool>? _ready;

  static const int _bedtimeId = 1;
  static const int _goalId = 2;
  static const int _focusId = 3;
  static const int _appLimitBaseId = 1000;

  static const _reminders = AndroidNotificationDetails(
    'reminders',
    'Reminders',
    channelDescription: 'Nightly wind-down reminder',
  );
  static const _alerts = AndroidNotificationDetails(
    'usage_alerts',
    'Usage alerts',
    channelDescription: 'When you pass your daily goal or an app limit',
    importance: Importance.high,
    priority: Priority.high,
  );
  static const _focus = AndroidNotificationDetails(
    'focus',
    'Focus sessions',
    channelDescription: 'When a focus session finishes',
    importance: Importance.high,
    priority: Priority.high,
  );

  /// Whether this device can show LoopAware notifications at all.
  bool get isSupported => !kIsWeb && Platform.isAndroid;

  Future<bool> _ensureReady() => _ready ??= _init();

  Future<bool> _init() async {
    if (!isSupported) return false;
    try {
      tzdata.initializeTimeZones();
      try {
        final zone = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(zone.identifier));
      } catch (_) {
        // Unknown zone name: fall back to UTC scheduling rather than fail.
      }
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      return true;
    } catch (error) {
      debugPrint('Notifications unavailable: $error');
      return false;
    }
  }

  /// Asks for the Android 13+ notification permission. Returns whether
  /// notifications are allowed.
  Future<bool> requestPermission() async {
    if (!await _ensureReady()) return false;
    try {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Schedules the daily wind-down reminder at [time], replacing any
  /// existing one.
  Future<void> scheduleBedtimeReminder(TimeOfDay time) async {
    if (!await _ensureReady()) return;
    try {
      final now = tz.TZDateTime.now(tz.local);
      var at = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        time.hour,
        time.minute,
      );
      if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
      await _plugin.zonedSchedule(
        id: _bedtimeId,
        scheduledDate: at,
        notificationDetails: const NotificationDetails(android: _reminders),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        title: 'Time to wind down',
        body:
            'Screens after 10pm cut into your sleep. Put the phone on '
            'charge outside the bedroom.',
      );
    } catch (error) {
      debugPrint('Could not schedule reminder: $error');
    }
  }

  Future<void> cancelBedtimeReminder() => _cancel(_bedtimeId);

  Future<void> showGoalExceeded({
    required int totalMinutes,
    required int goalMinutes,
  }) => _show(
    _goalId,
    _alerts,
    'Past your daily goal',
    'You\'ve used your phone for ${Formatters.duration(totalMinutes)} '
        'today — ${Formatters.duration(totalMinutes - goalMinutes)} over '
        'your ${Formatters.duration(goalMinutes)} goal.',
  );

  Future<void> showAppLimitExceeded({
    required int index,
    required String appName,
    required int minutes,
    required int limitMinutes,
  }) => _show(
    _appLimitBaseId + index,
    _alerts,
    '$appName limit reached',
    '${Formatters.duration(minutes)} on $appName today, past your '
        '${Formatters.duration(limitMinutes)} limit.',
  );

  /// Schedules the "session finished" alert for [end], so it fires even if
  /// the app is in the background.
  Future<void> scheduleFocusEnd(DateTime end, int minutes) async {
    if (!await _ensureReady()) return;
    try {
      await _plugin.zonedSchedule(
        id: _focusId,
        scheduledDate: tz.TZDateTime.from(end, tz.local),
        notificationDetails: const NotificationDetails(android: _focus),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: 'Focus session complete',
        body: '${Formatters.duration(minutes)} of focus done. Take a break.',
      );
    } catch (error) {
      debugPrint('Could not schedule focus alert: $error');
    }
  }

  Future<void> cancelFocusEnd() => _cancel(_focusId);

  Future<void> _show(
    int id,
    AndroidNotificationDetails details,
    String title,
    String body,
  ) async {
    if (!await _ensureReady()) return;
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(android: details),
      );
    } catch (error) {
      debugPrint('Could not show notification: $error');
    }
  }

  Future<void> _cancel(int id) async {
    if (!await _ensureReady()) return;
    try {
      await _plugin.cancel(id: id);
    } catch (_) {}
  }
}
