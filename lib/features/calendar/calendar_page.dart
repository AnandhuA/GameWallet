import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/companion_models.dart';
import '../../core/companion_repository.dart';
import '../../core/models.dart';
import '../../shared/widgets.dart';
import '../companion/companion_providers.dart';
import '../companion/game_selector.dart';
import '../settings/settings_provider.dart';

class PlayCalendarPage extends StatefulWidget {
  const PlayCalendarPage({super.key});
  @override
  State<PlayCalendarPage> createState() => _PlayCalendarPageState();
}

class _PlayCalendarPageState extends State<PlayCalendarPage> {
  DateTime selected = DateTime.now();
  bool all = true;
  @override
  Widget build(BuildContext context) {
    final p = context.watch<CalendarProvider>();
    final demo = context.watch<SettingsProvider>().demo;
    final entries = p
        .entries(demo)
        .where((e) => all || DateUtils.isSameDay(e.scheduled, selected))
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Play calendar')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final game = await selectGame(context);
          if (game != null && context.mounted) {
            await Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => PlanEditor(game: game, date: selected),
              ),
            );
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Plan session'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        children: [
          CatalogSourceLabel(demo: demo),
          CalendarDatePicker(
            initialDate: selected,
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
            onDateChanged: (v) => setState(() {
              selected = v;
              all = false;
            }),
          ),
          SwitchListTile(
            value: all,
            onChanged: (v) => setState(() => all = v),
            title: const Text('Show all plans'),
          ),
          const Text(
            'Plans stay on this device. No reminders or notifications are sent.',
          ),
          if (entries.isEmpty)
            const EmptyState(
              'Make time to play',
              'Plan a session without changing game completion status.',
            ),
          for (final plan in entries)
            Card(
              child: ListTile(
                leading: Checkbox(
                  value: plan.completed,
                  onChanged: (v) =>
                      guarded(context, () => p.save(plan.withCompleted(v!))),
                ),
                title: Text(plan.game.title),
                subtitle: Text(
                  '${plan.scheduled.toString().split(' ').first}${plan.hasTime ? ' · ${TimeOfDay.fromDateTime(plan.scheduled).format(context)}' : ''}\n${plan.completed ? 'Session completed' : 'Pending'}${plan.notes.isEmpty ? '' : ' · ${plan.notes}'}',
                ),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => PlanEditor(game: plan.game, initial: plan),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class PlanEditor extends StatefulWidget {
  final Game game;
  final DateTime? date;
  final PlaySessionPlan? initial;
  const PlanEditor({super.key, required this.game, this.date, this.initial});
  @override
  State<PlanEditor> createState() => _PlanEditorState();
}

class _PlanEditorState extends State<PlanEditor> {
  late final notes = TextEditingController(text: widget.initial?.notes ?? '');
  late DateTime date =
      widget.initial?.scheduled ?? widget.date ?? DateTime.now();
  late bool hasTime = widget.initial?.hasTime ?? false;
  late bool completed = widget.initial?.completed ?? false;
  bool saving = false;
  String? error;
  @override
  void dispose() {
    notes.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() => saving = true);
    try {
      await context.read<CalendarProvider>().save(
        PlaySessionPlan(
          id: widget.initial?.id ?? context.read<CompanionRepository>().newId(),
          game: widget.game,
          scheduled: date,
          notes: notes.text,
          hasTime: hasTime,
          completed: completed,
        ),
      );
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          error = 'Could not save session.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Plan play session')),
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
          ListTile(
            title: const Text('Date'),
            subtitle: Text(date.toString().split(' ').first),
            trailing: const Icon(Icons.calendar_month),
            onTap: () async {
              final result = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (result != null) {
                setState(
                  () => date = DateTime(
                    result.year,
                    result.month,
                    result.day,
                    date.hour,
                    date.minute,
                  ),
                );
              }
            },
          ),
          SwitchListTile(
            title: const Text('Include a time'),
            value: hasTime,
            onChanged: (v) => setState(() => hasTime = v),
          ),
          if (hasTime)
            ListTile(
              title: const Text('Time'),
              subtitle: Text(TimeOfDay.fromDateTime(date).format(context)),
              onTap: () async {
                final result = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(date),
                );
                if (result != null) {
                  setState(
                    () => date = DateTime(
                      date.year,
                      date.month,
                      date.day,
                      result.hour,
                      result.minute,
                    ),
                  );
                }
              },
            ),
          TextField(
            controller: notes,
            maxLines: 4,
            maxLength: 2000,
            decoration: const InputDecoration(labelText: 'Session notes'),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: completed,
            onChanged: (v) => setState(() => completed = v!),
            title: const Text('Session completed'),
            subtitle: const Text(
              'This does not mark the whole game completed.',
            ),
          ),
          if (error != null) Notice(error!),
          FilledButton(
            onPressed: saving ? null : save,
            child: Text(saving ? 'Saving…' : 'Save session'),
          ),
          if (widget.initial != null)
            TextButton(
              onPressed: saving
                  ? null
                  : () async {
                      await guarded(
                        context,
                        () => context.read<CalendarProvider>().delete(
                          widget.initial!.id,
                        ),
                      );
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
              child: const Text('Delete session'),
            ),
        ],
      ),
    ),
  );
}
