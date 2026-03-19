import 'package:flutter/material.dart';
import '../utils/app_settings.dart';

class PitchPainter extends CustomPainter {
  final List<double> pitchHistory;
  final int minMidi;
  final int maxMidi;
  final double scrollOffset;

  PitchPainter({
    required this.pitchHistory,
    required this.minMidi,
    required this.maxMidi,
    required this.scrollOffset,
  });

  static const List<String> naturalNotes = [
    'C', 'D', 'E', 'F', 'G', 'A', 'B'
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
    return naturalNotes.contains(noteName(midi).replaceAll('♭','').replaceAll('#',''));
  }

  @override
  void paint(Canvas canvas, Size size) {

    final selectedScale = AppSettings.major.value;
    final rootNote = selectedScale.split(" ").first;
    final chromaticMode = selectedScale == "Chromatic";

    /// Background
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

    double y = size.height + scrollOffset;

    /// ================= SCALE =================

    for (int midi = maxMidi; midi >= minMidi; midi--) {

      if (!isNatural(midi)) continue;

      String note = noteName(midi);
      int oct = octave(midi);

      bool isRoot = !chromaticMode && note == rootNote;

      double gap = 48;

      if (note == 'F' || note == 'C') {
        gap = 32;
      }

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

    /// ================= USER PITCH =================

    if (pitchHistory.length < 2) return;

    final pitchPaint = Paint()
      ..color = Colors.cyanAccent
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    final path = Path();

    double? prevX;
    double? prevY;

    for (int i = 0; i < pitchHistory.length; i++) {

      double midi = pitchHistory[i];

      if (midi <= 0) continue;

      double x = size.width * i / (pitchHistory.length - 1);

      double normalized =
          (midi - minMidi) / (maxMidi - minMidi);

      double y =
          size.height * (1 - normalized.clamp(0.0, 1.0)) +
          scrollOffset;

      if (prevX == null) {

        path.moveTo(x, y);

      } else {

        double controlX = (prevX + x) / 2;

        path.cubicTo(
          controlX,
          prevY!,
          controlX,
          y,
          x,
          y,
        );
      }

      prevX = x;
      prevY = y;
    }

    canvas.drawPath(path, pitchPaint);
  }

  @override
  bool shouldRepaint(covariant PitchPainter oldDelegate) {
    return true;
  }
}