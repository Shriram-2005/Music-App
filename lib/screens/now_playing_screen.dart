import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:just_audio/just_audio.dart';
import 'package:translator/translator.dart';
import '../providers/library_provider.dart';
import '../providers/audio_provider.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/song_options_menu.dart';
import 'driving_mode_screen.dart';

class LrcLine {
  final Duration time;
  final String text;
  LrcLine(this.time, this.text);
}

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  bool _showLyrics = false;
  bool _isLoadingLyrics = false;
  bool _isFullScreenLyrics = false;
  bool _showTranslation = false;
  bool _isTranslating = false;
  String? _rawLyrics;
  List<LrcLine> _parsedLyrics = [];
  String? _lastSongId;
  final Map<int, String> _translatedLyrics = {};
  final GoogleTranslator _translator = GoogleTranslator();
  
  final ScrollController _lyricsScrollController = ScrollController();
  int _lastAutoScrollIndex = -1;


  @override
  void dispose() {
    _lyricsScrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final audioProvider = context.watch<AudioProvider>();
    final song = audioProvider.currentSong;
    if (song != null && song['id'].toString() != _lastSongId) {
      _lastSongId = song['id'].toString();
      _showLyrics = false;
      _rawLyrics = null;
      _parsedLyrics = [];
      _showTranslation = false;
      _translatedLyrics.clear();
      int? dur = int.tryParse(song['duration']?.toString() ?? '');
      _fetchLyrics(song['name'] ?? '', song['primaryArtists'] ?? '', duration: dur);
    }
  }

  Future<void> _fetchLyrics(String track, String artist, {int retryCount = 0, int? duration}) async {
    setState(() => _isLoadingLyrics = true);
    try {
      final lyrics = await ApiService.getSyncedLyrics(track, artist, duration).timeout(const Duration(seconds: 10));
      if (mounted) {
        if (lyrics != null) {
          final parsed = _parseLrc(lyrics);
          setState(() {
            _rawLyrics = lyrics;
            _parsedLyrics = parsed;
          });
        } else {
          _handleLyricsFailure(track, artist, retryCount);
        }
      }
    } catch (e) {
      if (mounted) {
        _handleLyricsFailure(track, artist, retryCount);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingLyrics = false);
      }
    }
  }

  Future<void> _translateLyrics() async {
    if (_parsedLyrics.isEmpty || _isTranslating) return;
    
    final settings = context.read<SettingsProvider>();
    final targetLang = settings.translationLanguage;
    
    setState(() {
      _showTranslation = true;
      _isTranslating = true;
    });

    try {
      for (int i = 0; i < _parsedLyrics.length; i++) {
        if (_parsedLyrics[i].text.trim().isEmpty) continue;
        if (_translatedLyrics.containsKey(i)) continue;
        
        final translation = await _translator.translate(_parsedLyrics[i].text, to: targetLang);
        if (mounted) {
          setState(() {
            _translatedLyrics[i] = translation.text;
          });
        }
      }
    } catch (e) {
      debugPrint('Translation error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isTranslating = false;
        });
      }
    }
  }

  void _handleLyricsFailure(String track, String artist, int retryCount) {
    if (retryCount < 1) {
      setState(() {
        _rawLyrics = "Loading failed. Retrying in 3s...";
        _parsedLyrics = [];
      });
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _lastSongId != null) {
          _fetchLyrics(track, artist, retryCount: retryCount + 1);
        }
      });
    } else {
      setState(() {
        _rawLyrics = "Lyrics not found.";
        _parsedLyrics = [];
      });
    }
  }

  List<LrcLine> _parseLrc(String lrc) {
    List<LrcLine> lines = [];
    final tagRegex = RegExp(r'\[(\d+):(\d{2})(?:\.(\d+))?\]');
    for (var line in lrc.split('\n')) {
      final tags = tagRegex.allMatches(line);
      if (tags.isNotEmpty) {
        final text = line.substring(tags.last.end).trim();
        for (var match in tags) {
          final m = int.parse(match.group(1)!);
          final s = int.parse(match.group(2)!);
          String msStr = match.group(3) ?? '000';
          if (msStr.length == 1) msStr += '00';
          else if (msStr.length == 2) msStr += '0';
          else if (msStr.length > 3) msStr = msStr.substring(0, 3);
          
          final ms = int.parse(msStr);
          lines.add(LrcLine(Duration(minutes: m, seconds: s, milliseconds: ms), text));
        }
      }
    }
    lines.sort((a, b) => a.time.compareTo(b.time));
    return lines;
  }

  @override
  Widget build(BuildContext context) {
    final audioProvider = context.watch<AudioProvider>();
    final libraryProvider = context.watch<LibraryProvider>();
    final currentSong = audioProvider.currentSong;

    if (currentSong == null) {
      return const Scaffold(body: Center(child: Text('No song playing')));
    }

    String imageUrl = '';
    final rawImg = currentSong['image'];
    if (rawImg is String) {
      imageUrl = rawImg;
    } else if (rawImg is List && rawImg.isNotEmpty) {
      try {
        final last = rawImg.last;
        if (last is Map && last['url'] != null) {
          imageUrl = last['url'].toString();
        } else if (last is String) {
          imageUrl = last;
        }
      } catch (_) {}
    }

    final isLiked = libraryProvider.isLiked(currentSong['id'].toString());
    final dominantColor = audioProvider.dominantColor ?? AppTheme.background;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, size: 32, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.queue_music, color: Colors.white),
            onPressed: () => _showUpNextSheet(context, audioProvider),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {
              if (currentSong != null) {
                showSongOptionsMenu(context, currentSong);
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background blurry image
          if (imageUrl.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: CachedNetworkImageProvider(imageUrl),
                  fit: BoxFit.cover,
                ),
              ),
            )
          else
            Container(color: Colors.black),
          // Blur filter
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    dominantColor.withOpacity(0.4),
                    Colors.black.withOpacity(0.8),
                    Colors.black,
                  ],
                ),
              ),
            ),
          ),
          // Content
          SafeArea(
            child: _isFullScreenLyrics 
              ? _buildFullScreenLyrics(context, audioProvider.player.positionStream)
              : _buildNormalView(context, audioProvider, libraryProvider, currentSong, imageUrl, isLiked),
          ),
        ],
      ),
    );
  }

  Widget _buildNormalView(BuildContext context, AudioProvider audioProvider, LibraryProvider libraryProvider, dynamic currentSong, String imageUrl, bool isLiked) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      physics: const BouncingScrollPhysics(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const SizedBox(height: 16),
          // Album Art
          Hero(
            tag: "album_art_${currentSong['id']}",
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.45,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          // Title & Artist
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentSong['name'] ?? 'Unknown',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentSong['primaryArtists'] ?? '',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.7),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      color: isLiked ? AppTheme.primary : Colors.white,
                    ),
                    onPressed: () {
                      libraryProvider.toggleLike(currentSong);
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Scrubber StreamBuilder
          StreamBuilder<Duration>(
            stream: audioProvider.player.positionStream,
            builder: (context, snapshot) {
              final position = snapshot.data ?? Duration.zero;
              final duration = audioProvider.player.duration ?? Duration.zero;
              return Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: Colors.white,
                      inactiveTrackColor: Colors.white.withOpacity(0.2),
                      thumbColor: Colors.white,
                      trackHeight: 4.0,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                    ),
                    child: Slider(
                      min: 0,
                      max: duration.inMilliseconds.toDouble(),
                      value: position.inMilliseconds.toDouble().clamp(0, duration.inMilliseconds.toDouble()),
                      onChanged: (value) {
                        audioProvider.seek(Duration(milliseconds: value.toInt()));
                      },
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      StreamBuilder<bool>(
                        stream: audioProvider.player.shuffleModeEnabledStream,
                        builder: (context, snapshot) {
                          final isShuffle = snapshot.data ?? false;
                          return IconButton(
                            icon: const Icon(Icons.shuffle, size: 20),
                            color: isShuffle ? AppTheme.primary : Colors.white54,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => audioProvider.toggleShuffle(),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDuration(position),
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                      ),
                      const Spacer(),
                      Text(
                        _formatDuration(duration),
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                      ),
                      const SizedBox(width: 8),
                      StreamBuilder<LoopMode>(
                        stream: audioProvider.player.loopModeStream,
                        builder: (context, snapshot) {
                          final loopMode = snapshot.data ?? LoopMode.off;
                          IconData icon = Icons.repeat;
                          Color color = Colors.white54;
                          if (loopMode == LoopMode.all) {
                            color = AppTheme.primary;
                          } else if (loopMode == LoopMode.one) {
                            icon = Icons.repeat_one;
                            color = AppTheme.primary;
                          }
                          return IconButton(
                            icon: Icon(icon, size: 20),
                            color: color,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => audioProvider.toggleRepeat(),
                          );
                        }
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous),
                iconSize: 42,
                color: Colors.white,
                onPressed: () => audioProvider.playPrevious(),
              ),
              IconButton(
                icon: const Icon(Icons.replay_10),
                iconSize: 36,
                color: Colors.white,
                onPressed: () => audioProvider.seekBackward(),
              ),
              StreamBuilder<bool>(
                stream: audioProvider.player.playingStream,
                builder: (context, snapshot) {
                  final isPlaying = snapshot.data ?? false;
                  return Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.primary,
                    ),
                    child: IconButton(
                      icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                      iconSize: 48,
                      color: Colors.black,
                      onPressed: () => audioProvider.togglePlayPause(),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.forward_10),
                iconSize: 36,
                color: Colors.white,
                onPressed: () => audioProvider.seekForward(),
              ),
              IconButton(
                icon: const Icon(Icons.skip_next),
                iconSize: 42,
                color: Colors.white,
                onPressed: () => audioProvider.playNext(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: StreamBuilder<Duration>(
              stream: audioProvider.player.bufferedPositionStream,
              builder: (context, snapshot) {
                final buffered = snapshot.data ?? Duration.zero;
                final quality = audioProvider.currentQuality;
                
                double mbConsumed = 0.0;
                if (quality.contains('320')) {
                  mbConsumed = (buffered.inSeconds * 40) / 1024;
                } else if (quality.contains('160')) {
                  mbConsumed = (buffered.inSeconds * 20) / 1024;
                } else if (quality.contains('96')) {
                  mbConsumed = (buffered.inSeconds * 12) / 1024;
                }
                
                final dataString = quality == 'Offline' ? '0.0' : mbConsumed.toStringAsFixed(1);
                return Text(
                  'Quality: $quality | Data: ~$dataString MB',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                );
              },
            ),
          ),
          const SizedBox(height: 32),
          // Lyrics Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Lyrics',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.translate,
                            color: _showTranslation ? AppTheme.primary : Colors.white54,
                          ),
                          onPressed: () {
                            if (!_showTranslation) {
                              _translateLyrics();
                            } else {
                              setState(() {
                                _showTranslation = false;
                              });
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.white54),
                          onPressed: () {
                            if (currentSong != null) {
                              _fetchLyrics(currentSong['name'] ?? '', currentSong['primaryArtists'] ?? '');
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.open_in_full, color: Colors.white),
                          onPressed: () {
                            setState(() {
                              _isFullScreenLyrics = true;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 300,
                  child: _buildLyricsView(context, audioProvider.player.positionStream),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildFullScreenLyrics(BuildContext context, Stream<Duration> positionStream) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Lyrics',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close_fullscreen, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _isFullScreenLyrics = false;
                  });
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: _buildLyricsView(context, positionStream),
        ),
      ],
    );
  }

  Widget _buildLyricsView(BuildContext context, Stream<Duration> positionStream) {
    if (_isLoadingLyrics) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }
    if (_parsedLyrics.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          child: Text(
            _rawLyrics ?? "Tap here or wait for lyrics...",
            style: const TextStyle(color: Colors.white, fontSize: 18, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return StreamBuilder<Duration>(
      stream: positionStream,
      builder: (context, snapshot) {
        // Add 500ms offset to the stream position to highlight earlier
        final position = (snapshot.data ?? Duration.zero) + const Duration(milliseconds: 500);
        
        int currentIndex = -1;
        for (int i = 0; i < _parsedLyrics.length; i++) {
          if (_parsedLyrics[i].time <= position) {
            currentIndex = i;
          } else {
            break;
          }
        }

        if (currentIndex != -1 && currentIndex != _lastAutoScrollIndex) {
          _lastAutoScrollIndex = currentIndex;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_lyricsScrollController.hasClients) {
              // Smoothly scroll to the approximate position based on index
              final targetOffset = currentIndex * (_isFullScreenLyrics ? 60.0 : 50.0);
              _lyricsScrollController.animateTo(
                targetOffset,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
          });
        }

        return ListView.builder(
          controller: _lyricsScrollController,
          physics: const BouncingScrollPhysics(),
          itemCount: _parsedLyrics.length,
          itemBuilder: (context, index) {
            final isCurrent = index == currentIndex;
            return InkWell(
              onTap: () {
                final audioProvider = context.read<AudioProvider>();
                audioProvider.player.seek(_parsedLyrics[index].time);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Column(
                  children: [
                    Text(
                      _parsedLyrics[index].text,
                      style: TextStyle(
                        color: isCurrent ? AppTheme.primary : Colors.white.withOpacity(0.5),
                        fontSize: isCurrent ? (_isFullScreenLyrics ? 28 : 24) : (_isFullScreenLyrics ? 20 : 18),
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_showTranslation && _translatedLyrics.containsKey(index)) ...[
                      const SizedBox(height: 4),
                      Text(
                        _translatedLyrics[index]!,
                        style: TextStyle(
                          color: isCurrent ? Colors.amberAccent : Colors.white38,
                          fontSize: isCurrent ? (_isFullScreenLyrics ? 18 : 16) : (_isFullScreenLyrics ? 14 : 12),
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }


  void _showUpNextSheet(BuildContext context, AudioProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            return Consumer<AudioProvider>(
              builder: (context, audioProvider, child) {
                final queue = audioProvider.queue;
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const Text('Up Next', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ReorderableListView.builder(
                        scrollController: scrollController,
                        itemCount: queue.length,
                        onReorder: (oldIndex, newIndex) {
                          audioProvider.reorderQueue(oldIndex, newIndex);
                        },
                        itemBuilder: (context, index) {
                          final song = queue[index];
                          final isPlaying = index == audioProvider.currentIndex;
                          return ListTile(
                            key: ValueKey('${song['id']}_$index'),
                            leading: Icon(
                              isPlaying ? Icons.equalizer : Icons.music_note,
                              color: isPlaying ? AppTheme.primary : Colors.white54,
                            ),
                            title: Text(
                              song['name'] ?? 'Unknown',
                              style: TextStyle(
                                color: isPlaying ? AppTheme.primary : Colors.white,
                                fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              song['primaryArtists'] ?? '',
                              style: const TextStyle(color: Colors.white54),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: const Icon(Icons.drag_handle, color: Colors.white24),
                            onTap: () {
                              audioProvider.playSong(song, newQueue: queue);
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}
