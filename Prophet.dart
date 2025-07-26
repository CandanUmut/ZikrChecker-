// lib/prophet_interactive_page.dart

// lib/prophet_interactive_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdfx/pdfx.dart';
import 'package:signature/signature.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';

/// --------------------------------------------------
/// MODEL: Hadis
/// --------------------------------------------------
class Hadith {
  final String id;
  final String arabic;
  final String translation;
  Hadith({
    required this.id,
    required this.arabic,
    required this.translation,
  });
  factory Hadith.fromJson(Map<String,dynamic> j) => Hadith(
        id: j['hadith_number']?.toString() ?? j['id']?.toString() ?? '',
        arabic: j['arabic'] ?? j['body'] ?? '',
        translation: j['english'] ?? j['translation'] ?? '',
      );
}

/// --------------------------------------------------
/// MODEL: Bölüm (PDF chapter)
/// --------------------------------------------------
class Section {
  final String id;
  final String title;
  final int page;
  Section({required this.id, required this.title, required this.page});
}

/// --------------------------------------------------
/// MODEL: Refleksiyon kaydı
/// --------------------------------------------------
class ReflectionEntry {
  final String date;
  final String hadith;
  final String reflection;
  ReflectionEntry({
    required this.date,
    required this.hadith,
    required this.reflection,
  });
  Map<String,dynamic> toJson() => {
        'date': date,
        'hadith': hadith,
        'reflection': reflection,
      };
  factory ReflectionEntry.fromJson(Map<String,dynamic> j) =>
      ReflectionEntry(
        date: j['date'],
        hadith: j['hadith'],
        reflection: j['reflection'],
      );
}

/// --------------------------------------------------
/// PAGE: İnteraktif “Çöle İn(en) Nur” + hadîs + refleksiyon
/// --------------------------------------------------
class ProphetInteractivePage extends StatefulWidget {
  const ProphetInteractivePage({Key? key}) : super(key: key);
  @override
  State<ProphetInteractivePage> createState() =>
      _ProphetInteractivePageState();
}

class _ProphetInteractivePageState extends State<ProphetInteractivePage> {
  // PDF
  late final PdfController _pdfCtrl;
  // Bölümler
  late final List<Section> _chapters;
  // Hadisler
  late Future<List<Hadith>> _hadithsFuture;
  List<Hadith> _allHadiths = [];
  String? _dailyHadithText;
  // Refleksiyon
  final _reflectionCtrl = TextEditingController();
  List<ReflectionEntry> _reflections = [];
  // Çizim
  final SignatureController _sigCtrl = SignatureController(
    penStrokeWidth: 2, penColor: Colors.black,
  );

  @override
  void initState() {
    super.initState();
    // PDF kontrolcüsü
    _pdfCtrl = PdfController(
      document: PdfDocument.openAsset('assets/cole_inen_nur.pdf'),
    );
    // Bölümleri tanımla
    _chapters = [
      Section(id: 'takdim', title: 'Takdim', page: 1),
      Section(id: 'baslangic', title: 'Başlangıç', page: 3),
      // TODO: Başka bölümleri ekle
    ];
    // Hadisleri yükle
    _hadithsFuture = _loadHadiths();
    // Durumları oku
    _loadState();
  }

  @override
  void dispose() {
    _pdfCtrl.dispose();
    _reflectionCtrl.dispose();
    _sigCtrl.dispose();
    super.dispose();
  }

  /// 1) JSON asset’lerinden hadisleri oku
  Future<List<Hadith>> _loadHadiths() async {
    final assets = [
      'assets/hadith/bukhari.json',
      'assets/hadith/muslim.json',
      // TODO: Diğer JSON dosyalarını ekle
    ];
    final list = <Hadith>[];
    for (final path in assets) {
      final raw = await rootBundle.loadString(path);
      final dyn = jsonDecode(raw);
      if (dyn is List) {
        for (final e in dyn) {
          list.add(Hadith.fromJson(e as Map<String,dynamic>));
        }
      } else if (dyn is Map<String,dynamic>) {
        // Bazı JSON’larda {"hadiths":[...]}
        final arr = dyn['hadiths'] as List<dynamic>? ?? [];
        for (final e in arr) {
          list.add(Hadith.fromJson(e as Map<String,dynamic>));
        }
      }
    }
    return list;
  }

  /// 2) SharedPreferences’tan geçmiş refleksiyonları ve günlük hadisi hazırla
  Future<void> _loadState() async {
    // Refleksiyonlar
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('prophet_reflections');
    if (raw != null) {
      final arr = jsonDecode(raw) as List<dynamic>;
      _reflections = arr
          .map((e) => ReflectionEntry.fromJson(e as Map<String,dynamic>))
          .toList();
    }
    // Günlük hadis
    final hadiths = await _hadithsFuture;
    _allHadiths = hadiths;
    if (hadiths.isNotEmpty) {
      final todayIndex = DateTime.now().day % hadiths.length;
      _dailyHadithText =
          '${hadiths[todayIndex].arabic}\n\n${hadiths[todayIndex].translation}';
    }
    setState(() {});
  }

  /// 3) Refleksiyonu kaydet
  Future<void> _saveReflection() async {
    final txt = _reflectionCtrl.text.trim();
    if (txt.isEmpty || _dailyHadithText == null) return;
    final entry = ReflectionEntry(
      date: DateTime.now().toIso8601String(),
      hadith: _dailyHadithText!,
      reflection: txt,
    );
    _reflections.insert(0, entry);
    _reflectionCtrl.clear();
    final prefs = await SharedPreferences.getInstance();
    final out = jsonEncode(_reflections.map((e) => e.toJson()).toList());
    await prefs.setString('prophet_reflections', out);
    setState(() {});
  }

  /// 4) Bağış linki aç
  Future<void> _openDonation() async {
    const url = 'https://buy.stripe.com/test_XXXXXXXXXXXXXXXX';
    if (!await launchUrl(Uri.parse(url),
        mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bağış sayfası açılamadı')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Efendimizin Hayatı'),
          actions: [
            IconButton(
              icon: const Icon(Icons.favorite),
              tooltip: 'Bağış Yap',
              onPressed: _openDonation,
            ),
          ],
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFA5D6A7), Color(0xFF2E7D32)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          bottom: const TabBar(tabs: [
            Tab(icon: Icon(Icons.book), text: 'Kitap'),
            Tab(icon: Icon(Icons.list), text: 'Hadisler'),
            Tab(icon: Icon(Icons.edit), text: 'Refleksiyon'),
          ]),
        ),
        body: TabBarView(children: [
          // --- Tab 1: Bölümler + PDF ---
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Bölümler', style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              ..._chapters.map((s) => Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      title:
                          Text(s.title, style: theme.textTheme.titleMedium),
                      trailing: const Icon(Icons.arrow_forward),
                      onTap: () => _pdfCtrl.jumpToPage(s.page),
                    ),
                  )),
              const SizedBox(height: 16),
              SizedBox(
                height: 400,
                child: PdfView(
                  controller: _pdfCtrl,
                  scrollDirection: Axis.vertical,
                  builders: PdfViewBuilders<DefaultBuilderOptions>(
                    options: const DefaultBuilderOptions(),
                    documentLoaderBuilder: (_) =>
                        const Center(child: CircularProgressIndicator()),
                    pageLoaderBuilder: (_) =>
                        const Center(child: CircularProgressIndicator()),
                    errorBuilder: (_, __) =>
                        const Center(child: Text('PDF yüklenirken hata')),
                  ),
                ),
              ),
            ],
          ),

          // --- Tab 2: Hadisler ---
          FutureBuilder<List<Hadith>>(
            future: _hadithsFuture,
            builder: (ctx, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              final hadiths = snap.data ?? [];
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: hadiths.length,
                itemBuilder: (_, i) {
                  final h = hadiths[i];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Hadis ${h.id}',
                              style: theme.textTheme.titleMedium),
                          const SizedBox(height: 8),
                          Text(h.arabic,
                              style: theme.textTheme.bodyMedium),
                          const SizedBox(height: 8),
                          Text(h.translation,
                              style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),

          // --- Tab 3: Refleksiyon ---
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Günün Hadisi', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              if (_dailyHadithText != null)
                Card(
                  color: Colors.teal.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(_dailyHadithText!,
                        style: theme.textTheme.bodyLarge),
                  ),
                ),
              const SizedBox(height: 16),
              Text('Senin Refleksiyonun', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _reflectionCtrl,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Ne hissettin? Neler öğrendin?',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Kaydet'),
                onPressed: _saveReflection,
              ),

              const SizedBox(height: 24),
              Text('Çizim Alanı', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Container(
                height: 200,
                decoration:
                    BoxDecoration(border: Border.all(color: Colors.grey)),
                child: Signature(
                  controller: _sigCtrl,
                  backgroundColor: Colors.white,
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  child: const Text('Temizle'),
                  onPressed: () => _sigCtrl.clear(),
                ),
              ),

              const SizedBox(height: 24),
              Text('Geçmiş Refleksiyonlar',
                  style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              ..._reflections.map((r) => Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      title: Text(r.date.split('T').first),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Hadis:', style: theme.textTheme.bodySmall),
                          Text(r.hadith,
                              style: theme.textTheme.bodyMedium),
                          const SizedBox(height: 4),
                          Text('Refleksiyon: ${r.reflection}'),
                        ],
                      ),
                    ),
                  )),
            ],
          ),
        ]),
      ),
    );
  }
}
