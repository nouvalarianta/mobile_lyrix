import 'package:flutter/material.dart';
import 'package:lyrix/services/pocketbase_service.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:lyrix/theme/app_theme.dart'; // Menambahkan import untuk AppTheme

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

  @override
  void dispose() {
    _newPlaylistController.dispose();
    super.dispose();
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
    // Tampilkan loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      ),
    );

    try {
      // Cek apakah lagu sudah ada
      await pb.collection('detail_playlist').getFirstListItem(
            'playlist_id = "${playlist.id}" && song_id = "${widget.songToAdd.id}"',
          );

      if (mounted) {
        Navigator.pop(context); // Hapus loading indicator
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lagu sudah ada di playlist ini!')),
        );
        return;
      }
    } on ClientException catch (e) {
      // Jika error bukan 404 (Not Found), berarti ada masalah lain.
      if (e.statusCode != 404) {
        print('Error checking existing song in playlist: ${e.response}');
        if (mounted) Navigator.pop(context); // Hapus loading indicator
        return;
      }
      // Jika 404, berarti lagu belum ada. Lanjutkan proses penambahan.
    } catch (e) {
      print('Unexpected error checking existing song in playlist: $e');
      if (mounted) Navigator.pop(context); // Hapus loading indicator
      return;
    }

    try {
      // Tambahkan lagu ke detail_playlist
      await pb.collection('detail_playlist').create(body: {
        'playlist_id': playlist.id,
        'song_id': widget.songToAdd.id,
        'timestamp': DateTime.now().toIso8601String(),
      });

      // Update jumlah lagu di collection playlists
      final currentSongCount = playlist.getIntValue('songCount');
      await pb.collection('playlists').update(playlist.id, body: {
        'songCount': currentSongCount + 1,
      });

      if (mounted) {
        Navigator.pop(context); // Hapus loading indicator
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Lagu "${widget.songToAdd.getStringValue('title')}" ditambahkan ke playlist "${playlist.getStringValue('name')}"')),
        );
        Navigator.pop(context); // Tutup bottom sheet
      }
    } on ClientException catch (e) {
      print('PocketBase Client Error adding song to playlist: ${e.response}');
      if (mounted) {
        Navigator.pop(context); // Hapus loading indicator
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Gagal menambahkan lagu: ${e.response['message'] ?? e.toString()}')),
        );
      }
    } catch (e) {
      print('Unexpected error adding song to playlist: $e');
      if (mounted) {
        Navigator.pop(context); // Hapus loading indicator
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menambahkan lagu: $e')),
        );
      }
    }
  }

  Future<void> _createNewPlaylistAndAddSong() async {
    final newPlaylistName = _newPlaylistController.text.trim();
    if (newPlaylistName.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nama playlist tidak boleh kosong.')),
        );
      }
      return;
    }

    // Tampilkan loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      ),
    );

    try {
      if (!pb.authStore.isValid || pb.authStore.model == null) {
        throw Exception('User not logged in!');
      }

      // Buat playlist baru
      final newPlaylistRecord = await pb.collection('playlists').create(body: {
        'name': newPlaylistName,
        'createdBy': pb.authStore.model!.id,
        'songCount': 1, // Langsung set 1 karena lagu pertama ditambahkan
        'imageUrl': '',
      });

      // Tambahkan lagu ke playlist yang baru dibuat
      await pb.collection('detail_playlist').create(body: {
        'playlist_id': newPlaylistRecord.id,
        'song_id': widget.songToAdd.id,
        'timestamp': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        Navigator.pop(context); // Hapus loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Playlist "$newPlaylistName" dibuat dan lagu ditambahkan.')),
        );
        Navigator.pop(context); // Tutup bottom sheet
      }
    } on ClientException catch (e) {
      print('PocketBase Client Error creating new playlist: ${e.response}');
      if (mounted) {
        Navigator.pop(context); // Hapus loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Gagal membuat playlist: ${e.response['message'] ?? e.toString()}')),
        );
      }
    } catch (e) {
      print('Error creating new playlist: $e');
      if (mounted) {
        Navigator.pop(context); // Hapus loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuat playlist: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Padding untuk keyboard
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        // Memberi batasan tinggi maksimal untuk BottomSheet
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Tambahkan ke Playlist',
                    style: Theme.of(context).textTheme.titleLarge),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _newPlaylistController,
              decoration: InputDecoration(
                hintText: 'Nama Playlist Baru',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add_circle,
                      color: AppTheme.primaryColor),
                  onPressed: _createNewPlaylistAndAddSong,
                ),
              ),
            ),
            const Divider(height: 32),
            // -- PERUBAHAN DI SINI --
            // Widget Expanded dihapus
            if (_isLoadingPlaylists)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_userPlaylists.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
                    child: Text('Tidak ada playlist. Buat yang baru di atas!')),
              )
            else
              // ListView sekarang dibungkus Flexible agar bisa di-scroll di dalam Column
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true, // shrinkWrap tetap diperlukan
                  itemCount: _userPlaylists.length,
                  itemBuilder: (context, index) {
                    final playlist = _userPlaylists[index];
                    final playlistImageUrl = playlist
                            .getStringValue('imageUrl')
                            .isNotEmpty
                        ? pb
                            .getFileUrl(
                                playlist, playlist.getStringValue('imageUrl'))
                            .toString()
                        : '';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: playlistImageUrl.isNotEmpty
                            ? Image.network(playlistImageUrl,
                                width: 50, height: 50, fit: BoxFit.cover)
                            : Container(
                                width: 50,
                                height: 50,
                                color: Colors.grey[800],
                                child: const Icon(Icons.playlist_play,
                                    color: Colors.white)),
                      ),
                      title: Text(playlist.getStringValue('name')),
                      subtitle:
                          Text('${playlist.getIntValue('songCount')} lagu'),
                      onTap: () => _addSongToPlaylist(playlist),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
