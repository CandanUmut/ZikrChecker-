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
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
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
      );
    } catch (e) {
      _error = 'Failed: $e';
    }
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final r = _result!;
    final items = r.times;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text("Today's Prayer Times",
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          // Next prayer card
          Card(
            color: Colors.teal.shade50,
            child: ListTile(
              leading: const Icon(Icons.timer),
              title: Text(
                'Next: ${r.nextPrayerName}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'In ${PrayerTimeService.formatDuration(r.timeUntilNext)}',
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...items.entries.map(
                (e) => Card(
              child: ListTile(
                title: Text(e.key),
                trailing: Text(
                  PrayerTimeService.formatTime(e.value),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Method: Muslim World League • Madhab: Shafi\nPull down to refresh.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
