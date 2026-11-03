import '../../shared/grid_density_button.dart';
import '../settings/settings_provider.dart';
import '../library/library_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../shared/widgets.dart';
import 'search_provider.dart';
import '../companion/companion_providers.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});
  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  final controller = TextEditingController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final columns = context.select<SettingsProvider, int>(
      (p) => p.gridColumns('explore'),
    );
    final p = context.watch<SearchProvider>();
    final hidden = context.watch<DiscoveryPreferencesProvider>();
    final library = context.watch<LibraryProvider>();
    final visibleGames = p.games
        .where((g) => !hidden.hidden(g) && !library.excludedFromDiscovery(g))
        .toList();
    if (controller.text != p.query) {
      controller.value = TextEditingValue(
        text: p.query,
        selection: TextSelection.collapsed(offset: p.query.length),
      );
    }
    void apply({
      String? genre,
      String? platform,
      int? year,
      String? sort,
      String? changed,
    }) => p.apply(
      genreValue: changed == 'genre' ? genre : p.genre,
      platformValue: changed == 'platform' ? platform : p.platform,
      yearValue: changed == 'year' ? year : p.year,
      sortValue: sort ?? p.sort,
    );
    final colors = Theme.of(context).colorScheme;
    final filterCount = [
      p.genre,
      p.platform,
      p.year,
    ].where((v) => v != null).length;
    final sorts = {
      if (p.query.trim().isNotEmpty) 'relevance': 'Best match',
      'popular': 'Popular',
      'rating': 'Top rated',
      'release': 'Release date',
    };
    return ListView(
      key: const PageStorageKey('explore'),
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Explore',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Find your next favorite.',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'About discovery rankings',
              onPressed: () => showDialog<void>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Discovery rankings'),
                  content: const Text(
                    'Popularity uses RAWG collection activity. Ratings are shown on a 100-point scale. Results reflect your selected filters.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: const Text('Got it'),
                    ),
                  ],
                ),
              ),
              icon: const Icon(Icons.info_outline, size: 20),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: p.setQuery,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search games…',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: colors.surfaceContainerLow,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: p.query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () => p.setQuery(''),
                          icon: const Icon(Icons.close),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filledTonal(
              tooltip: filterCount == 0
                  ? 'Filter games'
                  : 'Filter games ($filterCount active)',
              style: IconButton.styleFrom(
                minimumSize: const Size(52, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                useSafeArea: true,
                builder: (_) => _ExploreFilters(provider: p),
              ),
              icon: Badge(
                isLabelVisible: filterCount > 0,
                label: Text('$filterCount'),
                child: const Icon(Icons.tune),
              ),
            ),
          ],
        ),
        if (p.platform == null && p.preferredPlatforms.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: ActionChip(
              label: const Text('Use my platforms'),
              onPressed: () => apply(
                platform: SearchProvider.myPlatforms,
                changed: 'platform',
              ),
            ),
          ),
        if (filterCount > 0) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (p.genre != null)
                InputChip(
                  label: Text(p.filters.genres[p.genre] ?? 'Genre'),
                  onDeleted: () => apply(changed: 'genre'),
                ),
              if (p.platform != null)
                InputChip(
                  label: Text(
                    p.platform == SearchProvider.myPlatforms
                        ? 'My platforms'
                        : p.filters.platforms[p.platform] ?? 'Platform',
                  ),
                  onDeleted: () => apply(changed: 'platform'),
                ),
              if (p.year != null)
                InputChip(
                  label: Text('${p.year}'),
                  onDeleted: () => apply(changed: 'year'),
                ),
              TextButton(
                onPressed: () => p.apply(sortValue: p.sort),
                child: const Text('Clear all'),
              ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Text(
                p.query.isEmpty ? 'Discover games' : 'Search results',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const GridDensityButton(screen: 'explore'),
            PopupMenuButton<String>(
              tooltip: 'Sort games',
              initialValue: p.sort,
              onSelected: (v) => apply(sort: v),
              itemBuilder: (_) => [
                for (final e in sorts.entries)
                  CheckedPopupMenuItem(
                    value: e.key,
                    checked: p.sort == e.key,
                    child: Text(e.value),
                  ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.sort, size: 18, color: colors.primary),
                    const SizedBox(width: 6),
                    Text(
                      sorts[p.sort]!,
                      style: TextStyle(
                        color: colors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Icon(Icons.expand_more, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (p.stale)
          const Notice(
            'Offline or service unavailable · cached results may be outdated.',
            icon: Icons.cloud_off,
          ),
        if (p.error != null)
          EmptyState(
            'Search could not finish',
            p.error!,
            retry: () => p.search(more: p.games.isNotEmpty),
          ),
        if (visibleGames.isNotEmpty) GameGrid(visibleGames, columns: columns),
        if (p.loading)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: LoadingCards(),
          ),
        if (!p.loading && p.error == null && visibleGames.isEmpty)
          EmptyState(
            'No games found',
            'Try another title or loosen your filters. Playing, played and hidden games are excluded.',
            retry: p.platform == SearchProvider.myPlatforms
                ? () => apply(changed: 'platform')
                : null,
          ),
        if (!p.loading &&
            p.error == null &&
            visibleGames.isEmpty &&
            p.platform == SearchProvider.myPlatforms)
          Center(
            child: TextButton(
              onPressed: () => apply(changed: 'platform'),
              child: const Text('All platforms'),
            ),
          ),
        if (p.hasMore && !p.loading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: OutlinedButton(
                onPressed: () => p.search(more: true),
                child: const Text('Load more games'),
              ),
            ),
          ),
      ],
    );
  }
}

class _ExploreFilters extends StatefulWidget {
  final SearchProvider provider;
  const _ExploreFilters({required this.provider});
  @override
  State<_ExploreFilters> createState() => _ExploreFiltersState();
}

class _ExploreFiltersState extends State<_ExploreFilters> {
  late String? genre = widget.provider.genre,
      platform = widget.provider.platform;
  late int? year = widget.provider.year;
  @override
  Widget build(BuildContext context) {
    Widget field(
      String label,
      String? value,
      Map<String, String> items,
      ValueChanged<String?> change,
    ) => DropdownButtonFormField<String>(
      key: ValueKey('$label:$value'),
      initialValue: items.containsKey(value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: [
        const DropdownMenuItem<String>(value: null, child: Text('All')),
        for (final e in items.entries)
          DropdownMenuItem(
            value: e.key,
            child: Text(e.value, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (v) => setState(() => change(v)),
    );
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .85,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Filter games',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      genre = null;
                      platform = null;
                      year = null;
                    }),
                    child: const Text('Reset'),
                  ),
                  IconButton(
                    tooltip: 'Close filters',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              field(
                'Genre',
                genre,
                widget.provider.filters.genres,
                (v) => genre = v,
              ),
              const SizedBox(height: 16),
              field('Platform', platform, {
                if (widget.provider.preferredPlatforms.isNotEmpty)
                  SearchProvider.myPlatforms: 'My platforms',
                ...widget.provider.filters.platforms,
              }, (v) => platform = v),
              const SizedBox(height: 16),
              field('Release year', year?.toString(), {
                for (var y = DateTime.now().year + 5; y >= 1970; y--)
                  '$y': '$y',
              }, (v) => year = int.tryParse(v ?? '')),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  widget.provider.apply(
                    genreValue: genre,
                    platformValue: platform,
                    yearValue: year,
                    sortValue: widget.provider.sort,
                  );
                  Navigator.pop(context);
                },
                child: const Text('Show games'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
