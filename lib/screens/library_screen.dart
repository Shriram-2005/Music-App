import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/library_provider.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
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
      return PlaylistDetailScreen(
        key: ValueKey('playlist_$_selectedPlaylistId'),
        title: _selectedPlaylistName ?? '',
        songs: _selectedPlaylistSongs,
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
                    : ListView.builder(
                        itemCount: playlists.length,
                        itemBuilder: (context, index) {
                          final p = playlists[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: Colors.grey[900],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Icon(Icons.queue_music, color: Colors.white54),
                            ),
                            title: Text(
                              p['name'],
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text('Playlist', style: TextStyle(color: Colors.white.withOpacity(0.6))),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.white54),
                              onPressed: () => libraryProvider.deletePlaylist(p['id'].toString()),
                            ),
                            onTap: () async {
                              final pId = p['id'].toString();
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
}
