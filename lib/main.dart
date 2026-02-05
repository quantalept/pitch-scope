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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const PitchScreen(),
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
  static const MethodChannel _channel = MethodChannel('live_audio_stream');

  bool isRunning = false;
  double pitchHz = 0;

  int? lockedCenterMidi;
  final List<double?> pitchHistory = [];

  late final AnimationController _controller;

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
        final hz = (call.arguments as num).toDouble();

        if (hz < 60 || hz > 3000) {
          pitchHistory.add(null);
          return;
        }

        final midi = hzToMidi(hz);

        if (lockedCenterMidi == null ||
            (midi - lockedCenterMidi!).abs() >= 1) {
          lockedCenterMidi = midi;
        }

        setState(() {
          pitchHz = hz;
          pitchHistory.add(hz);
          if (pitchHistory.length > 220) pitchHistory.removeAt(0);
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

  int hzToMidi(double hz) => (69 + 12 * log(hz / 440) / ln2).round();

  String noteName(int midi) {
    const notes = [
      'C',
      'C#',
      'D',
      'D#',
      'E',
      'F',
      'F#',
      'G',
      'G#',
      'A',
      'A#',
      'B'
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

              // TOP 3 LINES CENTERED
              if (lockedCenterMidi != null)
                Column(
                  children: [
                    Text(
                      '${noteName(lockedCenterMidi!)}${(lockedCenterMidi! ~/ 12) - 1}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 18,
                        letterSpacing: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      noteName(lockedCenterMidi!),
                      style: const TextStyle(
                        fontSize: 88,
                        fontWeight: FontWeight.w300,
                        color: Colors.white,
                        letterSpacing: -2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      pitchHz > 0 ? '${pitchHz.toStringAsFixed(0)} Hz' : '-- Hz',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                )
              else
                Text(
                  'Tap to start',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                  ),
                  textAlign: TextAlign.center,
                ),

              const SizedBox(height: 24),

              // PITCH GRAPH (full width, left-aligned)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: NeonPitchPainterWithDots(
                          centerMidi: lockedCenterMidi,
                          pitchHistory: pitchHistory,
                          animationValue: _controller.value,
                        ),
                        size: Size.infinite,
                      );
                    },
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

/// NEON PITCH PAINTER WITH DOTS AND LABELS
class NeonPitchPainterWithDots extends CustomPainter {
  final int? centerMidi;
  final List<double?> pitchHistory;
  final double animationValue;

  NeonPitchPainterWithDots({
    required this.centerMidi,
    required this.pitchHistory,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 🔴 BACKGROUND WITH GRADIENT
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFF050505),
          Color(0xFF101010),
          Color(0xFF050505),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Offset.zero & size, bgPaint);

    if (centerMidi == null) return;

    const visibleRows = 7;
    final leftPadding = 16.0;
    final rowHeight = size.height / visibleRows;
    final centerRow = visibleRows ~/ 2;

    final labelStyle = const TextStyle(
      color: Colors.white30,
      fontSize: 12,
    );

    final gridPaint = Paint()
      ..color = Colors.white10
      ..strokeWidth = 1;

    // horizontal grid + labels
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

    // neon line (change to white)
final linePaint = Paint()
  ..color = Colors.white // <-- change from gradient to plain white
  ..strokeWidth = 3
  ..style = PaintingStyle.stroke
  ..strokeCap = StrokeCap.round
  ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);


    final path = Path();
    bool hasStarted = false;

    for (int i = 0; i < pitchHistory.length; i++) {
      final pitch = pitchHistory[i];
      if (pitch == null) {
        hasStarted = false;
        continue;
      }

      final x =
          leftPadding + (size.width - leftPadding) * i / (pitchHistory.length - 1);
      final midi = (69 + 12 * log(pitch / 440) / ln2).round();
      final rowOffset = centerRow - (midi - centerMidi!);

      if (rowOffset < 0 || rowOffset >= visibleRows) continue;
      final y = rowOffset * rowHeight + rowHeight / 2;

      if (!hasStarted) {
        path.moveTo(x, y);
        hasStarted = true;
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, linePaint);

    // glowing dots
    final dotPaint = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.5 + 0.5 * animationValue)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    for (int i = 0; i < pitchHistory.length; i++) {
      final pitch = pitchHistory[i];
      if (pitch == null) continue;

      final x =
          leftPadding + (size.width - leftPadding) * i / (pitchHistory.length - 1);
      final midi = (69 + 12 * log(pitch / 440) / ln2).round();
      final rowOffset = centerRow - (midi - centerMidi!);
      if (rowOffset < 0 || rowOffset >= visibleRows) continue;

      final y = rowOffset * rowHeight + rowHeight / 2;
      canvas.drawCircle(Offset(x, y), 4, dotPaint);
    }

    // center line
    final centerY = centerRow * rowHeight + rowHeight / 2;
    final centerLinePaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(leftPadding, centerY),
      Offset(size.width, centerY),
      centerLinePaint,
    );
  }

  @override
  bool shouldRepaint(covariant NeonPitchPainterWithDots oldDelegate) => true;

  String _noteName(int midi) {
    const notes = [
      'C', 'C#', 'D', 'D#', 'E', 'F',
      'F#', 'G', 'G#', 'A', 'A#', 'B'
    ];
    return '${notes[midi % 12]}${(midi ~/ 12) - 1}';
  }
}
