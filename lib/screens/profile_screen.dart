import 'package:flutter/material.dart';
import 'package:lyrix/theme/app_theme.dart';
import 'package:lyrix/screens/edit_profile_screen.dart';
import 'package:lyrix/screens/library_screen.dart';
import 'package:lyrix/screens/liked_songs_screen.dart';
import 'package:lyrix/screens/recently_played_screen.dart';
import 'package:lyrix/screens/playlists_screen.dart';
import 'package:lyrix/screens/following_screen.dart';
import 'package:lyrix/screens/settings_screen.dart';
import 'package:lyrix/services/pocketbase_service.dart'; // Import ini
import 'package:lyrix/screens/login_screen.dart'; // Untuk navigasi setelah logout
import 'package:pocketbase/pocketbase.dart'; // Pastikan ini diimpor untuk RecordModel

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _userName = 'Guest User';
  String _userEmail = 'guest@example.com';
  String? _imageUrl; // Mengubah dari _avatarUrl menjadi _imageUrl

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    // Tambahkan listener untuk perubahan autentikasi secara real-time
    pb.authStore.onChange.listen((_) {
      _loadUserProfile(); // Muat ulang data profil saat ada perubahan autentikasi
    });
  }

  void _loadUserProfile() {
    if (pb.authStore.isValid && pb.authStore.model is RecordModel) {
      final user = pb.authStore.model as RecordModel;

      // --- DEBUGGING: Cetak objek user untuk melihat strukturnya ---
      print('Profile: User RecordModel raw: ${user.toJson()}');
      print('Profile: User ID: ${user.id}');
      print(
          'Profile: User Username: ${user.data['username']}'); // Ambil username dari data
      print(
          'Profile: User Email: ${user.data['email']}'); // Ambil email dari data
      print('Profile: User name from data: ${user.data['name']}');
      print(
          'Profile: User image from data: ${user.data['image']}'); // Menggunakan 'image'
      // --- END DEBUGGING ---

      setState(() {
        // Ambil nama dari field 'name' jika ada, jika tidak, gunakan username.
        _userName = user.data['name'] ?? user.data['username'] ?? 'No Name';

        // Ambil email dari field 'email' di data.
        _userEmail = user.data['email'] ?? 'guest@example.com';

        // Muat URL gambar yang sudah ada jika tersedia dari field 'image'
        if (user.data['image'] != null && user.data['image'].isNotEmpty) {
          try {
            // Gunakan pb.getFileUrl dengan nama field 'image'
            _imageUrl = pb.getFileUrl(user, user.data['image']).toString();
          } catch (e) {
            print('Error getting image URL in ProfileScreen: $e');
            _imageUrl = null;
          }
        } else {
          _imageUrl = null;
        }
      });
    } else {
      // Jika tidak ada user yang login, reset ke nilai default
      setState(() {
        _userName = 'Guest User';
        _userEmail = 'guest@example.com';
        _imageUrl = null;
      });
      print('User is not logged in on ProfileScreen.');
    }
  }

  void _logout() async {
    try {
      pb.authStore.clear(); // Hapus token autentikasi dari PocketBase

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Anda telah keluar dari akun'),
          backgroundColor: AppTheme.surfaceColor,
        ),
      );

      if (mounted) {
        // Navigasi kembali ke LoginScreen dan hapus semua rute sebelumnya
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal logout: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Profile',
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings_outlined),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SettingsScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              CircleAvatar(
                radius: 50,
                backgroundColor: AppTheme.primaryColor,
                // Gunakan _imageUrl jika tidak null, jika tidak, gunakan ikon default
                backgroundImage: _imageUrl != null
                    ? NetworkImage(_imageUrl!)
                    : null, // Jika _imageUrl null, backgroundImage juga null
                child: _imageUrl == null
                    ? const Icon(
                        Icons.person,
                        size: 50,
                        color: Colors.white,
                      )
                    : null, // Jika ada gambar, jangan tampilkan ikon
              ),
              const SizedBox(height: 16),
              Text(
                _userName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _userEmail,
                style: const TextStyle(
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EditProfileScreen(),
                    ),
                  ).then((value) {
                    // Muat ulang data profil setelah kembali dari EditProfileScreen
                    _loadUserProfile();
                  });
                },
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
                child: const Text('Edit Profile'),
              ),
              const SizedBox(height: 32),
              const Divider(),
              _buildListTile(
                context,
                'Your Library',
                Icons.library_music_outlined,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LibraryScreen(),
                    ),
                  );
                },
              ),
              _buildListTile(
                context,
                'Liked Songs',
                Icons.favorite_border,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LikedSongsScreen(),
                    ),
                  );
                },
              ),
              _buildListTile(
                context,
                'Recently Played',
                Icons.history,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RecentlyPlayedScreen(),
                    ),
                  );
                },
              ),
              _buildListTile(
                context,
                'Your Playlists',
                Icons.playlist_play,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PlaylistsScreen(),
                    ),
                  );
                },
              ),
              _buildListTile(
                context,
                'Following',
                Icons.people_outline,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FollowingScreen(),
                    ),
                  );
                },
              ),
              const Divider(),
              _buildListTile(
                context,
                'Settings',
                Icons.settings_outlined,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                },
              ),
              _buildListTile(
                context,
                'Help & Support',
                Icons.help_outline,
                () {},
              ),
              _buildListTile(
                context,
                'About',
                Icons.info_outline,
                () {},
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () {
                  _showLogoutDialog(context);
                },
                child: const Text(
                  'Log Out',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListTile(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap, {
    Widget? trailing,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: trailing ?? const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Keluar'),
        content: const Text('Apakah Anda yakin ingin keluar dari akun Anda?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Tutup dialog
              _logout(); // Panggil fungsi logout
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }
}
