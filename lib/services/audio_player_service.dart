import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:lyrix/services/pocketbase_service.dart';
import 'dart:math';

class AudioPlayerService with ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  RecordModel? _currentSong;
  List<RecordModel> _currentPlaylist = [];
  int _currentPlaylistIndex = -1;
  bool _isShuffleActive = false;
  bool _isRepeatActive = false;

  List<RecordModel> _allSongs = [];
  bool _isFetchingAllSongs = false;

  final List<String> _localPlayedSongIds = [];
  static const int _maxLocalHistorySize = 10;

  AudioPlayer get audioPlayer => _audioPlayer;
  RecordModel? get currentSong => _currentSong;
  bool get isPlaying => _audioPlayer.playing;
  bool get isShuffleActive => _isShuffleActive;
  bool get isRepeatActive => _isRepeatActive;
  Duration get totalDuration => _audioPlayer.duration ?? Duration.zero;

  AudioPlayerService() {
    _audioPlayer.sequenceStateStream.listen((sequenceState) {
      if (sequenceState != null && sequenceState.currentSource != null) {
        final newIndex = sequenceState.currentIndex;
        if (newIndex >= 0 && newIndex < _currentPlaylist.length) {
          _currentSong = _currentPlaylist[newIndex];

          if (_currentSong != null &&
              _localPlayedSongIds.lastOrNull != _currentSong!.id) {
            _localPlayedSongIds.add(_currentSong!.id);
            if (_localPlayedSongIds.length > _maxLocalHistorySize) {
              _localPlayedSongIds.removeAt(0);
            }
            print('Local history: $_localPlayedSongIds');
          }
        } else {
          _currentSong = null;
        }
      } else {
        _currentSong = null;
      }
      notifyListeners();
      if (sequenceState?.currentSource == null &&
          _audioPlayer.processingState == ProcessingState.completed &&
          !_isRepeatActive &&
          _currentPlaylist.isNotEmpty) {
        _playRandomSongFromAll();
      }
    });

    _audioPlayer.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.completed &&
          !_isRepeatActive) {}
      notifyListeners();
    });

    _fetchAllSongs();
  }

  Future<void> _fetchAllSongs() async {
    if (_isFetchingAllSongs) return;
    _isFetchingAllSongs = true;
    try {
      _allSongs = await pb.collection('songs').getFullList(
            sort: 'title',
            batch: 200,
          );
      print('Fetched ${_allSongs.length} total songs for random playback.');
    } catch (e) {
      print('Error fetching all songs: $e');
      _allSongs = [];
    } finally {
      _isFetchingAllSongs = false;
    }
  }

  Future<void> _playRandomSongFromAll() async {
    if (_allSongs.isEmpty) {
      await _fetchAllSongs();
      if (_allSongs.isEmpty) {
        print('No songs available for random playback.');
        return;
      }
    }

    final random = Random();
    final randomIndex = random.nextInt(_allSongs.length);
    final randomSong = _allSongs[randomIndex];

    print('Playing random song: ${randomSong.getStringValue('title')}');
    await playSong(randomSong);
    _currentPlaylist = [randomSong];
    _currentPlaylistIndex = 0;
    notifyListeners();
  }

  Future<void> _addSongToRecentlyPlayed(RecordModel song) async {
    if (!pb.authStore.isValid) {
      print(
          'User not authenticated, skipping recently played record creation.');
      return;
    }
    try {
      try {
        final existingRecord =
            await pb.collection('played_history').getFirstListItem(
                  'user = "${pb.authStore.model!.id}" && song_item = "${song.id}"',
                );

        await pb.collection('played_history').update(existingRecord.id, body: {
          'timestamp': DateTime.now().toIso8601String(),
        });
        print(
            'Updated song in recently played: ${song.getStringValue('title')}');
      } on ClientException catch (e) {
        if (e.statusCode == 404) {
          await pb.collection('played_history').create(body: {
            'song_item': song.id,
            'user': pb.authStore.model!.id,
            'timestamp': DateTime.now().toIso8601String(),
          });
          print(
              'Added new song to recently played: ${song.getStringValue('title')}');
        } else {
          print(
              'Error checking/adding song to recently played (client exception): $e');
        }
      }
    } catch (e) {
      print('Unexpected Error adding song to recently played: $e');
    }
  }

  Future<void> playSong(RecordModel song) async {
    _currentSong = song;

    _currentPlaylist = [song];
    _currentPlaylistIndex = 0;
    _isShuffleActive = false;
    _isRepeatActive = false;
    notifyListeners();

    try {
      final songUrl =
          pb.getFileUrl(song, song.getStringValue('audioUrl')).toString();
      print('Attempting to play song from URL (file type): $songUrl');

      await _audioPlayer.setAudioSource(
        AudioSource.uri(Uri.parse(songUrl)),
      );
      _audioPlayer.play();
      await _addSongToRecentlyPlayed(song);
    } catch (e) {
      print("Error playing song: $e");
    }
  }

  Future<void> playPlaylist(List<RecordModel> playlist,
      {int startIndex = 0}) async {
    if (playlist.isEmpty) {
      _currentPlaylist = [];
      _currentSong = null;
      _currentPlaylistIndex = -1;
      _audioPlayer.stop();
      notifyListeners();
      return;
    }

    _currentPlaylist = List.from(playlist);
    _currentPlaylistIndex = startIndex;
    _currentSong = _currentPlaylist[startIndex];
    notifyListeners();

    final audioSources = _currentPlaylist.map((song) {
      final songUrl =
          pb.getFileUrl(song, song.getStringValue('audioUrl')).toString();
      return AudioSource.uri(
        Uri.parse(songUrl),
        tag: song.id,
      );
    }).toList();

    try {
      await _audioPlayer.setAudioSource(
        ConcatenatingAudioSource(
          children: audioSources,
        ),
        initialIndex: startIndex,
        initialPosition: Duration.zero,
      );
      if (_isShuffleActive) {
        await _audioPlayer.setShuffleModeEnabled(true);
        await _audioPlayer.shuffle();
      } else {
        await _audioPlayer.setShuffleModeEnabled(false);
      }
      _audioPlayer.play();

      if (_currentSong != null) {
        await _addSongToRecentlyPlayed(_currentSong!);
      }
    } catch (e) {
      print("Error playing playlist: $e");
    }
  }

  void togglePlayPause() {
    if (_audioPlayer.playerState.processingState == ProcessingState.ready ||
        _audioPlayer.playerState.processingState == ProcessingState.buffering ||
        _audioPlayer.playerState.processingState == ProcessingState.loading) {
      if (_audioPlayer.playing) {
        _audioPlayer.pause();
      } else {
        _audioPlayer.play();
      }
    } else if (_audioPlayer.playerState.processingState ==
        ProcessingState.completed) {
      if (_isRepeatActive) {
        _audioPlayer.seek(Duration.zero);
        _audioPlayer.play();
      } else {
        seekToNext();
      }
    }
    notifyListeners();
  }

  void seek(Duration position) {
    _audioPlayer.seek(position);
  }

  Future<void> seekToPrevious() async {
    if (_audioPlayer.hasPrevious) {
      await _audioPlayer.seekToPrevious();
    } else if (_audioPlayer.position.inSeconds > 5) {
      await _audioPlayer.seek(Duration.zero);
    } else if (_localPlayedSongIds.length > 1) {
      final previousSongId =
          _localPlayedSongIds[_localPlayedSongIds.length - 2];

      try {
        final previousSongRecord =
            await pb.collection('songs').getOne(previousSongId);
        print(
            'Playing from local history: ${previousSongRecord.getStringValue('title')}');

        await playSong(previousSongRecord);

        if (_localPlayedSongIds.isNotEmpty) {
          _localPlayedSongIds.removeLast();
        }
      } on ClientException catch (e) {
        print('Error fetching previous song from local history: ${e.response}');

        await _audioPlayer.seek(Duration.zero);
      } catch (e) {
        print('Unexpected error fetching previous song from local history: $e');
        await _audioPlayer.seek(Duration.zero);
      }
    } else {
      await _audioPlayer.seek(Duration.zero);
    }
    notifyListeners();
  }

  Future<void> seekToNext() async {
    if (_audioPlayer.hasNext) {
      await _audioPlayer.seekToNext();
    } else {
      print('No next song in queue. Playing random song...');
      _playRandomSongFromAll();
    }
    notifyListeners();
  }

  void toggleShuffle() async {
    _isShuffleActive = !_isShuffleActive;
    await _audioPlayer.setShuffleModeEnabled(_isShuffleActive);
    if (_isShuffleActive) {
      await _audioPlayer.shuffle();
    }
    notifyListeners();
  }

  void toggleRepeat() {
    _isRepeatActive = !_isRepeatActive;
    _audioPlayer.setLoopMode(_isRepeatActive ? LoopMode.one : LoopMode.off);
    notifyListeners();
  }

  void stop() {
    _audioPlayer.stop();
    _currentSong = null;
    _currentPlaylist = [];
    _currentPlaylistIndex = -1;
    _isShuffleActive = false;
    _isRepeatActive = false;
    notifyListeners();
  }
}
