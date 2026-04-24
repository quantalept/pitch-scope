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
    required this.version,
  });

  final double tolerance = 1.0;

  // Left column width reserved for note labels
  static const double scaleWidth = 55;

  // Number of semitones visible on screen at once
  static const double visibleSemitones = 13.0;

  double hzToMidi(double hz) {
    if (hz <= 0) return 0;
    return 69 + 12 * log(hz / 440) / ln2;
  }

  static const List<String> _chromatic = [
    'C', 'C#', 'D', 'Eb', 'E', 'F',
    'F#', 'G', 'Ab', 'A', 'Bb', 'B'
  ];

  String noteName(int midi) => _chromatic[midi % 12];
  int octave(int midi) => (midi ~/ 12) - 1;

  // Y position for a midi note given the current center
  double midiToY(double midi, double centerMidi, Size size) {
    final double semitoneHeight = size.height / visibleSemitones;
    return (size.height / 2) + (centerMidi - midi) * semitoneHeight;
  }

  double _xFromIndex(int i, int total, Size size) {
    if (total <= 1) return scaleWidth;
    return scaleWidth + (i / (total - 1)) * (size.width - scaleWidth);
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

    // Determine which pitch to center the scale on
    double centerMidi = 60.0; // default C4

    final validRef = referencePitch.where((e) => e > 60 && e < 2000).toList();
    final validUser = pitchHistory.where((e) => e > 60 && e < 2000).toList();

    if (validUser.isNotEmpty) {
      centerMidi = hzToMidi(validUser.last).roundToDouble();
    } else if (validRef.isNotEmpty) {
      centerMidi = hzToMidi(validRef.last).roundToDouble();
    }

    // Draw all chromatic notes in the visible window
    final double semitoneHeight = size.height / visibleSemitones;
    final int minMidiVisible = (centerMidi - visibleSemitones / 2 - 1).floor();
    final int maxMidiVisible = (centerMidi + visibleSemitones / 2 + 1).ceil();

    for (int midi = minMidiVisible; midi <= maxMidiVisible; midi++) {
      final double y = midiToY(midi.toDouble(), centerMidi, size);
      if (y < -4 || y > size.height + 4) continue;

      final String note = noteName(midi);
      final int oct = octave(midi);
      final bool isRoot = !chromaticMode &&
          note.replaceAll('#', '').replaceAll('b', '')[0] == rootNote[0];
      final bool isC = note == 'C';

      // Grid line — starts exactly at scaleWidth
      final linePaint = Paint()
        ..strokeWidth = isRoot ? 2.0 : (isC ? 1.0 : 0.5)
        ..color = isRoot
            ? Colors.white
            : (isC ? Colors.white54 : Colors.white24);

      canvas.drawLine(
        Offset(scaleWidth - 5, y),
        Offset(size.width, y),
        linePaint,
      );

      // Label — right-aligned, ending just before scaleWidth
      final labelStyle = TextStyle(
        color: isRoot
            ? Colors.white
            : (isC ? Colors.white70 : Colors.white38),
        fontSize: isRoot ? 14 : (isC ? 13 : 11),
        fontWeight: isRoot ? FontWeight.bold : FontWeight.normal,
      );

      final tp = TextPainter(
        text: TextSpan(text: "$note$oct", style: labelStyle),
        textDirection: TextDirection.ltr,
      );
      tp.layout();

      // Right-align: x = scaleWidth - textWidth - 4px padding
      tp.paint(canvas, Offset(4, y - tp.height / 2));
    }

    // Draw a thin vertical separator between scale and graph
    canvas.drawLine(
      Offset(scaleWidth, 0),
      Offset(scaleWidth, size.height),
      Paint()
        ..color = Colors.white24
        ..strokeWidth = 0.5,
    );

    // Sliding window
    const int windowSize = 150;

    final ref = referencePitch.length > windowSize
        ? referencePitch.sublist(referencePitch.length - windowSize)
        : referencePitch;

    final user = pitchHistory.length > windowSize
        ? pitchHistory.sublist(pitchHistory.length - windowSize)
        : pitchHistory;

    if (ref.length < 2 && user.length < 2) return;

    // Reference (mp3) pitch line — purple
    final refPaint = Paint()
      ..color = Colors.purpleAccent
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    double? prevX, prevY;

    for (int i = 0; i < ref.length; i++) {
      final double hz = ref[i];
      if (hz <= 60 || hz > 2000) { prevX = null; prevY = null; continue; }

      final double midi = hzToMidi(hz);
      final double x = _xFromIndex(i, ref.length, size);
      final double yPos = midiToY(midi, centerMidi, size);

      if (prevX != null && prevY != null) {
        canvas.drawLine(Offset(prevX, prevY), Offset(x, yPos), refPaint);
      }
      prevX = x;
      prevY = yPos;
    }

    // User pitch line — green/red/yellow
    prevX = null;
    prevY = null;

    for (int i = 0; i < user.length; i++) {
      final double hz = user[i];
      if (hz <= 60 || hz > 2000) { prevX = null; prevY = null; continue; }

      final double midi = hzToMidi(hz);
      final double x = _xFromIndex(i, user.length, size);
      final double yPos = midiToY(midi, centerMidi, size);

      final double refMidi = (i < ref.length && ref[i] > 60)
          ? hzToMidi(ref[i])
          : midi;
      final double diff = midi - refMidi;

      final Color color = diff.abs() <= tolerance
          ? Colors.green
          : diff > tolerance
              ? Colors.red
              : Colors.yellow;

      final userPaint = Paint()
        ..color = color
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;

      if (prevX != null && prevY != null) {
        canvas.drawLine(Offset(prevX, prevY), Offset(x, yPos), userPaint);
      }
      prevX = x;
      prevY = yPos;
    }
  }

  @override
  bool shouldRepaint(covariant RagaComparisonPainter oldDelegate) {
    return oldDelegate.version != version ||
        oldDelegate.raagaName != raagaName ||
        oldDelegate.minPitch != minPitch ||
        oldDelegate.maxPitch != maxPitch;
  }
}