import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';
import '../providers/audio_provider.dart';
import '../providers/library_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/player_bar.dart';
import '../widgets/song_options_menu.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;
  List<dynamic> _searchResults = [];
  List<String> _recentSearches = [];
  bool _isSearching = false;
  
  int _searchPage = 1;
  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> _categories = [
    {'name': 'Hindi', 'color': Colors.orange},
    {'name': 'English', 'color': Colors.blue},
    {'name': 'Tamil', 'color': Colors.red},
    {'name': 'Telugu', 'color': Colors.green},
    {'name': 'Punjabi', 'color': Colors.purple},
    {'name': 'Malayalam', 'color': Colors.teal},
    {'name': 'Pop', 'color': Colors.pink},
    {'name': 'Hip-Hop', 'color': Colors.deepOrange},
    {'name': 'Romance', 'color': Colors.redAccent},
    {'name': 'Devotional', 'color': Colors.amber},
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _focusNode.addListener(() {
      setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRecents();
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          FocusScope.of(context).requestFocus(_focusNode);
        }
      });
    });
  }

  Future<void> _loadRecents() async {
    final lib = context.read<LibraryProvider>();
    if (lib.dbHelper != null) {
      final recents = await lib.dbHelper!.getRecentSearches();
      setState(() {
        _recentSearches = recents;
      });
    }
  }

  void _performSearch(String query, {bool dismissKeyboard = true}) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    
    if (dismissKeyboard) {
      _focusNode.unfocus();
    }
    setState(() {
      _isSearching = true;
      _searchPage = 1;
      _searchResults = [];
    });
    
    final lib = context.read<LibraryProvider>();
    if (lib.dbHelper != null) {
      await lib.dbHelper!.saveSearch(query.trim());
      await _loadRecents();
    }
    
    final results = await ApiService.searchSongs(query);
    
    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchResults = [];
    });
    _loadRecents();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _debounce?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 && !_isLoadingMore && _searchResults.isNotEmpty && !_isSearching) {
      _fetchMoreSearch();
    }
  }

  Future<void> _fetchMoreSearch() async {
    if (_searchController.text.trim().isEmpty) return;
    
    setState(() => _isLoadingMore = true);
    _searchPage++;
    
    final results = await ApiService.searchSongs(_searchController.text, page: _searchPage);
    
    if (mounted) {
      setState(() {
        _searchResults.addAll(results);
        _isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final audioProvider = context.watch<AudioProvider>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                  child: Text(
                    'Search',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _focusNode,
                    autofocus: false,
                    style: const TextStyle(color: Colors.black, fontSize: 16),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      hintText: 'What do you want to listen to?',
                      hintStyle: TextStyle(color: Colors.grey.shade600),
                      prefixIcon: const Icon(Icons.search, color: Colors.black),
                      suffixIcon: _searchController.text.isNotEmpty || _searchResults.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.black),
                              onPressed: _clearSearch,
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (val) => _performSearch(val, dismissKeyboard: true),
                    onChanged: (val) {
                      if (val.isEmpty) {
                        _clearSearch();
                      } else {
                        setState(() {});
                        if (_debounce?.isActive ?? false) _debounce!.cancel();
                        _debounce = Timer(const Duration(milliseconds: 500), () {
                          if (mounted) {
                            _performSearch(val, dismissKeyboard: false);
                          }
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _isSearching
                      ? const Center(child: CircularProgressIndicator())
                      : _searchController.text.isEmpty
                          ? CustomScrollView(
                              slivers: [
                                if (_recentSearches.isNotEmpty)
                                  SliverToBoxAdapter(
                                    child: _buildRecentSearches(),
                                  ),
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                    child: const Text('Browse all', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                SliverPadding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                  sliver: SliverGrid(
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      childAspectRatio: 1.5,
                                      crossAxisSpacing: 16,
                                      mainAxisSpacing: 16,
                                    ),
                                    delegate: SliverChildBuilderDelegate(
                                      (context, index) {
                                        final category = _categories[index];
                                        return GestureDetector(
                                          onTap: () {
                                            _searchController.text = category['name'];
                                            _performSearch(category['name'], dismissKeyboard: true);
                                          },
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: category['color'],
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            padding: const EdgeInsets.all(12),
                                            child: Align(
                                              alignment: Alignment.topLeft,
                                              child: Text(
                                                category['name'],
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                      childCount: _categories.length,
                                    ),
                                  ),
                                ),
                                const SliverToBoxAdapter(child: SizedBox(height: 100)),
                              ],
                            )
                          : Column(
                              children: [
                                Expanded(
                                  child: ListView.builder(
                                    controller: _scrollController,
                                    padding: const EdgeInsets.only(bottom: 120),
                                    itemCount: _searchResults.length + (_isLoadingMore ? 1 : 0),
                                    itemBuilder: (context, index) {
                                      if (index == _searchResults.length) {
                                        return const Padding(
                                          padding: EdgeInsets.symmetric(vertical: 20),
                                          child: Center(child: CircularProgressIndicator()),
                                        );
                                      }
                                      final song = _searchResults[index];
                                      final imageUrl = (song['image'] != null && song['image'].isNotEmpty)
                                          ? song['image'].last['url']
                                          : '';
                                      return ListTile(
                                        leading: ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: CachedNetworkImage(
                                            imageUrl: imageUrl,
                                            width: 50,
                                            height: 50,
                                            fit: BoxFit.cover,
                                            errorWidget: (c, u, e) => Container(color: Colors.grey[800], width: 50, height: 50),
                                          ),
                                        ),
                                        title: Text(
                                          song['name'] ?? 'Unknown',
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
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
                                          audioProvider.playSong(song, newQueue: _searchResults);
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                ),
              ],
            ),
            
            // Global Player Bar
            if (audioProvider.currentSong != null)
              const Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: PlayerBar(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            'Browse all',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.5,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final category = _categories[index];
              return GestureDetector(
                onTap: () {
                  final query = '${category['name']} songs';
                  _searchController.text = query;
                  _performSearch(query, dismissKeyboard: true);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: category['color'],
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -15,
                        bottom: -15,
                        child: Transform.rotate(
                          angle: 0.4,
                          child: Icon(Icons.music_note, size: 80, color: Colors.white.withOpacity(0.2)),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          category['name'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecentSearches() {
    final settings = context.watch<SettingsProvider>();
    if (!settings.showRecentSearches) {
      return const SizedBox.shrink();
    }
    
    if (_recentSearches.isEmpty) {
      return const Center(
        child: Text(
          'Play what you love',
          style: TextStyle(color: Colors.white54, fontSize: 16),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Recent searches', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            TextButton(
              onPressed: () async {
                final lib = context.read<LibraryProvider>();
                if (lib.dbHelper != null) {
                  await lib.dbHelper!.clearRecentSearches();
                  _loadRecents();
                }
              },
              child: const Text('Clear', style: TextStyle(color: AppTheme.primary)),
            )
          ],
        ),
        ..._recentSearches.map((query) => ListTile(
              leading: const Icon(Icons.history, color: Colors.white70),
              title: Text(query, style: const TextStyle(color: Colors.white)),
              trailing: IconButton(
                icon: const Icon(Icons.close, color: Colors.white54),
                onPressed: () async {
                  final lib = context.read<LibraryProvider>();
                  if (lib.dbHelper != null) {
                    await lib.dbHelper!.removeRecentSearch(query);
                    _loadRecents();
                  }
                },
              ),
              onTap: () {
                _searchController.text = query;
                _performSearch(query);
              },
            )),
      ],
    );
  }
}
