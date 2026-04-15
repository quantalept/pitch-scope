import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';
import 'package:pitchscope/utils/app_settings.dart';
import '../widgets/settings_screen.dart';
import '../pitch/raga_comparision_painter.dart';

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
  bool micPermissionGranted = false;

  final List<double> pitchHistory = [];
  final List<double> mp3PitchHistory = [];

  /// 🔥 NEW (REALTIME MP3)
  List<double> fullMp3Pitch = [];
  int mp3Index = 0;

  Timer? _timer;

  String? mp3Path;

  final double minPitch = 60.0;
  final double maxPitch = 1000.0;

  @override
  void initState() {
    super.initState();

    /// 🔥 INIT BUFFER
    mp3PitchHistory.addAll(List.generate(200, (_) => 0));

    /// 🎤 MIC STREAM
    _channel.setMethodCallHandler((call) async {
      if (!isListening || isPaused) return;

      if (call.method == 'userPitch') {
        final hz = (call.arguments as num).toDouble();
        if (hz < 60 || hz > 2000) return;

        setState(() {
          pitchHz = hz;
          currentNote = _hzToNote(hz);

          if (pitchHistory.isEmpty) {
            pitchHistory.add(hz);
          } else {
            final smooth = pitchHistory.last * 0.7 + hz * 0.3;
            pitchHistory.add(smooth);
          }

          if (pitchHistory.length > 200) {
            pitchHistory.removeAt(0);
          }
        });
      }
    });

    _loadSong();
    _loadMp3Pitch();
    _startRealtimeSync(); // 🔥 CRITICAL
  }

  /// 🎼 REALTIME SYNC TIMER
  void _startRealtimeSync() {
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!isListening || isPaused) return;

      double mp3Hz = 0;

      if (mp3Index < fullMp3Pitch.length) {
        mp3Hz = fullMp3Pitch[mp3Index];
        mp3Index++;
      }

      /// 🔥 NO JUMP / NO BREAK
      if (mp3Hz < 60 || mp3Hz > 1000) {
        mp3Hz =
            mp3PitchHistory.isNotEmpty ? mp3PitchHistory.last : 0;
      }

      /// 🔥 MOVE GRAPH
      mp3PitchHistory.removeAt(0);
      mp3PitchHistory.add(mp3Hz);

      setState(() {});
    });
  }

  /// 🎵 Hz → Note
  String _hzToNote(double hz) {
    const notes = [
      'C','C#','D','D#','E','F',
      'F#','G','G#','A','A#','B'
    ];
    int midi = (69 + 12 * log(hz / 440) / ln2).round();
    int octave = (midi ~/ 12) - 1;
    return "${notes[midi % 12]}$octave";
  }

  /// 🎧 LOAD MP3
  Future<void> _loadSong() async {
    try {
      String assetPath = 'assets/songs/Bhairavi_ragam.mp3';

      final data = await rootBundle.load(assetPath);
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

  /// 🎼 LOAD FULL PITCH (NO TRIM)
  Future<void> _loadMp3Pitch() async {
    try {
      final jsonString =
          await rootBundle.loadString("assets/pitch/bhairavi_pitch.json");

      final data = jsonDecode(jsonString);

      fullMp3Pitch = List<double>.from(data['pitch']);
      mp3Index = 0;

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Pitch load error: $e");
    }
  }

  /// 🎤 MIC
  Future<void> _toggleMic() async {
    if (!micPermissionGranted) {
      if (!await recorder.hasPermission()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Microphone permission required")),
        );
        return;
      } else {
        micPermissionGranted = true;
      }
    }

    try {
      if (!isListening) {
        await _channel.invokeMethod('startUser');
        if (mp3Path != null) await player.play();
      } else {
        await _channel.invokeMethod('stopUser');
        await player.stop();
      }

      setState(() => isListening = !isListening);
    } catch (e) {
      debugPrint("Mic error: $e");
    }
  }

  /// ⛔ STOP
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
      pitchHz = 0;
      currentNote = "--";
      mp3Index = 0;
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
            currentNote != "--" ? currentNote : "--",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            icon: Icon(
              isPaused ? Icons.pause_circle : Icons.pause_circle_outline,
              color: Colors.orange,
            ),
            onPressed: () => setState(() => isPaused = !isPaused),
          ),
          IconButton(
            icon: const Icon(Icons.stop_circle_outlined,
                color: Colors.white),
            onPressed: _stopAll,
          ),
          const Icon(Icons.play_arrow,
              color: Colors.lightBlueAccent),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopAll();
    player.dispose();
    recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0026),
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
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
          Expanded(
            child: CustomPaint(
              painter: RagaComparisonPainter(
                pitchHistory: pitchHistory,
                referencePitch: mp3PitchHistory,
                minPitch: minPitch,
                maxPitch: maxPitch,
                raagaName: widget.raagaName,
              ),
              size: Size.infinite,
            ),
          ),
          SafeArea(
            top: false,
            child: _footer(),
          ),
        ],
      ),
    );
  }
}