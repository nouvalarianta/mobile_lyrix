import 'package:flutter/material.dart';
import 'package:lyrix/theme/app_theme.dart';
import 'package:lyrix/screens/artist_detail_screen.dart';
import 'package:lyrix/services/pocketbase_service.dart'; // Import PocketBase instance
import 'package:pocketbase/pocketbase.dart'; // Import RecordModel

// Hapus imports:
// import 'package:lyrix/models/artist.dart';
// import 'package:lyrix/data/mock_data.dart';

class FollowingScreen extends StatefulWidget {
  const FollowingScreen({super.key});

  @override
  State<FollowingScreen> createState() => _FollowingScreenState();
}

class _FollowingScreenState extends State<FollowingScreen> {
  bool _isLoading = true;
  List<RecordModel> _followedArtists = []; // Ubah menjadi RecordModel
  List<RecordModel> _filteredArtists = []; // Ubah menjadi RecordModel
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  // Opsi pengurutan
  String _currentSortOption = 'Terbaru Diikuti';
  final List<String> _sortOptions = [
    'Terbaru Diikuti',
    'Terlama Diikuti',
    'Nama (A-Z)',
    'Nama (Z-A)',
    'Popularitas',
  ];

  @override
  void initState() {
    super.initState();
    _loadFollowedArtists();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _loadFollowedArtists() async {
    setState(() {
      _isLoading = true;
    });
    try {
      // Untuk demo, kita akan mengambil semua artis dari koleksi 'artist'
      // Dalam implementasi nyata, Anda akan memfilter artis yang diikuti oleh pengguna saat ini
      final artists = await pb.collection('artist').getFullList(
            sort: '-created', // Contoh: urutkan berdasarkan yang terbaru dibuat
          );

      if (mounted) {
        setState(() {
          _followedArtists = artists;
          _filteredArtists = List.from(_followedArtists);
          _isLoading = false;
          _sortArtists(); // Terapkan pengurutan awal
        });
      }
    } on ClientException catch (e) {
      print('PocketBase Client Error fetching followed artists: ${e.response}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Failed to load followed artists: ${e.response['message'] ?? e.toString()}')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Unexpected Error fetching followed artists: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load followed artists: $e')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredArtists = List.from(_followedArtists);
      } else {
        _filteredArtists = _followedArtists
            .where((artist) => artist
                .getStringValue('name')
                .toLowerCase()
                .contains(query)) // Akses nama artis dari RecordModel
            .toList();
      }
      _sortArtists(); // Pastikan urutan tetap setelah pencarian
    });
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _filteredArtists = List.from(_followedArtists);
        _sortArtists(); // Pastikan urutan tetap setelah pencarian
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
                    title: Text(option),
                    trailing: _currentSortOption == option
                        ? const Icon(Icons.check, color: AppTheme.primaryColor)
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
        );
      },
    );
  }

  void _sortArtists() {
    setState(() {
      switch (_currentSortOption) {
        case 'Nama (A-Z)':
          _filteredArtists.sort((a, b) =>
              a.getStringValue('name').compareTo(b.getStringValue('name')));
          break;
        case 'Nama (Z-A)':
          _filteredArtists.sort((a, b) =>
              b.getStringValue('name').compareTo(a.getStringValue('name')));
          break;
        case 'Popularitas':
          _filteredArtists.sort((a, b) => b
              .getIntValue('monthlyListeners')
              .compareTo(a.getIntValue('monthlyListeners')));
          break;
        case 'Terbaru Diikuti':
          // Dalam kasus nyata, ini akan mengurutkan berdasarkan field 'created' di koleksi 'followed_artists'
          // Untuk demo ini, kita akan mengurutkan berdasarkan tanggal 'created' artis di koleksi 'artist'
          _filteredArtists.sort((a, b) => b.created.compareTo(a.created));
          break;
        case 'Terlama Diikuti':
          // Sama seperti di atas, tapi terbalik
          _filteredArtists.sort((a, b) => a.created.compareTo(b.created));
          break;
      }
    });
  }

  // Fungsi unfollow artist (simulasi)
  void _unfollowArtist(RecordModel artist) {
    // Terima RecordModel
    setState(() {
      // Dalam implementasi nyata, Anda akan menghapus record dari koleksi 'followed_artists'
      // Contoh simulasi penghapusan dari daftar lokal:
      _followedArtists.removeWhere((item) => item.id == artist.id);
      _filteredArtists.removeWhere((item) => item.id == artist.id);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Berhenti mengikuti ${artist.getStringValue('name')}'),
        backgroundColor: AppTheme.surfaceColor,
        action: SnackBarAction(
          label: 'BATAL',
          textColor: AppTheme.primaryColor,
          onPressed: () {
            // Dalam implementasi nyata, Anda akan membuat record baru di 'followed_artists'
            // Contoh simulasi penambahan kembali ke daftar lokal:
            setState(() {
              _followedArtists.add(artist);
              _sortArtists(); // Urutkan kembali
            });
          },
        ),
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
                  hintText: 'Cari artis...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                ),
                style: const TextStyle(color: Colors.white),
                autofocus: true,
              )
            : const Text('Artis yang Diikuti'),
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
          : _filteredArtists.isEmpty
              ? _buildEmptyState()
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.7,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _filteredArtists.length,
                  itemBuilder: (context, index) {
                    final artistRecord =
                        _filteredArtists[index]; // Ambil RecordModel
                    return _buildArtistItem(
                        artistRecord); // Teruskan RecordModel
                  },
                ),
    );
  }

  Widget _buildArtistItem(RecordModel artistRecord) {
    // Terima RecordModel
    final String name = artistRecord.getStringValue('name');
    final String imageUrl = artistRecord.getStringValue('imageUrl').isNotEmpty
        ? pb
            .getFileUrl(artistRecord, artistRecord.getStringValue('imageUrl'))
            .toString()
        : '';
    final int monthlyListeners = artistRecord.getIntValue('monthlyListeners');

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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: CircleAvatar(
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
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(monthlyListeners / 1000000).toStringAsFixed(1)}M pendengar bulanan',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.play_circle_filled,
                    color: AppTheme.primaryColor,
                    size: 28,
                  ),
                  onPressed: () {
                    // Implementasi untuk memutar musik artis (misal, memutar lagu top pertama)
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.person_remove_outlined,
                    size: 22,
                  ),
                  onPressed: () =>
                      _unfollowArtist(artistRecord), // Teruskan RecordModel
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 4),
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
            Icons.person_outline,
            size: 80,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            _isSearching
                ? 'Tidak ada artis yang cocok dengan pencarian Anda'
                : 'Anda belum mengikuti artis apa pun',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Ikuti artis favorit Anda untuk mendapatkan update terbaru',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.5),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              // Navigasi ke halaman penemuan artis (misal, SearchScreen)
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const Text(
                        'Discover Artists Page')), // Ganti dengan halaman discover artis Anda
              );
            },
            icon: const Icon(Icons.explore),
            label: const Text('Jelajahi Artis'),
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
