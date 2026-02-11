import 'dart:math';

/// Convert Hz to MIDI (floating point)
double? hzToMidi(double hz) {
  if (hz <= 0 || hz.isNaN || hz.isInfinite) return null;
  return 69 + 12 * (log(hz / 440.0) / ln2);
}

/// Convert MIDI to Hz
double midiToHz(int midi) {
  return 440.0 * pow(2.0, (midi - 69) / 12.0);
}

/// Get note name (C, C#, D, etc.)
String noteName(int midi) {
  const notes = [
    'C', 'C#', 'D', 'D#', 'E', 'F',
    'F#', 'G', 'G#', 'A', 'A#', 'B'
  ];
  return notes[(midi % 12 + 12) % 12]; 
}

int octave(int midi) {
  return (midi ~/ 12) - 1;
}

/// Convert Hz to Note Label (A4, C#5 etc.)
String hzToNoteLabel(double hz) {
  final midi = hzToMidi(hz);
  if (midi == null) return '--';

  final roundedMidi = midi.round();
  return '${noteName(roundedMidi)}${octave(roundedMidi)}';
}

double? snapHzToMidi(double hz) {
  final midi = hzToMidi(hz);
  if (midi == null) return null;

  final snappedMidi = midi.round();
  return midiToHz(snappedMidi);
}

double? centsOff(double hz) {
  final midi = hzToMidi(hz);
  if (midi == null) return null;

  final nearest = midi.round();
  return (midi - nearest) * 100; // cents
}
