import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'model/song.dart';
import 'dart:convert';

class GeminiService {
  static final GeminiService instance = GeminiService._init();
  GeminiService._init();

  late final GenerativeModel _model;
  bool _isInitialized = false;

  void init() {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      print('⚠️ Gemini API Key không tìm thấy trong file .env!');
      return;
    }
    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
      ),
    );
    _isInitialized = true;
  }

  Future<String?> analyzeMusicQuery(String query, List<Song> library) async {
    if (!_isInitialized) init();
    if (!_isInitialized) return null;

    final songListJson = library.map((s) => {
      'id': s.id,
      'title': s.title,
      'artist': s.artist,
      'album': s.album,
    }).toList();

    final prompt = '''
Bạn là một trợ lý âm nhạc AI thông minh. 
Người dùng gửi yêu cầu: "$query"

Đây là danh sách bài hát trong ứng dụng (dưới dạng JSON):
${jsonEncode(songListJson)}

Nhiệm vụ:
1. Nếu yêu cầu là một link nhạc hoặc mô tả bài hát đơn lẻ, hãy xác định đó là bài hát nào.
2. Nếu người dùng muốn TẠO DANH SÁCH PHÁT (Playlist) theo chủ đề, tâm trạng hoặc nghệ sĩ (VD: "Tạo playlist nhạc buồn", "Phát các bài của ERIK"), hãy chọn ra tất cả các bài hát phù hợp từ danh sách trên.
3. Trả về kết quả theo định dạng JSON duy nhất như sau:
{
  "identified_song": "Tên bài hát/chủ đề bạn xác định được",
  "matched_song_id": "ID của bài hát nếu là tìm kiếm đơn lẻ, nếu không hãy để null",
  "playlist_ids": ["Mảng các ID bài hát phù hợp nếu là yêu cầu tạo playlist, nếu không hãy để []"],
  "reason": "Giải thích ngắn gọn tại sao bạn chọn các bài này",
  "is_playlist_creation": true/false (true nếu người dùng muốn tạo danh sách nhiều bài)
}
''';

    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      return response.text;
    } catch (e) {
      print(' Lỗi Gemini: $e');
      return null;
    }
  }
}
