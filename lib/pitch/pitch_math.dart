import 'dart:math';


double? hzToMidi(double hz) {
  if (hz <= 0 || hz.isNaN || hz.isInfinite) return null;
  return 69 + 12 * (log(hz / 440.0) / ln2);
}

double midiToHz(int midi) {
  return 440.0 * pow(2.0, (midi - 69) / 12.0);
}

String noteName(int midi) {
  const notes = [
    'C', 'C#', 'D', 'D#', 'E', 'F',
    'F#', 'G', 'G#', 'A', 'A#', 'B'
  ];
  return notes[midi % 12];
}

int octave(int midi) {
  return (midi ~/ 12) - 1;
}

String hzToNoteLabel(double hz) {
  final midi = hzToMidi(hz);
  if (midi == null) return '--';

  final roundedMidi = midi.round();
  return '${noteName(roundedMidi)}${octave(roundedMidi)}';
}
