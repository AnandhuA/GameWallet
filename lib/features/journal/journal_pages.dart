import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/companion_models.dart';
import '../../core/models.dart';
import '../../shared/widgets.dart';
import '../companion/companion_providers.dart';
import '../companion/game_selector.dart';
import '../library/library_provider.dart';
import '../settings/settings_provider.dart';
import '../library/playthrough_dates.dart';

Future<void> editPlaythrough(
  BuildContext context,
  Game game, {
  PlaythroughEntry? entry,
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => JournalEditor(game: game, initial: entry),
  ),
);
final Set<String> _completionFlows = {};
Future<bool> completeGame(
  BuildContext context,
  Game game, {
  bool? favorite,
}) async {
  if (!_completionFlows.add(game.key)) return false;
  try {
    final library = context.read<LibraryProvider>();
    final draft = library.completionDraft(game);
    final choice = await showWalletSheet<CompletionChoice>(
      context: context,
      builder: (_) => PlaythroughDatesDialog(initial: draft, completion: true),
    );
    if (choice == null || !context.mounted) return false;
    if (choice.review) {
      return await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => JournalEditor(
                game: game,
                complete: true,
                favorite: favorite,
                completionRun: choice.run,
              ),
            ),
          ) ??
          false;
    }
    await library.completePlaythrough(game, choice.run, favorite: favorite);
    return true;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not save completion. Your previous status is preserved.',
          ),
        ),
      );
    }
    return false;
  } finally {
    _completionFlows.remove(game.key);
  }
}

class JournalPage extends StatefulWidget {
  final Game? game;
  const JournalPage({super.key, this.game});
  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  String query = '';
  bool ratedOnly = false;
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<JournalProvider>();
    final demo = context.watch<SettingsProvider>().demo;
    final entries = provider
        .entries(widget.game?.demo ?? demo, gameKey: widget.game?.key)
        .where(
          (e) =>
              (!ratedOnly || e.rating != null) &&
              '${e.game.title} ${e.review} ${e.notes} ${e.tags.join(' ')}'
                  .toLowerCase()
                  .contains(query.toLowerCase()),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.game == null
              ? 'Playthrough journal'
              : '${widget.game!.title} · Journal',
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final game = widget.game ?? await selectGame(context);
          if (game != null && context.mounted) {
            await editPlaythrough(context, game);
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('New entry'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          CatalogSourceLabel(demo: widget.game?.demo ?? demo),
          TextField(
            decoration: const InputDecoration(
              hintText: 'Search titles, notes or tags',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => query = v),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilterChip(
              label: const Text('Rated entries'),
              selected: ratedOnly,
              onSelected: (v) => setState(() => ratedOnly = v),
            ),
          ),
          if (entries.isEmpty)
            const EmptyState(
              'Your story starts here',
              'Add a playthrough to remember what you played and how it felt.',
            ),
          for (final entry in entries)
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(14),
                leading: SizedBox(
                  width: 48,
                  height: 70,
                  child: GameArt(entry.game),
                ),
                title: Text(entry.game.title),
                subtitle: Text(
                  '${entry.imported ? 'Imported · date unknown' : entry.playedOn?.toString().split(' ').first ?? 'Date not set'}\n${entry.rating == null ? 'Unrated' : '★ ${entry.rating}/5'} · ${entry.recommendation}\n${entry.review.isNotEmpty ? entry.review : entry.notes}',
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        JournalDetail(id: entry.id, demo: entry.game.demo),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class JournalDetail extends StatelessWidget {
  final String id;
  final bool demo;
  const JournalDetail({super.key, required this.id, required this.demo});
  @override
  Widget build(BuildContext context) {
    final p = context.watch<JournalProvider>();
    final entry = p.entries(demo).where((e) => e.id == id).firstOrNull;
    final linked = entry == null
        ? null
        : context
              .watch<LibraryProvider>()
              .entry(entry.game)
              ?.playthroughs
              .where((r) => r.id == entry.playthroughId)
              .firstOrNull;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Playthrough'),
        actions: [
          if (entry != null)
            IconButton(
              tooltip: 'Edit entry',
              onPressed: () =>
                  editPlaythrough(context, entry.game, entry: entry),
              icon: const Icon(Icons.edit_outlined),
            ),
          if (entry != null)
            IconButton(
              tooltip: 'Delete entry',
              onPressed: () async {
                final yes = await showDialog<bool>(
                  context: context,
                  builder: (_) => const ConfirmDialog(
                    title: 'Delete this journal entry?',
                    message: 'This entry will be removed from your journal.',
                  ),
                );
                if (yes == true && context.mounted) {
                  await guarded(context, () => p.delete(id));
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                }
              },
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: entry == null
          ? const EmptyState('Entry unavailable', 'It may have been removed.')
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                CatalogSourceLabel(demo: entry.game.demo),
                Text(
                  entry.game.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(
                  linked != null
                      ? '${linked.startDate == null ? 'Start not recorded' : dateKey(linked.startDate!)} → ${linked.endDate == null ? 'End not recorded' : dateKey(linked.endDate!)}'
                      : entry.imported
                      ? 'Imported from your previous library · play date unknown'
                      : entry.playedOn?.toString().split(' ').first ??
                            'Date not set',
                ),
                Text(
                  entry.rating == null ? 'Unrated' : '★ ${entry.rating} / 5',
                ),
                for (final field in {
                  'Review': entry.review,
                  'Personal notes': entry.notes,
                  'Favorite moment': entry.moment,
                  'Quote': entry.quote,
                  'Reactions': entry.reactions.join(' · '),
                  'Tags': entry.tags.join(', '),
                  'Recommend': entry.recommendation,
                }.entries)
                  if (field.value.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            field.key,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          SelectableText(field.value),
                        ],
                      ),
                    ),
              ],
            ),
    );
  }
}

class JournalEditor extends StatefulWidget {
  final Game game;
  final PlaythroughEntry? initial;
  final bool complete;
  final bool? favorite;
  final GamePlaythrough? completionRun;
  const JournalEditor({
    super.key,
    required this.game,
    this.initial,
    this.complete = false,
    this.favorite,
    this.completionRun,
  });
  @override
  State<JournalEditor> createState() => _JournalEditorState();
}

class _JournalEditorState extends State<JournalEditor> {
  late final review = TextEditingController(text: widget.initial?.review ?? '');
  late final notes = TextEditingController(text: widget.initial?.notes ?? '');
  late final moment = TextEditingController(text: widget.initial?.moment ?? '');
  late final quote = TextEditingController(text: widget.initial?.quote ?? '');
  late final tags = TextEditingController(
    text: widget.initial?.tags.join(', ') ?? '',
  );
  late final custom = TextEditingController(
    text: widget.initial?.reactions.join(', ') ?? '',
  );
  late double? rating = widget.initial?.rating;
  late String recommend = widget.initial?.recommendation ?? 'maybe';
  late DateTime? played =
      widget.complete || widget.initial?.playthroughId != null
      ? null
      : widget.initial?.playedOn ??
            (widget.initial?.imported == true ? null : DateTime.now());
  late final run =
      widget.completionRun ??
      (widget.complete
          ? context.read<LibraryProvider>().completionDraft(widget.game)
          : null);
  late final reviewId =
      widget.initial?.id ?? context.read<JournalProvider>().newId();
  bool saving = false;
  String? error;
  @override
  void dispose() {
    for (final c in [review, notes, moment, quote, tags, custom]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    setState(() {
      saving = true;
      error = null;
    });
    final journal = context.read<JournalProvider>();
    final library = context.read<LibraryProvider>();
    final old = library.entry(widget.game);
    final entry = PlaythroughEntry(
      id: reviewId,
      playthroughId: run?.id ?? widget.initial?.playthroughId,
      game: widget.game,
      review: review.text,
      notes: notes.text,
      moment: moment.text,
      quote: quote.text,
      reactions: custom.text
          .split(',')
          .map((v) => v.trim())
          .where((v) => v.isNotEmpty)
          .toSet()
          .toList(),
      tags: tags.text
          .split(',')
          .map((v) => v.trim())
          .where((v) => v.isNotEmpty)
          .toSet()
          .toList(),
      rating: rating,
      playedOn: run != null || widget.initial?.playthroughId != null
          ? null
          : played,
      recommendation: recommend,
      createdAt: widget.initial?.createdAt,
      imported: widget.initial?.imported ?? false,
    );
    try {
      if (widget.complete) {
        await library.completePlaythrough(
          widget.game,
          run!,
          favorite: widget.favorite,
        );
      }
      try {
        await journal.save(entry);
      } catch (_) {
        if (widget.complete) {
          if (old == null) {
            await library.remove(widget.game);
          } else {
            await library.save(old);
          }
        }
        rethrow;
      }
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          error = 'Could not save this playthrough. Please try again.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save this playthrough. Please try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.complete ? 'Complete & review' : 'Playthrough review'),
      actions: [
        TextButton(
          onPressed: saving ? null : save,
          child: Text(saving ? 'Saving…' : 'Save'),
        ),
      ],
    ),
    body: WalletViewport(
      form: true,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CatalogSourceLabel(demo: widget.game.demo),
          Text(
            widget.game.title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<double>(
            initialValue: rating,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Your rating'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Not rated')),
              ...List.generate(
                10,
                (i) => DropdownMenuItem(
                  value: (i + 1) / 2,
                  child: Text('★ ${(i + 1) / 2} / 5'),
                ),
              ),
            ],
            onChanged: saving ? null : (v) => setState(() => rating = v),
          ),
          if (run != null || widget.initial?.playthroughId != null)
            Text(
              'Dates are linked to this playthrough. Edit them in Playthrough history.',
            )
          else
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Play date'),
              subtitle: Text(
                played?.toString().split(' ').first ?? 'Unknown / imported',
              ),
              trailing: const Icon(Icons.calendar_month),
              onTap: saving
                  ? null
                  : () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: played ?? DateTime.now(),
                        firstDate: DateTime(1970),
                        lastDate: DateTime.now(),
                      );
                      if (d != null) {
                        setState(() => played = d);
                      }
                    },
            ),
          for (final f in [
            (review, 'Review'),
            (notes, 'Personal notes'),
            (moment, 'Favorite moment'),
            (quote, 'Favorite quote'),
            (custom, 'Reactions (comma separated)'),
            (tags, 'Tags (comma separated)'),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextField(
                controller: f.$1,
                maxLines: f.$1 == review || f.$1 == notes ? 3 : 1,
                maxLength: f.$1 == review || f.$1 == notes ? 5000 : 500,
                enabled: !saving,
                decoration: InputDecoration(labelText: f.$2),
              ),
            ),
          Wrap(
            spacing: 6,
            children: ['Loved it', 'Challenging', 'Relaxing', 'Emotional']
                .map(
                  (v) => ActionChip(
                    label: Text(v),
                    onPressed: saving
                        ? null
                        : () {
                            final values =
                                custom.text
                                    .split(',')
                                    .map((v) => v.trim())
                                    .where((v) => v.isNotEmpty)
                                    .toSet()
                                  ..add(v);
                            setState(() => custom.text = values.join(', '));
                          },
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: recommend,
            decoration: const InputDecoration(
              labelText: 'Would you recommend it?',
            ),
            items: const [
              DropdownMenuItem(value: 'yes', child: Text('Yes')),
              DropdownMenuItem(value: 'maybe', child: Text('Maybe')),
              DropdownMenuItem(value: 'no', child: Text('No')),
            ],
            onChanged: saving ? null : (v) => setState(() => recommend = v!),
          ),
          if (error != null) Notice(error!),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: saving ? null : save,
            child: const Text('Save playthrough'),
          ),
        ],
      ),
    ),
  );
}
