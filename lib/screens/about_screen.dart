import 'package:flutter/material.dart';
import 'package:lyrix/theme/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Tentang Lyrix', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: AppTheme.backgroundColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  const Icon(Icons.music_note,
                      size: 80, color: AppTheme.primaryColor),
                  const SizedBox(height: 16),
                  Text(
                    'Lyrix',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Versi Aplikasi: 1.0.0',
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(color: Colors.white70),
                  ),
                  Text(
                    'Build: 1 (Alpha)',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            const Divider(color: Colors.white24),
            const SizedBox(height: 24),
            Text(
              'Misi Kami',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'Lyrix bertujuan untuk menjadi platform utama Anda dalam menemukan, mendengarkan, dan mengelola musik favorit Anda. Kami percaya musik memiliki kekuatan untuk menyatukan dan menginspirasi.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            Text(
              'Teknologi',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'Dibangun dengan ❤️ menggunakan Flutter dan didukung oleh PocketBase untuk backend yang cepat dan efisien.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            Text(
              'Hak Cipta & Lisensi',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              '© 2025 Lyrix App. Semua hak dilindungi undang-undang.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.white70),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.gavel_outlined,
                  color: AppTheme.primaryColor),
              title: const Text('Syarat & Ketentuan',
                  style: TextStyle(color: Colors.white)),
              onTap: () {},
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.policy_outlined,
                  color: AppTheme.primaryColor),
              title: const Text('Kebijakan Privasi',
                  style: TextStyle(color: Colors.white)),
              onTap: () {},
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
