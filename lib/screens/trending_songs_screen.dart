import 'package:flutter/material.dart';
import 'package:lyrix/theme/app_theme.dart';
import 'package:lyrix/screens/song_detail_screen.dart';
import 'package:lyrix/services/pocketbase_service.dart';
import 'package:pocketbase/pocketbase.dart';

class TrendingSongsScreen extends StatefulWidget {
  const TrendingSongsScreen({super.key});

  @override
  State<TrendingSongsScreen> createState() => _TrendingSongsScreenState();
}

class _TrendingSongsScreenState extends State<TrendingSongsScreen> {
  bool _isLoading = true;
  List<RecordModel> _trendingSongs = [];
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  List<RecordModel> _filteredSongs = [];

  String _currentSortOption = 'Popularitas';
  final List<String> _sortOptions = [
    'Popularitas',
    'Terbaru',
    'Judul (A-Z)',
    'Judul (Z-A)',
    'Artis (A-Z)',
    'Artis (Z-A)',
  ];

  @override
  void initState() {
    super.initState();
    _loadTrendingSongs();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _loadTrendingSongs() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final songs = await pb.collection('songs').getFullList(
            sort: '-plays',
          );

      if (mounted) {
        setState(() {
          _trendingSongs = songs;
          _filteredSongs = List.from(_trendingSongs);
          _isLoading = false;
          _sortSongs();
        });
      }
    } on ClientException catch (e) {
      print('PocketBase Client Error fetching trending songs: ${e.response}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Failed to load trending songs: ${e.response['message'] ?? e.toString()}')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Unexpected Error fetching trending songs: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An unexpected error occurred: $e')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredSongs = List.from(_trendingSongs);
      } else {
        _filteredSongs = _trendingSongs
            .where((song) =>
                song.getStringValue('title').toLowerCase().contains(query) ||
                song.getStringValue('artist').toLowerCase().contains(query) ||
                song.getStringValue('album').toLowerCase().contains(query))
            .toList();
      }
      _sortSongs();
    });
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _filteredSongs = List.from(_trendingSongs);
        _sortSongs();
      }
    });
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Urutkan Berdasarkan',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _sortOptions.length,
                  itemBuilder: (context, index) {
                    final option = _sortOptions[index];
                    return ListTile(
                      title: Text(option),
                      trailing: _currentSortOption == option
                          ? const Icon(Icons.check,
                              color: AppTheme.primaryColor)
                          : null,
                      onTap: () {
                        setState(() {
                          _currentSortOption = option;
                          _sortSongs();
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _sortSongs() {
    setState(() {
      switch (_currentSortOption) {
        case 'Popularitas':
          _filteredSongs.sort((a, b) =>
              b.getIntValue('plays').compareTo(a.getIntValue('plays')));
          break;
        case 'Terbaru':
          _filteredSongs.sort((a, b) => b
              .getIntValue('releaseYear')
              .compareTo(a.getIntValue('releaseYear')));
          break;
        case 'Judul (A-Z)':
          _filteredSongs.sort((a, b) =>
              a.getStringValue('title').compareTo(b.getStringValue('title')));
          break;
        case 'Judul (Z-A)':
          _filteredSongs.sort((a, b) =>
              b.getStringValue('title').compareTo(a.getStringValue('title')));
          break;
        case 'Artis (A-Z)':
          _filteredSongs.sort((a, b) =>
              a.getStringValue('artist').compareTo(b.getStringValue('artist')));
          break;
        case 'Artis (Z-A)':
          _filteredSongs.sort((a, b) =>
              b.getStringValue('artist').compareTo(a.getStringValue('artist')));
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Cari lagu trending...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                ),
                style: const TextStyle(color: Colors.white),
                autofocus: true,
              )
            : const Text('Trending Songs'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
          ),
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: _showSortOptions,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryColor,
              ),
            )
          : _filteredSongs.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredSongs.length,
                  itemBuilder: (context, index) {
                    final songRecord = _filteredSongs[index];
                    return _buildSongItem(songRecord, index);
                  },
                ),
    );
  }

  Widget _buildSongItem(RecordModel songRecord, int index) {
    final String title = songRecord.getStringValue('title');
    final String artist = songRecord.getStringValue('artist');
    final String imageUrl = songRecord.getStringValue('image').isNotEmpty
        ? pb
            .getFileUrl(songRecord, songRecord.getStringValue('image'))
            .toString()
        : '';
    final int plays = songRecord.getIntValue('plays');
    final int likes = songRecord.getIntValue('likes');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppTheme.surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SongDetailScreen(songRecord: songRecord),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Container(
                width: 30,
                alignment: Alignment.center,
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: index < 3 ? AppTheme.primaryColor : Colors.white70,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 60,
                            height: 60,
                            color: Colors.grey[800],
                            child: const Icon(Icons.music_note,
                                color: Colors.white),
                          );
                        },
                      )
                    : Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey[800],
                        child:
                            const Icon(Icons.music_note, color: Colors.white),
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      artist,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.headphones,
                          size: 14,
                          color: Colors.white54,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${(plays / 1000000).toStringAsFixed(1)}M',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.favorite,
                          size: 14,
                          color: Colors.white54,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${(likes / 1000).toStringAsFixed(0)}K',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.play_circle_filled,
                  color: AppTheme.primaryColor,
                  size: 36,
                ),
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.trending_up,
            size: 80,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            _isSearching
                ? 'Tidak ada lagu yang cocok dengan pencarian Anda'
                : 'Tidak ada lagu trending saat ini',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (!_isSearching)
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                });
                _loadTrendingSongs();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Muat Ulang'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
