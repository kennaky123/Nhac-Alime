import 'package:flutter/material.dart';
import '../../data/reponsitory/repository.dart'; // Chỉnh lại đường dẫn import file repository của bạn cho đúng nhé

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

  // Hàm gọi dữ liệu từ Repository
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
      setState(() { isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Nếu đang tải dữ liệu thì xoay vòng tròn chờ
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
            // --- PHẦN 1: GỢI Ý CHO BẠN (Cuộn ngang) ---
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              child: Text(
                'Gợi ý cho bạn',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(
              height: 200, // Chiều cao của list cuộn ngang
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: recommendedSongs.length,
                itemBuilder: (context, index) {
                  final song = recommendedSongs[index];
                  return _buildSongCard(song);
                },
              ),
            ),

            // --- PHẦN 2: THỊNH HÀNH (Danh sách dọc) ---
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Đang thịnh hành',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            ListView.builder(
              shrinkWrap: true, // Quan trọng để ListView con không chiếm hết màn hình
              physics: const NeverScrollableScrollPhysics(), // Tắt cuộn của ListView này để cuộn chung với SingleChildScrollView bên ngoài
              itemCount: trendingSongs.length,
              itemBuilder: (context, index) {
                final song = trendingSongs[index];
                return _buildTrendingTile(song, index + 1);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Widget vẽ Card cho bài hát cuộn ngang (Có load ảnh từ mạng)
  Widget _buildSongCard(Map<String, dynamic> song) {
    return Container(
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
                  child: const Icon(Icons.music_note, size: 50, color: Colors.grey),
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
    );
  }

  // Widget vẽ List cho bài hát thịnh hành
  Widget _buildTrendingTile(Map<String, dynamic> song, int rank) {
    return ListTile(
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Số thứ hạng (1, 2, 3...)
          Text(
            '#$rank',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: rank <= 3 ? Colors.deepPurple : Colors.grey, // Top 3 màu nổi bật
            ),
          ),
          const SizedBox(width: 12),
          // Ảnh bài hát nhỏ
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              song['image'] ?? '',
              width: 50,
              height: 50,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 50, height: 50, color: Colors.grey.shade300,
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
      onTap: () {
        // Xử lý khi bấm vào bài hát (VD: Mở màn hình phát nhạc)
      },
    );
  }
}