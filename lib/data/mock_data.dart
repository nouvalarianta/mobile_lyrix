import 'package:lyrix/models/song.dart';
import 'package:lyrix/models/artist.dart';

class MockData {
  static List<Song> getSongs() {
    return [
      Song(
        id: '1',
        title: 'Blinding Lights',
        artist: 'The Weeknd',
        album: 'After Hours',
        imageUrl:
            'https://via.placeholder.com/300/121212/FFFFFF?text=Blinding+Lights',
        albumImageUrl:
            'https://via.placeholder.com/300/121212/FFFFFF?text=After+Hours',
        duration: '3:20',
        plays: 1500000,
        likes: 750000,
        releaseYear: '2020',
        trackNumber: 9,
        description:
            'Blinding Lights is a song by Canadian singer the Weeknd. It was released on November 29, 2019, as the second single from his fourth studio album After Hours.',
      ),
      Song(
        id: '2',
        title: 'Shape of You',
        artist: 'Ed Sheeran',
        album: '÷ (Divide)',
        imageUrl:
            'https://via.placeholder.com/300/121212/FFFFFF?text=Shape+of+You',
        albumImageUrl:
            'https://via.placeholder.com/300/121212/FFFFFF?text=Divide',
        duration: '3:54',
        plays: 2000000,
        likes: 1000000,
        releaseYear: '2017',
        trackNumber: 1,
        description:
            'Shape of You is a song by English singer-songwriter Ed Sheeran. It was released on 6 January 2017 as one of the double lead singles from his third studio album ÷.',
      ),
      Song(
        id: '3',
        title: 'Dance Monkey',
        artist: 'Tones and I',
        album: 'The Kids Are Coming',
        imageUrl:
            'https://via.placeholder.com/300/121212/FFFFFF?text=Dance+Monkey',
        albumImageUrl:
            'https://via.placeholder.com/300/121212/FFFFFF?text=The+Kids+Are+Coming',
        duration: '3:29',
        plays: 1800000,
        likes: 900000,
        releaseYear: '2019',
        trackNumber: 2,
        description:
            'Dance Monkey is a song by Australian singer Tones and I, released on 10 May 2019 as the second single from her debut EP The Kids Are Coming.',
      ),
      Song(
        id: '4',
        title: 'Bad Guy',
        artist: 'Billie Eilish',
        album: 'When We All Fall Asleep, Where Do We Go?',
        imageUrl: 'https://via.placeholder.com/300/121212/FFFFFF?text=Bad+Guy',
        albumImageUrl:
            'https://via.placeholder.com/300/121212/FFFFFF?text=WWAFAWDWG',
        duration: '3:14',
        plays: 1700000,
        likes: 850000,
        releaseYear: '2019',
        trackNumber: 2,
        description:
            'Bad Guy is a song by American singer Billie Eilish. It was released on March 29, 2019, as the fifth single from her debut studio album When We All Fall Asleep, Where Do We Go?',
      ),
      Song(
        id: '5',
        title: 'Levitating',
        artist: 'Dua Lipa',
        album: 'Future Nostalgia',
        imageUrl:
            'https://via.placeholder.com/300/121212/FFFFFF?text=Levitating',
        albumImageUrl:
            'https://via.placeholder.com/300/121212/FFFFFF?text=Future+Nostalgia',
        duration: '3:23',
        plays: 1600000,
        likes: 800000,
        releaseYear: '2020',
        trackNumber: 5,
        description:
            'Levitating is a song by English singer Dua Lipa from her second studio album Future Nostalgia (2020). It was released on 2 October 2020 as the fifth single from the album.',
      ),
    ];
  }

  static List<Artist> getArtists() {
    return [
      Artist(
        id: '1',
        name: 'The Weeknd',
        imageUrl:
            'https://via.placeholder.com/300/121212/FFFFFF?text=The+Weeknd',
        followers: 45000000,
        monthlyListeners: 75000000,
        topTracks: 15,
        bio:
            'Abel Makkonen Tesfaye, known professionally as the Weeknd, is a Canadian singer, songwriter, and record producer. He is known for his sonic versatility and dark lyricism.',
      ),
      Artist(
        id: '2',
        name: 'Ed Sheeran',
        imageUrl:
            'https://via.placeholder.com/300/121212/FFFFFF?text=Ed+Sheeran',
        followers: 50000000,
        monthlyListeners: 80000000,
        topTracks: 20,
        bio:
            'Edward Christopher Sheeran MBE is an English singer, songwriter, musician, record producer, and actor. He has sold more than 150 million records worldwide, making him one of the world\'s best-selling music artists.',
      ),
      Artist(
        id: '3',
        name: 'Billie Eilish',
        imageUrl:
            'https://via.placeholder.com/300/121212/FFFFFF?text=Billie+Eilish',
        followers: 40000000,
        monthlyListeners: 70000000,
        topTracks: 12,
        bio:
            'Billie Eilish Pirate Baird O\'Connell is an American singer and songwriter. She first gained public attention in 2015 with her debut single "Ocean Eyes".',
      ),
      Artist(
        id: '4',
        name: 'Dua Lipa',
        imageUrl: 'https://via.placeholder.com/300/121212/FFFFFF?text=Dua+Lipa',
        followers: 35000000,
        monthlyListeners: 65000000,
        topTracks: 10,
        bio:
            'Dua Lipa is an English singer and songwriter. After working as a model, she signed with Warner Bros. Records in 2014 and released her self-titled debut album in 2017.',
      ),
      Artist(
        id: '5',
        name: 'Tones and I',
        imageUrl:
            'https://via.placeholder.com/300/121212/FFFFFF?text=Tones+and+I',
        followers: 20000000,
        monthlyListeners: 40000000,
        topTracks: 5,
        bio:
            'Toni Watson, known professionally as Tones and I, is an Australian singer and songwriter. Her breakout single, "Dance Monkey", was released in May 2019 and reached number one in over 30 countries.',
      ),
    ];
  }

  static List<Song> getArtistSongs(String artistId) {
    // Return songs filtered by artist ID
    return getSongs()
        .where((song) =>
            song.artist ==
            getArtists().firstWhere((artist) => artist.id == artistId).name)
        .toList();
  }
}
