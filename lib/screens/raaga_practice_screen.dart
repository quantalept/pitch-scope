import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';
import 'package:pitchscope/utils/app_settings.dart';
import '../widgets/settings_screen.dart';
import '../pitch/raga_comparision_painter.dart';
import 'dart:async';

class RaagaPracticeScreen extends StatefulWidget {
  final String raagaName;
  final String songName;
  final String lyric;

  const RaagaPracticeScreen({
    super.key,
    required this.raagaName,
    required this.songName,
    required this.lyric,
  });

  @override
  State<RaagaPracticeScreen> createState() => _RaagaPracticeScreenState();
}

class _RaagaPracticeScreenState extends State<RaagaPracticeScreen> {
  static const MethodChannel _channel = MethodChannel('live_audio_stream');

  final AudioPlayer player = AudioPlayer();
  final AudioRecorder recorder = AudioRecorder();

  bool isListening = false;
  bool isPaused = false;

  double pitchHz = 0;
  String currentNote = "--";

  final List<double> pitchHistory = [];
  final List<double> mp3PitchHistory = [];

  List<double> fullMp3Pitch = [];
  int mp3Index = 0;

  // Version counter for efficient shouldRepaint
  int _paintVersion = 0;

  Timer? _timer;
  String? mp3Path;

  @override
  void initState() {
    super.initState();

    // Init buffer
    mp3PitchHistory.addAll(List.generate(200, (_) => 0));

    // User pitch stream from native
    _channel.setMethodCallHandler((call) async {
      if (isPaused) return;

      if (call.method == 'userPitch') {
        final hz = (call.arguments as num).toDouble();

        debugPrint("🎤 USER HZ: $hz");

        if (hz < 60 || hz > 2000) return;

        setState(() {
          pitchHz = hz;
          currentNote = _hzToNote(hz);

          final smooth = pitchHistory.isEmpty
              ? hz
              : pitchHistory.last * 0.7 + hz * 0.3;

          pitchHistory.add(smooth);
          if (pitchHistory.length > 200) {
            pitchHistory.removeAt(0);
          }

          _paintVersion++;
        });
      }
    });

    _init();
  }

  Future<void> _init() async {
    await _loadSong();
    await _loadMp3Pitch();
    _startRealtimeSync();
  }

  void _startRealtimeSync() {
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (isPaused) return;

      double mp3Hz = 0;

      if (mp3Index < fullMp3Pitch.length) {
        mp3Hz = fullMp3Pitch[mp3Index];
        mp3Index++;
      }

      if (mp3Hz < 60 || mp3Hz > 1000) {
        mp3Hz = mp3PitchHistory.isNotEmpty ? mp3PitchHistory.last : 0;
      }

      if (mp3PitchHistory.isNotEmpty) {
        mp3PitchHistory.removeAt(0);
      }

      mp3PitchHistory.add(mp3Hz);

      _paintVersion++;
      setState(() {});
    });
  }

  String _hzToNote(double hz) {
    const notes = [
      'C', 'C#', 'D', 'D#', 'E', 'F',
      'F#', 'G', 'G#', 'A', 'A#', 'B'
    ];
    int midi = (69 + 12 * log(hz / 440) / ln2).round();
    int octave = (midi ~/ 12) - 1;
    return "${notes[midi % 12]}$octave";
  }

  Future<void> _loadSong() async {
    try {
      final data = await rootBundle.load('assets/songs/Bhairavi_ragam.mp3');
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/${widget.raagaName}.mp3');

      await file.writeAsBytes(data.buffer.asUint8List());
      mp3Path = file.path;

      await player.setFilePath(mp3Path!);
      await player.setVolume(0);
    } catch (e) {
      debugPrint("MP3 load error: $e");
    }
  }

  Future<void> _loadMp3Pitch() async {
    try {
      final jsonString =
          await rootBundle.loadString("assets/pitch/bhairavi_pitch.json");

      final data = jsonDecode(jsonString);

      fullMp3Pitch = List<double>.from(data['pitch']);

      mp3PitchHistory.clear();
      for (int i = 0; i < 200; i++) {
        mp3PitchHistory.add(i < fullMp3Pitch.length ? fullMp3Pitch[i] : 0);
      }

      mp3Index = 200;

      _paintVersion++;
      setState(() {});
    } catch (e) {
      debugPrint("Pitch load error: $e");
    }
  }

  Future<void> _toggleMic() async {
    if (!await recorder.hasPermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission is required to practice.'),
          ),
        );
      }
      return;
    }

    if (!isListening) {
      await _channel.invokeMethod('startUser');
      if (mp3Path != null) await player.play();
    } else {
      await _channel.invokeMethod('stopUser');
      await player.stop();
    }

    setState(() => isListening = !isListening);
  }

  Future<void> _stopAll() async {
    try {
      await _channel.invokeMethod('stopUser');
    } catch (_) {}

    await player.stop();
    _timer?.cancel();

    setState(() {
      isListening = false;
      isPaused = false;
      pitchHistory.clear();
      mp3PitchHistory.clear();
      mp3PitchHistory.addAll(List.generate(200, (_) => 0));
      mp3Index = 0;
      pitchHz = 0;
      currentNote = "--";
      _paintVersion++;
    });
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      builder: (_) => const SettingsScreen(),
    );
  }

  Widget _footer() {
    return Container(
      height: 85,
      color: const Color(0xFF2B003D),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: Icon(
              isListening ? Icons.mic : Icons.mic_off,
              color: isListening ? Colors.greenAccent : Colors.white,
            ),
            onPressed: _toggleMic,
          ),
          Text(
            currentNote,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            icon: Icon(
              isPaused ? Icons.play_circle : Icons.pause_circle,
              color: Colors.orange,
            ),
            onPressed: () => setState(() => isPaused = !isPaused),
          ),
          IconButton(
            icon: const Icon(Icons.stop_circle_outlined, color: Colors.white),
            onPressed: _stopAll,
          ),
          const Icon(Icons.play_arrow, color: Colors.lightBlueAccent),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    player.dispose();
    recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0026),
      body: Column(
        children: [
          SafeArea(
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () async {
                    await _stopAll();
                    Navigator.pop(context);
                  },
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        "${widget.songName} - ${widget.raagaName}",
                        style: const TextStyle(color: Colors.white),
                      ),
                      Text(
                        widget.lyric,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.settings, color: Colors.white),
                  onPressed: _openSettings,
                ),
              ],
            ),
          ),

          // ✅ SizedBox.expand ensures canvas gets full available size
          Expanded(
            child: SizedBox.expand(
              child: CustomPaint(
                painter: RagaComparisonPainter(
                  pitchHistory: isListening ? pitchHistory : [],
                  referencePitch: isListening ? mp3PitchHistory : [],
                  minPitch: 60,
                  maxPitch: 1000,
                  raagaName: widget.raagaName,
                  version: _paintVersion,
                ),
              ),
            ),
          ),

          _footer(),
        ],
      ),
    );
  }
}