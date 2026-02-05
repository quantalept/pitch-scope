import 'dart:math';

class PitchNote {
  final String note;
  final int octave;
  final double cents;
  PitchNote(this.note, this.octave, this.cents);
}

PitchNote pitchToNote(double frequency) {
  const notes = ['C','C#','D','D#','E','F','F#','G','G#','A','A#','B'];
  final midi = 69 + 12 * log(frequency / 440) / ln2;
  final rounded = midi.round();
  final note = notes[rounded % 12];
  final octave = (rounded ~/ 12) - 1;
  final cents = (midi - rounded) * 100;
  return PitchNote(note, octave, cents);
}