import 'package:flutter/material.dart';
import '../utils/app_settings.dart';
import 'dart:math';

class RagaComparisonPainter extends CustomPainter {
  final List<double> pitchHistory;
  final List<double> referencePitch;
  final double minPitch;
  final double maxPitch;
  final String raagaName;
  final int version;

  RagaComparisonPainter({
    required this.pitchHistory,
    required this.referencePitch,
    required this.minPitch,
    required this.maxPitch,
    required this.raagaName,
    this.version = 0,
  });

  final double tolerance = 1.0;

  static const double scaleWidth = 80;

  static const List<String> naturalNotes = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];

  double hzToMidi(double hz) {
    if (hz <= 0) return 0;
    return 69 + 12 * log(hz / 440) / ln2;
  }

  String noteName(int midi) {
    const chromatic = [
      'C', 'C#', 'D', 'E♭', 'E', 'F',
      'F#', 'G', 'A♭', 'A', 'B♭', 'B'
    ];
    return chromatic[midi % 12];
  }

  int octave(int midi) => (midi ~/ 12) - 1;

  bool isNatural(int midi) {
    String note = noteName(midi)
        .replaceAll('♭', '')
        .replaceAll('#', '');
    return naturalNotes.contains(note);
  }

  // Build midi -> Y map using ONLY natural notes with the same gap as SongComparisonPainter
  Map<int, double> _buildMidiYMap(Size size) {
    final map = <int, double>{};
    double y = size.height;
    for (int midi = 84; midi >= 36; midi--) {
      if (!isNatural(midi)) continue;
      final note = noteName(midi);
      final double gap = (note == 'F' || note == 'C') ? 32 : 48;
      y -= gap;
      map[midi] = y;
    }
    return map;
  }

  // Convert hz to Y by interpolating between surrounding natural note Y positions
  double hzToY(double hz, Map<int, double> midiYMap, Size size) {
    final double midi = hzToMidi(hz);

    double? yBelow, yAbove;
    int mBelow = 0, mAbove = 0;

    for (int m = midi.floor(); m >= 36; m--) {
      if (midiYMap.containsKey(m)) {
        yBelow = midiYMap[m];
        mBelow = m;
        break;
      }
    }
    for (int m = midi.ceil(); m <= 84; m++) {
      if (midiYMap.containsKey(m)) {
        yAbove = midiYMap[m];
        mAbove = m;
        break;
      }
    }

    if (yBelow == null && yAbove == null) return size.height / 2;
    if (yBelow == null) return yAbove!;
    if (yAbove == null) return yBelow;
    if (mAbove == mBelow) return yBelow;

    final double fraction = (midi - mBelow) / (mAbove - mBelow);
    return yBelow + (yAbove - yBelow) * fraction;
  }

  double _xFromIndex(int i, int total, Size size) {
    if (total <= 1) return scaleWidth;
    double graphWidth = size.width - scaleWidth;
    return scaleWidth + (i / (total - 1)) * graphWidth;
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

    // Background
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

    // Build shared Y map — only natural notes, same gaps as SongComparisonPainter
    final midiYMap = _buildMidiYMap(size);

    // Draw scale: only natural notes, label at x=20 (same as SongComparisonPainter)
    for (final entry in midiYMap.entries) {
      final int midi = entry.key;
      final double y = entry.value;

      if (y < -60 || y > size.height + 60) continue;

      final String note = noteName(midi);
      final int oct = octave(midi);
      final bool isRoot = !chromaticMode && note[0] == rootNote[0];

      canvas.drawLine(
        Offset(scaleWidth, y),
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

    // Window
    const int windowSize = 150;

    final ref = referencePitch.length > windowSize
        ? referencePitch.sublist(referencePitch.length - windowSize)
        : referencePitch;

    final user = pitchHistory.length > windowSize
        ? pitchHistory.sublist(pitchHistory.length - windowSize)
        : pitchHistory;

    if (ref.length < 2 || user.length < 2) return;

    // Clip pitch lines to graph area only
    canvas.save();
    canvas.clipRect(
        Rect.fromLTWH(scaleWidth, 0, size.width - scaleWidth, size.height));

    // Reference line — purple
    final refPaint = Paint()
      ..color = Colors.purpleAccent
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    double? prevX, prevY;

    for (int i = 0; i < ref.length; i++) {
      final double hz = ref[i];
      if (hz <= 0 || hz > 2000) {
        prevX = null;
        prevY = null;
        continue;
      }

      final double x = _xFromIndex(i, ref.length, size);
      final double yPos = hzToY(hz, midiYMap, size);

      if (prevX != null && prevY != null) {
        canvas.drawLine(Offset(prevX, prevY), Offset(x, yPos), refPaint);
      }
      prevX = x;
      prevY = yPos;
    }

    // User line — green/red/yellow
    prevX = null;
    prevY = null;

    for (int i = 0; i < user.length; i++) {
      final double hz = user[i];
      if (hz <= 0 || hz > 2000) {
        prevX = null;
        prevY = null;
        continue;
      }

      final double midi = hzToMidi(hz);
      final double x = _xFromIndex(i, user.length, size);
      final double yPos = hzToY(hz, midiYMap, size);

      final double refMidi = (i < ref.length && ref[i] > 0)
          ? hzToMidi(ref[i])
          : midi;
      final double diff = midi - refMidi;

      final Color color = diff.abs() <= tolerance
          ? Colors.green
          : diff > tolerance
              ? Colors.red
              : Colors.yellow;

      final paint = Paint()
        ..color = color
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;

      if (prevX != null && prevY != null) {
        canvas.drawLine(Offset(prevX, prevY), Offset(x, yPos), paint);
      }
      prevX = x;
      prevY = yPos;
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant RagaComparisonPainter oldDelegate) => true;
}