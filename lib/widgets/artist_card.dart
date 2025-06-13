import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart'; // Import RecordModel
import 'package:lyrix/services/pocketbase_service.dart'; // Import pb untuk getFileUrl

// Hapus import: import 'package:lyrix/models/artist.dart';

class ArtistCard extends StatelessWidget {
  final RecordModel artistRecord; // <--- UBAH INI
  final VoidCallback onTap;

  const ArtistCard({
    super.key,
    required this.artistRecord, // <--- UBAH INI
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Ambil data dari RecordModel
    final String name =
        artistRecord.getStringValue('name'); // Asumsi field 'name' untuk artis
    // Perhatikan: Anda menggunakan field 'imageUrl' untuk gambar artis di PocketBase
    final String imageUrl = artistRecord.getStringValue('imageUrl').isNotEmpty
        ? pb
            .getFileUrl(artistRecord, artistRecord.getStringValue('imageUrl'))
            .toString()
        : ''; // Fallback jika tidak ada gambar

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          children: [
            CircleAvatar(
              radius: 60,
              // Gunakan imageUrl jika tidak kosong, jika tidak gunakan child ikon
              backgroundImage: imageUrl.isNotEmpty
                  ? NetworkImage(imageUrl)
                  : null, // Jika kosong, set null agar child tampil
              onBackgroundImageError: (exception, stackTrace) {
                print('Error loading artist image: $exception');
                // Anda bisa menambahkan logging atau tampilan error lain di sini
              },
              child: imageUrl.isEmpty // Tampilkan ikon jika tidak ada gambar
                  ? const Icon(
                      Icons.person,
                      size: 50,
                      color: Colors.white54,
                    )
                  : null, // Jika ada gambar, child-nya null
            ),
            const SizedBox(height: 8),
            Text(
              name,
              style: Theme.of(context).textTheme.bodyLarge,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
