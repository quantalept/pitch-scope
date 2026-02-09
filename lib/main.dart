import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const PitchScopeApp());
}

class PitchScopeApp extends StatelessWidget {
  const PitchScopeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: PitchScreen(),
    );
  }
}

class PitchScreen extends StatefulWidget {
  const PitchScreen({super.key});

  @override
  State<PitchScreen> createState() => _PitchScreenState();
}

class _PitchScreenState extends State<PitchScreen>
    with SingleTickerProviderStateMixin {

  static const MethodChannel _channel =
      MethodChannel('live_audio_stream');

  bool isRunning = false;
  double pitchHz = 0;

  int? lockedCenterMidi;
  final List<double?> pitchHistory = [];

  late final AnimationController _controller;

  // 🔹 SMOOTHING (fixes "too fast" feeling)
  double smoothPitch(double previous, double current) {
    return previous == 0 ? current : previous * 0.85 + current * 0.15;
  }

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..repeat(reverse: true);

    _channel.setMethodCallHandler((call) async {
      if (!isRunning) return;

      if (call.method == 'pitch') {
        final double hz = (call.arguments as num).toDouble();

        // 🔇 SILENCE / NOISE FILTER
        if (hz < 60 || hz > 3000) {
          setState(() {
            pitchHz = 0;
            pitchHistory.add(null);
            if (pitchHistory.length > 220) {
              pitchHistory.removeAt(0);
            }
          });
          return;
        }

        final int midi = hzToMidi(hz);

        if (lockedCenterMidi == null ||
            (midi - lockedCenterMidi!).abs() >= 1) {
          lockedCenterMidi = midi;
        }

        final double last =
            pitchHistory.isNotEmpty && pitchHistory.last != null
                ? pitchHistory.last!
                : hz;

        final double smoothedHz = smoothPitch(last, hz);

        setState(() {
          pitchHz = smoothedHz;
          pitchHistory.add(smoothedHz);
          if (pitchHistory.length > 220) {
            pitchHistory.removeAt(0);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> toggle() async {
    if (!isRunning) {
      await _channel.invokeMethod('start');
    } else {
      await _channel.invokeMethod('stop');
    }

    setState(() {
      isRunning = !isRunning;
    });
  }

  int hzToMidi(double hz) =>
      (69 + 12 * log(hz / 440) / ln2).round();

  String noteName(int midi) {
    const notes = [
      'C', 'C#', 'D', 'D#', 'E', 'F',
      'F#', 'G', 'G#', 'A', 'A#', 'B'
    ];
    return notes[midi % 12];
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: toggle,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF050505),
                Color(0xFF101010),
                Color(0xFF050505),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 48),

              if (lockedCenterMidi != null)
                Column(
                  children: [
                    Text(
                      '${noteName(lockedCenterMidi!)}${(lockedCenterMidi! ~/ 12) - 1}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      noteName(lockedCenterMidi!),
                      style: const TextStyle(
                        fontSize: 88,
                        fontWeight: FontWeight.w300,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      pitchHz > 0
                          ? '${pitchHz.toStringAsFixed(0)} Hz'
                          : '-- Hz',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 16,
                      ),
                    ),
                  ],
                )
              else
                const Text(
                  'Tap to start',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                  ),
                ),

              const SizedBox(height: 24),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: CustomPaint(
                    painter: PitchPainterCrisp(
                      centerMidi: lockedCenterMidi,
                      pitchHistory: pitchHistory,
                    ),
                    size: Size.infinite,
                  ),
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

class PitchPainterCrisp extends CustomPainter {
  final int? centerMidi;
  final List<double?> pitchHistory;

  PitchPainterCrisp({
    required this.centerMidi,
    required this.pitchHistory,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (centerMidi == null) return;

    const visibleRows = 7;
    final leftPadding = 18.0;
    final rowHeight = size.height / visibleRows;
    final centerRow = visibleRows ~/ 2;

    final gridPaint = Paint()
      ..color = Colors.white10
      ..strokeWidth = 1;

    final labelStyle = const TextStyle(
      color: Colors.white30,
      fontSize: 12,
    );

    for (int i = 0; i < visibleRows; i++) {
      final midi = centerMidi! + (centerRow - i);
      final y = i * rowHeight;

      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(size.width, y),
        gridPaint,
      );

      final hz = 440 * pow(2, (midi - 69) / 12);
      final tp = TextPainter(
        text: TextSpan(
          text: '${_noteName(midi)} ${hz.round()}Hz',
          style: labelStyle,
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(canvas, Offset(0, y + (rowHeight - tp.height) / 2));
    }

    final linePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    bool started = false;

    for (int i = 0; i < pitchHistory.length; i++) {
      final pitch = pitchHistory[i];
      if (pitch == null) {
        started = false;
        continue;
      }

      final x = leftPadding +
          (size.width - leftPadding) *
              i /
              max(1, pitchHistory.length - 1);

      final midi = (69 + 12 * log(pitch / 440) / ln2).round();
      final rowOffset = centerRow - (midi - centerMidi!);

      if (rowOffset < 0 || rowOffset >= visibleRows) continue;

      final y = rowOffset * rowHeight + rowHeight / 2;

      if (!started) {
        path.moveTo(x, y);
        started = true;
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, linePaint);

    final centerY = centerRow * rowHeight + rowHeight / 2;
    canvas.drawLine(
      Offset(leftPadding, centerY),
      Offset(size.width, centerY),
      Paint()
        ..color = Colors.white24
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;

  String _noteName(int midi) {
    const notes = [
      'C', 'C#', 'D', 'D#', 'E', 'F',
      'F#', 'G', 'G#', 'A', 'A#', 'B'
    ];
    return '${notes[midi % 12]}${(midi ~/ 12) - 1}';
  }
}
