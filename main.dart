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
import 'screens/quran_reader_page.dart';

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

  late final List<Widget> _screens = [
    const HomeScreen(),
    const ZikrCounterScreen(),
    const PrayerTimesScreen(),
    const QiblaScreen(),
    const QuranReaderPage(),  // <-- NEW
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
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DebugPrefsScreen()),
                );
              },
            ),
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
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.countertops),
              selectedIcon: Icon(Icons.plus_one),
              label: 'Zikr',
            ),
            NavigationDestination(
              icon: Icon(Icons.schedule),
              selectedIcon: Icon(Icons.access_time_filled),
              label: 'Times',
            ),
            NavigationDestination(
              icon: Icon(Icons.explore_outlined),
              selectedIcon: Icon(Icons.explore),
              label: 'Qibla',
            ),
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book),
              label: 'Qur\'an',
            ),
          ],
        ),
      ),
    );
  }
}
