import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models.dart';
import '../../shared/widgets.dart';
import '../journal/journal_pages.dart';
import '../library/library_provider.dart';
import '../library/playthrough_dates.dart';
import 'companion_providers.dart';

class GameActionsMenu extends StatelessWidget {
  final Game game;
  final Color? iconColor;
  final String? primaryLabel;
  final VoidCallback? primaryAction, onOpenJournal;
  const GameActionsMenu(
    this.game, {
    super.key,
    this.iconColor,
    this.primaryLabel,
    this.primaryAction,
    this.onOpenJournal,
  });
  Future<void> select(BuildContext context, String value) async {
    final hidden = context.read<DiscoveryPreferencesProvider>().hidden(game);

    if (value == 'open') {
      openGame(context, game);
      return;
    }

    if (value == 'primary') {
      primaryAction?.call();
      return;
    }
    if (value == 'openJournal') {
      onOpenJournal?.call();
      return;
    }
    if (value == 'playing') {
      await guarded(
        context,
        () => context.read<LibraryProvider>().startPlaying(game),
      );
      return;
    }
    if (value == 'favorite') {
      await guarded(
        context,
        () => context.read<LibraryProvider>().favorite(game),
      );
      return;
    }
    if (value == 'journal' && context.mounted) {
      await editPlaythrough(context, game);
    }
    if (value == 'completed' && context.mounted) {
      await guarded(context, () async {
        await completeGame(context, game);
      });
    }
    if (value == 'want' && context.mounted) {
      await guarded(
        context,
        () => context.read<LibraryProvider>().updateLibrary(
          game,
          status: LibraryStatus.wantToPlay,
          favorite:
              context.read<LibraryProvider>().entry(game)?.favorite ?? false,
        ),
      );
    }
    if (value == 'dates' && context.mounted) {
      await editPlaythroughDates(context, game);
    }
    if (value == 'history' && context.mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => PlaythroughHistoryPage(game: game),
        ),
      );
    }
    if (value == 'hide' && context.mounted) {
      await guarded(
        context,
        () => context.read<DiscoveryPreferencesProvider>().setHidden(
          game,
          !hidden,
        ),
      );
    }
  }

  List<PopupMenuEntry<String>> items(BuildContext context) {
    final hidden = context.read<DiscoveryPreferencesProvider>().hidden(game);
    return [
      const PopupMenuItem(value: 'open', child: Text('Open details')),
      if (context.read<LibraryProvider>().entry(game) != null) ...[
        const PopupMenuItem(value: 'dates', child: Text('Edit dates')),
        const PopupMenuItem(
          value: 'history',
          child: Text('Playthrough history'),
        ),
      ],
      if (primaryLabel != null)
        PopupMenuItem(
          value: 'primary',
          enabled: primaryAction != null,
          child: Text(primaryLabel!),
        ),
      if (onOpenJournal != null)
        const PopupMenuItem(value: 'openJournal', child: Text('View journal')),
      if (primaryLabel != null || onOpenJournal != null)
        const PopupMenuDivider(),
      PopupMenuItem(
        value: 'favorite',
        child: Text(
          context.read<LibraryProvider>().entry(game)?.favorite == true
              ? 'Remove favorite'
              : 'Add to favorites',
        ),
      ),
      if (primaryLabel == null)
        const PopupMenuItem(
          value: 'playing',
          child: Text('Start / resume playing'),
        ),
      const PopupMenuItem(value: 'want', child: Text('Want to Play')),
      const PopupMenuItem(value: 'completed', child: Text('Mark completed')),
      const PopupMenuItem(value: 'journal', child: Text('Add playthrough')),
      PopupMenuItem(
        value: 'hide',
        child: Text(hidden ? 'Show in discovery' : 'Not interested'),
      ),
    ];
  }

  Future<void> show(BuildContext context) async {
    final selected = await showWalletSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(game.title),
                subtitle: const Text('Game actions'),
              ),
              for (final item in items(context))
                if (item is PopupMenuItem<String>)
                  ListTile(
                    title: item.child,
                    enabled: item.enabled,
                    onTap: () => Navigator.pop(context, item.value),
                  )
                else
                  const Divider(),
            ],
          ),
        ),
      ),
    );
    if (selected != null && context.mounted) await select(context, selected);
  }

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: 'Actions for ${game.title}',
    icon: Icon(Icons.more_horiz, color: iconColor),
    onSelected: (value) => select(context, value),
    itemBuilder: (_) => items(context),
  );
}
