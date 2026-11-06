import '../../shared/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models.dart';
import '../../shared/widgets.dart';
import '../library/library_provider.dart';
import '../library/library_editor.dart';
import '../settings/settings_provider.dart';
import 'home_provider.dart';
import '../companion/companion_providers.dart';
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
    final primaryKeys = p.sections.entries
        .where((e) => e.key != 'Free-to-play')
        .expand((e) => e.value)
        .map(p.repository.canonicalKey)
        .toSet();
    final free = (p.sections['Free-to-play'] ?? <Game>[])
        .where(
          (g) =>
              !hidden.hidden(g) &&
              !library.excludedFromDiscovery(g) &&
              !primaryKeys.contains(p.repository.canonicalKey(g)),
        )
        .toList();
    final popular = (p.sections['Popular right now'] ?? <Game>[])
        .where((g) => !hidden.hidden(g) && !library.excludedFromDiscovery(g))
        .toList();
    final trending = smartCandidates(
      p.repository
          .deduplicate([
            ...(p.sections['Popular right now'] ?? <Game>[]),
            ...free,
          ])
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
    final featured = trending.firstOrNull ?? free.firstOrNull;
    void reload() =>
        p.load(settings.demo, settings.platforms, forceRefresh: true);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76 * MediaQuery.textScalerOf(context).scale(14) / 14,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hi, ${settings.displayName}',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 22),
            ),
            const Text(
              'What are we playing today?',
              style: TextStyle(
                fontFamily: 'Figtree',
                fontWeight: FontWeight.w400,
                fontSize: 12,
              ),
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
            if (p.notice != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(p.notice!),
              ),
            if (p.error != null)
              EmptyState('Discovery is unavailable', p.error!, retry: reload),
            if (featured != null) ...[
              const SectionHeading('Made for you'),
              const SizedBox(height: 14),
              FeatureGameCard(featured),
              const SizedBox(height: 12),
              SizedBox(
                height: 240 * MediaQuery.textScalerOf(context).scale(14) / 14,
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
                          child: ActionChip(
                            onPressed: () => widget.onBrowse(platform: p.key),
                            label: Text(p.value),
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
            if (free.isNotEmpty) ...[
              const SizedBox(height: 28),
              const SectionHeading('Free-to-play'),
              TextButton(
                onPressed: () =>
                    openExternal(context, 'https://www.freetogame.com/'),
                child: const Text('Supplementary catalog: FreeToGame'),
              ),
              PosterShelf(free),
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
            if (!settings.demo)
              Wrap(
                children: [
                  TextButton(
                    onPressed: () => openExternal(context, 'https://rawg.io/'),
                    child: const Text('Catalog: RAWG'),
                  ),
                  TextButton(
                    onPressed: () =>
                        openExternal(context, 'https://www.freetogame.com/'),
                    child: const Text('FreeToGame'),
                  ),
                ],
              ),
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
    ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
  );
}

class FeatureGameCard extends StatelessWidget {
  final Game game;
  final bool compact;
  const FeatureGameCard(this.game, {super.key, this.compact = false});
  @override
  Widget build(BuildContext context) {
    final entry = context.watch<LibraryProvider>().entry(game);
    final tokens = WalletTokens.of(context), text = Theme.of(context).textTheme;
    if (compact) {
      return GameListRow(game, metadata: game.genres.take(2).join(' · '));
    }
    return ClipRRect(
      borderRadius: WalletRadius.card,
      child: Stack(
        children: [
          Positioned.fill(
            child: ExcludeSemantics(child: GameArt(game, wide: true)),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: tokens.scrim),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(WalletSpace.page),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Recommended for you',
                    style: text.labelLarge?.copyWith(
                      color: tokens.artworkMuted,
                    ),
                  ),
                  const SizedBox(height: WalletSpace.md),
                  GameInteraction(
                    game: game,
                    child: Text(
                      game.title,
                      style: text.headlineSmall?.copyWith(
                        color: tokens.artworkText,
                      ),
                    ),
                  ),
                  const SizedBox(height: WalletSpace.sm),
                  Text(
                    [
                      if (game.release != null) '${game.release!.year}',
                      ...game.genres.take(2),
                    ].join(' · '),
                    style: text.bodySmall?.copyWith(color: tokens.artworkMuted),
                  ),
                  const SizedBox(height: WalletSpace.md),
                  Wrap(
                    spacing: WalletSpace.sm,
                    runSpacing: WalletSpace.sm,
                    children: [
                      FilledButton.icon(
                        onPressed: () => editLibrary(context, game),
                        icon: const Icon(Icons.bookmark_border, size: 18),
                        label: Text(entry?.status?.label ?? 'Want to play'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => guarded(context, () async {
                          await context.read<LibraryProvider>().startPlaying(
                            game,
                          );
                        }),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: tokens.artworkText,
                          side: BorderSide(
                            color: tokens.artworkMuted.withValues(alpha: .5),
                          ),
                        ),
                        icon: const Icon(Icons.play_arrow_outlined, size: 18),
                        label: const Text('Play'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MiniGameCard extends StatelessWidget {
  final Game game;
  const MiniGameCard(this.game, {super.key});
  @override
  Widget build(BuildContext context) => GameListRow(
    game,
    compact: true,
    metadata: game.genres.take(2).join(' · '),
    caption:
        '${game.release?.year ?? 'TBA'}${game.rating == null ? '' : ' · ${game.rating!.round()}/100'}',
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
          : 156.0;
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final game in games)
              Padding(
                padding: const EdgeInsets.only(right: WalletSpace.md),
                child: SizedBox(
                  width: width,
                  child: GamePosterCard(
                    game,
                    caption:
                        '${game.release?.year ?? 'TBA'}${game.rating == null ? '' : ' · ${game.rating!.round()}/100'}',
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}
