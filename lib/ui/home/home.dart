import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:music_app/ui/home/viewmodel.dart';
import 'package:music_app/ui/now_playing/audio_player_manager.dart';
import '../../data/model/song.dart';
import '../now_playing/playing.dart';
import '../../data/reponsitory/music_repository_impl.dart';
import '../../data/reponsitory/repository.dart';
import '../../ui/user/user.dart';
import '../../ui/user/playlist_detail.dart';
import '../../main.dart';
import 'dart:async'; // Thêm thư viện này để dùng Timer
import '../user/login.dart';

void main() {
  runApp(const MusicApp());
}


class MusicApp extends StatelessWidget {
  const MusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ValueListenableBuilder giúp lắng nghe khi nút gạt thay đổi để vẽ lại toàn app
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return MaterialApp(
          title: 'Music App',
          // Theme Sáng
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
          ),
          // Theme Tối
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
            scaffoldBackgroundColor: Colors.black, // Nền đen sâu
          ),
          themeMode: currentMode,
          // Áp dụng theme theo trạng thái hiện tại
          home: const LoginScreen(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

// ==========================================

// MÀN HÌNH CHÍNH (Chứa thanh điều hướng Bottom Navigation)

// ==========================================

class MusicHomepage extends StatefulWidget {
  const MusicHomepage({super.key});

  @override
  State<MusicHomepage> createState() => _MusicHomepageState();
}

class _MusicHomepageState extends State<MusicHomepage> {
  final List<Widget> _tabs = [
    const HomeTab(),

    DiscoveryScreen(repository: MusicRepositoryImpl()),

    const AccountTab(),

    // Giả sử class này đã có trong ui/user/user.dart của bạn
    const SettingsTab(),
  ];

  Song? _currentPlayingSong;

  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();

    AudioPlayerManager().currentSongNotifier.addListener(() {
      if (mounted) {
        setState(() {
          _currentPlayingSong = AudioPlayerManager().currentSongNotifier.value;
        });
      }
    });

    AudioPlayerManager().player.playingStream.listen((playing) {
      if (mounted) {
        setState(() {
          _isPlaying = playing;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          CupertinoTabScaffold(
            tabBar: CupertinoTabBar(
              backgroundColor: Theme.of(context).colorScheme.onInverseSurface,

              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),

                BottomNavigationBarItem(
                  icon: Icon(Icons.album),
                  label: 'Discovery',
                ),

                BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  label: 'Account',
                ),

                BottomNavigationBarItem(
                  icon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
            ),

            tabBuilder: (BuildContext context, int index) {
              return CupertinoTabView(builder: (context) => _tabs[index]);
            },
          ),

          // Hiển thị MiniPlayer nếu đang có bài hát được chọn
          if (_currentPlayingSong != null)
            Positioned(
              bottom: 50,

              left: 0,

              right: 0,

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
              ),
            ),
        ],
      ),
    );
  }
}

// ==========================================

// GIAO DIỆN KHÁM PHÁ (Discovery Tab) - ĐÃ THÊM TÍNH NĂNG PHÁT NHẠC

// ==========================================

class DiscoveryScreen extends StatefulWidget {
  final Repository repository;

  const DiscoveryScreen({Key? key, required this.repository}) : super(key: key);

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
      final recommended = await widget.repository.getRecommendedSongs(
        "user_01",
      );

      final trending = await widget.repository.getTrendingSongs();

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


  // --- HÀM XỬ LÝ PHÁT NHẠC (ÉP KIỂU AN TOÀN) ---

  void _onSongTap(
      Map<String, dynamic> songData,
      List<Map<String, dynamic>> playlistData,
      ) {
    try {
      // 1. Ép kiểu an toàn sang Song

      Song selectedSong = Song(
        id: songData['id']?.toString() ?? '',

        title: songData['title']?.toString() ?? 'Unknown',

        album: songData['album']?.toString() ?? 'Unknown',

        artist: songData['artist']?.toString() ?? 'Unknown',

        source: songData['source']?.toString() ?? '',

        image: songData['image']?.toString() ?? '',

        duration: int.tryParse(songData['duration']?.toString() ?? '0') ?? 0,
      );

      // 2. Chuyển đổi toàn bộ danh sách để làm playlist vuốt tới/lui

      List<Song> playlist = playlistData
          .map(
            (data) => Song(
          id: data['id']?.toString() ?? '',

          title: data['title']?.toString() ?? 'Unknown',

          album: data['album']?.toString() ?? 'Unknown',

          artist: data['artist']?.toString() ?? 'Unknown',

          source: data['source']?.toString() ?? '',

          image: data['image']?.toString() ?? '',

          duration: int.tryParse(data['duration']?.toString() ?? '0') ?? 0,
        ),
      )
          .toList();

      // 3. Tái sử dụng màn hình NowPlaying

      Navigator.push(
        context,

        CupertinoPageRoute(
          builder: (context) =>
              NowPlaying(songs: playlist, playingSong: selectedSong),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Discovery',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),

        centerTitle: true,

        elevation: 0,

        backgroundColor: Colors.transparent,

        foregroundColor: Colors.black,
      ),

      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),

              child: Text(
                'Gợi ý cho bạn',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),

            SizedBox(
              height: 200,

              child: ListView.builder(
                scrollDirection: Axis.horizontal,

                physics: const BouncingScrollPhysics(),

                padding: const EdgeInsets.symmetric(horizontal: 8),

                itemCount: recommendedSongs.length,

                itemBuilder: (context, index) {
                  return _buildSongCard(recommendedSongs[index]);
                },
              ),
            ),

            const Padding(
              padding: EdgeInsets.all(16.0),

              child: Text(
                'Đang thịnh hành',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),

            ListView.builder(
              shrinkWrap: true,

              physics: const NeverScrollableScrollPhysics(),

              itemCount: trendingSongs.length,

              itemBuilder: (context, index) {
                return _buildTrendingTile(trendingSongs[index], index + 1);
              },
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSongCard(Map<String, dynamic> song) {
    // ĐÃ THÊM GESTURE DETECTOR ĐỂ BẤM ĐƯỢC

    return GestureDetector(
      onTap: () => _onSongTap(song, recommendedSongs),

      child: Container(
        width: 140,

        margin: const EdgeInsets.symmetric(horizontal: 8),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),

              child: SizedBox(
                height: 140,

                width: 140,

                child: Image.network(
                  song['image'] ?? '',

                  fit: BoxFit.cover,

                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey.shade300,

                    child: const Icon(
                      Icons.music_note,
                      size: 50,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            Text(
              song['title'] ?? 'Unknown',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            Text(
              song['artist'] ?? 'Unknown',
              style: const TextStyle(color: Colors.grey, fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendingTile(Map<String, dynamic> song, int rank) {
    return ListTile(
      leading: Row(
        mainAxisSize: MainAxisSize.min,

        children: [
          Text(
            '#$rank',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: rank <= 3 ? Colors.deepPurple : Colors.grey,
            ),
          ),

          const SizedBox(width: 12),

          ClipRRect(
            borderRadius: BorderRadius.circular(8),

            child: Image.network(
              song['image'] ?? '',

              width: 50,
              height: 50,
              fit: BoxFit.cover,

              errorBuilder: (context, error, stackTrace) => Container(
                width: 50,
                height: 50,
                color: Colors.grey.shade300,

                child: const Icon(Icons.music_note, color: Colors.grey),
              ),
            ),
          ),
        ],
      ),

      title: Text(
        song['title'] ?? 'Unknown',
        style: const TextStyle(fontWeight: FontWeight.bold),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),

      subtitle: Text(
        song['artist'] ?? 'Unknown',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),

      trailing: const Icon(Icons.more_vert),

      // ĐÃ THÊM ONTAP GỌI HÀM PHÁT NHẠC
      onTap: () => _onSongTap(song, trendingSongs),
    );
  }
}

// ==========================================

// GIAO DIỆN HOME (Danh sách bài hát chính)

// ==========================================

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const HomeTabPage();
  }
}

class HomeTabPage extends StatefulWidget {
  const HomeTabPage({super.key});

  @override
  State<HomeTabPage> createState() => _HomeTabPageState();
}

class _HomeTabPageState extends State<HomeTabPage> {
  List<Song> songs = [];

  late MusicViewModel _viewModel;

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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),

          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await _viewModel.createNewPlaylist(controller.text);

                if (mounted) Navigator.pop(context);
              }
            },

            child: const Text('Tạo'),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    _viewModel = MusicViewModel(repository: MusicRepositoryImpl());

    _viewModel.addListener(() {
      if (mounted) {
        setState(() {
          songs = _viewModel.songs;
        });
      }
    });

    _viewModel.loadSongs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'All Songs',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),

        centerTitle: true,

        elevation: 0,

        backgroundColor: Colors.transparent,

        foregroundColor: Colors.black,
      ),

      body: songs.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
        itemBuilder: (context, position) =>
            _SongItemSection(parent: this, song: songs[position]),

        separatorBuilder: (context, index) => const Divider(
          color: Colors.grey,
          thickness: 1,
          indent: 24,
          endIndent: 24,
        ),

        itemCount: songs.length,

        shrinkWrap: true,
      ),
    );
  }

  @override
  void dispose() {
    _viewModel.dispose();
    AudioPlayerManager().dispose();
    super.dispose();
  }

  void showBottomSheet(Song song) {
    _viewModel.loadUserPlaylists();

    showModalBottomSheet(
      context: context,

      isScrollControlled: true,

      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(16),

              height: MediaQuery.of(context).size.height * 0.6,

              child: Column(
                children: [
                  Text(
                    'Thêm "${song.title}" vào...',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 10),

                  ListTile(
                    leading: const Icon(Icons.add_box, color: Colors.blue),

                    title: const Text('Tạo danh sách phát mới'),

                    onTap: () => _showCreatePlaylistDialog(context),
                  ),

                  const Divider(),

                  Expanded(
                    child: _viewModel.playlists.isEmpty
                        ? const Center(
                      child: Text('Bạn chưa có danh sách phát nào'),
                    )
                        : ListView.builder(
                      itemCount: _viewModel.playlists.length,

                      itemBuilder: (context, index) {
                        final playlist = _viewModel.playlists[index];

                        return ListTile(
                          leading: const Icon(Icons.playlist_play),

                          title: Text(playlist['title']),

                          onTap: () async {
                            await _viewModel.addSongToPlaylist(
                              playlist['id'],
                              song.id,
                            );

                            if (mounted) {
                              Navigator.pop(context);

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Đã thêm vào danh sách phát',
                                  ),
                                ),
                              );
                            }
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void navigate(Song song) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) {
          return NowPlaying(songs: songs, playingSong: song);
        },
      ),
    );
  }
}

class _SongItemSection extends StatelessWidget {
  const _SongItemSection({required this.parent, required this.song});

  final _HomeTabPageState parent;

  final Song song;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 24, right: 8),

      leading: ClipRRect(
        borderRadius: BorderRadius.circular(16),

        child: FadeInImage.assetNetwork(
          placeholder: 'assets/apple-music-app-for-windows-icon.png',

          image: song.image,

          width: 48,
          height: 48,

          imageErrorBuilder: (context, error, stackTrace) => Image.asset(
            'assets/apple-music-app-for-windows-icon.png',
            width: 48,
            height: 48,
          ),
        ),
      ),

      title: Text(song.title),

      subtitle: Text(song.artist),

      trailing: IconButton(
        onPressed: () => parent.showBottomSheet(song),

        icon: const Icon(Icons.more_horiz),
      ),

      onTap: () => parent.navigate(song),
    );
  }
}

// ==========================================

// WIDGET MINI PLAYER (Thanh phát nhạc thu nhỏ)

// ==========================================

class MiniPlayer extends StatelessWidget {
  final Song song;

  final VoidCallback onTap;

  final VoidCallback onPlayPause;

  final VoidCallback onNext;

  final VoidCallback onPrevious;

  final bool isPlaying;

  const MiniPlayer({
    super.key,

    required this.song,
    required this.onTap,

    required this.onPlayPause,
    required this.onNext,
    required this.onPrevious,

    this.isPlaying = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,

      child: Container(
        height: 65,

        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),

        padding: const EdgeInsets.symmetric(horizontal: 12),

        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,

          borderRadius: BorderRadius.circular(12),

          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),

        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),

              child: FadeInImage.assetNetwork(
                placeholder: 'assets/apple-music-app-for-windows-icon.png',

                image: song.image,

                width: 45,
                height: 45,
                fit: BoxFit.cover,

                imageErrorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.music_note, size: 45),
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                mainAxisAlignment: MainAxisAlignment.center,

                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),

                  Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),

            IconButton(
              icon: const Icon(Icons.skip_previous),
              onPressed: onPrevious,
            ),

            IconButton(
              icon: Icon(
                isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                size: 35,
              ),
              onPressed: onPlayPause,
            ),

            IconButton(icon: const Icon(Icons.skip_next), onPressed: onNext),
          ],
        ),
      ),
    );
  }
}

// ==========================================

// CÁC TAB KHÁC (Settings, Account)

// ==========================================

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  bool _isDarkMode = themeNotifier.value == ThemeMode.dark;
  String _sleepTimerText = "Tắt"; // Trạng thái hẹn giờ
  Timer? _sleepTimer;

  // Hàm xử lý Hẹn giờ tắt nhạc
  void _showSleepTimerDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Hẹn giờ tắt nhạc',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ListTile(title: const Text('Tắt'), onTap: () => _setTimer("Tắt")),
              ListTile(
                title: const Text('Sau 1 phút'),
                onTap: () => _setTimer("1 phút"),
              ),
              ListTile(
                title: const Text('Sau 30 phút'),
                onTap: () => _setTimer("30 phút"),
              ),
              ListTile(
                title: const Text('Sau 60 phút'),
                onTap: () => _setTimer("60 phút"),
              ),
            ],
          ),
        );
      },
    );
  }

  void _setTimer(String value) {
    setState(() => _sleepTimerText = value);
    Navigator.pop(context);

    Duration? duration;

    switch (value) {
      case "1 phút":
        duration = const Duration(minutes: 1);
        break;
      case "30 phút":
        duration = const Duration(minutes: 30);
        break;
      case "60 phút":
        duration = const Duration(minutes: 60);
        break;
      case "Tắt":
        duration = null;
        break;
    }

    AudioPlayerManager().setSleepTimer(duration);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã hẹn giờ tắt: $value')),
    );
  }
  // Hàm Đăng xuất
  void _logout() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn thoát không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
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
      appBar: AppBar(
        title: const Text(
          'Cài đặt',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          // 1. NÚT GẠT CHẾ ĐỘ SÁNG/TỐI
          SwitchListTile(
            secondary: Icon(
              _isDarkMode ? Icons.dark_mode : Icons.light_mode,
              color: _isDarkMode ? Colors.orange : Colors.blue,
            ),
            title: const Text('Chế độ tối'),
            subtitle: const Text('Thay đổi giao diện ứng dụng'),
            value: _isDarkMode,
            onChanged: (bool value) {
              setState(() {
                _isDarkMode = value;
              });
              // Note: Để đổi toàn bộ theme app, bạn cần dùng State Management như Provider
              // hoặc truyền callback về MaterialApp.
              // Dòng này sẽ phát tín hiệu đổi màu cho toàn app:
              themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
            },
          ),
          const Divider(),

          // 2. NÚT HẸN GIỜ
          ListTile(
            leading: const Icon(Icons.timer_outlined, color: Colors.green),
            title: const Text('Hẹn giờ tắt nhạc'),
            trailing: Text(
              _sleepTimerText,
              style: const TextStyle(color: Colors.grey),
            ),
            onTap: _showSleepTimerDialog,
          ),
          const Divider(),

          // CÁC CÀI ĐẶT KHÁC (Ví dụ thêm)
          const ListTile(
            leading: Icon(Icons.info_outline, color: Colors.grey),
            title: Text('Phiên bản ứng dụng'),
            trailing: Text('1.0.0'),
          ),
          const Divider(),

          // 3. NÚT ĐĂNG XUẤT
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              'Đăng xuất',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            onTap: _logout,
          ),
        ],
      ),
    );
  }
}

/*

class AccountTab extends StatelessWidget {

  const AccountTab({super.key});


  @override

  Widget build(BuildContext context) {

    return const CupertinoPageScaffold(

      navigationBar: CupertinoNavigationBar(middle: Text('Account')),

      child: Center(child: Text('Account Screen')),

    );

  }

}

*/
