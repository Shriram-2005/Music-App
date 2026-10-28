import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/library_provider.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'playlist_detail_screen.dart';
import 'downloaded_songs_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  // Navigation State
  bool _showLikedSongs = false;
  String? _selectedPlaylistId;
  String? _selectedPlaylistName;
  List<dynamic> _selectedPlaylistSongs = [];

  void _clearSelection() {
    setState(() {
      _showLikedSongs = false;
      _selectedPlaylistId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final libraryProvider = context.watch<LibraryProvider>();
    final likedCount = libraryProvider.likedSongs.length;
    final playlists = libraryProvider.playlists;

    return PopScope(
      canPop: !_showLikedSongs && _selectedPlaylistId == null,
      onPopInvoked: (didPop) {
        if (!didPop) {
          _clearSelection();
        }
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _buildCurrentView(context, libraryProvider, likedCount, playlists),
      ),
    );
  }

  Widget _buildCurrentView(
    BuildContext context, 
    LibraryProvider libraryProvider, 
    int likedCount, 
    List<Map<String, dynamic>> playlists
  ) {
    if (_showLikedSongs) {
      return PlaylistDetailScreen(
        key: const ValueKey('liked_songs_view'),
        title: 'Liked Songs',
        songs: libraryProvider.likedSongs,
        isLikedSongs: true,
        onBack: _clearSelection,
      );
    }

    if (_selectedPlaylistId != null) {
      final matches = playlists.where((p) => p['id']?.toString() == _selectedPlaylistId);
      final liveName = matches.isNotEmpty ? matches.first['name']?.toString() : _selectedPlaylistName;
      final liveSongs = matches.isNotEmpty && matches.first['songs'] is List 
          ? (matches.first['songs'] as List<dynamic>) 
          : _selectedPlaylistSongs;

      return PlaylistDetailScreen(
        key: ValueKey('playlist_$_selectedPlaylistId'),
        title: liveName ?? '',
        songs: liveSongs,
        isLikedSongs: false,
        playlistId: _selectedPlaylistId,
        onBack: _clearSelection,
      );
    }

    // Default Library View
    return Scaffold(
      key: const ValueKey('library_home'),
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Consumer<AuthService>(
                        builder: (context, auth, _) {
                          final user = auth.currentUser;
                          final photoURL = user?.photoURL;
                          final initial = user?.displayName?.isNotEmpty == true 
                              ? user!.displayName![0].toUpperCase() 
                              : (user?.email?.isNotEmpty == true ? user!.email![0].toUpperCase() : 'U');

                          return CircleAvatar(
                            backgroundColor: AppTheme.primary,
                            backgroundImage: photoURL != null && photoURL.isNotEmpty ? NetworkImage(photoURL) : null,
                            child: photoURL == null || photoURL.isEmpty
                                ? Text(initial, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold))
                                : null,
                          );
                        },
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        'Your Library',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, color: Colors.white, size: 28),
                    onPressed: () {
                      _showCreatePlaylistDialog(context, libraryProvider);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Liked Songs Tile
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.deepPurple, Colors.indigo],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.favorite, color: Colors.white),
                ),
                title: const Text('Liked Songs', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                subtitle: Text('Playlist • $likedCount songs', style: TextStyle(color: Colors.white.withOpacity(0.6))),
                onTap: () {
                  setState(() {
                    _showLikedSongs = true;
                  });
                },
              ),
              
              const SizedBox(height: 8),

              // Downloaded Songs Tile
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.download_done_rounded, color: AppTheme.primary),
                ),
                title: const Text('Downloaded Songs', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                subtitle: Text('Offline • ${libraryProvider.downloadedSongs.length} songs', style: TextStyle(color: Colors.white.withOpacity(0.6))),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const DownloadedSongsScreen()));
                },
              ),

              const SizedBox(height: 16),
              
              // Custom Playlists
              Expanded(
                child: playlists.isEmpty 
                    ? Center(
                        child: Text(
                          'Create your first playlist!',
                          style: TextStyle(color: Colors.white.withOpacity(0.5)),
                        ),
                      )
                    : Theme(
                        data: Theme.of(context).copyWith(
                          canvasColor: Colors.transparent,
                        ),
                        child: ReorderableListView.builder(
                          buildDefaultDragHandles: false,
                          padding: const EdgeInsets.only(bottom: 120),
                          itemCount: playlists.length,
                          onReorder: (oldIndex, newIndex) {
                            libraryProvider.reorderPlaylists(oldIndex, newIndex);
                          },
                          itemBuilder: (context, index) {
                            final p = playlists[index];
                            final pId = p['id'].toString();
                            final pSongs = p['songs'] as List<dynamic>? ?? [];
                            final count = pSongs.length;
                            
                            String firstArt = '';
                            if (pSongs.isNotEmpty) {
                              final firstSong = pSongs.first;
                              if (firstSong['image'] is String) {
                                firstArt = firstSong['image'];
                              } else if (firstSong['image'] is List && (firstSong['image'] as List).isNotEmpty) {
                                final last = (firstSong['image'] as List).last;
                                if (last is Map && last['url'] != null) {
                                  firstArt = last['url'].toString();
                                } else if (last is String) {
                                  firstArt = last;
                                }
                              }
                            }

                            return ListTile(
                              key: ValueKey('library_playlist_$pId'),
                              contentPadding: EdgeInsets.zero,
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: firstArt.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: firstArt,
                                        width: 64,
                                        height: 64,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) => Container(
                                          width: 64,
                                          height: 64,
                                          color: Colors.grey[900],
                                          child: const Icon(Icons.queue_music, color: Colors.white54),
                                        ),
                                      )
                                    : Container(
                                        width: 64,
                                        height: 64,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[900],
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.queue_music, color: Colors.white54),
                                      ),
                              ),
                              title: Text(
                                p['name'] ?? 'Untitled Playlist',
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                'Playlist • $count ${count == 1 ? 'song' : 'songs'}',
                                style: TextStyle(color: Colors.white.withOpacity(0.6)),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.white54),
                                    onPressed: () => _confirmDeletePlaylist(context, libraryProvider, p),
                                  ),
                                  ReorderableDragStartListener(
                                    index: index,
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                                      child: Icon(Icons.drag_handle, color: Colors.white38),
                                    ),
                                  ),
                                ],
                              ),
                              onTap: () async {
                                final songs = await libraryProvider.getPlaylistSongs(pId);
                                if (context.mounted) {
                                  setState(() {
                                    _selectedPlaylistId = pId;
                                    _selectedPlaylistName = p['name'];
                                    _selectedPlaylistSongs = songs;
                                  });
                                }
                              },
                            );
                          },
                        ),
                      ),
              ),
              const SizedBox(height: 90), // Player padding
            ],
          ),
        ),
      ),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context, LibraryProvider provider) {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text('New Playlist', style: TextStyle(color: Colors.white)),
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
                if (controller.text.isNotEmpty) {
                  provider.createPlaylist(controller.text);
                }
                Navigator.pop(context);
              },
              child: const Text('CREATE', style: TextStyle(color: AppTheme.primary)),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeletePlaylist(BuildContext context, LibraryProvider libraryProvider, Map<String, dynamic> playlist) {
    final playlistName = playlist['name']?.toString() ?? 'Playlist';
    final playlistId = playlist['id']?.toString() ?? '';

    // Step 1: Initial Warning Dialog
    showDialog(
      context: context,
      builder: (step1Ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 28),
            SizedBox(width: 8),
            Text('Delete Playlist?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "$playlistName"?\n\n'
          'All songs within this playlist will be removed. This action cannot be undone.',
          style: const TextStyle(color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(step1Ctx),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent.withOpacity(0.2),
              foregroundColor: Colors.redAccent,
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(step1Ctx);
              // Step 2: Type to Confirm Dialog
              _showTypeToConfirmDeleteDialog(context, libraryProvider, playlistName, playlistId);
            },
            child: const Text('PROCEED', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showTypeToConfirmDeleteDialog(
    BuildContext context, 
    LibraryProvider libraryProvider, 
    String playlistName, 
    String playlistId
  ) {
    final TextEditingController confirmController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (step2Ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isMatch = confirmController.text.trim() == playlistName.trim();

            return AlertDialog(
              backgroundColor: Colors.grey[900],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Confirm Deletion', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
                      children: [
                        const TextSpan(text: 'To confirm, please type '),
                        TextSpan(
                          text: '"$playlistName"',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        const TextSpan(text: ' below:'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: confirmController,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: playlistName,
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                      filled: true,
                      fillColor: Colors.black26,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: isMatch ? Colors.redAccent : Colors.white24),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: isMatch ? Colors.redAccent : AppTheme.primary, width: 2),
                      ),
                    ),
                    onChanged: (_) {
                      setDialogState(() {});
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(step2Ctx),
                  child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isMatch ? Colors.redAccent : Colors.grey[800],
                    foregroundColor: isMatch ? Colors.white : Colors.white38,
                    elevation: 0,
                  ),
                  onPressed: isMatch
                      ? () {
                          Navigator.pop(step2Ctx);
                          libraryProvider.deletePlaylist(playlistId);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Deleted playlist "$playlistName"'),
                              backgroundColor: Colors.grey[900],
                            ),
                          );
                        }
                      : null,
                  child: const Text('DELETE PLAYLIST', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
