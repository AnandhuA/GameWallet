import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../features/settings/settings_provider.dart';

/// Screen-specific density; zero keeps the responsive automatic layout.
class GridDensityButton extends StatelessWidget {
  final String screen;
  const GridDensityButton({super.key, required this.screen});
  @override
  Widget build(BuildContext context) {
    final columns = context.select<SettingsProvider, int>(
      (p) => p.gridColumns(screen),
    );
    return IconButton.filledTonal(
      tooltip: 'View style',
      icon: const Icon(Icons.grid_view_rounded, size: 20),
      onPressed: () async {
        final selected = await showModalBottomSheet<Object>(
          context: context,
          showDragHandle: true,
          builder: (context) => SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Grid layout',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Choose more artwork or more games per row. Long press a game for actions.',
                  ),
                  const SizedBox(height: 16),
                  if (screen == 'library') ...[
                    for (final style in {
                      'compact': 'Compact grid',
                      'grid': 'Large grid',
                      'list': 'List',
                    }.entries)
                      ListTile(
                        title: Text(style.value),
                        leading: Icon(
                          style.key == 'list'
                              ? Icons.view_list_outlined
                              : Icons.grid_view_rounded,
                        ),
                        trailing:
                            context.read<SettingsProvider>().libraryLayout ==
                                style.key
                            ? const Icon(Icons.check)
                            : null,
                        onTap: () => Navigator.pop(context, style.key),
                      ),
                    const Divider(),
                  ],
                  for (final count in [0, 2, 3, 4, 5])
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      selected: columns == count,
                      selectedTileColor: Theme.of(
                        context,
                      ).colorScheme.secondaryContainer,
                      leading: Icon(
                        count == 0
                            ? Icons.auto_awesome_mosaic_outlined
                            : Icons.view_week_outlined,
                      ),
                      title: Text(
                        count == 0 ? 'Auto · fit to screen' : '$count columns',
                      ),
                      trailing: columns == count
                          ? const Icon(Icons.check_circle_rounded)
                          : null,
                      onTap: () => Navigator.pop(context, count),
                    ),
                ],
              ),
            ),
          ),
        );
        if (selected != null && context.mounted) {
          try {
            final settings = context.read<SettingsProvider>();
            if (selected is int) {
              await settings.setGridColumns(screen, selected);
            } else if (selected is String) {
              await settings.setLibraryLayout(selected);
            }
          } catch (_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Could not save grid layout. Try again.'),
                ),
              );
            }
          }
        }
      },
    );
  }
}
