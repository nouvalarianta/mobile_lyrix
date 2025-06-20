import 'package:flutter/material.dart';
import 'package:lyrix/theme/app_theme.dart';
import 'package:lyrix/screens/song_detail_screen.dart';
import 'package:lyrix/services/pocketbase_service.dart';
import 'package:pocketbase/pocketbase.dart';
import 'dart:math';

class LikedSongsScreen extends StatefulWidget {
  const LikedSongsScreen({super.key});

  @override
  State<LikedSongsScreen> createState() => _LikedSongsScreenState();
}

class _LikedSongsScreenState extends State<LikedSongsScreen> {
  bool _isLoading = true;
  List<RecordModel> _likedSongRecords = [];
  List<RecordModel> _filteredSongRecords = [];
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  String _currentSortOption = 'Terbaru Ditambahkan';
  final List<String> _sortOptions = [
    'Terbaru Ditambahkan',
    'Terlama Ditambahkan',
    'Judul (A-Z)',
    'Judul (Z-A)',
    'Artis (A-Z)',
    'Artis (Z-A)',
  ];

  @override
  void initState() {
    super.initState();
    _loadLikedSongs();
    _searchController.addListener(_onSearchChanged);
    pb.authStore.onChange.listen((_) {
      if (mounted) {
        _loadLikedSongs();
      }
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _loadLikedSongs() async {
    if (!pb.authStore.isValid) {
      setState(() {
        _likedSongRecords = [];
        _filteredSongRecords = [];
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });
    try {
      final records = await pb.collection('liked_songs').getFullList(
            filter: 'user = "${pb.authStore.model?.id}"',
            expand: 'song',
            sort: '-created',
          );

      if (mounted) {
        setState(() {
          _likedSongRecords = records;
          _filteredSongRecords = List.from(_likedSongRecords);
          _isLoading = false;
          _sortSongs();
        });
      }
    } on ClientException catch (e) {
      print('PocketBase Client Error fetching liked songs: ${e.response}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Failed to load liked songs: ${e.response['message'] ?? e.toString()}')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Unexpected Error fetching liked songs: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load liked songs: $e')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredSongRecords = List.from(_likedSongRecords);
      } else {
        _filteredSongRecords = _likedSongRecords.where((likedRecord) {
          final song = likedRecord.expand['song']?.first;
          if (song == null) return false;
          return song.getStringValue('title').toLowerCase().contains(query) ||
              song.getStringValue('artist').toLowerCase().contains(query) ||
              song.getStringValue('album').toLowerCase().contains(query);
        }).toList();
      }
      _sortSongs();
    });
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _filteredSongRecords = List.from(_likedSongRecords);
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
        case 'Judul (A-Z)':
          _filteredSongRecords.sort((a, b) => a.expand['song']!.first
              .getStringValue('title')
              .compareTo(b.expand['song']!.first.getStringValue('title')));
          break;
        case 'Judul (Z-A)':
          _filteredSongRecords.sort((a, b) => b.expand['song']!.first
              .getStringValue('title')
              .compareTo(a.expand['song']!.first.getStringValue('title')));
          break;
        case 'Artis (A-Z)':
          _filteredSongRecords.sort((a, b) => a.expand['song']!.first
              .getStringValue('artist')
              .compareTo(b.expand['song']!.first.getStringValue('artist')));
          break;
        case 'Artis (Z-A)':
          _filteredSongRecords.sort((a, b) => b.expand['song']!.first
              .getStringValue('artist')
              .compareTo(a.expand['song']!.first.getStringValue('artist')));
          break;
        case 'Terbaru Ditambahkan':
          _filteredSongRecords.sort((a, b) => b.created.compareTo(a.created));
          break;
        case 'Terlama Ditambahkan':
          _filteredSongRecords.sort((a, b) => a.created.compareTo(b.created));
          break;
      }
    });
  }

  void _playAllSongs() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Memutar semua lagu yang disukai'),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  void _shufflePlay() {
    setState(() {
      _filteredSongRecords.shuffle(Random());
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Memutar secara acak lagu yang disukai'),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: AppTheme.surfaceColor,
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 16.0, bottom: 16.0),
              title: const Text(
                'Liked Songs',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.purple.shade800,
                          AppTheme.backgroundColor,
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    right: -50,
                    bottom: -20,
                    child: Icon(
                      Icons.favorite,
                      size: 200,
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Icon(_isSearching ? Icons.close : Icons.search,
                    color: Colors.white),
                onPressed: _toggleSearch,
              ),
              IconButton(
                icon: const Icon(Icons.sort, color: Colors.white),
                onPressed: _showSortOptions,
              ),
            ],
          ),
          if (_isSearching)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari lagu yang disukai',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: AppTheme.surfaceColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  autofocus: true,
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_likedSongRecords.length} lagu',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _playAllSongs,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Putar Semua'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _shufflePlay,
                        icon: const Icon(Icons.shuffle),
                        label: const Text('Acak'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white24,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(
                  color: AppTheme.primaryColor,
                ),
              ),
            )
          else if (_filteredSongRecords.isEmpty)
            SliverFillRemaining(
              child: _buildEmptyState(),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final likedSongRecord = _filteredSongRecords[index];
                  final song = likedSongRecord.expand['song']?.first;

                  if (song == null) {
                    return const ListTile(title: Text('Lagu tidak ditemukan'));
                  }
                  return _buildSongItem(likedSongRecord, song);
                },
                childCount: _filteredSongRecords.length,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSongItem(RecordModel likedSongRecord, RecordModel songRecord) {
    final String title = songRecord.getStringValue('title');
    final String artist = songRecord.getStringValue('artist');
    final String album = songRecord.getStringValue('album');
    final String imageUrl = songRecord.getStringValue('image').isNotEmpty
        ? pb
            .getFileUrl(songRecord, songRecord.getStringValue('image'))
            .toString()
        : '';
    final String duration = songRecord.getStringValue('duration');

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: 8.0,
      ),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: imageUrl.isNotEmpty
            ? Image.network(
                imageUrl,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 56,
                    height: 56,
                    color: Colors.grey[800],
                    child: const Icon(Icons.music_note, color: Colors.white),
                  );
                },
              )
            : Container(
                width: 56,
                height: 56,
                color: Colors.grey[800],
                child: const Icon(Icons.music_note, color: Colors.white),
              ),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '$artist • $album',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white.withOpacity(0.7),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            duration,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 16),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white70),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'play',
                child: Row(
                  children: [
                    Icon(Icons.play_arrow, size: 20),
                    SizedBox(width: 8),
                    Text('Putar'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'playlist',
                child: Row(
                  children: [
                    Icon(Icons.playlist_add, size: 20),
                    SizedBox(width: 8),
                    Text('Tambahkan ke Playlist'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'unlike',
                child: Row(
                  children: [
                    Icon(Icons.favorite_border, size: 20),
                    SizedBox(width: 8),
                    Text('Hapus dari Disukai'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share, size: 20),
                    SizedBox(width: 8),
                    Text('Bagikan'),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'unlike') {
                _unlikeSong(likedSongRecord);
              }
            },
          ),
        ],
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SongDetailScreen(songRecord: songRecord),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_border,
            size: 80,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            _isSearching
                ? 'Tidak ada lagu yang cocok dengan pencarian Anda'
                : 'Anda belum menyukai lagu apa pun',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (!_isSearching && pb.authStore.isValid)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: const Icon(Icons.explore),
              label: const Text('Jelajahi Musik'),
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

  void _unlikeSong(RecordModel likedSongRecord) async {
    try {
      if (!pb.authStore.isValid) {
        throw Exception('User not authenticated.');
      }
      await pb.collection('liked_songs').delete(likedSongRecord.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Lagu ${likedSongRecord.expand['song']?.first.getStringValue('title') ?? 'Unknown'} dihapus dari daftar yang disukai'),
            backgroundColor: AppTheme.surfaceColor,
            action: SnackBarAction(
              label: 'BATAL',
              textColor: AppTheme.primaryColor,
              onPressed: () {
                _loadLikedSongs();
              },
            ),
          ),
        );
      }
      _loadLikedSongs();
    } on ClientException catch (e) {
      print('PocketBase Client Error unliking song: ${e.response}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Failed to unlike song: ${e.response['message'] ?? e.toString()}')),
        );
      }
    } catch (e) {
      print('Unexpected Error unliking song: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An unexpected error occurred: $e')),
        );
      }
    }
  }
}
