import 'dart:async';

class PlaylistEventBus {
  static final PlaylistEventBus _instance = PlaylistEventBus._internal();
  factory PlaylistEventBus() => _instance;
  PlaylistEventBus._internal();

  final _controller = StreamController<void>.broadcast();

  Stream<void> get onPlaylistChanged => _controller.stream;

  void notifyPlaylistChanged() {
    _controller.add(null);
  }
}
