import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models.dart';
import '../companion/companion_providers.dart';
import '../library/library_provider.dart';
import '../settings/settings_provider.dart';

class StatisticsPage extends StatelessWidget {
  const StatisticsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final demo = context.watch<SettingsProvider>().demo;
    final library = context.watch<LibraryProvider>();
    final games = library.entries(demo);
    final journal = context.watch<JournalProvider>().entries(demo);
    final ratings = journal.map((e) => e.rating).whereType<double>().toList();
    final counts = {
      'Saved games': '${games.length}',
      'Want to Play':
          '${games.where((e) => e.status == LibraryStatus.wantToPlay).length}',
      'Playing':
          '${games.where((e) => e.status == LibraryStatus.playing).length}',
      'Completed':
          '${games.where((e) => e.status == LibraryStatus.completed).length}',
      'Journal entries': '${journal.length}',
      'Average review rating': ratings.isEmpty
          ? '—'
          : '${(ratings.reduce((a, b) => a + b) / ratings.length).toStringAsFixed(1)} / 5',
    };
    Map<String, int> breakdown(Iterable<String> values) {
      final result = <String, int>{};
      for (final v in values) {
        result[v] = (result[v] ?? 0) + 1;
      }
      return result;
    }

    final groups = {
      'Genres': breakdown(games.expand((e) => e.game.genres.toSet())),
      'Platforms': breakdown(games.expand((e) => e.game.platforms.toSet())),
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Statistics')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: counts.entries
                .map(
                  (e) => SizedBox(
                    width: 160,
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.insights,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              e.value,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            Text(e.key),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 24),
          for (final group in groups.entries) ...[
            Text(group.key, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (group.value.isEmpty)
              const Text('Save games to see this breakdown.'),
            for (final e
                in (group.value.entries.toList()
                      ..sort((a, b) => b.value.compareTo(a.value)))
                    .take(12))
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(e.key),
                trailing: Text('${e.value}'),
              ),
            const SizedBox(height: 16),
          ],
          const Text(
            'Statistics reflect saved records. No total-playtime or historical-completion estimates are generated.',
          ),
        ],
      ),
    );
  }
}
