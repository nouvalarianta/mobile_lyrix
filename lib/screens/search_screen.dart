import 'package:flutter/material.dart';
import 'package:lyrix/screens/artist_detail_screen.dart';
import 'package:lyrix/screens/song_detail_screen.dart';
import 'package:lyrix/theme/app_theme.dart';
import 'package:lyrix/services/pocketbase_service.dart';
import 'package:pocketbase/pocketbase.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  bool _isSearching = false;
  String _searchQuery = '';
  List<RecordModel> _filteredSongs = [];
  List<RecordModel> _filteredArtists = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim();
      _isSearching = _searchQuery.isNotEmpty;
    });

    if (_isSearching) {
      _searchMusic(_searchQuery);
    } else {
      setState(() {
        _filteredSongs = [];
        _filteredArtists = [];
      });
    }
  }

  void _searchMusic(String query) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final songsResult = await pb.collection('songs').getList(
            page: 1,
            perPage: 20,
            filter:
                'title ~ "%$query%" || artist ~ "%$query%" || album ~ "%$query%"',
          );

      final artistsResult = await pb.collection('artist').getList(
            page: 1,
            perPage: 20,
            filter: 'name ~ "%$query%"',
          );

      if (mounted) {
        setState(() {
          _filteredSongs = songsResult.items;
          _filteredArtists = artistsResult.items;
          _isLoading = false;
        });
      }
    } on ClientException catch (e) {
      print('PocketBase Client Error during search: ${e.response}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Search failed: ${e.response['message'] ?? 'Unknown error'}')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Unexpected Error during search: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('An unexpected error occurred during search: $e')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search songs, artists...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _isSearching
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppTheme.surfaceColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            if (_searchQuery.isNotEmpty) ...[
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Songs'),
                  Tab(text: 'Artists'),
                ],
                indicatorColor: AppTheme.primaryColor,
                labelColor: AppTheme.primaryColor,
                unselectedLabelColor: Colors.white70,
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _filteredSongs.isEmpty
                              ? const Center(child: Text('No songs found'))
                              : ListView.builder(
                                  itemCount: _filteredSongs.length,
                                  itemBuilder: (context, index) {
                                    final songRecord = _filteredSongs[index];
                                    final imageUrl = songRecord
                                            .getStringValue('image')
                                            .isNotEmpty
                                        ? pb
                                            .getFileUrl(
                                                songRecord,
                                                songRecord
                                                    .getStringValue('image'))
                                            .toString()
                                        : '';
                                    return ListTile(
                                      leading: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: imageUrl.isNotEmpty
                                            ? Image.network(
                                                imageUrl,
                                                width: 50,
                                                height: 50,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error,
                                                    stackTrace) {
                                                  return Container(
                                                    width: 50,
                                                    height: 50,
                                                    color: Colors.grey[800],
                                                    child: const Icon(
                                                        Icons.music_note,
                                                        color: Colors.white),
                                                  );
                                                },
                                              )
                                            : Container(
                                                width: 50,
                                                height: 50,
                                                color: Colors.grey[800],
                                                child: const Icon(
                                                    Icons.music_note,
                                                    color: Colors.white),
                                              ),
                                      ),
                                      title: Text(
                                          songRecord.getStringValue('title')),
                                      subtitle: Text(
                                          songRecord.getStringValue('artist')),
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                SongDetailScreen(
                                                    songRecord: songRecord),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                          _filteredArtists.isEmpty
                              ? const Center(child: Text('No artists found'))
                              : ListView.builder(
                                  itemCount: _filteredArtists.length,
                                  itemBuilder: (context, index) {
                                    final artistRecord =
                                        _filteredArtists[index];
                                    final imageUrl = artistRecord
                                            .getStringValue('imageUrl')
                                            .isNotEmpty
                                        ? pb
                                            .getFileUrl(
                                                artistRecord,
                                                artistRecord
                                                    .getStringValue('imageUrl'))
                                            .toString()
                                        : '';
                                    return ListTile(
                                      leading: CircleAvatar(
                                        radius: 25,
                                        backgroundImage: imageUrl.isNotEmpty
                                            ? NetworkImage(imageUrl)
                                            : null,
                                        onBackgroundImageError:
                                            (exception, stackTrace) {
                                          print(
                                              'Error loading artist image: $exception');
                                        },
                                        child: imageUrl.isEmpty
                                            ? const Icon(Icons.person,
                                                size: 25, color: Colors.white54)
                                            : null,
                                      ),
                                      title: Text(
                                          artistRecord.getStringValue('name')),
                                      subtitle: Text(
                                          '${artistRecord.getIntValue('followers')} followers'),
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                ArtistDetailScreen(
                                                    artistRecord: artistRecord),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                        ],
                      ),
              ),
            ] else ...[
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.search,
                      size: 80,
                      color: Colors.white24,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Search for songs, artists and more',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.white54,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
