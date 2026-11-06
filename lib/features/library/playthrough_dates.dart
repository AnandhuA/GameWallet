import '../../shared/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models.dart';
import '../../shared/widgets.dart';
import '../companion/companion_providers.dart';
import '../journal/journal_pages.dart';
import 'library_provider.dart';

class CompletionChoice {
  final GamePlaythrough run;
  final bool review;
  const CompletionChoice(this.run, this.review);
}

class PlaythroughDatesDialog extends StatefulWidget {
  final GamePlaythrough initial;
  final bool completion;
  const PlaythroughDatesDialog({
    super.key,
    required this.initial,
    this.completion = false,
  });
  @override
  State<PlaythroughDatesDialog> createState() => _DatesState();
}

class _DatesState extends State<PlaythroughDatesDialog> {
  late DateTime? start = widget.initial.startDate, end = widget.initial.endDate;
  String? error;
  Future<void> pick(bool first) async {
    final today = context.read<LibraryProvider>().today;
    final value = await showDatePicker(
      context: context,
      initialDate: ((first ? start : end) ?? today).isAfter(today)
          ? today
          : ((first ? start : end) ?? today).isBefore(DateTime(1900))
          ? DateTime(1900)
          : ((first ? start : end) ?? today),
      firstDate: DateTime(1900),
      lastDate: today,
    );
    if (value != null && mounted) {
      setState(() {
        if (first) {
          start = value;
        } else {
          end = value;
        }
        error = null;
      });
    }
  }

  void save(bool review) {
    final run = GamePlaythrough(
      id: widget.initial.id,
      startDate: start,
      endDate: end,
      completed: widget.initial.completed,
    );
    try {
      context.read<LibraryProvider>().validateDates(run);
      Navigator.pop(context, CompletionChoice(run, review));
    } catch (e) {
      setState(
        () => error = e.toString().replaceFirst('Invalid argument(s): ', ''),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = start == null || (widget.initial.completed && end == null)
        ? null
        : inclusiveDays(start!, end ?? context.read<LibraryProvider>().today);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final validDuration = days != null && days > 0;
    Widget dateField(bool first) {
      final value = first ? start : end;
      return Material(
        color: colors.surfaceContainerHighest.withValues(alpha: .55),
        borderRadius: WalletRadius.row,
        child: ListTile(
          dense: true,
          minVerticalPadding: 8,
          shape: RoundedRectangleBorder(borderRadius: WalletRadius.row),
          contentPadding: const EdgeInsets.only(left: 14, right: 4),
          leading: Icon(
            first ? Icons.play_circle_outline_rounded : Icons.flag_outlined,
            color: colors.primary,
          ),
          title: Text(
            first ? 'Start date' : 'End date',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          subtitle: Text(
            value == null
                ? 'Not recorded'
                : MaterialLocalizations.of(context).formatMediumDate(value),
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          onTap: () => pick(first),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (value != null)
                IconButton(
                  tooltip: first ? 'Clear start date' : 'Clear end date',
                  onPressed: () => setState(() {
                    if (first) {
                      start = null;
                    } else {
                      end = null;
                    }
                    error = null;
                  }),
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              IconButton(
                tooltip: first ? 'Choose start date' : 'Choose end date',
                onPressed: () => pick(first),
                icon: const Icon(Icons.calendar_month_outlined, size: 20),
              ),
            ],
          ),
        ),
      );
    }

    return AppBottomSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: WalletRadius.row,
                ),
                child: Icon(
                  widget.completion
                      ? Icons.task_alt_rounded
                      : Icons.edit_calendar_outlined,
                  color: colors.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.completion ? 'Complete game' : 'Edit dates',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          dateField(true),
          if (widget.initial.completed) ...[
            const SizedBox(height: 8),
            dateField(false),
          ],
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: validDuration
                  ? colors.primaryContainer.withValues(alpha: .5)
                  : colors.surfaceContainerLow,
              borderRadius: WalletRadius.row,
            ),
            child: Row(
              children: [
                Icon(
                  validDuration
                      ? Icons.timelapse_rounded
                      : Icons.info_outline_rounded,
                  size: 22,
                  color: colors.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        days == null
                            ? 'Dates not recorded'
                            : days < 1
                            ? 'End date must follow start date'
                            : widget.initial.completed
                            ? 'Completed in $days ${days == 1 ? 'day' : 'days'}'
                            : 'Day $days',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(error!, style: TextStyle(color: colors.error)),
            ),
          const SizedBox(height: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: () => save(widget.completion),
            icon: Icon(
              widget.completion
                  ? Icons.rate_review_outlined
                  : Icons.check_rounded,
              size: 20,
            ),
            label: Text(widget.completion ? 'Add review' : 'Save dates'),
          ),
          if (widget.completion) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () => save(false),
              child: const Text('Complete without review'),
            ),
          ],
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

Future<void> editPlaythroughDates(
  BuildContext context,
  Game game, {
  GamePlaythrough? run,
}) async {
  final library = context.read<LibraryProvider>();
  final old = library.entry(game);
  if (old == null) return;
  final initial =
      run ??
      library.active(game) ??
      (old.status == LibraryStatus.playing
          ? GamePlaythrough(id: 'legacy-active:${game.key}')
          : old.playthroughs.lastOrNull ??
                GamePlaythrough(
                  id: 'legacy:${game.key}',
                  completed: library.hasPlayed(game),
                ));
  final choice = await showWalletSheet<CompletionChoice>(
    context: context,
    builder: (_) => PlaythroughDatesDialog(initial: initial),
  );
  if (choice != null && context.mounted) {
    await guarded(context, () => library.updateDates(game, choice.run));
  }
}

class PlaythroughHistoryPage extends StatelessWidget {
  final Game game;
  const PlaythroughHistoryPage({super.key, required this.game});
  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>(),
        journal = context.watch<JournalProvider>();
    final entry = library.entry(game),
        runs =
            library.entry(game)?.playthroughs.reversed.toList() ??
            <GamePlaythrough>[];
    final undated =
        (entry?.completedRuns ?? 0) - runs.where((r) => r.completed).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Playthrough history')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(game.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          if (undated > 0)
            Notice(
              '$undated earlier ${undated == 1 ? 'completion' : 'completions'} · dates not recorded',
            ),
          if (runs.isEmpty)
            EmptyState(
              'Dates not recorded',
              'Add known dates without changing your completion count.',
              retry: () => editPlaythroughDates(context, game),
            ),
          for (final run in runs)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      run.completed ? 'Completed' : 'In progress',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${run.startDate == null ? 'Start not recorded' : dateKey(run.startDate!)} → ${run.endDate == null ? 'End not recorded' : dateKey(run.endDate!)}',
                    ),
                    Text(
                      run.days(library.today) == null
                          ? 'Dates not recorded'
                          : run.completed
                          ? 'Completed in ${run.days(library.today)} ${run.days(library.today) == 1 ? 'day' : 'days'}'
                          : 'Day ${run.days(library.today)}',
                    ),
                    TextButton.icon(
                      onPressed: () =>
                          editPlaythroughDates(context, game, run: run),
                      icon: const Icon(Icons.edit_calendar),
                      label: const Text('Edit dates'),
                    ),
                    for (final review
                        in journal
                            .entries(game.demo, gameKey: game.key)
                            .where((r) => r.playthroughId == run.id))
                      ListTile(
                        title: Text(
                          review.rating == null
                              ? 'View review'
                              : '${review.rating}/5 · View review',
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                JournalDetail(id: review.id, demo: game.demo),
                          ),
                        ),
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
