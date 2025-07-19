import 'package:flutter/material.dart';
import 'package:characters/characters.dart';
import 'package:quran/quran.dart' as quran;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zikr_checker/widgets/daily_verse_widget.dart';

class QuranReaderPage extends StatefulWidget {
  const QuranReaderPage({super.key});

  @override
  State<QuranReaderPage> createState() => _QuranReaderPageState();
}

class _QuranReaderPageState extends State<QuranReaderPage> {
  // UI / list state
  String _searchQuery = '';
  bool _showList = true;

  // Reading position
  int _currentSurah = 1;
  int _currentAyah = 1;
  late int _totalAyatCurrent;

  // Preferences
  String _translationLang = 'en'; // 'en' | 'tr' (fallback)
  bool _showTransliteration = true;
  bool _asciiTranslit = false; // long press toggle
  bool _translitInfoShown = false;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _totalAyatCurrent = quran.getVerseCount(_currentSurah);
    _restoreState();
  }

  Future<void> _restoreState() async {
    final prefs = await SharedPreferences.getInstance();
    _currentSurah = prefs.getInt('last_surah') ?? 1;
    _currentAyah = prefs.getInt('last_ayah') ?? 1;
    _translationLang = prefs.getString('pref_translation_lang') ?? 'en';
    _showTransliteration =
        prefs.getBool('pref_show_transliteration') ?? true;
    _asciiTranslit = prefs.getBool('pref_ascii_translit') ?? false;
    _translitInfoShown = prefs.getBool('pref_translit_info_shown') ?? false;
    _totalAyatCurrent = quran.getVerseCount(_currentSurah);
    setState(() => _loading = false);

    // Eğer transliterasyon açık ve bilgi daha önce gösterilmediyse açılışta göster
    if (_showTransliteration && !_translitInfoShown) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showTranslitInfoDialog();
      });
    }
  }

  Future<void> _persistReading() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_surah', _currentSurah);
    await prefs.setInt('last_ayah', _currentAyah);
  }

  Future<void> _persistPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pref_translation_lang', _translationLang);
    await prefs.setBool('pref_show_transliteration', _showTransliteration);
    await prefs.setBool('pref_ascii_translit', _asciiTranslit);
    await prefs.setBool('pref_translit_info_shown', _translitInfoShown);
  }

  void _openSurah(int surah) {
    setState(() {
      _currentSurah = surah;
      _totalAyatCurrent = quran.getVerseCount(surah);
      _currentAyah = 1;
      _showList = false;
    });
    _persistReading();
  }

  void _nextAyah() {
    setState(() {
      if (_currentAyah < _totalAyatCurrent) {
        _currentAyah++;
      } else if (_currentSurah < 114) {
        _currentSurah++;
        _totalAyatCurrent = quran.getVerseCount(_currentSurah);
        _currentAyah = 1;
      }
    });
    _persistReading();
  }

  void _prevAyah() {
    setState(() {
      if (_currentAyah > 1) {
        _currentAyah--;
      } else if (_currentSurah > 1) {
        _currentSurah--;
        _totalAyatCurrent = quran.getVerseCount(_currentSurah);
        _currentAyah = quran.getVerseCount(_currentSurah);
      }
    });
    _persistReading();
  }

  String _arabic() => quran.getVerse(_currentSurah, _currentAyah);

  String _translation() {
    final base = quran.getVerseTranslation(_currentSurah, _currentAyah);
    if (_translationLang == 'tr') return '[TR Fallback] $base';
    return base;
  }

  bool _showBasmala() =>
      _currentAyah == 1 && _currentSurah != 1 && _currentSurah != 9;

  String get _basmala => 'بِسْمِ ٱللّٰهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ';

  List<int> get _filteredSurahs {
    if (_searchQuery.trim().isEmpty) {
      return List<int>.generate(114, (i) => i + 1);
    }
    final q = _searchQuery.toLowerCase();
    return List<int>.generate(114, (i) => i + 1).where((s) {
      return quran.getSurahName(s).toLowerCase().contains(q) ||
          quran.getSurahNameEnglish(s).toLowerCase().contains(q);
    }).toList();
  }

  // ─────────────── Advanced Transliteration ───────────────
  static final RegExp _allMarks = RegExp(
      r'[\u0610-\u061A\u064B-\u065F\u0660-\u0669\u06D6-\u06ED\u0670\u06E0\u06E2\u06E3\u06E5\u06E6]');

  static const Set<String> _sunLetters = {
    'ت','ث','د','ذ','ر','ز','س','ش','ص','ض','ط','ظ','ل','ن'
  };

  static final Map<String, String> _overrideWords = {
    'بسم': 'bismi',
    'الحمد': 'al-ḥamd',
    'لله': 'lillāh',
    'الله': 'allāh',
    'الرحمن': 'ar-raḥmān',
    'الرحيم': 'ar-raḥīm',
    'مالك': 'mālik',
    'يوم': 'yawm',
    'الدين': 'ad-dīn',
    'العالمين': 'al-ʿālamīn',
    'رب': 'rabb',
  };

  String _normalize(String s) {
    return s
        .replaceAll('ٱ', 'ا')
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي')
        .replaceAll('ـ', '')
        .replaceAll('ّ', '\u0001') // shadda marker
        .replaceAll(_allMarks, '');
  }

  String _transliterateVerse(String input) {
    final norm = _normalize(input);
    final words = norm.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final outWords = <String>[];

    for (final w in words) {
      outWords.add(_transliterateWord(w));
    }

    var result = outWords.join(' ');

    result = result.replaceAll(RegExp(r'\bbi ismi\b'), 'bismi');
    result = result.replaceAll(RegExp(r'\blil lāh\b'), 'lillāh');
    result = result.replaceAll(RegExp(r'\brabb il-ʿ'), 'rabbil-ʿ');
    result = result.replaceAll(RegExp(r'\byawm i d-dīn\b'), 'yawmi d-dīn');

    result = result.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (_asciiTranslit) {
      result = result
          .replaceAll('ā', 'a')
          .replaceAll('ī', 'i')
          .replaceAll('ū', 'u')
          .replaceAll('ḥ', 'h')
          .replaceAll('ṣ', 's')
          .replaceAll('ḍ', 'd')
          .replaceAll('ṭ', 't')
          .replaceAll('ẓ', 'z')
          .replaceAll('ʿ', '`')
          .replaceAll('‘', '`');
    }

    return result;
  }

  String _transliterateWord(String w) {
    if (w.isEmpty) return '';

    // Direct dictionary override
    final override = _overrideWords[w];
    if (override != null) return override;

    // Allah forms
    if (w == 'له' || w == 'لله') return 'lillāh';
    if (w.contains('الله')) return 'allāh';

    // Definite article handling
    if (w.startsWith('ال') && w.length > 2) {
      final second = w[2];
      final rest = w.substring(2);
      if (_sunLetters.contains(second)) {
        // Sun-letter assimilation: al + r → ar-r...
        final firstCons = _mapChar(second); // e.g. 'r'
        return 'a$firstCons-${_raw(rest)}';  // <-- fixed interpolation
      } else {
        return 'al-${_raw(rest)}';
      }
    }

    // Fallback raw mapping
    return _raw(w);
  }


  String _raw(String w) {
    final chars = w.characters.toList();
    final out = StringBuffer();
    for (var i = 0; i < chars.length; i++) {
      final ch = chars[i];
      if (ch == '\u0001') {
        // shadda marker
        final prev = out.isNotEmpty ? out.toString()[out.length - 1] : '';
        if (prev.isNotEmpty && RegExp(r'[a-zʿ’]').hasMatch(prev)) out.write(prev);
        continue;
      }
      out.write(_mapChar(ch));
    }
    return out.toString();
  }

  String _mapChar(String ch) {
    const map = {
      'ا': 'ā','ب': 'b','ت': 't','ث': 'th','ج': 'j','ح': 'ḥ','خ': 'kh',
      'د': 'd','ذ': 'dh','ر': 'r','ز': 'z','س': 's','ش': 'sh','ص': 'ṣ',
      'ض': 'ḍ','ط': 'ṭ','ظ': 'ẓ','ع': 'ʿ','غ': 'gh','ف': 'f','ق': 'q',
      'ك': 'k','ل': 'l','م': 'm','ن': 'n','ه': 'h','و': 'w','ي': 'y',
      'ء': '’','ؤ': '’','ئ': '’','ى': 'ā','ة': 'h',
    };
    return map[ch] ?? '';
  }

  String _transliterateDisplayed(String arabic) {
    try {
      return _transliterateVerse(arabic);
    } catch (_) {
      return '';
    }
  }

  // ─────────────── Info Dialog ───────────────
  Future<void> _showTranslitInfoDialog() async {
    final theme = Theme.of(context);
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('About Transliteration'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This transliteration is generated locally using rules + a small word list. '
                    'Short vowels (a, i, u) are mostly absent in the consonant-only Arabic script; '
                    'so some syllables are approximated.\n',
                style: theme.textTheme.bodyMedium,
              ),
              Text(
                'We DO handle:\n• Common words: bismi, allāh, ar-raḥmān, ar-raḥīm\n'
                    '• Sun-letter assimilation (al + r → ar-r…)\n'
                    '• Long vowels ā, ī, ū\n• Basic shadda doubling\n',
                style: theme.textTheme.bodySmall,
              ),
              Text(
                'We may NOT always get:\n• Perfect short vowels in rare words\n'
                    '• Full tajwīd nuances or pause rules\n• Complex sandhi between words',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Text(
                'If exact recitation practice is required, please rely on a teacher or a fully vocalized Mushaf.',
                style: theme.textTheme.bodySmall!
                    .copyWith(color: theme.colorScheme.primary),
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('ASCII (simplified) mode'),
                subtitle: const Text('Remove ḥ / ṣ / ṭ etc.'),
                value: _asciiTranslit,
                onChanged: (v) {
                  setState(() => _asciiTranslit = v);
                },
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show transliteration'),
                value: _showTransliteration,
                onChanged: (v) {
                  setState(() => _showTransliteration = v);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'close'),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (res != null) {
      _translitInfoShown = true;
      _persistPrefs();
    }
  }

  void _toggleTransliteration() {
    setState(() => _showTransliteration = !_showTransliteration);
    if (_showTransliteration && !_translitInfoShown) {
      // Show info immediately on first enable
      Future.microtask(_showTranslitInfoDialog);
    }
    _persistPrefs();
  }

  void _toggleAsciiTranslit() {
    setState(() => _asciiTranslit = !_asciiTranslit);
    _persistPrefs();
  }

  // Language selection
  void _chooseLanguage() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 4),
            Text('Select Translation',
                style: Theme.of(ctx).textTheme.titleMedium),
            const Divider(),
            RadioListTile<String>(
              value: 'en',
              groupValue: _translationLang,
              title: const Text('English'),
              onChanged: (v) => Navigator.pop(ctx, v),
            ),
            RadioListTile<String>(
              value: 'tr',
              groupValue: _translationLang,
              title: const Text('Türkçe (English fallback)'),
              onChanged: (v) => Navigator.pop(ctx, v),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
    if (selected != null && selected != _translationLang) {
      setState(() => _translationLang = selected);
      _persistPrefs();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Qur\'an'),
        actions: [
          IconButton(
            tooltip: 'Change translation',
            onPressed: _chooseLanguage,
            icon: const Icon(Icons.language),
          ),
          GestureDetector(
            onLongPress: _toggleAsciiTranslit,
            child: IconButton(
              tooltip: _showTransliteration
                  ? 'Hide transliteration'
                  : 'Show transliteration',
              onPressed: _toggleTransliteration,
              icon: Icon(
                _showTransliteration
                    ? Icons.visibility
                    : Icons.visibility_outlined,
              ),
            ),
          ),
          if (_showTransliteration) // Info icon to re-open dialog
            IconButton(
              tooltip: 'Transliteration info',
              onPressed: _showTranslitInfoDialog,
              icon: const Icon(Icons.info_outline),
            ),
          IconButton(
            tooltip: _showList ? 'Go to reading' : 'Surah list',
            onPressed: () => setState(() => _showList = !_showList),
            icon: Icon(_showList ? Icons.menu_book : Icons.list),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: DailyVerseWidget(translationLang: _translationLang),
          ),
          if (_showList)
            ..._buildSurahList(theme)
          else
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: _buildReader(theme),
              ),
            ),
        ],
      ),
      bottomNavigationBar: !_showList ? _readerNav(theme) : null,
    );
  }

  List<Widget> _buildSurahList(ThemeData theme) {
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        sliver: SliverToBoxAdapter(
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search Surah...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
        ),
      ),
      SliverList.builder(
        itemCount: _filteredSurahs.length,
        itemBuilder: (context, index) {
          final s = _filteredSurahs[index];
          final ayat = quran.getVerseCount(s);
          return ListTile(
            title: Text(
              '${quran.getSurahName(s)}  (${quran.getSurahNameEnglish(s)})',
              style: theme.textTheme.bodyLarge,
            ),
            subtitle: Text('$ayat verses'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _openSurah(s),
          );
        },
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 80)),
    ];
  }

  Widget _buildReader(ThemeData theme) {
    final arabic = _arabic();
    final translation = _translation();
    final translit =
    _showTransliteration ? _transliterateDisplayed(arabic) : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${quran.getSurahName(_currentSurah)} '
              '(${quran.getSurahNameEnglish(_currentSurah)})',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Ayah $_currentAyah / $_totalAyatCurrent',
                style: theme.textTheme.labelMedium),
            const SizedBox(width: 12),
            TextButton(onPressed: _chooseAyah, child: const Text('Jump')),
          ],
        ),
        const SizedBox(height: 12),
        if (_showBasmala()) ...[
          Text(
            _basmala,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontFamily: 'Scheherazade',
              fontSize: 22,
              height: 1.8,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
        ],
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant
                .withOpacity(theme.brightness == Brightness.light ? 0.4 : 0.2),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(18),
          child: SelectableText(
            arabic,
            textDirection: TextDirection.rtl,
            style: theme.textTheme.titleLarge?.copyWith(
              fontFamily: 'Scheherazade',
              fontSize: 26,
              height: 1.9,
            ),
          ),
        ),
        if (_showTransliteration && translit.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            translit,
            textAlign: TextAlign.left,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontStyle: FontStyle.italic,
              height: 1.5,
              color: theme.colorScheme.primary,
            ),
          ),
          if (_asciiTranslit)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'ASCII mode',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.primary),
              ),
            ),
        ],
        const SizedBox(height: 18),
        Text(
          translation,
          style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.arrow_back),
              label: const Text('Prev'),
              onPressed: _prevAyah,
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Next'),
              onPressed: _nextAyah,
            ),
            OutlinedButton(
              onPressed: () {
                setState(() => _currentAyah = 1);
                _persistReading();
              },
              child: const Text('Start of Surah'),
            ),
            OutlinedButton(
              onPressed: () {
                setState(() => _currentAyah = _totalAyatCurrent);
                _persistReading();
              },
              child: const Text('End of Surah'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _readerNav(ThemeData theme) {
    return BottomAppBar(
      height: 66,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(
            tooltip: 'Previous Ayah',
            onPressed: _prevAyah,
            icon: const Icon(Icons.skip_previous),
          ),
          Text('$_currentSurah:$_currentAyah',
              style: theme.textTheme.titleMedium),
          IconButton(
            tooltip: 'Next Ayah',
            onPressed: _nextAyah,
            icon: const Icon(Icons.skip_next),
          ),
        ],
      ),
    );
  }

  Future<void> _chooseAyah() async {
    final selected = await showDialog<int>(
      context: context,
      builder: (ctx) {
        int tempAyah = _currentAyah;
        return AlertDialog(
          title: const Text('Jump to Ayah'),
          content: StatefulBuilder(
            builder: (c, setS) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Slider(
                  min: 1,
                  max: _totalAyatCurrent.toDouble(),
                  divisions: _totalAyatCurrent - 1,
                  value: tempAyah.toDouble(),
                  label: tempAyah.toString(),
                  onChanged: (v) => setS(() => tempAyah = v.toInt()),
                ),
                Text('Ayah: $tempAyah'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, tempAyah),
              child: const Text('Go'),
            ),
          ],
        );
      },
    );
    if (selected != null) {
      setState(() => _currentAyah = selected);
      _persistReading();
    }
  }
}
