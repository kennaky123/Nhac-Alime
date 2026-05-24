import 'dart:math';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../data/firebase_service.dart';
import '../../data/model/song.dart';
import '../setting/premium_screen.dart';
import 'audio_player_manager.dart';
import 'premium_ad_dialog.dart';

class NowPlaying extends StatelessWidget {
  const NowPlaying({super.key, required this.playingSong, required this.songs});
  final Song playingSong;
  final List<Song> songs;

  @override
  Widget build(BuildContext context) {
    return NowPlayingPage(
      songs: songs,
      playingSong: playingSong,
    );
  }
}

class NowPlayingPage extends StatefulWidget {
  const NowPlayingPage({super.key, required this.songs, required this.playingSong});

  final Song playingSong;
  final List<Song> songs;

  @override
  State<NowPlayingPage> createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends State<NowPlayingPage> with SingleTickerProviderStateMixin {
  late AnimationController _imageAnimController;
  late AudioPlayerManager _audioPlayerManager;
  late int _selectedItemIndex;
  late Song _song;
  late double _currentAnimationPosition;
  late LoopMode _loopMode;
  bool _isShuffle = false;
  bool _isPremium = true; // Mặc định là true để không hiện quảng cáo khi đang load

  @override
  void initState(){
    super.initState();
    _currentAnimationPosition = 0.0;
    _song = widget.playingSong;
    _imageAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 12000),
    );
    _audioPlayerManager = AudioPlayerManager();
    _audioPlayerManager.isNowPlayingOpen.value = true; // Đánh dấu là đang mở trang phát nhạc
    _checkPremium();

    // ĐỒNG BỘ PLAYLIST VỚI MANAGER
    _audioPlayerManager.currentPlaylist = widget.songs;
    _audioPlayerManager.currentIndex = widget.songs.indexOf(widget.playingSong);

    if(_audioPlayerManager.songUrl.compareTo(_song.source) != 0){
      _audioPlayerManager.updateSongUrl(_song.source, song: _song); 
      // XÓA DÒNG GỌI prepare Ở ĐÂY VÌ updateSongUrl ĐÃ TỰ GỌI RỒI
    } else {
      _audioPlayerManager.prepare(isNewSong: false);
    }

    _selectedItemIndex = widget.songs.indexOf(widget.playingSong);
    _loopMode = LoopMode.off;
  }

  Future<void> _checkPremium() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final premium = await FirebaseService.instance.isUserPremium(user.uid);
      if (mounted) {
        setState(() {
          _isPremium = premium;
        });

        // Nếu không phải Premium thì hiện quảng cáo chặn nhạc
        if (!premium) {
          _audioPlayerManager.player.pause(); // Dừng nhạc
          
          if (mounted) {
            showDialog(
              context: context,
              barrierDismissible: false, // Bắt buộc phải nhấn X mới tắt được
              builder: (context) => PremiumAdDialog(
                userId: user.uid,
                onDismiss: () {
                  _audioPlayerManager.player.play(); // Chạy lại nhạc khi tắt quảng cáo
                },
              ),
            );
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _imageAnimController.dispose();
    _audioPlayerManager.isNowPlayingOpen.value = false; // Đánh dấu là đã đóng trang phát nhạc
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final colorScheme = Theme.of(context).colorScheme;
    const delta = 64;
    final radius = (screenWidth - delta) / 2;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text('PLAYING FROM ALBUM', 
              style: TextStyle(fontSize: 10, letterSpacing: 1.5, color: colorScheme.onSurface.withOpacity(0.5))),
            Text(_song.album, 
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.more_horiz_rounded)),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.primary.withOpacity(0.2),
              colorScheme.surface,
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            Hero(
              tag: 'song_art_${_song.id}',
              child: RotationTransition(
                turns: Tween(begin: 0.0, end: 1.0).animate(_imageAnimController),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withOpacity(0.3),
                        blurRadius: 40,
                        spreadRadius: 5,
                      )
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(radius),
                    child: FadeInImage.assetNetwork(
                      placeholder: 'assets/apple-music-app-for-windows-icon.png',
                      image: _song.image,
                      width: screenWidth - delta,
                      height: screenWidth - delta,
                      fit: BoxFit.cover,
                      imageErrorBuilder: (context, error, stackTrace) => Image.asset(
                        'assets/apple-music-app-for-windows-icon.png',
                        width: screenWidth - delta,
                        height: screenWidth - delta,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                _song.title,
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_isPremium) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  border: Border.all(color: colorScheme.primary, width: 1.5),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'LOSSLESS',
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _song.artist,
                          style: TextStyle(fontSize: 18, color: colorScheme.primary, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.favorite_border_rounded, size: 28),
                    color: colorScheme.primary,
                  )
                ],
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: _progressbar(),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _mediaButtons(),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(icon: const Icon(Icons.share_rounded, size: 20), onPressed: () {}),
                const SizedBox(width: 40),
                IconButton(icon: const Icon(Icons.playlist_play_rounded, size: 28), onPressed: () {}),
              ],
            ),
            if (!_isPremium) const SizedBox(height: 20) else const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _mediaButtons() {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        IconButton(
          onPressed: () {
            setState(() {
              _audioPlayerManager.isSmartShuffle = !_audioPlayerManager.isSmartShuffle;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_audioPlayerManager.isSmartShuffle ? 'Đã bật Smart Shuffle (Giai điệu tương đồng)' : 'Đã tắt Smart Shuffle'))
            );
          },
          icon: Icon(_audioPlayerManager.isSmartShuffle ? Icons.auto_awesome_rounded : Icons.shuffle_rounded),
          color: _audioPlayerManager.isSmartShuffle ? Colors.amber : Colors.grey,
        ),
        MediaButtonControl(function: _setPrevSong, icon: Icons.skip_previous_rounded, color: colorScheme.onSurface, size: 42),
        _playButton(),
        MediaButtonControl(function: _setNextSong, icon: Icons.skip_next_rounded, color: colorScheme.onSurface, size: 42),
        MediaButtonControl(function: _setRepeatOption, icon: _repeatingIcon(), color: _getRepeatingIconColor(), size: 24),
      ],
    );
  }

  StreamBuilder<DurationState> _progressbar() {
    final colorScheme = Theme.of(context).colorScheme;
    return StreamBuilder<DurationState>(
      stream: _audioPlayerManager.durationState,
      builder: (context, snapshot) {
        final durationState = snapshot.data;
        final progress = durationState?.progress ?? Duration.zero;
        final total = durationState?.total ?? Duration.zero;

        return ProgressBar(
          progress: progress,
          total: total,
          onSeek: _audioPlayerManager.player.seek,
          barHeight: 6.0,
          baseBarColor: colorScheme.primary.withOpacity(0.1),
          progressBarColor: colorScheme.primary,
          thumbColor: colorScheme.primary,
          thumbRadius: 8,
          timeLabelTextStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.5), fontWeight: FontWeight.bold),
        );
      },
    );
  }

  StreamBuilder<PlayerState> _playButton() {
    final colorScheme = Theme.of(context).colorScheme;
    return StreamBuilder(
      stream: _audioPlayerManager.player.playerStateStream,
      builder: (context, snapshot) {
        final playState = snapshot.data;
        final processingSate = playState?.processingState;
        final playing = playState?.playing;
        
        if (processingSate == ProcessingState.loading || processingSate == ProcessingState.buffering) {
          return Container(
            padding: const EdgeInsets.all(16),
            child: const CircularProgressIndicator(),
          );
        }
        
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colorScheme.primary,
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: IconButton(
            onPressed: () {
              if (playing != true) {
                _audioPlayerManager.player.play();
                _imageAnimController.forward(from: _currentAnimationPosition);
                _imageAnimController.repeat();
              } else {
                _audioPlayerManager.player.pause();
                _imageAnimController.stop();
                _currentAnimationPosition = _imageAnimController.value;
              }
            },
            icon: Icon(playing == true ? Icons.pause_rounded : Icons.play_arrow_rounded),
            iconSize: 56,
            color: colorScheme.onPrimary,
          ),
        );
      },
    );
  }

  void _setShuffle(){
    setState(() {
      _isShuffle = !_isShuffle;
    });
  }

  Color? _getShuffleColor(){
    return _isShuffle ? Colors.deepPurple : Colors.grey;
  }

  IconData _repeatingIcon() {
    return switch(_loopMode){
      LoopMode.one => Icons.repeat_one,
      LoopMode.all => Icons.repeat_on,
      _ => Icons.repeat,
    };
  }

  Color? _getRepeatingIconColor(){
    return _loopMode == LoopMode.off ? Colors.grey : Colors.deepPurple;
  }

  void _setRepeatOption(){
    if(_loopMode == LoopMode.off){
      _loopMode = LoopMode.one;
    } else if(_loopMode == LoopMode.one){
      _loopMode = LoopMode.all;
    } else {
      _loopMode = LoopMode.off;
    }
    setState(() {
      _audioPlayerManager.player.setLoopMode(_loopMode);
    });
  }

  void _setNextSong (){
    if(_isShuffle){
      var random = Random();
      _selectedItemIndex = random.nextInt(widget.songs.length);
    } else if (_selectedItemIndex < widget.songs.length - 1){
      ++ _selectedItemIndex;
    } else if(_loopMode == LoopMode.all && _selectedItemIndex == widget.songs.length - 1){
      _selectedItemIndex = 0;
    }
    if(_selectedItemIndex > widget.songs.length){
      _selectedItemIndex = _selectedItemIndex % widget.songs.length;
    }
    final nextSong = widget.songs[_selectedItemIndex];

    // Đồng bộ index với manager
    _audioPlayerManager.currentIndex = _selectedItemIndex;
    _audioPlayerManager.updateSongUrl(nextSong.source, song: nextSong);

    setState(() {
      _song = nextSong;
    });
  }

  void _setPrevSong(){
    if(_isShuffle){
      var random = Random();
      _selectedItemIndex = random.nextInt(widget.songs.length);
    } else if(_selectedItemIndex > 0){
      -- _selectedItemIndex;
    } else if(_loopMode == LoopMode.all && _selectedItemIndex == 0){
      _selectedItemIndex = widget.songs.length - 1;
    }
    if(_selectedItemIndex < 0){
      _selectedItemIndex = (-1 * _selectedItemIndex) % widget.songs.length;
    }
    final nextSong = widget.songs[_selectedItemIndex];

    // Đồng bộ index với manager
    _audioPlayerManager.currentIndex = _selectedItemIndex;
    _audioPlayerManager.updateSongUrl(nextSong.source, song: nextSong);

    setState(() {
      _song = nextSong;
    });
  }
}

class MediaButtonControl extends StatefulWidget{
  const MediaButtonControl({
    super.key,
    required this.function,
    required this.icon,
    required this.color,
    required this.size,
  });
  final void Function()? function;
  final IconData icon;
  final double? size;
  final Color? color;

  @override
  State<StatefulWidget> createState() => _MediaButtonControlState();
}

class _MediaButtonControlState extends State<MediaButtonControl>{
  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: widget.function,
      icon: Icon(widget.icon),
      iconSize: widget.size,
      color: widget.color ?? Theme.of(context).colorScheme.primary,
    );
  }
}
