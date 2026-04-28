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

  final double tolerance = 1.5;

  static const double scaleWidth = 80;
  static const double visibleSemitones = 14.0;
  static const List<String> naturalNotes = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];
  static const int visibleWindow = 200;

  double hzToMidi(double hz) {
    if (hz <= 0) return 0;
    return 69 + 12 * log(hz / 440) / ln2;
  }

  static const List<String> _chromatic = [
    'C', 'C#', 'D', 'E♭', 'E', 'F',
    'F#', 'G', 'A♭', 'A', 'B♭', 'B'
  ];

  String noteName(int midi) => _chromatic[midi % 12];
  int octave(int midi) => (midi ~/ 12) - 1;

  bool isNatural(int midi) {
    final note = noteName(midi)
        .replaceAll('♭', '')
        .replaceAll('#', '');
    return naturalNotes.contains(note);
  }

  double midiToY(double midi, double centerMidi, Size size) {
    final double semitoneHeight = size.height / visibleSemitones;
    return (size.height / 2) + (centerMidi - midi) * semitoneHeight;
  }

  // Newest data point always at right edge, older data scrolls left
  double _xFromIndex(int i, int total, Size size) {
    final double graphWidth = size.width - scaleWidth;
    final double slotWidth = graphWidth / visibleWindow;
    final int offset = visibleWindow - total;
    return scaleWidth + (offset + i) * slotWidth;
  }

  double _computeCenter(List<double> refWindow, List<double> userWindow) {
    final validRef = refWindow.where((e) => e > 60 && e < 2000).toList();
    if (validRef.isNotEmpty) {
      final midiValues = validRef.map(hzToMidi).toList();
      final avg = midiValues.reduce((a, b) => a + b) / midiValues.length;
      return avg.roundToDouble();
    }

    final validUser = userWindow.where((e) => e > 60 && e < 2000).toList();
    if (validUser.isNotEmpty) {
      final midiValues = validUser.map(hzToMidi).toList();
      final avg = midiValues.reduce((a, b) => a + b) / midiValues.length;
      return avg.roundToDouble();
    }

    return 57.0; // A3 default
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
      Paint()..color = const Color(0xFF0D0D0D),
    );

    // Stable center
    final double centerMidi = _computeCenter(referencePitch, pitchHistory);

    // Scale paints
    final normalLinePaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 1;
    final boldLinePaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 1.5;
    const normalText = TextStyle(color: Color(0xFF888888), fontSize: 12);
    const boldText = TextStyle(
      color: Colors.white,
      fontSize: 14,
      fontWeight: FontWeight.bold,
    );

    final int topMidi = (centerMidi + visibleSemitones / 2 + 1).ceil();
    final int botMidi = (centerMidi - visibleSemitones / 2 - 1).floor();

    // Draw grid lines and labels
    for (int midi = topMidi; midi >= botMidi; midi--) {
      if (!isNatural(midi)) continue;

      final double y = midiToY(midi.toDouble(), centerMidi, size);
      if (y < -4 || y > size.height + 4) continue;

      final String note = noteName(midi);
      final int oct = octave(midi);
      final bool isRoot = !chromaticMode && note[0] == rootNote[0];

      canvas.drawLine(
        Offset(scaleWidth, y),
        Offset(size.width, y),
        isRoot ? boldLinePaint : normalLinePaint,
      );

      final tp = TextPainter(
        text: TextSpan(
          text: "$note$oct",
          style: isRoot ? boldText : normalText,
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(scaleWidth - tp.width - 6, y - tp.height / 2));
    }

    // Vertical separator
    canvas.drawLine(
      Offset(scaleWidth, 0),
      Offset(scaleWidth, size.height),
      Paint()
        ..color = Colors.white24
        ..strokeWidth = 0.5,
    );

    // Clip to graph area
    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(scaleWidth, 0, size.width - scaleWidth, size.height),
    );

    // Reference line (purple)
    _drawRefLine(canvas, size, referencePitch, centerMidi);

    // User line (green/red/yellow)
    _drawUserLine(canvas, size, pitchHistory, referencePitch, centerMidi);

    canvas.restore();
  }

  void _drawRefLine(
    Canvas canvas,
    Size size,
    List<double> data,
    double centerMidi,
  ) {
    if (data.length < 2) return;

    double? prevX, prevY;

    for (int i = 0; i < data.length; i++) {
      final double hz = data[i];
      if (hz <= 60 || hz > 2000) {
        prevX = null;
        prevY = null;
        continue;
      }

      final double midi = hzToMidi(hz);
      final double x = _xFromIndex(i, data.length, size);
      final double y = midiToY(midi, centerMidi, size);

      if (prevX != null && prevY != null) {
        canvas.drawLine(
          Offset(prevX, prevY),
          Offset(x, y),
          Paint()
            ..color = const Color(0xFFCC44FF)
            ..strokeWidth = 4
            ..strokeCap = StrokeCap.round,
        );
      }

      prevX = x;
      prevY = y;
    }

    // Dot at current position
    final double lastHz = data.last;
    if (lastHz > 60 && lastHz < 2000) {
      final double x = _xFromIndex(data.length - 1, data.length, size);
      final double y = midiToY(hzToMidi(lastHz), centerMidi, size);
      canvas.drawCircle(Offset(x, y), 5,
          Paint()..color = const Color(0xFFCC44FF));
    }
  }

  void _drawUserLine(
    Canvas canvas,
    Size size,
    List<double> userData,
    List<double> refData,
    double centerMidi,
  ) {
    if (userData.length < 2) return;

    double? prevX, prevY;
    Color prevColor = Colors.green;

    for (int i = 0; i < userData.length; i++) {
      final double hz = userData[i];
      if (hz <= 60 || hz > 2000) {
        prevX = null;
        prevY = null;
        continue;
      }

      final double midi = hzToMidi(hz);
      final double x = _xFromIndex(i, userData.length, size);
      final double y = midiToY(midi, centerMidi, size);

      final double refMidi = (i < refData.length && refData[i] > 60)
          ? hzToMidi(refData[i])
          : midi;
      final double diff = midi - refMidi;

      final Color color;
      if (diff.abs() <= tolerance) {
        color = const Color(0xFF00E676); // green
      } else if (diff > tolerance) {
        color = const Color(0xFFFF1744); // red — too high
      } else {
        color = const Color(0xFFFFD600); // yellow — too low
      }

      if (prevX != null && prevY != null) {
        canvas.drawLine(
          Offset(prevX, prevY),
          Offset(x, y),
          Paint()
            ..color = color
            ..strokeWidth = 4
            ..strokeCap = StrokeCap.round,
        );
      }

      prevX = x;
      prevY = y;
      prevColor = color;
    }

    // Dot at current position
    final double lastHz = userData.last;
    if (lastHz > 60 && lastHz < 2000) {
      final double x =
          _xFromIndex(userData.length - 1, userData.length, size);
      final double y = midiToY(hzToMidi(lastHz), centerMidi, size);
      canvas.drawCircle(Offset(x, y), 6, Paint()..color = prevColor);
    }
  }

  @override
  bool shouldRepaint(covariant RagaComparisonPainter oldDelegate) {
    return oldDelegate.version != version;
  }
}