import 'package:flutter/material.dart';
import '../utils/app_settings.dart';

class RagaComparisonPainter extends CustomPainter {

  final List<double> pitchHistory;
  final List<double> ragaPattern;
  final int minMidi;
  final int maxMidi;
  final int timeIndex;

  RagaComparisonPainter({
    required this.pitchHistory,
    required this.ragaPattern,
    required this.minMidi,
    required this.maxMidi,
    required this.timeIndex,
  });

  final double tolerance = 0.5;

  static const List<String> naturalNotes = [
    'C','D','E','F','G','A','B'
  ];

  String noteName(int midi) {
    const chromatic = [
      'C','C#','D','E♭','E','F',
      'F#','G','A♭','A','B♭','B'
    ];
    return chromatic[midi % 12];
  }

  int octave(int midi) {
    return (midi ~/ 12) - 1;
  }

  bool isNatural(int midi) {
    String note = noteName(midi);
    note = note.replaceAll('♭', '').replaceAll('#', '');
    return naturalNotes.contains(note);
  }

  double midiToY(double midi, Size size) {
    double normalized =
        (midi - minMidi) / (maxMidi - minMidi);

    return size.height *
        (1 - normalized.clamp(0.0, 1.0));
  }

  @override
  void paint(Canvas canvas, Size size) {

    final selectedScale = AppSettings.major.value;
    final rootNote = selectedScale.split(" ").first;
    final chromaticMode = selectedScale == "Chromatic";

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

    const normalText = TextStyle(
      color: Colors.white70,
      fontSize: 13,
    );

    const boldText = TextStyle(
      color: Colors.white,
      fontSize: 15,
      fontWeight: FontWeight.bold,
    );

    double y = size.height;

    /// SCALE LINES
    for (int midi = maxMidi; midi >= minMidi; midi--) {

      if (!isNatural(midi)) continue;

      String note = noteName(midi);
      int oct = octave(midi);

      bool isRoot = !chromaticMode && note == rootNote;

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

    const double stepX = 6;

    /// ✅ RAGA GUIDE (SCROLLING WITH USER PITCH)
    if (ragaPattern.isNotEmpty && pitchHistory.length > 1) {

      final ragaPaint = Paint()
        ..color = Colors.purpleAccent
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke;

      final ragaPath = Path();

      int historyLen = pitchHistory.length;

      for (int i = 0; i < historyLen; i++) {

        double progress = i / (historyLen - 1);

        int ragaIndex =
            (progress * (ragaPattern.length - 1)).round();

        double midi = ragaPattern[ragaIndex];

        double x =
            size.width - (historyLen - i) * stepX;

        double y = midiToY(midi, size);

        if (i == 0) {
          ragaPath.moveTo(x, y);
        } else {
          ragaPath.lineTo(x, y);
        }
      }

      canvas.drawPath(ragaPath, ragaPaint);
    }

    /// ✅ USER PITCH (SCROLLING)
    if (pitchHistory.length < 2) return;

    double? prevX;
    double? prevY;

    for (int i = 0; i < pitchHistory.length; i++) {

      double midi = pitchHistory[i];
      if (midi <= 0) continue;

      double x =
          size.width - (pitchHistory.length - i) * stepX;

      double y = midiToY(midi, size);

      if (prevX != null) {

        double progress =
            i / (pitchHistory.length - 1);

        int ragaIndex =
            (progress * (ragaPattern.length - 1)).round();

        double target = ragaPattern[ragaIndex];

        double diff = midi - target;

        Color color;

        if (diff.abs() <= tolerance) {
          color = Colors.green;
        } else if (diff > tolerance) {
          color = Colors.red;
        } else {
          color = Colors.yellow;
        }

        final pitchPaint = Paint()
          ..color = color
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..isAntiAlias = true;

        canvas.drawLine(
          Offset(prevX!, prevY!),
          Offset(x, y),
          pitchPaint,
        );
      }

      prevX = x;
      prevY = y;
    }
  }

  @override
  bool shouldRepaint(covariant RagaComparisonPainter oldDelegate) {
    return true;
  }
}