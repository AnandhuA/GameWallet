import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../shared/widgets.dart';
import 'deal_record.dart';
import 'deal_cover.dart';
import 'deal_details_page.dart';
import 'deals_provider.dart';

class DealsPage extends StatelessWidget {
  const DealsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final p = context.watch<DealsProvider>();
    final records = p.visible;
    final latest = records.isEmpty ? null : records.first.dateLabel;
    final latestRecords = records.where((e) => e.dateLabel == latest).toList();
    final history = records.where((e) => e.dateLabel != latest).toList();
    return RefreshIndicator(
      onRefresh: () => p.load(refresh: true),
      child: CustomScrollView(
        key: const PageStorageKey('deals'),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList.list(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Deals',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh deals',
                      onPressed: p.loading ? null : () => p.load(refresh: true),
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                const Text('Discover giveaways. Find your next game.'),
                const SizedBox(height: 16),
                TextField(
                  onChanged: (value) => p.filter(text: value),
                  decoration: const InputDecoration(
                    hintText: 'Search giveaway history',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final entry in const {
                      'all': 'All',
                      'pc': 'PC',
                      'android': 'Android',
                      'ios': 'iOS',
                      'unknown': 'Unspecified',
                    }.entries)
                      ChoiceChip(
                        label: Text(entry.value),
                        selected: p.platform == entry.key,
                        onSelected: (_) => p.filter(platformValue: entry.key),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Epic giveaway records. Offers may have expired; check availability and regional eligibility on Epic.',
                ),
                if (p.snapshot != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${p.snapshot!.stale ? 'Offline / outdated records · ' : ''}Last fetched ${_time(p.snapshot!.fetchedAt)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                if (p.loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: LinearProgressIndicator(),
                  ),
                if (p.error != null) ...[
                  const SizedBox(height: 12),
                  Text(p.error!),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => p.load(refresh: true),
                      child: const Text('Retry'),
                    ),
                  ),
                ],
                if (!p.loading && p.error == null && records.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      children: [
                        const Icon(Icons.local_offer_outlined, size: 32),
                        const SizedBox(height: 8),
                        Text(
                          p.query.isNotEmpty || p.platform != 'all'
                              ? 'No matching giveaways'
                              : 'No giveaway records yet',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Text('Try another search or refresh the feed.'),
                        TextButton(
                          onPressed: () => p.load(refresh: true),
                          child: const Text('Refresh'),
                        ),
                      ],
                    ),
                  ),
                if (records.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 20, bottom: 8),
                    child: SectionHeader('Latest recorded giveaways'),
                  ),
              ],
            ),
          ),
          _rows(latestRecords),
          if (history.isNotEmpty)
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
              sliver: SliverToBoxAdapter(
                child: SectionHeader('Giveaway history'),
              ),
            ),
          _rows(history),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            sliver: SliverToBoxAdapter(
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => openExternal(
                    context,
                    'https://github.com/josephmate/EpicFreeGamesList',
                  ),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Source: EpicFreeGamesList · josephmate'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rows(List<DealRecord> records) => SliverPadding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    sliver: SliverList.builder(
      itemCount: records.length,
      itemBuilder: (context, index) => _DealRow(records[index]),
    ),
  );
  static String _time(DateTime value) => value
      .toLocal()
      .toIso8601String()
      .substring(0, 16)
      .replaceFirst('T', ' · ');
}

class _DealRow extends StatelessWidget {
  final DealRecord record;
  const _DealRow(this.record);
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: InkWell(
      onTap: () => openDeal(context, record),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 64,
                      height: 86,
                      child: DealCover(record),
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${record.source} · ${switch (record.platform) {
                          'pc' => 'PC',
                          'ios' => 'iOS',
                          'android' => 'Android',
                          _ => 'Platform unspecified',
                        }}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Giveaway recorded ${record.dateLabel}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (record.rating != null || record.criticScore != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  [
                    if (record.rating != null)
                      'Epic ${record.rating!.toStringAsFixed(1)}/5',
                    if (record.criticScore != null)
                      'Metacritic ${record.criticScore}/100',
                  ].join(' · '),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => openExternal(context, record.storeUrl),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Check on Epic'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
