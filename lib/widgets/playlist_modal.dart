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
              title: const Text('New Playlist', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600)),
              onTap: () {
                _showCreateDialog(context, libraryProvider);
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
                    final pSongs = p['songs'] as List<dynamic>? ?? [];
                    final alreadyAdded = pSongs.any((s) => s['id']?.toString() == song['id']?.toString());
                    final count = pSongs.length;

                    return ListTile(
                      leading: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.queue_music, color: Colors.white70),
                      ),
                      title: Text(p['name'] ?? 'Untitled Playlist', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                      subtitle: Text(
                        '$count ${count == 1 ? 'song' : 'songs'}${alreadyAdded ? ' • Already added' : ''}',
                        style: TextStyle(color: alreadyAdded ? AppTheme.primary : Colors.white54, fontSize: 12),
                      ),
                      trailing: alreadyAdded
                          ? const Icon(Icons.check_circle, color: AppTheme.primary, size: 20)
                          : const Icon(Icons.add_circle_outline, color: Colors.white38, size: 20),
                      onTap: () async {
                        await libraryProvider.addSongToPlaylist(p['id'].toString(), song);
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Added "${song['name'] ?? 'Song'}" to ${p['name']}'),
                              backgroundColor: Colors.grey[900],
                            ),
                          );
                        }
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

  void _showCreateDialog(BuildContext context, LibraryProvider libraryProvider) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('New Playlist', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Playlist name',
            hintStyle: TextStyle(color: Colors.white54),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.primary)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(dialogCtx);
                final newId = await libraryProvider.createPlaylist(name);
                if (newId != null) {
                  await libraryProvider.addSongToPlaylist(newId, song);
                }
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Created "$name" and added "${song['name'] ?? 'Song'}"'),
                      backgroundColor: Colors.grey[900],
                    ),
                  );
                }
              }
            },
            child: const Text('CREATE & ADD', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
