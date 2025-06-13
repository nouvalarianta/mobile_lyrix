import 'package:flutter/material.dart';
import 'package:lyrix/theme/app_theme.dart';
import 'package:lyrix/widgets/animated_play_button.dart';
import 'package:lyrix/services/pocketbase_service.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:just_audio/just_audio.dart';

class SongDetailScreen extends StatefulWidget {
  final RecordModel songRecord;

  const SongDetailScreen({super.key, required this.songRecord});

  @override
  State<SongDetailScreen> createState() => _SongDetailScreenState();
}

class _SongDetailScreenState extends State<SongDetailScreen> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  bool _isLiked = false; // State untuk status disukai/tidak disukai

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

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _loadSongData();
    _checkLikeStatus(); // Periksa status like saat init
    _loadSimilarSongs();
    _audioPlayer.playerStateStream.listen((playerState) {
      final isPlaying = playerState.playing;
      final processingState = playerState.processingState;
      if (mounted) {
        setState(() {
          _isPlaying = isPlaying;
          if (processingState == ProcessingState.completed) {
            _isPlaying = false;
            _audioPlayer.seek(Duration.zero);
          }
        });
      }
    });
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
        try {
          _audioUrl =
              pb.getFileUrl(song, song.getStringValue('audioUrl')).toString();
          _audioPlayer.setAudioSource(AudioSource.uri(Uri.parse(_audioUrl)));
        } catch (e) {
          print('Error setting audio source: $e');
          _audioUrl = '';
        }
      } else {
        _audioUrl = '';
      }
    });
  }

  // Fungsi untuk memeriksa apakah lagu ini sudah disukai oleh pengguna yang login
  void _checkLikeStatus() async {
    if (!pb.authStore.isValid) {
      setState(() {
        _isLiked = false;
      });
      return;
    }
    try {
      await pb.collection('liked_songs').getFirstListItem(
        'user = "${pb.authStore.model?.id}" && song_item = "${widget.songRecord.id}"', // Perbaikan: Gunakan song_item
      );
      if (mounted) {
        setState(() {
          _isLiked = true; // Jika record ditemukan, berarti lagu disukai
        });
      }
    } on ClientException catch (e) {
      if (e.statusCode == 404) {
        if (mounted) {
          setState(() {
            _isLiked = false;
          });
        }
      } else {
        print('Error checking like status: ${e.response}');
        if (mounted) {
          setState(() {
            _isLiked = false;
          });
        }
      }
    } catch (e) {
      print('Unexpected error checking like status: $e');
      if (mounted) {
        setState(() {
          _isLiked = false;
        });
      }
    }
  }

  // Fungsi untuk menambah/menghapus lagu dari daftar yang disukai
  void _toggleLikeStatus() async {
    if (!pb.authStore.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login untuk menyukai lagu!')),
      );
      return;
    }

    setState(() {
      _isLiked = !_isLiked; // Langsung update UI optimistik
    });

    try {
      if (_isLiked) {
        // Jika status baru adalah liked, buat record baru di 'liked_songs'
        await pb.collection('liked_songs').create(body: {
          'user': pb.authStore.model?.id,
          'song_item': widget.songRecord.id, // Perbaikan: Gunakan song_item
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Menyukai ${_title}')),
        );
      } else {
        // Jika status baru adalah unliked, cari record yang sesuai dan hapus
        final likedRecordToDelete = await pb
            .collection('liked_songs')
            .getFirstListItem(
                'user = "${pb.authStore.model?.id}" && song_item = "${widget.songRecord.id}"'); // Perbaikan: Gunakan song_item
        await pb.collection('liked_songs').delete(likedRecordToDelete.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Berhenti menyukai ${_title}')),
        );
      }
    } on ClientException catch (e) {
      print('Error toggling like status: ${e.response}');
      if (mounted) {
        // Rollback UI jika ada error
        setState(() {
          _isLiked = !_isLiked;
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
          _isLiked = !_isLiked;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terjadi kesalahan tak terduga: $e')),
        );
      }
    }
  }

  // Fungsi baru untuk mencatat riwayat pemutaran
  void _recordPlayedHistory(RecordModel songRecord) async {
    if (!pb.authStore.isValid) return; // Hanya catat jika user login

    try {
      // Periksa apakah ada record history yang sama untuk lagu ini oleh user yang sama
      // dalam durasi singkat (misal, 1 menit terakhir) untuk menghindari duplikasi berlebihan.
      // Jika Anda hanya ingin update timestamp dari record terakhir, logic akan lebih kompleks.
      // Untuk kesederhanaan, kita akan selalu membuat record baru untuk setiap play,
      // atau memperbarui timestamp record yang sudah ada jika ditemukan dalam rentang waktu tertentu.

      // Coba cari record terakhir untuk lagu ini oleh user ini.
      // Jika ditemukan, update timestamp-nya. Jika tidak, buat baru.
      RecordModel? existingPlayedRecord;
      try {
        existingPlayedRecord =
            await pb.collection('played_history').getFirstListItem(
                  'user = "${pb.authStore.model?.id}" && song_item = "${songRecord.id}"',
                );
      } on ClientException catch (e) {
        if (e.statusCode != 404) {
          // Abaikan 404, itu normal jika tidak ada history
          print('Error checking existing played history: ${e.response}');
        }
      }

      if (existingPlayedRecord != null) {
        // Jika ada record lama, update timestamp-nya
        await pb
            .collection('played_history')
            .update(existingPlayedRecord.id, body: {
          'timestamp': DateTime.now().toIso8601String(),
        });
        print('Updated play history for ${songRecord.getStringValue('title')}');
      } else {
        // Jika tidak ada record lama, buat yang baru
        await pb.collection('played_history').create(body: {
          'user': pb.authStore.model?.id,
          'song_item': songRecord.id,
          'timestamp': DateTime.now().toIso8601String(),
        });
        print(
            'Created new play history record for ${songRecord.getStringValue('title')}');
      }
    } on ClientException catch (e) {
      print('PocketBase Client Error recording play history: ${e.response}');
    } catch (e) {
      print('Unexpected error recording play history: $e');
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

  void _togglePlayPause() {
    if (_audioUrl.isNotEmpty) {
      if (_isPlaying) {
        _audioPlayer.pause();
      } else {
        _audioPlayer.play();
        _recordPlayedHistory(
            widget.songRecord); // Panggil fungsi pencatat riwayat
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audio not available for this song.')),
      );
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                  // Aksi untuk lebih banyak opsi
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
                      AnimatedPlayButton(
                        size: 64,
                        isPlaying: _isPlaying,
                        onPressed: _togglePlayPause,
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
                    onTap: () {
                      // Navigate to album details
                    },
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
      bottomNavigationBar: Container(
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
              child: _imageUrl.isNotEmpty
                  ? Image.network(
                      _imageUrl,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 56,
                          height: 56,
                          color: Colors.grey[800],
                          child:
                              const Icon(Icons.music_note, color: Colors.white),
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
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Now Playing',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white54,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _title,
                    style: Theme.of(context).textTheme.bodyLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.skip_previous),
              onPressed: () {
                _audioPlayer.seekToPrevious();
              },
            ),
            IconButton(
              icon: Icon(
                _isPlaying
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_filled,
                size: 42,
                color: AppTheme.primaryColor,
              ),
              onPressed: _togglePlayPause,
            ),
            IconButton(
              icon: const Icon(Icons.skip_next),
              onPressed: () {
                _audioPlayer.seekToNext();
              },
            ),
          ],
        ),
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
