import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:lyrix/services/pocketbase_service.dart';

class SongCard extends StatelessWidget {
  final RecordModel songRecord;
  final VoidCallback onTap;

  const SongCard({
    super.key,
    required this.songRecord,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final String title = songRecord.getStringValue('title');
    final String artist = songRecord.getStringValue('artist');
    final String imageUrl = songRecord.getStringValue('image').isNotEmpty
        ? pb
            .getFileUrl(songRecord, songRecord.getStringValue('image'))
            .toString()
        : '';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      width: 160,
                      height: 160,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 160,
                          height: 160,
                          color: Colors.grey[800],
                          child: const Center(
                            child: Icon(
                              Icons.music_note,
                              size: 40,
                              color: Colors.white54,
                            ),
                          ),
                        );
                      },
                    )
                  : Container(
                      width: 160,
                      height: 160,
                      color: Colors.grey[800],
                      child: const Center(
                        child: Icon(
                          Icons.music_note,
                          size: 40,
                          color: Colors.white54,
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyLarge,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              artist,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.white54),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
