import 'package:flutter/material.dart';
import 'package:lyrix/theme/app_theme.dart';
import 'package:lyrix/services/pocketbase_service.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:lyrix/screens/playlist_detail_screen.dart';
import 'package:lyrix/services/audio_player_service.dart';
import 'package:provider/provider.dart';
import 'package:lyrix/screens/now_playing_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class PlaylistsScreen extends StatefulWidget {
  const PlaylistsScreen({super.key});

  @override
  State<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends State<PlaylistsScreen> {
  bool _isLoading = true;
  List<RecordModel> _playlists = [];
  List<RecordModel> _filteredPlaylists = [];
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  XFile? _dialogPickedXFile;
  String? _dialogCurrentImageUrl;

  String _currentSortOption = 'Terbaru Dibuat';
  final List<String> _sortOptions = [
    'Terbaru Dibuat',
    'Terlama Dibuat',
    'Nama (A-Z)',
    'Nama (Z-A)',
    'Jumlah Lagu (Terbanyak)',
    'Jumlah Lagu (Tersedikit)',
  ];

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
    _searchController.addListener(_onSearchChanged);
    pb.authStore.onChange.listen((_) {
      if (mounted) {
        _loadPlaylists();
      }
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _loadPlaylists() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final playlists = await pb.collection('playlists').getFullList(
            sort: '-created',
            expand: 'createdBy',
          );

      if (mounted) {
        setState(() {
          _playlists = playlists;
          _filteredPlaylists = List.from(_playlists);
          _isLoading = false;
          _sortPlaylists();
        });
      }
    } on ClientException catch (e) {
      print('PocketBase Client Error fetching playlists: ${e.response}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Failed to load playlists: ${e.response['message'] ?? e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Unexpected Error fetching playlists: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An unexpected error occurred: $e'),
            backgroundColor: Colors.red,
          ),
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
        _filteredPlaylists = List.from(_playlists);
      } else {
        _filteredPlaylists = _playlists.where((playlist) {
          final playlistName = playlist.getStringValue('name').toLowerCase();
          final createdByName = playlist.expand['createdBy']?.first
                  .getStringValue('name')
                  .toLowerCase() ??
              '';
          return playlistName.contains(query) || createdByName.contains(query);
        }).toList();
      }
      _sortPlaylists();
    });
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _filteredPlaylists = List.from(_playlists);
        _sortPlaylists();
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
                          _sortPlaylists();
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

  void _sortPlaylists() {
    setState(() {
      switch (_currentSortOption) {
        case 'Nama (A-Z)':
          _filteredPlaylists.sort((a, b) =>
              a.getStringValue('name').compareTo(b.getStringValue('name')));
          break;
        case 'Nama (Z-A)':
          _filteredPlaylists.sort((a, b) =>
              b.getStringValue('name').compareTo(a.getStringValue('name')));
          break;
        case 'Jumlah Lagu (Terbanyak)':
          _filteredPlaylists.sort((a, b) =>
              b.getIntValue('songCount').compareTo(a.getIntValue('songCount')));
          break;
        case 'Jumlah Lagu (Tersedikit)':
          _filteredPlaylists.sort((a, b) =>
              a.getIntValue('songCount').compareTo(b.getIntValue('songCount')));
          break;
        case 'Terbaru Dibuat':
          _filteredPlaylists.sort((a, b) => b.created.compareTo(a.created));
          break;
        case 'Terlama Dibuat':
          _filteredPlaylists.sort((a, b) => a.created.compareTo(b.created));
          break;
      }
    });
  }

  Future<void> _getImageForPlaylist(
      ImageSource source, Function setInnerState) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 80);

    if (pickedFile != null) {
      setInnerState(() {
        _dialogPickedXFile = pickedFile;
        _dialogCurrentImageUrl = null;
      });
    }
  }

  void _showImageSourceDialogForPlaylist(Function setInnerState) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Pilih Sumber Gambar',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  const Icon(Icons.photo_camera, color: AppTheme.primaryColor),
              title:
                  const Text('Kamera', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _getImageForPlaylist(ImageSource.camera, setInnerState);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.photo_library, color: AppTheme.primaryColor),
              title:
                  const Text('Galeri', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _getImageForPlaylist(ImageSource.gallery, setInnerState);
              },
            ),
            if (_dialogCurrentImageUrl != null || _dialogPickedXFile != null)
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text('Hapus Gambar',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  setInnerState(() {
                    _dialogPickedXFile = null;
                    _dialogCurrentImageUrl = null;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text('Gambar playlist akan dihapus saat disimpan'),
                      backgroundColor: AppTheme.surfaceColor,
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  void _createNewPlaylist() {
    final TextEditingController playlistNameController =
        TextEditingController();
    setState(() {
      _dialogPickedXFile = null;
      _dialogCurrentImageUrl = null;
    });

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setInnerState) {
          ImageProvider? imageProvider;
          if (_dialogPickedXFile != null) {
            imageProvider = FileImage(File(_dialogPickedXFile!.path));
          } else {
            imageProvider =
                const AssetImage('assets/images/default_playlist.png');
          }

          return AlertDialog(
            backgroundColor: AppTheme.surfaceColor,
            title: const Text('Buat Playlist Baru',
                style: TextStyle(color: Colors.white)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () async {
                      _showImageSourceDialogForPlaylist(setInnerState);
                    },
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: AppTheme.surfaceColor,
                      backgroundImage: imageProvider,
                      child: (imageProvider is AssetImage &&
                                  imageProvider.assetName ==
                                      'assets/images/default_playlist.png') &&
                              _dialogPickedXFile == null
                          ? const Icon(Icons.add_photo_alternate,
                              size: 40, color: Colors.white70)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: playlistNameController,
                    decoration: InputDecoration(
                      hintText: 'Nama Playlist',
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      hintStyle: const TextStyle(color: Colors.white60),
                    ),
                    style: const TextStyle(color: Colors.white),
                    autofocus: true,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal',
                    style: TextStyle(color: AppTheme.primaryColor)),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  if (playlistNameController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Nama playlist tidak boleh kosong!'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const AlertDialog(
                      backgroundColor: AppTheme.surfaceColor,
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                              color: AppTheme.primaryColor),
                          SizedBox(height: 16),
                          Text('Membuat playlist...',
                              style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                  );

                  try {
                    if (!pb.authStore.isValid || pb.authStore.model == null) {
                      throw Exception('User not logged in to create playlist!');
                    }

                    final Map<String, dynamic> body = {
                      'name': playlistNameController.text.trim(),
                      'createdBy': pb.authStore.model!.id,
                      'songCount': 0,
                    };

                    final List<http.MultipartFile> files = [];
                    if (_dialogPickedXFile != null) {
                      final fileBytes = await _dialogPickedXFile!.readAsBytes();
                      final fileName = _dialogPickedXFile!.name;
                      final fileExtension = fileName.split('.').last;
                      final contentType = MediaType('image', fileExtension);

                      files.add(
                        http.MultipartFile.fromBytes(
                          'imageUrl',
                          fileBytes,
                          filename: fileName,
                          contentType: contentType,
                        ),
                      );
                    }

                    await pb.collection('playlists').create(
                          body: body,
                          files: files,
                        );

                    if (mounted) Navigator.pop(context);

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Playlist "${playlistNameController.text}" berhasil dibuat!'),
                          backgroundColor: AppTheme.primaryColor,
                        ),
                      );
                    }
                    _loadPlaylists();
                  } on ClientException catch (e) {
                    if (mounted) Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Gagal membuat playlist: ${e.response['message'] ?? 'Terjadi kesalahan.'}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  } catch (e) {
                    if (mounted) Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Terjadi kesalahan tak terduga: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Buat'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _deletePlaylist(RecordModel playlistRecord) async {
    if (!pb.authStore.isValid ||
        playlistRecord.expand['createdBy']?.first.id !=
            pb.authStore.model?.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Anda tidak memiliki izin untuk menghapus playlist ini.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Hapus Playlist?',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'Apakah Anda yakin ingin menghapus playlist "${playlistRecord.getStringValue('name')}"? Ini akan menghapus semua lagu di dalamnya juga.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal',
                style: TextStyle(color: AppTheme.primaryColor)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppTheme.primaryColor),
            SizedBox(height: 16),
            Text('Menghapus playlist...',
                style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );

    try {
      final detailRecordsToDelete =
          await pb.collection('detail_playlist').getFullList(
                filter: 'playlist_id = "${playlistRecord.id}"',
                batch: 100,
              );
      for (var record in detailRecordsToDelete) {
        await pb.collection('detail_playlist').delete(record.id);
      }

      await pb.collection('playlists').delete(playlistRecord.id);

      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Playlist "${playlistRecord.getStringValue('name')}" berhasil dihapus.'),
            backgroundColor: AppTheme.primaryColor,
          ),
        );
        _loadPlaylists();
      }
    } on ClientException catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Gagal menghapus playlist: ${e.response['message'] ?? 'Terjadi kesalahan.'}'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Terjadi kesalahan tak terduga saat menghapus: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _editPlaylist(RecordModel playlistRecord) {
    if (!pb.authStore.isValid ||
        playlistRecord.expand['createdBy']?.first.id !=
            pb.authStore.model?.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Anda tidak memiliki izin untuk mengedit playlist ini.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final TextEditingController nameController =
        TextEditingController(text: playlistRecord.getStringValue('name'));
    setState(() {
      _dialogPickedXFile = null;
      _dialogCurrentImageUrl =
          playlistRecord.getStringValue('imageUrl').isNotEmpty
              ? pb
                  .getFileUrl(
                      playlistRecord, playlistRecord.getStringValue('imageUrl'))
                  .toString()
              : null;
    });

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setInnerState) {
          ImageProvider? imageProvider;
          if (_dialogPickedXFile != null) {
            imageProvider = FileImage(File(_dialogPickedXFile!.path));
          } else if (_dialogCurrentImageUrl != null) {
            imageProvider = NetworkImage(_dialogCurrentImageUrl!);
          } else {
            imageProvider =
                const AssetImage('assets/images/default_playlist.png');
          }

          return AlertDialog(
            backgroundColor: AppTheme.surfaceColor,
            title: const Text('Edit Playlist',
                style: TextStyle(color: Colors.white)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () async {
                      _showImageSourceDialogForPlaylist(setInnerState);
                    },
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: AppTheme.surfaceColor,
                      backgroundImage: imageProvider,
                      child: (imageProvider is AssetImage &&
                              imageProvider.assetName ==
                                  'assets/images/default_playlist.png' &&
                              _dialogPickedXFile == null)
                          ? const Icon(Icons.add_photo_alternate,
                              size: 40, color: Colors.white70)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      hintText: 'Nama Playlist',
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      hintStyle: const TextStyle(color: Colors.white60),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal',
                    style: TextStyle(color: AppTheme.primaryColor)),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  if (nameController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Nama playlist tidak boleh kosong.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const AlertDialog(
                      backgroundColor: AppTheme.surfaceColor,
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                              color: AppTheme.primaryColor),
                          SizedBox(height: 16),
                          Text('Menyimpan perubahan...',
                              style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                  );

                  try {
                    final Map<String, dynamic> body = {
                      'name': nameController.text.trim(),
                    };

                    final List<http.MultipartFile> files = [];
                    if (_dialogPickedXFile != null) {
                      final fileBytes = await _dialogPickedXFile!.readAsBytes();
                      final fileName = _dialogPickedXFile!.name;
                      final fileExtension = fileName.split('.').last;
                      final contentType = MediaType('image', fileExtension);

                      files.add(
                        http.MultipartFile.fromBytes(
                          'imageUrl',
                          fileBytes,
                          filename: fileName,
                          contentType: contentType,
                        ),
                      );
                    } else if (_dialogCurrentImageUrl == null &&
                        playlistRecord.getStringValue('imageUrl').isNotEmpty) {
                      files.add(
                        http.MultipartFile.fromString(
                          'imageUrl',
                          '',
                        ),
                      );
                    }

                    await pb
                        .collection('playlists')
                        .update(playlistRecord.id, body: body, files: files);

                    if (mounted) Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Playlist "${nameController.text}" berhasil diperbarui.'),
                        backgroundColor: AppTheme.primaryColor,
                      ),
                    );
                    _loadPlaylists();
                  } on ClientException catch (e) {
                    if (mounted) Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Gagal memperbarui playlist: ${e.response['message'] ?? 'Terjadi kesalahan.'}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  } catch (e) {
                    if (mounted) Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Terjadi kesalahan tak terduga saat memperbarui: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Simpan'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _playPlaylistFromListItem(RecordModel playlistRecord) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppTheme.primaryColor),
            SizedBox(height: 16),
            Text('Memuat lagu...', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );

    try {
      final detailRecords = await pb.collection('detail_playlist').getFullList(
            filter: 'playlist_id = "${playlistRecord.id}"',
            expand: 'song_id',
            sort: 'timestamp',
          );

      List<RecordModel> songsToPlay = [];
      for (var detailRecord in detailRecords) {
        if (detailRecord.expand['song_id']?.isNotEmpty == true) {
          songsToPlay.add(detailRecord.expand['song_id']!.first);
        }
      }

      if (mounted) Navigator.pop(context);

      final audioPlayerService =
          Provider.of<AudioPlayerService>(context, listen: false);

      if (songsToPlay.isNotEmpty) {
        audioPlayerService.playPlaylist(songsToPlay);
        if (mounted) {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const NowPlayingScreen()));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Playlist ini kosong. Tidak ada lagu untuk diputar.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } on ClientException catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Gagal memuat lagu playlist: ${e.response['message'] ?? 'Terjadi kesalahan.'}'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Terjadi kesalahan tak terduga saat memuat lagu: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
                  hintText: 'Cari playlist...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                ),
                style: const TextStyle(color: Colors.white),
                autofocus: true,
              )
            : const Text('Your Playlists',
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
          : _filteredPlaylists.isEmpty
              ? _buildEmptyState()
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.68,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _filteredPlaylists.length,
                  itemBuilder: (context, index) {
                    final playlistRecord = _filteredPlaylists[index];
                    return _buildPlaylistItem(playlistRecord);
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewPlaylist,
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildPlaylistItem(RecordModel playlistRecord) {
    final String name = playlistRecord.getStringValue('name');
    final String imageUrl = playlistRecord.getStringValue('imageUrl').isNotEmpty
        ? pb
            .getFileUrl(
                playlistRecord, playlistRecord.getStringValue('imageUrl'))
            .toString()
        : '';
    final int songCount = playlistRecord.getIntValue('songCount');
    final String createdByName =
        playlistRecord.expand['createdBy']?.first.getStringValue('name') ??
            'Unknown User';

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
                  PlaylistDetailScreen(playlistRecord: playlistRecord),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      height: 110,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 110,
                          color: Colors.grey[800],
                          child: const Center(
                            child: Icon(
                              Icons.playlist_play,
                              size: 50,
                              color: Colors.white54,
                            ),
                          ),
                        );
                      },
                    )
                  : Container(
                      height: 110,
                      color: Colors.grey[800],
                      child: const Center(
                        child: Icon(
                          Icons.playlist_play,
                          size: 50,
                          color: Colors.white54,
                        ),
                      ),
                    ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$songCount lagu',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Oleh $createdByName',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 4.0),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.primaryColor,
                    radius: 14,
                    child: IconButton(
                      icon: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 16,
                      ),
                      onPressed: () =>
                          _playPlaylistFromListItem(playlistRecord),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert,
                      size: 18,
                      color: Colors.white70,
                    ),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: const [
                            Icon(Icons.edit, size: 20, color: Colors.white70),
                            SizedBox(width: 8),
                            Text('Edit Playlist',
                                style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: const [
                            Icon(Icons.delete_forever,
                                size: 20, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Hapus Playlist',
                                style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'edit') {
                        _editPlaylist(playlistRecord);
                      } else if (value == 'delete') {
                        _deletePlaylist(playlistRecord);
                      }
                    },
                  ),
                ],
              ),
            ),
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
            Icons.playlist_play,
            size: 80,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            _isSearching
                ? 'Tidak ada playlist yang cocok dengan pencarian Anda'
                : 'Anda belum memiliki playlist',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Buat playlist untuk mengorganisir lagu favorit Anda',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.5),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _createNewPlaylist,
            icon: const Icon(Icons.add),
            label: const Text('Buat Playlist Baru'),
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
