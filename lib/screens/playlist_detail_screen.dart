import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/audio_provider.dart';
import '../providers/library_provider.dart';
import '../services/download_service.dart';
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

  @override
  void initState() {
    super.initState();
    _localSongs = List.from(widget.songs);
    _currentTitle = widget.title;
  }

  void _renamePlaylist(BuildContext context, LibraryProvider libraryProvider) {
    final TextEditingController controller = TextEditingController(text: _currentTitle);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text('Rename Playlist', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: controller,
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
                if (controller.text.isNotEmpty && widget.playlistId != null) {
                  libraryProvider.renamePlaylist(widget.playlistId!, controller.text);
                  setState(() => _currentTitle = controller.text);
                }
                Navigator.pop(context);
              },
              child: const Text('SAVE', style: TextStyle(color: AppTheme.primary)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final audioProvider = context.watch<AudioProvider>();
    final libraryProvider = context.watch<LibraryProvider>();
    
    // For Liked Songs, we always stay synced. For Custom, we rely on _localSongs
    final displaySongs = widget.isLikedSongs ? libraryProvider.likedSongs : _localSongs;

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
              child: displaySongs.isEmpty
                  ? const Center(
                      child: Text(
                        'No songs here yet.',
                        style: TextStyle(color: Colors.white70, fontSize: 18),
                      ),
                    )
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${displaySongs.length} songs',
                                style: const TextStyle(color: Colors.white70, fontSize: 16),
                              ),
                              FloatingActionButton(
                                backgroundColor: AppTheme.primary,
                                onPressed: () {
                                  if (displaySongs.isNotEmpty) {
                                    audioProvider.playSong(displaySongs[0], newQueue: displaySongs);
                                  }
                                },
                                child: const Icon(Icons.play_arrow, color: Colors.black, size: 32),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: widget.isLikedSongs
                            // Liked Songs shouldn't be reordered, just standard list
                            ? ListView.builder(
                                padding: const EdgeInsets.only(bottom: 120),
                                itemCount: displaySongs.length,
                                itemBuilder: (context, index) => _buildSongTile(displaySongs[index], audioProvider, libraryProvider, displaySongs, index),
                              )
                            // Custom Playlists allow Reordering
                            : Theme(
                                data: Theme.of(context).copyWith(
                                  canvasColor: Colors.transparent,
                                ),
                                child: ReorderableListView.builder(
                                  padding: const EdgeInsets.only(bottom: 120),
                                  itemCount: displaySongs.length,
                                  onReorder: (oldIndex, newIndex) {
                                    setState(() {
                                      if (newIndex > oldIndex) {
                                        newIndex -= 1;
                                      }
                                      final item = _localSongs.removeAt(oldIndex);
                                      _localSongs.insert(newIndex, item);
                                    });
                                    if (widget.playlistId != null) {
                                      libraryProvider.replacePlaylistSongs(widget.playlistId!, _localSongs);
                                    }
                                    
                                    // Sync the audio queue if we are currently playing from this list
                                    if (audioProvider.currentSong != null) {
                                      final isPlayingThisList = _localSongs.any((s) => s['id'].toString() == audioProvider.currentSong['id'].toString());
                                      if (isPlayingThisList) {
                                        audioProvider.updateQueue(List.from(_localSongs));
                                      }
                                    }
                                  },
                                  itemBuilder: (context, index) {
                                    final song = displaySongs[index];
                                    return _buildSongTile(song, audioProvider, libraryProvider, displaySongs, index);
                                  },
                                ),
                              ),
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

  Widget _buildSongTile(dynamic song, AudioProvider audioProvider, LibraryProvider libraryProvider, List<dynamic> displaySongs, int index) {
    final isPlaying = audioProvider.currentSong?['id'] == song['id'];

    bool liked = libraryProvider.isLiked(song['id'].toString());

    return ListTile(
      key: ValueKey(song['id']),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!widget.isLikedSongs)
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.only(right: 12.0),
                child: Icon(Icons.drag_indicator, color: Colors.white30),
              ),
            ),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: CachedNetworkImage(
              imageUrl: song['image'] != null && (song['image'] as List).isNotEmpty
                  ? song['image'].last['url']
                  : '',
              width: 50,
              height: 50,
              fit: BoxFit.cover,
              errorWidget: (c, u, e) => const Icon(Icons.music_note, color: Colors.white54),
            ),
          ),
        ],
      ),
      title: Text(
        song['name'] ?? 'Unknown',
        style: TextStyle(
          color: isPlaying ? AppTheme.primary : Colors.white,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        song['primaryArtists'] ?? 'Unknown Artist',
        style: const TextStyle(color: Colors.white70),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white70),
            color: Colors.grey[900],
            onSelected: (value) {
              if (value == 'like') {
                libraryProvider.toggleLike(song);
              } else if (value == 'download') {
                if (libraryProvider.dbHelper != null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Downloading...')));
                  DownloadService.downloadSong(libraryProvider.dbHelper!, song, (p) {}, (s, m) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
                  });
                }
              } else if (value == 'remove') {
                if (widget.playlistId != null) {
                  libraryProvider.removeSongFromPlaylist(widget.playlistId!, song['id'].toString());
                  setState(() {
                    _localSongs.removeAt(index);
                  });
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
                      Text('Remove', style: TextStyle(color: Colors.redAccent)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      onTap: () {
        audioProvider.playSong(song, newQueue: displaySongs);
      },
    );
  }
}
