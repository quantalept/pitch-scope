import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'song_comparision_painter.dart';
import '../widgets/settings_screen.dart';

class SongPracticeScreen extends StatefulWidget {
  final SongModel song;

  const SongPracticeScreen({super.key, required this.song});

  @override
  State<SongPracticeScreen> createState() => _SongPracticeScreenState();
}

class _SongPracticeScreenState extends State<SongPracticeScreen> {
  static const MethodChannel _channel = MethodChannel('live_audio_stream');

  bool isListening = false;
  bool isPaused = false;

  String currentNote = "";

  List<double> userPitch = List.generate(150, (_) => 0.0);
  List<double> visibleSongPitch = List.generate(150, (_) => 0.0);

  List<double> fullSongPitch = [];

  double _latestMicPitch = 0;

  List<double> _pitchBuffer = [];
  double _lastStablePitch = 0;

  Timer? _timer;
  int _songIndex = 0;

  static const int frameMs = 50;

  @override
  void initState() {
    super.initState();

    _extractSongPitch();

    _channel.setMethodCallHandler((call) async {
      if (call.method == "userPitch") {
        if (!isListening || isPaused) return;

        final hz = (call.arguments as num).toDouble();

        if (hz < 60 || hz > 2000) return;

        _latestMicPitch = hz;
      }
    });

    _timer = Timer.periodic(const Duration(milliseconds: frameMs), (_) {
      if (!mounted || !isListening || isPaused) return;

      double songHz = 0;

      if (_songIndex < fullSongPitch.length) {
        songHz = fullSongPitch[_songIndex];
        _songIndex++;
      }

      double hz = _latestMicPitch;

      if (hz > 60 && hz < 2000) {
        _pitchBuffer.add(hz);
        if (_pitchBuffer.length > 5) _pitchBuffer.removeAt(0);

        hz = _pitchBuffer.reduce((a, b) => a + b) / _pitchBuffer.length;

        if (_lastStablePitch != 0 &&
            (hz - _lastStablePitch).abs() > 50) {
          hz = _lastStablePitch;
        }

        _lastStablePitch = hz;
        currentNote = _hzToNote(hz);
      } else {
        hz = 0;
        currentNote = "";
      }

      userPitch.removeAt(0);
      userPitch.add(hz);

      visibleSongPitch.removeAt(0);
      if (songHz > 60 && songHz < 2000) {
        visibleSongPitch.add(songHz);
      } else {
        visibleSongPitch.add(
          visibleSongPitch.isNotEmpty
              ? visibleSongPitch.last
              : 0,
        );
      }

      setState(() {});
    });
  }

  Future<void> _extractSongPitch() async {
    try {
      final result = await _channel.invokeMethod(
        "extractPitchFromFile",
        {"path": widget.song.data},
      );

      final raw = List<double>.from(result);

      fullSongPitch = _smoothPitch(raw);

      _songIndex = 0;

      debugPrint("✅ Song pitch loaded: ${fullSongPitch.length}");
    } catch (e) {
      debugPrint("❌ Extraction failed: $e");
    }
  }

  List<double> _smoothPitch(List<double> input) {
    List<double> output = [];

    for (int i = 0; i < input.length; i++) {
      double val = input[i];

      if (val < 80 || val > 1000) {
        output.add(output.isNotEmpty ? output.last : 0);
        continue;
      }

      double prev = i > 0 ? input[i - 1] : val;
      double next = i < input.length - 1 ? input[i + 1] : val;

      double smooth = (prev + val + next) / 3;

      if (output.isNotEmpty &&
          (smooth - output.last).abs() > 80) {
        smooth = output.last;
      }

      output.add(smooth);
    }

    return output;
  }

  String _hzToNote(double hz) {
    const notes = ['C','C#','D','D#','E','F','F#','G','G#','A','A#','B'];

    int midi = (69 + 12 * log(hz / 440) / ln2).round();
    int octave = (midi ~/ 12) - 1;

    return "${notes[midi % 12]}$octave";
  }

  Future<void> _toggleMic() async {
    try {
      if (!isListening) {
        await _channel.invokeMethod("startUser");
      } else {
        await _channel.invokeMethod("stopUser");
      }

      setState(() => isListening = !isListening);
    } catch (e) {
      debugPrint("Mic error: $e");
    }
  }

  Future<void> _stopAll() async {
    try {
      await _channel.invokeMethod("stopUser");
    } catch (_) {}

    setState(() {
      isListening = false;
      isPaused = false;
      currentNote = "";
      userPitch = List.generate(150, (_) => 0.0);
      visibleSongPitch = List.generate(150, (_) => 0.0);
      _pitchBuffer.clear();
      _lastStablePitch = 0;
      _songIndex = 0;
    });
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      builder: (_) => const SettingsScreen(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// ✅ FIXED FOOTER
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

          /// 🎯 CENTER NOTE
          Text(
            currentNote.isNotEmpty ? currentNote : "--",
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0026),

      /// 🔥 IMPORTANT FIX (removes overlay issue)
      resizeToAvoidBottomInset: false,

      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
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
                          widget.song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.song.artist ?? "",
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
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
          ),

          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: RagaComparisonPainter(
                pitchHistory: userPitch,
                referencePitch: visibleSongPitch,
                minPitch: 60,
                maxPitch: 1000,
                raagaName: "",
              ),
            ),
          ),

          /// ✅ FIXED FOOTER (no overlap ever)
          SafeArea(
            top: false,
            child: _footer(),
          ),
        ],
      ),
    );
  }
}