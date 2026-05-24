import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class YouTubeService {
  static final YouTubeService instance = YouTubeService._init();
  YouTubeService._init();

  final _yt = YoutubeExplode();

  /// Trích xuất tiêu đề video từ một URL YouTube
  Future<String?> getVideoTitle(String url) async {
    try {
      final videoId = VideoId.parseVideoId(url);
      if (videoId == null) return null;

      final video = await _yt.videos.get(videoId);
      return video.title;
    } catch (e) {
      print('❌ Lỗi YouTube Explode: $e');
      return null;
    }
  }

  /// Lấy URL stream audio mới nhất từ một link YouTube
  Future<String?> getStreamUrl(String url) async {
    try {
      final videoId = VideoId.parseVideoId(url);
      if (videoId == null) {
        print('⚠️ Không thể phân tách Video ID từ URL: $url');
        return null;
      }

      print('📡 Đang trích xuất audio stream cho ID: $videoId');
      final manifest = await _yt.videos.streamsClient.getManifest(videoId);
      final streamInfo = manifest.audioOnly.withHighestBitrate();
      final streamUrl = streamInfo.url.toString();
      print('✅ Đã lấy được Audio Stream URL (bắt đầu bằng: ${streamUrl.substring(0, 30)}...)');
      return streamUrl;
    } catch (e) {
      print('❌ Lỗi lấy Stream URL: $e');
      return null;
    }
  }

  /// Trích xuất chi tiết video từ một URL YouTube
  Future<Map<String, dynamic>?> getVideoDetails(String url) async {
    try {
      final videoId = VideoId.parseVideoId(url);
      if (videoId == null) return null;

      final video = await _yt.videos.get(videoId);
      
      return {
        'title': video.title,
        'artist': video.author,
        'image': video.thumbnails.highResUrl,
        'duration': video.duration?.inSeconds ?? 240,
        'source': url, // Chỉ lưu link gốc YouTube để tránh hết hạn (403)
      };
    } catch (e) {
      print('❌ Lỗi YouTube Explode: $e');
      return null;
    }
  }

  void dispose() {
    _yt.close();
  }
}
