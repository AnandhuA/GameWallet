import '../../shared/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/companion_models.dart';
import '../../core/companion_repository.dart';
import '../../core/game_repository.dart';
import '../../core/models.dart';
import '../../shared/widgets.dart';
import '../companion/companion_providers.dart';
import '../companion/game_actions.dart';
import '../companion/game_selector.dart';
import '../library/library_provider.dart';
import '../settings/settings_provider.dart';

class LineUpPage extends StatefulWidget {
  const LineUpPage({super.key});
  @override
  State<LineUpPage> createState() => _LineUpPageState();
}

class _LineUpPageState extends State<LineUpPage> {
  String filter = 'all';
  @override
  Widget build(BuildContext context) {
    final p = context.watch<LineUpProvider>();
    final demo = context.watch<SettingsProvider>().demo;
    final library = context.watch<LibraryProvider>();
    final all = p.entries(demo);
    final lists = all
        .where(
          (l) =>
              filter == 'all' ||
              filter == 'favorites' && l.favorite ||
              filter == 'user' && !l.starter,
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('LineUp'),
        actions: [
          IconButton(
            tooltip: 'New LineUp',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const LineUpEditor()),
            ),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const LineUpEditor()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('New'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                    child: const Icon(Icons.playlist_add_check),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'Build a play order. Your progress follows your completed games.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'all',
                  label: Text('All ${all.length}'),
                  icon: const Icon(Icons.grid_view),
                ),
                ButtonSegment(
                  value: 'favorites',
                  label: Text('Fav ${all.where((l) => l.favorite).length}'),
                  icon: const Icon(Icons.favorite_border),
                ),
                ButtonSegment(
                  value: 'user',
                  label: Text('User ${all.where((l) => !l.starter).length}'),
                  icon: const Icon(Icons.person_outline),
                ),
              ],
              selected: {filter},
              onSelectionChanged: (v) => setState(() => filter = v.single),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: p.loading
                ? null
                : () => p.loadStarters(context.read<GameRepository>(), demo),
            icon: const Icon(Icons.cloud_download_outlined),
            label: Text(
              p.loading
                  ? 'Verifying starter games…'
                  : 'Load / retry curated starters',
            ),
          ),
          if (p.loading) const LinearProgressIndicator(),
          if (p.error != null) Notice(p.error!),
          if (lists.isEmpty && !p.loading)
            const EmptyState(
              'Your next adventure, in order',
              'Create your own LineUp or load curated starter lists.',
            ),
          for (final list in lists)
            Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: list.games.isEmpty
                        ? CircleAvatar(
                            radius: 26,
                            backgroundColor: Color(list.color),
                            child: const Icon(
                              Icons.sports_esports,
                              color: Colors.white,
                            ),
                          )
                        : SizedBox(
                            width: 44,
                            child: GameCover(
                              list.games
                                      .where(
                                        (game) => game.key == list.coverKey,
                                      )
                                      .firstOrNull ??
                                  list.games.first,
                            ),
                          ),
                    title: Text(
                      list.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${list.starter ? 'Game Wallet curated' : 'Custom LineUp'} · ${p.completed(list, library)}/${list.games.length} completed',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Favorite ${list.title}',
                          onPressed: () => guarded(
                            context,
                            () => p.save(list.copy(favorite: !list.favorite)),
                          ),
                          icon: Icon(
                            list.favorite
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: list.favorite
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => LineUpDetail(id: list.id),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: ClipRRect(
                      borderRadius: WalletRadius.control,
                      child: LinearProgressIndicator(
                        minHeight: 5,
                        value: list.games.isEmpty
                            ? 0
                            : p.completed(list, library) / list.games.length,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class LineUpDetail extends StatelessWidget {
  final String id;
  const LineUpDetail({super.key, required this.id});
  @override
  Widget build(BuildContext context) {
    final p = context.watch<LineUpProvider>();
    final list = p.byId(id);
    final library = context.watch<LibraryProvider>();
    return Scaffold(
      appBar: AppBar(
        title: Text(list?.title ?? 'LineUp'),
        actions: [
          if (list != null)
            IconButton(
              tooltip: list.starter ? 'Clone to edit' : 'Edit LineUp',
              icon: Icon(list.starter ? Icons.copy : Icons.edit_outlined),
              onPressed: () async {
                final editable = list.starter ? await p.clone(list) : list;
                if (context.mounted) {
                  await Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => LineUpEditor(initial: editable),
                    ),
                  );
                }
              },
            ),
        ],
      ),
      body: list == null
          ? const EmptyState('LineUp removed', 'Go back to your lists.')
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                CatalogSourceLabel(demo: list.demo),
                if (list.games.isNotEmpty)
                  ClipRRect(
                    borderRadius: WalletRadius.row,
                    child: SizedBox(
                      height: 180,
                      child: GameArt(
                        list.games
                                .where((g) => g.key == list.coverKey)
                                .firstOrNull ??
                            list.games.first,
                        wide: true,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Text(list.description),
                const SizedBox(height: 16),
                Text(
                  '${p.completed(list, library)} of ${list.games.length} completed',
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: list.games.isEmpty
                      ? 0
                      : p.completed(list, library) / list.games.length,
                ),
                if (list.games.isEmpty)
                  const EmptyState(
                    'No games yet',
                    'Edit this LineUp to add games.',
                  ),
                for (final pair in list.games.asMap().entries)
                  Card(
                    child: ListTile(
                      leading: SizedBox(
                        width: 44,
                        height: 65,
                        child: GameArt(pair.value),
                      ),
                      title: Text('${pair.key + 1}. ${pair.value.title}'),
                      subtitle: Text(
                        library.entry(pair.value)?.status?.label ??
                            'Not started',
                      ),
                      trailing: GameActionsMenu(pair.value),
                      onTap: () => openGame(context, pair.value),
                    ),
                  ),
              ],
            ),
    );
  }
}

class LineUpEditor extends StatefulWidget {
  final GameLineUp? initial;
  const LineUpEditor({super.key, this.initial});
  @override
  State<LineUpEditor> createState() => _LineUpEditorState();
}

class _LineUpEditorState extends State<LineUpEditor> {
  late final title = TextEditingController(text: widget.initial?.title ?? '');
  late final description = TextEditingController(
    text: widget.initial?.description ?? '',
  );
  late List<Game> games = [...?widget.initial?.games];
  late int color = widget.initial?.color ?? 0xFF06B6D4;
  late String? coverKey = widget.initial?.coverKey;
  bool saving = false;
  String? error;
  @override
  void dispose() {
    title.dispose();
    description.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (title.text.trim().isEmpty) {
      setState(() => error = 'Add a LineUp name.');
      return;
    }
    setState(() => saving = true);
    try {
      final p = context.read<LineUpProvider>();
      await p.save(
        GameLineUp(
          id: widget.initial?.id ?? context.read<CompanionRepository>().newId(),
          title: title.text,
          description: description.text,
          games: games,
          color: color,
          coverKey: coverKey,
          favorite: widget.initial?.favorite ?? false,
          demo: widget.initial?.demo ?? context.read<SettingsProvider>().demo,
        ),
      );
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          error = 'Could not save this LineUp.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.initial == null ? 'New LineUp' : 'Edit LineUp'),
      actions: [
        TextButton(onPressed: saving ? null : save, child: const Text('Save')),
      ],
    ),
    body: WalletViewport(
      form: true,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: title,
            maxLength: 80,
            decoration: const InputDecoration(labelText: 'LineUp name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: description,
            maxLength: 1000,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children:
                [0xFF06B6D4, 0xFF8B5CF6, 0xFF1DB954, 0xFFE53935, 0xFFFFB020]
                    .map(
                      (c) => IconButton.filled(
                        tooltip: 'Choose color',
                        style: IconButton.styleFrom(backgroundColor: Color(c)),
                        onPressed: () => setState(() => color = c),
                        icon: Icon(
                          c == color ? Icons.check : Icons.circle_outlined,
                          color: Colors.white,
                        ),
                      ),
                    )
                    .toList(),
          ),
          const SizedBox(height: 16),
          if (games.isNotEmpty)
            DropdownButtonFormField<String>(
              key: ValueKey('${games.map((g) => g.key).join(',')}:$coverKey'),
              initialValue: games.any((g) => g.key == coverKey)
                  ? coverKey
                  : games.first.key,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Cover artwork'),
              items: games
                  .map(
                    (g) => DropdownMenuItem(
                      value: g.key,
                      child: Text(g.title, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => coverKey = v),
            ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: saving
                ? null
                : () async {
                    final game = await selectGame(context);
                    if (game != null &&
                        mounted &&
                        !games.any((g) => g.key == game.key)) {
                      setState(() => games.add(game));
                    }
                  },
            icon: const Icon(Icons.add),
            label: const Text('Add game'),
          ),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: games.length,
            onReorder: (from, to) => setState(() {
              if (to > from) {
                to--;
              }
              games.insert(to, games.removeAt(from));
            }),
            itemBuilder: (context, i) => ListTile(
              key: ValueKey(games[i].key),
              title: Text(games[i].title),
              leading: ReorderableDragStartListener(
                index: i,
                child: const Icon(Icons.drag_handle),
              ),
              trailing: IconButton(
                tooltip: 'Remove ${games[i].title}',
                onPressed: () => setState(() => games.removeAt(i)),
                icon: const Icon(Icons.close),
              ),
            ),
          ),
          if (error != null) Notice(error!),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: saving ? null : save,
            child: const Text('Save LineUp'),
          ),
          if (widget.initial != null && !widget.initial!.starter)
            TextButton(
              onPressed: saving
                  ? null
                  : () async {
                      final yes = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Delete this LineUp?'),
                          content: const Text(
                            'Saved games and journal entries will remain.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (yes == true && context.mounted) {
                        await guarded(
                          context,
                          () => context.read<LineUpProvider>().delete(
                            widget.initial!.id,
                          ),
                        );
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      }
                    },
              child: const Text('Delete LineUp'),
            ),
        ],
      ),
    ),
  );
}
