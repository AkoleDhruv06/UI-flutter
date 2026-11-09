import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyMusicApp());
}

const bg = Color(0xFF0D0B14);
const sidebarBg = Color(0xFF120F1C);
const panel = Color(0xFF171321);
const purple = Color(0xFF9B6DFF);
const muted = Color(0xFF9992A8);

const List<Song> starterSongs = [
  Song('Lofi Hip Hop Radio', 'Lofi Girl', 'jfKfPfyJRdk'),
  Song('Never Gonna Give You Up', 'Rick Astley', 'dQw4w9WgXcQ'),
  Song('Despacito', 'Luis Fonsi', 'kJQP7kiw5Fk'),
  Song('Faded', 'Alan Walker', '60ItHLz5WEA'),
  Song('Closer', 'The Chainsmokers', 'PT2_F-1esPk'),
  Song('Perfect', 'Ed Sheeran', '2Vv-BfVoq4g'),
];

class Song {
  final String title;
  final String artist;
  final String videoId;

  const Song(this.title, this.artist, this.videoId);

  String get thumbnail => 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';

  Map<String, dynamic> toJson() => {
        'title': title,
        'artist': artist,
        'videoId': videoId,
      };

  factory Song.fromJson(Map<String, dynamic> json) => Song(
        json['title'] as String,
        json['artist'] as String,
        json['videoId'] as String,
      );
}

class MyMusicApp extends StatelessWidget {
  const MyMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'My Music',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: bg,
        colorScheme: const ColorScheme.dark(
          primary: purple,
          surface: panel,
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: panel,
          contentTextStyle: TextStyle(color: Colors.white),
        ),
      ),
      home: const MusicDashboard(),
    );
  }
}

class MusicDashboard extends StatefulWidget {
  const MusicDashboard({super.key});

  @override
  State<MusicDashboard> createState() => _MusicDashboardState();
}

class _MusicDashboardState extends State<MusicDashboard> {
  late final YoutubePlayerController playerController;
  final TextEditingController searchController = TextEditingController();

  final List<Song> allSongs = List<Song>.from(starterSongs);
  final List<Song> userSongs = [];
  final Set<String> favouriteIds = {};

  int selectedIndex = 0;
  String selectedPage = 'Home';
  String searchText = '';
  bool isPlaying = false;
  bool isLoading = true;

  Song get currentSong => allSongs[selectedIndex];

  @override
  void initState() {
    super.initState();
    playerController = YoutubePlayerController.fromVideoId(
      videoId: starterSongs.first.videoId,
      autoPlay: false,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        strictRelatedVideos: true,
      ),
    );
    loadSavedData();
  }

  Future<void> loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedSongs = prefs.getString('userSongs');
    final savedFavourites = prefs.getStringList('favouriteIds') ?? [];

    if (savedSongs != null) {
      try {
        final decoded = jsonDecode(savedSongs) as List<dynamic>;
        userSongs
          ..clear()
          ..addAll(decoded.map(
            (item) => Song.fromJson(item as Map<String, dynamic>),
          ));
      } catch (_) {
        // Ignore invalid old data and keep the built-in starter songs.
      }
    }

    if (!mounted) return;
    setState(() {
      allSongs
        ..clear()
        ..addAll(starterSongs)
        ..addAll(userSongs);
      favouriteIds
        ..clear()
        ..addAll(savedFavourites);
      isLoading = false;
    });
  }

  Future<void> saveSongs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'userSongs',
      jsonEncode(userSongs.map((song) => song.toJson()).toList()),
    );
  }

  Future<void> saveFavourites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favouriteIds', favouriteIds.toList());
  }

  void playSong(int index) {
    if (index < 0 || index >= allSongs.length) return;
    setState(() {
      selectedIndex = index;
      isPlaying = true;
    });
    playerController.loadVideoById(videoId: allSongs[index].videoId);
  }

  void nextSong() {
    if (allSongs.isEmpty) return;
    playSong((selectedIndex + 1) % allSongs.length);
  }

  void previousSong() {
    if (allSongs.isEmpty) return;
    playSong((selectedIndex - 1 + allSongs.length) % allSongs.length);
  }

  void togglePlayPause() {
    if (isPlaying) {
      playerController.pauseVideo();
    } else {
      playerController.playVideo();
    }
    setState(() => isPlaying = !isPlaying);
  }

  Future<void> toggleFavourite(Song song) async {
    setState(() {
      if (!favouriteIds.add(song.videoId)) {
        favouriteIds.remove(song.videoId);
      }
    });
    await saveFavourites();
  }

  Future<void> addSongDialog() async {
    final urlController = TextEditingController();
    final titleController = TextEditingController();
    final artistController = TextEditingController();
    String? errorText;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: panel,
            title: const Text('Add a YouTube video'),
            content: SizedBox(
              width: 430,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: urlController,
                      decoration: const InputDecoration(
                        labelText: 'YouTube URL or video ID',
                        hintText: 'https://www.youtube.com/watch?v=...',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Video title',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: artistController,
                      decoration: const InputDecoration(
                        labelText: 'Artist / channel name',
                      ),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          errorText!,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final raw = urlController.text.trim();
                  final videoId =
                      YoutubePlayerController.convertUrlToId(raw) ?? raw;
                  final validId =
                      RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(videoId);
                  final title = titleController.text.trim();
                  final artist = artistController.text.trim();

                  if (!validId) {
                    setDialogState(() {
                      errorText = 'Enter a valid YouTube video URL or ID.';
                    });
                    return;
                  }
                  if (title.isEmpty || artist.isEmpty) {
                    setDialogState(() {
                      errorText = 'Please enter both a title and artist.';
                    });
                    return;
                  }
                  if (allSongs.any((song) => song.videoId == videoId)) {
                    setDialogState(() {
                      errorText = 'This video is already in your music list.';
                    });
                    return;
                  }

                  final newSong = Song(title, artist, videoId);
                  setState(() {
                    userSongs.add(newSong);
                    allSongs.add(newSong);
                    selectedPage = 'My Library';
                    selectedIndex = allSongs.length - 1;
                    searchText = '';
                    searchController.clear();
                    isPlaying = true;
                  });
                  await saveSongs();
                  playerController.loadVideoById(videoId: videoId);
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                },
                child: const Text('Add video'),
              ),
            ],
          ),
        );
      },
    );

    urlController.dispose();
    titleController.dispose();
    artistController.dispose();
  }

  List<MapEntry<int, Song>> get visibleSongs {
    final query = searchText.toLowerCase().trim();
    return allSongs.asMap().entries.where((entry) {
      final song = entry.value;
      final matchesSearch = song.title.toLowerCase().contains(query) ||
          song.artist.toLowerCase().contains(query);
      final matchesPage = switch (selectedPage) {
        'Favourites' => favouriteIds.contains(song.videoId),
        'My Library' => userSongs.any((item) => item.videoId == song.videoId),
        _ => true,
      };
      return matchesSearch && matchesPage;
    }).toList();
  }

  @override
  void dispose() {
    playerController.close();
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isHome = selectedPage == 'Home';
    final width = MediaQuery.of(context).size.width;
    final columns = width >= 1250 ? 3 : width >= 850 ? 2 : 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  if (width >= 700) sidebar(),
                  Expanded(
                    child: Column(
                      children: [
                        topBar(showMenu: width < 700),
                        Expanded(
                          child: isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : SingleChildScrollView(
                                  padding: EdgeInsets.all(width < 700 ? 16 : 28),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (width < 700) mobileNavigation(),
                                      Text(
                                        pageHeading,
                                        style: const TextStyle(
                                          fontSize: 30,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        pageSubtitle,
                                        style: const TextStyle(color: muted),
                                      ),
                                      const SizedBox(height: 24),
                                      if (isHome) ...[
                                        featuredPlayer(),
                                        const SizedBox(height: 32),
                                      ],
                                      Row(
                                        children: [
                                          Expanded(child: sectionTitle(sectionHeading)),
                                          if (selectedPage == 'Explore' ||
                                              selectedPage == 'My Library')
                                            FilledButton.icon(
                                              onPressed: addSongDialog,
                                              icon: const Icon(Icons.add),
                                              label: const Text('Add video'),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 18),
                                      if (visibleSongs.isEmpty)
                                        emptyState()
                                      else
                                        GridView.builder(
                                          shrinkWrap: true,
                                          physics:
                                              const NeverScrollableScrollPhysics(),
                                          itemCount: visibleSongs.length,
                                          gridDelegate:
                                              SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: columns,
                                            crossAxisSpacing: 20,
                                            mainAxisSpacing: 20,
                                            childAspectRatio:
                                                columns == 1 ? 2.1 : 1.3,
                                          ),
                                          itemBuilder: (context, index) {
                                            final entry = visibleSongs[index];
                                            return songCard(
                                              entry.value,
                                              entry.key,
                                            );
                                          },
                                        ),
                                    ],
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            bottomPlayer(),
          ],
        ),
      ),
    );
  }

  String get pageHeading => switch (selectedPage) {
        'Home' => 'Your music, your world.',
        'Explore' => 'Discover something new.',
        'Favourites' => 'Your favourite videos.',
        _ => 'Your personal library.',
      };

  String get pageSubtitle => switch (selectedPage) {
        'Home' => 'Pick something and enjoy the vibe.',
        'Explore' => 'Browse every video in your collection, or add a new one.',
        'Favourites' => 'The videos you have saved with a heart.',
        _ => 'Videos you have added to your own collection.',
      };

  String get sectionHeading => switch (selectedPage) {
        'Favourites' => 'Your favourites',
        'Explore' => 'Explore music',
        'My Library' => 'Your added videos',
        _ => 'Your music',
      };

  Widget sidebar() {
    return Container(
      width: 220,
      color: sidebarBg,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.graphic_eq, color: purple, size: 32),
              SizedBox(width: 10),
              Text(
                'MY MUSIC',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 50),
          const Text(
            'MENU',
            style: TextStyle(color: muted, fontSize: 11, letterSpacing: 2),
          ),
          const SizedBox(height: 16),
          navItem(Icons.home_rounded, 'Home'),
          navItem(Icons.explore_rounded, 'Explore'),
          navItem(Icons.favorite_rounded, 'Favourites'),
          navItem(Icons.library_music_rounded, 'My Library'),
          const Spacer(),
          const Divider(color: Colors.white12),
          const SizedBox(height: 15),
          const Text('YOUR MUSIC SPACE',
              style: TextStyle(color: muted, fontSize: 11)),
          const SizedBox(height: 8),
          const Text('Made for your favourites.',
              style: TextStyle(color: muted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget navItem(IconData icon, String label) {
    final active = selectedPage == label;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => changePage(label),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: active ? purple.withValues(alpha: 0.18) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(icon, size: 19, color: active ? purple : muted),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: active ? Colors.white : muted,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void changePage(String page) {
    setState(() {
      selectedPage = page;
      searchText = '';
      searchController.clear();
    });
  }

  Widget mobileNavigation() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final page in ['Home', 'Explore', 'Favourites', 'My Library'])
            ChoiceChip(
              label: Text(page),
              selected: selectedPage == page,
              onSelected: (_) => changePage(page),
              selectedColor: purple.withValues(alpha: 0.3),
            ),
        ],
      ),
    );
  }

  Widget topBar({required bool showMenu}) {
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          Text(
            showMenu ? 'MY MUSIC' : 'Discover',
            style: const TextStyle(fontSize: 16, color: muted),
          ),
          const Spacer(),
          SizedBox(
            width: MediaQuery.of(context).size.width < 700 ? 190 : 300,
            child: TextField(
              controller: searchController,
              onChanged: (value) => setState(() => searchText = value),
              decoration: InputDecoration(
                hintText: 'Search your music...',
                hintStyle: const TextStyle(color: muted),
                prefixIcon: const Icon(Icons.search, color: muted),
                filled: true,
                fillColor: panel,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          const CircleAvatar(
            backgroundColor: Color(0xFF39265B),
            child: Icon(Icons.person, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget featuredPlayer() {
    final song = currentSong;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.play_circle_fill, color: purple),
              SizedBox(width: 8),
              Text(
                'NOW PLAYING',
                style: TextStyle(
                  color: purple,
                  letterSpacing: 2,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: YoutubePlayer(
              controller: playerController,
              aspectRatio: 16 / 9,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(song.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 19)),
                    const SizedBox(height: 4),
                    Text(song.artist, style: const TextStyle(color: muted)),
                  ],
                ),
              ),
              IconButton(
                onPressed: previousSong,
                icon: const Icon(Icons.skip_previous),
              ),
              IconButton(
                onPressed: nextSong,
                icon: const Icon(Icons.skip_next),
                color: purple,
                iconSize: 30,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget sectionTitle(String title) => Text(
        title,
        style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
      );

  Widget songCard(Song song, int index) {
    final active = index == selectedIndex;
    final favourite = favouriteIds.contains(song.videoId);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => playSong(index),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: active ? purple : Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: Image.network(
                      song.thumbnail,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFF30263F),
                        child: const Icon(Icons.music_note,
                            size: 40, color: purple),
                      ),
                    ),
                  ),
                  const Center(
                    child: CircleAvatar(
                      backgroundColor: Colors.black54,
                      child: Icon(Icons.play_arrow,
                          color: Colors.white, size: 24),
                    ),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: IconButton(
                      tooltip: favourite
                          ? 'Remove from favourites'
                          : 'Add to favourites',
                      onPressed: () => toggleFavourite(song),
                      icon: Icon(
                        favourite ? Icons.favorite : Icons.favorite_border,
                        color: favourite ? Colors.pinkAccent : Colors.white,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget emptyState() {
    final message = selectedPage == 'Favourites'
        ? 'You have not added any favourites yet.\nTap the heart on a video to save it here.'
        : selectedPage == 'My Library'
            ? 'Your library is empty.\nUse “Add video” to add a YouTube video.'
            : 'No videos match your search.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          const Icon(Icons.music_off, size: 42, color: muted),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: muted, height: 1.5)),
          if (selectedPage == 'My Library') ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: addSongDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add your first video'),
            ),
          ],
        ],
      ),
    );
  }

  Widget bottomPlayer() {
    final song = currentSong;
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: panel,
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: Image.network(
              song.thumbnail,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.music_note, color: muted),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  song.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Previous',
            onPressed: previousSong,
            icon: const Icon(Icons.skip_previous),
          ),
          IconButton(
            tooltip: isPlaying ? 'Pause' : 'Play',
            onPressed: togglePlayPause,
            icon: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 32,
              color: purple,
            ),
          ),
          IconButton(
            tooltip: 'Next',
            onPressed: nextSong,
            icon: const Icon(Icons.skip_next),
          ),
          if (MediaQuery.of(context).size.width >= 800) ...[
            const SizedBox(width: 12),
            const Icon(Icons.graphic_eq, color: purple),
            const SizedBox(width: 10),
            const Text(
              'MY MUSIC',
              style: TextStyle(
                color: muted,
                fontSize: 11,
                letterSpacing: 2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}