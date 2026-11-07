import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supertonic_flutter/supertonic_flutter.dart';

void main() => runApp(const App());
const green = Color(0xFF176B58);

class App extends StatefulWidget {
  const App({super.key});
  @override
  State<App> createState() => _AppState();
}
class _AppState extends State<App> {
  ThemeMode mode = ThemeMode.light;
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false, title: 'صوت الخشوع', themeMode: mode,
    theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: green), scaffoldBackgroundColor: const Color(0xFFF5F7F3)),
    darkTheme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: green, brightness: Brightness.dark)),
    home: Reader(dark: mode == ThemeMode.dark, toggle: () => setState(() => mode = mode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light)),
  );
}

class Reader extends StatefulWidget {
  const Reader({super.key, required this.dark, required this.toggle});
  final bool dark;
  final VoidCallback toggle;
  @override
  State<Reader> createState() => _ReaderState();
}
class _ReaderState extends State<Reader> {
  final text = TextEditingController();
  final tts = FlutterTts();
  final neuralTts = SupertonicTTS();
  final neuralPlayer = TTSAudioPlayer();
  bool neuralReady = false, neuralLoading = false, useNeural = false;
  double modelProgress = 0;
  String maleVoice = 'M1';
  List<String> saved = [];
  double speed = .72, volume = .42, pause = .7, pitch = .92;
  bool checking = true, ready = false, speaking = false, advanced = false;
  String locale = 'ar', status = 'جارٍ فحص الصوت العربي…';
  int get words => text.text.trim().isEmpty ? 0 : text.text.trim().split(RegExp(r'\s+')).length;

  @override
  void initState() {
    super.initState();
    text.addListener(() { if (mounted) setState(() {}); });
    load();
    configure();
  }
  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    if (mounted) setState(() => saved = p.getStringList('saved_readings_v1') ?? []);
  }
  Future<void> persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList('saved_readings_v1', saved);
  }
  Future<void> configure() async {
    setState(() { checking = true; ready = false; });
    tts.setStartHandler(() { if (mounted) setState(() => speaking = true); });
    tts.setCompletionHandler(() { if (mounted) setState(() => speaking = false); });
    tts.setCancelHandler(() { if (mounted) setState(() => speaking = false); });
    tts.setErrorHandler((e) { if (mounted) setState(() { speaking = false; status = 'تعذّرت القراءة: ' + e; }); });
    try {
      await tts.awaitSpeakCompletion(true);
      await tts.setSpeechRate(speed);
      await tts.setVolume(volume);
      await tts.setPitch(pitch);
      final raw = await tts.getVoices;
      final voices = (raw as List? ?? []).whereType<Map>().where((v) {
        final l = (v['locale'] ?? '').toString().toLowerCase();
        final net = (v['network_required'] == true || (v['network_required'] ?? '').toString().toLowerCase() == 'true');
        return l.startsWith('ar') && !net;
      }).toList();
      if (voices.isNotEmpty) {
        final v = voices.firstWhere((x) => (x['locale'] ?? '').toString().toLowerCase() == 'ar-sa', orElse: () => voices.first);
        locale = (v['locale'] ?? 'ar').toString();
        await tts.setVoice({'name': (v['name'] ?? '').toString(), 'locale': locale});
        await tts.setLanguage(locale);
        if (mounted) setState(() { ready = true; checking = false; status = 'الصوت العربي المحلي جاهز. جودة النطق تتبع المحرك المثبّت.'; });
      } else if (await tts.isLanguageInstalled('ar') == true) {
        locale = 'ar';
        await tts.setLanguage(locale);
        if (mounted) setState(() { ready = true; checking = false; status = 'اللغة العربية متاحة على الهاتف.'; });
      } else if (mounted) {
        setState(() { checking = false; status = 'لا يوجد صوت عربي محلي. ثبّت صوتاً عربياً من إعدادات تحويل النص إلى كلام ثم أعد الفحص.'; });
      }
    } catch (e) {
      if (mounted) setState(() { checking = false; status = 'تعذّر فحص محرك الصوت: ' + e.toString(); });
    }
  }
  Future<void> downloadNeuralVoice() async {
    if (neuralReady || neuralLoading) return;
    setState(() { neuralLoading = true; modelProgress = 0; status = 'جارٍ تجهيز الصوت الرجولي لأول مرة…'; });
    try {
      if (!await SupertonicTTS.modelsReady()) {
        await SupertonicTTS.preDownloadModels(onProgress: (done, total, file, progress) {
          if (mounted) setState(() => modelProgress = progress.clamp(0.0, 1.0).toDouble());
        });
      }
      await neuralTts.initialize();
      if (!mounted) return;
      setState(() { neuralReady = true; neuralLoading = false; modelProgress = 1; useNeural = true; status = 'الصوت الرجولي المحلي جاهز ومحدد للقراءة. يمكنك الآن فصل الإنترنت.'; });
      message('تم تجهيز الصوت الرجولي على الهاتف.');
    } catch (e) {
      if (!mounted) return;
      setState(() { neuralLoading = false; status = 'تعذّر تجهيز النموذج: $e'; });
      message('فشل تنزيل الصوت. تحقق من الإنترنت والمساحة ثم أعد المحاولة.');
    }
  }

  Future<void> readWithNeural() async {
    if (!neuralReady) return message('نزّل الصوت الرجولي أولاً.');
    if (text.text.trim().isEmpty) return message('اكتب نصاً أولاً.');
    final paragraphs = text.text.trim().split(RegExp(r'\n\s*\n')).map((x) => x.trim()).where((x) => x.isNotEmpty);
    try {
      await neuralPlayer.stop();
      if (mounted) setState(() => speaking = true);
      for (final paragraph in paragraphs) {
        if (!mounted || !speaking) break;
        final result = await neuralTts.synthesize(
          paragraph,
          language: 'ar',
          voiceStyle: maleVoice,
          config: TTSConfig(speechSpeed: speed.clamp(.7, .9).toDouble(), denoisingSteps: 5, silenceDuration: 0.0),
        );
        if (!mounted || !speaking) break;
        await neuralPlayer.play(result);
        if (pause > 0 && mounted && speaking) {
          await Future<void>.delayed(Duration(milliseconds: (pause * 1000).round()));
        }
      }
      if (mounted) setState(() => speaking = false);
    } catch (e) {
      if (mounted) setState(() { speaking = false; status = 'خطأ في الصوت الرجولي: $e'; });
    }
  }

  Future<void> readText() async {
    if (useNeural) return readWithNeural();
    final value = text.text.trim();
    if (value.isEmpty) return message('اكتب نصاً أولاً.');
    if (!ready) return message('الصوت العربي غير جاهز.');
    try {
      await tts.stop();
      await tts.setSpeechRate(speed);
      await tts.setVolume(volume);
      await tts.setPitch(pitch);
      for (final p in value.split(RegExp(r'\n\s*\n')).map((x) => x.trim()).where((x) => x.isNotEmpty)) {
        if (!mounted) return;
        await tts.speak(p);
        if (pause > 0) await Future<void>.delayed(Duration(milliseconds: (pause * 1000).round()));
      }
      if (mounted) setState(() => speaking = false);
    } catch (e) {
      if (mounted) setState(() { speaking = false; status = 'حدث خطأ أثناء القراءة: ' + e.toString(); });
    }
  }
  Future<void> stop() async { await tts.stop(); await neuralPlayer.stop(); if (mounted) setState(() => speaking = false); }
  void message(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s), behavior: SnackBarBehavior.floating));
  Future<void> saveText() async {
    final value = text.text.trim();
    if (value.isEmpty) return message('لا يوجد نص لحفظه.');
    if (saved.contains(value)) return message('النص محفوظ بالفعل.');
    setState(() => saved = [value, ...saved]);
    await persist();
    message('حُفظ النص على هاتفك.');
  }
  Future<void> library() async {
    await showModalBottomSheet<void>(context: context, isScrollControlled: true, showDragHandle: true, builder: (ctx) =>
      Directionality(textDirection: TextDirection.rtl, child: SafeArea(child: SizedBox(height: MediaQuery.of(context).size.height * .65, child: Column(children: [
        const Padding(padding: EdgeInsets.all(16), child: Text('مكتبتي', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold))),
        Expanded(child: saved.isEmpty ? const Center(child: Text('لا توجد نصوص محفوظة بعد.')) : ListView.builder(itemCount: saved.length, itemBuilder: (c, i) => ListTile(
          title: Text(saved[i], maxLines: 2, overflow: TextOverflow.ellipsis),
          onTap: () { text.text = saved[i]; Navigator.pop(ctx); },
          trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () async { setState(() => saved.removeAt(i)); await persist(); if (mounted) Navigator.pop(ctx); if (mounted) library(); }),
        ))),
      ])))));
  }
  @override
  void dispose() { tts.stop(); neuralPlayer.dispose(); neuralTts.dispose(); text.dispose(); super.dispose(); }
  Widget slider(String label, double value, double min, double max, ValueChanged<double> change, String display) => Column(children: [
    Row(children: [Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))), Text(display, style: const TextStyle(color: green, fontWeight: FontWeight.bold))]),
    Slider(value: value, min: min, max: max, activeColor: green, onChanged: change),
  ]);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(
      appBar: AppBar(title: Row(children: [
        Container(width: 38, height: 38, decoration: BoxDecoration(color: green, borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.menu_book_rounded, color: Colors.white)),
        const SizedBox(width: 10), const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('صوت الخشوع', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)), Text('رفيق القراءة الهادئة', style: TextStyle(fontSize: 11, color: Colors.grey))]),
      ]), actions: [IconButton(onPressed: library, icon: const Icon(Icons.bookmarks_outlined)), IconButton(onPressed: widget.toggle, icon: Icon(widget.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined))]),
      body: SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 28), children: [
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF145847), Color(0xFF287B64)], begin: Alignment.topRight, end: Alignment.bottomLeft), borderRadius: BorderRadius.circular(26)), child: Row(children: [
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('على مهل… وبطمأنينة', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.bold)), SizedBox(height: 7), Text('اكتب، اضبط الإيقاع، ثم استمع بصوت منخفض وواضح.', style: TextStyle(color: Colors.white70, height: 1.5)), SizedBox(height: 12), Row(children: [Icon(Icons.waves_rounded, color: Color(0xFFE8C98C), size: 17), SizedBox(width: 6), Text('وضع القراءة الهادئة', style: TextStyle(color: Color(0xFFFFE7B8), fontSize: 12, fontWeight: FontWeight.w600))])])),
          const SizedBox(width: 12), Container(width: 66, height: 66, decoration: BoxDecoration(color: Colors.white12, shape: BoxShape.circle, border: Border.all(color: Colors.white24)), child: const Icon(Icons.spa_outlined, color: Color(0xFFFFE7B8), size: 34)),
        ])),
        const SizedBox(height: 18),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('النص المراد قراءته', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)), Text(words.toString() + ' كلمة', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12))]),
        const SizedBox(height: 10),
        Card(child: Padding(padding: const EdgeInsets.all(14), child: TextField(controller: text, minLines: 8, maxLines: 14, textAlign: TextAlign.right, textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 19, height: 1.9), decoration: InputDecoration(hintText: 'اكتب هنا…\n\nلأفضل نتيجة في العربية، أضف التشكيل للكلمات التي تحتمل أكثر من نطق.', hintStyle: TextStyle(color: cs.onSurfaceVariant, fontSize: 15, height: 1.8), border: InputBorder.none)))),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: saveText, icon: const Icon(Icons.bookmark_add_outlined), label: const Text('حفظ'))),
          const SizedBox(width: 7), Expanded(child: OutlinedButton.icon(onPressed: text.clear, icon: const Icon(Icons.delete_outline), label: const Text('مسح'))),
          const SizedBox(width: 7), Expanded(child: OutlinedButton.icon(onPressed: () => text.text = 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ\n\nالْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ', icon: const Icon(Icons.auto_awesome_outlined), label: const Text('مثال مشكول'))),
        ]),
        const SizedBox(height: 16),
        Card(child: Padding(padding: const EdgeInsets.all(15), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Icon(Icons.record_voice_over_rounded, color: green), const SizedBox(width: 8), const Expanded(child: Text('محرك الصوت الرجولي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))), Switch(value: useNeural, onChanged: neuralReady ? (v) => setState(() => useNeural = v) : null)]),
          const Text('صوت عصبي محلي مستقل عن أصوات الهاتف. يحتاج تنزيل ملفات النموذج مرة واحدة (قرابة 400 ميغابايت).', style: TextStyle(fontSize: 12, height: 1.5)),
          const SizedBox(height: 10),
          if (!neuralReady) ...[
            FilledButton.icon(onPressed: neuralLoading ? null : downloadNeuralVoice, icon: const Icon(Icons.download_rounded), label: Text(neuralLoading ? 'جارٍ تنزيل ملفات الصوت…' : 'تنزيل الصوت الرجولي عبر Wi‑Fi')),
            if (neuralLoading) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: modelProgress > 0 ? modelProgress : null),
              const SizedBox(height: 4),
              Text(modelProgress > 0 ? 'اكتمل ${(modelProgress * 100).round()}%' : 'يتم الاتصال بمصدر النموذج…', style: const TextStyle(fontSize: 11)),
            ],
          ] else ...[
            Row(children: [
              const Expanded(child: Text('اختر نبرة رجولية للتجربة', style: TextStyle(fontSize: 12))),
              DropdownButton<String>(value: maleVoice, items: ['M1','M2','M3','M4','M5'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setState(() => maleVoice = v ?? 'M1')),
            ]),
            TextButton.icon(onPressed: () => setState(() => useNeural = true), icon: const Icon(Icons.check_circle_outline), label: Text(useNeural ? 'المحرك الرجولي محدد' : 'استخدام الصوت الرجولي')),
          ],
        ]))),
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('ضبط القراءة', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)), TextButton.icon(onPressed: () => setState(() => advanced = !advanced), icon: Icon(advanced ? Icons.expand_less : Icons.tune), label: Text(advanced ? 'إخفاء' : 'تخصيص'))]),
        Card(child: Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 14), child: Column(children: [
          slider('سرعة القراءة', speed, .35, .9, (v) => setState(() => speed = v), speed.toStringAsFixed(2)),
          if (!useNeural) slider('مستوى صوت محرك الهاتف', volume, .08, 1, (v) => setState(() => volume = v), (volume * 100).round().toString() + '%')
          else const Align(alignment: Alignment.centerRight, child: Text('للصوت الرجولي: استخدم أزرار مستوى الصوت في الهاتف.', style: TextStyle(fontSize: 12, color: Colors.grey))),
          if (advanced) ...[
            const Divider(height: 22),
            slider('الوقفة بين الفقرات', pause, 0, 2, (v) => setState(() => pause = v), pause.toStringAsFixed(1) + ' ث'),
            slider('حدة الصوت', pitch, .7, 1.2, (v) => setState(() => pitch = v), pitch.toStringAsFixed(2)),
            Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => setState(() { speed = .72; volume = .42; pause = .7; pitch = .92; }), child: const Text('إعادة الضبط'))),
          ],
        ]))),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: FilledButton.icon(onPressed: checking || (useNeural ? !neuralReady : !ready) || speaking ? null : readText, style: FilledButton.styleFrom(backgroundColor: green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 17)), icon: Icon(speaking ? Icons.graphic_eq : Icons.play_arrow_rounded), label: Text(speaking ? 'تتم القراءة…' : 'ابدأ القراءة', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))),
          const SizedBox(width: 10), IconButton.filledTonal(onPressed: speaking ? stop : null, icon: const Icon(Icons.stop_rounded), tooltip: 'إيقاف', style: IconButton.styleFrom(fixedSize: const Size(54, 54))),
        ]),
        const SizedBox(height: 12),
        Card(child: Padding(padding: const EdgeInsets.all(14), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(ready ? Icons.check_circle_outline : Icons.info_outline, color: ready ? green : const Color(0xFFC59A52)), const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(checking ? 'فحص محرك الصوت' : ready ? 'محرك الصوت جاهز' : 'الصوت يحتاج إعداداً', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4), Text(status, style: TextStyle(color: cs.onSurfaceVariant, height: 1.5, fontSize: 12)),
            if (!checking) TextButton(onPressed: configure, child: const Text('إعادة فحص الصوت')),
          ])),
        ]))),
        const SizedBox(height: 12),
        Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: cs.surfaceContainerHighest.withValues(alpha: .65), borderRadius: BorderRadius.circular(18)), child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.lightbulb_outline, size: 19), SizedBox(width: 9), Expanded(child: Text('ملاحظة نطق: التشكيل يساعد المحرك على اختيار النطق المقصود. محرك الهاتف الحالي لا يضمن أحكام التجويد أو مخارج الحروف وصفاتها؛ هذه النسخة تضبط مستوى الصوت والسرعة والوقفات فقط.', style: TextStyle(fontSize: 12, height: 1.6))),
        ])),
        const SizedBox(height: 12), Center(child: Text('صُنع ليكون الصوت هادئاً… والمعنى حاضراً', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11))),
      ])),
    ));
  }
}
