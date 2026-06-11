import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/audio_provider.dart';
import '../theme/app_theme.dart';

class DrivingModeScreen extends StatelessWidget {
  const DrivingModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final audioProvider = context.watch<AudioProvider>();
    final currentSong = audioProvider.currentSong;
    
    if (currentSong == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, size: 40, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: Text('No song playing', style: TextStyle(color: Colors.white, fontSize: 24)),
        ),
      );
    }

    final imageUrl = currentSong['image'] != null && currentSong['image'].isNotEmpty 
        ? currentSong['image'][0]['url'] 
        : '';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Blurred background
          if (imageUrl.isNotEmpty)
            Opacity(
              opacity: 0.3,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
              ),
            ),
          
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: IconButton(
                      icon: const Icon(Icons.close, size: 48, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
                
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          currentSong['name'] ?? 'Unknown',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          currentSong['primaryArtists'] ?? '',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 28,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Massive Controls
                Container(
                  padding: const EdgeInsets.only(bottom: 60, top: 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.skip_previous),
                        iconSize: 80,
                        color: Colors.white,
                        onPressed: () => audioProvider.playPrevious(),
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
                              iconSize: 120,
                              color: Colors.black,
                              onPressed: () => audioProvider.togglePlayPause(),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_next),
                        iconSize: 80,
                        color: Colors.white,
                        onPressed: () => audioProvider.playNext(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
