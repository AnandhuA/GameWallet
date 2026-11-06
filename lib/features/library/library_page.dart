import '../../shared/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models.dart';
import '../../shared/widgets.dart';
import '../settings/settings_provider.dart';
import 'library_provider.dart';
import 'library_editor.dart';
import '../companion/companion_providers.dart';

class LibraryPage extends StatefulWidget {
  final LibraryStatus? initialStatus;
  final bool initialFavorites, initialNotes, initialSaved;
  const LibraryPage({
    super.key,
    this.initialStatus,
    this.initialFavorites = false,
    this.initialNotes = false,
    this.initialSaved = false,
  });
  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  late LibraryStatus? status = widget.initialStatus;
  late bool favorites = widget.initialFavorites;
  String sort = 'updated';
  @override
  Widget build(BuildContext context) {
    final demo = context.select<SettingsProvider, bool>((p) => p.demo);
    final journal = context.watch<JournalProvider>();
    final entries = context
        .watch<LibraryProvider>()
        .entries(demo)
        .where(
          (e) =>
              (status == null || e.status == status) &&
              (!favorites || e.favorite) &&
              (!widget.initialSaved || e.bookmarked) &&
              (!widget.initialNotes || journal.latest(e.game) != null),
        )
        .toList();
    entries.sort(
      (a, b) => sort == 'title'
          ? a.game.title.compareTo(b.game.title)
          : sort == 'rating'
          ? (journal.latest(b.game)?.rating ?? 0).compareTo(
              journal.latest(a.game)?.rating ?? 0,
            )
          : b.updated.compareTo(a.updated),
    );
    return ListView(
      key: const PageStorageKey('library'),
      padding: const EdgeInsets.all(16),
      children: [
        CatalogSourceLabel(demo: demo),
        Text(
          widget.initialNotes ? 'Your journal' : 'Library',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your library, favorites, and notes are saved on this device.',
        ),
        const SizedBox(height: 24),
        Card(
          margin: const EdgeInsets.only(bottom: 20),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHigh,
                  child: Icon(
                    Icons.playlist_add_check,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    '${entries.length} games in this view. Your next adventure starts here.',
                  ),
                ),
              ],
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('All games'),
              selected: status == null,
              onSelected: (_) => setState(() => status = null),
            ),
            for (final s in LibraryStatus.values)
              ChoiceChip(
                label: Text(s.label),
                selected: status == s,
                onSelected: (_) => setState(() => status = s),
              ),
            FilterChip(
              label: const Text('Favorites'),
              selected: favorites,
              onSelected: (v) => setState(() => favorites = v),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 220,
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: sort,
              decoration: const InputDecoration(labelText: 'Sort saved games'),
              items: const [
                DropdownMenuItem(
                  value: 'updated',
                  child: Text('Recently saved'),
                ),
                DropdownMenuItem(value: 'title', child: Text('Title')),
                DropdownMenuItem(
                  value: 'rating',
                  child: Text('Personal rating'),
                ),
              ],
              onChanged: (v) => setState(() => sort = v!),
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (entries.isEmpty)
          const EmptyState(
            'Make room for your next favorite',
            'Save a game from Discover or Explore to start your collection.',
          ),
        for (final e in entries)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  SizedBox(
                    width: 64,
                    height: 82,
                    child: ClipRRect(
                      borderRadius: WalletRadius.control,
                      child: GameArt(e.game),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            alignment: Alignment.centerLeft,
                          ),
                          onPressed: () => openGame(context, e.game),
                          child: Text(
                            e.game.title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Text(
                          '${e.status?.label ?? 'Saved'}${e.favorite ? ' · ♥ Favorite' : ''}${journal.latest(e.game)?.rating == null ? '' : ' · ${journal.latest(e.game)!.rating}/5'}',
                        ),
                        if (!e.game.demo && e.game.source != 'rawg')
                          const Text(
                            'Saved IGDB listing',
                            style: TextStyle(fontSize: 12),
                          ),
                        if ((journal.latest(e.game)?.notes ?? '').isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              journal.latest(e.game)!.notes,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Favorite ${e.game.title}',
                    onPressed: () => guarded(
                      context,
                      () => context.read<LibraryProvider>().favorite(e.game),
                    ),
                    icon: Icon(
                      e.favorite ? Icons.favorite : Icons.favorite_border,
                      color: e.favorite ? accent : null,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Edit ${e.game.title}',
                    onPressed: () => editLibrary(context, e.game),
                    icon: Icon(Icons.edit_outlined),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
