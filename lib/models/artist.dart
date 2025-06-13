class Artist {
  final String id;
  final String name;
  final String imageUrl;
  final int followers;
  final int monthlyListeners;
  final int topTracks;
  final String bio;

  Artist({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.followers,
    required this.monthlyListeners,
    required this.topTracks,
    required this.bio,
  });

  factory Artist.fromJson(Map<String, dynamic> json) {
    return Artist(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      followers: json['followers'] ?? 0,
      monthlyListeners: json['monthlyListeners'] ?? 0,
      topTracks: json['topTracks'] ?? 0,
      bio: json['bio'] ?? '',
    );
  }
}
