import 'package:flutter/material.dart';
import 'package:lyrix/theme/app_theme.dart';
import 'package:lyrix/data/mock_data.dart';

class PlaylistsScreen extends StatefulWidget {
  const PlaylistsScreen({super.key});

  @override
  State<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends State<PlaylistsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _playlists = [];
  List<Map<String, dynamic>> _filteredPlaylists = [];
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  // Opsi pengurutan
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
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _loadPlaylists() {
    // Simulasi loading data
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          // Menggunakan data dummy untuk simulasi
          _playlists = _generatePlaylistsData();
          _filteredPlaylists = List.from(_playlists);
          _isLoading = false;
        });
      }
    });
  }

  List<Map<String, dynamic>> _generatePlaylistsData() {
    final songs = MockData.getSongs();

    return [
      {
        'id': '1',
        'name': 'Favorit Saya',
        'imageUrl':
            'https://via.placeholder.com/300/121212/FFFFFF?text=Favorit',
        'songCount': 25,
        'createdBy': 'Saya',
        'createdAt': DateTime.now().subtract(const Duration(days: 30)),
        'songs': songs.take(5).toList(),
      },
      {
        'id': '2',
        'name': 'Musik Santai',
        'imageUrl': 'https://via.placeholder.com/300/121212/FFFFFF?text=Santai',
        'songCount': 18,
        'createdBy': 'Saya',
        'createdAt': DateTime.now().subtract(const Duration(days: 60)),
        'songs': songs.take(3).toList(),
      },
      {
        'id': '3',
        'name': 'Workout',
        'imageUrl':
            'https://via.placeholder.com/300/121212/FFFFFF?text=Workout',
        'songCount': 15,
        'createdBy': 'Saya',
        'createdAt': DateTime.now().subtract(const Duration(days: 90)),
        'songs': songs.take(4).toList(),
      },
      {
        'id': '4',
        'name': 'Top Hits 2023',
        'imageUrl':
            'https://via.placeholder.com/300/121212/FFFFFF?text=Top+Hits',
        'songCount': 50,
        'createdBy': 'Lyrix',
        'createdAt': DateTime.now().subtract(const Duration(days: 10)),
        'songs': songs,
      },
      {
        'id': '5',
        'name': 'Nostalgia 90an',
        'imageUrl': 'https://via.placeholder.com/300/121212/FFFFFF?text=90s',
        'songCount': 30,
        'createdBy': 'Lyrix',
        'createdAt': DateTime.now().subtract(const Duration(days: 15)),
        'songs': songs.take(6).toList(),
      },
      {
        'id': '6',
        'name': 'Lagu Akustik',
        'imageUrl':
            'https://via.placeholder.com/300/121212/FFFFFF?text=Akustik',
        'songCount': 22,
        'createdBy': 'Saya',
        'createdAt': DateTime.now().subtract(const Duration(days: 120)),
        'songs': songs.take(4).toList(),
      },
      {
        'id': '7',
        'name': 'Indie Hits',
        'imageUrl': 'https://via.placeholder.com/300/121212/FFFFFF?text=Indie',
        'songCount': 35,
        'createdBy': 'Lyrix',
        'createdAt': DateTime.now().subtract(const Duration(days: 20)),
        'songs': songs.take(7).toList(),
      },
      {
        'id': '8',
        'name': 'Perjalanan',
        'imageUrl': 'https://via.placeholder.com/300/121212/FFFFFF?text=Travel',
        'songCount': 28,
        'createdBy': 'Saya',
        'createdAt': DateTime.now().subtract(const Duration(days: 150)),
        'songs': songs.take(5).toList(),
      },
    ];
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredPlaylists = List.from(_playlists);
      } else {
        _filteredPlaylists = _playlists
            .where((playlist) =>
                playlist['name'].toLowerCase().contains(query) ||
                playlist['createdBy'].toLowerCase().contains(query))
            .toList();
      }
    });
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _filteredPlaylists = List.from(_playlists);
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
        return Column(
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
            // Use ConstrainedBox to limit the height
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height *
                    0.4, // 40% of screen height
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _sortOptions.length,
                itemBuilder: (context, index) {
                  final option = _sortOptions[index];
                  return ListTile(
                    title: Text(option),
                    trailing: _currentSortOption == option
                        ? const Icon(Icons.check, color: AppTheme.primaryColor)
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
        );
      },
    );
  }

  void _sortPlaylists() {
    setState(() {
      switch (_currentSortOption) {
        case 'Nama (A-Z)':
          _filteredPlaylists.sort((a, b) => a['name'].compareTo(b['name']));
          break;
        case 'Nama (Z-A)':
          _filteredPlaylists.sort((a, b) => b['name'].compareTo(a['name']));
          break;
        case 'Jumlah Lagu (Terbanyak)':
          _filteredPlaylists
              .sort((a, b) => b['songCount'].compareTo(a['songCount']));
          break;
        case 'Jumlah Lagu (Tersedikit)':
          _filteredPlaylists
              .sort((a, b) => a['songCount'].compareTo(b['songCount']));
          break;
        case 'Terbaru Dibuat':
          _filteredPlaylists.sort((a, b) => (b['createdAt'] as DateTime)
              .compareTo(a['createdAt'] as DateTime));
          break;
        case 'Terlama Dibuat':
          _filteredPlaylists.sort((a, b) => (a['createdAt'] as DateTime)
              .compareTo(b['createdAt'] as DateTime));
          break;
      }
    });
  }

  void _createNewPlaylist() {
    // Implementasi untuk membuat playlist baru
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Buat Playlist Baru'),
        content: TextField(
          decoration: InputDecoration(
            hintText: 'Nama Playlist',
            filled: true,
            fillColor: Colors.white10,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Playlist baru telah dibuat'),
                  backgroundColor: AppTheme.primaryColor,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('Buat'),
          ),
        ],
      ),
    );
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
            : const Text('Playlist Anda'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
          ),
          IconButton(
            icon: const Icon(Icons.sort),
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
                    childAspectRatio: 0.68, // Adjusted to give more height
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _filteredPlaylists.length,
                  itemBuilder: (context, index) {
                    final playlist = _filteredPlaylists[index];
                    return _buildPlaylistItem(playlist);
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewPlaylist,
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildPlaylistItem(Map<String, dynamic> playlist) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: AppTheme.surfaceColor,
      child: InkWell(
        onTap: () {
          // Navigasi ke detail playlist
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: Image.network(
                playlist['imageUrl'],
                height: 110, // Reduced height
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 110, // Reduced height
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
              ),
            ),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0), // Reduced padding
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playlist['name'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2), // Reduced spacing
                    Text(
                      '${playlist['songCount']} lagu',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2), // Reduced spacing
                    Text(
                      'Oleh ${playlist['createdBy']}',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            // Play button
            Padding(
              padding: const EdgeInsets.only(
                  left: 8.0, right: 8.0, bottom: 4.0), // Adjusted padding
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.primaryColor,
                    radius: 14, // Reduced radius
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 16, // Reduced size
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(
                      Icons.more_vert,
                      size: 18, // Reduced size
                    ),
                    onPressed: () {
                      // Tampilkan opsi playlist
                    },
                    padding: EdgeInsets.zero, // Remove padding
                    constraints: const BoxConstraints(), // Minimize constraints
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
