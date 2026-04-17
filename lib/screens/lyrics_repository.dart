import 'dart:io';
import 'package:on_audio_query/on_audio_query.dart';

class LyricsRepository {
  final Map<String, String> _cache = {};

  Future<String> getLyrics(SongModel song) async {
    final path = song.data;

    if (_cache.containsKey(path)) {
      return _cache[path]!;
    }

    String lyrics = "";

    final lrcFile = File(path.replaceAll(RegExp(r'\.\w+$'), '.lrc'));
    final txtFile = File(path.replaceAll(RegExp(r'\.\w+$'), '.txt'));

    if (await lrcFile.exists()) {
      lyrics = await lrcFile.readAsString();
    } else if (await txtFile.exists()) {
      lyrics = await txtFile.readAsString();
    }

    if (lyrics.trim().isEmpty) {
      lyrics = "No lyrics available for this song.";
    }

    _cache[path] = lyrics;
    return lyrics;
  }
}