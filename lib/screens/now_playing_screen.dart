import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lyrix/theme/app_theme.dart';
import 'package:lyrix/services/audio_player_service.dart';
import 'package:lyrix/services/pocketbase_service.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:lyrix/widgets/add_to_playlist_bottom_sheet.dart';

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen>
    with TickerProviderStateMixin {
  late AnimationController _playButtonController;
  late AnimationController _albumRotationController;

  bool _isLiked = false;
  String? _likedRecordId;

  @override
  void initState() {
    super.initState();
    _playButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _albumRotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    );

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLikeStatus();
      final audioPlayerService =
          Provider.of<AudioPlayerService>(context, listen: false);
      if (audioPlayerService.currentSong != null) {
        if (audioPlayerService.isPlaying) {
          _playButtonController.value = 1.0;
          _albumRotationController.repeat();
        } else {
          _playButtonController.value = 0.0;
          _albumRotationController.stop();
        }
      } else {
        _playButtonController.value = 0.0;
        _albumRotationController.stop();
      }
    });

    Provider.of<AudioPlayerService>(context, listen: false)
        .audioPlayer
        .playerStateStream
        .listen((playerState) {
      if (!mounted) return;
      if (playerState.playing && _playButtonController.value != 1.0) {
        _playButtonController.forward();
        _albumRotationController.repeat();
      } else if (!playerState.playing && _playButtonController.value != 0.0) {
        _playButtonController.reverse();
        _albumRotationController.stop();
      }
    });

    Provider.of<AudioPlayerService>(context, listen: false)
        .audioPlayer
        .processingStateStream
        .listen((processingState) {
      if (!mounted) return;
      if (processingState == ProcessingState.completed) {
        _albumRotationController.stop();
        _playButtonController.reverse();
      }
    });
  }

  @override
  void dispose() {
    _playButtonController.dispose();
    _albumRotationController.dispose();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    super.dispose();
  }

  void _checkLikeStatus() async {
    final audioPlayerService =
        Provider.of<AudioPlayerService>(context, listen: false);
    final currentSong = audioPlayerService.currentSong;

    if (!pb.authStore.isValid || currentSong == null) {
      setState(() {
        _isLiked = false;
        _likedRecordId = null;
      });
      return;
    }
    try {
      final likedRecord = await pb.collection('liked_songs').getFirstListItem(
            'user = "${pb.authStore.model?.id}" && song = "${currentSong.id}"',
          );
      if (mounted) {
        setState(() {
          _isLiked = true;
          _likedRecordId = likedRecord.id;
        });
      }
    } on ClientException catch (e) {
      if (e.statusCode == 404) {
        if (mounted) {
          setState(() {
            _isLiked = false;
            _likedRecordId = null;
          });
        }
      } else {
        print('Error checking like status in NowPlayingScreen: ${e.response}');
        if (mounted) {
          setState(() {
            _isLiked = false;
            _likedRecordId = null;
          });
        }
      }
    } catch (e) {
      print('Unexpected error checking like status in NowPlayingScreen: $e');
      if (mounted) {
        setState(() {
          _isLiked = false;
        });
      }
    }
  }

  void _toggleLikeStatus() async {
    final audioPlayerService =
        Provider.of<AudioPlayerService>(context, listen: false);
    final currentSong = audioPlayerService.currentSong;

    if (!pb.authStore.isValid || currentSong == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login untuk menyukai lagu!')),
      );
      return;
    }

    bool previousLikedStatus = _isLiked;
    setState(() {
      _isLiked = !_isLiked;
    });

    try {
      if (_isLiked) {
        final newLikedRecord = await pb.collection('liked_songs').create(body: {
          'user': pb.authStore.model?.id,
          'song': currentSong.id,
        });
        if (mounted) {
          setState(() {
            _likedRecordId = newLikedRecord.id;
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Menyukai ${currentSong.getStringValue('title')}')),
        );
      } else {
        if (_likedRecordId != null) {
          await pb.collection('liked_songs').delete(_likedRecordId!);
          if (mounted) {
            setState(() {
              _likedRecordId = null;
            });
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Berhenti menyukai ${currentSong.getStringValue('title')}')),
          );
        }
      }
    } on ClientException catch (e) {
      print('Error toggling like status in NowPlayingScreen: ${e.response}');
      if (mounted) {
        setState(() {
          _isLiked = previousLikedStatus;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Gagal mengubah status suka: ${e.response['message'] ?? 'Unknown error'}')),
        );
      }
    } catch (e) {
      print('Unexpected error toggling like status in NowPlayingScreen: $e');
      if (mounted) {
        setState(() {
          _isLiked = previousLikedStatus;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terjadi kesalahan tak terduga: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<AudioPlayerService>(
        builder: (context, audioPlayerService, child) {
          final currentSong = audioPlayerService.currentSong;
          if (currentSong == null) {
            return Scaffold(
              backgroundColor: Colors.black,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.music_note, size: 80, color: Colors.white24),
                    SizedBox(height: 16),
                    Text('Tidak ada lagu yang sedang diputar',
                        style: Theme.of(context).textTheme.titleLarge),
                  ],
                ),
              ),
            );
          }

          final imageUrl = currentSong.getStringValue('image').isNotEmpty
              ? pb
                  .getFileUrl(currentSong, currentSong.getStringValue('image'))
                  .toString()
              : '';
          final title = currentSong.getStringValue('title');
          final artist = currentSong.getStringValue('artist');

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryColor.withOpacity(0.3),
                  AppTheme.backgroundColor,
                  Colors.black,
                ],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.keyboard_arrow_down,
                              color: Colors.white, size: 30),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Column(
                          children: [
                            Text('MEMUTAR LAGU',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                        color: Colors.white70,
                                        letterSpacing: 1)),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.more_vert,
                              color: Colors.white, size: 30),
                          onPressed: () {},
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    Expanded(
                      flex: 4,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24.0, vertical: 0.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: imageUrl.isNotEmpty
                              ? Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                    color: Colors.grey[800],
                                    child: const Icon(Icons.music_note,
                                        size: 100, color: Colors.white24),
                                  ),
                                )
                              : Container(
                                  color: Colors.grey[800],
                                  child: const Icon(Icons.music_note,
                                      size: 100, color: Colors.white24),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                artist,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(color: Colors.white70),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            _isLiked ? Icons.favorite : Icons.favorite_border,
                            color: _isLiked
                                ? AppTheme.primaryColor
                                : Colors.white70,
                          ),
                          onPressed: _toggleLikeStatus,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    StreamBuilder<DurationState>(
                      stream: audioPlayerService.audioPlayer
                          .createPositionStream(
                            minPeriod: const Duration(milliseconds: 200),
                          )
                          .map((position) => DurationState(
                              position, audioPlayerService.totalDuration)),
                      builder: (context, snapshot) {
                        final durationState = snapshot.data ??
                            DurationState(Duration.zero, Duration.zero);
                        return ProgressBar(
                          progress: durationState.position,
                          total: durationState.total,
                          baseBarColor: Colors.white.withOpacity(0.3),
                          progressBarColor: AppTheme.primaryColor,
                          thumbColor: AppTheme.primaryColor,
                          bufferedBarColor: Colors.white.withOpacity(0.1),
                          onSeek: audioPlayerService.seek,
                          thumbRadius: 6,
                          timeLabelLocation: TimeLabelLocation.below,
                          timeLabelTextStyle: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.white70),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.shuffle,
                            color: audioPlayerService.isShuffleActive
                                ? AppTheme.primaryColor
                                : Colors.white70,
                            size: 30,
                          ),
                          onPressed: audioPlayerService.toggleShuffle,
                        ),
                        IconButton(
                            icon: const Icon(Icons.skip_previous,
                                color: Colors.white, size: 40),
                            onPressed: audioPlayerService.seekToPrevious),
                        IconButton(
                          icon: Icon(
                            audioPlayerService.isPlaying
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_filled,
                            color: AppTheme.primaryColor,
                            size: 70,
                          ),
                          onPressed: audioPlayerService.togglePlayPause,
                        ),
                        IconButton(
                            icon: const Icon(Icons.skip_next,
                                color: Colors.white, size: 40),
                            onPressed: audioPlayerService.seekToNext),
                        IconButton(
                          icon: Icon(
                            Icons.repeat,
                            color: audioPlayerService.isRepeatActive
                                ? AppTheme.primaryColor
                                : Colors.white70,
                            size: 30,
                          ),
                          onPressed: audioPlayerService.toggleRepeat,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                            icon: const Icon(Icons.devices,
                                color: Colors.white70, size: 30),
                            onPressed: () {/* Connect to device */}),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.add_box_outlined,
                                  color: Colors.white70, size: 30),
                              onPressed: () {
                                _showAddToPlaylistDialog(context, currentSong);
                              },
                            ),
                            const SizedBox(width: 16),
                            IconButton(
                                icon: const Icon(Icons.share,
                                    color: Colors.white70, size: 30),
                                onPressed: () {/* Share */}),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddToPlaylistDialog(BuildContext context, RecordModel songToAdd) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return AddToPlaylistBottomSheet(songToAdd: songToAdd);
      },
    );
  }
}

class DurationState {
  const DurationState(this.position, this.total);
  final Duration position;
  final Duration total;
}
