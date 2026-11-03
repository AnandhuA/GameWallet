import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/image_cache_service.dart';
import '../../shared/widgets.dart';
import 'settings_provider.dart';

class CacheSettingsPanel extends StatelessWidget {
  const CacheSettingsPanel({super.key});
  @override
  Widget build(BuildContext context) {
    final images = context.watch<ImageCacheService>();
    final settings = context.watch<SettingsProvider>();
    Future<void> clear(bool data, bool art) => guarded(context, () async {
      if (data) await settings.clearCache();
      if (art) {
        await images.clear();
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Cache cleared. Your library and playthrough dates are preserved.',
            ),
          ),
        );
      }
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Offline cache', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          '${settings.metadataCacheCount} game-data entries · ${images.count} images · ${(images.bytes / 1048576).toStringAsFixed(1)} MB',
        ),
        const SizedBox(height: 6),
        Text(
          'Game data: ${settings.cacheHours} hours. Artwork: up to 100 MB / 500 images. Older artwork may be evicted; saved game information and dates remain available.',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: () => clear(true, false),
              child: const Text('Clear game data'),
            ),
            OutlinedButton(
              onPressed: () => clear(false, true),
              child: const Text('Clear images'),
            ),
            TextButton(
              onPressed: () => clear(true, true),
              child: const Text('Clear all cache'),
            ),
          ],
        ),
      ],
    );
  }
}
