import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/game_repository.dart';
import '../../core/models.dart';
import '../../shared/widgets.dart';
import '../explore/search_provider.dart';
import '../settings/settings_provider.dart';

Future<Game?> selectGame(BuildContext context) => Navigator.of(
  context,
).push<Game>(MaterialPageRoute(builder: (_) => const GameSelector()));

class GameSelector extends StatelessWidget {
  const GameSelector({super.key});
  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (context) =>
        SearchProvider(context.read<GameRepository>())
          ..configure(context.read<SettingsProvider>().demo, const []),
    child: const _SelectorBody(),
  );
}

class _SelectorBody extends StatelessWidget {
  const _SelectorBody();
  @override
  Widget build(BuildContext context) {
    final search = context.watch<SearchProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Choose a game')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search RAWG or demo games',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: search.setQuery,
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                CatalogSourceLabel(demo: search.demo),
                if (search.loading) const LinearProgressIndicator(),
                if (search.error != null)
                  EmptyState(
                    'Could not search',
                    search.error!,
                    retry: search.search,
                  ),
                if (!search.loading &&
                    search.error == null &&
                    search.games.isEmpty)
                  const EmptyState('No games found', 'Try another title.'),
                for (final game in search.games)
                  ListTile(
                    leading: SizedBox(
                      width: 42,
                      height: 56,
                      child: GameArt(game),
                    ),
                    title: Text(game.title),
                    subtitle: Text(game.platforms.join(' · ')),
                    onTap: () => Navigator.pop(context, game),
                  ),
                if (search.hasMore && !search.loading)
                  TextButton(
                    onPressed: () => search.search(more: true),
                    child: const Text('Load more'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
