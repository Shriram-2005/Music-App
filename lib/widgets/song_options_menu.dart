import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/audio_provider.dart';
import '../providers/library_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/playlist_modal.dart';
import '../screens/driving_mode_screen.dart';

void _showSleepTimerModal(BuildContext context, AudioProvider provider) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.grey[900],
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Sleep Timer', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
            if (provider.sleepTimerEndTime != null)
              ListTile(
                leading: const Icon(Icons.timer_off, color: Colors.red),
                title: const Text('Cancel Timer', style: TextStyle(color: Colors.red)),
                onTap: () {
                  provider.cancelSleepTimer();
                  Navigator.pop(context);
                },
              ),
            for (int minutes in [15, 30, 45, 60])
              ListTile(
                leading: const Icon(Icons.timer, color: Colors.white70),
                title: Text('$minutes minutes', style: const TextStyle(color: Colors.white)),
                onTap: () {
                  provider.startSleepTimer(Duration(minutes: minutes));
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      );
    },
  );
}

void _showCastModal(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.grey[900],
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (context) => Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Cast to Device', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.tv, color: Colors.white),
            title: const Text('Living Room TV', style: TextStyle(color: Colors.white)),
            subtitle: const Text('Chromecast', style: TextStyle(color: Colors.white54)),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.speaker, color: Colors.white),
            title: const Text('Bedroom Speaker', style: TextStyle(color: Colors.white)),
            subtitle: const Text('AirPlay', style: TextStyle(color: Colors.white54)),
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    ),
  );
}

void showSongOptionsMenu(BuildContext context, dynamic song) {
  final audioProvider = context.read<AudioProvider>();
  final libraryProvider = context.read<LibraryProvider>();
  
  final isLiked = libraryProvider.isLiked(song['id'].toString());
  final isDownloaded = libraryProvider.isDownloaded(song['id'].toString());
  
  String imageUrl = '';
  if (song['image'] is List && song['image'].isNotEmpty) {
    imageUrl = song['image'].last['url'];
  } else if (song['image'] is String) {
    imageUrl = song['image'];
  }
  
  showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  // Header
                  ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => Container(color: Colors.grey[800], width: 50, height: 50),
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
                  ),
                  const Divider(color: Colors.white24),
                  
                  // Like Option
                  ListTile(
                    leading: Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border, 
                      color: isLiked ? AppTheme.primary : Colors.white,
                    ),
                    title: const Text('Like', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      libraryProvider.toggleLike(song);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isLiked ? 'Removed from Liked Songs' : 'Added to Liked Songs'),
                          backgroundColor: Colors.grey[900],
                        )
                      );
                    },
                  ),
                  
                  // Add to Queue Option
                  ListTile(
                    leading: const Icon(Icons.queue_music, color: Colors.white),
                    title: const Text('Add to Queue', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      final currentQueue = audioProvider.queue;
                      if (!currentQueue.any((s) => s['id'] == song['id'])) {
                        currentQueue.add(song);
                      }
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: const Text('Added to Queue'), backgroundColor: Colors.grey[900])
                      );
                    },
                  ),
                  
                  // Add to Playlist Option
                  ListTile(
                    leading: const Icon(Icons.playlist_add, color: Colors.white),
                    title: const Text('Add to Playlist', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      showDialog(
                        context: context,
                        builder: (context) => PlaylistModal(song: song),
                      );
                    },
                  ),
                  
                  // Download Option
                  ListTile(
                    leading: Icon(
                      isDownloaded ? Icons.download_done : Icons.download, 
                      color: isDownloaded ? AppTheme.primary : Colors.white,
                    ),
                    title: Text(isDownloaded ? 'Remove Download' : 'Download', style: const TextStyle(color: Colors.white)),
                    onTap: () async {
                      Navigator.pop(context);
                      if (isDownloaded) {
                        await libraryProvider.removeDownload(song['id'].toString());
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: const Text('Download removed'), backgroundColor: Colors.grey[900])
                          );
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: const Text('Downloading...'), backgroundColor: Colors.grey[900])
                        );
                        final success = await libraryProvider.downloadSong(song);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(success ? 'Download complete!' : 'Download failed.'),
                              backgroundColor: success ? Colors.green : Colors.red,
                            )
                          );
                        }
                      }
                    },
                  ),
                  
                  const Divider(color: Colors.white24),

                  // Sleep Timer Option
                  ListTile(
                    leading: Icon(
                      Icons.bedtime, 
                      color: audioProvider.sleepTimerEndTime != null ? AppTheme.primary : Colors.white,
                    ),
                    title: const Text('Sleep Timer', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      _showSleepTimerModal(context, audioProvider);
                    },
                  ),

                  // Cast to Device Option
                  ListTile(
                    leading: const Icon(Icons.cast, color: Colors.white),
                    title: const Text('Cast to Device', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      _showCastModal(context);
                    },
                  ),

                  // Driving Mode Option
                  ListTile(
                    leading: const Icon(Icons.directions_car, color: Colors.white),
                    title: const Text('Driving Mode', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const DrivingModeScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
        }
      );
    }
  );
}
