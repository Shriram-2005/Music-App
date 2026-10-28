import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/audio_provider.dart';
import '../providers/library_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/player_bar.dart';

class PlaylistDetailScreen extends StatefulWidget {
  final String title;
  final List<dynamic> songs;
  final bool isLikedSongs;
  final String? playlistId;

  final VoidCallback? onBack;

  const PlaylistDetailScreen({
    super.key,
    required this.title,
    required this.songs,
    this.isLikedSongs = false,
    this.playlistId,
    this.onBack,
  });

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  late List<dynamic> _localSongs;
  late String _currentTitle;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<dynamic> _onlineResults = [];
  bool _isSearchingOnline = false;
  Timer? _onlineDebounce;

  @override
  void initState() {
    super.initState();
    _localSongs = List.from(widget.songs);
    _currentTitle = widget.title;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _onlineDebounce?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PlaylistDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.title != oldWidget.title) {
      _currentTitle = widget.title;
    }
    if (widget.songs != oldWidget.songs) {
      _localSongs = List.from(widget.songs);
    }
  }

  void _renamePlaylist(BuildContext context, LibraryProvider libraryProvider) {
    final TextEditingController controller = TextEditingController(text: _currentTitle);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text('Rename Playlist', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Playlist name',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
              enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
              focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.primary)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isNotEmpty && widget.playlistId != null) {
                  libraryProvider.renamePlaylist(widget.playlistId!, text);
                  setState(() => _currentTitle = text);
                }
                Navigator.pop(context);
              },
              child: const Text('SAVE', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  String _extractSongImage(dynamic song) {
    if (song == null) return '';
    final image = song['image'];
    if (image is String) return image;
    if (image is List && image.isNotEmpty) {
      try {
        final last = image.last;
        if (last is Map && last['url'] != null) {
          return last['url'].toString();
        } else if (last is String) {
          return last;
        }
        final first = image[0];
        if (first is Map && first['url'] != null) {
          return first['url'].toString();
        }
      } catch (_) {}
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final audioProvider = context.watch<AudioProvider>();
    final libraryProvider = context.watch<LibraryProvider>();
    
    // For Liked Songs, always stay synced with libraryProvider.likedSongs
    // For custom playlists, reactively look up from libraryProvider.playlists if available
    List<dynamic> displaySongs;
    if (widget.isLikedSongs) {
      displaySongs = libraryProvider.likedSongs;
    } else if (widget.playlistId != null) {
      final matches = libraryProvider.playlists.where((p) => p['id']?.toString() == widget.playlistId);
      if (matches.isNotEmpty && matches.first['songs'] is List) {
        displaySongs = matches.first['songs'] as List<dynamic>;
      } else {
        displaySongs = _localSongs;
      }
    } else {
      displaySongs = _localSongs;
    }

    final queueTag = widget.isLikedSongs ? 'liked_songs' : 'playlist_${widget.playlistId}';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(_currentTitle, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (widget.onBack != null) {
              widget.onBack!();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          if (!widget.isLikedSongs && widget.playlistId != null)
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white),
              onPressed: () => _renamePlaylist(context, libraryProvider),
            ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  widget.isLikedSongs ? Colors.deepPurple.shade900 : AppTheme.primary.withOpacity(0.5),
                  AppTheme.background,
                ],
                stops: const [0.0, 0.4],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Search Bar inside Playlist
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 8.0),
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Search songs in this playlist...',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14),
                          prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 20),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    _onlineDebounce?.cancel();
                                    setState(() {
                                      _searchQuery = '';
                                      _onlineResults = [];
                                      _isSearchingOnline = false;
                                    });
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onChanged: (val) {
                          final trimmed = val.trim();
                          setState(() {
                            _searchQuery = trimmed;
                          });
                          _onlineDebounce?.cancel();
                          if (_searchQuery.isNotEmpty) {
                            _onlineDebounce = Timer(const Duration(milliseconds: 500), () async {
                              if (!mounted) return;
                              setState(() => _isSearchingOnline = true);
                              final results = await ApiService.searchSongs(_searchQuery);
                              if (mounted) {
                                setState(() {
                                  _onlineResults = results;
                                  _isSearchingOnline = false;
                                });
                              }
                            });
                          } else {
                            setState(() {
                              _onlineResults = [];
                              _isSearchingOnline = false;
                            });
                          }
                        },
                      ),
                    ),
                  ),

                  // Content Area: Search Mode vs Normal Playlist View
                  Expanded(
                    child: _searchQuery.isNotEmpty
                        ? _buildSearchModeView(displaySongs, audioProvider, libraryProvider, queueTag)
                        : _buildNormalPlaylistView(displaySongs, audioProvider, libraryProvider, queueTag),
                  ),
                ],
              ),
            ),
          ),
          if (audioProvider.currentSong != null)
            const Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: PlayerBar(),
            ),
        ],
      ),
    );
  }

  Widget _buildNormalPlaylistView(
    List<dynamic> displaySongs,
    AudioProvider audioProvider,
    LibraryProvider libraryProvider,
    String queueTag,
  ) {
    if (displaySongs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.isLikedSongs ? Icons.favorite_border : Icons.queue_music, size: 64, color: Colors.white30),
            const SizedBox(height: 16),
            const Text(
              'No songs here yet.',
              style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Use the search bar above to find and add songs!',
              style: TextStyle(color: Colors.white38, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${displaySongs.length} ${displaySongs.length == 1 ? 'song' : 'songs'}',
                style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500),
              ),
              Row(
                children: [
                  // Shuffle Play
                  IconButton(
                    icon: const Icon(Icons.shuffle, color: Colors.white, size: 28),
                    tooltip: 'Shuffle Play',
                    onPressed: () {
                      if (displaySongs.isNotEmpty) {
                        final shuffled = List<dynamic>.from(displaySongs)..shuffle();
                        audioProvider.playSong(
                          shuffled[0], 
                          newQueue: shuffled, 
                          initialIndex: 0,
                          queueTag: queueTag,
                        );
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  // Play All
                  FloatingActionButton(
                    backgroundColor: AppTheme.primary,
                    onPressed: () {
                      if (displaySongs.isNotEmpty) {
                        audioProvider.playSong(
                          displaySongs[0], 
                          newQueue: displaySongs, 
                          initialIndex: 0,
                          queueTag: queueTag,
                        );
                      }
                    },
                    child: const Icon(Icons.play_arrow, color: Colors.black, size: 32),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: widget.isLikedSongs
            // Liked Songs - Standard List
            ? ListView.builder(
                padding: const EdgeInsets.only(bottom: 120),
                itemCount: displaySongs.length,
                itemBuilder: (context, index) => _buildSongTile(
                  displaySongs[index], 
                  audioProvider, 
                  libraryProvider, 
                  displaySongs, 
                  index,
                  queueTag,
                  isReorderable: false,
                ),
              )
            // Custom Playlists - Reorderable List
            : Theme(
                data: Theme.of(context).copyWith(
                  canvasColor: Colors.transparent,
                ),
                child: ReorderableListView.builder(
                  padding: const EdgeInsets.only(bottom: 120),
                  itemCount: displaySongs.length,
                  onReorder: (oldIndex, newIndex) {
                    final currentList = List<dynamic>.from(displaySongs);
                    if (newIndex > oldIndex) {
                      newIndex -= 1;
                    }
                    final item = currentList.removeAt(oldIndex);
                    currentList.insert(newIndex, item);
                    setState(() {
                      _localSongs = currentList;
                    });
                    if (widget.playlistId != null) {
                      libraryProvider.replacePlaylistSongs(widget.playlistId!, currentList);
                    }
                    
                    // Sync active queue only if currently playing from this playlist
                    if (audioProvider.queueTag == queueTag) {
                      audioProvider.updateQueue(List.from(currentList), queueTag: queueTag);
                    }
                  },
                  itemBuilder: (context, index) {
                    final song = displaySongs[index];
                    return _buildSongTile(
                      song, 
                      audioProvider, 
                      libraryProvider, 
                      displaySongs, 
                      index,
                      queueTag,
                      isReorderable: true,
                    );
                  },
                ),
              ),
        ),
      ],
    );
  }

  Widget _buildSearchModeView(
    List<dynamic> displaySongs,
    AudioProvider audioProvider,
    LibraryProvider libraryProvider,
    String queueTag,
  ) {
    final qLower = _searchQuery.toLowerCase();
    final localMatches = displaySongs.where((song) {
      final name = (song['name']?.toString() ?? '').toLowerCase();
      final artist = (song['primaryArtists']?.toString() ?? '').toLowerCase();
      return name.contains(qLower) || artist.contains(qLower);
    }).toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 120),
      children: [
        // Section 1: In this playlist
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              const Icon(Icons.playlist_play, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'IN THIS PLAYLIST (${localMatches.length})',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ),
        if (localMatches.isNotEmpty)
          ...localMatches.asMap().entries.map((entry) {
            return _buildSongTile(
              entry.value, 
              audioProvider, 
              libraryProvider, 
              localMatches, 
              entry.key, 
              queueTag,
              isReorderable: false,
            );
          })
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              'No matching songs found in this playlist.',
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
            ),
          ),

        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Divider(color: Colors.white12, height: 32),
        ),

        // Section 2: Online Search Results to Add
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: const [
              Icon(Icons.public, color: AppTheme.primary, size: 18),
              SizedBox(width: 8),
              Text(
                'SEARCH ONLINE TO ADD',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ),

        if (_isSearchingOnline)
          const Padding(
            padding: EdgeInsets.all(32.0),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_onlineResults.isNotEmpty)
          ..._onlineResults.map((song) {
            final songId = song['id']?.toString() ?? '';
            final inPlaylist = displaySongs.any((s) => s['id']?.toString() == songId);
            final imageUrl = _extractSongImage(song);

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          width: 48,
                          height: 48,
                          color: Colors.grey[850],
                          child: const Icon(Icons.music_note, color: Colors.white54),
                        ),
                      )
                    : Container(
                        width: 48,
                        height: 48,
                        color: Colors.grey[850],
                        child: const Icon(Icons.music_note, color: Colors.white54),
                      ),
              ),
              title: Text(
                song['name'] ?? 'Unknown',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                song['primaryArtists'] ?? 'Unknown Artist',
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: inPlaylist
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.check, color: AppTheme.primary, size: 16),
                          SizedBox(width: 4),
                          Text(
                            'Added',
                            style: TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    )
                  : ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      onPressed: () async {
                        if (widget.isLikedSongs) {
                          await libraryProvider.toggleLike(song);
                        } else if (widget.playlistId != null) {
                          await libraryProvider.addSongToPlaylist(widget.playlistId!, song);
                        }
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Added "${song['name']}" to $_currentTitle'),
                            backgroundColor: Colors.grey[900],
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
              onTap: () {
                audioProvider.playSong(song, newQueue: _onlineResults);
              },
            );
          })
        else
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: Text(
                'No online songs found for "$_searchQuery"',
                style: TextStyle(color: Colors.white.withOpacity(0.5)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSongTile(
    dynamic song, 
    AudioProvider audioProvider, 
    LibraryProvider libraryProvider, 
    List<dynamic> displaySongs, 
    int index,
    String queueTag, {
    bool isReorderable = true,
  }) {
    final songId = song['id']?.toString() ?? '';
    final isPlaying = audioProvider.currentSong?['id']?.toString() == songId;
    final liked = libraryProvider.isLiked(songId);
    final imageUrl = _extractSongImage(song);

    return ListTile(
      key: ValueKey('pl_song_${widget.playlistId ?? 'liked'}_${songId}_$index'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!widget.isLikedSongs && isReorderable)
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.only(right: 12.0),
                child: Icon(Icons.drag_indicator, color: Colors.white30),
              ),
            ),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    errorWidget: (c, u, e) => Container(
                      width: 50,
                      height: 50,
                      color: Colors.grey[850],
                      child: const Icon(Icons.music_note, color: Colors.white54),
                    ),
                  )
                : Container(
                    width: 50,
                    height: 50,
                    color: Colors.grey[850],
                    child: const Icon(Icons.music_note, color: Colors.white54),
                  ),
          ),
        ],
      ),
      title: Text(
        song['name'] ?? 'Unknown',
        style: TextStyle(
          color: isPlaying ? AppTheme.primary : Colors.white,
          fontWeight: isPlaying ? FontWeight.bold : FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        song['primaryArtists'] ?? 'Unknown Artist',
        style: TextStyle(color: isPlaying ? AppTheme.primary.withOpacity(0.8) : Colors.white70),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isPlaying)
            const Padding(
              padding: EdgeInsets.only(right: 8.0),
              child: Icon(Icons.equalizer, color: AppTheme.primary, size: 20),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white70),
            color: Colors.grey[900],
            onSelected: (value) async {
              if (value == 'like') {
                libraryProvider.toggleLike(song);
              } else if (value == 'download') {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Downloading...')));
                final success = await libraryProvider.downloadSong(song);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(success ? 'Downloaded "${song['name'] ?? 'Song'}"' : 'Download failed')),
                  );
                }
              } else if (value == 'remove') {
                if (widget.playlistId != null) {
                  await libraryProvider.removeSongFromPlaylist(widget.playlistId!, songId);
                  setState(() {
                    _localSongs = List<dynamic>.from(displaySongs)..removeWhere((s) => s['id']?.toString() == songId);
                  });
                  if (audioProvider.queueTag == queueTag) {
                    audioProvider.updateQueue(List.from(_localSongs), queueTag: queueTag);
                  }
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Removed from $_currentTitle')),
                    );
                  }
                }
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'like',
                child: Row(
                  children: [
                    Icon(liked ? Icons.favorite : Icons.favorite_border, color: liked ? AppTheme.primary : Colors.white),
                    const SizedBox(width: 8),
                    Text(liked ? 'Unlike' : 'Like', style: const TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'download',
                child: Row(
                  children: [
                    Icon(Icons.download, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Download', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              if (!widget.isLikedSongs)
                const PopupMenuItem<String>(
                  value: 'remove',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: Colors.redAccent),
                      SizedBox(width: 8),
                      Text('Remove from Playlist', style: TextStyle(color: Colors.redAccent)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      onTap: () {
        audioProvider.playSong(
          song, 
          newQueue: displaySongs, 
          initialIndex: index,
          queueTag: queueTag,
        );
      },
    );
  }
}
