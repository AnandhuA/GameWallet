import 'playthrough_dates.dart';
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
                ? colors.onSurface.withValues(alpha: .08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            key: ValueKey('tracking-tab-$value'),
            onTap: () => setState(() => view = value),
            borderRadius: BorderRadius.circular(12),
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
                        borderRadius: BorderRadius.circular(7),
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
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: colors.outlineVariant,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
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
                                'My games',
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Hi, ${context.watch<SettingsProvider>().displayName} · Your gaming space',
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
                        IconButton.filledTonal(
                          tooltip: 'Discover more games',
                          onPressed: widget.onExplore,
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        if (query.isEmpty) const PersonalOverview(),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: colors.onSurface.withValues(alpha: .035),
            borderRadius: BorderRadius.circular(16),
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
        else
          for (final entry in entries) ...[
            entryCard(entry),
            const SizedBox(height: 12),
          ],
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
    final theme = Theme.of(context), colors = theme.colorScheme;
    final game = entry.game;
    final muted = colors.onSurfaceVariant;
    final library = context.watch<LibraryProvider>();
    final active = library.active(game);
    final playing = entry.status == LibraryStatus.playing && !playedView;
    final days = active?.days(library.today);
    final timing = playedView || entry.status == LibraryStatus.completed
        ? library.completedTiming(game)
        : playing && active?.startDate == null
        ? null
        : library.timing(game);
    final panel = Color.alphaBlend(
      colors.primary.withValues(alpha: .035),
      colors.surface,
    );
    final metadata = [
      if (game.release != null) '${game.release!.year}',
      ...game.genres.take(2),
    ].join(' · ');
    if (grid) {
      final titleStyle = theme.textTheme.titleSmall?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        height: 1.3,
      );
      return Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: compact ? Colors.transparent : panel,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: compact
              ? BorderSide.none
              : BorderSide(color: colors.outlineVariant.withValues(alpha: .4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () => openGame(context, game),
              onLongPress: () => GameActionsMenu(
                game,
                primaryLabel: actionLabel,
                primaryAction: onAction,
                onOpenJournal: onJournal,
              ).show(context),
              onSecondaryTap: () => GameActionsMenu(
                game,
                primaryLabel: actionLabel,
                primaryAction: onAction,
                onOpenJournal: onJournal,
              ).show(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: compact ? .82 : .72,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [GameArt(game)],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 2),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight:
                            MediaQuery.textScalerOf(
                              context,
                            ).scale(titleStyle?.fontSize ?? 14) *
                            2.6,
                      ),
                      child: Text(
                        game.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: titleStyle,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      [
                        if (game.release != null) '${game.release!.year}',
                        if (!compact) status,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(color: muted),
                    ),
                  ),
                ],
              ),
            ),
            if (timing != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 5, 10, 0),
                child: Text(
                  timing,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(color: muted),
                ),
              ),
            if (compact && actionLabel == 'Start playing')
              Tooltip(
                message: '$actionLabel ${game.title}',
                child: TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                  child: Text(actionLabel),
                ),
              )
            else if (compact)
              const SizedBox(height: 12)
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 4, 2, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: onAction,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 8,
                          ),
                          minimumSize: const Size(0, 48),
                        ),
                        child: Text(
                          onAction == null ? status : actionLabel,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: onAction == null ? muted : colors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Journal for ${game.title}',
                      onPressed: onJournal,
                      icon: const Icon(Icons.edit_note, size: 20),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    }
    final neutralPanel = Color.alphaBlend(
      colors.onSurface.withValues(alpha: .035),
      colors.surface,
    );
    void actions() => GameActionsMenu(
      game,
      primaryLabel: actionLabel,
      primaryAction: onAction,
      onOpenJournal: onJournal,
    ).show(context);
    if (playing) {
      final highlight = theme.brightness == Brightness.dark
          ? colors.primary
          : colors.primaryContainer;
      return Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        color: const Color(0xFF121619),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFF282D30)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                Positioned.fill(
                  child: ExcludeSemantics(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FractionallySizedBox(
                        widthFactor: .8,
                        heightFactor: 1,
                        child: Opacity(
                          opacity: .38,
                          child: GameArt(game, wide: true),
                        ),
                      ),
                    ),
                  ),
                ),
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF121619),
                          Color(0xF0121619),
                          Color(0x80121619),
                        ],
                        stops: [0, .4, 1],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: highlight,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              'Now playing',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (days != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: highlight.withValues(alpha: .14),
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Text(
                                'Day $days',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: highlight,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () => openGame(context, game),
                        onLongPress: actions,
                        onSecondaryTap: actions,
                        borderRadius: BorderRadius.circular(10),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 64,
                              height: 88,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(9),
                                child: GameArt(game),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    game.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          height: 1.25,
                                        ),
                                  ),
                                  TextButton.icon(
                                    style: TextButton.styleFrom(
                                      foregroundColor: const Color(0xFFB8C1C7),
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(0, 44),
                                      alignment: Alignment.centerLeft,
                                    ),
                                    onPressed: () =>
                                        editPlaythroughDates(context, game),
                                    icon: const Icon(
                                      Icons.calendar_today_outlined,
                                      size: 14,
                                    ),
                                    label: Text(
                                      active?.startDate == null
                                          ? 'Add start date'
                                          : 'Started ${MaterialLocalizations.of(context).formatMediumDate(active!.startDate!)}',
                                      maxLines: 2,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: const Color(0xFFB8C1C7),
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFF151A1E),
                border: Border(top: BorderSide(color: Color(0xFF282D30))),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: LayoutBuilder(
                builder: (context, box) {
                  final complete = FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      backgroundColor: highlight.withValues(alpha: .16),
                      foregroundColor: highlight,
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onPressed: onAction,
                    icon: const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 18,
                    ),
                    label: const Text('Complete game'),
                  );
                  final journal = TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    onPressed: onJournal,
                    icon: const Icon(Icons.edit_note_rounded, size: 20),
                    label: Text(
                      journalCount > 0 ? 'Journal ($journalCount)' : 'Journal',
                    ),
                  );
                  if (MediaQuery.textScalerOf(context).scale(14) > 19 ||
                      box.maxWidth < 300) {
                    return Wrap(spacing: 8, children: [complete, journal]);
                  }
                  return Row(
                    children: [
                      Expanded(child: complete),
                      const SizedBox(width: 8),
                      journal,
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      );
    }
    return Card(
      margin: EdgeInsets.zero,
      color: neutralPanel,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.onSurface.withValues(alpha: .08)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () => openGame(context, game),
                  onLongPress: actions,
                  onSecondaryTap: actions,
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 76,
                    height: 108,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: GameArt(game),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () => openGame(context, game),
                        onLongPress: actions,
                        onSecondaryTap: actions,
                        child: Text(
                          game.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        metadata,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: muted,
                        ),
                      ),
                      if (timing != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            timing,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colors.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              height: 1,
              color: colors.onSurface.withValues(alpha: .07),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: colors.primary,
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  onPressed: onAction,
                  icon: Icon(actionIcon, size: 18),
                  label: Text(
                    onAction == null ? status : actionLabel,
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  tooltip: 'Journal for ${game.title}',
                  onPressed: onJournal,
                  icon: const Icon(Icons.edit_note_rounded, size: 23),
                  color: muted,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
