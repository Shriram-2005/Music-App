import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';
import '../providers/audio_provider.dart';
import '../providers/library_provider.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../providers/settings_provider.dart';
import 'settings_screen.dart';
import 'search_screen.dart';
import 'artist_screen.dart';
import '../widgets/song_options_menu.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> _trendingSongs = [];
  List<dynamic> _recommendedSongs = [];
  List<dynamic> _recentlyPlayed = [];
  List<dynamic> _dailyMixSongs = [];
  int _dailyMixLimit = 25;
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  
  String _selectedLanguage = 'All';
  List<String> _activeLanguages = ['Hindi', 'English', 'Tamil', 'Telugu', 'Punjabi'];
  final List<String> _allAvailableLanguages = [
    'Hindi', 'English', 'Tamil', 'Telugu', 'Punjabi', 
    'Malayalam', 'Pop', 'Romance', 'Marathi', 'Gujarati', 
    'Bengali', 'Kannada', 'Bhojpuri', 'Urdu', 'Arabic', 
    'Spanish', 'French', 'Korean', 'Japanese', 'Assamese', 'Odia'
  ];
  String _defaultRecommendedQuery = 'trending';
  
  Color _dominantColor = AppTheme.primary;
  String _heroImageUrl = 'https://picsum.photos/600/600';

  int _recommendedPage = 1;
  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 && !_isLoadingMore && _recommendedSongs.isNotEmpty) {
      _fetchMoreRecommended();
    }
  }

  Future<void> _fetchMoreRecommended() async {
    setState(() => _isLoadingMore = true);
    _recommendedPage++;
    
    String query = _selectedLanguage == 'All' ? _defaultRecommendedQuery : '$_selectedLanguage songs';
    if (_searchController.text.isNotEmpty) {
      query = _searchController.text;
    }
    
    final results = await ApiService.searchSongs(query, page: _recommendedPage);
    
    if (mounted) {
      setState(() {
        _recommendedSongs.addAll(results);
        _isLoadingMore = false;
      });
    }
  }

  void _refreshDailyMix([LibraryProvider? providedProvider]) {
    final libraryProvider = providedProvider ?? context.read<LibraryProvider>();
    final playlists = libraryProvider.playlists;
    
    List<dynamic> allCustomSongs = [];
    for (var p in playlists) {
      allCustomSongs.addAll(p['songs'] ?? []);
    }
    
    final Map<String, dynamic> uniqueMap = {};
    for (var s in allCustomSongs) {
      uniqueMap[s['id'].toString()] = s;
    }
    
    setState(() {
      _dailyMixSongs = uniqueMap.values.toList();
      _dailyMixSongs.shuffle();
      if (_dailyMixSongs.length > _dailyMixLimit) {
        _dailyMixSongs = _dailyMixSongs.sublist(0, _dailyMixLimit);
      }
    });
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _recommendedPage = 1;
    });
    
    final libraryProvider = context.read<LibraryProvider>();
    final playlists = libraryProvider.playlists;
    final liked = libraryProvider.likedSongs;
    
    // Build Daily Mix
    _refreshDailyMix(libraryProvider);

    // Determine tailored queries based on liked/recent
    final random = Random();
    List<String> pool = [];
    if (liked.isNotEmpty) {
      pool.add(liked[random.nextInt(liked.length)]['name'].toString().split(' ')[0]);
    }
    final recently = await libraryProvider.getRecentlyPlayed();
    if (recently.isNotEmpty) {
      pool.add(recently[random.nextInt(recently.length)]['primaryArtists'].toString().split(',')[0]);
    }
    
    // If no history, use defaults
    if (pool.isEmpty) {
      pool.addAll(['trending', 'top charts', 'pop hits']);
    } else if (pool.length == 1) {
      pool.add('trending'); // Ensure we have at least 2 queries
    }

    final query1 = pool[0];
    final query2 = pool[1];
    _defaultRecommendedQuery = query2;

    // Fetch parallel discovery data
    final responses = await Future.wait([
      ApiService.searchSongs(query1),
      ApiService.searchSongs(query2),
    ]);

    final trending = responses[0] as List<dynamic>;
    final recommended = responses[1] as List<dynamic>;

    if (trending.isNotEmpty) {
      final firstImage = _getHighResImage(trending.first['image']);
      if (firstImage != null) {
        _heroImageUrl = firstImage;
        await _updatePalette(_heroImageUrl);
      }
    }

    if (mounted) {
      setState(() {
        _trendingSongs = trending;
        _recommendedSongs = recommended;
        _recentlyPlayed = recently;
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchLanguageRecommendations(String language) async {
    setState(() {
      _selectedLanguage = language;
      _recommendedPage = 1;
      _isLoading = true;
    });
    
    String query = language == 'All' ? _defaultRecommendedQuery : '$language songs';
    final results = await ApiService.searchSongs(query);
    
    if (mounted) {
      setState(() {
        _recommendedSongs = results;
        _isLoading = false;
      });
    }
  }

  Future<void> _search(String query) async {
    if (query.isEmpty) return;
    setState(() {
      _isLoading = true;
      _recommendedPage = 1;
    });
    final results = await ApiService.searchSongs(query);
    setState(() {
      _recommendedSongs = results; // Replace bottom list with search results
      _isLoading = false;
    });
  }

  Future<void> _updatePalette(String imageUrl) async {
    try {
      final PaletteGenerator generator = await PaletteGenerator.fromImageProvider(
        CachedNetworkImageProvider(imageUrl),
      );
      if (mounted) {
        setState(() {
          _dominantColor = generator.dominantColor?.color ?? AppTheme.primary;
        });
      }
    } catch (e) {
      // ignore
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
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // Ambient Background Blur
          AnimatedContainer(
            duration: const Duration(milliseconds: 800),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _dominantColor.withOpacity(0.6),
                  AppTheme.background,
                ],
                stops: const [0.0, 0.4],
              ),
            ),
          ),

          // Main scrollable content
          RefreshIndicator(
            color: AppTheme.primary,
            backgroundColor: AppTheme.surface,
            onRefresh: _loadInitialData,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                  _buildHeader(),
                  _buildSearchBar(),
                  
                  if (settings.isOfflineMode) ...[
                    _buildSectionTitle('Offline Mode Active'),
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: Text(
                          'You are currently offline. Only downloaded songs are available.',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ),
                    _buildOfflineList(audioProvider, libraryProvider),
                    const SliverToBoxAdapter(child: SizedBox(height: 120)),
                  ] else if (_isLoading)
                    const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
                    )
                  else ...[
                    // Daily Mix
                    if (_dailyMixSongs.isNotEmpty) ...[
                      _buildSectionTitle('Your Daily Mix'),
                      _buildDailyMixCard(audioProvider, libraryProvider),
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    ],

                    if (settings.showRecentlyPlayed && _recentlyPlayed.isNotEmpty) ...[
                      _buildSectionTitle('Recently Played'),
                      _buildSquareCarousel(_recentlyPlayed, audioProvider),
                    ],
                    if (settings.showTrending) ...[
                      _buildSectionTitle('Trending Now'),
                      _buildSquareCarousel(_trendingSongs, audioProvider),
                    ],

                    _buildSectionTitle(_searchController.text.isEmpty ? 'Recommended for You' : 'Search Results'),
                    if (_searchController.text.isEmpty) _buildLanguageChips(),
                    if (_selectedLanguage != 'All' && _searchController.text.isEmpty)
                      _buildArtistPills(),
                    _buildVerticalList(audioProvider, libraryProvider),
                    if (_isLoadingMore)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 120)), // Space for global player
                  ]
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDailyMixCard(AudioProvider audioProvider, LibraryProvider libraryProvider) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: GestureDetector(
          onTap: () {
            audioProvider.playSong(_dailyMixSongs[0], newQueue: _dailyMixSongs);
          },
          child: Container(
            constraints: const BoxConstraints(minHeight: 160),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [AppTheme.primary.withOpacity(0.8), Colors.deepPurple],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(color: AppTheme.primary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -20,
                  bottom: -20,
                  child: Icon(Icons.graphic_eq, size: 140, color: Colors.white.withOpacity(0.1)),
                ),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: _dailyMixSongs.isEmpty 
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Daily Mix',
                          style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create a playlist and add songs to generate your dynamic Daily Mix!',
                          style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Daily Mix',
                            style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.refresh, color: Colors.white),
                                onPressed: () {
                                  _refreshDailyMix(libraryProvider);
                                },
                              ),
                              PopupMenuButton<int>(
                                icon: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                                  ),
                                  child: const Icon(Icons.filter_list, color: Colors.white),
                                ),
                              ),
                            ),
                            color: AppTheme.surface.withOpacity(0.95),
                            elevation: 10,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            onSelected: (value) {
                              setState(() {
                                _dailyMixLimit = value;
                              });
                              _refreshDailyMix(libraryProvider);
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 10, child: Text('Top 10', style: TextStyle(color: Colors.white))),
                              const PopupMenuItem(value: 25, child: Text('Top 25', style: TextStyle(color: Colors.white))),
                              const PopupMenuItem(value: 50, child: Text('Top 50', style: TextStyle(color: Colors.white))),
                            ],
                          ),
                            ],
                          ),
                        ],
                      ),
                      Text(
                        'A dynamic blend of your playlists\n$_dailyMixLimit Handpicked tracks',
                        style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              if (_dailyMixSongs.isNotEmpty) {
                                audioProvider.playSong(_dailyMixSongs[0], newQueue: _dailyMixSongs);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.play_arrow, color: Colors.black, size: 20),
                                  SizedBox(width: 4),
                                  Text('PLAY', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () => _showMixModal(context, audioProvider, libraryProvider),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                border: Border.all(color: Colors.white),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.list, color: Colors.white, size: 20),
                                  SizedBox(width: 4),
                                  Text('VIEW', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final user = context.watch<AuthService>().currentUser;
    final userName = user?.displayName?.isNotEmpty == true 
        ? user!.displayName 
        : (user?.email?.isNotEmpty == true ? user!.email!.split('@')[0] : '');

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 60, 20, 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getGreeting(userName),
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
                ),
                const Text(
                  'Discover',
                  style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                ),
              ],
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                );
              },
              child: Consumer<AuthService>(
                builder: (context, auth, _) {
                  final user = auth.currentUser;
                  final photoURL = user?.photoURL;
                  final initial = user?.displayName?.isNotEmpty == true 
                      ? user!.displayName![0].toUpperCase() 
                      : (user?.email?.isNotEmpty == true ? user!.email![0].toUpperCase() : 'U');

                  return CircleAvatar(
                    radius: 24,
                    backgroundColor: AppTheme.primary,
                    backgroundImage: photoURL != null && photoURL.isNotEmpty ? NetworkImage(photoURL) : null,
                    child: photoURL == null || photoURL.isEmpty
                        ? Text(initial, style: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold))
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getGreeting(String? userName) {
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) greeting = 'Good Morning';
    else if (hour < 17) greeting = 'Good Afternoon';
    else greeting = 'Good Evening';
    
    if (userName != null && userName.isNotEmpty) {
      return '$greeting, $userName';
    }
    return greeting;
  }

  Widget _buildSearchBar() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SearchScreen()),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: Colors.white.withOpacity(0.1),
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: Colors.white70),
                    const SizedBox(width: 12),
                    Text(
                      'Search songs, artists...',
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageChips() {
    final displayList = ['All', ..._activeLanguages];
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 40,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: displayList.length + 1,
          itemBuilder: (context, index) {
            if (index == displayList.length) {
               return Padding(
                 padding: const EdgeInsets.symmetric(horizontal: 4),
                 child: ActionChip(
                   label: const Text('+ Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                   backgroundColor: Colors.white.withOpacity(0.1),
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                   side: BorderSide.none,
                   onPressed: _showLanguageFilterModal,
                 )
               );
            }
            final lang = displayList[index];
            final isSelected = _selectedLanguage == lang;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: Text(lang, style: TextStyle(color: isSelected ? Colors.black : Colors.white)),
                selected: isSelected,
                selectedColor: AppTheme.primary,
                backgroundColor: Colors.white.withOpacity(0.1),
                onSelected: (selected) {
                  if (selected && _selectedLanguage != lang) {
                    _fetchLanguageRecommendations(lang);
                  }
                },
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                side: BorderSide.none,
              ),
            );
          },
        ),
      ),
    );
  }

  void _showLanguageFilterModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).padding.bottom + 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Active Languages (Drag to Reorder)', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 250),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ReorderableListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _activeLanguages.length,
                      onReorder: (oldIndex, newIndex) {
                        setModalState(() {
                          if (newIndex > oldIndex) newIndex -= 1;
                          final item = _activeLanguages.removeAt(oldIndex);
                          _activeLanguages.insert(newIndex, item);
                        });
                        setState(() {});
                      },
                      itemBuilder: (context, index) {
                        final lang = _activeLanguages[index];
                        return ListTile(
                          key: ValueKey(lang),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                          leading: const Icon(Icons.drag_indicator, color: Colors.white54),
                          title: Text(lang, style: const TextStyle(color: Colors.white, fontSize: 16)),
                          trailing: IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                            onPressed: () {
                              setModalState(() {
                                _activeLanguages.remove(lang);
                                if (_selectedLanguage == lang) {
                                  _selectedLanguage = 'All';
                                  _fetchLanguageRecommendations('All');
                                }
                              });
                              setState(() {});
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Available Languages (Tap to Add)', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _allAvailableLanguages.map((lang) {
                      final isActive = _activeLanguages.contains(lang);
                      if (isActive) return const SizedBox.shrink(); // Hide if already active
                      return ActionChip(
                        label: Text(lang, style: const TextStyle(color: Colors.white)),
                        backgroundColor: Colors.white.withOpacity(0.1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        side: BorderSide.none,
                        onPressed: () {
                          setModalState(() {
                            _activeLanguages.add(lang);
                          });
                          setState(() {});
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary, 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 16)
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Save Filters', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            );
          }
        );
      }
    );
  }

  Widget _buildSectionTitle(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSquareCarousel(List<dynamic> songsList, AudioProvider audioProvider) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 220,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          itemCount: songsList.length,
          itemBuilder: (context, index) {
            final song = songsList[index];
            final imageUrl = _getHighResImage(song['image']) ?? '';
            final isPlaying = audioProvider.currentSong?['id'] == song['id'];

            return GestureDetector(
              onTap: () {
                _updatePalette(imageUrl);
                audioProvider.playSong(song, newQueue: songsList);
              },
              child: Container(
                width: 160,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: imageUrl,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          if (isPlaying)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.4),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Center(
                                  child: Icon(Icons.equalizer, color: AppTheme.primary, size: 36),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      song['name'] ?? 'Unknown',
                      style: TextStyle(
                        color: isPlaying ? AppTheme.primary : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildVerticalList(AudioProvider audioProvider, LibraryProvider libraryProvider) {
    if (_recommendedSongs.isEmpty) return const SliverToBoxAdapter(child: SizedBox());

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final song = _recommendedSongs[index];
          final imageUrl = _getHighResImage(song['image']) ?? '';
          final isPlaying = audioProvider.currentSong?['id'] == song['id'];
          final isLiked = libraryProvider.isLiked(song['id'].toString());

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 32,
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                     width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
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
              _updatePalette(imageUrl);
              audioProvider.playSong(song, newQueue: _recommendedSongs);
            },
          );
        },
        childCount: _recommendedSongs.length,
      ),
    );
  }

  Widget _buildArtistPills() {
    if (_recommendedSongs.isEmpty) return const SliverToBoxAdapter(child: SizedBox());

    final Set<String> artistsSet = {};
    for (var song in _recommendedSongs) {
      final artistList = song['primaryArtists']?.toString().split(',') ?? [];
      for (var a in artistList) {
        if (a.trim().isNotEmpty) {
          artistsSet.add(a.trim());
        }
      }
    }

    final artists = artistsSet.toList();
    if (artists.isEmpty) return const SliverToBoxAdapter(child: SizedBox());

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 10, 20, 10),
            child: Text(
              'Artists',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(
            height: 100, // increased height for squircle
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: artists.length,
              itemBuilder: (context, index) {
                final artist = artists[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ArtistScreen(artistName: artist),
                        ),
                      );
                    },
                    child: Container(
                      width: 100,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        artist,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildOfflineList(AudioProvider audioProvider, LibraryProvider libraryProvider) {
    final downloaded = libraryProvider.downloadedSongs;
    if (downloaded.isEmpty) {
      return const SliverFillRemaining(
        child: Center(child: Text('No downloaded songs found.', style: TextStyle(color: Colors.white70))),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final song = downloaded[index];
          final imageUrl = _getHighResImage(song['image']) ?? '';
          final isPlaying = audioProvider.currentSong?['id'] == song['id'];
          final isLiked = libraryProvider.isLiked(song['id'].toString());

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 32,
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) => Container(color: Colors.grey[800], child: const Icon(Icons.music_note, color: Colors.white54)),
                  ),
                ),
              ],
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
              _updatePalette(imageUrl);
              audioProvider.playSong(song, newQueue: downloaded);
            },
          );
        },
        childCount: downloaded.length,
      ),
    );
  }

  void _showMixModal(BuildContext context, AudioProvider audioProvider, LibraryProvider libraryProvider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Your Daily Mix ($_dailyMixLimit)', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54),
                        onPressed: () => Navigator.pop(context),
                      )
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: _dailyMixSongs.length,
                    itemBuilder: (context, index) {
                      final song = _dailyMixSongs[index];
                      final imageUrl = _getHighResImage(song['image']) ?? '';
                      final isPlaying = audioProvider.currentSong?['id'] == song['id'];

                      return ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(imageUrl: imageUrl, width: 48, height: 48, fit: BoxFit.cover),
                        ),
                        title: Text(
                          song['name'] ?? 'Unknown',
                          style: TextStyle(color: isPlaying ? AppTheme.primary : Colors.white),
                        ),
                        subtitle: Text(song['primaryArtists'] ?? '', style: const TextStyle(color: Colors.white54)),
                        onTap: () {
                          audioProvider.playSong(song, newQueue: _dailyMixSongs);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
