import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../data/model/song.dart';
import '../now_playing/playing.dart';
import '../../data/reponsitory/repository.dart';


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
      final recommended = await widget.repository.getRecommendedSongs("user_01");
      final trending = await widget.repository.getTrendingSongs();

      setState(() {
        recommendedSongs = recommended;
        trendingSongs = trending;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Lỗi tải dữ liệu Discovery: $e");
      setState(() { isLoading = false; });
    }
  }

  // --- HÀM MỚI: Xử lý khi nhấn vào bài hát ---
  // --- HÀM ĐÃ ĐƯỢC NÂNG CẤP ÉP KIỂU AN TOÀN ---
  void _onSongTap(Map<String, dynamic> songData, List<Map<String, dynamic>> playlistData) {
    try {
      // 1. Ép kiểu an toàn: Thêm .toString() để chống lỗi crash ngầm
      Song selectedSong = Song(
        id: songData['id']?.toString() ?? '',
        title: songData['title']?.toString() ?? 'Unknown',
        album: songData['album']?.toString() ?? 'Unknown',
        artist: songData['artist']?.toString() ?? 'Unknown',
        source: songData['source']?.toString() ?? '',
        image: songData['image']?.toString() ?? '',
        duration: int.tryParse(songData['duration']?.toString() ?? '0') ?? 0,
      );

      // 2. Chuyển đổi toàn bộ danh sách
      List<Song> playlist = playlistData.map((data) => Song(
        id: data['id']?.toString() ?? '',
        title: data['title']?.toString() ?? 'Unknown',
        album: data['album']?.toString() ?? 'Unknown',
        artist: data['artist']?.toString() ?? 'Unknown',
        source: data['source']?.toString() ?? '',
        image: data['image']?.toString() ?? '',
        duration: int.tryParse(data['duration']?.toString() ?? '0') ?? 0,
      )).toList();

      // 3. Mở màn hình phát nhạc
      Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (context) => NowPlaying(
            songs: playlist,
            playingSong: selectedSong,
          ),
        ),
      );
    } catch (e) {
      // Nếu vẫn còn lỗi, nó sẽ in dòng chữ màu đỏ ra Console để chúng ta biết ngay
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
        title: const Text('Discovery', style: TextStyle(fontWeight: FontWeight.bold)),
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
              child: Text('Gợi ý cho bạn', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
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
              child: Text('Đang thịnh hành', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
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
    return GestureDetector(
      // GỌI HÀM PHÁT NHẠC Ở ĐÂY
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
                height: 140, width: 140,
                child: Image.network(
                  song['image'] ?? '',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey.shade300,
                    child: const Icon(Icons.music_note, size: 50, color: Colors.grey),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(song['title'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(song['artist'] ?? 'Unknown', style: const TextStyle(color: Colors.grey, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
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
          Text('#$rank', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: rank <= 3 ? Colors.deepPurple : Colors.grey)),
          const SizedBox(width: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              song['image'] ?? '',
              width: 50, height: 50, fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 50, height: 50, color: Colors.grey.shade300,
                child: const Icon(Icons.music_note, color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
      title: Text(song['title'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(song['artist'] ?? 'Unknown', maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.more_vert),
      // GỌI HÀM PHÁT NHẠC Ở ĐÂY
      onTap: () => _onSongTap(song, trendingSongs),
    );
  }
}