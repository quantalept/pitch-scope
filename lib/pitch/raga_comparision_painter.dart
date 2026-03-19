import 'package:flutter/material.dart';
import '../utils/app_settings.dart';

class RagaComparisonPainter extends CustomPainter {

  final List<double> pitchHistory;
  final int minMidi;
  final int maxMidi;
  final int timeIndex;
  final String raagaName;

  RagaComparisonPainter({
    required this.pitchHistory,
    required this.minMidi,
    required this.maxMidi,
    required this.timeIndex,
    required this.raagaName,
  });

  final double tolerance = 0.5;

  /// 🎼 BUILD REAL RAGA PATTERN
  List<double> buildRagaPattern(int baseMidi) {

    switch (raagaName) {

      case "Bhairavi":
        return [
          0,1,3,5,7,8,10,12,
          8,10,12,1,3,
          5,1,3,
          1,0,
          12,10,8,7,5,3,1,0,
        ].map((i) => baseMidi + i.toDouble()).toList();

      case "Kalyani":
        return [
          0,2,4,6,7,9,11,12,
          4,6,7,9,
          6,4,2,
          12,11,9,7,6,4,2,0,
        ].map((i) => baseMidi + i.toDouble()).toList();

      case "Todi":
        return [
          0,1,3,6,7,8,10,12,
          1,3,1,0,
          8,10,12,1,3,
          6,3,1,
          12,10,8,7,6,3,1,0,
        ].map((i) => baseMidi + i.toDouble()).toList();

      case "Mayamalavagowla":
        return [
          0,1,4,5,7,8,11,12,
          11,8,7,5,4,1,0,
        ].map((i) => baseMidi + i.toDouble()).toList();

      case "Shankarabharanam":
        return [
          0,2,4,5,7,9,11,12,
          12,11,9,7,5,4,2,0,
        ].map((i) => baseMidi + i.toDouble()).toList();

      case "Mohanam":
        return [
          0,2,4,7,9,12,
          9,7,4,2,0,
        ].map((i) => baseMidi + i.toDouble()).toList();

      case "Kamboji":
        return [
          0,2,4,5,7,9,12,
          10,9,7,5,4,2,0,
          11,9,7,
        ].map((i) => baseMidi + i.toDouble()).toList();

      default:
        return [
          0,2,4,5,7,9,11,12,
        ].map((i) => baseMidi + i.toDouble()).toList();
    }
  }

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

    /// 🎯 ROOT → MIDI
    const chromatic = [
      'C','C#','D','D#','E','F',
      'F#','G','G#','A','A#','B'
    ];

    int rootIndex = chromatic.indexWhere((n) =>
        n == rootNote.replaceAll('♯', '#').replaceAll('♭', 'b'));

    if (rootIndex == -1) rootIndex = 0;

    final baseMidi = 60 + rootIndex;

    final ragaPattern = buildRagaPattern(baseMidi);

    /// BACKGROUND
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

    /// SCALE LINES (UNCHANGED)
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

    /// 🎼 REAL RAGA (SMOOTH)
    if (ragaPattern.isNotEmpty && pitchHistory.length > 1) {

      final ragaPaint = Paint()
        ..color = Colors.purpleAccent
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke;

      final ragaPath = Path();
      int len = pitchHistory.length;

      for (int i = 0; i < len; i++) {

        double progress = i / (len - 1);

        double scaledIndex =
            progress * (ragaPattern.length - 1);

        int lower = scaledIndex.floor();
        int upper = scaledIndex.ceil();

        if (upper >= ragaPattern.length) {
          upper = ragaPattern.length - 1;
        }

        double t = scaledIndex - lower;

        /// 🎵 smooth curve (gamaka feel)
        double smoothT = t * t * (3 - 2 * t);

        double midi =
            ragaPattern[lower] +
            (ragaPattern[upper] - ragaPattern[lower]) * smoothT;

        double x = size.width - (len - i) * stepX;
        double y = midiToY(midi, size);

        if (i == 0) {
          ragaPath.moveTo(x, y);
        } else {
          ragaPath.lineTo(x, y);
        }
      }

      canvas.drawPath(ragaPath, ragaPaint);
    }

    /// USER PITCH (UNCHANGED)
    if (pitchHistory.length < 2) return;

    double? prevX;
    double? prevY;

    for (int i = 0; i < pitchHistory.length; i++) {

      double midi = pitchHistory[i];
      if (midi <= 0) continue;

      double x = size.width - (pitchHistory.length - i) * stepX;
      double y = midiToY(midi, size);

      if (prevX != null) {

        double progress =
            i / (pitchHistory.length - 1);

        int idx =
            (progress * (ragaPattern.length - 1)).round();

        double target = ragaPattern[idx];
        double diff = midi - target;

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
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..isAntiAlias = true;

        canvas.drawLine(
          Offset(prevX!, prevY!),
          Offset(x, y),
          paint,
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