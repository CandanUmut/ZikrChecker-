Aşağıda “Ameller” özelliğinizdeki tüm kodu tek bir dosyada birleştirdim ve biraz daha cilaladım. Böylece lib/ameller/ameller_full_page.dart koyup, tek bir import ile tüm akışı kullanabilirsiniz:

// lib/ameller/ameller_full_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';

/// --- MODEL ---
class AmelDay {
  AmelDay({
    required this.date,
    required this.counters,
    this.sins = '',
    this.tawba = '',
    this.better = '',
  });
  final String date;
  final Map<String,int> counters;
  String sins, tawba, better;

  Map<String,dynamic> toJson() => {
        'date': date,
        'counters': counters,
        'sins': sins,
        'tawba': tawba,
        'better': better,
      };
  factory AmelDay.fromJson(Map<String,dynamic> j) => AmelDay(
        date: j['date'] as String,
        counters: Map<String,int>.from(j['counters'] ?? {}),
        sins: j['sins'] ?? '',
        tawba: j['tawba'] ?? '',
        better: j['better'] ?? '',
      );
}

/// --- STORE (SharedPreferences) ---
class AmelStore {
  AmelStore._();
  static final AmelStore I = AmelStore._();
  static const _key = 'ameller_log_v1';
  final Map<String,AmelDay> _cache = {};

  Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw != null) {
      final m = jsonDecode(raw) as Map<String,dynamic>;
      m.forEach((k,v) => _cache[k] = AmelDay.fromJson(v));
    }
  }

  AmelDay getDay(String date, Map<String,int> defaults) {
    return _cache.putIfAbsent(date, () => AmelDay(
      date: date,
      counters: Map.from(defaults),
    ));
  }

  Future<void> saveDay(AmelDay day) async {
    _cache[day.date] = day;
    final p = await SharedPreferences.getInstance();
    final out = _cache.map((k,d) => MapEntry(k, d.toJson()));
    await p.setString(_key, jsonEncode(out));
  }

  List<AmelDay> allDays() {
    final list = _cache.values.toList()..sort((a,b) => b.date.compareTo(a.date));
    return list;
  }

  Map<String,int> weeklyTotals(DateTime now) {
    final start = now.subtract(const Duration(days:6));
    final totals = <String,int>{};
    for (final d in _cache.values) {
      final dt = DateTime.parse(d.date);
      if (dt.isBefore(start)||dt.isAfter(now)) continue;
      d.counters.forEach((k,v) {
        totals[k] = (totals[k] ?? 0) + v;
      });
    }
    return totals;
  }
}

/// --- WIDGET: TAM SAYFA ---
class AmellerFullPage extends StatefulWidget {
  const AmellerFullPage({super.key});
  @override
  State<AmellerFullPage> createState() => _AmellerFullPageState();
}

class _AmellerFullPageState extends State<AmellerFullPage> {
  final _tabCtrl = TabController(length: 2, vsync: ScrollableState());
  bool _loaded = false;
  late AmelDay _today;
  late Map<String,int> _weeklyTotals;
  final _sinsCtrl   = TextEditingController();
  final _tawbaCtrl  = TextEditingController();
  final _betterCtrl = TextEditingController();

  // Etiketler ve default sayılar
  final _labels = {
    'zikr': 'Zikr',
    'namaz': 'Namaz (Sünnet/Nafile)',
    'sadaka': 'Sadaka',
    'kuran': 'Kur’an Okuma',
    'dua': 'Dua / Salavat',
  };

  @override
  void initState() {
    super.initState();
    _initAll();
  }

  Future<void> _initAll() async {
    await AmelStore.I.init();
    final today = DateTime.now().toIso8601String().substring(0,10);
    _today = AmelStore.I.getDay(today, {for (var k in _labels.keys) k: 0});
    _weeklyTotals = AmelStore.I.weeklyTotals(DateTime.now());
    _sinsCtrl.text   = _today.sins;
    _tawbaCtrl.text  = _today.tawba;
    _betterCtrl.text = _today.better;
    setState(() => _loaded = true);
  }

  Future<void> _inc(String k) async {
    setState(() => _today.counters[k] = (_today.counters[k] ?? 0) + 1);
    await AmelStore.I.saveDay(_today);
    _weeklyTotals = AmelStore.I.weeklyTotals(DateTime.now());
  }
  Future<void> _dec(String k) async {
    setState(() {
      final v = (_today.counters[k] ?? 0)-1;
      _today.counters[k] = v<0?0:v;
    });
    await AmelStore.I.saveDay(_today);
    _weeklyTotals = AmelStore.I.weeklyTotals(DateTime.now());
  }

  Future<void> _saveForm() async {
    _today
      ..sins   = _sinsCtrl.text
      ..tawba  = _tawbaCtrl.text
      ..better = _betterCtrl.text;
    await AmelStore.I.saveDay(_today);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kaydedildi')));
  }

  @override
  void dispose() {
    _sinsCtrl.dispose();
    _tawbaCtrl.dispose();
    _betterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFA5D6A7), Color(0xFF2E7D32)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          title: const Text('Ameller'),
          bottom: const TabBar(tabs: [
            Tab(icon: Icon(Icons.task_alt), text: 'Defter'),
            Tab(icon: Icon(Icons.book), text: 'Kitaplar'),
          ]),
        ),
        body: TabBarView(children: [
          // --- TAB 1: Amel Defteri ---
          ListView(padding: const EdgeInsets.all(16), children: [
            Text('Bugünkü Ameller', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            ..._labels.entries.map((e) {
              final v = _today.counters[e.key] ?? 0;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal:12,vertical:8),
                  child: Row(
                    children: [
                      Expanded(child: Text(e.value, style: theme.textTheme.bodyLarge)),
                      IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: v>0?() => _dec(e.key):null),
                      Text('$v', style: theme.textTheme.titleMedium),
                      IconButton(icon: const Icon(Icons.add_circle_outline), onPressed:() => _inc(e.key)),
                    ],
                  ),
                ),
              );
            }).toList(),

            const SizedBox(height: 24),
            Text('Haftalık Toplam', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            SizedBox(height:180, child: _buildWeeklyChart()),

            const SizedBox(height:24),
            Card(
              child: ExpansionTile(
                title: const Text('Hafta Sonu Değerlendirme'),
                subtitle: const Text('Günahlarınız, tövbeniz, gelişim'),
                childrenPadding: const EdgeInsets.all(16),
                children: [
                  _tf(_sinsCtrl, 'Ne günah işledin?'),
                  const SizedBox(height:8),
                  _tf(_tawbaCtrl,'Tövbe ettin mi?'),
                  const SizedBox(height:8),
                  _tf(_betterCtrl,'Nasıl daha iyi olursun?'),
                  const SizedBox(height:16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.save), label: const Text('Kaydet'),
                    onPressed: _saveForm,
                  ),
                ],
              ),
            ),

            const SizedBox(height:24),
            Text('Geçmiş Günler', style: theme.textTheme.titleLarge),
            const SizedBox(height:8),
            ...AmelStore.I.allDays().map((d) {
              return ListTile(
                title: Text(d.date),
                subtitle: Text(
                  _labels.keys.map((k) => '${_labels[k]}: ${d.counters[k] ?? 0}')
                    .join('   •  '),
                ),
                trailing: d.sins.isNotEmpty ? const Icon(Icons.note) : null,
              );
            }).toList(),
            const SizedBox(height: 80),
          ]),

          // --- TAB 2: Amel Kitapları ---
          ListView(padding: const EdgeInsets.all(16), children: [
            for (final sec in {
              'Kur’an & Tefsir': [
                ['IslamHouse','https://islamhouse.com/en/category/156/'],
                ['OpenLibrary Qur’an','https://openlibrary.org/subjects/quran'],
              ],
              'Hadis': [
                ['Gutenberg Hadith','https://www.gutenberg.org/ebooks/search/?query=hadith'],
                ['IslamHouse Hadis','https://islamhouse.com/en/category/532/'],
              ],
              'Seerah/Tarih': [
                ['OpenLibrary Tarih','https://openlibrary.org/subjects/islamic_history'],
                ['Gutenberg Islam Tarih','https://www.gutenberg.org/ebooks/search/?query=islam+history'],
              ],
              'Klasik Eserler': [
                ['Yazma Eserler Kurumu','https://yazmalar.gov.tr/'],
                ['İlmiye Vakfı','https://kutuphane.ilmiyefoundation.org/'],
              ],
              'Modern Eğitim': [
                ['IslamHouse Eğitim','https://islamhouse.com/en/category/1/'],
                ['OpenLibrary Islam','https://openlibrary.org/subjects/islam'],
              ],
            }.entries)
              ...[
                Text(sec.key, style: theme.textTheme.titleLarge),
                const SizedBox(height:8),
                ...sec.value.map((it) => Card(
                      child: ListTile(
                        title: Text(it[0]),
                        trailing: const Icon(Icons.open_in_new),
                        onTap: () => _launch(it[1]),
                      ),
                    )),
                const SizedBox(height:16),
              ],
          ]),
        ]),
      ),
    );
  }

  Widget _tf(TextEditingController c, String hint) => TextField(
    controller: c,
    maxLines: null,
    decoration: InputDecoration(
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );

  Widget _buildWeeklyChart() {
    return BarChart(BarChartData(
      gridData: FlGridData(show: false),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles:false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles:false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles:false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(showTitles:true, getTitlesWidget:(i,_){
            const days = ['P','S','Ç','P','C','Ct','Pz'];
            return Text(days[i.toInt()]);
          }),
        ),
      ),
      barGroups: List.generate(
        7,
        (i) => BarChartGroupData(x:i, barRods:[
          BarChartRodData(toY: _weeklyTotals.values.elementAt(i).toDouble(), width:14)
        ]),
      ),
    ));
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }
}



⸻

Kullanım
	1.	pubspec.yaml’e gereken paketleri ekleyip flutter pub get çalıştırın:

shared_preferences: ^2.2.2
fl_chart: ^0.66.2
url_launcher: ^6.2.5
google_fonts: ^6.1.0


	2.	main.dart’te bir buton veya rota tanımlayıp:

routes: {
  '/ameller': (_) => const AmellerFullPage(),
}


	3.	Butona basınca:

Navigator.pushNamed(context, '/ameller');



Hepsi bu—tek dosyada, fonksiyonel ve şık bir “Ameller” sayfası.
Allah kabul etsin!
