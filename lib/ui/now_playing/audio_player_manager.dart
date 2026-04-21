import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import '../../data/model/song.dart';
import '../home/home.dart';
import 'dart:async';

class AudioPlayerManager {
  AudioPlayerManager._internal();
  static final AudioPlayerManager _instance = AudioPlayerManager._internal();
  factory AudioPlayerManager() => _instance;

  final player = AudioPlayer();
  Stream<DurationState>? durationState;
  String songUrl = "";

  // Báo hiệu bài hát đang phát cho Mini Player
  final ValueNotifier<Song?> currentSongNotifier = ValueNotifier<Song?>(null);

  // Lưu danh sách phát hiện tại
  List<Song> currentPlaylist = [];
  int currentIndex = 0;

  Timer? _sleepTimer;

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

  void prepare({bool isNewSong = false}){
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
      player.setUrl(songUrl);
    }
  }

  void updateSongUrl(String url, {Song? song}) {
    songUrl = url;
    if (song != null) {
      currentSongNotifier.value = song;
    }
    prepare(isNewSong: true);
  }

  // Hàm chuyển bài tiếp theo (dành cho Mini Player)
  void nextSong() {
    if (currentPlaylist.isEmpty) return;
    if (currentIndex < currentPlaylist.length - 1) {
      currentIndex++;
    } else {
      currentIndex = 0; // Hết list thì quay lại từ đầu
    }
    final next = currentPlaylist[currentIndex];
    updateSongUrl(next.source, song: next);
    player.play(); // Tự động phát khi qua bài
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
    player.play(); // Tự động phát khi lùi bài
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