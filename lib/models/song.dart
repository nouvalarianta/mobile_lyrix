class Song {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String imageUrl;
  final String albumImageUrl;
  final String duration;
  final int plays;
  final int likes;
  final String releaseYear;
  final int trackNumber;
  final String description;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.imageUrl,
    required this.albumImageUrl,
    required this.duration,
    required this.plays,
    required this.likes,
    required this.releaseYear,
    required this.trackNumber,
    required this.description,
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      artist: json['artist'] ?? '',
      album: json['album'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      albumImageUrl: json['albumImageUrl'] ?? '',
      duration: json['duration'] ?? '',
      plays: json['plays'] ?? 0,
      likes: json['likes'] ?? 0,
      releaseYear: json['releaseYear'] ?? '',
      trackNumber: json['trackNumber'] ?? 0,
      description: json['description'] ?? '',
    );
  }
}
