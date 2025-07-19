// core/notification_service.dart
import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );
    tz.initializeTimeZones();
  }

  static Future<void> scheduleDailyReminders() async {
    try {
      // Cancel any existing (avoid duplicates)
      await _plugin.cancelAll();

      final reminders = <_Reminder>[
        _Reminder(
          id: 101,
          hour: 9,
          minute: 0,
          title: 'Daily Zikr',
          body: 'Did you do your daily Zikr?',
        ),
        _Reminder(
          id: 102,
          hour: 18,
          minute: 30,
          title: 'Gratitude',
          body: 'Take a moment for gratitude 🌿',
        ),
      ];

      final now = DateTime.now();

      for (final r in reminders) {
        final first = DateTime(now.year, now.month, now.day, r.hour, r.minute);
        final fire = first.isBefore(now) ? first.add(const Duration(days: 1)) : first;
        final tzTime = tz.TZDateTime.from(fire, tz.local);

        await _plugin.zonedSchedule(
          r.id,
          r.title,
          r.body,
          tzTime,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'daily_channel',
              'Daily Reminders',
              channelDescription: 'Daily zikr and gratitude reminders',
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
          // IMPORTANT: use INEXACT on Android 13/14 to avoid exact alarm permission
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (e) {
      // Swallow to avoid startup crash
      // ignore: avoid_print
      print('Notification schedule failed (ignored): $e');
    }
  }
}

class _Reminder {
  final int id;
  final int hour;
  final int minute;
  final String title;
  final String body;
  _Reminder({
    required this.id,
    required this.hour,
    required this.minute,
    required this.title,
    required this.body,
  });
}
