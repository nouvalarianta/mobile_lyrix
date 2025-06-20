import 'package:flutter/material.dart';
import 'package:lyrix/theme/app_theme.dart';
import 'package:lyrix/services/pocketbase_service.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:lyrix/services/audio_player_service.dart';
import 'package:provider/provider.dart';
import 'package:lyrix/screens/now_playing_screen.dart';
import 'package:lyrix/widgets/add_to_playlist_bottom_sheet.dart';

class ArtistDetailScreen extends StatefulWidget {
  final RecordModel artistRecord;

  const ArtistDetailScreen({super.key, required this.artistRecord});

  @override
  State<ArtistDetailScreen> createState() => _ArtistDetailScreenState();
}

class _ArtistDetailScreenState extends State<ArtistDetailScreen> {
  bool _isFollowing = false;
  bool _isLoading = true;
  List<RecordModel> _artistSongs = [];

  String _artistName = '';
  String _artistImageUrl = '';
  int _followers = 0;
  int _monthlyListeners = 0;
  int _topTracksCount = 0;
  String _bio = 'No biography available.';

  String? _followingRecordId;

  @override
  void initState() {
    super.initState();
    _loadArtistData();
    _checkAndLoadData();
    pb.authStore.onChange.listen((_) {
      if (mounted) {
        _checkFollowStatus();
      }
    });
  }

  void _checkAndLoadData() async {
    setState(() {
      _isLoading = true;
    });
    _checkFollowStatus();
    await _loadArtistSongs();
    setState(() {
      _isLoading = false;
    });
  }

  void _loadArtistData() {
    final artist = widget.artistRecord;
    setState(() {
      _artistName = artist.getStringValue('name');
      _followers = artist.getIntValue('followers');
      _monthlyListeners = artist.getIntValue('monthlyListeners');
      _topTracksCount = artist.getIntValue('topTracks');
      _bio = artist.getStringValue('bio').isNotEmpty
          ? artist.getStringValue('bio')
          : 'No biography available.';

      if (artist.getStringValue('imageUrl').isNotEmpty) {
        try {
          _artistImageUrl = pb
              .getFileUrl(artist, artist.getStringValue('imageUrl'))
              .toString();
        } catch (e) {
          print('Error getting artist image URL: $e');
          _artistImageUrl = '';
        }
      } else {
        _artistImageUrl = '';
      }
    });
  }

  void _checkFollowStatus() async {
    if (!pb.authStore.isValid) {
      if (mounted) {
        setState(() {
          _isFollowing = false;
          _followingRecordId = null;
        });
      }
      return;
    }
    try {
      final followRecord = await pb.collection('following').getFirstListItem(
            'users = "${pb.authStore.model?.id}" && artist = "${widget.artistRecord.id}"',
          );
      if (mounted) {
        setState(() {
          _isFollowing = true;
          _followingRecordId = followRecord.id;
        });
      }
    } on ClientException catch (e) {
      if (e.statusCode == 404) {
        if (mounted) {
          setState(() {
            _isFollowing = false;
            _followingRecordId = null;
          });
        }
      } else {
        print('Error checking follow status: ${e.response}');
        if (mounted) {
          setState(() {
            _isFollowing = false;
            _followingRecordId = null;
          });
        }
      }
    } catch (e) {
      print('Unexpected error checking follow status: $e');
      if (mounted) {
        setState(() {
          _isFollowing = false;
        });
      }
    }
  }

  void _toggleFollowStatus() async {
    if (!pb.authStore.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login untuk mengikuti artis!')),
      );
      return;
    }

    bool previousFollowingStatus = _isFollowing;
    int previousFollowers = _followers;

    setState(() {
      _isFollowing = !_isFollowing;
      if (_isFollowing) {
        _followers++;
      } else {
        _followers--;
      }
    });

    try {
      if (_isFollowing) {
        final newFollowRecord = await pb.collection('following').create(body: {
          'users': pb.authStore.model?.id,
          'artist': widget.artistRecord.id,
        });
        if (mounted) {
          setState(() {
            _followingRecordId = newFollowRecord.id;
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mengikuti ${_artistName}')),
        );
      } else {
        if (_followingRecordId != null) {
          await pb.collection('following').delete(_followingRecordId!);
          if (mounted) {
            setState(() {
              _followingRecordId = null;
            });
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Berhenti mengikuti ${_artistName}')),
          );
        }
      }

      await pb.collection('artist').update(widget.artistRecord.id, body: {
        'followers': _followers,
      });
    } on ClientException catch (e) {
      print('Error toggling follow status: ${e.response}');
      if (mounted) {
        setState(() {
          _isFollowing = previousFollowingStatus;
          _followers = previousFollowers;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Gagal mengubah status follow: ${e.response['message'] ?? 'Unknown error'}')),
        );
      }
    } catch (e) {
      print('Unexpected error toggling follow status: $e');
      if (mounted) {
        setState(() {
          _isFollowing = previousFollowingStatus;
          _followers = previousFollowers;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terjadi kesalahan tak terduga: $e')),
        );
      }
    }
  }

  Future<void> _loadArtistSongs() async {
    try {
      final songs = await pb.collection('songs').getFullList(
            filter: 'artist = "${widget.artistRecord.getStringValue('name')}"',
            sort: '-plays',
            batch: 10,
          );

      if (mounted) {
        setState(() {
          _artistSongs = songs;
        });
      }
    } on ClientException catch (e) {
      print('PocketBase Client Error fetching artist songs: ${e.response}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Failed to load artist songs: ${e.response['message'] ?? 'Unknown error'}')),
        );
      }
    } catch (e) {
      print('Unexpected Error fetching artist songs: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load artist songs: $e')),
        );
      }
    }
  }

  void _showAddToPlaylistDialog(BuildContext context, RecordModel songToAdd) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return AddToPlaylistBottomSheet(songToAdd: songToAdd);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: AppTheme.surfaceColor,
            expandedHeight: 280,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onPressed: () {},
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                _artistName,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              centerTitle: true,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  _artistImageUrl.isNotEmpty
                      ? Image.network(
                          _artistImageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: AppTheme.surfaceColor,
                              child: const Icon(
                                Icons.person,
                                size: 80,
                                color: Colors.white24,
                              ),
                            );
                          },
                        )
                      : Container(
                          color: AppTheme.surfaceColor,
                          child: const Icon(
                            Icons.person,
                            size: 80,
                            color: Colors.white24,
                          ),
                        ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          AppTheme.backgroundColor.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _artistName,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$_followers followers',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Colors.white70,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _toggleFollowStatus,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isFollowing
                              ? Colors.white24
                              : AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                            side: _isFollowing
                                ? const BorderSide(color: Colors.white70)
                                : BorderSide.none,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                        ),
                        child: Text(_isFollowing ? 'Following' : 'Follow'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(context, '$_followers', 'Followers'),
                      _buildStatItem(
                          context, '$_monthlyListeners', 'Monthly Listeners'),
                      _buildStatItem(context, '$_topTracksCount', 'Top Tracks'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Biography',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _bio,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white70,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Popular Songs',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                ),
                      ),
                      TextButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'See All Songs feature not implemented yet.')),
                          );
                        },
                        child: const Text('See All',
                            style: TextStyle(color: AppTheme.primaryColor)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _isLoading && _artistSongs.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: CircularProgressIndicator(
                                color: AppTheme.primaryColor),
                          ),
                        )
                      : _artistSongs.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Text(
                                  'No popular songs available for this artist.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: Colors.white54,
                                      ),
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: EdgeInsets.zero,
                              itemCount: _artistSongs.length > 5
                                  ? 5
                                  : _artistSongs.length,
                              itemBuilder: (context, index) {
                                final songRecord = _artistSongs[index];
                                final songImageUrl = songRecord
                                        .getStringValue('image')
                                        .isNotEmpty
                                    ? pb
                                        .getFileUrl(songRecord,
                                            songRecord.getStringValue('image'))
                                        .toString()
                                    : '';
                                return ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: songImageUrl.isNotEmpty
                                        ? Image.network(
                                            songImageUrl,
                                            width: 50,
                                            height: 50,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              return Container(
                                                width: 50,
                                                height: 50,
                                                color: Colors.grey[800],
                                                child: const Icon(
                                                    Icons.music_note,
                                                    color: Colors.white,
                                                    size: 20),
                                              );
                                            },
                                          )
                                        : Container(
                                            width: 50,
                                            height: 50,
                                            color: Colors.grey[800],
                                            child: const Icon(Icons.music_note,
                                                color: Colors.white, size: 20),
                                          ),
                                  ),
                                  title: Text(
                                    songRecord.getStringValue('title'),
                                    style: const TextStyle(
                                        fontSize: 14, color: Colors.white),
                                  ),
                                  subtitle: Text(
                                    '${songRecord.getStringValue('artist')} • ${songRecord.getIntValue('plays')} plays',
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.white70),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.more_vert,
                                        size: 20, color: Colors.white70),
                                    onPressed: () {
                                      _showSongOptionsMenu(context, songRecord);
                                    },
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                  onTap: () {
                                    Provider.of<AudioPlayerService>(context,
                                            listen: false)
                                        .playSong(songRecord);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const NowPlayingScreen(),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                  const SizedBox(height: 16),
                  Text(
                    'Albums',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                        ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 160,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: 5,
                      itemBuilder: (context, index) {
                        return Container(
                          width: 120,
                          margin: const EdgeInsets.only(right: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  height: 120,
                                  color: Colors.grey[800],
                                  child: const Center(
                                    child: Icon(Icons.album,
                                        size: 36, color: Colors.white54),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Album ${index + 1}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      fontSize: 12,
                                      color: Colors.white,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '2023',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      fontSize: 10,
                                      color: Colors.white70,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white70,
              ),
        ),
      ],
    );
  }

  void _showSongOptionsMenu(BuildContext context, RecordModel songRecord) {
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
              ListTile(
                leading: const Icon(Icons.queue_music, color: Colors.white),
                title: const Text('Add to Queue',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            '${songRecord.getStringValue('title')} added to queue')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.playlist_add, color: Colors.white),
                title: const Text('Add to Playlist',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _showAddToPlaylistDialog(context, songRecord);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share, color: Colors.white),
                title: const Text('Share Song',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text('Share functionality not implemented yet.')),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
