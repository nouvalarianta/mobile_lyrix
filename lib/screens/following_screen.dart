import 'package:flutter/material.dart';
import 'package:lyrix/theme/app_theme.dart';
import 'package:lyrix/screens/artist_detail_screen.dart';
import 'package:lyrix/services/pocketbase_service.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:lyrix/screens/popular_artists_screen.dart';

class FollowingScreen extends StatefulWidget {
  const FollowingScreen({super.key});

  @override
  State<FollowingScreen> createState() => _FollowingScreenState();
}

class _FollowingScreenState extends State<FollowingScreen> {
  bool _isLoading = true;
  List<RecordModel> _followedArtists = [];
  List<RecordModel> _filteredArtists = [];
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  String _currentSortOption = 'Terbaru Diikuti';
  final List<String> _sortOptions = [
    'Terbaru Diikuti',
    'Terlama Diikuti',
    'Nama (A-Z)',
    'Nama (Z-A)',
    'Popularitas',
  ];

  @override
  void initState() {
    super.initState();
    _loadFollowedArtists();
    _searchController.addListener(_onSearchChanged);
    pb.authStore.onChange.listen((_) {
      if (mounted) {
        _loadFollowedArtists();
      }
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _loadFollowedArtists() async {
    if (!pb.authStore.isValid) {
      setState(() {
        _followedArtists = [];
        _filteredArtists = [];
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });
    try {
      final records = await pb.collection('following').getFullList(
            filter: 'users = "${pb.authStore.model?.id}"',
            expand: 'artist,users',
            sort: '-created',
          );

      if (mounted) {
        setState(() {
          _followedArtists = records;
          _filteredArtists = List.from(_followedArtists);
          _isLoading = false;
          _sortArtists();
        });
      }
    } on ClientException catch (e) {
      print('PocketBase Client Error fetching followed artists: ${e.response}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Failed to load followed artists: ${e.response['message'] ?? e.toString()}')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Unexpected Error fetching followed artists: $e');
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
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredArtists = List.from(_followedArtists);
      } else {
        _filteredArtists = _followedArtists.where((followedRecord) {
          final artist = followedRecord.expand['artist']?.first;
          if (artist == null) return false;
          return artist.getStringValue('name').toLowerCase().contains(query);
        }).toList();
      }
      _sortArtists();
    });
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _filteredArtists = List.from(_followedArtists);
        _sortArtists();
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
                    color: Colors.white,
                  ),
                ),
              ),
              const Divider(color: Colors.white24),
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
                      title: Text(option,
                          style: const TextStyle(color: Colors.white)),
                      trailing: _currentSortOption == option
                          ? const Icon(Icons.check,
                              color: AppTheme.primaryColor)
                          : null,
                      onTap: () {
                        setState(() {
                          _currentSortOption = option;
                          _sortArtists();
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

  void _sortArtists() {
    setState(() {
      switch (_currentSortOption) {
        case 'Nama (A-Z)':
          _filteredArtists.sort((a, b) => a.expand['artist']!.first
              .getStringValue('name')
              .compareTo(b.expand['artist']!.first.getStringValue('name')));
          break;
        case 'Nama (Z-A)':
          _filteredArtists.sort((a, b) => b.expand['artist']!.first
              .getStringValue('name')
              .compareTo(a.expand['artist']!.first.getStringValue('name')));
          break;
        case 'Popularitas':
          _filteredArtists.sort((a, b) =>
              (b.expand['artist']?.first.getIntValue('monthlyListeners') ?? 0)
                  .compareTo((a.expand['artist']?.first
                          .getIntValue('monthlyListeners') ??
                      0)));
          break;
        case 'Terbaru Diikuti':
          _filteredArtists.sort((a, b) => b.created.compareTo(a.created));
          break;
        case 'Terlama Diikuti':
          _filteredArtists.sort((a, b) => a.created.compareTo(b.created));
          break;
      }
    });
  }

  void _unfollowArtist(RecordModel followedArtistRecord) async {
    final String? recordUserId = followedArtistRecord.expand['users']?.first.id;
    final String? loggedInUserId = pb.authStore.model?.id;

    print('Attempting to unfollow...');
    print('Logged in user ID: $loggedInUserId');
    print('User ID on following record: $recordUserId');

    if (!pb.authStore.isValid ||
        loggedInUserId == null ||
        recordUserId != loggedInUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Anda tidak memiliki izin untuk berhenti mengikuti artis ini. Pastikan Anda login dan ini adalah artis yang Anda ikuti.')),
      );
      return;
    }

    final String artistName =
        followedArtistRecord.expand['artist']?.first.getStringValue('name') ??
            'Unknown Artist';

    try {
      await pb.collection('following').delete(followedArtistRecord.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Berhenti mengikuti ${artistName}'),
            action: SnackBarAction(
              label: 'BATAL',
              textColor: AppTheme.primaryColor,
              onPressed: () async {
                if (!pb.authStore.isValid || pb.authStore.model == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text('Tidak dapat membatalkan: Anda tidak login.')),
                  );
                  return;
                }
                final artistIdToReFollow =
                    followedArtistRecord.expand['artist']?.first.id;
                if (artistIdToReFollow == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Tidak dapat membatalkan: ID artis tidak ditemukan.')),
                  );
                  return;
                }
                try {
                  await pb.collection('following').create(body: {
                    'users': pb.authStore.model!.id,
                    'artist': artistIdToReFollow,
                  });
                  _loadFollowedArtists();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            'Berhasil membatalkan unfollow ${artistName}')),
                  );
                } on ClientException catch (e) {
                  print('Error performing undo follow: ${e.response}');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            'Gagal membatalkan unfollow: ${e.response['message'] ?? e.toString()}')),
                  );
                } catch (e) {
                  print('Unexpected error performing undo follow: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            'Terjadi kesalahan tak terduga saat membatalkan: $e')),
                  );
                }
              },
            ),
          ),
        );
      }
      _loadFollowedArtists();
    } on ClientException catch (e) {
      print('PocketBase Client Error unfollowing artist: ${e.response}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Gagal berhenti mengikuti artis: ${e.response['message'] ?? e.toString()}')),
        );
      }
    } catch (e) {
      print('Unexpected Error unfollowing artist: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terjadi kesalahan tak terduga: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Cari artis...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                ),
                style: const TextStyle(color: Colors.white),
                autofocus: true,
              )
            : const Text('Following', style: TextStyle(color: Colors.white)),
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
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryColor,
              ),
            )
          : _filteredArtists.isEmpty
              ? _buildEmptyState()
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.7,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _filteredArtists.length,
                  itemBuilder: (context, index) {
                    final followedArtistRecord = _filteredArtists[index];
                    final artistRecord =
                        followedArtistRecord.expand['artist']?.first;
                    final userRecord =
                        followedArtistRecord.expand['users']?.first;

                    if (artistRecord == null) {
                      print(
                          'Warning: Artist record not expanded for followedArtistRecord ID: ${followedArtistRecord.id}. Skipping this item.');
                      return const SizedBox.shrink();
                    }
                    return _buildArtistItem(
                        followedArtistRecord, artistRecord, userRecord);
                  },
                ),
    );
  }

  Widget _buildArtistItem(RecordModel followedArtistRecord,
      RecordModel artistRecord, RecordModel? userRecord) {
    final String name = artistRecord.getStringValue('name');
    final String imageUrl = artistRecord.getStringValue('imageUrl').isNotEmpty
        ? pb
            .getFileUrl(artistRecord, artistRecord.getStringValue('imageUrl'))
            .toString()
        : '';
    final int monthlyListeners = artistRecord.getIntValue('monthlyListeners');

    final ImageProvider<Object> avatarImageProvider = imageUrl.isNotEmpty
        ? NetworkImage(imageUrl)
        : const AssetImage('assets/images/default_avatar.png')
            as ImageProvider<Object>;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: AppTheme.surfaceColor,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  ArtistDetailScreen(artistRecord: artistRecord),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: CircleAvatar(
                radius: 50,
                backgroundImage: avatarImageProvider,
                onBackgroundImageError: (exception, stackTrace) {
                  print('Error loading artist image: $exception');
                },
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(monthlyListeners / 1000000).toStringAsFixed(1)}M pendengar bulanan',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.play_circle_filled,
                    color: AppTheme.primaryColor,
                    size: 28,
                  ),
                  onPressed: () {},
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.person_remove_outlined,
                    size: 22,
                    color: Colors.white70,
                  ),
                  onPressed: () => _unfollowArtist(followedArtistRecord),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
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
            Icons.person_outline,
            size: 80,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            _isSearching
                ? 'Tidak ada artis yang cocok dengan pencarian Anda'
                : 'Anda belum mengikuti artis apa pun',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Ikuti artis favorit Anda untuk mendapatkan update terbaru',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.5),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (!_isSearching && pb.authStore.isValid)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const PopularArtistsScreen()),
                );
              },
              icon: const Icon(Icons.explore),
              label: const Text('Jelajahi Artis'),
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
