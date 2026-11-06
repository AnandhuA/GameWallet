import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/models.dart';
import '../features/companion/game_actions.dart';
import 'app_theme.dart';
import 'widgets.dart' show GameArt, openGame;

class _GameMenuIntent extends Intent {
  const _GameMenuIntent();
}

class WalletViewport extends StatelessWidget {
  final Widget child;
  final bool form;
  const WalletViewport({super.key, required this.child, this.form = false});
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: form
            ? WalletTokens.of(context).sheetWidth
            : WalletTokens.of(context).contentWidth,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.sizeOf(context).width >= 900
              ? WalletSpace.page
              : 0,
        ),
        child: child,
      ),
    ),
  );
}

/// Shared pointer and keyboard access to existing game-action handlers.
class GameInteraction extends StatelessWidget {
  final Game game;
  final Widget child;
  final VoidCallback? onTap, onMenu;
  const GameInteraction({
    super.key,
    required this.game,
    required this.child,
    this.onTap,
    this.onMenu,
  });
  @override
  Widget build(BuildContext context) {
    void menu() =>
        onMenu != null ? onMenu!() : GameActionsMenu(game).show(context);
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.f10, shift: true): _GameMenuIntent(),
        SingleActivator(LogicalKeyboardKey.contextMenu): _GameMenuIntent(),
      },
      child: Actions(
        actions: {
          _GameMenuIntent: CallbackAction<_GameMenuIntent>(
            onInvoke: (_) {
              menu();
              return null;
            },
          ),
        },
        child: Material(
          color: Colors.transparent,
          borderRadius: WalletRadius.control,
          child: InkWell(
            borderRadius: WalletRadius.control,
            onTap: onTap ?? () => openGame(context, game),
            onLongPress: menu,
            onSecondaryTap: menu,
            child: child,
          ),
        ),
      ),
    );
  }
}

class GameCover extends StatelessWidget {
  final Game game;
  final bool wide;
  const GameCover(this.game, {super.key, this.wide = false});
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: WalletRadius.control,
    child: AspectRatio(
      aspectRatio: wide ? 16 / 9 : 3 / 4,
      child: GameArt(game, wide: wide),
    ),
  );
}

class GamePosterCard extends StatelessWidget {
  final Game game;
  final String? caption;
  final VoidCallback? onTap, onMenu;
  const GamePosterCard(
    this.game, {
    super.key,
    this.caption,
    this.onTap,
    this.onMenu,
  });
  @override
  Widget build(BuildContext context) => GameInteraction(
    game: game,
    onTap: onTap,
    onMenu: onMenu,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GameCover(game),
        const SizedBox(height: WalletSpace.sm),
        ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.textScalerOf(context).scale(14) * 2.8,
          ),
          child: Text(
            game.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        if (caption != null)
          Padding(
            padding: const EdgeInsets.only(top: WalletSpace.xs),
            child: Text(
              caption!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    ),
  );
}

class GameListRow extends StatelessWidget {
  final Game game;
  final String? metadata, caption;
  final VoidCallback? onTap, onMenu;
  final Widget? footer, trailing;
  final bool compact;
  const GameListRow(
    this.game, {
    super.key,
    this.metadata,
    this.caption,
    this.onTap,
    this.onMenu,
    this.footer,
    this.trailing,
    this.compact = false,
  });
  @override
  Widget build(BuildContext context) => Card(
    shape: const RoundedRectangleBorder(borderRadius: WalletRadius.row),
    child: GameInteraction(
      game: game,
      onTap: onTap,
      onMenu: onMenu,
      child: Padding(
        padding: const EdgeInsets.all(WalletSpace.sm),
        child: Column(
          children: [
            Row(
              children: [
                SizedBox(width: 56, child: GameCover(game)),
                const SizedBox(width: WalletSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        game.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      if (metadata != null && metadata!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: WalletSpace.xs),
                          child: Text(
                            metadata!,
                            maxLines: compact ? 1 : null,
                            overflow: compact ? TextOverflow.ellipsis : null,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                      if (caption != null)
                        Padding(
                          padding: const EdgeInsets.only(top: WalletSpace.xs),
                          child: Text(
                            caption!,
                            maxLines: compact ? 1 : null,
                            overflow: compact ? TextOverflow.ellipsis : null,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
            ?footer,
          ],
        ),
      ),
    ),
  );
}

class StatusPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool artwork;
  const StatusPill(this.label, {super.key, this.icon, this.artwork = false});
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tokens = WalletTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: WalletSpace.sm,
        vertical: WalletSpace.xs,
      ),
      decoration: BoxDecoration(
        color: artwork
            ? tokens.artworkBase.withValues(alpha: .8)
            : colors.surfaceContainerHigh,
        borderRadius: WalletRadius.control,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 14,
              color: artwork ? tokens.artworkText : colors.primary,
            ),
            const SizedBox(width: WalletSpace.xs),
          ],
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: artwork ? tokens.artworkText : colors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SectionHeader(this.title, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: WalletSpace.lg, bottom: WalletSpace.md),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        ?trailing,
      ],
    ),
  );
}

class FilterChipBar extends StatelessWidget {
  final List<Widget> children;
  const FilterChipBar({super.key, required this.children});
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: WalletSpace.sm,
    runSpacing: WalletSpace.sm,
    children: children,
  );
}

class PlayingCard extends StatelessWidget {
  final Game game;
  final String metadata, dateLabel;
  final int? days;
  final VoidCallback onDates, onJournal, onMenu;
  final VoidCallback? onComplete;
  const PlayingCard({
    super.key,
    required this.game,
    required this.metadata,
    required this.dateLabel,
    required this.days,
    required this.onDates,
    required this.onJournal,
    required this.onMenu,
    this.onComplete,
  });
  @override
  Widget build(BuildContext context) {
    final tokens = WalletTokens.of(context), text = Theme.of(context).textTheme;
    return ClipRRect(
      borderRadius: WalletRadius.card,
      child: Stack(
        children: [
          Positioned.fill(
            child: ExcludeSemantics(child: GameArt(game, wide: true)),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: tokens.scrim),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(WalletSpace.page),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 170),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Now playing',
                          style: text.labelMedium?.copyWith(
                            color: tokens.artworkMuted,
                          ),
                        ),
                      ),
                      if (days != null) StatusPill('Day $days', artwork: true),
                    ],
                  ),
                  const SizedBox(height: WalletSpace.md),
                  GameInteraction(
                    game: game,
                    onMenu: onMenu,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: WalletSpace.xs,
                      ),
                      child: Text(
                        game.title,
                        style: text.titleLarge?.copyWith(
                          color: tokens.artworkText,
                        ),
                      ),
                    ),
                  ),
                  if (metadata.isNotEmpty)
                    Text(
                      metadata,
                      style: text.bodySmall?.copyWith(
                        color: tokens.artworkMuted,
                      ),
                    ),
                  TextButton.icon(
                    onPressed: onDates,
                    style: TextButton.styleFrom(
                      foregroundColor: tokens.artworkText,
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft,
                    ),
                    icon: const Icon(Icons.calendar_today_outlined, size: 16),
                    label: Text(dateLabel),
                  ),
                  const SizedBox(height: WalletSpace.xs),
                  Wrap(
                    spacing: WalletSpace.sm,
                    runSpacing: WalletSpace.sm,
                    children: [
                      FilledButton.icon(
                        onPressed: onComplete,
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text('Complete game'),
                      ),
                      OutlinedButton.icon(
                        onPressed: onJournal,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: tokens.artworkText,
                          side: BorderSide(
                            color: tokens.artworkMuted.withValues(alpha: .5),
                          ),
                        ),
                        icon: const Icon(Icons.edit_note, size: 18),
                        label: const Text('Journal'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared presentation for scrollable forms. Existing handlers own validation and saving.
class AppBottomSheet extends StatelessWidget {
  final Widget child;
  const AppBottomSheet({super.key, required this.child});
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: WalletTokens.of(context).sheetWidth,
        maxHeight: MediaQuery.sizeOf(context).height * .9,
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          WalletSpace.page,
          WalletSpace.md,
          WalletSpace.page,
          WalletSpace.page + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: child,
      ),
    ),
  );
}

Future<T?> showWalletSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool showDragHandle = true,
  bool isScrollControlled = true,
  bool useSafeArea = true,
}) {
  final duration = WalletTokens.motion(context);
  if (MediaQuery.sizeOf(context).width >= 700) {
    return showDialog<T>(
      context: context,
      animationStyle: AnimationStyle(
        duration: duration,
        reverseDuration: duration,
      ),
      builder: (context) => Dialog(child: builder(context)),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    showDragHandle: showDragHandle,
    useSafeArea: useSafeArea,
    sheetAnimationStyle: AnimationStyle(
      duration: duration,
      reverseDuration: duration,
    ),
    builder: builder,
  );
}

class ConfirmDialog extends StatelessWidget {
  final String title, message, confirmLabel;
  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Delete',
  });
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(title),
    content: Text(message),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, true),
        child: Text(confirmLabel),
      ),
    ],
  );
}
