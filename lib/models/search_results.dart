import 'package:lyrix/models/song.dart';
import 'package:lyrix/models/artist.dart';

class SearchResults {
  final List<Song> songs;
  final List<Artist> artists;

  SearchResults({
    required this.songs,
    required this.artists,
  });

  // Factory method to create SearchResults from JSON
  factory SearchResults.fromJson(Map<String, dynamic> json) {
    List<Song> songs = [];
    List<Artist> artists = [];

    if (json['songs'] != null) {
      songs = (json['songs'] as List).map((songJson) => Song.fromJson(songJson)).toList();
    }

    if (json['artists'] != null) {
      artists = (json['artists'] as List).map((artistJson) => Artist.fromJson(artistJson)).toList();
    }

    return SearchResults(
      songs: songs,
      artists: artists,
    );
  }

  // Empty search results
  factory SearchResults.empty() {
    return SearchResults(
      songs: [],
      artists: [],
    );
  }
}
