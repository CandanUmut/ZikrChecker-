# ZikrChecker-
Check out how you’re doing 


Below is a complete, self-contained Flutter project outline for ZikrChecker with all requested features. You can copy these files into a new Flutter project. I’ve aimed for clarity, modularity, and offline functionality. Prayer times are calculated locally using the adhan_dart package (fully offline). Qibla direction uses flutter_qiblah. Daily reset logic + zikr counter + tasks use SharedPreferences. Local notifications scheduled once on first launch (you can reschedule on each day change if desired).

Folder structure

zikr_checker/
  pubspec.yaml
  android/ ... (standard – only note extra config below)
  ios/ ...      (standard – plus perms in Info.plist)
  lib/
    main.dart
    core/
      app_theme.dart
      constants.dart
      prefs_keys.dart
      prayer_time_service.dart
      notification_service.dart
      date_utils.dart
    screens/
      home_screen.dart
      zikr_counter_screen.dart
      prayer_times_screen.dart
      qibla_screen.dart
      debug_prefs_screen.dart
    widgets/
      task_toggle_tile.dart
      section_card.dart



⸻

pubspec.yaml

name: zikr_checker
description: Offline Islamic daily tracker & zikr counter.
publish_to: "none"
version: 1.0.0+1

environment:
  sdk: ">=3.3.0 <4.0.0"

dependencies:
  flutter: 
    sdk: flutter
  shared_preferences: ^2.2.3
  adhan_dart: ^2.0.0
  geolocator: ^11.0.0
  flutter_qiblah: ^2.3.0
  permission_handler: ^11.3.0
  flutter_local_notifications: ^17.1.0
  intl: ^0.19.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0

flutter:
  uses-material-design: true
  assets:
    - assets/ (create folder if you want images; currently unused)

Run flutter pub get after creating.

⸻

Android Permissions & Setup

android/app/src/main/AndroidManifest.xml (add inside <manifest> where appropriate)

<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-feature android:name="android.hardware.location.gps"/>
<uses-feature android:name="android.hardware.sensor.compass"/>

<!-- Inside <application> add service & receiver for notifications (flutter_local_notifications handles). -->

For Android 13+ notifications permission is requested in code.

⸻

iOS Permissions

ios/Runner/Info.plist add keys:

<key>NSLocationWhenInUseUsageDescription</key>
<string>Needed to calculate prayer times and Qibla direction.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Needed to calculate prayer times and Qibla direction.</string>
<key>UIBackgroundModes</key>
<array>
  <string>location</string>
</array>

If on iOS 10+, local notifications are configured automatically; no extra plist keys needed besides request code.

⸻

lib/core/constants.dart

class AppStrings {
  static const appTitle = 'ZikrChecker';
  static const tasksTitle = '🕊️ Daily Spiritual Actions';
  static const zikrCounterTitle = 'Zikr Counter';
  static const prayerTimesTitle = 'Prayer Times';
  static const qiblaTitle = 'Qibla';
}

class DailyTasks {
  static const repentance = 'Repentance';
  static const quranReading = 'Qur\'an Reading';
  static const salawat = 'Sending Salawat';
  static const gratitude = 'Gratitude';
  static const goodDeeds = 'Doing Good Deeds';

  static const all = [
    repentance,
    quranReading,
    salawat,
    gratitude,
    goodDeeds,
  ];
}

lib/core/prefs_keys.dart

class PrefsKeys {
  static const lastDate = 'last_date_yyyyMMdd';
  static const zikrCount = 'zikr_count';
  static String taskKey(String name) => 'task_${name.replaceAll(" ", "_")}';
}

lib/core/date_utils.dart

import 'package:intl/intl.dart';

class DateHelpers {
  static final _fmt = DateFormat('yyyyMMdd');
  static String todayKey() => _fmt.format(DateTime.now());
  static String humanToday() => DateFormat('MMMM d, yyyy').format(DateTime.now());
}

lib/core/app_theme.dart

import 'package:flutter/material.dart';

ThemeData buildLightTheme() {
  final base = ThemeData.light(useMaterial3: true);
  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: Colors.teal,
      secondary: Colors.tealAccent,
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
    ),
    scaffoldBackgroundColor: const Color(0xFFF7F9FA),
    cardTheme: CardTheme(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
    ),
    switchTheme: base.switchTheme.copyWith(
      thumbIcon: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? const Icon(Icons.check, size: 14)
            : const Icon(Icons.circle_outlined, size: 12),
      ),
    ),
  );
}

lib/core/notification_service.dart

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Simple wrapper to schedule two daily reminders.
/// Called once after permissions & maybe daily when date changes.
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _plugin.initialize(const InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    ));
    tz.initializeTimeZones();
  }

  static Future<void> scheduleDailyReminders() async {
    // Cancel old to avoid duplicates if rescheduling.
    await _plugin.cancelAll();

    final now = DateTime.now();
    // Choose gentle times (customizable)
    final reminders = <_ReminderSpec>[
      _ReminderSpec(
        id: 1,
        hour: 9,
        minute: 0,
        title: 'Daily Zikr',
        body: 'Did you do your daily Zikr?',
      ),
      _ReminderSpec(
        id: 2,
        hour: 18,
        minute: 30,
        title: 'Gratitude',
        body: 'Take a moment for gratitude 🌿',
      ),
    ];

    for (final r in reminders) {
      final schedule = DateTime(
        now.year, now.month, now.day, r.hour, r.minute,
      );
      final first = schedule.isBefore(now) ? schedule.add(const Duration(days:1)) : schedule;
      final tzTime = tz.TZDateTime.from(first, tz.local);
      await _plugin.zonedSchedule(
        r.id,
        r.title,
        r.body,
        tzTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_channel',
            'Daily Reminders',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }
}

class _ReminderSpec {
  final int id;
  final int hour;
  final int minute;
  final String title;
  final String body;
  _ReminderSpec({
    required this.id,
    required this.hour,
    required this.minute,
    required this.title,
    required this.body,
  });
}

lib/core/prayer_time_service.dart

import 'package:adhan_dart/adhan_dart.dart';
import 'package:intl/intl.dart';

class PrayerTimeResult {
  final Map<String, DateTime> times;
  PrayerTimeResult(this.times);
}

class PrayerTimeService {
  static PrayerTimeResult calculate(
      {required double latitude,
       required double longitude,
       required double elevation}) {
    // Calculation parameters (you can tune to your local convention).
    final params = CalculationMethod.MuslimWorldLeague();
    params.madhab = Madhab.Shafi;
    final date = DateComponents.from(DateTime.now());
    final coords = Coordinates(latitude, longitude);
    final prayerTimes = PrayerTimes(coords, date, params, utcOffset: DateTime.now().timeZoneOffset);
    final formatTimes = {
      'Fajr': prayerTimes.fajr!,
      'Dhuhr': prayerTimes.dhuhr!,
      'Asr': prayerTimes.asr!,
      'Maghrib': prayerTimes.maghrib!,
      'Isha': prayerTimes.isha!,
    };
    return PrayerTimeResult(formatTimes);
  }

  static String format(DateTime dt) => DateFormat('HH:mm').format(dt);
}



⸻

lib/widgets/section_card.dart

import 'package:flutter/material.dart';

class SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

lib/widgets/task_toggle_tile.dart

import 'package:flutter/material.dart';

class TaskToggleTile extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const TaskToggleTile({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }
}



⸻

lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../core/prefs_keys.dart';
import '../core/date_utils.dart';
import '../widgets/task_toggle_tile.dart';
import '../widgets/section_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late SharedPreferences _prefs;
  final Map<String, bool> _taskStates = { for (var t in DailyTasks.all) t: false };
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    // Task states were already reset in main if needed; just load.
    for (final t in DailyTasks.all) {
      _taskStates[t] = _prefs.getBool(PrefsKeys.taskKey(t)) ?? false;
    }
    setState(() => _loading = false);
  }

  Future<void> _toggle(String task, bool val) async {
    setState(() => _taskStates[task] = val);
    await _prefs.setBool(PrefsKeys.taskKey(task), val);
  }

  Future<void> _resetAll() async {
    for (final t in DailyTasks.all) {
      _taskStates[t] = false;
      await _prefs.setBool(PrefsKeys.taskKey(t), false);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: () async => _resetAll(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text("Today: ${DateHelpers.humanToday()}",
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
            SectionCard(
              title: AppStrings.tasksTitle,
              child: Column(
                children: DailyTasks.all.map((t) =>
                  TaskToggleTile(
                    label: t,
                    value: _taskStates[t] ?? false,
                    onChanged: (v) => _toggle(t, v),
                  )
                ).toList(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Pull down to reset all tasks for today (or will auto-reset tomorrow).",
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}



⸻

lib/screens/zikr_counter_screen.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/prefs_keys.dart';
import '../core/date_utils.dart';

class ZikrCounterScreen extends StatefulWidget {
  const ZikrCounterScreen({super.key});

  @override
  State<ZikrCounterScreen> createState() => _ZikrCounterScreenState();
}

class _ZikrCounterScreenState extends State<ZikrCounterScreen> {
  late SharedPreferences _prefs;
  int _count = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _prefs = await SharedPreferences.getInstance();
    _count = _prefs.getInt(PrefsKeys.zikrCount) ?? 0;
    setState(() => _loading = false);
  }

  Future<void> _increment() async {
    setState(() => _count++);
    await _prefs.setInt(PrefsKeys.zikrCount, _count);
  }

  Future<void> _reset() async {
    setState(() => _count = 0);
    await _prefs.setInt(PrefsKeys.zikrCount, 0);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text("Today: ${DateHelpers.humanToday()}",
              style: Theme.of(context).textTheme.labelLarge),
          const Spacer(),
          Text('Zikr Count', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          Text('$_count',
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.bold,
              )),
          const SizedBox(height: 40),
          FilledButton(
            onPressed: _increment,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 70),
            ),
            child: const Text('+1', style: TextStyle(fontSize: 28)),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.refresh),
            label: const Text('Reset'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
            ),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}



⸻

lib/screens/prayer_times_screen.dart

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../core/prayer_time_service.dart';

class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key});
  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> {
  bool _loading = true;
  String? _error;
  PrayerTimeResult? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final perm = await Geolocator.checkPermission();
      LocationPermission finalPerm = perm;
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        finalPerm = await Geolocator.requestPermission();
      }
      if (finalPerm == LocationPermission.denied ||
          finalPerm == LocationPermission.deniedForever) {
        setState(() {
          _error = 'Location permission denied.';
          _loading = false;
        });
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      _result = PrayerTimeService.calculate(
        latitude: pos.latitude,
        longitude: pos.longitude,
        elevation: pos.altitude,
      );
    } catch (e) {
      _error = 'Failed: $e';
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Retry'))
          ],
        ),
      );
    }
    final items = _result!.times;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text("Today's Prayer Times",
            style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          ...items.entries.map((e) => Card(
            child: ListTile(
              title: Text(e.key),
              trailing: Text(PrayerTimeService.format(e.value),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          )),
          const SizedBox(height: 12),
          Text(
            'Calculated locally (Muslim World League method). Pull down to refresh.',
            style: Theme.of(context).textTheme.bodySmall,
          )
        ],
      ),
    );
  }
}



⸻

lib/screens/qibla_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_qiblah/flutter_qiblah.dart';
import 'package:permission_handler/permission_handler.dart';

class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  bool _permissionsGranted = false;

  @override
  void initState() {
    super.initState();
    _initPermissions();
  }

  Future<void> _initPermissions() async {
    final locStatus = await Permission.locationWhenInUse.request();
    final sensorStatus = await Permission.sensors.request(); // optional depending on plugin
    setState(() {
      _permissionsGranted = locStatus.isGranted && !sensorStatus.isDenied;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_permissionsGranted) {
      return Center(
        child: ElevatedButton(
          onPressed: _initPermissions,
          child: const Text('Grant Permissions'),
        ),
      );
    }

    return StreamBuilder<QiblahDirection>(
      stream: FlutterQiblah.qiblahStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final direction = snapshot.data!;
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Transform.rotate(
                angle: (direction.qiblah * (3.141592653589793 / 180) * -1),
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.teal, width: 4),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'Kaaba',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('Direction: ${direction.qiblah.toStringAsFixed(2)}°',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text('North offset: ${direction.direction.toStringAsFixed(2)}°'),
            ],
          ),
        );
      },
    );
  }
}



⸻

lib/screens/debug_prefs_screen.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DebugPrefsScreen extends StatefulWidget {
  const DebugPrefsScreen({super.key});
  @override
  State<DebugPrefsScreen> createState() => _DebugPrefsScreenState();
}

class _DebugPrefsScreenState extends State<DebugPrefsScreen> {
  Map<String, Object?> _values = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final map = <String, Object?>{};
    for (final k in keys) {
      map[k] = prefs.get(k);
    }
    setState(() {
      _values = map;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final entries = _values.entries.toList()
      ..sort((a,b) => a.key.compareTo(b.key));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        itemCount: entries.length,
        itemBuilder: (c, i) {
          final e = entries[i];
          return ListTile(
            title: Text(e.key),
            subtitle: Text('${e.value}'),
          );
        },
      ),
    );
  }
}



⸻

lib/main.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/app_theme.dart';
import 'core/constants.dart';
import 'core/prefs_keys.dart';
import 'core/date_utils.dart';
import 'core/notification_service.dart';

import 'screens/home_screen.dart';
import 'screens/zikr_counter_screen.dart';
import 'screens/prayer_times_screen.dart';
import 'screens/qibla_screen.dart';
import 'screens/debug_prefs_screen.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  await _dailyResetIfNeeded(prefs);
  await NotificationService.init();
  await _ensureNotificationPermission();
  await NotificationService.scheduleDailyReminders();

  runApp(const ZikrCheckerApp());
}

/// Reset tasks + zikr counter when date changes
Future<void> _dailyResetIfNeeded(SharedPreferences prefs) async {
  final todayKey = DateHelpers.todayKey();
  final stored = prefs.getString(PrefsKeys.lastDate);
  if (stored != todayKey) {
    // Reset tasks
    for (final t in DailyTasks.all) {
      await prefs.setBool(PrefsKeys.taskKey(t), false);
    }
    await prefs.setInt(PrefsKeys.zikrCount, 0);
    await prefs.setString(PrefsKeys.lastDate, todayKey);
  }
}

Future<void> _ensureNotificationPermission() async {
  if (Platform.isAndroid) {
    // Android 13+ runtime notification permission
    final status = await Permission.notification.status;
    if (status.isDenied) {
      await Permission.notification.request();
    }
  }
  if (Platform.isIOS) {
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }
}

class ZikrCheckerApp extends StatefulWidget {
  const ZikrCheckerApp({super.key});

  @override
  State<ZikrCheckerApp> createState() => _ZikrCheckerAppState();
}

class _ZikrCheckerAppState extends State<ZikrCheckerApp> {
  int _index = 0;

  final _screens = const [
    HomeScreen(),
    ZikrCounterScreen(),
    PrayerTimesScreen(),
    QiblaScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appTitle,
      theme: buildLightTheme(),
      home: Scaffold(
        appBar: AppBar(
          title: Text(AppStrings.appTitle),
          actions: [
            IconButton(
              tooltip: 'Debug Prefs',
              icon: const Icon(Icons.bug_report_outlined),
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const DebugPrefsScreen(),
                ));
              },
            )
          ],
        ),
        body: _screens[_index],
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.check_circle_outline),
                  selectedIcon: Icon(Icons.check_circle),
                  label: 'Home'),
              NavigationDestination(
                  icon: Icon(Icons.countertops),
                  selectedIcon: Icon(Icons.plus_one),
                  label: 'Zikr'),
              NavigationDestination(
                  icon: Icon(Icons.schedule),
                  selectedIcon: Icon(Icons.access_time_filled),
                  label: 'Times'),
              NavigationDestination(
                  icon: Icon(Icons.explore_outlined),
                  selectedIcon: Icon(Icons.explore),
                  label: 'Qibla'),
            ],
        ),
      ),
    );
  }
}



⸻

Notes & Best Practice Considerations

Area	Explanation / Next Steps
State Management	Simple StatefulWidget is sufficient; could evolve to Riverpod if complexity grows.
Local Notification Rescheduling	Currently scheduled on startup; if you want different times per user, persist times & reschedule after daily reset.
Location & Compass	flutter_qiblah internally handles sensor streams. Ensure device supports magnetometer.
Error Handling	Minimal; consider adding user-friendly snackbars for permission denials.
Prayer Calculation Parameters	Chosen Muslim World League + Shafi; adjust to local fiqh preferences.
Background	App is offline: all logic is local; no network calls used.
Testing	Add widget tests for persistent states & daily reset.
Internationalization	Use intl extension; for multi-language support add AR/EN localization.



⸻

Quick Start

flutter create zikr_checker
# Replace lib/ and pubspec.yaml with above content (merge dependencies)
flutter pub get
flutter run



⸻

If you’d like additional enhancements (dark mode, Tasbih vibration feedback, custom zikr sets, statistics page, streak tracking, export/import), just ask and we can iterate.

Let me know if you want this converted into a single-file minimal version or expanded with tests. 🤍

Would you like a follow-up step adding streak tracking or custom reminders next?
