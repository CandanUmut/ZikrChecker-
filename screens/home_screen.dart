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
