import 'package:flutter/material.dart';
import '../utils/app_settings.dart';
import 'dart:math';

class RagaComparisonPainter extends CustomPainter {
  final List<double> pitchHistory;
  final List<double> referencePitch;
  final double minPitch;
  final double maxPitch;
  final String raagaName;

  RagaComparisonPainter({
    required this.pitchHistory,
    required this.referencePitch,
    required this.minPitch,
    required this.maxPitch,
    required this.raagaName,
  });

  final double tolerance = 1.0;

  double hzToMidi(double hz) {
    if (hz <= 0) return 0;
    return 69 + 12 * log(hz / 440) / ln2;
  }

  static const List<String> naturalNotes = ['C','D','E','F','G','A','B'];

  String noteName(int midi) {
    const chromatic = [
      'C','C#','D','E♭','E','F',
      'F#','G','A♭','A','B♭','B'
    ];
    return chromatic[midi % 12];
  }

  int octave(int midi) => (midi ~/ 12) - 1;

  bool isNatural(int midi) {
    String note = noteName(midi).replaceAll('♭', '').replaceAll('#', '');
    return naturalNotes.contains(note);
  }

  double midiToY(double midi, double minMidi, double maxMidi, Size size) {
    double range = maxMidi - minMidi;
    if (range.abs() < 1) range = 1;

    double normalized = (midi - minMidi) / range;

    if (normalized.isNaN || normalized.isInfinite) {
      normalized = 0.5;
    }

    return size.height * (1 - normalized.clamp(0.0, 1.0));
  }

  /// 🔥 FIX: stable time mapping (NO logic change, only alignment fix)
  double _xFromIndex(int i, int total, Size size) {
    if (total <= 1) return 0;
    return (i / (total - 1)) * size.width;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final selectedScale = AppSettings.major.value;
    final rootNote = selectedScale
        .split(" ")
        .first
        .replaceAll('♯', '#')
        .replaceAll('♭', 'b')
        .trim();

    final chromaticMode = selectedScale == "Chromatic";

    /// 🎨 BACKGROUND
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF121212),
    );

    final normalLine = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1;

    final boldLine = Paint()
      ..color = Colors.white
      ..strokeWidth = 2;

    const normalText = TextStyle(color: Colors.white70, fontSize: 13);
    const boldText = TextStyle(
      color: Colors.white,
      fontSize: 15,
      fontWeight: FontWeight.bold,
    );

    double y = size.height;

    /// 🎼 LEFT SCALE (UNCHANGED - DO NOT TOUCH)
    for (int midi = 84; midi >= 36; midi--) {
      if (!isNatural(midi)) continue;

      String note = noteName(midi);
      int oct = octave(midi);
      bool isRoot = !chromaticMode && note[0] == rootNote[0];
      double gap = (note == 'F' || note == 'C') ? 32 : 48;

      y -= gap;
      if (y < -60 || y > size.height + 60) continue;

      canvas.drawLine(
        Offset(80, y),
        Offset(size.width, y),
        isRoot ? boldLine : normalLine,
      );

      final tp = TextPainter(
        text: TextSpan(
          text: "$note$oct",
          style: isRoot ? boldText : normalText,
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(20, y - tp.height / 2));
    }

    /// 🔥 WINDOW (UNCHANGED LOGIC)
    const int windowSize = 150;

    final ref = referencePitch.length > windowSize
        ? referencePitch.sublist(referencePitch.length - windowSize)
        : referencePitch;

    final user = pitchHistory.length > windowSize
        ? pitchHistory.sublist(pitchHistory.length - windowSize)
        : pitchHistory;

    if (ref.length < 2 || user.length < 2) return;

    final validRef = ref.where((e) => e > 0).toList();
    if (validRef.isEmpty) return;

    double minMidi = validRef.map(hzToMidi).reduce(min);
    double maxMidi = validRef.map(hzToMidi).reduce(max);

    if ((maxMidi - minMidi).abs() < 1) {
      maxMidi += 2;
      minMidi -= 2;
    }

    /// 🟣 MP3 LINE (FIXED ALIGNMENT ONLY)
    final refPaint = Paint()
      ..color = Colors.purpleAccent
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    double? prevX, prevY;

    for (int i = 0; i < ref.length; i++) {
      double hz = ref[i];
      if (hz <= 0) continue;

      double midi = hzToMidi(hz);

      double x = _xFromIndex(i, ref.length, size);
      double y = midiToY(midi, minMidi, maxMidi, size);

      if (prevX != null && prevY != null) {
        canvas.drawLine(
          Offset(prevX, prevY),
          Offset(x, y),
          refPaint,
        );
      }

      prevX = x;
      prevY = y;
    }

    /// 🎤 USER LINE (FIXED ALIGNMENT ONLY)
    prevX = null;
    prevY = null;

    for (int i = 0; i < user.length; i++) {
      double hz = user[i];
      if (hz <= 0) continue;

      double midi = hzToMidi(hz);

      double x = _xFromIndex(i, user.length, size);
      double y = midiToY(midi, minMidi, maxMidi, size);

      double refMidi = (i < ref.length && ref[i] > 0)
          ? hzToMidi(ref[i])
          : midi;

      double diff = midi - refMidi;

      Color color;
      if (diff.abs() <= tolerance) {
        color = Colors.green;
      } else if (diff > tolerance) {
        color = Colors.red;
      } else {
        color = Colors.yellow;
      }

      final paint = Paint()
        ..color = color
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;

      if (prevX != null && prevY != null) {
        canvas.drawLine(
          Offset(prevX, prevY),
          Offset(x, y),
          paint,
        );
      }

      prevX = x;
      prevY = y;
    }
  }

  @override
  bool shouldRepaint(covariant RagaComparisonPainter oldDelegate) => true;
}