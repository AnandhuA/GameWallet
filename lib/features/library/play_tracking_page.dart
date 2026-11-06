import 'playthrough_dates.dart';
import '../../shared/app_theme.dart';
import 'package:flutter/services.dart';
import 'personal_overview.dart';
import '../../shared/grid_density_button.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models.dart';
import '../../shared/widgets.dart';
import '../settings/settings_provider.dart';
import '../companion/game_actions.dart';
import '../companion/companion_providers.dart';
import '../journal/journal_pages.dart';
import 'library_provider.dart';

class PlayTrackingPage extends StatefulWidget {
  final VoidCallback onExplore;
  const PlayTrackingPage({super.key, required this.onExplore});
  @override
  State<PlayTrackingPage> createState() => _PlayTrackingPageState();
}

class _PlayTrackingPageState extends State<PlayTrackingPage> {
  int view = 0;
  String query = '', sort = 'updated';
  final search = TextEditingController();
  final searchFocus = FocusNode();
  bool searchOpen = false;
  void closeSearch() {
    searchFocus.unfocus();
    search.clear();
    setState(() {
      searchOpen = false;
      query = '';
    });
  }

  void openSearch() {
    setState(() => searchOpen = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && searchOpen) searchFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    searchFocus.dispose();
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final demo = context.select<SettingsProvider, bool>((p) => p.demo);
    final layout = context.select<SettingsProvider, String>(
      (p) => p.libraryLayout,
    );
    final columns = context.select<SettingsProvider, int>(
      (p) => p.gridColumns('library'),
    );
    final library = context.watch<LibraryProvider>();
    final journal = context.watch<JournalProvider>();
    final playing = library.playingEntries(demo),
        history = library.playedEntries(demo),
        saved = library.savedEntries(demo);
    final entries = ([playing, history, saved][view])
        .where((e) => e.game.title.toLowerCase().contains(query.toLowerCase()))
        .toList();
    entries.sort(
      (a, b) => sort == 'title'
          ? a.game.title.compareTo(b.game.title)
          : b.updated.compareTo(a.updated),
    );
    final theme = Theme.of(context), colors = theme.colorScheme;
    Widget entryCard(LibraryEntry entry, {bool grid = false}) =>
        _TrackingGameCard(
          entry: entry,
          grid: grid,
          playedView: view == 1,
          compact: layout == 'compact',
          status: entry.status == LibraryStatus.playing
              ? library.hasPlayed(entry.game)
                    ? 'Replaying'
                    : 'Now playing'
              : library.hasPlayed(entry.game)
              ? 'Played'
              : 'Want to play',
          journalCount: journal.entries(demo, gameKey: entry.game.key).length,
          actionLabel: view == 0
              ? 'Complete game'
              : library.hasPlayed(entry.game)
              ? 'Play again'
              : 'Start playing',
          actionIcon: view == 0
              ? Icons.check_circle_outline
              : library.hasPlayed(entry.game)
              ? Icons.replay
              : Icons.play_arrow_rounded,
          onAction: view != 0 && entry.status == LibraryStatus.playing
              ? null
              : () {
                  if (view == 0) {
                    completeGame(context, entry.game);
                    return;
                  }
                  guarded(context, () async {
                    await library.setStatus(entry.game, LibraryStatus.playing);
                    if (mounted) {
                      search.clear();
                      setState(() {
                        view = 0;
                        query = '';
                      });
                    }
                  });
                },
          onJournal: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => JournalPage(game: entry.game),
            ),
          ),
        );
    Widget tab(int value, String label, int count) => Expanded(
      child: Semantics(
        selected: view == value,
        label: '$label, $count games',
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: view == value
                ? colors.surfaceContainerHigh
                : Colors.transparent,
            borderRadius: WalletRadius.control,
          ),
          child: InkWell(
            key: ValueKey('tracking-tab-$value'),
            onTap: () => setState(() => view = value),
            borderRadius: WalletRadius.control,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: view == value
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: view == value
                              ? colors.onSurface
                              : colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Container(
                      constraints: const BoxConstraints(
                        minWidth: 22,
                        minHeight: 22,
                      ),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: view == value
                            ? colors.surface.withValues(alpha: .45)
                            : colors.surfaceContainerHighest.withValues(
                                alpha: .5,
                              ),
                        borderRadius: WalletRadius.control,
                      ),
                      child: Text(
                        '$count',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: view == value
                              ? colors.onSurface
                              : colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return ListView(
      key: const PageStorageKey('play-tracking'),
      padding: const EdgeInsets.all(16),
      children: [
        LayoutBuilder(
          builder: (context, box) => AnimatedSwitcher(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 260),
            reverseDuration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 200),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SizeTransition(
                sizeFactor: animation,
                axis: Axis.horizontal,
                axisAlignment: 1,
                child: child,
              ),
            ),
            child: SizedBox(
              width: box.maxWidth,
              key: ValueKey(searchOpen),
              child: searchOpen
                  ? CallbackShortcuts(
                      bindings: {
                        const SingleActivator(LogicalKeyboardKey.escape):
                            closeSearch,
                      },
                      child: TextField(
                        key: const ValueKey('my-games-search-field'),
                        controller: search,
                        focusNode: searchFocus,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => searchFocus.unfocus(),
                        onChanged: (value) => setState(() => query = value),
                        decoration: InputDecoration(
                          hintText: 'Search your games',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: IconButton(
                            tooltip: 'Close search',
                            onPressed: closeSearch,
                            icon: const Icon(Icons.close_rounded),
                          ),
                          filled: true,
                          fillColor: colors.surfaceContainerLow,
                          border: OutlineInputBorder(
                            borderRadius: WalletRadius.card,
                            borderSide: BorderSide(
                              color: colors.outlineVariant,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: WalletRadius.card,
                            borderSide: BorderSide(
                              color: colors.outlineVariant.withValues(
                                alpha: .4,
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hi, ${context.watch<SettingsProvider>().displayName}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Your gaming space · ${playing.length} playing · ${history.length} played',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Search my games',
                          onPressed: openSearch,
                          icon: const Icon(Icons.search_rounded),
                        ),
                        Tooltip(
                          message: 'Discover more games',
                          child: FilledButton.icon(
                            onPressed: widget.onExplore,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add'),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(height: 18),

        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            borderRadius: WalletRadius.card,
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: .25),
            ),
          ),
          child: Row(
            children: [
              tab(0, 'Playing', playing.length),
              const SizedBox(width: 4),
              tab(1, 'Played', history.length),
              const SizedBox(width: 4),
              tab(2, 'Saved', saved.length),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Text(
                [
                  'Continue playing',
                  'Finished adventures',
                  'Your next adventures',
                ][view],
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (view != 0) const GridDensityButton(screen: 'library'),
            PopupMenuButton<String>(
              tooltip: 'Sort saved games',
              icon: Icon(
                sort == 'title'
                    ? Icons.sort_by_alpha_rounded
                    : Icons.sort_rounded,
                size: 21,
                color: sort == 'title'
                    ? colors.primary
                    : colors.onSurfaceVariant,
              ),
              initialValue: sort,
              onSelected: (v) => setState(() => sort = v),
              itemBuilder: (_) => [
                CheckedPopupMenuItem(
                  value: 'updated',
                  checked: sort == 'updated',
                  child: const Text('Recently updated'),
                ),
                CheckedPopupMenuItem(
                  value: 'title',
                  checked: sort == 'title',
                  child: const Text('Title A–Z'),
                ),
              ],
            ),
            Text(
              '${entries.length} ${entries.length == 1 ? 'game' : 'games'}${query.isNotEmpty ? ' found' : ''}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (entries.isEmpty) ...[
          EmptyState(
            query.isNotEmpty
                ? 'No matching games'
                : view == 1
                ? 'Your next finish starts here'
                : view == 2
                ? 'Build your next adventure'
                : 'Ready for your next adventure?',
            query.isNotEmpty
                ? 'Try another title in your saved games.'
                : view == 1
                ? 'Mark a game Played to keep it here. Replaying keeps your history.'
                : view == 2
                ? 'Tap Saved on any game to keep it here for later.'
                : 'Open a game and tap Playing to add it here.',
          ),
          if (query.isEmpty)
            Center(
              child: FilledButton.icon(
                onPressed: widget.onExplore,
                icon: const Icon(Icons.explore_outlined),
                label: const Text('Discover games'),
              ),
            ),
        ],
        if (view != 0 && layout != 'list' && entries.isNotEmpty)
          LayoutBuilder(
            builder: (context, box) {
              final largeText = MediaQuery.textScalerOf(context).scale(14) > 21;
              final count = columns != 0
                  ? columns
                  : (box.maxWidth /
                            (largeText
                                ? 250
                                : layout == 'compact'
                                ? 170
                                : 230))
                        .floor()
                        .clamp(largeText ? 1 : 2, 6);
              final width = (box.maxWidth - (count - 1) * 12) / count;
              return Wrap(
                spacing: 12,
                runSpacing: 18,
                children: [
                  for (final entry in entries)
                    SizedBox(
                      width: width,
                      child: width < 130
                          ? DenseGameCard(
                              entry.game,
                              caption: library.completedDays(entry.game) == null
                                  ? null
                                  : '${library.completedDays(entry.game)} ${library.completedDays(entry.game) == 1 ? 'day' : 'days'}',
                            )
                          : entryCard(entry, grid: true),
                    ),
                ],
              );
            },
          )
        else if (view == 0 && entries.isNotEmpty)
          LayoutBuilder(
            builder: (context, box) {
              final count = MediaQuery.textScalerOf(context).scale(14) > 21
                  ? 1
                  : (box.maxWidth / 360).floor().clamp(1, 3);
              final width =
                  (box.maxWidth - (count - 1) * WalletSpace.md) / count;
              return Wrap(
                spacing: WalletSpace.md,
                runSpacing: WalletSpace.md,
                children: [
                  for (final entry in entries)
                    SizedBox(width: width, child: entryCard(entry)),
                ],
              );
            },
          )
        else
          for (final entry in entries) ...[
            entryCard(entry),
            const SizedBox(height: 12),
          ],
        if (view == 0 && query.isEmpty) const PersonalOverview(),
      ],
    );
  }
}

class _TrackingGameCard extends StatelessWidget {
  final LibraryEntry entry;
  final String status, actionLabel;
  final int journalCount;
  final bool grid, compact, playedView;
  final IconData actionIcon;
  final VoidCallback? onAction;
  final VoidCallback onJournal;
  const _TrackingGameCard({
    required this.entry,
    this.grid = false,
    this.playedView = false,
    this.compact = false,
    required this.status,
    required this.journalCount,
    required this.actionLabel,
    required this.actionIcon,
    required this.onAction,
    required this.onJournal,
  });

  @override
  Widget build(BuildContext context) {
    final game = entry.game;
    final library = context.watch<LibraryProvider>();
    final active = library.active(game);
    final playing = entry.status == LibraryStatus.playing && !playedView;
    final days = active?.days(library.today);
    final timing = playedView || entry.status == LibraryStatus.completed
        ? library.completedTiming(game)
        : playing && active?.startDate == null
        ? null
        : library.timing(game);
    final metadata = [
      ...game.genres.take(2),
      ...game.platforms.take(1),
    ].join(' · ');
    void actions() => GameActionsMenu(
      game,
      primaryLabel: actionLabel,
      primaryAction: onAction,
      onOpenJournal: onJournal,
    ).show(context);
    if (playing) {
      return PlayingCard(
        game: game,
        metadata: metadata,
        days: days,
        dateLabel: active?.startDate == null
            ? 'Add start date'
            : 'Started ${MaterialLocalizations.of(context).formatMediumDate(active!.startDate!)}',
        onDates: () => editPlaythroughDates(context, game, run: active),
        onComplete: onAction,
        onJournal: onJournal,
        onMenu: actions,
      );
    }
    if (grid) {
      final completedDays = playedView ? library.completedDays(game) : null;
      return Card(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GamePosterCard(
              game,
              onMenu: actions,
              caption: completedDays == null
                  ? null
                  : '$completedDays ${completedDays == 1 ? 'day' : 'days'}',
            ),
            if (compact && actionLabel == 'Start playing')
              Tooltip(
                message: '$actionLabel ${game.title}',
                child: TextButton(
                  onPressed: onAction,
                  child: Text(actionLabel),
                ),
              ),
          ],
        ),
      );
    }
    return GameListRow(
      game,
      metadata: metadata,
      caption: timing,
      onMenu: actions,
      footer: Padding(
        padding: const EdgeInsets.only(top: WalletSpace.sm),
        child: Wrap(
          spacing: WalletSpace.sm,
          children: [
            TextButton.icon(
              onPressed: onAction,
              icon: Icon(actionIcon, size: 18),
              label: Text(actionLabel),
            ),
            TextButton.icon(
              onPressed: onJournal,
              icon: const Icon(Icons.edit_note, size: 18),
              label: const Text('Journal'),
            ),
          ],
        ),
      ),
    );
  }
}
