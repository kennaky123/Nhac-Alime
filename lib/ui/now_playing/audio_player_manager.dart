import 'dart:math';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:rxdart/rxdart.dart';
import '../../data/model/song.dart';
import 'dart:async';
import '../../data/firebase_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/youtube_service.dart';

class AudioPlayerManager {
  AudioPlayerManager._internal() {
    // KHÔNG dùng pipeline ngay từ đầu để đảm bảo có tiếng 100%
    player = AudioPlayer();
    _equalizer = AndroidEqualizer();
    player.setVolume(1.0);
  }
  static final AudioPlayerManager _instance = AudioPlayerManager._internal();
  factory AudioPlayerManager() => _instance;

  late AudioPlayer player;
  late final AndroidEqualizer _equalizer;
  bool _isEqualizerSupported = false; // Cờ đánh dấu đã init pipeline hay chưa
  AndroidEqualizer get equalizer => _equalizer;

  /// Hàm này sẽ "nâng cấp" trình phát nhạc để sử dụng Equalizer khi cần
  Future<void> enableEqualizerSupport() async {
    if (_isEqualizerSupported) return;

    final currentPosition = player.position;
    final wasPlaying = player.playing;
    final currentUrl = songUrl;
    final currentSong = currentSongNotifier.value;

    // Giải phóng player cũ
    await player.dispose();

    // Tạo player mới có hỗ trợ Equalizer
    final pipeline = AudioPipeline(androidAudioEffects: [_equalizer]);
    player = AudioPlayer(audioPipeline: pipeline);
    _isEqualizerSupported = true;
    
    // Khôi phục trạng thái
    if (currentUrl.isNotEmpty) {
      updateSongUrl(currentUrl, song: currentSong);
      await player.seek(currentPosition);
      if (wasPlaying) player.play();
    }
  }
  Stream<DurationState>? durationState;
  String songUrl = "";
  bool isSmartShuffle = false;

  // Báo hiệu màu sắc mới khi chuyển bài
  final ValueNotifier<ColorScheme?> currentColorSchemeNotifier = ValueNotifier<ColorScheme?>(null);

  // Báo hiệu bài hát đang phát cho Mini Player
  final ValueNotifier<Song?> currentSongNotifier = ValueNotifier<Song?>(null);

  // Báo hiệu trang NowPlaying đang mở
  final ValueNotifier<bool> isNowPlayingOpen = ValueNotifier<bool>(false);

  // Lưu danh sách phát hiện tại
  List<Song> currentPlaylist = [];
  int currentIndex = 0;

  Timer? _sleepTimer;

  void initAutoNext() {
    player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        nextSong();
      }
    });
  }

  void setSleepTimer(Duration? duration) {
    _sleepTimer?.cancel();

    if (duration != null) {
      _sleepTimer = Timer(duration, () {
        player.pause();
      });
    }
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
  }

  Future<void> prepare({bool isNewSong = false}) async {
    durationState = Rx.combineLatest2<Duration, PlaybackEvent, DurationState>(
        player.positionStream,
        player.playbackEventStream,
            (position, playbackEvent) => DurationState(
            progress: position,
            buffered: playbackEvent.bufferedPosition,
            total: playbackEvent.duration
        )
    );
    if(isNewSong){
      try {
        final cleanUrl = songUrl.trim();
        debugPrint("🎵 Đang tải nhạc: '$cleanUrl'");

        // Ghi lại lịch sử nghe nhạc khi bắt đầu bài mới
        final userId = FirebaseAuth.instance.currentUser?.uid;
        if (userId != null && currentSongNotifier.value != null) {
          final s = currentSongNotifier.value!;
          FirebaseService.instance.logPlayHistory(
            userId, 
            s.id,
            songTitle: s.title,
            artist: s.artist,
            image: s.image,
            source: s.source,
          );
        }

        // Tự động nhận diện Asset hoặc Network URL
        if (cleanUrl.toLowerCase().startsWith('assets/')) {
          await player.setAsset(cleanUrl);
        } else if (cleanUrl.contains('youtube.com') || cleanUrl.contains('youtu.be')) {
          // Xử lý link YouTube: Lấy live stream URL để tránh lỗi 403
          // Lưu ý: Không kiểm tra 'googlevideo.com' ở đây để tránh lặp vô tận
          final liveUrl = await YouTubeService.instance.getStreamUrl(cleanUrl);
          if (liveUrl != null) {
            debugPrint("🔗 Đang phát audio stream trực tiếp từ YouTube...");
            // THÊM HEADERS ĐỂ TRÁNH LỖI 403
            await player.setAudioSource(
              AudioSource.uri(
                Uri.parse(liveUrl),
                headers: {
                  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                  'Referer': 'https://www.youtube.com/',
                  'Origin': 'https://www.youtube.com',
                },
              ),
            );
          } else {
            debugPrint("⚠️ Không lấy được stream, thử phát link gốc (có thể lỗi 403)...");
            await player.setUrl(cleanUrl);
          }
        } else if (cleanUrl.startsWith('http')) {
          await player.setUrl(cleanUrl);
        } else {
          // Trường hợp khác (ví dụ file path local nếu sau này có dùng)
          await player.setFilePath(cleanUrl);
        }
      } catch (e) {
        debugPrint("❌ Lỗi load audio source: $e");
      }
    }
  }

  void updateSongUrl(String url, {Song? song}) async {
    if (song != null) {
      currentSongNotifier.value = song;
      _updatePalette(song.image);
    }

    songUrl = url;
    await prepare(isNewSong: true);
    player.play();
  }

  // Hàm chuyển bài tiếp theo (dành cho Mini Player)
  void nextSong() {
    if (currentPlaylist.isEmpty) return;
    
    if (isSmartShuffle && currentSongNotifier.value != null) {
      _smartNext();
      return;
    }

    if (currentIndex < currentPlaylist.length - 1) {
      currentIndex++;
    } else {
      currentIndex = 0; // Hết list thì quay lại từ đầu
    }
    final next = currentPlaylist[currentIndex];
    updateSongUrl(next.source, song: next);
  }

  void _smartNext() {
    final current = currentSongNotifier.value!;
    // Thuật toán Smart Shuffle đơn giản: Tìm bài cùng artist hoặc cùng album trong playlist
    List<int> candidates = [];
    for (int i = 0; i < currentPlaylist.length; i++) {
      if (i == currentIndex) continue;
      if (currentPlaylist[i].artist == current.artist || currentPlaylist[i].album == current.album) {
        candidates.add(i);
      }
    }

    if (candidates.isNotEmpty) {
      currentIndex = candidates[Random().nextInt(candidates.length)];
    } else {
      // Nếu không tìm thấy sự tương đồng, chọn ngẫu nhiên
      currentIndex = Random().nextInt(currentPlaylist.length);
    }

    final next = currentPlaylist[currentIndex];
    updateSongUrl(next.source, song: next);
  }

  // Hàm lùi bài (dành cho Mini Player)
  void previousSong() {
    if (currentPlaylist.isEmpty) return;
    if (currentIndex > 0) {
      currentIndex--;
    } else {
      currentIndex = currentPlaylist.length - 1;
    }
    final prev = currentPlaylist[currentIndex];
    updateSongUrl(prev.source, song: prev);
  }

  void stopMusic() {
    player.stop();
    currentSongNotifier.value = null;
    currentColorSchemeNotifier.value = null;
  }

  Future<void> _updatePalette(String imageUrl) async {
    if (imageUrl.isEmpty) {
      currentColorSchemeNotifier.value = null;
      return;
    }
    try {
      final PaletteGenerator paletteGenerator = await PaletteGenerator.fromImageProvider(
        NetworkImage(imageUrl),
        size: const Size(200, 200), // Kích thước nhỏ để xử lý nhanh hơn
      ).timeout(const Duration(seconds: 3)); // Tránh treo quá lâu
      
      final Color primaryColor = paletteGenerator.dominantColor?.color ?? Colors.blue;
      
      currentColorSchemeNotifier.value = ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.dark, // Mặc định dark cho Now Playing screen
      );
    } catch (e) {
      debugPrint("❌ Lỗi trích xuất màu: $e");
      currentColorSchemeNotifier.value = null;
    }
  }

  void dispose(){
    player.dispose();
  }
}

class DurationState{
  const DurationState({
    required this.progress,
    required this.buffered,
    this.total,
  });
  final Duration progress;
  final Duration buffered;
  final Duration? total;
}
