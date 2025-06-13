import 'package:flutter/material.dart';
import 'package:lyrix/theme/app_theme.dart';
import 'package:lyrix/screens/artist_detail_screen.dart';
import 'package:lyrix/services/pocketbase_service.dart'; // Import PocketBase instance
import 'package:pocketbase/pocketbase.dart'; // Import RecordModel

// Hapus imports:
// import 'package:lyrix/models/artist.dart';
// import 'package:lyrix/data/mock_data.dart';

class PopularArtistsScreen extends StatefulWidget {
  const PopularArtistsScreen({super.key});

  @override
  State<PopularArtistsScreen> createState() => _PopularArtistsScreenState();
}

class _PopularArtistsScreenState extends State<PopularArtistsScreen> {
  bool _isLoading = true;
  List<RecordModel> _popularArtists = []; // Ubah menjadi RecordModel
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  List<RecordModel> _filteredArtists = []; // Ubah menjadi RecordModel

  // Opsi pengurutan
  String _currentSortOption = 'Popularitas';
  final List<String> _sortOptions = [
    'Popularitas',
    'Nama (A-Z)',
    'Nama (Z-A)',
    'Pengikut (Terbanyak)',
    'Pengikut (Tersedikit)',
  ];

  @override
  void initState() {
    super.initState();
    _loadPopularArtists();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _loadPopularArtists() async {
    setState(() {
      _isLoading = true;
    });
    try {
      // Ambil artis dari koleksi 'artist'
      // Urutkan berdasarkan monthlyListeners (popularitas) secara default
      final artists = await pb.collection('artist').getFullList(
            sort:
                '-monthlyListeners', // Urutkan dari yang paling banyak pendengar bulanan
          );

      if (mounted) {
        setState(() {
          _popularArtists = artists;
          _filteredArtists =
              List.from(_popularArtists); // Inisialisasi daftar yang difilter
          _isLoading = false;
          _sortArtists(); // Terapkan pengurutan awal
        });
      }
    } on ClientException catch (e) {
      print('PocketBase Client Error fetching popular artists: ${e.response}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Failed to load popular artists: ${e.response['message'] ?? 'Unknown error'}')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Unexpected Error fetching popular artists: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load popular artists: $e')),
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
        _filteredArtists = List.from(_popularArtists);
      } else {
        _filteredArtists = _popularArtists
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
        _filteredArtists = List.from(_popularArtists);
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
              ConstrainedBox(
                // Tambahkan ConstrainedBox agar bottom sheet tidak terlalu tinggi
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
                          ? const Icon(Icons.check,
                              color: AppTheme.primaryColor)
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
          ),
        );
      },
    );
  }

  void _sortArtists() {
    setState(() {
      switch (_currentSortOption) {
        case 'Popularitas':
          _filteredArtists.sort((a, b) => b
              .getIntValue('monthlyListeners')
              .compareTo(a.getIntValue('monthlyListeners')));
          break;
        case 'Nama (A-Z)':
          _filteredArtists.sort((a, b) =>
              a.getStringValue('name').compareTo(b.getStringValue('name')));
          break;
        case 'Nama (Z-A)':
          _filteredArtists.sort((a, b) =>
              b.getStringValue('name').compareTo(a.getStringValue('name')));
          break;
        case 'Pengikut (Terbanyak)':
          _filteredArtists.sort((a, b) =>
              b.getIntValue('followers').compareTo(a.getIntValue('followers')));
          break;
        case 'Pengikut (Tersedikit)':
          _filteredArtists.sort((a, b) =>
              a.getIntValue('followers').compareTo(b.getIntValue('followers')));
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Cari artis populer...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                ),
                style: const TextStyle(color: Colors.white),
                autofocus: true,
              )
            : const Text('Popular Artists'),
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
                    childAspectRatio: 0.9,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _filteredArtists.length,
                  itemBuilder: (context, index) {
                    final artistRecord =
                        _filteredArtists[index]; // Ambil RecordModel
                    return _buildArtistItem(
                        artistRecord, index); // Teruskan RecordModel
                  },
                ),
    );
  }

  Widget _buildArtistItem(RecordModel artistRecord, int index) {
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
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    radius: 38,
                    backgroundImage:
                        imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
                    onBackgroundImageError: (exception, stackTrace) {
                      print('Error loading artist image: $exception');
                    },
                    child: imageUrl.isEmpty
                        ? const Icon(
                            Icons.person,
                            size: 38, // Ukuran ikon sesuai radius
                            color: Colors.white54,
                          )
                        : null,
                  ),
                  if (index < 3) // Tampilkan badge untuk 3 teratas
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.backgroundColor,
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        '${(monthlyListeners / 1000000).toStringAsFixed(1)}M pendengar', // Menggunakan monthlyListeners
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 9,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.play_circle_filled,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                    onPressed: () {
                      // Implementasi untuk memutar musik artis (misal, lagu top pertama)
                      // Anda perlu membuat sebuah service pemutar lagu yang bisa diakses global
                      // dan meneruskan lagu RecordModel ke sana.
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 30,
                      minHeight: 30,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(
                      Icons.person_add_outlined,
                      size: 16,
                    ),
                    onPressed: () {
                      // Implementasi untuk mengikuti artis ke PocketBase
                      // Ini akan memerlukan fungsi untuk menambah/menghapus record di koleksi 'followed_artists'
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Anda sekarang mengikuti ${name}'),
                          backgroundColor: AppTheme.primaryColor,
                        ),
                      );
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 30,
                      minHeight: 30,
                    ),
                  ),
                ],
              ),
            ],
          ),
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
            Icons.people_outline,
            size: 80,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            _isSearching
                ? 'Tidak ada artis yang cocok dengan pencarian Anda'
                : 'Tidak ada artis populer saat ini',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (!_isSearching)
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _isLoading = true; // Set loading true sebelum memuat ulang
                });
                _loadPopularArtists(); // Muat ulang data dari PocketBase
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Muat Ulang'),
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
