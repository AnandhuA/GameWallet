import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../shared/widgets.dart';
import '../companion/companion_providers.dart';
import '../settings/settings_provider.dart';

class HiddenGamesPage extends StatelessWidget {
  const HiddenGamesPage({super.key});
  @override
  Widget build(BuildContext context) {
    final p = context.watch<DiscoveryPreferencesProvider>();
    final games = p.hiddenGames(context.watch<SettingsProvider>().demo);
    return Scaffold(
      appBar: AppBar(title: const Text('Not interested')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Hidden from discovery and picking. Library records and notes are kept.',
          ),
          if (games.isEmpty)
            const EmptyState(
              'Nothing hidden',
              'Use a game’s action menu to hide it.',
            ),
          for (final g in games)
            ListTile(
              leading: SizedBox(width: 42, height: 58, child: GameArt(g)),
              title: Text(g.title),
              trailing: TextButton(
                onPressed: () => guarded(context, () => p.setHidden(g, false)),
                child: const Text('Restore'),
              ),
            ),
        ],
      ),
    );
  }
}
