import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../shared/widgets.dart';
import '../settings/settings_provider.dart';
import '../companion/companion_providers.dart';
import '../calendar/calendar_page.dart';
import 'library_provider.dart';
import 'dashboard_model.dart';

class PersonalOverview extends StatelessWidget {
  const PersonalOverview({super.key});
  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final library = context.watch<LibraryProvider>();
    final model = DashboardModel(
      library.entries(settings.demo),
      context.watch<CalendarProvider>().entries(settings.demo),
      DateTime.now(),
    );

    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    if (model.plans.isEmpty && model.finishes.isEmpty) {
      return const SizedBox.shrink();
    }
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (model.plans.isNotEmpty) ...[
          Row(
            children: [
              Expanded(
                child: Text('Coming up', style: theme.textTheme.titleSmall),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const PlayCalendarPage(),
                  ),
                ),
                child: const Text('Calendar'),
              ),
            ],
          ),
          for (final plan in model.plans)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.event_outlined, color: colors.primary),
              title: Text(
                plan.game.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${MaterialLocalizations.of(context).formatMediumDate(plan.scheduled)}${plan.hasTime ? ' · ${TimeOfDay.fromDateTime(plan.scheduled).format(context)}' : ''}',
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => PlanEditor(game: plan.game, initial: plan),
                ),
              ),
            ),
        ],
        if (model.finishes.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Recent finishes', style: theme.textTheme.titleSmall),
          ),
          for (final finish in model.finishes)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.task_alt_rounded),
              title: Text(
                finish.$1.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                MaterialLocalizations.of(
                  context,
                ).formatMediumDate(finish.$2.endDate!),
              ),
              onTap: () => openGame(context, finish.$1),
            ),
        ],
      ],
    );
    return Padding(padding: const EdgeInsets.only(bottom: 20), child: content);
  }
}
