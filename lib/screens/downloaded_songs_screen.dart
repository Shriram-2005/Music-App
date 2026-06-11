import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/library_provider.dart';
import '../providers/audio_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/song_options_menu.dart';
import '../widgets/player_bar.dart';

class DownloadedSongsScreen extends StatelessWidget {
  const DownloadedSongsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final libraryProvider = context.watch<LibraryProvider>();
    final audioProvider = context.watch<AudioProvider>();
    final songs = libraryProvider.downloadedSongs;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Downloaded Songs', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          songs.isEmpty
              ? const Center(
                  child: Text(
                    'No downloaded songs yet.',
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                )
              : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 120),
                  itemCount: songs.length,
                  itemBuilder: (context, index) {
                    final song = songs[index];
                    String imageUrl = '';
                    if (song['image'] is List && song['image'].isNotEmpty) {
                      imageUrl = song['image'].last['url'];
                    } else if (song['image'] is String) {
                      imageUrl = song['image'];
                    }

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => Container(color: Colors.grey[800], width: 56, height: 56),
                        ),
                      ),
                      title: Text(
                        song['name'] ?? 'Unknown',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        song['primaryArtists'] ?? '',
                        style: TextStyle(color: Colors.white.withOpacity(0.6)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.more_vert, color: Colors.white54),
                        onPressed: () => showSongOptionsMenu(context, song),
                      ),
                      onTap: () {
                        audioProvider.playSong(song, newQueue: songs);
                      },
                    );
                  },
                ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: PlayerBar(),
          ),
        ],
      ),
    );
  }
}
