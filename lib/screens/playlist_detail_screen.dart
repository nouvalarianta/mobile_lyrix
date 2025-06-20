import 'package:flutter/material.dart';
import 'package:lyrix/theme/app_theme.dart';
import 'package:lyrix/services/pocketbase_service.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:lyrix/services/audio_player_service.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'package:lyrix/screens/now_playing_screen.dart';
import 'package:lyrix/widgets/add_to_playlist_bottom_sheet.dart';

class PlaylistDetailScreen extends StatefulWidget {
  final RecordModel playlistRecord;

  const PlaylistDetailScreen({super.key, required this.playlistRecord});

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  bool _isLoadingSongs = true;
  List<RecordModel> _songsInPlaylist = [];

  List<RecordModel> _expandedSongs = [];

  String _playlistName = '';
  String _playlistImageUrl = '';
  String _createdBy = 'Unknown User';
  int _songCount = 0;

  @override
  void initState() {
    super.initState();
    _loadPlaylistDetails();
    _loadSongsInPlaylist();

    pb.collection('detail_playlist').subscribe('*', (e) {
      if (mounted) {
        _loadSongsInPlaylist();
      }
    });
  }

  void _loadPlaylistDetails() {
    final playlist = widget.playlistRecord;
    setState(() {
      _playlistName = playlist.getStringValue('name');
      _createdBy = playlist.getStringValue('createdBy').isNotEmpty
          ? playlist.getStringValue('createdBy')
          : 'Unknown User';
      _songCount = playlist.getIntValue('songCount');

      if (playlist.getStringValue('imageUrl').isNotEmpty) {
        try {
          _playlistImageUrl = pb
              .getFileUrl(playlist, playlist.getStringValue('imageUrl'))
              .toString();
        } catch (e) {
          print('Error getting playlist image URL: $e');
          _playlistImageUrl = '';
        }
      } else {
        _playlistImageUrl = '';
      }
    });
  }

  Future<void> _loadSongsInPlaylist() async {
    setState(() {
      _isLoadingSongs = true;
    });
    try {
      final detailRecords = await pb.collection('detail_playlist').getFullList(
            filter: 'playlist_id = "${widget.playlistRecord.id}"',
            expand: 'song_id',
            sort: 'timestamp',
          );

      List<RecordModel> songs = [];
      for (var detailRecord in detailRecords) {
        if (detailRecord.expand['song_id']?.isNotEmpty == true) {
          songs.add(detailRecord.expand['song_id']!.first);
        }
      }

      if (mounted) {
        setState(() {
          _songsInPlaylist = detailRecords;
          _expandedSongs = songs;
          _isLoadingSongs = false;
          _songCount = _expandedSongs.length;
        });
      }
    } on ClientException catch (e) {
      print('PocketBase Client Error fetching playlist songs: ${e.response}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Failed to load playlist songs: ${e.response['message'] ?? e.toString()}')),
        );
        setState(() {
          _isLoadingSongs = false;
        });
      }
    } catch (e) {
      print('Unexpected Error fetching playlist songs: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An unexpected error occurred: $e')),
        );
        setState(() {
          _isLoadingSongs = false;
        });
      }
    }
  }

  void _playPlaylist() {
    final audioPlayerService =
        Provider.of<AudioPlayerService>(context, listen: false);
    if (_expandedSongs.isNotEmpty) {
      audioPlayerService.playPlaylist(_expandedSongs);
      Navigator.push(context,
          MaterialPageRoute(builder: (context) => const NowPlayingScreen()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Playlist ini kosong.')),
      );
    }
  }

  void _shufflePlaylist() {
    final audioPlayerService =
        Provider.of<AudioPlayerService>(context, listen: false);
    if (_expandedSongs.isNotEmpty) {
      List<RecordModel> shuffledSongs = List.from(_expandedSongs);
      shuffledSongs.shuffle(Random());
      audioPlayerService.playPlaylist(shuffledSongs);
      Navigator.push(context,
          MaterialPageRoute(builder: (context) => const NowPlayingScreen()));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Memutar playlist secara acak')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Playlist ini kosong.')),
      );
    }
  }

  void _removeSongFromPlaylist(RecordModel detailPlaylistRecord) async {
    if (!pb.authStore.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login untuk mengelola playlist.')),
      );
      return;
    }

    try {
      await pb.collection('detail_playlist').delete(detailPlaylistRecord.id);

      final updatedPlaylist =
          await pb.collection('playlists').getOne(widget.playlistRecord.id);
      await pb.collection('playlists').update(widget.playlistRecord.id, body: {
        'songCount': updatedPlaylist.getIntValue('songCount') - 1,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Lagu dihapus dari playlist "${widget.playlistRecord.getStringValue('name')}"')),
        );
        _loadSongsInPlaylist();
        _loadPlaylistDetails();
      }
    } on ClientException catch (e) {
      print(
          'PocketBase Client Error removing song from playlist: ${e.response}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Gagal menghapus lagu: ${e.response['message'] ?? e.toString()}')),
        );
      }
    } catch (e) {
      print('Unexpected Error removing song from playlist: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terjadi kesalahan tak terduga: $e')),
        );
      }
    }
  }

  void _showAddToAnotherPlaylistDialog(
      BuildContext context, RecordModel songToAdd) {
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
            expandedHeight: 320,
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
              centerTitle: true,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  _playlistImageUrl.isNotEmpty
                      ? Image.network(
                          _playlistImageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                            color: Colors.grey[800],
                            child: Icon(Icons.playlist_play,
                                size: 100, color: Colors.white24),
                          ),
                        )
                      : Container(
                          color: Colors.grey[800],
                          child: Icon(Icons.playlist_play,
                              size: 100, color: Colors.white24),
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
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _playlistName,
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Dibuat oleh $_createdBy • $_songCount lagu',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton.icon(
                    onPressed: _playPlaylist,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Putar Playlist'),
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
                  IconButton(
                    icon: const Icon(Icons.shuffle, color: Colors.white70),
                    onPressed: _shufflePlaylist,
                  ),
                ],
              ),
            ),
          ),
          _isLoadingSongs
              ? const SliverFillRemaining(
                  child: Center(
                    child:
                        CircularProgressIndicator(color: AppTheme.primaryColor),
                  ),
                )
              : _expandedSongs.isEmpty
                  ? SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Center(
                          child: Column(
                            children: [
                              const SizedBox(height: 40),
                              Icon(Icons.music_note,
                                  size: 80, color: Colors.white24),
                              const SizedBox(height: 16),
                              Text('Playlist ini kosong.',
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              Text('Tambahkan lagu untuk mulai mendengarkan.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(color: Colors.white70)),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: () {},
                                icon: const Icon(Icons.add),
                                label: const Text('Tambahkan Lagu'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final song = _expandedSongs[index];

                          final detailRecord = _songsInPlaylist.firstWhere(
                            (rec) => rec.expand['song_id']?.first.id == song.id,
                            orElse: () => null as RecordModel,
                          );

                          final imageUrl =
                              song.getStringValue('image').isNotEmpty
                                  ? pb
                                      .getFileUrl(
                                          song, song.getStringValue('image'))
                                      .toString()
                                  : '';
                          return ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: imageUrl.isNotEmpty
                                  ? Image.network(imageUrl,
                                      width: 60, height: 60, fit: BoxFit.cover)
                                  : Container(
                                      width: 60,
                                      height: 60,
                                      color: Colors.grey[800],
                                      child: Icon(Icons.music_note,
                                          color: Colors.white)),
                            ),
                            title: Text(song.getStringValue('title')),
                            subtitle: Text(song.getStringValue('artist')),
                            trailing: PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert,
                                  color: Colors.white70),
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'remove',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete, size: 20),
                                      SizedBox(width: 8),
                                      Text('Hapus dari Playlist'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'addToAnother',
                                  child: Row(
                                    children: [
                                      Icon(Icons.playlist_add, size: 20),
                                      SizedBox(width: 8),
                                      Text('Tambahkan ke Playlist Lain'),
                                    ],
                                  ),
                                ),
                              ],
                              onSelected: (value) {
                                if (value == 'remove') {
                                  if (detailRecord != null) {
                                    _removeSongFromPlaylist(detailRecord);
                                  } else {
                                    print(
                                        'Error: Detail record not found for song ${song.id}');
                                  }
                                } else if (value == 'addToAnother') {
                                  _showAddToAnotherPlaylistDialog(
                                      context, song);
                                }
                              },
                            ),
                            onTap: () {
                              final audioPlayerService =
                                  Provider.of<AudioPlayerService>(context,
                                      listen: false);
                              audioPlayerService.playPlaylist(_expandedSongs);
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const NowPlayingScreen()));
                            },
                          );
                        },
                        childCount: _expandedSongs.length,
                      ),
                    ),
        ],
      ),
    );
  }
}
