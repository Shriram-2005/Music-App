import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/db_helper.dart';

class AudioProvider extends ChangeNotifier {
  late final AudioPlayer _player;
  late final AudioPlayer _playerB;
  DbHelper? _dbHelper;
  String? _userId;

  List<dynamic> _queue = [];
  int _currentIndex = 0;
  bool _isLoading = false;
  String _currentQuality = '320 kbps';
  
  ConcatenatingAudioSource? _playlist;
  bool _isPreloading = false;
  
  Color? _dominantColor;
  
  Timer? _sleepTimer;
  DateTime? _sleepTimerEndTime;
  Timer? _fadeTimer;

  AudioPlayer get player => _player;
  DateTime? get sleepTimerEndTime => _sleepTimerEndTime;
  List<dynamic> get queue => _queue;
  int get currentIndex => _currentIndex;
  bool get isLoading => _isLoading;
  String get currentQuality => _currentQuality;
  Color? get dominantColor => _dominantColor;

  dynamic get currentSong => (_currentIndex >= 0 && _currentIndex < _queue.length) 
      ? _queue[_currentIndex] 
      : null;

  AudioProvider(this._userId) {
    _player = AudioPlayer();
    _playerB = AudioPlayer();
    
    if (_userId != null) {
      _dbHelper = DbHelper(userId: _userId!);
    }

    _init();
    
    _player.currentIndexStream.listen((index) {
      if (index != null && index > 0 && _playlist != null) {
        // Advanced to preloaded song (e.g. from Lock Screen Next button or auto-play)
        if (_currentIndex + 1 < _queue.length) {
          _currentIndex++;
          notifyListeners();
          _preloadNextSong();
        }
      }
    });
    
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (_player.loopMode == LoopMode.one) {
          seek(Duration.zero);
          _player.play();
        } else if (_playlist == null || _playlist!.length <= 1) {
          // Fallback if preloading failed
          playNext();
        }
      }
      notifyListeners();
    });
  }

  void updateUser(String? userId) {
    _userId = userId;
    if (_userId != null) {
      _dbHelper = DbHelper(userId: _userId!);
    } else {
      _dbHelper = null;
    }
    notifyListeners();
  }

  String _getBestAudioUrl(List<dynamic>? downloadUrls) {
    if (downloadUrls == null || downloadUrls.isEmpty) return '';
    try {
      final url = downloadUrls[0]['url'];
      return url?.toString() ?? '';
    } catch (e) {
      return '';
    }
  }

  String _getHighResImage(List<dynamic>? imageUrls) {
    if (imageUrls == null || imageUrls.isEmpty) return '';
    try {
      final url = imageUrls[0]['url'];
      return url?.toString() ?? '';
    } catch (e) {
      print('Error parsing metadata: $e');
      return '';
    }
  }

  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedSong = prefs.getString('saved_current_song');
      if (savedSong != null) {
        final song = jsonDecode(savedSong);
        _queue = [song];
        _currentIndex = 0;
        final artUrl = _getHighResImage(song['image']);
        _updateDominantColor(artUrl);
        notifyListeners();
        
        // Prepare the player but do not play
        final audioUrl = await _getAudioUrlForSong(song);
        if (audioUrl != null && audioUrl.isNotEmpty) {
          final mediaItem = MediaItem(
            id: song['id'].toString(),
            album: song['album']?['name']?.toString() ?? '',
            title: song['name']?.toString() ?? 'Unknown',
            artist: song['primaryArtists']?.toString() ?? 'Unknown',
            artUri: artUrl.isNotEmpty ? Uri.parse(artUrl) : null,
          );
          AudioSource source = AudioSource.uri(Uri.parse(audioUrl), tag: mediaItem);
          _playlist = ConcatenatingAudioSource(children: [source]);
          await _player.setAudioSource(_playlist!, initialIndex: 0);
        }
      }
    } catch (e) {
      print('Error loading saved song: $e');
    }
  }

  Future<void> playSong(dynamic song, {List<dynamic>? newQueue}) async {
    if (newQueue != null && newQueue.isNotEmpty) {
      _queue = newQueue;
      _currentIndex = _queue.indexWhere((s) => s['id'] == song['id']);
      if (_currentIndex == -1) _currentIndex = 0;
    } else if (newQueue == null && _queue.isEmpty) {
      _queue = [song];
      _currentIndex = 0;
    } else if (newQueue == null) {
      _currentIndex = _queue.indexWhere((s) => s['id'] == song['id']);
      if (_currentIndex == -1) {
         _queue = [song];
         _currentIndex = 0;
      }
    }

    await _playCurrentIndex();
  }

  void updateQueue(List<dynamic> newQueue) {
    if (_queue.isEmpty || _currentIndex < 0 || _currentIndex >= _queue.length) return;
    
    final playingSongId = _queue[_currentIndex]['id'].toString();
    _queue = newQueue;
    
    final newIndex = _queue.indexWhere((s) => s['id'].toString() == playingSongId);
    if (newIndex != -1) {
      _currentIndex = newIndex;
      _rebuildPreload();
    }
    notifyListeners();
  }

  void reorderQueue(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final item = _queue.removeAt(oldIndex);
    _queue.insert(newIndex, item);

    // Find new currentIndex
    if (oldIndex == _currentIndex) {
      _currentIndex = newIndex;
    } else if (oldIndex < _currentIndex && newIndex >= _currentIndex) {
      _currentIndex -= 1;
    } else if (oldIndex > _currentIndex && newIndex <= _currentIndex) {
      _currentIndex += 1;
    }
    
    _rebuildPreload();
    notifyListeners();
  }

  Future<void> _rebuildPreload() async {
    if (_playlist != null && _playlist!.length > 1) {
      await _playlist!.removeAt(1);
    }
    _isPreloading = false;
    _preloadNextSong();
  }

  Future<String?> _getAudioUrlForSong(dynamic song) async {
    final songId = song['id'].toString();
    String? localPath;
    if (_dbHelper != null) {
      localPath = await _dbHelper!.getDownloadPath(songId);
    }
    
    if (localPath != null && await File(localPath).exists()) {
        return 'file://$localPath';
    } else {
        return await ApiService.getAudioUrl(songId);
    }
  }

  Future<void> _playCurrentIndex() async {
    if (_currentIndex < 0 || _currentIndex >= _queue.length) return;
    
    _isLoading = true;
    notifyListeners();

    try {
      final song = _queue[_currentIndex];
      final songId = song['id'].toString();

      final audioUrl = await _getAudioUrlForSong(song);
      if (audioUrl == null || audioUrl.isEmpty) {
        print('Audio URL is empty! Cannot play.');
        return;
      }

      if (audioUrl.startsWith('file://')) {
        _currentQuality = 'Offline';
      } else if (audioUrl.contains('_320')) {
        _currentQuality = '320 kbps';
      } else if (audioUrl.contains('_160')) {
        _currentQuality = '160 kbps';
      } else if (audioUrl.contains('_96')) {
        _currentQuality = '96 kbps';
      } else {
        _currentQuality = 'Stream';
      }

      final artUrl = _getHighResImage(song['image']);
      _updateDominantColor(artUrl);
      
      final mediaItem = MediaItem(
        id: song['id'].toString(),
        album: song['album']?['name']?.toString() ?? '',
        title: song['name']?.toString() ?? 'Unknown',
        artist: song['primaryArtists']?.toString() ?? 'Unknown',
        artUri: artUrl.isNotEmpty ? Uri.parse(artUrl) : null,
      );

      AudioSource source = AudioSource.uri(Uri.parse(audioUrl), tag: mediaItem);

      _playlist = ConcatenatingAudioSource(children: [source]);
      await _player.setAudioSource(_playlist!, initialIndex: 0);
      await _player.setVolume(1.0);
      await _player.play();
      
      _preloadNextSong();
      
      if (song != null && _dbHelper != null) {
        _dbHelper!.addRecentlyPlayed(song);
      }
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_current_song', jsonEncode(song));
      
    } catch (e) {
      print('Error playing audio: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _updateDominantColor(String imageUrl) async {
    if (imageUrl.isEmpty) {
      _dominantColor = null;
      notifyListeners();
      return;
    }
    try {
      final palette = await PaletteGenerator.fromImageProvider(NetworkImage(imageUrl));
      _dominantColor = palette.dominantColor?.color ?? palette.mutedColor?.color;
      notifyListeners();
    } catch (e) {
      _dominantColor = null;
      notifyListeners();
    }
  }

  Future<void> _preloadNextSong() async {
    if (_isPreloading) return;
    if (_currentIndex + 1 >= _queue.length) return;
    
    _isPreloading = true;
    try {
      final nextSong = _queue[_currentIndex + 1];
      final songId = nextSong['id'].toString();

      String? audioUrl;
      String? localPath;
      if (_dbHelper != null) {
        localPath = await _dbHelper!.getDownloadPath(songId);
      }
      
      if (localPath != null && await _dbHelper!.getDownloadPath(songId).then((_) => true)) {
          audioUrl = 'file://$localPath';
      } else {
          audioUrl = await ApiService.getAudioUrl(songId);
      }
      
      if (audioUrl.isNotEmpty && _playlist != null) {
        final artUrl = _getHighResImage(nextSong['image']);
        final mediaItem = MediaItem(
          id: nextSong['id'].toString(),
          album: nextSong['album']?['name']?.toString() ?? '',
          title: nextSong['name']?.toString() ?? 'Unknown',
          artist: nextSong['primaryArtists']?.toString() ?? 'Unknown',
          artUri: artUrl.isNotEmpty ? Uri.parse(artUrl) : null,
        );
        AudioSource nextSource = AudioSource.uri(Uri.parse(audioUrl), tag: mediaItem);
        await _playlist!.add(nextSource);
      }
    } catch (e) {
      print('Failed to preload next song: $e');
    } finally {
      _isPreloading = false;
    }
  }

  Future<void> smoothPause() async {
    _fadeTimer?.cancel();
    double vol = _player.volume;
    _fadeTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      vol -= 0.1;
      if (vol <= 0.0) {
        _player.setVolume(0.0);
        _player.pause();
        timer.cancel();
      } else {
        _player.setVolume(vol);
      }
    });
  }

  Future<void> smoothPlay() async {
    _fadeTimer?.cancel();
    await _player.play();
    double vol = _player.volume;
    if (vol == 0.0) vol = 0.1;
    _fadeTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      vol += 0.1;
      if (vol >= 1.0) {
        _player.setVolume(1.0);
        timer.cancel();
      } else {
        _player.setVolume(vol);
      }
    });
  }

  void togglePlayPause() {
    if (_player.playing) {
      smoothPause();
    } else {
      smoothPlay();
    }
  }

  void startSleepTimer(Duration duration) {
    _sleepTimer?.cancel();
    _sleepTimerEndTime = DateTime.now().add(duration);
    _sleepTimer = Timer(duration, () {
      smoothPause();
      _sleepTimerEndTime = null;
      notifyListeners();
    });
    notifyListeners();
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepTimerEndTime = null;
    notifyListeners();
  }

  Future<void> playNext() async {
    final prefs = await SharedPreferences.getInstance();
    final bool crossfade = prefs.getBool('crossfadeEnabled') ?? false;
    final int duration = prefs.getInt('crossfadeDuration') ?? 3;
    
    if (crossfade && _player.playing) {
      await _crossfadeToNext(duration);
    } else {
      _currentIndex++;
      if (_currentIndex >= _queue.length) _currentIndex = 0;
      await _playCurrentIndex();
    }
  }

  Future<void> _crossfadeToNext(int durationSeconds) async {
    _currentIndex++;
    if (_currentIndex >= _queue.length) _currentIndex = 0;
    
    // Copy current state to Player B to fade out
    try {
      final currentPos = _player.position;
      final currentSong = _queue[_currentIndex - 1 >= 0 ? _currentIndex - 1 : _queue.length - 1];
      final currentUrl = await _getAudioUrlForSong(currentSong);
      if (currentUrl != null) {
        await _playerB.setUrl(currentUrl);
        await _playerB.seek(currentPos);
        _playerB.setVolume(1.0);
        _playerB.play();
      }
    } catch (e) {
      print('PlayerB crossfade error: $e');
    }

    // Instantly advance Player A to next song with 0 volume
    _player.setVolume(0.0);
    _playCurrentIndex();

    // Crossfade loop
    final steps = 20;
    final stepMs = (durationSeconds * 1000) ~/ steps;
    for (int i = 1; i <= steps; i++) {
      await Future.delayed(Duration(milliseconds: stepMs));
      _playerB.setVolume(1.0 - (i / steps));
      _player.setVolume(i / steps);
    }
    
    _playerB.stop();
  }

  Future<void> playPrevious() async {
    if (_queue.isEmpty) return;
    _currentIndex = (_currentIndex - 1) % _queue.length;
    if (_currentIndex < 0) _currentIndex = _queue.length - 1;
    _playCurrentIndex();
  }

  void seek(Duration position) {
    _player.seek(position);
  }

  void seekForward() {
    final newPosition = _player.position + const Duration(seconds: 10);
    final duration = _player.duration ?? Duration.zero;
    if (newPosition < duration) {
      _player.seek(newPosition);
    } else {
      _player.seek(duration);
    }
  }

  void seekBackward() {
    final newPosition = _player.position - const Duration(seconds: 10);
    if (newPosition > Duration.zero) {
      _player.seek(newPosition);
    } else {
      _player.seek(Duration.zero);
    }
  }

  void toggleShuffle() async {
    await _player.setShuffleModeEnabled(!_player.shuffleModeEnabled);
    if (_player.shuffleModeEnabled) {
      await _player.shuffle();
    }
  }

  void toggleRepeat() async {
    if (_player.loopMode == LoopMode.off) {
      await _player.setLoopMode(LoopMode.all);
    } else if (_player.loopMode == LoopMode.all) {
      await _player.setLoopMode(LoopMode.one);
    } else {
      await _player.setLoopMode(LoopMode.off);
    }
  }
}
