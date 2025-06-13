import 'package:flutter/material.dart';
import 'package:lyrix/screens/song_detail_screen.dart';
import 'package:lyrix/theme/app_theme.dart';
import 'package:lyrix/services/pocketbase_service.dart'; // Import PocketBase instance
import 'package:pocketbase/pocketbase.dart'; // Import RecordModel

// Hapus imports:
// import 'package:lyrix/models/artist.dart';
// import 'package:lyrix/models/song.dart';
// import 'package:lyrix/data/mock_data.dart';

class ArtistDetailScreen extends StatefulWidget {
  final RecordModel artistRecord; // Menerima RecordModel langsung

  const ArtistDetailScreen({super.key, required this.artistRecord});

  @override
  State<ArtistDetailScreen> createState() => _ArtistDetailScreenState();
}

class _ArtistDetailScreenState extends State<ArtistDetailScreen> {
  bool _isFollowing = false;
  bool _isLoading = true; // Loading state untuk data artis dan lagu-lagu
  List<RecordModel> _artistSongs = [];

  // Data artis yang akan ditampilkan di UI
  String _artistName = '';
  String _artistImageUrl = '';
  int _followers = 0;
  int _monthlyListeners = 0;
  int _topTracksCount = 0;
  String _bio = 'No biography available.';

  @override
  void initState() {
    super.initState();
    _loadArtistData(); // Muat data detail artis
    _loadArtistSongs(); // Muat lagu-lagu artis
  }

  void _loadArtistData() {
    final artist = widget.artistRecord;
    setState(() {
      _artistName = artist.getStringValue('name');
      _followers = artist.getIntValue('followers');
      _monthlyListeners = artist.getIntValue('monthlyListeners');
      // Perbaikan di sini: Pastikan nama field 'topTracks' di PocketBase sama persis
      // Jika di screenshot Anda '#topTracks', maka gunakan getIntValue('#topTracks')
      // Namun, nama field PocketBase standar biasanya tanpa '#'.
      _topTracksCount =
          artist.getIntValue('topTracks'); // Asumsi field 'topTracks'
      _bio =
          artist.getStringValue('bio').isNotEmpty == true
              ? artist.getStringValue('bio')
              : 'No biography available.';

      // Get image URL dari field 'imageUrl'
      if (artist.getStringValue('imageUrl').isNotEmpty) {
        try {
          _artistImageUrl = pb
              .getFileUrl(artist, artist.getStringValue('imageUrl'))
              .toString();
        } catch (e) {
          print('Error getting artist image URL: $e');
          _artistImageUrl = ''; // Fallback
        }
      } else {
        _artistImageUrl = ''; // Pastikan string kosong jika tidak ada
      }
      _isLoading = false; // Set loading false setelah data artis dimuat
    });
  }

  Future<void> _loadArtistSongs() async {
    try {
      // Ambil lagu-lagu dari artis ini
      // PENTING: Asumsi ada field 'artist' di koleksi 'songs' yang nilainya adalah NAMA ARTIS.
      // Filter yang Anda gunakan: 'artist = "${widget.artistRecord.getStringValue('name')}"'
      // Ini akan mencari lagu di mana field 'artist' di koleksi 'songs'
      // cocok dengan nama artis (misal, "Dua Lipa").
      // Pastikan field 'artist' di koleksi 'songs' Anda adalah 'text' dan berisi nama artis,
      // BUKAN relasi ke koleksi 'artist' atau ID.
      // Jika itu relasi, filternya akan berbeda: 'artist.id = "${widget.artistRecord.id}"'
      final songs = await pb.collection('songs').getFullList(
            filter: 'artist = "${widget.artistRecord.getStringValue('name')}"',
            sort: '-plays', // Urutkan lagu terpopuler dari artis ini
            batch: 10, // Ambil beberapa lagu saja untuk demo
          );

      if (mounted) {
        setState(() {
          _artistSongs = songs;
        });
      }
    } on ClientException catch (e) {
      print('PocketBase Client Error fetching artist songs: ${e.response}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Failed to load artist songs: ${e.response['message'] ?? 'Unknown error'}')),
        );
      }
    } catch (e) {
      print('Unexpected Error fetching artist songs: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load artist songs: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: AppTheme.surfaceColor, // Warna AppBar
            expandedHeight: 280,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onPressed: () {
                  // Aksi untuk lebih banyak opsi
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                _artistName,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              centerTitle: true,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Gambar latar belakang
                  _artistImageUrl.isNotEmpty
                      ? Image.network(
                          _artistImageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: AppTheme.surfaceColor,
                              child: const Icon(
                                Icons.person,
                                size: 80,
                                color: Colors.white24,
                              ),
                            );
                          },
                        )
                      : Container(
                          color: AppTheme.surfaceColor,
                          child: const Icon(
                            Icons.person,
                            size: 80,
                            color: Colors.white24,
                          ),
                        ),
                  // Overlay gradient
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _artistName,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$_followers followers',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Colors.white70,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _isFollowing = !_isFollowing;
                          });
                          // TODO: Implement follow/unfollow logic to PocketBase
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isFollowing
                              ? Colors.white24
                              : AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                        ),
                        child: Text(_isFollowing ? 'Following' : 'Follow'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(context, '$_followers', 'Followers'),
                      _buildStatItem(
                          context, '$_monthlyListeners', 'Monthly Listeners'),
                      _buildStatItem(context, '$_topTracksCount', 'Top Tracks'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Biography',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _bio,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white70,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Popular Songs',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      TextButton(
                        onPressed: () {
                          // TODO: Navigate to all songs by this artist
                        },
                        child: const Text('See All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (_isLoading &&
                      _artistSongs.isEmpty) // Perbaiki loading indicator
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_artistSongs.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text(
                          'No popular songs available for this artist.',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.white54,
                                  ),
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      itemCount: _artistSongs.length > 5
                          ? 5
                          : _artistSongs.length, // Batasi 5 lagu teratas
                      itemBuilder: (context, index) {
                        final songRecord = _artistSongs[index];
                        final songImageUrl =
                            songRecord.getStringValue('image').isNotEmpty
                                ? pb
                                    .getFileUrl(songRecord,
                                        songRecord.getStringValue('image'))
                                    .toString()
                                : '';
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: songImageUrl.isNotEmpty
                                ? Image.network(
                                    songImageUrl,
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: 50,
                                        height: 50,
                                        color: Colors.grey[800],
                                        child: const Icon(Icons.music_note,
                                            color: Colors.white, size: 20),
                                      );
                                    },
                                  )
                                : Container(
                                    width: 50,
                                    height: 50,
                                    color: Colors.grey[800],
                                    child: const Icon(Icons.music_note,
                                        color: Colors.white, size: 20),
                                  ),
                          ),
                          title: Text(
                            songRecord.getStringValue('title'),
                            style: const TextStyle(fontSize: 14),
                          ),
                          subtitle: Text(
                            // Perbaikan: Akses 'artist' dari RecordModel dan 'plays' juga dari RecordModel
                            '${songRecord.getStringValue('artist')} • ${songRecord.getIntValue('plays')} plays',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.more_vert, size: 20),
                            onPressed: () {
                              // Aksi untuk opsi lagu
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    SongDetailScreen(songRecord: songRecord),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  const SizedBox(height: 16),
                  Text(
                    'Albums',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 160,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: 5, // Ini masih placeholder
                      itemBuilder: (context, index) {
                        // Ini masih hardcoded/placeholder, perlu integrasi dengan koleksi 'albums' jika ada
                        return Container(
                          width: 120,
                          margin: const EdgeInsets.only(right: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  height: 120,
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
                              const SizedBox(height: 6),
                              Text(
                                'Album ${index + 1}', // Placeholder
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      fontSize: 12,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '2023', // Placeholder
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      fontSize: 10,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
