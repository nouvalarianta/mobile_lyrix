import 'package:flutter/material.dart';
import 'package:lyrix/screens/artist_detail_screen.dart';
import 'package:lyrix/screens/search_screen.dart';
import 'package:lyrix/screens/profile_screen.dart';
import 'package:lyrix/widgets/artist_card.dart';
import 'package:lyrix/widgets/song_card.dart';
import 'package:lyrix/widgets/section_header.dart';
import 'package:lyrix/screens/trending_songs_screen.dart';
import 'package:lyrix/screens/popular_artists_screen.dart';
import 'package:lyrix/screens/recently_played_screen.dart';
import 'package:lyrix/screens/now_playing_screen.dart';
import 'package:lyrix/services/pocketbase_service.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:lyrix/services/audio_player_service.dart';
import 'package:provider/provider.dart';
import 'package:lyrix/theme/app_theme.dart';

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
    final audioPlayerService = Provider.of<AudioPlayerService>(context);

    return Scaffold(
      body: Stack(
        children: [
          _screens[_currentIndex],
          if (audioPlayerService.currentSong != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 80,
              child: _buildMiniPlayer(context, audioPlayerService),
            ),
        ],
      ),
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

  Widget _buildMiniPlayer(
      BuildContext context, AudioPlayerService audioPlayerService) {
    final currentSong = audioPlayerService.currentSong!;
    final imageUrl = currentSong.getStringValue('image').isNotEmpty
        ? pb
            .getFileUrl(currentSong, currentSong.getStringValue('image'))
            .toString()
        : '';

    return GestureDetector(
      onTap: () {
        Navigator.push(context,
            MaterialPageRoute(builder: (context) => const NowPlayingScreen()));
      },
      child: Container(
        height: 60,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      width: 45,
                      height: 45,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 45,
                        height: 45,
                        color: Colors.grey[800],
                        child: Icon(Icons.music_note,
                            color: Colors.white, size: 20),
                      ),
                    )
                  : Container(
                      width: 45,
                      height: 45,
                      color: Colors.grey[800],
                      child:
                          Icon(Icons.music_note, color: Colors.white, size: 20),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    currentSong.getStringValue('title'),
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    currentSong.getStringValue('artist'),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.white70),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                audioPlayerService.isPlaying
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_filled,
                size: 36,
                color: AppTheme.primaryColor,
              ),
              onPressed: audioPlayerService.togglePlayPause,
            ),
          ],
        ),
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
  List<RecordModel> _recentlyPlayed = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHomeData();
  }

  Future<void> _fetchHomeData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final songs = await pb.collection('songs').getFullList(
            sort: '-plays',
            batch: 10,
          );

      final artists = await pb.collection('artist').getFullList(
            sort: '-monthlyListeners',
            batch: 10,
          );

      List<RecordModel> recentSongs = [];
      if (pb.authStore.isValid) {
        final history = await pb.collection('played_history').getFullList(
              filter: 'user = "${pb.authStore.model?.id}"',
              expand: 'song_item',
              sort: '-timestamp',
              batch: 10,
            );

        final uniqueSongIds = <String>{};
        recentSongs = history
            .where((h) => h.expand['song_item']?.isNotEmpty == true)
            .map((h) => h.expand['song_item']!.first)
            .where((song) => uniqueSongIds.add(song.id))
            .toList();
      }

      if (mounted) {
        setState(() {
          _trendingSongs = songs;
          _popularArtists = artists;
          _recentlyPlayed = recentSongs;
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
                      songRecord: songRecord,
                      onTap: () {
                        Provider.of<AudioPlayerService>(context, listen: false)
                            .playSong(songRecord);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => NowPlayingScreen(),
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
                      artistRecord: artistRecord,
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
                  ? const Center(child: Text('')) // Hide indicator here
                  : _recentlyPlayed.isEmpty
                      ? const Center(child: Text('No recently played songs.'))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          itemCount: _recentlyPlayed.length,
                          itemBuilder: (context, index) {
                            final songRecord = _recentlyPlayed[index];
                            final imageUrl =
                                songRecord.getStringValue('image').isNotEmpty
                                    ? pb
                                        .getFileUrl(
                                          songRecord,
                                          songRecord.getStringValue('image'),
                                        )
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
                                  Provider.of<AudioPlayerService>(context,
                                          listen: false)
                                      .playSong(songRecord);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => NowPlayingScreen(),
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
