import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models.dart';
import '../../shared/widgets.dart';
import '../library/library_provider.dart';
import '../library/library_editor.dart';
import '../settings/settings_provider.dart';
import 'home_provider.dart';
import '../companion/companion_providers.dart';
import '../companion/game_actions.dart';
import '../journal/journal_pages.dart';
import '../settings/preferences_page.dart';

class HomePage extends StatefulWidget {
  final void Function({String? genre, String? platform}) onBrowse;
  final VoidCallback onSearch, onPick;
  const HomePage({
    super.key,
    required this.onBrowse,
    required this.onSearch,
    required this.onPick,
  });
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool upcoming = false;
  @override
  Widget build(BuildContext context) {
    final p = context.watch<HomeProvider>();
    final settings = context.watch<SettingsProvider>();
    final hidden = context.watch<DiscoveryPreferencesProvider>();
    final library = context.watch<LibraryProvider>();
    final popular = (p.sections['Popular right now'] ?? <Game>[])
        .where((g) => !hidden.hidden(g) && !library.excludedFromDiscovery(g))
        .toList();
    final trending = smartCandidates(
      (p.sections['Popular right now'] ?? <Game>[])
          .where((g) => !library.excludedFromDiscovery(g))
          .toList(),
      library,
      hidden,
      unfinished: false,
      preferredGenres: settings.genres,
    );
    final top = (p.sections['Top rated'] ?? <Game>[])
        .where((g) => !hidden.hidden(g) && !library.excludedFromDiscovery(g))
        .toList();
    final releases =
        (p.sections[upcoming ? 'On the horizon' : 'Fresh releases'] ?? <Game>[])
            .where(
              (g) => !hidden.hidden(g) && !library.excludedFromDiscovery(g),
            )
            .toList();
    final featured = trending.firstOrNull;
    void reload() =>
        p.load(settings.demo, settings.platforms, forceRefresh: true);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hi, ${settings.displayName}',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22),
            ),
            const Text(
              'What are we playing today?',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Smart Pick',
            onPressed: widget.onPick,
            icon: Icon(
              Icons.auto_awesome,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          IconButton(
            tooltip: 'Search games',
            onPressed: widget.onSearch,
            icon: Icon(Icons.search),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            p.load(settings.demo, settings.platforms, forceRefresh: true),
        child: ListView(
          key: const PageStorageKey('home'),
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
          children: [
            const SizedBox(height: 16),
            if (!settings.setupComplete)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const PreferencesPage(),
                    ),
                  ),
                  icon: const Icon(Icons.tune, size: 18),
                  label: const Text('Personalize your game picks'),
                ),
              ),
            if (p.stale)
              const Notice(
                'Offline · saved results may be outdated.',
                icon: Icons.cloud_off,
              ),
            if (p.loading) const LoadingCards(),
            if (p.error != null)
              EmptyState('Discovery is unavailable', p.error!, retry: reload),
            if (featured != null) ...[
              const SectionHeading('Made for you'),
              const SizedBox(height: 14),
              FeatureGameCard(featured),
              const SizedBox(height: 12),
              SizedBox(
                height: 240,
                child: GridView.builder(
                  scrollDirection: Axis.horizontal,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisExtent: 250,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 10,
                  ),
                  itemCount: trending.skip(1).take(10).length,
                  itemBuilder: (context, index) =>
                      MiniGameCard(trending.skip(1).take(10).elementAt(index)),
                ),
              ),
              const SizedBox(height: 24),
            ],
            if (!p.loading &&
                p.error == null &&
                popular.isEmpty &&
                settings.platforms.isNotEmpty)
              Column(
                children: [
                  const Text('No new games match your platforms.'),
                  TextButton(
                    onPressed: () => widget.onBrowse(platform: ''),
                    child: const Text('Explore all platforms'),
                  ),
                ],
              ),
            if (p.filters.platforms.isNotEmpty) ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: p.filters.platforms.entries
                      .where(
                        (p) =>
                            settings.demo ||
                            [
                              'PC',
                              'PlayStation 5',
                              'Xbox Series S/X',
                              'Android',
                              'iOS',
                              'Nintendo Switch',
                            ].contains(p.value),
                      )
                      .map(
                        (p) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: TextButton(
                            onPressed: () => widget.onBrowse(platform: p.key),
                            child: Text(p.value),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const Divider(height: 1),
              const SizedBox(height: 18),
            ],
            if (trending.isNotEmpty) ...[
              PosterShelf(trending.take(10).toList()),
              const SizedBox(height: 28),
            ],
            Row(
              children: [
                const Expanded(child: SectionHeading('New releases')),
                IconButton(
                  tooltip: 'Refresh games',
                  onPressed: p.loading ? null : reload,
                  icon: Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    label: Text('Released'),
                    icon: Icon(Icons.sports_esports_outlined),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text('Upcoming'),
                    icon: Icon(Icons.upcoming_outlined),
                  ),
                ],
                selected: {upcoming},
                onSelectionChanged: (v) => setState(() => upcoming = v.single),
              ),
            ),
            const SizedBox(height: 18),
            if (releases.isNotEmpty)
              PosterShelf(releases.take(10).toList())
            else if (!p.loading && p.error == null)
              const EmptyState(
                'No releases found',
                'Try another platform or check back later.',
              ),
            if (featured != null) ...[
              const SizedBox(height: 24),
              FeatureGameCard(featured, compact: true),
              const SizedBox(height: 28),
              const SectionHeading('Trending now'),
              const SizedBox(height: 16),
              PosterShelf(popular),
            ],
            if (top.isNotEmpty) ...[
              const SizedBox(height: 28),
              const SectionHeading('Top rated'),
              const SizedBox(height: 16),
              PosterShelf(top),
            ],
            if (p.filters.genres.isNotEmpty) ...[
              const SizedBox(height: 28),
              const SectionHeading('Find your kind of game'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: p.filters.genres.entries
                    .take(12)
                    .map(
                      (g) => ActionChip(
                        label: Text(g.value),
                        onPressed: () => widget.onBrowse(genre: g.key),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class SectionHeading extends StatelessWidget {
  final String text;
  const SectionHeading(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(
      context,
    ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
  );
}

class FeatureGameCard extends StatelessWidget {
  final Game game;
  final bool compact;
  const FeatureGameCard(this.game, {super.key, this.compact = false});
  @override
  Widget build(BuildContext context) {
    final entry = context.watch<LibraryProvider>().entry(game);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openGame(context, game),
        child: Stack(
          children: [
            if (!compact) Positioned.fill(child: GameArt(game, wide: true)),
            if (!compact)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: .78),
                        Colors.black.withValues(alpha: .68),
                      ],
                    ),
                  ),
                ),
              ),
            Positioned(right: 0, top: 0, child: GameActionsMenu(game)),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: compact ? 84 : 88,
                    height: compact ? 118 : 145,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: GamePoster(game),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        Text(
                          compact ? 'Trending game' : 'Pick for you',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          game.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: compact ? null : Colors.white,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${game.release?.year ?? 'TBA'} · ${game.genres.firstOrNull ?? 'Game'}${game.rating == null ? '' : ' · ${game.rating!.round()}/100'}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: compact
                                ? Theme.of(context).colorScheme.onSurfaceVariant
                                : Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        if (!compact)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Wrap(
                              spacing: 2,
                              runSpacing: 0,
                              children: [
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                    ),
                                  ),
                                  onPressed: () => editLibrary(context, game),
                                  icon: Icon(Icons.bookmark_border, size: 17),
                                  label: Text(
                                    entry?.status?.label ?? 'Want to play',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Favorite ${game.title}',
                                  onPressed: () => guarded(
                                    context,
                                    () => context
                                        .read<LibraryProvider>()
                                        .favorite(game),
                                  ),
                                  icon: Icon(
                                    entry?.favorite == true
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    size: 20,
                                    color: entry?.favorite == true
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.white,
                                  ),
                                ),
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                    ),
                                  ),
                                  onPressed: () => guarded(context, () async {
                                    await completeGame(context, game);
                                  }),
                                  icon: const Icon(
                                    Icons.check_circle_outline,
                                    size: 17,
                                  ),
                                  label: const Text(
                                    'Completed',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
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

class MiniGameCard extends StatelessWidget {
  final Game game;
  const MiniGameCard(this.game, {super.key});
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => openGame(context, game),
      child: Stack(
        children: [
          Positioned.fill(child: GameArt(game, wide: true)),
          Positioned.fill(
            child: ColoredBox(color: Colors.black.withValues(alpha: .76)),
          ),
          Padding(
            padding: const EdgeInsets.all(9),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 48,
                  height: 78,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: GamePoster(game),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        game.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        game.genres.firstOrNull ?? 'Game',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        game.rating == null
                            ? '${game.release?.year ?? 'TBA'}'
                            : '★ ${game.rating!.round()}',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
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

class PosterShelf extends StatelessWidget {
  final List<Game> games;
  const PosterShelf(this.games, {super.key});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final width = box.maxWidth < 600
          ? (box.maxWidth / 3.05).clamp(105.0, 160.0)
          : 174.0;
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: games
              .map(
                (g) => Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: SizedBox(
                    width: width,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => openGame(context, g),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AspectRatio(
                            aspectRatio: .67,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: GamePoster(g),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            g.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${g.release?.year ?? 'TBA'}${g.rating == null ? '' : ' · ${g.rating!.round()}/100'}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      );
    },
  );
}
