import 'package:flutter/material.dart';
import 'package:lyrix/theme/app_theme.dart';
import 'package:lyrix/screens/artist_detail_screen.dart';
import 'package:lyrix/services/pocketbase_service.dart'; // Import PocketBase instance
import 'package:pocketbase/pocketbase.dart'; // Import RecordModel

// Hapus imports model lokal dan mock data

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String _searchQuery = '';

  // Data untuk library (sekarang RecordModel)
  List<RecordModel> _playlists = []; // List of RecordModel for playlists
  List<RecordModel> _savedArtists = []; // List of RecordModel for artists
  List<RecordModel> _savedAlbums = []; // List of RecordModel for albums

  // Data yang difilter
  List<RecordModel> _filteredPlaylists = [];
  List<RecordModel> _filteredArtists = [];
  List<RecordModel> _filteredAlbums = [];

  // State untuk sorting
  String _currentSortOption = 'Terbaru';
  final List<String> _sortOptions = ['Terbaru', 'Terlama', 'A-Z', 'Z-A'];

  bool _isLoading = true; // Tambahkan loading state

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController.addListener(_onSearchChanged);

    _loadLibraryData(); // Panggil fungsi untuk memuat data dari PocketBase
  }

  void _loadLibraryData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      // Ambil Playlists (contoh: semua playlist atau playlist milik user)
      // Asumsi: Koleksi 'playlists' ada di PocketBase
      final playlists = await pb.collection('playlists').getFullList(
            sort: '-created',
            // filter: 'createdBy = "${pb.authStore.model?.id}"', // Jika playlist milik user
          );

      // Ambil Artis yang Disimpan (contoh: semua artis, atau artis yang difollow)
      // Asumsi: Koleksi 'artist' ada di PocketBase
      final artists = await pb.collection('artist').getFullList(
            sort:
                '-monthlyListeners', // Contoh: urutkan berdasarkan popularitas
            // Jika Anda punya koleksi 'followed_artists', Anda akan query dari sana dan expand 'artist'
          );

      // Ambil Album yang Disimpan (contoh: semua album)
      // Asumsi: Koleksi 'albums' ada di PocketBase
      final albums = await pb.collection('albums').getFullList(
            sort: '-releaseYear', // Contoh: urutkan berdasarkan tahun rilis
          );

      if (mounted) {
        setState(() {
          _playlists = playlists;
          _savedArtists = artists;
          _savedAlbums = albums;

          // Set data filter awal
          _filteredPlaylists = List.from(_playlists);
          _filteredArtists = List.from(_savedArtists);
          _filteredAlbums = List.from(_savedAlbums);

          _isLoading = false;
          _sortLibraryItems(); // Terapkan pengurutan awal
        });
      }
    } on ClientException catch (e) {
      print('PocketBase Client Error loading library data: ${e.response}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Failed to load library: ${e.response['message'] ?? e.toString()}')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Unexpected Error loading library data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load library: $e')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
      _isSearching = _searchQuery.isNotEmpty;

      if (_isSearching) {
        _filterLibraryItems();
      } else {
        // Reset filter
        _filteredPlaylists = List.from(_playlists);
        _filteredArtists = List.from(_savedArtists);
        _filteredAlbums = List.from(_savedAlbums);
      }
      _sortLibraryItems(); // Terapkan pengurutan setelah filter/reset
    });
  }

  void _filterLibraryItems() {
    final query = _searchQuery.toLowerCase();

    _filteredPlaylists = _playlists
        .where((playlist) =>
            playlist.getStringValue('name').toLowerCase().contains(query))
        .toList();

    _filteredArtists = _savedArtists
        .where((artist) =>
            artist.getStringValue('name').toLowerCase().contains(query))
        .toList();

    _filteredAlbums = _savedAlbums
        .where((album) =>
            album.getStringValue('name').toLowerCase().contains(query) ||
            album
                .getStringValue('artist')
                .toLowerCase()
                .contains(query)) // Asumsi field 'artist' di album
        .toList();
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
              ...List.generate(
                _sortOptions.length,
                (index) => ListTile(
                  title: Text(_sortOptions[index]),
                  trailing: _currentSortOption == _sortOptions[index]
                      ? const Icon(Icons.check, color: AppTheme.primaryColor)
                      : null,
                  onTap: () {
                    setState(() {
                      _currentSortOption = _sortOptions[index];
                      _sortLibraryItems(); // Panggil pengurutan
                    });
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _sortLibraryItems() {
    setState(() {
      switch (_tabController.index) {
        // Urutkan berdasarkan tab aktif
        case 0: // Playlists
          _sortPlaylists();
          break;
        case 1: // Artists
          _sortArtists();
          break;
        case 2: // Albums
          _sortAlbums();
          break;
      }
    });
  }

  void _sortPlaylists() {
    switch (_currentSortOption) {
      case 'A-Z':
        _filteredPlaylists.sort((a, b) =>
            a.getStringValue('name').compareTo(b.getStringValue('name')));
        break;
      case 'Z-A':
        _filteredPlaylists.sort((a, b) =>
            b.getStringValue('name').compareTo(a.getStringValue('name')));
        break;
      case 'Terbaru':
        _filteredPlaylists.sort((a, b) => b.created.compareTo(a.created));
        break;
      case 'Terlama':
        _filteredPlaylists.sort((a, b) => a.created.compareTo(b.created));
        break;
    }
  }

  void _sortArtists() {
    switch (_currentSortOption) {
      case 'A-Z':
        _filteredArtists.sort((a, b) =>
            a.getStringValue('name').compareTo(b.getStringValue('name')));
        break;
      case 'Z-A':
        _filteredArtists.sort((a, b) =>
            b.getStringValue('name').compareTo(a.getStringValue('name')));
        break;
      case 'Terbaru':
        _filteredArtists.sort((a, b) => b.created.compareTo(a.created));
        break;
      case 'Terlama':
        _filteredArtists.sort((a, b) => a.created.compareTo(b.created));
        break;
      case 'Popularitas':
        _filteredArtists.sort((a, b) => b
            .getIntValue('monthlyListeners')
            .compareTo(a.getIntValue('monthlyListeners')));
        break;
    }
  }

  void _sortAlbums() {
    switch (_currentSortOption) {
      case 'A-Z':
        _filteredAlbums.sort((a, b) =>
            a.getStringValue('name').compareTo(b.getStringValue('name')));
        break;
      case 'Z-A':
        _filteredAlbums.sort((a, b) =>
            b.getStringValue('name').compareTo(a.getStringValue('name')));
        break;
      case 'Terbaru':
        _filteredAlbums.sort((a, b) => b.created.compareTo(a.created));
        break;
      case 'Terlama':
        _filteredAlbums.sort((a, b) => a.created.compareTo(b.created));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Your Library',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () {
                          setState(() {
                            _isSearching = !_isSearching;
                            if (!_isSearching) {
                              _searchController.clear();
                              _filterLibraryItems(); // Reset filter saat search ditutup
                            }
                          });
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.sort),
                        onPressed: _showSortOptions,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_isSearching)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari di library Anda',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppTheme.surfaceColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Playlists'),
                Tab(text: 'Artists'),
                Tab(text: 'Albums'),
              ],
              indicatorColor: AppTheme.primaryColor,
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: Colors.white70,
            ),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppTheme.primaryColor),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        // Tab Playlists
                        _buildPlaylistsTab(),

                        // Tab Artists
                        _buildArtistsTab(),

                        // Tab Albums
                        _buildAlbumsTab(),
                      ],
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Implementasi untuk menambahkan item baru ke library
          _showAddToLibraryDialog();
        },
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildPlaylistsTab() {
    if (_filteredPlaylists.isEmpty) {
      return _buildEmptyState('Tidak ada playlist yang ditemukan');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredPlaylists.length,
      itemBuilder: (context, index) {
        final playlist = _filteredPlaylists[index];
        return _buildPlaylistItem(playlist);
      },
    );
  }

  Widget _buildPlaylistItem(RecordModel playlist) {
    // Ubah tipe menjadi RecordModel
    final String name = playlist.getStringValue('name');
    final String imageUrl = playlist
            .getStringValue('imageUrl')
            .isNotEmpty // Asumsi field 'imageUrl'
        ? pb
            .getFileUrl(playlist, playlist.getStringValue('imageUrl'))
            .toString()
        : '';
    final int songCount =
        playlist.getIntValue('songCount'); // Asumsi field 'songCount'
    final String createdBy =
        playlist.getStringValue('createdBy'); // Asumsi field 'createdBy'

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: AppTheme.surfaceColor,
      child: InkWell(
        onTap: () {
          // Navigasi ke detail playlist
          // Anda mungkin perlu membuat PlaylistDetailScreen baru
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
                      height: 140,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 140,
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
                      height: 140,
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
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$songCount lagu • Dibuat oleh $createdBy',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppTheme.primaryColor,
                        radius: 16,
                        child: const Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Putar Semua',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(
                          Icons.more_vert,
                          size: 20,
                        ),
                        onPressed: () {
                          // Tampilkan opsi playlist
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArtistsTab() {
    if (_filteredArtists.isEmpty) {
      return _buildEmptyState('Tidak ada artis yang ditemukan');
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _filteredArtists.length,
      itemBuilder: (context, index) {
        final artistRecord = _filteredArtists[index]; // Ambil RecordModel
        return _buildArtistItem(artistRecord); // Teruskan RecordModel
      },
    );
  }

  Widget _buildArtistItem(RecordModel artistRecord) {
    // Ubah tipe menjadi RecordModel
    final String name = artistRecord.getStringValue('name');
    final String imageUrl = artistRecord.getStringValue('imageUrl').isNotEmpty
        ? pb
            .getFileUrl(artistRecord, artistRecord.getStringValue('imageUrl'))
            .toString()
        : '';
    final int followers =
        artistRecord.getIntValue('followers'); // Asumsi field 'followers'

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
              builder: (context) => ArtistDetailScreen(
                  artistRecord: artistRecord), // Teruskan RecordModel
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 50,
              backgroundImage:
                  imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
              onBackgroundImageError: (exception, stackTrace) {
                print('Error loading artist image: $exception');
              },
              child: imageUrl.isEmpty
                  ? const Icon(
                      Icons.person,
                      size: 50,
                      color: Colors.white54,
                    )
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '$followers pengikut',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlbumsTab() {
    if (_filteredAlbums.isEmpty) {
      return _buildEmptyState('Tidak ada album yang ditemukan');
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _filteredAlbums.length,
      itemBuilder: (context, index) {
        final album = _filteredAlbums[index];
        return _buildAlbumItem(album);
      },
    );
  }

  Widget _buildAlbumItem(RecordModel album) {
    // Ubah tipe menjadi RecordModel
    final String name = album.getStringValue('name');
    final String artist =
        album.getStringValue('artist'); // Asumsi field 'artist' di album
    final String imageUrl =
        album.getStringValue('imageUrl').isNotEmpty // Asumsi field 'imageUrl'
            ? pb.getFileUrl(album, album.getStringValue('imageUrl')).toString()
            : '';
    final int releaseYear =
        album.getIntValue('releaseYear'); // Asumsi field 'releaseYear'
    final int songCount =
        album.getIntValue('songCount'); // Asumsi field 'songCount'

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: AppTheme.surfaceColor,
      child: InkWell(
        onTap: () {
          // Navigasi ke detail album
          // Anda mungkin perlu membuat AlbumDetailScreen baru
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
                              Icons.album,
                              size: 36,
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
                          Icons.album,
                          size: 36,
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      artist,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.7),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$releaseYear • $songCount lagu',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.library_music,
            size: 80,
            color: Colors.white24,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (!_isSearching)
            ElevatedButton(
              onPressed: () {
                _showAddToLibraryDialog();
              },
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
              child: const Text('Tambahkan Item'),
            ),
        ],
      ),
    );
  }

  void _showAddToLibraryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Tambahkan ke Library'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  const Icon(Icons.playlist_add, color: AppTheme.primaryColor),
              title: const Text('Buat Playlist Baru'),
              onTap: () {
                Navigator.pop(context);
                // Implementasi untuk membuat playlist baru
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.person_add, color: AppTheme.primaryColor),
              title: const Text('Ikuti Artis'),
              onTap: () {
                Navigator.pop(context);
                // Implementasi untuk mengikuti artis
                // Mungkin navigasi ke SearchScreen atau Discover Artists
              },
            ),
            ListTile(
              leading: const Icon(Icons.album, color: AppTheme.primaryColor),
              title: const Text('Simpan Album'),
              onTap: () {
                Navigator.pop(context);
                // Implementasi untuk menyimpan album
              },
            ),
          ],
        ),
      ),
    );
  }
}
