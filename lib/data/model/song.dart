class Song {
  Song({
    required this.id,
    required this.title,
    required this.album,
    required this.artist,
    required this.source,
    required this.image,
    required this.duration,
    this.isFavorite = false, // Thêm dòng này để quản lý trạng thái tim
  });

  // Giữ nguyên factory Json
  factory Song.fromJson(Map<String, dynamic> map) {
    return Song(
      id: map['id'],
      title: map['title'],
      album: map['album'],
      artist: map['artist'],
      source: map['source'],
      image: map['image'],
      duration: map['duration'] as int,
      // Lưu ý: Không lấy 'favorite' từ API vì API là dùng chung cho mọi người,
      // còn "thích" là do người dùng cá nhân quyết định trong Database.
    );
  }

  String id;
  String title;
  String album;
  String artist;
  String source;
  String image;
  int duration;
  bool isFavorite; // Thêm biến này vào class

// ... (giữ nguyên hashCode và toString)


  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Song &&
              runtimeType == other.runtimeType &&
              id == other.id; // So sánh bằng ID mới chính xác

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Song{id: $id, title: $title, album: $album, artist: $artist, source: $source, image: $image, duration: $duration}';
  }
}