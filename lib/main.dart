import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:record/record.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LakhisApp());
}

class LakhisApp extends StatelessWidget {
  const LakhisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'لخّص',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar', 'EG'),
      supportedLocales: const [
        Locale('ar', 'EG'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        fontFamily: 'Cairo',
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6C63FF)),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  int _remainingTrials = 3;

  @override
  void initState() {
    super.initState();
    _loadTrials();
  }

  Future<void> _loadTrials() async {
    final prefs = await SharedPreferences.getInstance();
    final used = prefs.getInt("used_trials") ?? 0;
    setState(() {
      _remainingTrials = (3 - used).clamp(0, 3);
    });
  }

  Future<void> _handleRecording() async {
    if (_remainingTrials <= 0) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const PaywallScreen()));
      return;
    }

    if (_isRecording) {
      final path = await _audioRecorder.stop();
      setState(() => _isRecording = false);
      if (path != null && mounted) {
        _startProcessing(path);
      }
    } else {
      final micStatus = await Permission.microphone.request();
      if (micStatus.isGranted) {
        final dir = await getTemporaryDirectory();
        final filePath = "${dir.path}/record_${DateTime.now().millisecondsSinceEpoch}.m4a";
        await _audioRecorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: filePath);
        setState(() => _isRecording = true);
      }
    }
  }

  Future<void> _pickAudioFile() async {
    if (_remainingTrials <= 0) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const PaywallScreen()));
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'm4a', 'wav', 'mp4'],
    );

    if (result != null && result.files.single.path != null && mounted) {
      _startProcessing(result.files.single.path!);
    }
  }

  void _startProcessing(String path) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProcessingScreen(filePath: path)),
    ).then((_) => _loadTrials());
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text("لخّص", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            tooltip: "محفظتي",
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WalletScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "متبقي لك: $_remainingTrials محاضرات مجانية",
                  style: const TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.bold),
                ),
              ),
              const Spacer(),
              const Text(
                "حوّل محاضرتك لملخص في ثوانٍ",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                "اضغط للتسجيل المباشر أو ارفع ملف صوتي",
                style: TextStyle(color: Colors.grey, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              GestureDetector(
                onTap: _handleRecording,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 170,
                  height: 170,
                  decoration: BoxDecoration(
                    color: _isRecording ? Colors.redAccent : const Color(0xFF6C63FF),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (_isRecording ? Colors.redAccent : const Color(0xFF6C63FF)).withOpacity(0.35),
                        blurRadius: 30,
                        spreadRadius: 10,
                      )
                    ],
                  ),
                  child: Icon(
                    _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                    color: Colors.white,
                    size: 75,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _isRecording ? "جاري التسجيل... اضغط للإيقاف" : "اضغط للبدء في التسجيل",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _isRecording ? Colors.redAccent : const Color(0xFF2C3E50),
                ),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _pickAudioFile,
                icon: const Icon(Icons.file_upload_outlined, color: Color(0xFF6C63FF)),
                label: const Text(
                  "رفع ملف صوتي / فيديو محاضرة",
                  style: TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 54),
                  side: const BorderSide(color: Color(0xFF6C63FF), width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class ProcessingScreen extends StatefulWidget {
  final String filePath;
  const ProcessingScreen({super.key, required this.filePath});

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  @override
  void initState() {
    super.initState();
    _process();
  }

  Future<void> _process() async {
    final prefs = await SharedPreferences.getInstance();
    final used = prefs.getInt("used_trials") ?? 0;
    await prefs.setInt("used_trials", used + 1);

    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const ResultScreen(
          summary: "تناولت المحاضرة المفاهيم الأساسية، مع شرح القوانين الرئيسية وتطبيقاتها العملية.",
          keyPoints: [
            "التعريف المبدئي وأهميته في السياق العام.",
            "القانون الأساسي وشروط تطبيقه.",
            "أهم الفروق الجوهرية والنتائج المستخلصة."
          ],
          quiz: [
            {
              "question": "ما هو المفهوم الأساسي الذي تركزت عليه المحاضرة؟",
              "options": ["المفهوم الأول", "المفهوم الثاني", "كلاهما معاً", "لا شيء مما سبق"]
            }
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF6C63FF)),
            SizedBox(height: 24),
            Text("جاري تفريغ وتلخيص المحاضرة...", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text("يستغرق الأمر بضع ثوانٍ", style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class ResultScreen extends StatelessWidget {
  final String summary;
  final List<String> keyPoints;
  final List<Map<String, dynamic>> quiz;

  const ResultScreen({
    super.key,
    required this.summary,
    required this.keyPoints,
    required this.quiz,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("نتائج التلخيص"),
          centerTitle: true,
          bottom: const TabBar(
            indicatorColor: Color(0xFF6C63FF),
            labelColor: Color(0xFF6C63FF),
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: "الملخص"),
              Tab(text: "النقاط المهمة"),
              Tab(text: "اختبر نفسك"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: SelectableText(summary, style: const TextStyle(fontSize: 16, height: 1.8)),
            ),
            ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: keyPoints.length,
              itemBuilder: (context, i) => ListTile(
                leading: const Icon(Icons.check_circle, color: Color(0xFF6C63FF)),
                title: Text(keyPoints[i]),
              ),
            ),
            ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: quiz.length,
              itemBuilder: (context, i) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("س${i + 1}:${quiz[i]['question']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ...((quiz[i]['options'] as List).map((opt) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Text("• $opt"),
                          ))),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("ترقية الباقة")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Icon(Icons.workspace_premium, size: 70, color: Color(0xFF6C63FF)),
            const SizedBox(height: 16),
            const Text("انتهت المحاضرات المجانية", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text("اختر باقتك للمتابعة بلا حدود", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 32),
            _buildCard("أسبوعي", "49 ج.م / أسبوع"),
            _buildCard("شهري (الأكثر طلباً ⭐)", "149 ج.م / شهر"),
            _buildCard("سنوي (وفر 55%)", "799 ج.م / سنة"),
            const Spacer(),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: const Color(0xFF6C63FF),
              ),
              child: const Text("تفعيل الاشتراك", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildCard(String title, String price) {
    return Card(

      
