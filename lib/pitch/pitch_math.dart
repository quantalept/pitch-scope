import 'dart:math';

/// Convert frequency (Hz) to MIDI note
/// Returns null if input is invalid or silence
double? hzToMidi(double hz) {
  if (hz <= 0 || hz.isNaN || hz.isInfinite) return null;
  return 69 + 12 * (log(hz / 440.0) / ln2);
}

/// Convert MIDI note to frequency (Hz)
double midiToHz(int midi) {
  return 440.0 * pow(2.0, (midi - 69) / 12.0);
}

/// Get note name (C, C#, D...)
String noteName(int midi) {
  const notes = [
    'C', 'C#', 'D', 'D#', 'E', 'F',
    'F#', 'G', 'G#', 'A', 'A#', 'B'
  ];
  return notes[midi % 12];
}

/// Get octave number
int octave(int midi) {
  return (midi ~/ 12) - 1;
}

/// Helper: Hz → note + octave safely
String hzToNoteLabel(double hz) {
  final midi = hzToMidi(hz);
  if (midi == null) return '--';

  final roundedMidi = midi.round();
  return '${noteName(roundedMidi)}${octave(roundedMidi)}';
}
