// lib/prophet_interactive_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:signature/signature.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';

class ProphetInteractivePage extends StatefulWidget {
  const ProphetInteractivePage({Key? key}) : super(key: key);
  @override
  State<ProphetInteractivePage> createState() => _ProphetInteractivePageState();
}

class _ProphetInteractivePageState extends State<ProphetInteractivePage> {
  // PDF controller
  late final PdfController _pdfCtrl;
  // Chapters (stub: split by pages or define your own)
  late final List<Section> _chapters;
  // Hadith list
  late Future<List<String>> _hadithsFuture;
  // Daily hadith & reflection
  String? _dailyHadith;
  final _reflectionCtrl = TextEditingController();
  List<ReflectionEntry> _reflections = [];
  // Drawing pad
  final SignatureController _sigCtrl = SignatureController(
    penStrokeWidth: 2, penColor: Colors.black,
  );

  @override
  void initState() {
    super.initState();
    _pdfCtrl = PdfController(
      document: PdfDocument.openAsset('assets/cole_inen_nur.pdf'),
    );
    // Define chapters manually or extract automatically
    _chapters = [
      Section(id: 'takdim', title: 'Takdim', page: 1),
      Section(id: 'baslangic', title: 'Başlangıç', page: 3),
      // TODO: ek bölümler...
    ];
    _hadithsFuture = fetchHadiths();
    _loadState();
  }

  @override
  void dispose() {
    _pdfCtrl.dispose();
    _reflectionCtrl.dispose();
    _sigCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    // Load reflections
    final raw = prefs.getString('prophet_reflections');
    if (raw != null) {
      final list = jsonDecode(raw) as List<dynamic>;
      _reflections = list.map((e) => ReflectionEntry.fromJson(e)).toList();
    }
    // Pick daily hadith once hadiths are ready
    final hadiths = await _hadithsFuture;
    final todayIndex = DateTime.now().day % hadiths.length;
    setState(() {
      _dailyHadith = hadiths[todayIndex];
    });
  }

  Future<List<String>> fetchHadiths() async {
    // TODO: Replace with real HTTP fetch from a hadith API
    await Future.delayed(const Duration(milliseconds: 200));
    return [
      'Hadis 1: “Gerçek mümin...”',
      'Hadis 2: “Kolaylaştırın, zorlaştırmayın...”',
      'Hadis 3: “Sabretmek imandandır...”',
      // ekleyin...
    ];
  }

  Future<void> _saveReflection() async {
    final text = _reflectionCtrl.text.trim();
    if (text.isEmpty || _dailyHadith == null) return;
    final entry = ReflectionEntry(
      date: DateTime.now().toIso8601String(),
      hadith: _dailyHadith!,
      reflection: text,
    );
    setState(() {
      _reflections.insert(0, entry);
      _reflectionCtrl.clear();
    });
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_reflections.map((e) => e.toJson()).toList());
    await prefs.setString('prophet_reflections', raw);
  }

  Future<void> _openDonation() async {
    const url = 'https://buy.stripe.com/test_XXXXXXXXXXXXXXXX';
    if (!await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
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
            )
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
          // ---------- Tab 1: Chapters & PDF ----------
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Bölümler', style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              ..._chapters.map((sec) => Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  title: Text(sec.title, style: theme.textTheme.titleMedium),
                  trailing: const Icon(Icons.arrow_forward),
                  onTap: () {
                    _pdfCtrl.jumpToPage(sec.page);
                  },
                ),
              )),
              const SizedBox(height: 16),
              SizedBox(
                height: 400,
                child: PdfView(
                  controller: _pdfCtrl,
                  scrollDirection: Axis.vertical,
                ),
              ),
            ],
          ),

          // ---------- Tab 2: Hadith List ----------
          FutureBuilder<List<String>>(
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
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(hadiths[i], style: theme.textTheme.bodyMedium),
                    ),
                  );
                },
              );
            },
          ),

          // ---------- Tab 3: Daily Reflection ----------
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Günün Hadisi', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              if (_dailyHadith != null)
                Card(
                  color: Colors.teal.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(_dailyHadith!, style: theme.textTheme.bodyLarge),
                  ),
                ),
              const SizedBox(height: 16),
              Text('Senin Refleksiyonun', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _reflectionCtrl,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Ne hissettin, neler öğrendin?',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                ),
                child: Signature(controller: _sigCtrl, backgroundColor: Colors.white),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    child: const Text('Temizle'),
                    onPressed: () => _sigCtrl.clear(),
                  ),
                  // TODO: “Çizimi Kaydet” işlemi
                ],
              ),

              const SizedBox(height: 24),
              Text('Geçmiş Refleksiyonlar', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              ..._reflections.map((r) => Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  title: Text(r.date.split('T').first),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hadis: ${r.hadith}', style: theme.textTheme.bodySmall),
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

/// --------------------------------------------------
/// SUPPORTING MODELS
/// --------------------------------------------------
class Section {
  final String id;
  final String title;
  final int page; // pdf sayfa
  Section({required this.id, required this.title, required this.page});
}

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
  factory ReflectionEntry.fromJson(Map<String,dynamic> j) => ReflectionEntry(
    date: j['date'],
    hadith: j['hadith'],
    reflection: j['reflection'],
  );
}
