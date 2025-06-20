import 'package:flutter/material.dart';
import 'package:lyrix/theme/app_theme.dart';
import 'package:lyrix/services/pocketbase_service.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:lyrix/screens/now_playing_screen.dart';
import 'package:lyrix/services/audio_player_service.dart';
import 'package:provider/provider.dart';
import 'package:lyrix/widgets/add_to_playlist_bottom_sheet.dart'
    as playlist_sheet;

class SongDetailScreen extends StatefulWidget {
  final RecordModel songRecord;

  const SongDetailScreen({super.key, required this.songRecord});

  @override
  State<SongDetailScreen> createState() => _SongDetailScreenState();
}

class _SongDetailScreenState extends State<SongDetailScreen> {
  bool _isLiked = false;

  String _title = '';
  String _artist = '';
  String _album = '';
  String _imageUrl = '';
  String _duration = '0:00';
  int _plays = 0;
  int _likes = 0;
  int _releaseYear = 0;
  int _trackNumber = 0;
  String _description = 'No description available.';
  String _audioUrl = '';

  List<RecordModel> _similarSongs = [];

  String? _likedRecordId;

  @override
  void initState() {
    super.initState();

    _loadSongData();
    _checkLikeStatus();
    _loadSimilarSongs();
  }

  void _loadSongData() {
    final song = widget.songRecord;
    setState(() {
      _title = song.getStringValue('title');
      _artist = song.getStringValue('artist');
      _album = song.getStringValue('album');
      _duration = song.getStringValue('duration');
      _plays = song.getIntValue('plays');
      _likes = song.getIntValue('likes');
      _releaseYear = song.getIntValue('releaseYear');
      _trackNumber = song.getIntValue('trackNumber');
      _description = song.getStringValue('description').isEmpty
          ? 'No description available.'
          : song.getStringValue('description');

      if (song.getStringValue('image').isNotEmpty) {
        try {
          _imageUrl =
              pb.getFileUrl(song, song.getStringValue('image')).toString();
        } catch (e) {
          print('Error getting song image URL: $e');
          _imageUrl = '';
        }
      } else {
        _imageUrl = '';
      }

      if (song.getStringValue('audioUrl').isNotEmpty) {
        _audioUrl =
            pb.getFileUrl(song, song.getStringValue('audioUrl')).toString();
      } else {
        _audioUrl = '';
      }
    });
  }

  void _checkLikeStatus() async {
    if (!pb.authStore.isValid) {
      setState(() {
        _isLiked = false;
        _likedRecordId = null;
      });
      return;
    }
    try {
      final likedRecord = await pb.collection('liked_songs').getFirstListItem(
            'user = "${pb.authStore.model?.id}" && song = "${widget.songRecord.id}"',
          );
      if (mounted) {
        setState(() {
          _isLiked = true;
          _likedRecordId = likedRecord.id;
        });
      }
    } on ClientException catch (e) {
      if (e.statusCode == 404) {
        if (mounted) {
          setState(() {
            _isLiked = false;
            _likedRecordId = null;
          });
        }
      } else {
        print('Error checking like status: ${e.response}');
        if (mounted) {
          setState(() {
            _isLiked = false;
            _likedRecordId = null;
          });
        }
      }
    } catch (e) {
      print('Unexpected error checking like status: $e');
      if (mounted) {
        setState(() {
          _isLiked = false;
          _likedRecordId = null;
        });
      }
    }
  }

  void _toggleLikeStatus() async {
    if (!pb.authStore.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login untuk menyukai lagu!')),
      );
      return;
    }

    bool previousLikedStatus = _isLiked;
    setState(() {
      _isLiked = !_isLiked;
    });

    try {
      if (_isLiked) {
        final newLikedRecord = await pb.collection('liked_songs').create(body: {
          'user': pb.authStore.model?.id,
          'song': widget.songRecord.id,
        });
        if (mounted) {
          setState(() {
            _likedRecordId = newLikedRecord.id;
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Menyukai ${_title}')),
        );
      } else {
        if (_likedRecordId != null) {
          await pb.collection('liked_songs').delete(_likedRecordId!);
          if (mounted) {
            setState(() {
              _likedRecordId = null;
            });
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Berhenti menyukai ${_title}')),
          );
        }
      }
    } on ClientException catch (e) {
      print('Error toggling like status: ${e.response}');
      if (mounted) {
        setState(() {
          _isLiked = previousLikedStatus;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Gagal mengubah status suka: ${e.response['message'] ?? 'Unknown error'}')),
        );
      }
    } catch (e) {
      print('Unexpected error toggling like status: $e');
      if (mounted) {
        setState(() {
          _isLiked = previousLikedStatus;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terjadi kesalahan tak terduga: $e')),
        );
      }
    }
  }

  Future<void> _loadSimilarSongs() async {
    try {
      final records = await pb.collection('songs').getFullList(
            filter: 'id != "${widget.songRecord.id}"',
            sort: '-plays',
            batch: 5,
          );
      if (mounted) {
        setState(() {
          _similarSongs = records;
        });
      }
    } catch (e) {
      print('Error fetching similar songs: $e');
    }
  }

  void _playThisSongAndRecordHistory() {
    final audioPlayerService =
        Provider.of<AudioPlayerService>(context, listen: false);
    audioPlayerService.playSong(widget.songRecord);

    if (mounted) {
      Navigator.push(context,
          MaterialPageRoute(builder: (context) => const NowPlayingScreen()));
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
        return playlist_sheet.AddToPlaylistBottomSheet(songToAdd: songToAdd);
      },
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final audioPlayerService = Provider.of<AudioPlayerService>(context);
    final isPlayingGlobal = audioPlayerService.isPlaying &&
        audioPlayerService.currentSong?.id == widget.songRecord.id;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: AppTheme.surfaceColor,
            expandedHeight: 300,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  _isLiked ? Icons.favorite : Icons.favorite_border,
                  color: _isLiked ? AppTheme.primaryColor : Colors.white,
                ),
                onPressed: _toggleLikeStatus,
              ),
              IconButton(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onPressed: () {
                  _showAddToPlaylistDialog(context, widget.songRecord);
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  _imageUrl.isNotEmpty
                      ? Image.network(
                          _imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: AppTheme.surfaceColor,
                              child: const Icon(
                                Icons.music_note,
                                size: 80,
                                color: Colors.white24,
                              ),
                            );
                          },
                        )
                      : Container(
                          color: AppTheme.surfaceColor,
                          child: const Icon(
                            Icons.music_note,
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
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _title,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _artist,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: Colors.white70,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: _playThisSongAndRecordHistory,
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryColor.withOpacity(0.3),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Icon(
                            isPlayingGlobal ? Icons.pause : Icons.play_arrow,
                            size: 32,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(context, '$_plays', 'Plays'),
                      _buildStatItem(context, '$_likes', 'Likes'),
                      _buildStatItem(context, _duration, 'Duration'),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'About',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                        ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 16),
                  Text(
                    'Album',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _imageUrl.isNotEmpty
                          ? Image.network(
                              _imageUrl,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 60,
                                  height: 60,
                                  color: Colors.grey[800],
                                  child: const Icon(Icons.album,
                                      color: Colors.white),
                                );
                              },
                            )
                          : Container(
                              width: 60,
                              height: 60,
                              color: Colors.grey[800],
                              child:
                                  const Icon(Icons.album, color: Colors.white),
                            ),
                    ),
                    title: Text(
                      _album,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    subtitle: Text(
                      '$_releaseYear • $_trackNumber tracks',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.white54),
                    ),
                    trailing:
                        const Icon(Icons.chevron_right, color: Colors.white54),
                    onTap: () {},
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'You might also like',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 220,
                    child: _similarSongs.isEmpty
                        ? const Center(child: Text('No similar songs found.'))
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _similarSongs.length,
                            itemBuilder: (context, index) {
                              final similarSong = _similarSongs[index];
                              final similarImageUrl = similarSong
                                      .getStringValue('image')
                                      .isNotEmpty
                                  ? pb
                                      .getFileUrl(similarSong,
                                          similarSong.getStringValue('image'))
                                      .toString()
                                  : '';
                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => SongDetailScreen(
                                          songRecord: similarSong),
                                    ),
                                  );
                                },
                                child: Container(
                                  width: 160,
                                  margin: const EdgeInsets.only(right: 16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: similarImageUrl.isNotEmpty
                                            ? Image.network(
                                                similarImageUrl,
                                                height: 160,
                                                width: 160,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error,
                                                    stackTrace) {
                                                  return Container(
                                                    height: 160,
                                                    width: 160,
                                                    color: Colors.grey[800],
                                                    child: const Center(
                                                      child: Icon(
                                                        Icons.music_note,
                                                        size: 40,
                                                        color: Colors.white54,
                                                      ),
                                                    ),
                                                  );
                                                },
                                              )
                                            : Container(
                                                height: 160,
                                                width: 160,
                                                color: Colors.grey[800],
                                                child: const Center(
                                                  child: Icon(
                                                    Icons.music_note,
                                                    size: 40,
                                                    color: Colors.white54,
                                                  ),
                                                ),
                                              ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        similarSong.getStringValue('title'),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyLarge,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        similarSong.getStringValue('artist'),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(color: Colors.white54),
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
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Consumer<AudioPlayerService>(
        builder: (context, audioPlayerService, child) {
          final currentSong = audioPlayerService.currentSong;
          if (currentSong == null) {
            return const SizedBox.shrink();
          }

          final imageUrl = currentSong.getStringValue('image').isNotEmpty
              ? pb
                  .getFileUrl(currentSong, currentSong.getStringValue('image'))
                  .toString()
              : '';

          return GestureDetector(
            onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const NowPlayingScreen()));
            },
            child: Container(
              height: 80,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  ClipRRect(
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
                                child: const Icon(Icons.music_note,
                                    color: Colors.white),
                              );
                            },
                          )
                        : Container(
                            width: 56,
                            height: 56,
                            color: Colors.grey[800],
                            child: const Icon(Icons.music_note,
                                color: Colors.white),
                          ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Now Playing',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.white54,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currentSong.getStringValue('title'),
                          style: Theme.of(context).textTheme.bodyLarge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_previous),
                    onPressed: audioPlayerService.seekToPrevious,
                  ),
                  IconButton(
                    icon: Icon(
                      audioPlayerService.isPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_filled,
                      size: 42,
                      color: AppTheme.primaryColor,
                    ),
                    onPressed: audioPlayerService.togglePlayPause,
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next),
                    onPressed: audioPlayerService.seekToNext,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Colors.white70),
        ),
      ],
    );
  }
}
