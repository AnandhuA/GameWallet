import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'cached_catalog_image.dart';

import '../core/models.dart';
import '../features/details/details_page.dart';
import '../features/library/library_provider.dart';
import '../features/companion/game_actions.dart';

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
  const CatalogImage(this.source, {super.key, this.fit = BoxFit.contain});
  @override
  Widget build(BuildContext context) {
    Widget error(BuildContext context, Object error, StackTrace? trace) =>
        const Center(
          child: Icon(
            Icons.broken_image_outlined,
            semanticLabel: 'Image unavailable',
          ),
        );
    return source.startsWith('assets/art/')
        ? Image.asset(source, fit: fit, errorBuilder: error)
        : CachedCatalogImage(
            source,
            fit: fit,
            placeholder: error(context, StateError('Image unavailable'), null),
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
    final url = wide ? game.artwork ?? game.cover : game.cover;
    final placeholder = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(
              const Color(0xFF332454),
              const Color(0xFF155960),
              (game.id % 7) / 7,
            )!,
            const Color(0xFF101323),
          ],
        ),
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
          color: Colors.white38,
        ),
      ),
    );
    if (url == null) {
      if (game.demo) {
        return Image.asset(
          'assets/art/${game.id}.png',
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => placeholder,
        );
      }
      return placeholder;
    }
    return CachedCatalogImage(url, fit: BoxFit.cover, placeholder: placeholder);
  }
}

class GameCard extends StatelessWidget {
  final Game game;
  const GameCard(this.game, {super.key});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final titleStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w700,
      height: 1.35,
    );
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => openGame(context, game),
        onLongPress: () => GameActionsMenu(game).show(context),
        onSecondaryTap: () => GameActionsMenu(game).show(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: .78,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [GamePoster(game)],
                ),
              ),
            ),
            const SizedBox(height: 9),
            ConstrainedBox(
              constraints: BoxConstraints(
                minHeight:
                    MediaQuery.textScalerOf(
                      context,
                    ).scale(titleStyle?.fontSize ?? 14) *
                    2.7,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  game.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: titleStyle,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 0, 2, 4),
              child: Row(
                children: [
                  Icon(
                    Icons.star_rounded,
                    size: 16,
                    color: game.rating == null
                        ? colors.onSurfaceVariant
                        : const Color(0xFFD99B1C),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${game.rating == null ? 'Unrated' : game.rating!.round()}${game.release == null ? '' : '  ·  ${game.release!.year}'}',
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
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
                  borderRadius: BorderRadius.circular(7),
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
          ? (box.maxWidth / 205).floor().clamp(2, 6)
          : columns;
      final gap = count >= 4 ? 8.0 : 12.0;
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
      borderRadius: BorderRadius.circular(12),
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
                borderRadius: BorderRadius.circular(16),
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
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AspectRatio(
        aspectRatio: .72,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            fit: StackFit.expand,
            children: [
              InkWell(
                onTap: () => openGame(context, game),
                onLongPress: () => GameActionsMenu(game).show(context),
                onSecondaryTap: () => GameActionsMenu(game).show(context),
                child: GameArt(game),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 7),
      InkWell(
        onTap: () => openGame(context, game),
        onLongPress: () => GameActionsMenu(game).show(context),
        onSecondaryTap: () => GameActionsMenu(game).show(context),
        child: Text(
          game.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
        ),
      ),
      if (caption != null) ...[
        const SizedBox(height: 4),
        Text(
          caption!,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ],
  );
}
