import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/audio_provider.dart';
import '../providers/library_provider.dart';
import '../screens/now_playing_screen.dart';
import '../theme/app_theme.dart';

class PlayerBar extends StatelessWidget {
  const PlayerBar({super.key});

  @override
  Widget build(BuildContext context) {
    final audioProvider = context.watch<AudioProvider>();
    final libraryProvider = context.watch<LibraryProvider>();
    final currentSong = audioProvider.currentSong;

    if (currentSong == null) return const SizedBox.shrink();

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
    final dominantColor = audioProvider.dominantColor ?? Colors.black;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const NowPlayingScreen(),
                fullscreenDialog: true,
              ),
            );
          },
          child: Container(
            height: 72,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: dominantColor.withOpacity(0.6),
            border: Border(top: BorderSide(color: dominantColor.withOpacity(0.3), width: 0.5)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) => Container(color: Colors.grey[900]),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      currentSong['name'] ?? 'Unknown',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currentSong['primaryArtists'] ?? '',
                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  isLiked ? Icons.favorite : Icons.favorite_border,
                  color: isLiked ? AppTheme.primary : Colors.white,
                ),
                onPressed: () {
                  libraryProvider.toggleLike(currentSong);
                },
              ),
              StreamBuilder<bool>(
                stream: audioProvider.player.playingStream,
                builder: (context, snapshot) {
                  final isPlaying = snapshot.data ?? false;
                  return IconButton(
                    icon: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
                    iconSize: 42,
                    color: Colors.white,
                    onPressed: () => audioProvider.togglePlayPause(),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.skip_next),
                color: Colors.white,
                onPressed: () => audioProvider.playNext(),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
