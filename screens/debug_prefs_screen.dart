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
