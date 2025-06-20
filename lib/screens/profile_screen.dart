import 'package:flutter/material.dart';
import 'package:lyrix/theme/app_theme.dart';
import 'package:lyrix/screens/edit_profile_screen.dart';
import 'package:lyrix/screens/liked_songs_screen.dart';
import 'package:lyrix/screens/recently_played_screen.dart';
import 'package:lyrix/screens/playlists_screen.dart';
import 'package:lyrix/screens/following_screen.dart';
import 'package:lyrix/screens/settings_screen.dart';
import 'package:lyrix/screens/help_and_support_screen.dart';
import 'package:lyrix/screens/about_screen.dart';
import 'package:lyrix/services/pocketbase_service.dart';
import 'package:lyrix/screens/login_screen.dart';
import 'package:pocketbase/pocketbase.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _userName = 'Guest User';
  String _userEmail = 'guest@example.com';
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    pb.authStore.onChange.listen((_) {
      _loadUserProfile();
    });
  }

  void _loadUserProfile() {
    if (pb.authStore.isValid && pb.authStore.model is RecordModel) {
      final user = pb.authStore.model as RecordModel;

      print('Profile: User RecordModel raw: ${user.toJson()}');
      print('Profile: User ID: ${user.id}');
      print('Profile: User Username: ${user.data['username']}');
      print('Profile: User Email: ${user.data['email']}');
      print('Profile: User name from data: ${user.data['name']}');
      print('Profile: User image from data: ${user.data['image']}');

      setState(() {
        _userName = user.data['name'] ?? user.data['username'] ?? 'No Name';
        _userEmail = user.data['email'] ?? 'guest@example.com';

        if (user.data['image'] != null && user.data['image'].isNotEmpty) {
          try {
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
      pb.authStore.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Anda telah keluar dari akun'),
        ),
      );

      if (mounted) {
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
                backgroundImage: _imageUrl != null
                    ? NetworkImage(_imageUrl!)
                    : const AssetImage('assets/images/default_avatar.png')
                        as ImageProvider<Object>,
                child: _imageUrl == null
                    ? const Icon(
                        Icons.person,
                        size: 50,
                        color: Colors.white,
                      )
                    : null,
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
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HelpAndSupportScreen(),
                    ),
                  );
                },
              ),
              _buildListTile(
                context,
                'About',
                Icons.info_outline,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AboutScreen(),
                    ),
                  );
                },
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
      leading: Icon(icon, color: Colors.white70),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      trailing:
          trailing ?? const Icon(Icons.chevron_right, color: Colors.white70),
      onTap: onTap,
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Log Out', style: TextStyle(color: Colors.white)),
        content: const Text('Apakah Anda yakin ingin keluar dari akun Anda?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal',
                style: TextStyle(color: AppTheme.primaryColor)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }
}
