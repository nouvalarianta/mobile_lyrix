import 'package:flutter/material.dart';
import 'package:lyrix/theme/app_theme.dart';
import 'package:lyrix/screens/song_detail_screen.dart';
import 'package:lyrix/screens/artist_detail_screen.dart';
import 'package:lyrix/services/pocketbase_service.dart';
import 'package:pocketbase/pocketbase.dart';

class RecentlyPlayedScreen extends StatefulWidget {
  const RecentlyPlayedScreen({super.key});

  @override
  State<RecentlyPlayedScreen> createState() => _RecentlyPlayedScreenState();
}

class _RecentlyPlayedScreenState extends State<RecentlyPlayedScreen> {
  bool _isLoading = true;
  List<RecordModel> _playedHistoryRecords = [];

  String _currentFilter = 'Semua';
  final List<String> _filterOptions = [
    'Semua',
    'Lagu',
    'Album',
    'Playlist',
    'Artis'
  ];

  @override
  void initState() {
    super.initState();
    _loadRecentlyPlayed();

    pb.authStore.onChange.listen((_) {
      if (mounted) {
        _loadRecentlyPlayed();
      }
    });
  }

  void _loadRecentlyPlayed() async {
    if (!pb.authStore.isValid) {
      setState(() {
        _playedHistoryRecords = [];
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final records = await pb.collection('played_history').getFullList(
            filter: 'user = "${pb.authStore.model?.id}"',
            expand: 'song_item,album_item,playlist_item,artist_item',
            sort: '-timestamp',
          );

      print(
          'Fetched Played History Records: ${records.map((r) => r.toJson()).toList()}');
      for (var record in records) {
        if (record.expand['song_item']?.isNotEmpty == true) {
          print(
              'Expanded Song Item: ${record.expand['song_item']!.first.toJson()}');
        }
      }

      if (mounted) {
        setState(() {
          _playedHistoryRecords = records;
          _isLoading = false;
        });
      }
    } on ClientException catch (e) {
      print('PocketBase Client Error fetching played history: ${e.response}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Failed to load history: ${e.response['message'] ?? e.toString()}')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Unexpected Error fetching played history: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An unexpected error occurred: $e')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<RecordModel> _getFilteredItems() {
    if (_currentFilter == 'Semua') {
      return _playedHistoryRecords;
    } else {
      final filterTypeMap = {
        'lagu': 'song_item',
        'album': 'album_item',
        'playlist': 'playlist_item',
        'artis': 'artist_item',
      };
      final fieldName = filterTypeMap[_currentFilter.toLowerCase()];

      if (fieldName == null) return [];

      return _playedHistoryRecords.where((item) {
        return item.expand[fieldName]?.isNotEmpty == true;
      }).toList();
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} menit yang lalu';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} jam yang lalu';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} hari yang lalu';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  void _showFilterOptions() {
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
                'Filter Berdasarkan',
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
                itemCount: _filterOptions.length,
                itemBuilder: (context, index) {
                  final option = _filterOptions[index];
                  return ListTile(
                    title: Text(option),
                    trailing: _currentFilter == option
                        ? const Icon(Icons.check, color: AppTheme.primaryColor)
                        : null,
                    onTap: () {
                      setState(() {
                        _currentFilter = option;
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

  @override
  Widget build(BuildContext context) {
    final filteredItems = _getFilteredItems();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recently Played'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterOptions,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryColor,
              ),
            )
          : filteredItems.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredItems.length,
                  itemBuilder: (context, index) {
                    final itemRecord = filteredItems[index];
                    return _buildRecentItem(itemRecord);
                  },
                ),
    );
  }

  Widget _buildRecentItem(RecordModel playedHistoryRecord) {
    final DateTime timestamp =
        DateTime.parse(playedHistoryRecord.data['timestamp']);

    RecordModel? itemData;
    String type = 'unknown';

    if (playedHistoryRecord.expand['song_item']?.isNotEmpty == true) {
      itemData = playedHistoryRecord.expand['song_item']!.first;
      type = 'song';
    } else if (playedHistoryRecord.expand['album_item']?.isNotEmpty == true) {
      itemData = playedHistoryRecord.expand['album_item']!.first;
      type = 'album';
    } else if (playedHistoryRecord.expand['playlist_item']?.isNotEmpty ==
        true) {
      itemData = playedHistoryRecord.expand['playlist_item']!.first;
      type = 'playlist';
    } else if (playedHistoryRecord.expand['artist_item']?.isNotEmpty == true) {
      itemData = playedHistoryRecord.expand['artist_item']!.first;
      type = 'artist';
    }

    if (itemData == null) {
      print(
          'Error: itemData is null for playedHistoryRecord ID: ${playedHistoryRecord.id}. Type: $type');
      return const SizedBox.shrink();
    }

    String title = '';
    String subtitle = '';
    String imageUrl = '';
    IconData typeIcon = Icons.help_outline;

    switch (type) {
      case 'song':
        title = itemData.getStringValue('title');
        subtitle =
            '${itemData.getStringValue('artist')} • ${itemData.getStringValue('album')}';
        imageUrl = itemData.getStringValue('image').isNotEmpty
            ? pb
                .getFileUrl(itemData, itemData.getStringValue('image'))
                .toString()
            : '';
        typeIcon = Icons.music_note;
        break;
      case 'album':
        title = itemData.getStringValue('name');
        subtitle =
            '${itemData.getStringValue('artist')} • ${itemData.getIntValue('releaseYear')}';
        imageUrl = itemData.getStringValue('imageUrl').isNotEmpty
            ? pb
                .getFileUrl(itemData, itemData.getStringValue('imageUrl'))
                .toString()
            : '';
        typeIcon = Icons.album;
        break;
      case 'playlist':
        title = itemData.getStringValue('name');
        subtitle =
            '${itemData.getIntValue('songCount')} lagu • ${itemData.getStringValue('createdBy')}';
        imageUrl = itemData.getStringValue('imageUrl').isNotEmpty
            ? pb
                .getFileUrl(itemData, itemData.getStringValue('imageUrl'))
                .toString()
            : '';
        typeIcon = Icons.playlist_play;
        break;
      case 'artist':
        title = itemData.getStringValue('name');
        subtitle =
            '${itemData.getIntValue('monthlyListeners')} pendengar bulanan';
        imageUrl = itemData.getStringValue('imageUrl').isNotEmpty
            ? pb
                .getFileUrl(itemData, itemData.getStringValue('imageUrl'))
                .toString()
            : '';
        typeIcon = Icons.person;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppTheme.surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          if (type == 'song') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SongDetailScreen(songRecord: itemData!),
              ),
            );
          } else if (type == 'artist') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    ArtistDetailScreen(artistRecord: itemData!),
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 60,
                            height: 60,
                            color: Colors.grey[800],
                            child: Icon(typeIcon, color: Colors.white),
                          );
                        },
                      )
                    : Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey[800],
                        child: Icon(typeIcon, color: Colors.white),
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTimestamp(timestamp),
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.play_circle_filled,
                  color: AppTheme.primaryColor,
                  size: 36,
                ),
                onPressed: () {},
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
            Icons.history,
            size: 80,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Belum ada riwayat pemutaran',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Mulai dengarkan musik untuk melihat riwayat pemutaran Anda',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.5),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (!pb.authStore.isValid)
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.login),
              label: const Text('Login'),
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
            )
          else
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: const Icon(Icons.explore),
              label: const Text('Jelajahi Musik'),
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
