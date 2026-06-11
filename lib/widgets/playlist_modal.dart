import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/library_provider.dart';
import '../theme/app_theme.dart';

class PlaylistModal extends StatelessWidget {
  final dynamic song;

  const PlaylistModal({super.key, required this.song});

  @override
  Widget build(BuildContext context) {
    final libraryProvider = context.watch<LibraryProvider>();
    final playlists = libraryProvider.playlists;

    return SafeArea(
      child: Material(
        color: Colors.transparent,
        child: Container(
          color: Colors.grey[900],
          child: Column(
            mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Add to Playlist',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.add, color: AppTheme.primary),
              title: const Text('New Playlist', style: TextStyle(color: AppTheme.primary)),
              onTap: () {
                Navigator.pop(context);
                // Future enhancement: forward to create playlist dialog
              },
            ),
            const Divider(color: Colors.white24),
            if (playlists.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32.0),
                child: Text('No playlists available', style: TextStyle(color: Colors.white54)),
              )
            else
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: playlists.length,
                  itemBuilder: (context, index) {
                    final p = playlists[index];
                    return ListTile(
                      leading: const Icon(Icons.queue_music, color: Colors.white54),
                      title: Text(p['name'], style: const TextStyle(color: Colors.white)),
                      onTap: () {
                        libraryProvider.addSongToPlaylist(p['id'].toString(), song);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Added to ${p['name']}'))
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      ),
    );
  }
}
