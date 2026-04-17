import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import 'song_practice_screen.dart';
import 'lyrics_repository.dart';

class DeviceSongsScreen extends StatefulWidget {
  const DeviceSongsScreen({super.key});

  @override
  State<DeviceSongsScreen> createState() => _DeviceSongsScreenState();
}

class _DeviceSongsScreenState extends State<DeviceSongsScreen> {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final LyricsRepository _lyricsRepo = LyricsRepository(); // ✅ ADDED

  List<SongModel> songs = [];
  List<SongModel> filteredSongs = [];

  final TextEditingController _searchController = TextEditingController();

  bool isLoading = true;
  bool permissionDenied = false;

  @override
  void initState() {
    super.initState();
    _loadSongs();
  }

  Future<void> _loadSongs() async {
    try {
      final status = await Permission.audio.request();

      if (!status.isGranted) {
        if (!mounted) return;

        setState(() {
          permissionDenied = true;
          isLoading = false;
        });
        return;
      }

      final result = await _audioQuery.querySongs(
        sortType: SongSortType.TITLE,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );

      if (!mounted) return;

      setState(() {
        songs = result;
        filteredSongs = result;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      debugPrint("❌ Song load error: $e");
    }
  }

  void _filterSongs(String query) {
    final q = query.toLowerCase();

    setState(() {
      filteredSongs = songs.where((song) {
        final title = song.title.toLowerCase();
        final artist = (song.artist ?? "").toLowerCase();
        return title.contains(q) || artist.contains(q);
      }).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 🎵 SONG TILE
  Widget _songTile(SongModel song) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),

      /// ✅ FIXED ON TAP (LYRICS ADDED)
      onTap: () async {
        final lyrics = await _lyricsRepo.getLyrics(song);

        if (!mounted) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SongPracticeScreen(
              song: song,
              lyrics: lyrics,
            ),
          ),
        );
      },

      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A0026),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.music_note,
                color: Colors.purpleAccent,
              ),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFE6D9FF),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    song.artist ?? "Unknown Artist",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            const Icon(
              Icons.chevron_right,
              color: Colors.white38,
            ),
          ],
        ),
      ),
    );
  }

  Widget _permissionDeniedUI() {
    return const Center(
      child: Text(
        "Audio permission is required to load songs",
        style: TextStyle(color: Colors.white54),
      ),
    );
  }

  Widget _emptyUI() {
    return const Center(
      child: Text(
        "No songs found",
        style: TextStyle(color: Colors.white54),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F001A),

      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon:
                        const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    "Use your own song",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF2A0A3D),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _filterSongs,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: "Search for songs / artists",
                    hintStyle: TextStyle(color: Colors.white54),
                    prefixIcon: Icon(Icons.search, color: Colors.white54),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            Expanded(
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Colors.purpleAccent,
                      ),
                    )
                  : permissionDenied
                      ? _permissionDeniedUI()
                      : filteredSongs.isEmpty
                          ? _emptyUI()
                          : ListView.builder(
                              itemCount: filteredSongs.length,
                              itemBuilder: (context, index) {
                                return _songTile(filteredSongs[index]);
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}