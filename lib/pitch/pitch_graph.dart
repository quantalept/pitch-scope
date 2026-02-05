import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'dart:math';


void main() {
  runApp(const PitchApp());
}

class PitchApp extends StatelessWidget {
  const PitchApp({super.key});

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

class _PitchScreenState extends State<PitchScreen> {
  final StreamController<double> _pitchController =
      StreamController<double>();

  double currentHz = 0;
  String currentNote = '--';

  @override
  void initState() {
    super.initState();

    // 🔧 Fake pitch stream for demo (replace with mic input)
    double hz = 300;
    Timer.periodic(const Duration(milliseconds: 40), (_) {
      hz += (Random().nextDouble() - 0.5) * 10;
      currentHz = hz.clamp(60, 1000);
      currentNote = hzToNote(currentHz);

      _pitchController.add(currentHz);
      setState(() {});
    });
  }

  @override
  void dispose() {
    _pitchController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Stack(
        children: [
          // FULL SCREEN GRAPH
          Positioned.fill(
            child: PitchGraph(
              pitchStream: _pitchController.stream,
              minHz: 60,
              maxHz: 1000,
            ),
          ),

          // TOP CENTER NOTE + HZ
          Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(
                  currentNote,
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w300,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${currentHz.toStringAsFixed(1)} Hz',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

double hzToY(double hz, double minHz, double maxHz, double height) {
  final clamped = hz.clamp(minHz, maxHz);
  return height - ((clamped - minHz) / (maxHz - minHz)) * height;
}

class PitchGraph extends StatefulWidget {
  final Stream<double> pitchStream;
  final double minHz;
  final double maxHz;

  const PitchGraph({
    super.key,
    required this.pitchStream,
    this.minHz = 60,
    this.maxHz = 1000,
  });

  @override
  State<PitchGraph> createState() => _PitchGraphState();
}

class _PitchGraphState extends State<PitchGraph> {
  static const int maxPoints = 200;
  final List<double> _pitches = [];

  @override
  void initState() {
    super.initState();
    widget.pitchStream.listen((hz) {
      setState(() {
        _pitches.add(hz);
        if (_pitches.length > maxPoints) {
          _pitches.removeAt(0);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: PitchPainter(
            pitches: _pitches,
            maxPoints: maxPoints,
            minHz: widget.minHz,
            maxHz: widget.maxHz,
          ),
        );
      },
    );
  }
}

class PitchPainter extends CustomPainter {
  final List<double> pitches;
  final int maxPoints;
  final double minHz;
  final double maxHz;

  PitchPainter({
    required this.pitches,
    required this.maxPoints,
    required this.minHz,
    required this.maxHz,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // BACKGROUND
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF121212),
    );

    // GRID LINES
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..strokeWidth = 1;

    for (final hz in [82, 110, 147, 196, 247, 330, 440, 659]) {
      final y = hzToY(hz.toDouble(), minHz, maxHz, size.height);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (pitches.length < 2) return;

    final pitchPaint = Paint()
      ..color = Colors.cyanAccent
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final dx = size.width / (maxPoints - 1);

    for (int i = 1; i < pitches.length; i++) {
      if (pitches[i] <= 0 || pitches[i - 1] <= 0) continue;

      canvas.drawLine(
        Offset(
          (i - 1) * dx,
          hzToY(pitches[i - 1], minHz, maxHz, size.height),
        ),
        Offset(
          i * dx,
          hzToY(pitches[i], minHz, maxHz, size.height),
        ),
        pitchPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

String hzToNote(double hz) {
  const a4 = 440.0;
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

  final noteNumber = (12 * (log(hz / a4) / ln2)).round() + 69;
  final noteIndex = noteNumber % 12;
  final octave = (noteNumber / 12).floor() - 1;

  return '${notes[noteIndex]}$octave';
}
