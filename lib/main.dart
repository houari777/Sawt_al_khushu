import 'package:flutter/material.dart';

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
  double _speed = 0.8;

  @override
  void dispose() {
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
                onPressed: null,
                icon: const Icon(Icons.volume_up_rounded),
                label: const Text('ابدأ القراءة'),
              ),
              const SizedBox(height: 10),
              const Text(
                'القراءة الصوتية غير مفعّلة بعد. سيتم تفعيلها بعد دمج محرك نطق محلي واختباره؛ لذلك لا يعمل هذا الزر حالياً.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.deepOrange, height: 1.5),
              ),
              const SizedBox(height: 12),
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
