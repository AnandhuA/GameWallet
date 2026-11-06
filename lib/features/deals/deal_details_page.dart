import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../shared/widgets.dart';
import 'deal_record.dart';
import 'deal_cover.dart';
import 'deals_catalog_provider.dart';

void openDeal(BuildContext context, DealRecord record) {
  final catalog = context.read<DealsCatalogProvider?>();
  Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => ChangeNotifierProvider(
        create: (_) => DealDetailsProvider(catalog, record)..load(),
        child: DealDetailsPage(record),
      ),
    ),
  );
}

class DealDetailsPage extends StatefulWidget {
  final DealRecord record;
  const DealDetailsPage(this.record, {super.key});
  @override
  State<DealDetailsPage> createState() => _DealDetailsPageState();
}

class _DealDetailsPageState extends State<DealDetailsPage> {
  bool expanded = false;
  @override
  Widget build(BuildContext context) {
    final p = context.watch<DealDetailsProvider>();
    final record = widget.record;
    final game = p.game;
    return Scaffold(
      appBar: AppBar(title: const Text('Deal details')),
      body: WalletViewport(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 200,
                child: DealCover(record, game: game, wide: true),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 88,
                    height: 118,
                    child: DealCover(record, game: game),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(record.source),
                      Text(switch (record.platform) {
                        'pc' => 'PC',
                        'android' => 'Android',
                        'ios' => 'iOS',
                        _ => 'Platform unspecified',
                      }),
                      if (record.rating != null)
                        Text(
                          'Epic rating ${record.rating!.toStringAsFixed(1)}/5',
                        ),
                      if (record.criticScore != null)
                        Text('Metacritic ${record.criticScore}/100'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Giveaway recorded ${record.dateLabel}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'This is a historical giveaway record. It may have expired. Check Epic for current availability, price and regional eligibility.',
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => openExternal(context, record.storeUrl),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Check on Epic'),
            ),
            if (p.loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: LinearProgressIndicator(),
              ),
            if (p.stale)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('Cached game information · may be outdated'),
              ),
            if (p.error != null) ...[
              const SizedBox(height: 16),
              Text(p.error!),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => p.load(refresh: true),
                  child: const Text('Retry game information'),
                ),
              ),
            ],
            if (game == null && !p.loading && p.error == null) ...[
              const SectionHeader('Choose the matching game'),
              const Text(
                'Confirm the title and edition before using RAWG artwork or adding it to your library.',
              ),
              if (p.candidates.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No matching catalog listing found. The Epic record remains available.',
                  ),
                ),
              for (final candidate in p.candidates)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(candidate.title),
                  subtitle: Text(
                    [
                      if (candidate.release != null)
                        '${candidate.release!.year}',
                      ...candidate.platforms,
                    ].join(' · '),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => p.select(candidate),
                ),
            ],
            if (game != null) ...[
              const SectionHeader('Game information'),
              TextButton(
                onPressed: () => openExternal(
                  context,
                  game.source == 'freetogame'
                      ? 'https://www.freetogame.com/'
                      : 'https://rawg.io/',
                ),
                child: Text(
                  game.source == 'freetogame'
                      ? 'Data: FreeToGame'
                      : 'Data: RAWG',
                ),
              ),
              Text(
                '${game.title} · ${game.source == 'freetogame' ? 'FreeToGame' : 'RAWG'}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (game.release != null)
                Text(
                  'Released ${game.release!.toIso8601String().substring(0, 10)}',
                ),
              if (game.genres.isNotEmpty) Text(game.genres.join(' · ')),
              if (game.summary.isNotEmpty) ...[
                const SectionHeader('Description'),
                Text(
                  game.summary,
                  maxLines: expanded ? null : 3,
                  overflow: expanded
                      ? TextOverflow.visible
                      : TextOverflow.ellipsis,
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => setState(() => expanded = !expanded),
                    child: Text(expanded ? 'Read less' : 'Read more'),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => openGame(context, game),
                icon: const Icon(Icons.sports_esports_outlined),
                label: const Text('Open full game details'),
              ),
              const Text(
                'Full details include your library actions, journal, screenshots and available store prices.',
              ),
            ],
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => openExternal(
                context,
                'https://github.com/josephmate/EpicFreeGamesList',
              ),
              child: const Text('Giveaway source: EpicFreeGamesList'),
            ),
          ],
        ),
      ),
    );
  }
}
