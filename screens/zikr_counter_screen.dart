import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/prefs_keys.dart';
import '../core/date_utils.dart';

class ZikrCounterScreen extends StatefulWidget {
  const ZikrCounterScreen({super.key});

  @override
  State<ZikrCounterScreen> createState() => _ZikrCounterScreenState();
}

class _ZikrCounterScreenState extends State<ZikrCounterScreen>
    with SingleTickerProviderStateMixin {
  late SharedPreferences _prefs;

  // Session state
  int _sessionCount = 0;
  int _target = 33;
  String _phrase = 'Subḥānallāh';
  bool _haptics = true;

  Map<String, int> _todayHistory = {};
  bool _loading = true;

  // Animation
  late AnimationController _ringController;
  double _lastProgress = 0;

  static const _messages = [
    'Keep your heart present 💚',
    'Tongue moist with remembrance 🌿',
    'Angels record each dhikr ✨',
    'Light upon light ☀️',
  ];
  int _messageIndex = 0;

  static const _defaultPhrases = [
    'Subḥānallāh',
    'Alḥamdulillāh',
    'Allāhu Akbar',
    'Lā ilāha illā Allāh',
    'Astaghfirullāh',
  ];

  static const _quickTargets = [33, 99, 100, 1000];

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _load();
  }

  @override
  void dispose() {
    _ringController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    _prefs = await SharedPreferences.getInstance();
    _phrase = _prefs.getString(PrefsKeys.zikrSelectedPhrase) ?? _phrase;
    _target = _prefs.getInt(PrefsKeys.zikrTarget) ?? _target;
    _sessionCount =
        _prefs.getInt(PrefsKeys.zikrSessionCount) ?? 0;
    _haptics = _prefs.getBool(PrefsKeys.zikrHaptics) ?? true;

    final raw = _prefs.getString(PrefsKeys.zikrTodayHistory);
    if (raw != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(raw);
        _todayHistory =
            decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
      } catch (_) {
        _todayHistory = {};
      }
    }
    setState(() => _loading = false);
  }

  // Persistence
  Future<void> _persistSession() async =>
      _prefs.setInt(PrefsKeys.zikrSessionCount, _sessionCount);
  Future<void> _persistPhraseTarget() async {
    await _prefs.setString(PrefsKeys.zikrSelectedPhrase, _phrase);
    await _prefs.setInt(PrefsKeys.zikrTarget, _target);
  }

  Future<void> _persistHistory() async =>
      _prefs.setString(PrefsKeys.zikrTodayHistory, jsonEncode(_todayHistory));

  // Logic
  void _increment({int step = 1}) {
    setState(() {
      _sessionCount += step;
      _todayHistory[_phrase] = (_todayHistory[_phrase] ?? 0) + step;
    });
    _persistSession();
    _persistHistory();
    _animateProgress();
    _checkMilestones();
  }

  void _decrement() {
    if (_sessionCount == 0) return;
    setState(() {
      _sessionCount--;
      final newVal = (_todayHistory[_phrase] ?? 0) - 1;
      if (newVal <= 0) {
        _todayHistory.remove(_phrase);
      } else {
        _todayHistory[_phrase] = newVal;
      }
    });
    _persistSession();
    _persistHistory();
    _animateProgress();
  }

  void _resetSession() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Reset Session'),
        content: Text(
            'Reset current count for “$_phrase”? Daily totals remain.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (ok == true) {
      setState(() => _sessionCount = 0);
      _persistSession();
      _animateProgress();
    }
  }

  void _animateProgress() {
    _lastProgress = _progress();
    _ringController.forward(from: 0);
  }

  double _progress() {
    if (_target <= 0) return 0;
    return (_sessionCount / _target).clamp(0, 1).toDouble();
  }

  void _checkMilestones() {
    if (_haptics) HapticFeedback.lightImpact();
    if ([_target, 33, 99].contains(_sessionCount)) {
      if (_haptics) HapticFeedback.mediumImpact();
      _rotateMessage();
      _showSnack('Milestone: $_sessionCount');
    }
  }

  void _rotateMessage() {
    setState(() => _messageIndex = (_messageIndex + 1) % _messages.length);
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  // UI actions
  Future<void> _changePhrase() async {
    final controller = TextEditingController();
    final chosen = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Select Zikr Phrase',
                      style: Theme.of(ctx).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  ..._defaultPhrases.map((p) => ListTile(
                    title: Text(p),
                    trailing: p == _phrase
                        ? const Icon(Icons.check, color: Colors.green)
                        : null,
                    onTap: () => Navigator.pop(ctx, p),
                  )),
                  const Divider(),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Custom phrase',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (v) {
                      final val = v.trim();
                      if (val.isNotEmpty) Navigator.pop(ctx, val);
                    },
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      final v = controller.text.trim();
                      if (v.isNotEmpty) Navigator.pop(ctx, v);
                    },
                    label: const Text('Use custom'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (chosen != null && chosen != _phrase) {
      setState(() {
        _phrase = chosen;
        _sessionCount = 0; // new session
      });
      _persistPhraseTarget();
      _persistSession();
      _animateProgress();
    }
  }

  Future<void> _changeTarget() async {
    final controller = TextEditingController(text: _target.toString());
    final selected = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Select Target',
                      style: Theme.of(ctx).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _quickTargets
                        .map((t) => ChoiceChip(
                      label: Text(t.toString()),
                      selected: t == _target,
                      onSelected: (_) => Navigator.pop(ctx, t),
                    ))
                        .toList(),
                  ),
                  const Divider(height: 32),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Custom target',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (v) {
                      final val = int.tryParse(v);
                      if (val != null && val > 0) Navigator.pop(ctx, val);
                    },
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () {
                      final v = int.tryParse(controller.text);
                      if (v != null && v > 0) Navigator.pop(ctx, v);
                    },
                    child: const Text('Set custom'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (selected != null && selected != _target) {
      setState(() => _target = selected);
      _persistPhraseTarget();
      _animateProgress();
    }
  }

  void _toggleHaptics() {
    setState(() => _haptics = !_haptics);
    _prefs.setBool(PrefsKeys.zikrHaptics, _haptics);
    _showSnack(_haptics ? 'Haptics enabled' : 'Haptics disabled');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final theme = Theme.of(context);
    final progress = _progress();
    final over = _sessionCount - _target;
    final percentStr = _target == 0
        ? '--'
        : '${((_sessionCount / _target) * 100).clamp(0, 999).toStringAsFixed(0)}%';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top controls
          Row(
            children: [
              Expanded(
                child: Text(
                  'Today: ${DateHelpers.humanToday()}',
                  style: theme.textTheme.labelLarge,
                ),
              ),
              IconButton(
                tooltip: 'Change phrase',
                onPressed: _changePhrase,
                icon: const Icon(Icons.edit_note),
              ),
              IconButton(
                tooltip: 'Change target',
                onPressed: _changeTarget,
                icon: const Icon(Icons.flag_outlined),
              ),
              IconButton(
                tooltip: _haptics ? 'Disable haptics' : 'Enable haptics',
                onPressed: _toggleHaptics,
                icon: Icon(
                  _haptics
                      ? Icons.vibration
                      : Icons.close,
                ),
              ),
              IconButton(
                tooltip: 'Reset session',
                onPressed: _resetSession,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Text(
            _phrase,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: .5,
            ),
          ),
          const SizedBox(height: 12),

          // Progress ring
          Center(
            child: SizedBox(
              height: 210,
              width: 210,
              child: AnimatedBuilder(
                animation: _ringController,
                builder: (ctx, _) {
                  final animValue = CurvedAnimation(
                    parent: _ringController,
                    curve: Curves.easeOutCubic,
                  ).value;
                  final currentProgress =
                      _lastProgress + (progress - _lastProgress) * animValue;

                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      _ProgressRing(progress: currentProgress),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$_sessionCount',
                            style: theme.textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            over > 0
                                ? '+$over over'
                                : 'of $_target ($percentStr)',
                            style: theme.textTheme.labelMedium,
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 6),

          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              _messages[_messageIndex],
              key: ValueKey(_messageIndex),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => _increment(),
                  onLongPress: () => _increment(step: 10),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(70),
                  ),
                  child: const Text('+1', style: TextStyle(fontSize: 28)),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _sessionCount > 0 ? _decrement : null,
                style: ElevatedButton.styleFrom(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
                  shape: const CircleBorder(),
                ),
                child: const Icon(Icons.remove, size: 32),
              ),
            ],
          ),
          const SizedBox(height: 28),

          Text(
            'Today\'s Phrases',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),

          if (_todayHistory.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No zikr recorded yet today.',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            )
          else
            Column(
              children: _todayHistory.entries
                  .toList()
                  .sortedBy((e) => e.key)
                  .map(
                    (e) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(e.key),
                  trailing: Text(
                    e.value.toString(),
                    style: theme.textTheme.labelLarge,
                  ),
                  onTap: () {
                    setState(() {
                      _phrase = e.key;
                      _sessionCount = 0;
                    });
                    _persistPhraseTarget();
                    _persistSession();
                    _animateProgress();
                  },
                ),
              )
                  .toList(),
            ),
          const SizedBox(height: 40), // bottom padding
        ],
      ),
    );
  }
}

/* ----------------------------- Progress Ring ----------------------------- */

class _ProgressRing extends StatelessWidget {
  final double progress; // 0..1
  const _ProgressRing({required this.progress});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ProgressRingPainter(progress),
      child: const SizedBox.expand(),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  final double progress;
  _ProgressRingPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 14.0;
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - stroke) / 2;

    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = Colors.grey.withOpacity(0.18)
      ..strokeCap = StrokeCap.round;

    final fgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: const [
          Color(0xFF4CAF50),
          Color(0xFF2196F3),
          Color(0xFF4CAF50),
        ],
        startAngle: -3.14159 / 2,
        endAngle: -3.14159 / 2 + 6.28318,
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    // background circle
    canvas.drawCircle(center, radius, bgPaint);

    // arc
    final sweep = progress * 6.28318;
    const start = -3.14159 / 2;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter old) =>
      old.progress != progress;
}

/* ----------------------------- Helpers ----------------------------- */

extension _SortExt<E> on List<E> {
  List<E> sortedBy(Comparable Function(E) key) {
    sort((a, b) => key(a).compareTo(key(b)));
    return this;
  }
}
