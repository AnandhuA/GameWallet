import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models.dart';
import '../../shared/widgets.dart';
import '../home/home_page.dart';
import '../home/home_provider.dart';
import '../library/library_provider.dart';
import '../settings/settings_provider.dart';
import '../companion/companion_providers.dart';

class SmartPickPage extends StatefulWidget {
  const SmartPickPage({super.key});
  @override
  State<SmartPickPage> createState() => _SmartPickPageState();
}

class _SmartPickPageState extends State<SmartPickPage> {
  String? platform, genre;
  String mood = 'Any';
  bool unfinished = true;
  Game? selected;
  @override
  Widget build(BuildContext context) {
    final home = context.watch<HomeProvider>();
    final settings = context.watch<SettingsProvider>();
    final library = context.watch<LibraryProvider>();
    final hidden = context.watch<DiscoveryPreferencesProvider>();
    final source = {
      for (final g in [
        ...home.sections.values
            .expand((g) => g)
            .where((g) => settings.matchesPlatforms(g, home.filters)),
        ...library.entries(settings.demo).map((e) => e.game),
      ])
        g.key: g,
    }.values.where((g) => g.demo == settings.demo);
    final platforms = source.expand((g) => g.platforms).toSet().toList()
      ..sort();
    final genres = source.expand((g) => g.genres).toSet().toList()..sort();
    final candidates = smartCandidates(
      source,
      library,
      hidden,
      platform: platform,
      genre: genre,
      mood: mood,
      unfinished: unfinished,
      preferredGenres: settings.genres,
    );
    final result = candidates.any((g) => g.key == selected?.key)
        ? selected
        : null;
    Widget filter(
      String label,
      String? value,
      List<String> options,
      ValueChanged<String?> change,
    ) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        initialValue: options.contains(value) ? value : null,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [
          const DropdownMenuItem(value: null, child: Text('Any')),
          ...options.map((v) => DropdownMenuItem(value: v, child: Text(v))),
        ],
        onChanged: change,
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Smart Pick')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Notice(
            'Local matching: platform, genre, mood and library status. Preferred genres rank first; no AI or completion-time estimates.',
          ),
          filter(
            'Platform',
            platform,
            platforms,
            (v) => setState(() {
              platform = v;
              selected = null;
            }),
          ),
          filter(
            'Genre',
            genre,
            genres,
            (v) => setState(() {
              genre = v;
              selected = null;
            }),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['Any', 'Relaxed', 'Challenge', 'Story', 'Strategic']
                .map(
                  (v) => ChoiceChip(
                    label: Text(v),
                    selected: mood == v,
                    onSelected: (_) => setState(() {
                      mood = v;
                      selected = null;
                    }),
                  ),
                )
                .toList(),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: unfinished,
            onChanged: (v) => setState(() {
              unfinished = v;
              selected = null;
            }),
            title: const Text('Skip completed and dropped'),
          ),
          Text('${candidates.length} eligible games'),
          const SizedBox(height: 16),
          if (result != null) ...[
            FeatureGameCard(result),
            const SizedBox(height: 16),
          ],
          FilledButton.icon(
            onPressed: candidates.isEmpty
                ? null
                : () => setState(() {
                    final bestScore = candidates.first.genres
                        .where(settings.genres.contains)
                        .length;
                    final preferred = candidates
                        .where(
                          (g) =>
                              g.genres.where(settings.genres.contains).length ==
                              bestScore,
                        )
                        .toList();
                    selected = preferred[Random().nextInt(preferred.length)];
                  }),
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Find a game'),
          ),
          if (candidates.isEmpty)
            const EmptyState(
              'No matching games',
              'Loosen your filters or load more discovery results.',
            ),
        ],
      ),
    );
  }
}
