import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pitchscope/widgets/settings_screen.dart';
import 'package:pitchscope/utils/app_settings.dart';
import 'package:pitchscope/pitch/pitch_painter.dart';

class PitchScreen extends StatefulWidget {

  final Function(double)? onPitchDetected;
  final bool paused;

  const PitchScreen({
    super.key,
    this.onPitchDetected,
    this.paused = false,
  });

  @override
  State<PitchScreen> createState() => _PitchScreenState();
}

class _PitchScreenState extends State<PitchScreen> {

  static const MethodChannel _channel =
      MethodChannel('live_audio_stream');

  double _scrollOffset = 0;

  bool isListening = false;
  bool isRecording = false;
  bool isPaused = false;

  double pitchHz = 0;
  String currentNote = "--";

  final List<double> pitchHistory = [];

  final int minMidi = 36;
  final int maxMidi = 84;

  @override
  void initState() {
    super.initState();

    _channel.setMethodCallHandler((call) async {

      if (call.method != 'pitch') return;

      if (!isListening || isPaused || widget.paused) return;

      try {

        final args = call.arguments;
        if (args == null) return;

        final double hz = (args as num).toDouble();

        if (hz <= 0 || hz.isNaN) return;

        if (hz < 60 || hz > 3000) {
          setState(() {
            pitchHz = 0;
            currentNote = "--";
          });
          return;
        }

        final smoothed =
            _smoothPitch(pitchHz, hz, AppSettings.sensitivity.value);

        final midi = _hzToMidi(smoothed).toDouble();

        setState(() {

          pitchHz = smoothed;
          currentNote = _hzToNote(smoothed);

          pitchHistory.add(midi);

          if (pitchHistory.length > 200) {
            pitchHistory.removeAt(0);
          }

        });

        // Send pitch to parent screen (RaagaPracticeScreen)
        widget.onPitchDetected?.call(midi);

      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _stopAll();
    _channel.setMethodCallHandler(null);
    super.dispose();
  }

  double _smoothPitch(double previous, double current, double alpha) {
    if (previous == 0) return current;
    return previous + alpha * (current - previous);
  }

  Future<void> _toggleMic() async {

    try {

      if (!isListening) {
        await _channel.invokeMethod('start');
      } else {
        await _channel.invokeMethod('stop');
      }

      setState(() {

        isListening = !isListening;

        if (!isListening) {
          pitchHz = 0;
          currentNote = "--";
          pitchHistory.clear();
        }

      });

    } catch (_) {}
  }

  Future<void> _stopAll() async {

    try {
      await _channel.invokeMethod('stop');
    } catch (_) {}

    setState(() {

      isListening = false;
      isRecording = false;
      isPaused = false;

      pitchHz = 0;
      currentNote = "--";
      pitchHistory.clear();

    });
  }

  int _hzToMidi(double hz) =>
      (69 + 12 * log(hz / 440.0) / ln2).round();

  String _hzToNote(double hz) {

    const notes = [
      'C','C#','D','D#','E','F',
      'F#','G','G#','A','A#','B'
    ];

    final midi = _hzToMidi(hz);
    final octave = (midi ~/ 12) - 1;
    final index = (midi % 12 + 12) % 12;

    final note = notes[index];

    return "$note$octave";
  }

  void _openSettings() {

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return const SettingsScreen();
      },
    );

  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: const Color(0xFF1A0026),

      appBar: AppBar(
        backgroundColor: const Color(0xFF12001D),
        elevation: 0,

        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () async {
            await _stopAll();
            Navigator.pop(context);
          },
        ),

        title: const Text(
          "Pitch Monitor",
          style: TextStyle(color: Colors.white),
        ),

        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: _openSettings,
          ),
        ],
      ),

      body: Column(
        children: [

          Expanded(
            child: GestureDetector(
              onVerticalDragUpdate: (details) {

                setState(() {
                  _scrollOffset += details.delta.dy;
                });

              },

              child: ValueListenableBuilder<String>(
                valueListenable: AppSettings.major,
                builder: (context, major, child) {

                  return Stack(
                    children: [

                      CustomPaint(
                        painter: NaturalScalePainter(
                          scrollOffset: _scrollOffset,
                          rootNote: major,
                        ),
                        size: Size.infinite,
                      ),

                      CustomPaint(
                        painter: PitchPainter(
                          pitchHistory: pitchHistory,
                          minMidi: minMidi,
                          maxMidi: maxMidi,
                          scrollOffset: _scrollOffset,
                        ),
                        size: Size.infinite,
                      ),

                    ],
                  );

                },
              ),
            ),
          ),

          Container(
            height: 90,
            decoration: const BoxDecoration(
              color: Color(0xFF2B003D),
            ),

            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [

                IconButton(
                  icon: Icon(
                    isListening ? Icons.mic : Icons.mic_off,
                    color: isListening
                        ? Colors.green
                        : Colors.white70,
                  ),
                  onPressed: _toggleMic,
                ),

                IconButton(
                  icon: Icon(
                    Icons.fiber_manual_record,
                    color: isRecording
                        ? Colors.red
                        : Colors.white70,
                    size: 28,
                  ),
                  onPressed: isListening
                      ? () {
                          setState(() {
                            isRecording = !isRecording;
                            isPaused = false;
                          });
                        }
                      : null,
                ),

                IconButton(
                  icon: Icon(
                    Icons.pause_circle_outline,
                    color: isPaused
                        ? Colors.orange
                        : Colors.white,
                    size: 30,
                  ),
                  onPressed: isRecording
                      ? () {
                          setState(() {
                            isPaused = !isPaused;
                          });
                        }
                      : null,
                ),

                Text(
                  currentNote,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const IconButton(
                  icon: Icon(
                    Icons.play_arrow,
                    color: Colors.white70,
                    size: 30,
                  ),
                  onPressed: null,
                ),

                IconButton(
                  icon: const Icon(
                    Icons.stop_circle_outlined,
                    color: Colors.white70,
                    size: 28,
                  ),
                  onPressed: _stopAll,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class NaturalScalePainter extends CustomPainter {

  final double scrollOffset;
  final String rootNote;

  NaturalScalePainter({
    required this.scrollOffset,
    required this.rootNote,
  });

  static const notes = ['C','D','E','F','G','A','B'];

  @override
  void paint(Canvas canvas, Size size) {

    const normalGap = 48.0;
    const closeGap = 30.0;

    final lineNormal = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1;

    final lineBold = Paint()
      ..color = Colors.white
      ..strokeWidth = 2;

    const normalText = TextStyle(
      color: Colors.white70,
      fontSize: 15,
    );

    const boldText = TextStyle(
      color: Colors.white,
      fontSize: 18,
      fontWeight: FontWeight.bold,
    );

    double y = size.height + scrollOffset;

    for (int octave = 1; octave <= 10; octave++) {

      for (int i = notes.length - 1; i >= 0; i--) {

        final note = notes[i];
        final label = "$note$octave";

        double gap;

        if (note == 'E' || note == 'B') {
          gap = closeGap;
        } else {
          gap = normalGap;
        }

        y -= gap;

        if (y < -60 || y > size.height + 60) continue;

        final isRoot = note == rootNote;

        canvas.drawLine(
          Offset(80, y),
          Offset(size.width, y),
          isRoot ? lineBold : lineNormal,
        );

        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: isRoot ? boldText : normalText,
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        tp.paint(canvas, Offset(20, y - tp.height / 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant NaturalScalePainter oldDelegate) {
    return oldDelegate.rootNote != rootNote ||
        oldDelegate.scrollOffset != scrollOffset;
  }
}