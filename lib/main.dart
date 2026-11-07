import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

void main() {
  runApp(const SawtAlKhushuApp());
}

class SawtAlKhushuApp extends StatelessWidget {
  const SawtAlKhushuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'صوت الخشوع',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF176B58),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Arial',
      ),
      home: const ReaderPage(),
    );
  }
}

class ReaderPage extends StatefulWidget {
  const ReaderPage({super.key});

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  final TextEditingController _textController = TextEditingController();
  final FlutterTts _tts = FlutterTts();

  double _speed = 0.8;
  bool _checkingVoice = true;
  bool _voiceReady = false;
  bool _speaking = false;
  String _status = 'جارٍ فحص محرك الصوت العربي على الهاتف...';
  String _arabicLocale = 'ar';

  @override
  void initState() {
    super.initState();
    _configureSpeech();
  }

  Future<void> _configureSpeech() async {
    _tts.setStartHandler(() {
      if (mounted) setState(() => _speaking = true);
    });
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _speaking = false);
    });
    _tts.setCancelHandler(() {
      if (mounted) setState(() => _speaking = false);
    });
    _tts.setErrorHandler((message) {
      if (mounted) {
        setState(() {
          _speaking = false;
          _status = 'تعذّر تشغيل الصوت: $message';
        });
      }
    });

    try {
      await _tts.setSpeechRate(_speed);
      await _tts.setVolume(1.0);
      await _tts.setPitch(0.92);

      final dynamic rawVoices = await _tts.getVoices;
      final voices = (rawVoices as List? ?? [])
          .whereType<Map>()
          .map((voice) => Map<String, dynamic>.from(voice))
          .where((voice) {
            final locale = (voice['locale'] ?? '').toString().toLowerCase();
            final networkRequired = voice['network_required'] == true ||
                voice['network_required'].toString().toLowerCase() == 'true';
            return locale.startsWith('ar') && !networkRequired;
          })
          .toList();

      if (voices.isNotEmpty) {
        final selected = voices.firstWhere(
          (voice) => (voice['locale'] ?? '').toString().toLowerCase() == 'ar-sa',
          orElse: () => voices.first,
        );
        _arabicLocale = selected['locale'].toString();
        await _tts.setVoice({
          'name': selected['name'].toString(),
          'locale': _arabicLocale,
        });
        await _tts.setLanguage(_arabicLocale);
        if (mounted) {
          setState(() {
            _voiceReady = true;
            _checkingVoice = false;
            _status = 'يوجد صوت عربي محلي على الهاتف. يمكنك تجربة القراءة دون إنترنت.';
          });
        }
        return;
      }

      final installed = await _tts.isLanguageInstalled('ar');
      if (installed == true) {
        await _tts.setLanguage('ar');
        if (mounted) {
          setState(() {
            _voiceReady = true;
            _checkingVoice = false;
            _arabicLocale = 'ar';
            _status = 'اللغة العربية مثبتة. جرّب القراءة؛ إذا طلب المحرك اتصالاً بالإنترنت فلن يكون الصوت محلياً.';
          });
        }
      } else if (mounted) {
        setState(() {
          _voiceReady = false;
          _checkingVoice = false;
          _status = 'لا يوجد حالياً صوت عربي مثبت محلياً. ثبّت بيانات صوت عربية من إعدادات تحويل النص إلى كلام في الهاتف ثم اضغط إعادة الفحص.';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _voiceReady = false;
          _checkingVoice = false;
          _status = 'لم نتمكن من فحص محرك الصوت: $error';
        });
      }
    }
  }

  Future<void> _speak() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      setState(() => _status = 'اكتب نصاً أولاً ثم ابدأ القراءة.');
      return;
    }
    if (!_voiceReady) {
      setState(() => _status = 'الصوت العربي غير جاهز. افحص المحرك أو ثبّت بيانات الصوت العربية أولاً.');
      return;
    }
    try {
      await _tts.stop();
      await _tts.setSpeechRate(_speed);
      await _tts.setLanguage(_arabicLocale);
      await _tts.speak(text);
    } catch (error) {
      if (mounted) {
        setState(() {
          _speaking = false;
          _status = 'حدث خطأ أثناء القراءة: $error';
        });
      }
    }
  }

  Future<void> _stop() async {
    await _tts.stop();
    if (mounted) setState(() => _speaking = false);
  }

  @override
  void dispose() {
    _tts.stop();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('صوت الخشوع'),
          centerTitle: true,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Icon(
                Icons.menu_book_rounded,
                size: 64,
                color: Color(0xFF176B58),
              ),
              const SizedBox(height: 12),
              const Text(
                'اكتب النص واستعد لقراءته بخشوع',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _textController,
                minLines: 7,
                maxLines: 14,
                textAlign: TextAlign.right,
                decoration: const InputDecoration(
                  hintText: 'اكتب النص العربي هنا...',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 20),
              Text('سرعة القراءة: ${_speed.toStringAsFixed(1)}'),
              Slider(
                value: _speed,
                min: 0.5,
                max: 1.2,
                divisions: 7,
                label: _speed.toStringAsFixed(1),
                onChanged: (value) => setState(() => _speed = value),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _checkingVoice || !_voiceReady ? null : _speak,
                icon: Icon(_speaking ? Icons.volume_up : Icons.play_arrow_rounded),
                label: Text(_speaking ? 'تتم القراءة...' : 'ابدأ القراءة'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _speaking ? _stop : null,
                icon: const Icon(Icons.stop_rounded),
                label: const Text('إيقاف القراءة'),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _voiceReady
                      ? Colors.green.withValues(alpha: 0.08)
                      : Colors.orange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _checkingVoice ? 'جارٍ فحص الصوت...' : _status,
                  textAlign: TextAlign.center,
                  style: const TextStyle(height: 1.5),
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _checkingVoice
                    ? null
                    : () {
                        setState(() {
                          _checkingVoice = true;
                          _voiceReady = false;
                        });
                        _configureSpeech();
                      },
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة فحص الصوت'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _textController.clear(),
                icon: const Icon(Icons.delete_outline),
                label: const Text('مسح النص'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
