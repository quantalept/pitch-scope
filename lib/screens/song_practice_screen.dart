import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'song_comparision_painter.dart';
import '../widgets/settings_screen.dart';

class SongPracticeScreen extends StatefulWidget {
  final SongModel song;
  final String lyrics;

  const SongPracticeScreen({
    super.key,
    required this.song,
    required this.lyrics,
  });

  @override
  State<SongPracticeScreen> createState() =>
      _SongPracticeScreenState();
}

class _SongPracticeScreenState extends State<SongPracticeScreen> {
  static const MethodChannel _channel =
      MethodChannel('live_audio_stream');

  bool isListening = false;
  bool isPaused = false;

  String currentNote = "";

  List<double> userPitch = List.generate(150, (_) => 0.0);
  List<double> visibleSongPitch =
      List.generate(150, (_) => 0.0);

  List<double> fullSongPitch = [];

  double _latestMicPitch = 0;

  Timer? _timer;

  int _songStartTime = 0;
  double _pitchFrameMs = 50;

  static const int frameMs = 50;

  // =======================
  // 🎵 LYRICS MODAL
  // =======================
  void _showLyrics() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A0026),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) {
        final isEmpty =
            widget.lyrics.trim().isEmpty ||
            widget.lyrics.contains("No lyrics");

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (_, controller) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                controller: controller,
                child: Text(
                  isEmpty
                      ? "No lyrics available for this song"
                      : widget.lyrics,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  double smoothPitch(double current, double previous) {
    if (current.isNaN || current.isInfinite || current <= 0) {
      return previous;
    }

    if (current < 40 || current > 2000) {
      return previous;
    }

    if (previous != 0) {
      double diff = (current - previous).abs();
      if (diff > 300) {
        return previous;
      }
    }

    const alpha = 0.25;
    return previous == 0
        ? current
        : (alpha * current + (1 - alpha) * previous);
  }

  @override
  void initState() {
    super.initState();

    _extractSongPitch();

    _channel.setMethodCallHandler((call) async {
      if (call.method == "userPitch") {
        if (!isListening || isPaused) return;

        final hz = (call.arguments as num).toDouble();

        if (hz < 40 || hz > 2000) return;

        _latestMicPitch = hz;
      }
    });

    _timer = Timer.periodic(
      const Duration(milliseconds: frameMs),
      (_) {
        if (!mounted || !isListening || isPaused) return;

        double songHz = 0;

        if (_songStartTime != 0 && fullSongPitch.isNotEmpty) {
          final now = DateTime.now().millisecondsSinceEpoch;
          final elapsedMs = now - _songStartTime;

          int index = (elapsedMs / _pitchFrameMs).floor();

          if (index >= 0 && index < fullSongPitch.length) {
            songHz = fullSongPitch[index];
          }
        }

        double hz = _latestMicPitch;

        double previousUser =
            userPitch.isNotEmpty ? userPitch.last : 0;

        hz = smoothPitch(hz, previousUser);

        currentNote = hz > 0 ? _hzToNote(hz) : "";

        userPitch.removeAt(0);
        userPitch.add(hz);

        visibleSongPitch.removeAt(0);

        double prevSong =
            visibleSongPitch.isNotEmpty ? visibleSongPitch.last : 0;

        if (songHz > 40 && songHz < 2000) {
          songHz = smoothPitch(songHz, prevSong);
          visibleSongPitch.add(songHz);
        } else {
          visibleSongPitch.add(prevSong);
        }

        setState(() {});
      },
    );
  }

  Future<void> _extractSongPitch() async {
    try {
      final result = await _channel.invokeMethod(
        "extractPitchFromFile",
        {"path": widget.song.data},
      );

      final raw = List<double>.from(result);
      final smoothed = _smoothPitch(raw);

      setState(() {
        fullSongPitch = smoothed;
        _songStartTime = DateTime.now().millisecondsSinceEpoch;
      });

      debugPrint("✅ Song pitch loaded: ${fullSongPitch.length}");
    } catch (e) {
      debugPrint("❌ Extraction failed: $e");
    }
  }

  List<double> _smoothPitch(List<double> input) {
    List<double> output = [];
    double lastValid = 0;

    for (var val in input) {
      if (val < 40 || val > 2000) {
        output.add(lastValid);
        continue;
      }

      if (lastValid != 0 && (val - lastValid).abs() > 120) {
        output.add(lastValid);
        continue;
      }

      lastValid = val;
      output.add(val);
    }

    return output;
  }

  String _hzToNote(double hz) {
    const notes = [
      'C','C#','D','D#','E','F',
      'F#','G','G#','A','A#','B'
    ];

    int midi =
        (69 + 12 * log(hz / 440) / ln2).round();
    int octave = (midi ~/ 12) - 1;

    return "${notes[midi % 12]}$octave";
  }

  Future<void> _toggleMic() async {
    try {
      if (!isListening) {
        await _channel.invokeMethod("startUser");
        _songStartTime =
            DateTime.now().millisecondsSinceEpoch;
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
      visibleSongPitch =
          List.generate(150, (_) => 0.0);
      _songStartTime = 0;
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
        mainAxisAlignment:
            MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: Icon(
              isListening
                  ? Icons.mic
                  : Icons.mic_off,
              color: isListening
                  ? Colors.greenAccent
                  : Colors.white,
            ),
            onPressed: _toggleMic,
          ),
          Text(
            currentNote.isNotEmpty
                ? currentNote
                : "--",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            icon: Icon(
              isPaused
                  ? Icons.pause_circle
                  : Icons.pause_circle_outline,
              color: Colors.orange,
            ),
            onPressed: () =>
                setState(() => isPaused = !isPaused),
          ),
          IconButton(
            icon: const Icon(
                Icons.stop_circle_outlined,
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
      body: Column(
        children: [
          /// TOP BAR
          SafeArea(
            bottom: false,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back,
                        color: Colors.white),
                    onPressed: () async {
                      await _stopAll();
                      Navigator.pop(context);
                    },
                  ),
                  Expanded(
                    child: Text(
                      widget.song.artist ?? "",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings,
                        color: Colors.white),
                    onPressed: _openSettings,
                  ),
                ],
              ),
            ),
          ),

          /// GRAPH + LYRICS OVERLAY
          Expanded(
            child: Stack(
              children: [
                CustomPaint(
                  size: Size.infinite,
                  painter: RagaComparisonPainter(
                    pitchHistory: userPitch,
                    referencePitch: visibleSongPitch,
                    minPitch: 60,
                    maxPitch: 1000,
                    raagaName: "",
                  ),
                ),

                /// 🎯 CENTERED TITLE + ADD LYRICS (LIKE YOUR IMAGE)
                Positioned(
                  top: 12,
                  left: 0,
                  right: 0,
                  child: Column(
                    children: [
                      Text(
                        widget.song.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: _showLyrics,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border:
                                Border.all(color: Colors.white24),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lyrics_outlined,
                                  color: Colors.white70,
                                  size: 16),
                              SizedBox(width: 6),
                              Text(
                                "Add Lyrics",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          /// FOOTER
          SafeArea(
            top: false,
            child: _footer(),
          ),
        ],
      ),
    );
  }
}