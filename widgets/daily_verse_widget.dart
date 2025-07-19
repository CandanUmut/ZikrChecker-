import 'dart:math';
import 'package:flutter/material.dart';
import 'package:quran/quran.dart' as quran;
import 'package:shared_preferences/shared_preferences.dart';

class DailyVerseWidget extends StatefulWidget {
  final String translationLang; // 'en' or 'tr'
  const DailyVerseWidget({super.key, required this.translationLang});

  @override
  State<DailyVerseWidget> createState() => _DailyVerseWidgetState();
}

class _DailyVerseWidgetState extends State<DailyVerseWidget> {
  late DateTime _today;
  int? _surahNumber;
  int? _ayahNumber;
  String? _arabic;
  String? _translation;

  @override
  void initState() {
    super.initState();
    _today = DateTime.now();
    _loadDaily();
  }

  Future<void> _loadDaily() async {
    // Deterministic "random" verse of day using day-of-year seed
    final dayOfYear = int.parse(
        DateTime.now().difference(DateTime(DateTime.now().year)).inDays.toString());
    final totalAyat = 6236; // total Quran verses
    final rand = Random(dayOfYear + DateTime.now().year);
    final globalAyahIndex = rand.nextInt(totalAyat) + 1; // 1-based
    // Convert global index to (surah, ayah)
    int cumulative = 0;
    for (int s = 1; s <= 114; s++) {
      final c = quran.getVerseCount(s);
      if (globalAyahIndex <= cumulative + c) {
        _surahNumber = s;
        _ayahNumber = globalAyahIndex - cumulative;
        break;
      }
      cumulative += c;
    }
    if (_surahNumber == null) {
      _surahNumber = 1;
      _ayahNumber = 1;
    }
    _arabic = quran.getVerse(_surahNumber!, _ayahNumber!);
    _translation = _getTranslation(_surahNumber!, _ayahNumber!);

    // (Optional) cache in SharedPreferences for the day so it doesn't "jump"
    final prefs = await SharedPreferences.getInstance();
    final keyDate = "${_today.year}-${_today.month}-${_today.day}";
    await prefs.setString('daily_verse_date', keyDate);
    await prefs.setInt('daily_verse_surah', _surahNumber!);
    await prefs.setInt('daily_verse_ayah', _ayahNumber!);

    setState(() {});
  }

  String _getTranslation(int surah, int ayah) {
    // The `quran` package ships English translation via getVerseTranslation.
    // For Turkish (simple approach), we map to English fallback or add limited examples.
    if (widget.translationLang == 'tr') {
      // For a real app supply a proper Turkish dataset. Placeholder fallback:
      return quran.getVerseTranslation(surah, ayah); // fallback English
    }
    return quran.getVerseTranslation(surah, ayah);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_arabic == null) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Daily Verse • ${_formatDate(_today)}',
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: theme.colorScheme.primary)),
            const SizedBox(height: 12),
            Text(
              _arabic!,
              textDirection: TextDirection.rtl,
              style: theme.textTheme.titleLarge?.copyWith(
                fontFamily: 'Scheherazade',
                height: 1.6,
                fontSize: 24,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _translation!,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '(${_surahNumber}:${_ayahNumber}) '
                    '${quran.getSurahName(_surahNumber!)}',
                style: theme.textTheme.labelSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
}
