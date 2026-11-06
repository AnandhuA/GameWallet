import '../../shared/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/game_repository.dart';
import '../../core/models.dart';
import '../../shared/widgets.dart';
import '../library/library_provider.dart';
import '../library/library_editor.dart';
import '../companion/companion_providers.dart';
import '../companion/game_actions.dart';
import '../journal/journal_pages.dart';
import '../calendar/calendar_page.dart';
import 'game_details_provider.dart';
import '../pick/pick_page.dart';
import 'game_description.dart';
import 'game_image_gallery.dart';
import '../pricing/store_prices_section.dart';

class DetailsPage extends StatelessWidget {
  final Game initial;
  const DetailsPage({super.key, required this.initial});
  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (c) =>
        GameDetailsProvider(c.read<GameRepository>(), initial)..load(),
    child: const _DetailsBody(),
  );
}

class _DetailsBody extends StatelessWidget {
  const _DetailsBody();
  @override
  Widget build(BuildContext context) {
    final p = context.watch<GameDetailsProvider>();
    final g = p.game;
    final library = context.watch<LibraryProvider>();
    final saved = library.entry(g);
    final journal = context.watch<JournalProvider>().entries(
      g.demo,
      gameKey: g.key,
    );
    final colors = Theme.of(context).colorScheme;
    final images = <String>{
      if (g.cover != null) g.cover!,
      if (g.artwork != null) g.artwork!,
      ...g.screenshots,
    }.toList();
    Widget heading(String title) => SectionHeader(title);
    Widget badge(IconData icon, String text) => StatusPill(text, icon: icon);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 220,
            actions: [GameActionsMenu(g)],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  GameArt(g, wide: true),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black26,
                          colors.surface.withValues(alpha: .3),
                          colors.surface,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: WalletTokens.of(context).detailsWidth,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: WalletRadius.control,
                            child: SizedBox(
                              width: 88,
                              height: 117,
                              child: GameArt(g),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  g.title,
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  g.release == null
                                      ? 'Release date unavailable'
                                      : g.release!
                                            .toLocal()
                                            .toString()
                                            .split(' ')
                                            .first,
                                ),
                                if (g.genres.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      g.genres.join(', '),
                                      style: TextStyle(
                                        color: colors.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    if (g.rating != null)
                                      badge(
                                        Icons.star,
                                        '${(g.rating! / 20).toStringAsFixed(1)} ${g.demo ? 'Demo' : (g.provenance['rating'] ?? g.source).toUpperCase()}',
                                      ),
                                    if (saved?.status != null)
                                      badge(
                                        Icons.sports_esports,
                                        saved!.status == LibraryStatus.completed
                                            ? 'Already played'
                                            : saved.status ==
                                                  LibraryStatus.playing
                                            ? 'Now playing'
                                            : saved.status!.label,
                                      ),
                                    if ((saved?.completedRuns ?? 0) > 0)
                                      badge(
                                        Icons.replay,
                                        '${saved!.completedRuns}x played',
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (saved != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            library.timing(g),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      const SizedBox(height: 14),
                      LayoutBuilder(
                        builder: (context, c) {
                          final largeText =
                              MediaQuery.textScalerOf(context).scale(14) > 20;
                          final width =
                              (c.maxWidth - (largeText ? 8 : 16)) /
                              (largeText ? 2 : 3);
                          Widget action(
                            String label,
                            IconData icon,
                            VoidCallback onTap, {
                            bool active = false,
                          }) {
                            final primary = [
                              'Saved',
                              'Playing',
                              'Played',
                            ].contains(label);
                            final child = Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(icon, size: 18),
                                const SizedBox(width: 7),
                                Flexible(
                                  child: Text(
                                    label,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            );
                            final style = ButtonStyle(
                              minimumSize: const WidgetStatePropertyAll(
                                Size(0, 48),
                              ),
                              padding: WidgetStatePropertyAll(
                                EdgeInsets.symmetric(
                                  horizontal: primary ? 8 : 10,
                                  vertical: 10,
                                ),
                              ),
                              foregroundColor: WidgetStatePropertyAll(
                                active
                                    ? colors.onPrimaryContainer
                                    : primary
                                    ? colors.onSurface
                                    : colors.onSurfaceVariant,
                              ),
                              backgroundColor: WidgetStatePropertyAll(
                                active
                                    ? colors.primaryContainer
                                    : primary
                                    ? colors.surfaceContainerLow
                                    : Colors.transparent,
                              ),
                              shape: WidgetStatePropertyAll(
                                RoundedRectangleBorder(
                                  borderRadius: WalletRadius.control,
                                ),
                              ),
                              side: WidgetStatePropertyAll(
                                primary
                                    ? BorderSide(
                                        color: active
                                            ? colors.primary.withValues(
                                                alpha: .5,
                                              )
                                            : colors.outlineVariant,
                                      )
                                    : BorderSide.none,
                              ),
                              textStyle: WidgetStatePropertyAll(
                                Theme.of(context).textTheme.labelLarge,
                              ),
                            );
                            final button = Semantics(
                              selected: primary || label == 'Favorite'
                                  ? active
                                  : null,
                              child: TextButton(
                                onPressed: onTap,
                                style: style,
                                child: child,
                              ),
                            );
                            return primary
                                ? SizedBox(width: width, child: button)
                                : button;
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  action(
                                    'Saved',
                                    saved?.bookmarked == true
                                        ? Icons.bookmark
                                        : Icons.bookmark_border,
                                    () => guarded(
                                      context,
                                      () => library.toggleSaved(g),
                                    ),
                                    active: saved?.bookmarked == true,
                                  ),
                                  action(
                                    'Playing',
                                    Icons.sports_esports_outlined,
                                    () => guarded(
                                      context,
                                      () => library.setStatus(
                                        g,
                                        saved?.status == LibraryStatus.playing
                                            ? null
                                            : LibraryStatus.playing,
                                      ),
                                    ),
                                    active:
                                        saved?.status == LibraryStatus.playing,
                                  ),
                                  action(
                                    'Played',
                                    Icons.check_circle_outline,
                                    () {
                                      if (saved?.status ==
                                          LibraryStatus.completed) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute<void>(
                                            builder: (_) =>
                                                JournalPage(game: g),
                                          ),
                                        );
                                      } else {
                                        completeGame(context, g);
                                      }
                                    },
                                    active:
                                        saved?.status ==
                                        LibraryStatus.completed,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  borderRadius: WalletRadius.row,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Wrap(
                                    spacing: 2,
                                    runSpacing: 0,
                                    children: [
                                      if ((saved?.completedRuns ?? 0) > 0)
                                        action(
                                          'Play again',
                                          Icons.replay,
                                          () => guarded(
                                            context,
                                            () => library.setStatus(
                                              g,
                                              LibraryStatus.playing,
                                            ),
                                          ),
                                        ),
                                      action(
                                        'Spin',
                                        Icons.casino_outlined,
                                        () => Navigator.push(
                                          context,
                                          MaterialPageRoute<void>(
                                            builder: (_) => Scaffold(
                                              appBar: AppBar(
                                                title: const Text(
                                                  'Pick a game',
                                                ),
                                              ),
                                              body: PickPage(
                                                initialCandidates: [g],
                                                onExplore: () =>
                                                    Navigator.pop(context),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      action(
                                        'Journal',
                                        Icons.edit_note,
                                        () => Navigator.push(
                                          context,
                                          MaterialPageRoute<void>(
                                            builder: (_) =>
                                                JournalPage(game: g),
                                          ),
                                        ),
                                      ),
                                      action(
                                        'Plan',
                                        Icons.event_available,
                                        () => Navigator.push(
                                          context,
                                          MaterialPageRoute<void>(
                                            builder: (_) => PlanEditor(game: g),
                                          ),
                                        ),
                                      ),
                                      action(
                                        'Favorite',
                                        saved?.favorite == true
                                            ? Icons.favorite
                                            : Icons.favorite_border,
                                        () => guarded(
                                          context,
                                          () => library.favorite(g),
                                        ),
                                        active: saved?.favorite == true,
                                      ),
                                      action(
                                        'Library',
                                        Icons.tune,
                                        () => editLibrary(context, g),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      if (g.demo) const Notice('Demo · fictional sample data'),
                      if (p.loading) const LinearProgressIndicator(),
                      if (p.stale)
                        const Notice(
                          'Offline or service unavailable · saved details may be outdated.',
                          icon: Icons.cloud_off,
                        ),
                      if (p.error != null)
                        EmptyState(
                          'Showing saved game summary',
                          p.error!,
                          retry: () => p.load(forceRefresh: true),
                        ),
                      if (g.platforms.isNotEmpty) ...[
                        heading('Available on'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: g.platforms
                              .map((s) => Chip(label: Text(s)))
                              .toList(),
                        ),
                      ],
                      if (g.links.isNotEmpty || g.trailers.isNotEmpty) ...[
                        heading(
                          g.source == 'freetogame' ||
                                  g.provenance['links'] == 'freetogame'
                              ? 'Game links'
                              : 'Official links',
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final url in g.links)
                              OutlinedButton.icon(
                                onPressed: () => openExternal(context, url),
                                icon: const Icon(Icons.open_in_new),
                                label: Text(
                                  Uri.tryParse(url)?.host ?? 'Website',
                                ),
                              ),
                            for (final url in g.trailers)
                              OutlinedButton.icon(
                                onPressed: () => openExternal(context, url),
                                icon: const Icon(Icons.play_arrow),
                                label: const Text('Trailer'),
                              ),
                          ],
                        ),
                      ],
                      StorePricesSection(game: g),
                      heading('Description'),
                      GameDescription(
                        key: ValueKey('description:${g.key}'),
                        text: g.summary,
                      ),
                      heading('Game images'),
                      GameImageGallery(
                        key: ValueKey('gallery:${g.key}'),
                        sources: images,
                      ),
                      if (g.developers.isNotEmpty ||
                          g.publishers.isNotEmpty) ...[
                        heading('Developers & publishers'),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final columns = constraints.maxWidth >= 650
                                ? 3
                                : constraints.maxWidth >= 400
                                ? 2
                                : 1;
                            final width =
                                (constraints.maxWidth - (columns - 1) * 8) /
                                columns;
                            return Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final name in {
                                  ...g.developers,
                                  ...g.publishers,
                                })
                                  SizedBox(
                                    width: width,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: colors.surfaceContainerLow,
                                        borderRadius: WalletRadius.control,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.business_outlined,
                                              color: colors.primary,
                                              size: 22,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    name,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodyMedium
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                  ),
                                                  Text(
                                                    [
                                                      if (g.developers.contains(
                                                        name,
                                                      ))
                                                        'Developer',
                                                      if (g.publishers.contains(
                                                        name,
                                                      ))
                                                        'Publisher',
                                                    ].join(' · '),
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .labelSmall
                                                        ?.copyWith(
                                                          color: colors
                                                              .onSurfaceVariant,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ],
                      if (!g.demo) ...[
                        heading('Catalog sources'),
                        Wrap(
                          children: [
                            if (g.source == 'rawg' ||
                                g.provenance.values.contains('rawg'))
                              TextButton(
                                onPressed: () =>
                                    openExternal(context, 'https://rawg.io/'),
                                child: const Text('RAWG'),
                              ),
                            if (g.source == 'freetogame' ||
                                g.fallbackImages.isNotEmpty ||
                                g.provenance.values.contains('freetogame'))
                              TextButton(
                                onPressed: () => openExternal(
                                  context,
                                  'https://www.freetogame.com/',
                                ),
                                child: const Text('FreeToGame'),
                              ),
                          ],
                        ),
                        if (g.provenance.isNotEmpty)
                          Text(
                            'Supplementary fields: ${g.provenance.entries.map((e) => '${const {'summary': 'Description', 'cover': 'Cover', 'fallbackImages': 'Artwork', 'release': 'Release date', 'developers': 'Developers', 'publishers': 'Publishers', 'genres': 'Genres', 'platforms': 'Platforms', 'links': 'Game links', 'screenshots': 'Screenshots', 'rating': 'Rating', 'primary': 'Catalog information'}[e.key] ?? 'Game information'}: ${e.value == 'rawg' ? 'RAWG' : 'FreeToGame'}').join(' · ')}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                      if (p.catalogMatches.isNotEmpty) ...[
                        heading('Other catalog matches'),
                        const Text(
                          'Confirm only if the title and edition refer to the same game. Your saved records will remain unchanged.',
                        ),
                        for (final candidate in p.catalogMatches)
                          ListTile(
                            title: Text(candidate.title),
                            subtitle: Text(
                              [
                                candidate.source,
                                if (candidate.release != null)
                                  '${candidate.release!.year}',
                                ...candidate.developers,
                                ...candidate.platforms,
                              ].join(' · '),
                            ),
                            trailing: const Icon(Icons.link),
                            onTap: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Same game and edition?'),
                                  content: Text(
                                    'Link ${g.source} and ${candidate.source} listings for ${g.title}? Notes, journals and playthroughs will not be merged or deleted.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Confirm match'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true && context.mounted) {
                                await guarded(
                                  context,
                                  () => p.confirmCatalogMatch(candidate),
                                );
                              }
                            },
                          ),
                      ],
                      heading('Your playthroughs'),
                      if (journal.isEmpty)
                        const Text(
                          'No reviews yet. Record a playthrough to start your journal.',
                        ),
                      for (final entry in journal.take(3))
                        Card(
                          child: ListTile(
                            title: Text(
                              entry.rating == null
                                  ? 'Unrated playthrough'
                                  : '${entry.rating}/5 stars',
                            ),
                            subtitle: Text(
                              entry.review.isEmpty ? entry.notes : entry.review,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    JournalDetail(id: entry.id, demo: g.demo),
                              ),
                            ),
                          ),
                        ),
                      if (p.similar.isNotEmpty) ...[
                        heading('Suggestions'),
                        GameGrid(p.similar),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
