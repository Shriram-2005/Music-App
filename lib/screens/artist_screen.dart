import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/audio_provider.dart';
import '../providers/library_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/song_options_menu.dart';

class ArtistScreen extends StatefulWidget {
  final String artistName;

  const ArtistScreen({super.key, required this.artistName});

  @override
  State<ArtistScreen> createState() => _ArtistScreenState();
}

class _ArtistScreenState extends State<ArtistScreen> {
  List<dynamic> _songs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchArtistSongs();
  }

  Future<void> _fetchArtistSongs() async {
    setState(() {
      _isLoading = true;
    });

    final results = await ApiService.searchSongs(widget.artistName);
    
    // Optional: Filter precisely by artist if the search API returns too broad results
    final filtered = results.where((song) {
      final artists = song['primaryArtists']?.toString().toLowerCase() ?? '';
      return artists.contains(widget.artistName.toLowerCase());
    }).toList();

    if (mounted) {
      setState(() {
        _songs = filtered.isNotEmpty ? filtered : results;
        _isLoading = false;
      });
    }
  }

  String? _getHighResImage(List<dynamic>? imageUrls) {
    if (imageUrls == null || imageUrls.isEmpty) return null;
    return imageUrls.last['url'];
  }

  @override
  Widget build(BuildContext context) {
    final audioProvider = context.watch<AudioProvider>();
    final libraryProvider = context.watch<LibraryProvider>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(widget.artistName, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _songs.isEmpty
              ? const Center(child: Text('No songs found', style: TextStyle(color: Colors.white70)))
              : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: _songs.length,
                        padding: const EdgeInsets.only(bottom: 120),
                        itemBuilder: (context, index) {
                          final song = _songs[index];
                          final imageUrl = _getHighResImage(song['image']) ?? '';
                          final isPlaying = audioProvider.currentSong?['id'] == song['id'];
                          final isLiked = libraryProvider.isLiked(song['id'].toString());

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: imageUrl,
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                              ),
                            ),
                            title: Text(
                              song['name'] ?? 'Unknown',
                              style: TextStyle(
                                color: isPlaying ? AppTheme.primary : Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              song['primaryArtists'] ?? '',
                              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    isLiked ? Icons.favorite : Icons.favorite_border,
                                    color: isLiked ? AppTheme.primary : Colors.white54,
                                  ),
                                  onPressed: () {
                                    libraryProvider.toggleLike(song);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.more_vert, color: Colors.white54),
                                  onPressed: () => showSongOptionsMenu(context, song),
                                ),
                              ],
                            ),
                            onTap: () {
                              audioProvider.playSong(song, newQueue: _songs);
                            },
                          );
                        },
                      ),
    );
  }
}
