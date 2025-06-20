import 'package:flutter/material.dart';
import 'package:lyrix/theme/app_theme.dart';
import 'package:lyrix/screens/artist_detail_screen.dart';
import 'package:lyrix/services/pocketbase_service.dart';
import 'package:pocketbase/pocketbase.dart';

class PopularArtistsScreen extends StatefulWidget {
  const PopularArtistsScreen({super.key});

  @override
  State<PopularArtistsScreen> createState() => _PopularArtistsScreenState();
}

class _PopularArtistsScreenState extends State<PopularArtistsScreen> {
  bool _isLoading = true;
  List<RecordModel> _popularArtists = [];
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  List<RecordModel> _filteredArtists = [];

  String _currentSortOption = 'Popularitas';
  final List<String> _sortOptions = [
    'Popularitas',
    'Nama (A-Z)',
    'Nama (Z-A)',
    'Pengikut (Terbanyak)',
    'Pengikut (Tersedikit)',
  ];

  final Map<String, Map<String, dynamic>> _artistFollowStatus = {};

  @override
  void initState() {
    super.initState();
    _loadPopularArtists();
    _searchController.addListener(_onSearchChanged);

    pb.authStore.onChange.listen((_) {
      if (mounted) {
        _checkFollowStatusForAllArtists();
      }
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _loadPopularArtists() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final artists = await pb.collection('artist').getFullList(
            sort: '-monthlyListeners',
          );

      if (mounted) {
        setState(() {
          _popularArtists = artists;
          _filteredArtists = List.from(_popularArtists);
          _isLoading = false;
          _sortArtists();
        });
        _checkFollowStatusForAllArtists();
      }
    } on ClientException catch (e) {
      print('PocketBase Client Error fetching popular artists: ${e.response}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Failed to load popular artists: ${e.response['message'] ?? 'Unknown error'}')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Unexpected Error fetching popular artists: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load popular artists: $e')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _checkFollowStatusForAllArtists() async {
    if (!pb.authStore.isValid || _popularArtists.isEmpty) {
      if (mounted) {
        setState(() {
          _artistFollowStatus.clear();
          for (var artist in _popularArtists) {
            _artistFollowStatus[artist.id] = {
              'isFollowing': false,
              'followRecordId': null
            };
          }
        });
      }
      return;
    }

    final String currentUserId = pb.authStore.model!.id;
    for (var artist in _popularArtists) {
      try {
        final followRecord = await pb.collection('following').getFirstListItem(
              'users = "$currentUserId" && artist = "${artist.id}"',
            );
        if (mounted) {
          setState(() {
            _artistFollowStatus[artist.id] = {
              'isFollowing': true,
              'followRecordId': followRecord.id
            };
          });
        }
      } on ClientException catch (e) {
        if (e.statusCode == 404) {
          if (mounted) {
            setState(() {
              _artistFollowStatus[artist.id] = {
                'isFollowing': false,
                'followRecordId': null
              };
            });
          }
        } else {
          print('Error checking follow status for ${artist.id}: ${e.response}');
          if (mounted) {
            setState(() {
              _artistFollowStatus[artist.id] = {
                'isFollowing': false,
                'followRecordId': null
              };
            });
          }
        }
      } catch (e) {
        print('Unexpected error checking follow status for ${artist.id}: $e');
        if (mounted) {
          setState(() {
            _artistFollowStatus[artist.id] = {
              'isFollowing': false,
              'followRecordId': null
            };
          });
        }
      }
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredArtists = List.from(_popularArtists);
      } else {
        _filteredArtists = _popularArtists
            .where((artist) =>
                artist.getStringValue('name').toLowerCase().contains(query))
            .toList();
      }
      _sortArtists();
    });
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _filteredArtists = List.from(_popularArtists);
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
        case 'Popularitas':
          _filteredArtists.sort((a, b) => b
              .getIntValue('monthlyListeners')
              .compareTo(a.getIntValue('monthlyListeners')));
          break;
        case 'Nama (A-Z)':
          _filteredArtists.sort((a, b) =>
              a.getStringValue('name').compareTo(b.getStringValue('name')));
          break;
        case 'Nama (Z-A)':
          _filteredArtists.sort((a, b) =>
              b.getStringValue('name').compareTo(a.getStringValue('name')));
          break;
        case 'Pengikut (Terbanyak)':
          _filteredArtists.sort((a, b) =>
              b.getIntValue('followers').compareTo(a.getIntValue('followers')));
          break;
        case 'Pengikut (Tersedikit)':
          _filteredArtists.sort((a, b) =>
              a.getIntValue('followers').compareTo(b.getIntValue('followers')));
          break;
      }
    });
  }

  void _toggleFollowStatus(RecordModel artistRecord) async {
    if (!pb.authStore.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login untuk mengikuti artis!')),
      );
      return;
    }

    final String artistId = artistRecord.id;
    bool isCurrentlyFollowing =
        _artistFollowStatus[artistId]?['isFollowing'] ?? false;
    String? followRecordId = _artistFollowStatus[artistId]?['followRecordId'];
    int currentFollowers = artistRecord.getIntValue('followers');
    String artistName = artistRecord.getStringValue('name');

    setState(() {
      _artistFollowStatus[artistId] = {
        'isFollowing': !isCurrentlyFollowing,
        'followRecordId': followRecordId
      };
      if (!isCurrentlyFollowing) {
        artistRecord.data['followers'] = currentFollowers + 1;
      } else {
        artistRecord.data['followers'] = currentFollowers - 1;
      }
    });

    try {
      if (!isCurrentlyFollowing) {
        final newFollowRecord = await pb.collection('following').create(body: {
          'users': pb.authStore.model!.id,
          'artist': artistId,
        });
        if (mounted) {
          setState(() {
            _artistFollowStatus[artistId]!['followRecordId'] =
                newFollowRecord.id;
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mengikuti $artistName')),
        );
      } else {
        if (followRecordId != null) {
          await pb.collection('following').delete(followRecordId);
          if (mounted) {
            setState(() {
              _artistFollowStatus[artistId]!['followRecordId'] = null;
            });
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Berhenti mengikuti $artistName')),
          );
        }
      }

      await pb.collection('artist').update(artistId, body: {
        'followers': artistRecord.getIntValue('followers'),
      });
    } on ClientException catch (e) {
      print('Error toggling follow status for $artistName: ${e.response}');

      if (mounted) {
        setState(() {
          _artistFollowStatus[artistId] = {
            'isFollowing': isCurrentlyFollowing,
            'followRecordId': followRecordId
          };
          artistRecord.data['followers'] = currentFollowers;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Gagal mengubah status follow: ${e.response['message'] ?? 'Unknown error'}')),
        );
      }
    } catch (e) {
      print('Unexpected error toggling follow status for $artistName: $e');

      if (mounted) {
        setState(() {
          _artistFollowStatus[artistId] = {
            'isFollowing': isCurrentlyFollowing,
            'followRecordId': followRecordId
          };
          artistRecord.data['followers'] = currentFollowers;
        });
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
                  hintText: 'Cari artis populer...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                ),
                style: const TextStyle(color: Colors.white),
                autofocus: true,
              )
            : const Text('Popular Artists',
                style: TextStyle(color: Colors.white)),
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
                    childAspectRatio: 0.9,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _filteredArtists.length,
                  itemBuilder: (context, index) {
                    final artistRecord = _filteredArtists[index];
                    return _buildArtistItem(artistRecord, index);
                  },
                ),
    );
  }

  Widget _buildArtistItem(RecordModel artistRecord, int index) {
    final String name = artistRecord.getStringValue('name');
    final String imageUrl = artistRecord.getStringValue('imageUrl').isNotEmpty
        ? pb
            .getFileUrl(artistRecord, artistRecord.getStringValue('imageUrl'))
            .toString()
        : '';

    final int followers = artistRecord.getIntValue('followers');

    final bool isFollowing =
        _artistFollowStatus[artistRecord.id]?['isFollowing'] ?? false;

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
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    radius: 38,
                    backgroundImage: avatarImageProvider,
                    onBackgroundImageError: (exception, stackTrace) {
                      print('Error loading artist image: $exception');
                    },
                  ),
                  if (index < 3)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.backgroundColor,
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        '${followers} pengikut',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 9,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.play_circle_filled,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                                Text('Play artist music not implemented yet.')),
                      );
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 30,
                      minHeight: 30,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      isFollowing
                          ? Icons.person_remove_outlined
                          : Icons.person_add_outlined,
                      size: 16,
                      color:
                          isFollowing ? AppTheme.primaryColor : Colors.white70,
                    ),
                    onPressed: () => _toggleFollowStatus(artistRecord),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 30,
                      minHeight: 30,
                    ),
                  ),
                ],
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
            Icons.people_outline,
            size: 80,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            _isSearching
                ? 'Tidak ada artis yang cocok dengan pencarian Anda'
                : 'Tidak ada artis populer saat ini',
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
                _loadPopularArtists();
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
