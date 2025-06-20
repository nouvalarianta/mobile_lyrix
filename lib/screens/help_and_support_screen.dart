import 'package:flutter/material.dart';
import 'package:lyrix/theme/app_theme.dart';

class HelpAndSupportScreen extends StatelessWidget {
  const HelpAndSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bantuan & Dukungan',
            style: TextStyle(color: Colors.white)),
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
            Text(
              'Selamat Datang di Bantuan Lyrix',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text(
              'Jika Anda memiliki pertanyaan, masalah, atau memerlukan bantuan terkait aplikasi Lyrix, silakan lihat topik di bawah atau hubungi kami.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            Text(
              'Topik Umum:',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 8),
            _buildHelpTopic(context, 'Memulai dengan Lyrix',
                'Panduan cepat untuk pengguna baru.'),
            _buildHelpTopic(context, 'Mengelola Playlist Anda',
                'Cara membuat, mengedit, dan menghapus playlist.'),
            _buildHelpTopic(context, 'Masalah Pemutaran Audio',
                'Solusi untuk masalah suara atau buffering.'),
            _buildHelpTopic(context, 'Pengaturan Akun & Privasi',
                'Cara mengelola profil dan privasi Anda.'),
            const SizedBox(height: 24),
            Text(
              'Hubungi Kami:',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.email, color: AppTheme.primaryColor),
              title: const Text('Email Dukungan',
                  style: TextStyle(color: Colors.white)),
              subtitle: Text('support@lyrixapp.com',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.white70)),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.web, color: AppTheme.primaryColor),
              title: const Text('Kunjungi Situs Web Kami',
                  style: TextStyle(color: Colors.white)),
              subtitle: Text('www.lyrixapp.com/help',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.white70)),
              onTap: () {},
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpTopic(BuildContext context, String title, String subtitle) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      color: AppTheme.surfaceColor,
      child: ListTile(
        title: Text(title,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: Colors.white)),
        subtitle: Text(subtitle,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.white70)),
        trailing: const Icon(Icons.chevron_right, color: Colors.white70),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Topik "${title}" dipilih.')),
          );
        },
      ),
    );
  }
}
