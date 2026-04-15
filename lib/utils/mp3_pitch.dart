import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// 🎧 MAIN FUNCTION: Convert MP3 → Pitch (Hz list)
Future<List<double>> extractPitchFromMp3(String assetPath) async {
  try {
    // 1️⃣ Load MP3 from assets
    final byteData = await rootBundle.load(assetPath);

    // 2️⃣ Save to temp file
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/temp.mp3');
    await file.writeAsBytes(byteData.buffer.asUint8List());

    // ❗ NOTE:
    // pitch_detector_dart CANNOT read MP3 directly
    // So we simulate input OR expect PCM input from native

    // 👉 TEMP FIX: return empty OR mock
    // (You MUST replace this with native decoding later)

    return [];

  } catch (e) {
    print("MP3 Pitch Error: $e");
    return [];
  }
}