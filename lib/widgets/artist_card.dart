import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:lyrix/services/pocketbase_service.dart';

class ArtistCard extends StatelessWidget {
  final RecordModel artistRecord;
  final VoidCallback onTap;

  const ArtistCard({
    super.key,
    required this.artistRecord,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final String name = artistRecord.getStringValue('name');

    final String imageUrl = artistRecord.getStringValue('imageUrl').isNotEmpty
        ? pb
            .getFileUrl(artistRecord, artistRecord.getStringValue('imageUrl'))
            .toString()
        : '';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          children: [
            CircleAvatar(
              radius: 60,
              backgroundImage:
                  imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
              onBackgroundImageError: (exception, stackTrace) {
                print('Error loading artist image: $exception');
              },
              child: imageUrl.isEmpty
                  ? const Icon(
                      Icons.person,
                      size: 50,
                      color: Colors.white54,
                    )
                  : null,
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
