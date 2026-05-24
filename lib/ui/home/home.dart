import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:music_app/data/firebase_service.dart';
import 'package:music_app/ui/home/viewmodel.dart';
import 'package:music_app/ui/now_playing/audio_player_manager.dart';
import 'package:music_app/data/model/song.dart';
import 'package:music_app/ui/now_playing/playing.dart';
import 'package:music_app/data/reponsitory/music_repository_impl.dart';
import 'package:music_app/data/reponsitory/repository.dart';
import 'package:music_app/ui/user/user.dart';
import 'package:music_app/main.dart';
import 'dart:async';
import 'package:music_app/ui/user/login.dart';
import '../history/history_screen.dart';
import 'gemini_search_screen.dart';

// ==========================================
// MÀN HÌNH CHÍNH (Chứa thanh điều hướng Bottom Navigation)
// ==========================================

class MusicHomepage extends StatefulWidget {
  final String userId;
  const MusicHomepage({super.key, required this.userId});

  @override
  State<MusicHomepage> createState() => _MusicHomepageState();
}

class _MusicHomepageState extends State<MusicHomepage> {
  late List<Widget> _tabs;

  Song? _currentPlayingSong;
  bool _isPlaying = false;
  bool _isNowPlayingOpen = false;

  @override
  void initState() {
    super.initState();
    final String currentUserId = widget.userId;
    _tabs = [
      HomeTab(userId: currentUserId),
      DiscoveryScreen(repository: MusicRepositoryImpl(), userId: currentUserId),
      HistoryTab(userId: currentUserId),
      AccountTab(userId: currentUserId),
      const SettingsTab(),
    ];

    AudioPlayerManager().currentSongNotifier.addListener(() {
      if (mounted) {
        // Sử dụng addPostFrameCallback để tránh lỗi "setState() during build"
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _currentPlayingSong = AudioPlayerManager().currentSongNotifier.value;
            });
          }
        });
      }
    });

    AudioPlayerManager().isNowPlayingOpen.addListener(() {
      if (mounted) {
        // Sử dụng addPostFrameCallback để tránh lỗi "setState() when widget tree was locked"
        // Đặc biệt là khi giá trị này thay đổi trong hàm dispose() của trang khác
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _isNowPlayingOpen = AudioPlayerManager().isNowPlayingOpen.value;
            });
          }
        });
      }
    });

    AudioPlayerManager().player.playingStream.listen((playing) {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _isPlaying = playing;
            });
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Stack(
        children: [
          CupertinoTabScaffold(
            tabBar: CupertinoTabBar(
              backgroundColor: colorScheme.surface.withValues(alpha: 0.8),
              activeColor: colorScheme.primary,
              inactiveColor: colorScheme.onSurface.withValues(alpha: 0.5),
              border: Border(top: BorderSide(color: colorScheme.outlineVariant, width: 0.5)),
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
                BottomNavigationBarItem(icon: Icon(Icons.explore_rounded), label: 'Discovery'),
                BottomNavigationBarItem(icon: Icon(Icons.history_rounded), label: 'History'),
                BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Account'),
                BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'Settings'),
              ],
            ),
            tabBuilder: (BuildContext context, int index) {
              return CupertinoTabView(builder: (context) => _tabs[index]);
            },
          ),
          if (_currentPlayingSong != null && !_isNowPlayingOpen)
            Positioned(
              bottom: 60, // Đẩy lên một chút để không bị đè bởi TabBar
              left: 12,
              right: 12,
              child: MiniPlayer(
                song: _currentPlayingSong!,
                isPlaying: _isPlaying,
                onTap: () {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (context) => NowPlaying(
                        songs: AudioPlayerManager().currentPlaylist,
                        playingSong: _currentPlayingSong!,
                      ),
                    ),
                  );
                },
                onPlayPause: () {
                  if (AudioPlayerManager().player.playing) {
                    AudioPlayerManager().player.pause();
                  } else {
                    AudioPlayerManager().player.play();
                  }
                },
                onPrevious: () {
                  AudioPlayerManager().previousSong();
                },
                onNext: () {
                  AudioPlayerManager().nextSong();
                },
                onClose: () {
                  AudioPlayerManager().stopMusic();
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ==========================================
// GIAO DIỆN KHÁM PHÁ (Discovery Tab)
// ==========================================

class DiscoveryScreen extends StatefulWidget {
  final Repository repository;
  final String userId;
  const DiscoveryScreen({Key? key, required this.repository, required this.userId}) : super(key: key);

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  List<Map<String, dynamic>> recommendedSongs = [];
  List<Map<String, dynamic>> trendingSongs = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final recommended = await widget.repository.getRecommendedSongs(widget.userId);
      final trending = await widget.repository.getTrendingSongs(widget.userId);
      setState(() {
        recommendedSongs = recommended;
        trendingSongs = trending;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Lỗi tải dữ liệu Discovery: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  void _onSongTap(Map<String, dynamic> songData, List<Map<String, dynamic>> playlistData) {
    try {
      Song selectedSong = Song(
        id: songData['id']?.toString() ?? '',
        title: songData['title']?.toString() ?? 'Unknown',
        album: songData['album']?.toString() ?? 'Unknown',
        artist: songData['artist']?.toString() ?? 'Unknown',
        source: songData['source']?.toString() ?? '',
        image: songData['image']?.toString() ?? '',
        duration: int.tryParse(songData['duration']?.toString() ?? '0') ?? 0,
      );

      List<Song> playlist = playlistData.map((data) => Song(
          id: data['id']?.toString() ?? '',
          title: data['title']?.toString() ?? 'Unknown',
          album: data['album']?.toString() ?? 'Unknown',
          artist: data['artist']?.toString() ?? 'Unknown',
          source: data['source']?.toString() ?? '',
          image: data['image']?.toString() ?? '',
          duration: int.tryParse(data['duration']?.toString() ?? '0') ?? 0,
        ),
      ).toList();

      Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (context) => NowPlaying(songs: playlist, playingSong: selectedSong),
        ),
      );
    } catch (e) {
      debugPrint("🚨 LỖI KHI BẤM VÀO BÀI HÁT: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discovery', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24)),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              child: Text('Suggested for you', 
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colorScheme.onSurface.withValues(alpha: 0.9))),
            ),
            SizedBox(
              height: 220,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: recommendedSongs.length,
                itemBuilder: (context, index) => _buildSongCard(recommendedSongs[index]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Trending Now', 
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colorScheme.onSurface.withValues(alpha: 0.9))),
                  TextButton(onPressed: () {}, child: const Text('See all')),
                ],
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              physics: const NeverScrollableScrollPhysics(),
              itemCount: trendingSongs.length,
              itemBuilder: (context, index) => _buildTrendingTile(trendingSongs[index], index + 1),
            ),
            const SizedBox(height: 100), // Khoảng trống cho MiniPlayer
          ],
        ),
      ),
    );
  }

  Widget _buildSongCard(Map<String, dynamic> song) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => _onSongTap(song, recommendedSongs),
      child: Container(
        width: 150,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  )
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Image.network(
                    song['image'] ?? '',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: colorScheme.surfaceContainerHighest,
                      child: Icon(Icons.music_note, size: 50, color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              song['title'] ?? 'Unknown',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              song['artist'] ?? 'Unknown',
              style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendingTile(Map<String, dynamic> song, int rank) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5), width: 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 30,
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: rank <= 3 ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.3),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                song['image'] ?? '',
                width: 54,
                height: 54,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 54,
                  height: 54,
                  color: colorScheme.surfaceContainerHighest,
                  child: Icon(Icons.music_note, color: colorScheme.onSurfaceVariant),
                ),
              ),
            ),
          ],
        ),
        title: Text(
          song['title'] ?? 'Unknown',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          song['artist'] ?? 'Unknown',
          style: TextStyle(fontSize: 13, color: colorScheme.onSurface.withValues(alpha: 0.6)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          icon: const Icon(Icons.more_vert_rounded),
          onPressed: () {},
        ),
        onTap: () => _onSongTap(song, trendingSongs),
      ),
    );
  }
}

// ==========================================
// GIAO DIỆN HOME (Danh sách bài hát chính)
// ==========================================

class HomeTab extends StatelessWidget {
  final String userId;
  const HomeTab({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return HomeTabPage(userId: userId);
  }
}

class HomeTabPage extends StatefulWidget {
  final String userId;
  const HomeTabPage({super.key, required this.userId});

  @override
  State<HomeTabPage> createState() => _HomeTabPageState();
}

class _HomeTabPageState extends State<HomeTabPage> {
  List<Song> songs = [];
  List<Song> losslessSongs = [];
  bool isPremium = false;
  late MusicViewModel _viewModel;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkPremium();
    _viewModel = MusicViewModel(repository: MusicRepositoryImpl(), userId: widget.userId);
    _viewModel.addListener(() {
      if (mounted) {
        setState(() {
          songs = _viewModel.songs;
          // Lọc nhạc Lossless (do Admin thêm từ Firestore)
          losslessSongs = _viewModel.songs.where((s) => !s.source.contains('thantrieu.com')).toList();
        });
      }
    });
    _viewModel.loadSongs();
  }

  Future<void> _checkPremium() async {
    final status = await FirebaseService.instance.isUserPremium(widget.userId);
    if (mounted) {
      setState(() => isPremium = status);
    }
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tạo danh sách mới'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Nhập tên danh sách...'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await _viewModel.createNewPlaylist(controller.text);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Tạo'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Library', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24)),
        actions: [
          IconButton(
            icon: const Icon(Icons.psychology_rounded, color: Colors.blue, size: 28),
            onPressed: () {
              Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (context) => GeminiSearchScreen(allSongs: _viewModel.allSongsForAI),
                ),
              );
            },
            tooltip: 'Gemini Assistant',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // THANH TÌM KIẾM
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search songs, artists...',
                prefixIcon: const Icon(Icons.search),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (value) => _viewModel.searchSongs(value),
            ),
          ),
          Expanded(
            child: songs.isEmpty && !_viewModel.isLoading
                ? const Center(child: Text('No songs found.'))
                : _viewModel.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        padding: const EdgeInsets.only(bottom: 150),
                        children: [
                          // DÒNG NHẠC LOSSLESS (Chỉ cho Premium)
                          if (isPremium && losslessSongs.isNotEmpty) ...[
                            const Padding(
                              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                              child: Text(
                                'LOSSLESS EXPERIENCE',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                  color: Colors.amber,
                                ),
                              ),
                            ),
                            SizedBox(
                              height: 180,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                itemCount: losslessSongs.length,
                                itemBuilder: (context, index) {
                                  final song = losslessSongs[index];
                                  return _buildLosslessCard(song);
                                },
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
                              child: Text(
                                'ALL SONGS',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                          // DANH SÁCH NHẠC CHÍNH
                          ...songs.map((song) => _SongItemSection(parent: this, song: song)).toList(),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildLosslessCard(Song song) {
    return GestureDetector(
      onTap: () => navigate(song),
      child: Container(
        width: 140,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                song.image,
                height: 120,
                width: 140,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: Colors.grey, child: const Icon(Icons.music_note)),
              ),
            ),
            const SizedBox(height: 8),
            Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  void showBottomSheet(Song song) {
    _viewModel.loadUserPlaylists();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(16),
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            children: [
              Text('Thêm "${song.title}" vào...', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ListTile(
                leading: const Icon(Icons.add_box, color: Colors.blue),
                title: const Text('Tạo danh sách phát mới'),
                onTap: () => _showCreatePlaylistDialog(context),
              ),
              const Divider(),
              Expanded(
                child: _viewModel.playlists.isEmpty
                    ? const Center(child: Text('Bạn chưa có danh sách phát nào'))
                    : ListView.builder(
                  itemCount: _viewModel.playlists.length,
                  itemBuilder: (context, index) {
                    final playlist = _viewModel.playlists[index];
                    return ListTile(
                      leading: const Icon(Icons.playlist_play),
                      title: Text(playlist['title']),
                      onTap: () async {
                        await _viewModel.addSongToPlaylist(playlist['id'], song.id);
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã thêm vào danh sách phát')));
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void navigate(Song song) {
    Navigator.push(
      context,
      CupertinoPageRoute(builder: (context) => NowPlaying(songs: songs, playingSong: song)),
    );
  }
}

class _SongItemSection extends StatelessWidget {
  const _SongItemSection({required this.parent, required this.song});
  final _HomeTabPageState parent;
  final Song song;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: FadeInImage.assetNetwork(
            placeholder: 'assets/apple-music-app-for-windows-icon.png',
            image: song.image,
            width: 52,
            height: 52,
            fit: BoxFit.cover,
            imageErrorBuilder: (context, error, stackTrace) => Image.asset('assets/apple-music-app-for-windows-icon.png', width: 52, height: 52),
          ),
        ),
        title: Text(song.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text(song.artist, style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 13)),
        trailing: IconButton(onPressed: () => parent.showBottomSheet(song), icon: const Icon(Icons.more_vert_rounded)),
        onTap: () => parent.navigate(song),
      ),
    );
  }
}

// ==========================================
// WIDGET MINI PLAYER
// ==========================================

class MiniPlayer extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onClose;
  final bool isPlaying;

  const MiniPlayer({
    super.key,
    required this.song,
    required this.onTap,
    required this.onPlayPause,
    required this.onNext,
    required this.onPrevious,
    required this.onClose,
    this.isPlaying = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 15,
              offset: const Offset(0, 5),
            )
          ],
        ),
        child: Row(
          children: [
            Hero(
              tag: 'song_art_${song.id}',
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: FadeInImage.assetNetwork(
                    placeholder: 'assets/apple-music-app-for-windows-icon.png',
                    image: song.image,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    imageErrorBuilder: (context, error, stackTrace) => const Icon(Icons.music_note, size: 50),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: colorScheme.onPrimaryContainer.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 32),
              onPressed: onPlayPause,
              color: colorScheme.onPrimaryContainer,
            ),
            IconButton(
              icon: const Icon(Icons.skip_next_rounded, size: 28),
              onPressed: onNext,
              color: colorScheme.onPrimaryContainer,
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20),
              onPressed: onClose,
              color: colorScheme.onPrimaryContainer.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// CÁC TAB KHÁC (Settings)
// ==========================================

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  bool _isDarkMode = themeNotifier.value == ThemeMode.dark;
  String _sleepTimerText = "Tắt";

  void _showSleepTimerDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Hẹn giờ tắt nhạc', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ListTile(title: const Text('Tắt'), onTap: () => _setTimer("Tắt")),
            ListTile(title: const Text('Sau 1 phút'), onTap: () => _setTimer("1 phút")),
            ListTile(title: const Text('Sau 30 phút'), onTap: () => _setTimer("30 phút")),
            ListTile(title: const Text('Sau 60 phút'), onTap: () => _setTimer("60 phút")),
          ],
        ),
      ),
    );
  }

  void _setTimer(String value) {
    setState(() => _sleepTimerText = value);
    Navigator.pop(context);
    Duration? duration;
    if (value == "1 phút") duration = const Duration(minutes: 1);
    else if (value == "30 phút") duration = const Duration(minutes: 30);
    else if (value == "60 phút") duration = const Duration(minutes: 60);

    AudioPlayerManager().setSleepTimer(duration);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã hẹn giờ tắt: $value')));
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn thoát không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Thoát', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt', style: TextStyle(fontWeight: FontWeight.bold)), centerTitle: true),
      body: ListView(
        children: [
          SwitchListTile(
            secondary: Icon(_isDarkMode ? Icons.dark_mode : Icons.light_mode, color: _isDarkMode ? Colors.orange : Colors.blue),
            title: const Text('Chế độ tối'),
            value: _isDarkMode,
            onChanged: (bool value) {
              setState(() => _isDarkMode = value);
              themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.timer_outlined, color: Colors.green),
            title: const Text('Hẹn giờ tắt nhạc'),
            trailing: Text(_sleepTimerText, style: const TextStyle(color: Colors.grey)),
            onTap: _showSleepTimerDialog,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Đăng xuất', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            onTap: _logout,
          ),
        ],
      ),
    );
  }
}
