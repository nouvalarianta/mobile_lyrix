import 'package:flutter/material.dart';
import 'package:lyrix/services/pocketbase_service.dart';
import 'package:pocketbase/pocketbase.dart';

class AddToPlaylistBottomSheet extends StatefulWidget {
  final RecordModel songToAdd;

  const AddToPlaylistBottomSheet({super.key, required this.songToAdd});

  @override
  State<AddToPlaylistBottomSheet> createState() =>
      _AddToPlaylistBottomSheetState();
}

class _AddToPlaylistBottomSheetState extends State<AddToPlaylistBottomSheet> {
  List<RecordModel> _userPlaylists = [];
  bool _isLoadingPlaylists = true;
  final TextEditingController _newPlaylistController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserPlaylists();
  }

  Future<void> _loadUserPlaylists() async {
    if (!pb.authStore.isValid) {
      if (mounted) {
        setState(() {
          _isLoadingPlaylists = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login untuk mengelola playlist.')),
        );
      }
      return;
    }
    try {
      final playlists = await pb.collection('playlists').getFullList(
            filter: 'createdBy = "${pb.authStore.model?.id}"',
            sort: '-updated',
          );
      if (mounted) {
        setState(() {
          _userPlaylists = playlists;
          _isLoadingPlaylists = false;
        });
      }
    } on ClientException catch (e) {
      print('PocketBase Client Error loading user playlists: ${e.response}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Gagal memuat playlist: ${e.response['message'] ?? e.toString()}')),
        );
        setState(() {
          _isLoadingPlaylists = false;
        });
      }
    } catch (e) {
      print('Unexpected error loading user playlists: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat playlist: $e')),
        );
        setState(() {
          _isLoadingPlaylists = false;
        });
      }
    }
  }

  Future<void> _addSongToPlaylist(RecordModel playlist) async {
    try {
      await pb.collection('detail_playlist').getFirstListItem(
            'playlist_id = "${playlist.id}" && song_id = "${widget.songToAdd.id}"',
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lagu sudah ada di playlist ini!')),
        );
        return;
      }
    } on ClientException catch (e) {
      if (e.statusCode != 404) {
        print('Error checking existing song in playlist: ${e.response}');
      }
    } catch (e) {
      print('Unexpected error checking existing song in playlist: $e');
    }

    try {
      await pb.collection('detail_playlist').create(body: {
        'playlist_id': playlist.id,
        'song_id': widget.songToAdd.id,
        'timestamp': DateTime.now().toIso8601String(),
      });

      final updatedPlaylistRecord =
          await pb.collection('playlists').getOne(playlist.id);
      final currentSongCount = updatedPlaylistRecord.getIntValue('songCount');

      await pb.collection('playlists').update(playlist.id, body: {
        'songCount': currentSongCount + 1,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Lagu "${widget.songToAdd.getStringValue('title')}" ditambahkan ke playlist "${playlist.getStringValue('name')}"')),
        );
        Navigator.pop(context);
      }
    } on ClientException catch (e) {
      print('PocketBase Client Error adding song to playlist: ${e.response}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Gagal menambahkan lagu ke playlist: ${e.response['message'] ?? e.toString()}')),
        );
      }
    } catch (e) {
      print('Unexpected error adding song to playlist: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menambahkan lagu ke playlist: $e')),
        );
      }
    }
  }

  Future<void> _createNewPlaylistAndAddSong() async {
    if (_newPlaylistController.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nama playlist tidak boleh kosong.')),
        );
      }
      return;
    }

    try {
      if (!pb.authStore.isValid || pb.authStore.model == null) {
        throw Exception('User not logged in!');
      }

      final newPlaylistRecord = await pb.collection('playlists').create(body: {
        'name': _newPlaylistController.text.trim(),
        'createdBy': pb.authStore.model!.id,
        'songCount': 1,
        'imageUrl': '',
      });

      await pb.collection('detail_playlist').create(body: {
        'playlist_id': newPlaylistRecord.id,
        'song_id': widget.songToAdd.id,
        'timestamp': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Playlist "${_newPlaylistController.text}" dibuat dan lagu ditambahkan.')),
        );
        Navigator.pop(context);
      }
    } on ClientException catch (e) {
      print('PocketBase Client Error creating new playlist: ${e.response}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Gagal membuat playlist: ${e.response['message'] ?? e.toString()}')),
        );
      }
    } catch (e) {
      print('Error creating new playlist: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuat playlist: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16.0,
        right: 16.0,
        top: 16.0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Tambahkan ke Playlist',
                  style: Theme.of(context).textTheme.titleLarge),
              IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => Navigator.pop(context)),
            ],
          ),
          SizedBox(height: 16),
          TextField(
            controller: _newPlaylistController,
            decoration: InputDecoration(
              hintText: 'Nama Playlist Baru',
              suffixIcon: IconButton(
                icon: Icon(Icons.add),
                onPressed: _createNewPlaylistAndAddSong,
              ),
            ),
          ),
          SizedBox(height: 16),
          Expanded(
            child: _isLoadingPlaylists
                ? Center(child: CircularProgressIndicator())
                : _userPlaylists.isEmpty
                    ? Center(child: Text('Tidak ada playlist. Buat yang baru!'))
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _userPlaylists.length,
                        itemBuilder: (context, index) {
                          final playlist = _userPlaylists[index];
                          final playlistImageUrl =
                              playlist.getStringValue('imageUrl').isNotEmpty
                                  ? pb
                                      .getFileUrl(playlist,
                                          playlist.getStringValue('imageUrl'))
                                      .toString()
                                  : '';
                          return ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: playlistImageUrl.isNotEmpty
                                  ? Image.network(playlistImageUrl,
                                      width: 50, height: 50, fit: BoxFit.cover)
                                  : Container(
                                      width: 50,
                                      height: 50,
                                      color: Colors.grey[800],
                                      child: Icon(Icons.playlist_play,
                                          color: Colors.white)),
                            ),
                            title: Text(playlist.getStringValue('name')),
                            subtitle: Text(
                                '${playlist.getIntValue('songCount')} lagu'),
                            onTap: () => _addSongToPlaylist(playlist),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
