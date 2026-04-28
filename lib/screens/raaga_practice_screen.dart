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

  // Both arrays always 200 items, index-aligned by time
  final List<double> pitchHistory =
      List.filled(200, 0.0, growable: true);
  final List<double> mp3PitchHistory =
      List.filled(200, 0.0, growable: true);

  List<double> fullMp3Pitch = [];
  int mp3Index = 0;

  // Pending user pitch — set by native callback, consumed by timer
  double _pendingUserHz = 0.0;
  double _lastValidUserHz = 0.0;
  int _silenceCount = 0;

  int _paintVersion = 0;

  Timer? _timer;
  String? mp3Path;

  @override
  void initState() {
    super.initState();

    // Native pitch callback — just stores value, timer consumes it
    _channel.setMethodCallHandler((call) async {
      if (isPaused) return;
      if (call.method == 'userPitch') {
        final hz = (call.arguments as num).toDouble();
        debugPrint("🎤 USER HZ: $hz");
        if (hz >= 60 && hz <= 2000) {
          _pendingUserHz = hz;
          _lastValidUserHz = hz;
          _silenceCount = 0;
        } else {
          _silenceCount++;
          // Hold last valid pitch for 12 ticks (~600ms) before going silent
          _pendingUserHz = _silenceCount <= 12 ? _lastValidUserHz : 0.0;
        }
      }
    });

    // Only load assets — do NOT start timer here
    _init();
  }

  Future<void> _init() async {
    await _loadSong();
    await _loadMp3Pitch();
  }

  // Called ONLY when mic button is pressed
  void _startRealtimeSync() {
    _timer?.cancel();

    // Reset both arrays to zero before starting
    pitchHistory.clear();
    pitchHistory.addAll(List.filled(200, 0.0));
    mp3PitchHistory.clear();
    mp3PitchHistory.addAll(List.filled(200, 0.0));
    mp3Index = 0;

    _pendingUserHz = 0.0;
    _lastValidUserHz = 0.0;
    _silenceCount = 0;

    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (isPaused) return;

      // Advance mp3 pitch by one step
      double mp3Hz = 0.0;
      if (mp3Index < fullMp3Pitch.length) {
        mp3Hz = fullMp3Pitch[mp3Index];
        mp3Index++;
      }

      // Smooth reference
      final double prevRef = mp3PitchHistory.last;
      final double smoothRef = (mp3Hz > 60 && prevRef > 60)
          ? prevRef * 0.7 + mp3Hz * 0.3
          : mp3Hz;

      // Spike rejection — ignore jumps larger than 5 semitones
      double rawUser = _pendingUserHz;
      if (rawUser > 60 && _lastValidUserHz > 60) {
        final double semitoneJump =
            (12 * log(rawUser / _lastValidUserHz) / ln2).abs();
        if (semitoneJump > 5) {
          rawUser = _lastValidUserHz; // reject spike, hold last good value
        }
      }

      // Strong smoothing — 85% old, 15% new — keeps line horizontal
      final double prevUser = pitchHistory.last;
      final double smoothUser = (rawUser > 60 && prevUser > 60)
          ? prevUser * 0.85 + rawUser * 0.15
          : rawUser;

      // Shift both arrays left by 1, append new value at end
      mp3PitchHistory.removeAt(0);
      mp3PitchHistory.add(smoothRef);

      pitchHistory.removeAt(0);
      pitchHistory.add(smoothUser);

      // Update displayed note
      if (smoothUser > 60) {
        pitchHz = smoothUser;
        currentNote = _hzToNote(smoothUser);
      }

      _paintVersion++;
      if (mounted) setState(() {});
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
      debugPrint("✅ Loaded ${fullMp3Pitch.length} mp3 pitch frames");
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
      // Start mic + song + timer all at the same moment
      await _channel.invokeMethod('startUser');
      if (mp3Path != null) await player.play();
      _startRealtimeSync();
    } else {
      await _channel.invokeMethod('stopUser');
      await player.stop();
      _timer?.cancel();
      _timer = null;
    }

    setState(() => isListening = !isListening);
  }

  Future<void> _stopAll() async {
    try {
      await _channel.invokeMethod('stopUser');
    } catch (_) {}

    await player.stop();
    _timer?.cancel();
    _timer = null;

    setState(() {
      isListening = false;
      isPaused = false;
      pitchHistory.clear();
      pitchHistory.addAll(List.filled(200, 0.0));
      mp3PitchHistory.clear();
      mp3PitchHistory.addAll(List.filled(200, 0.0));
      mp3Index = 0;
      pitchHz = 0;
      currentNote = "--";
      _pendingUserHz = 0.0;
      _lastValidUserHz = 0.0;
      _silenceCount = 0;
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

          Expanded(
            child: SizedBox.expand(
              child: CustomPaint(
                painter: RagaComparisonPainter(
                  pitchHistory: List.of(pitchHistory),
                  referencePitch: List.of(mp3PitchHistory),
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