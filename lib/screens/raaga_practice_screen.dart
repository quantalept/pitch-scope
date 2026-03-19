import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../widgets/settings_screen.dart';
import '../pitch/raga_comparision_painter.dart';

class RaagaPracticeScreen extends StatefulWidget {
  final String raagaName;
  final String songName;
  final String lyric;

  const RaagaPracticeScreen({
    super.key,
    required this.raagaName,
    required this.songName,
    required this.lyric,
  });

  @override
  State<RaagaPracticeScreen> createState() => _RaagaPracticeScreenState();
}

class _RaagaPracticeScreenState extends State<RaagaPracticeScreen> {
  static const MethodChannel _channel = MethodChannel('live_audio_stream');

  final AudioRecorder recorder = AudioRecorder();

  bool isListening = false;
  bool isRecording = false;
  bool isPaused = false;

  double pitchHz = 0;
  String currentNote = "--";

  final List<double> pitchHistory = [];

  int timeIndex = 0;

  final int minMidi = 36;
  final int maxMidi = 84;

  String? recordPath;

  /// RAGA MIDI PATTERNS
  static const Map<String, List<double>> ragaPatterns = {
    "Mayamalavagowla":[52,55,57,60,64,60,57],
    "Shankarabharanam":[50,54,57,60,64,62,59],
    "Kalyani":[52,56,59,63,67,64,60],
    "Todi":[50,53,56,60,63,60,56],
    "Mohanam":[52,55,59,64,67,64,59],
  };

  List<double> get ragaPattern =>
      ragaPatterns[widget.raagaName] ??
      [52,55,57,60,64,60,57];

  @override
  void initState() {
    super.initState();

    _channel.setMethodCallHandler((call) async {

      if (call.method != 'pitch') return;

      final hz = (call.arguments as num).toDouble();

      if (!isListening || isPaused) return;

      if (hz < 60 || hz > 2000) return;

      final midi = 69 + 12 * log(hz / 440) / ln2;

      setState(() {

        pitchHz = hz;
        currentNote = _hzToNote(hz);

        if (pitchHistory.isEmpty) {
          pitchHistory.add(midi);
        } else {

          final last = pitchHistory.last;
          final smooth = last * 0.75 + midi * 0.25;

          pitchHistory.add(smooth);
        }

        if (pitchHistory.length > 300) {
          pitchHistory.removeAt(0);
        }

        timeIndex++;
      });
    });
  }

  @override
  void dispose() {
    recorder.dispose();
    super.dispose();
  }

  String _hzToNote(double hz) {

    const notes = [
      'C','C#','D','D#','E','F',
      'F#','G','G#','A','A#','B'
    ];

    int midi = (69 + 12 * log(hz / 440) / ln2).round();
    int octave = (midi ~/ 12) - 1;

    return "${notes[midi % 12]}$octave";
  }

  Future<void> _toggleMic() async {

    try {

      if (!isListening) {
        await _channel.invokeMethod('start');
      } else {
        await _channel.invokeMethod('stop');
      }

      setState(() {
        isListening = !isListening;
      });

    } catch (_) {}

  }

  Future<void> _toggleRecord() async {

    if (!isListening) {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Turn on mic first")),
      );

      return;
    }

    if (!isRecording) {

      if (!await recorder.hasPermission()) {

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Microphone permission required")),
        );

        return;
      }

      final dir =
          await getApplicationDocumentsDirectory();

      final path =
          "${dir.path}/pitchscope_${DateTime.now().millisecondsSinceEpoch}.m4a";

      await recorder.start(
        const RecordConfig(),
        path: path,
      );

      recordPath = path;

    } else {

      await recorder.stop();

      if (recordPath != null) {

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Saved to $recordPath")),
        );

      }

    }

    setState(() {
      isRecording = !isRecording;
    });
  }

  Future<void> _stopAll() async {

    try {
      await _channel.invokeMethod('stop');
    } catch (_) {}

    if (isRecording) {
      await recorder.stop();
    }

    setState(() {

      isListening = false;
      isRecording = false;
      isPaused = false;

      pitchHistory.clear();
      pitchHz = 0;
      currentNote = "--";
      timeIndex = 0;

    });
  }

  void _openSettings() {

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const SettingsScreen(),
    );

  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: const Color(0xFF1A0026),

      body: SafeArea(

        child: Column(

          children: [

            /// HEADER
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [

                  IconButton(
                    icon: const Icon(Icons.arrow_back,color: Colors.white),
                    onPressed: () async {
                      await _stopAll();
                      Navigator.pop(context);
                    },
                  ),

                  Expanded(
                    child: Column(
                      children: [

                        Text(
                          "${widget.songName} - ${widget.raagaName}",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        Text(
                          widget.lyric,
                          style: const TextStyle(
                            color: Colors.white70,
                          ),
                        ),

                      ],
                    ),
                  ),

                  IconButton(
                    icon: const Icon(Icons.settings,color: Colors.white),
                    onPressed: _openSettings,
                  ),

                ],
              ),
            ),

            /// PRACTICE GRAPH
            Expanded(
              child: CustomPaint(
                painter: RagaComparisonPainter(
                  pitchHistory: pitchHistory,
                  ragaPattern: ragaPattern,
                  timeIndex: timeIndex,
                  minMidi: minMidi,
                  maxMidi: maxMidi,
                ),
                size: Size.infinite,
              ),
            ),

            /// FOOTER
            Container(

              height: 90,
              color: const Color(0xFF2B003D),

              child: Row(

                mainAxisAlignment: MainAxisAlignment.spaceEvenly,

                children: [

                  IconButton(
                    icon: Icon(
                      isListening ? Icons.mic : Icons.mic_off,
                      color: isListening ? Colors.green : Colors.white70,
                    ),
                    onPressed: _toggleMic,
                  ),

                  IconButton(
                    icon: Icon(
                      Icons.fiber_manual_record,
                      color: isRecording ? Colors.red : Colors.white70,
                    ),
                    onPressed: _toggleRecord,
                  ),

                  IconButton(
                    icon: Icon(
                      Icons.pause_circle_outline,
                      color: isPaused ? Colors.orange : Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        isPaused = !isPaused;
                      });
                    },
                  ),

                  Text(
                    currentNote,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  IconButton(
                    icon: const Icon(
                      Icons.stop_circle_outlined,
                      color: Colors.white70,
                    ),
                    onPressed: _stopAll,
                  ),

                ],

              ),

            ),

          ],

        ),

      ),

    );
  }
}