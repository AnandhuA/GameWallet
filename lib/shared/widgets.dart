import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'cached_catalog_image.dart';
import 'app_theme.dart';
import 'wallet_components.dart';
export 'wallet_components.dart';

import '../core/models.dart';
import '../features/details/details_page.dart';
import '../features/library/library_provider.dart';

const accent = Color(0xFF00B4CF);
Future<void> openExternal(BuildContext context, String value) async {
  try {
    if (!await launchUrl(
      Uri.parse(value),
      mode: LaunchMode.externalApplication,
    )) {
      throw StateError('Unavailable');
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this link.')),
      );
    }
  }
}

class RawgAttribution extends StatelessWidget {
  const RawgAttribution({super.key});
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: TextButton.icon(
      onPressed: () => openExternal(context, 'https://rawg.io'),
      icon: Icon(Icons.open_in_new, size: 14),
      label: const Text('Data source: RAWG', style: TextStyle(fontSize: 12)),
    ),
  );
}

class CatalogSourceLabel extends StatelessWidget {
  final bool demo;
  const CatalogSourceLabel({super.key, required this.demo});
  @override
  Widget build(BuildContext context) => demo
      ? const Notice('Demo · fictional sample data')
      : const SizedBox.shrink();
}

class CatalogImage extends StatelessWidget {
  final String source;
  final BoxFit fit;
  final ValueChanged<String>? onUnavailable;
  const CatalogImage(
    this.source, {
    super.key,
    this.fit = BoxFit.contain,
    this.onUnavailable,
  });
  @override
  Widget build(BuildContext context) {
    Widget error(BuildContext context, Object error, StackTrace? trace) =>
        const Center(
          child: Icon(
            Icons.broken_image_outlined,
            semanticLabel: 'Image unavailable',
          ),
        );
    return CachedCatalogImage(
      source,
      fit: fit,
      placeholder: error(context, StateError('Image unavailable'), null),
      onUnavailable: onUnavailable,
    );
  }
}

void openGame(BuildContext context, Game game) => Navigator.of(
  context,
).push(MaterialPageRoute<void>(builder: (_) => DetailsPage(initial: game)));

class GameArt extends StatelessWidget {
  final Game game;
  final bool wide;
  const GameArt(this.game, {super.key, this.wide = false});
  @override
  Widget build(BuildContext context) {
    final sources = catalogImageSources([
      if (wide) ...[
        game.artwork,
        game.cover,
      ] else ...[
        game.cover,
        game.artwork,
      ],
      ...game.screenshots,
      ...game.fallbackImages,
    ]);
    final placeholder = DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
      ),
      child: Center(
        child: Icon(
          game.demo
              ? [
                  Icons.auto_awesome,
                  Icons.rocket_launch,
                  Icons.landscape,
                  Icons.castle,
                ][game.id % 4]
              : Icons.sports_esports_outlined,
          size: wide ? 110 : 64,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
    if (sources.isEmpty) {
      if (game.demo) {
        return Image.asset(
          'assets/art/${game.id}.png',
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => placeholder,
        );
      }
      return placeholder;
    }
    return CachedCatalogImage(
      sources.first,
      key: ValueKey('${game.key}:$wide'),
      fallbackSources: sources.skip(1).toList(),
      fit: BoxFit.cover,
      placeholder: placeholder,
    );
  }
}

class GameCard extends StatelessWidget {
  final Game game;
  const GameCard(this.game, {super.key});
  @override
  Widget build(BuildContext context) => GamePosterCard(game);
}

class GamePoster extends StatelessWidget {
  final Game game;
  const GamePoster(this.game, {super.key});
  @override
  Widget build(BuildContext context) {
    final status = context.select<LibraryProvider, LibraryStatus?>(
      (p) => p.entry(game)?.status,
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        GameArt(game),
        if (status != null) ...[
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 60,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black54],
                ),
              ),
            ),
          ),
          Positioned(
            left: 8,
            bottom: 8,
            right: 8,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .7),
                  borderRadius: WalletRadius.control,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      status == LibraryStatus.completed
                          ? Icons.check_circle_outline
                          : status == LibraryStatus.playing
                          ? Icons.sports_esports_outlined
                          : status == LibraryStatus.dropped
                          ? Icons.stop_circle_outlined
                          : Icons.bookmark_border,
                      size: 12,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        status.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class GameGrid extends StatelessWidget {
  final List<Game> games;
  final int columns;
  const GameGrid(this.games, {super.key, this.columns = 0});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final count = columns == 0
          ? (box.maxWidth / 160).floor().clamp(2, 7)
          : columns;
      const gap = WalletSpace.md;
      final width = (box.maxWidth - (count - 1) * gap) / count;
      return Wrap(
        spacing: gap,
        runSpacing: 16,
        children: games
            .map(
              (g) => SizedBox(
                width: width,
                child: width < 130 ? DenseGameCard(g) : GameCard(g),
              ),
            )
            .toList(),
      );
    },
  );
}

class Notice extends StatelessWidget {
  final String text;
  final IconData icon;
  const Notice(this.text, {super.key, this.icon = Icons.info_outline});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.secondaryContainer,
      borderRadius: WalletRadius.control,
    ),
    child: Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  final String title, message;
  final VoidCallback? retry;
  const EmptyState(this.title, this.message, {super.key, this.retry});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
    child: Center(
      child: Column(
        children: [
          Icon(
            Icons.explore_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          if (retry != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: FilledButton.icon(
                onPressed: retry,
                icon: Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ),
        ],
      ),
    ),
  );
}

class LoadingCards extends StatelessWidget {
  const LoadingCards({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading games',
    child: Column(
      children: [
        const LinearProgressIndicator(),
        const SizedBox(height: 24),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: List.generate(
            4,
            (_) => Container(
              width: 160,
              height: 235,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: WalletRadius.card,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

Future<void> guarded(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save this change. Please try again.'),
        ),
      );
    }
  }
}

/// Artwork-first cell for user-selected dense grids. Actions stay reachable
/// through long press or right-click; metadata never crowds the title.
class DenseGameCard extends StatelessWidget {
  final Game game;
  final String? caption;
  const DenseGameCard(this.game, {super.key, this.caption});
  @override
  Widget build(BuildContext context) => GamePosterCard(game, caption: caption);
}
