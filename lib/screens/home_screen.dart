import 'package:flutter/material.dart';
import 'package:lyrix/screens/artist_detail_screen.dart';
import 'package:lyrix/screens/search_screen.dart';
import 'package:lyrix/screens/song_detail_screen.dart';
import 'package:lyrix/screens/profile_screen.dart';
import 'package:lyrix/widgets/artist_card.dart';
import 'package:lyrix/widgets/song_card.dart';
import 'package:lyrix/widgets/section_header.dart';
import 'package:lyrix/screens/trending_songs_screen.dart';
import 'package:lyrix/screens/popular_artists_screen.dart';
import 'package:lyrix/screens/recently_played_screen.dart';

import 'package:lyrix/services/pocketbase_service.dart';
import 'package:pocketbase/pocketbase.dart';

// Hapus import yang tidak diperlukan lagi:
// import 'package:lyrix/models/song.dart';
// import 'package:lyrix/models/artist.dart';
// import 'package:lyrix/data/mock_data.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final List<Widget> _screens = [];

  @override
  void initState() {
    super.initState();
    _screens.add(const HomeContent());
    _screens.add(const SearchScreen());
    _screens.add(const ProfileScreen());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  List<RecordModel> _trendingSongs = [];
  List<RecordModel> _popularArtists = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHomeData();
  }

  Future<void> _fetchHomeData() async {
    try {
      final songs = await pb.collection('songs').getFullList(
            sort: '-plays', // Urutkan berdasarkan plays
            batch: 10,
          );

      final artists = await pb.collection('artist').getFullList(
            sort: '-monthlyListeners',
            batch: 10,
          );

      if (mounted) {
        setState(() {
          _trendingSongs = songs;
          _popularArtists = artists;
          _isLoading = false;
        });
      }
    } on ClientException catch (e) {
      print('PocketBase Client Error fetching home data: ${e.response}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Failed to load data: ${e.response['message'] ?? e.toString()}')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Unexpected Error fetching home data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load data: $e')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            pinned: false,
            title: const Text('Lyrix'),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {},
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Discover',
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Find the latest trending music',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SectionHeader(
              title: 'Trending Songs',
              onSeeAllPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TrendingSongsScreen(),
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              ),
            )
          else if (_trendingSongs.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Center(child: Text('No trending songs found.')),
              ),
            )
          else
            SliverToBoxAdapter(
              child: SizedBox(
                height: 220,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: _trendingSongs.length,
                  itemBuilder: (context, index) {
                    final songRecord = _trendingSongs[index];
                    return SongCard(
                      songRecord: songRecord, // <--- Corrected
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
              ),
            ),
          SliverToBoxAdapter(
            child: SectionHeader(
              title: 'Popular Artists',
              onSeeAllPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PopularArtistsScreen(),
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              ),
            )
          else if (_popularArtists.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Center(child: Text('No popular artists found.')),
              ),
            )
          else
            SliverToBoxAdapter(
              child: SizedBox(
                height: 160,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: _popularArtists.length,
                  itemBuilder: (context, index) {
                    final artistRecord = _popularArtists[index];
                    return ArtistCard(
                      artistRecord: artistRecord, // <--- Corrected
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ArtistDetailScreen(artistRecord: artistRecord),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: SectionHeader(
              title: 'Recently Played',
              onSeeAllPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RecentlyPlayedScreen(),
                  ),
                );
              },
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 80,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _trendingSongs.isEmpty
                      ? const Center(child: Text('No recently played songs.'))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          itemCount: _trendingSongs.length,
                          itemBuilder: (context, index) {
                            final songRecord =
                                _trendingSongs[index % _trendingSongs.length];
                            final imageUrl =
                                songRecord.getStringValue('image').isNotEmpty
                                    ? pb
                                        .getFileUrl(songRecord,
                                            songRecord.getStringValue('image'))
                                        .toString()
                                    : '';
                            return Container(
                              width: 280,
                              margin: const EdgeInsets.only(right: 16),
                              child: ListTile(
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: imageUrl.isNotEmpty
                                      ? Image.network(
                                          imageUrl,
                                          width: 60,
                                          height: 60,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                            return Container(
                                              width: 60,
                                              height: 60,
                                              color: Colors.grey[800],
                                              child: const Icon(
                                                  Icons.music_note,
                                                  color: Colors.white),
                                            );
                                          },
                                        )
                                      : Container(
                                          width: 60,
                                          height: 60,
                                          color: Colors.grey[800],
                                          child: const Icon(Icons.music_note,
                                              color: Colors.white),
                                        ),
                                ),
                                title: Text(
                                  songRecord.getStringValue('title'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  songRecord.getStringValue('artist'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => SongDetailScreen(
                                          songRecord: songRecord),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
            ),
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 20),
          ),
        ],
      ),
    );
  }
}
