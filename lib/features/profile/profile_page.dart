import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models.dart';
import '../../shared/app_shell.dart';
import '../../shared/widgets.dart';
import '../library/library_page.dart';
import '../library/library_provider.dart';
import '../settings/settings_provider.dart';
import '../settings/preferences_page.dart';
import '../journal/journal_pages.dart';
import '../calendar/calendar_page.dart';
import '../companion/companion_providers.dart';
import 'statistics_page.dart';
import 'hidden_games_page.dart';
import '../pick/pick_page.dart';
import '../explore/explore_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});
  void openWheel(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => WheelProvider(),
          child: Scaffold(
            appBar: AppBar(title: const Text('Spin wheel')),
            body: Builder(
              builder: (wheelContext) => PickPage(
                onExplore: () {
                  Navigator.push(
                    wheelContext,
                    MaterialPageRoute<void>(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: const Text('Explore')),
                        body: const ExplorePage(),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> editName(BuildContext context) async {
    final settings = context.read<SettingsProvider>();
    final value = await showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(initial: settings.displayName),
    );
    if (value != null && context.mounted) {
      await guarded(context, () => settings.setDisplayName(value));
    }
  }

  void library(
    BuildContext context, {
    LibraryStatus? status,
    bool favorites = false,
    bool notes = false,
    bool saved = false,
  }) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(
          title: Text(
            notes
                ? 'Your journal'
                : favorites
                ? 'Favorites'
                : status?.label ?? 'Library',
          ),
        ),
        body: LibraryPage(
          initialStatus: status,
          initialFavorites: favorites,
          initialNotes: notes,
          initialSaved: saved,
        ),
      ),
    ),
  );
  void info(BuildContext context, String title, String text) =>
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(child: Text(text)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final entries = context.watch<LibraryProvider>().entries(settings.demo);
    final want = entries
        .where((e) => e.status == LibraryStatus.wantToPlay)
        .length;
    final notes = context
        .watch<JournalProvider>()
        .entries(settings.demo)
        .length;
    final completed = entries
        .where((e) => e.status == LibraryStatus.completed)
        .length;
    final favorites = entries.where((e) => e.favorite).length;
    final dropped = entries
        .where((e) => e.status == LibraryStatus.dropped)
        .length;
    Widget stat(String label, int value, IconData icon, VoidCallback action) =>
        Expanded(
          child: Card(
            margin: EdgeInsets.zero,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: action,
              child: Padding(
                padding: const EdgeInsets.all(13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      icon,
                      color: Theme.of(context).colorScheme.primary,
                      size: 22,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '$value',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(label, style: Theme.of(context).textTheme.labelMedium),
                  ],
                ),
              ),
            ),
          ),
        );
    Widget menu(
      IconData icon,
      String title,
      String? subtitle,
      VoidCallback action,
    ) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        leading: Icon(icon, size: 25),
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle),
        trailing: Icon(Icons.chevron_right),
        onTap: action,
      ),
    );
    return ListView(
      key: const PageStorageKey('profile'),
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Profile',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            IconButton(
              tooltip: 'Edit local profile',
              onPressed: () => editName(context),
              icon: Icon(Icons.edit_outlined),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  child: Icon(Icons.person, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        settings.displayName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Local Game Wallet profile',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            stat(
              'Want to play',
              want,
              Icons.bookmark_border,
              () => library(context, status: LibraryStatus.wantToPlay),
            ),
            const SizedBox(width: 8),
            stat(
              'Journal',
              notes,
              Icons.edit_note,
              () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => const JournalPage()),
              ),
            ),
            const SizedBox(width: 8),
            stat(
              'Completed',
              completed,
              Icons.task_alt,
              () => library(context, status: LibraryStatus.completed),
            ),
          ],
        ),
        const SizedBox(height: 24),
        menu(
          Icons.casino_outlined,
          'Spin wheel',
          'Let your next game pick itself',
          () => openWheel(context),
        ),
        menu(
          Icons.bookmarks_outlined,
          'My library',
          '${entries.length} saved',
          () => library(context),
        ),
        menu(
          Icons.play_circle_outline,
          'Now playing',
          null,
          () => library(context, status: LibraryStatus.playing),
        ),
        menu(
          Icons.visibility_off_outlined,
          'Not interested',
          '${context.watch<DiscoveryPreferencesProvider>().hiddenGames(settings.demo).length} hidden',
          () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const HiddenGamesPage()),
          ),
        ),
        menu(
          Icons.calendar_month,
          'Play calendar',
          'Plan upcoming sessions',
          () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const PlayCalendarPage()),
          ),
        ),
        menu(
          Icons.tune,
          'Gaming preferences',
          settings.genres.isEmpty
              ? 'Choose genres and platforms'
              : settings.genres.join(' · '),
          () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const PreferencesPage()),
          ),
        ),
        menu(
          Icons.favorite_border,
          'Favorites',
          '$favorites saved',
          () => library(context, favorites: true),
        ),
        menu(
          Icons.visibility_off_outlined,
          'Dropped games',
          '$dropped in your library',
          () => library(context, status: LibraryStatus.dropped),
        ),
        menu(
          Icons.bar_chart,
          'Statistics',
          null,
          () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const StatisticsPage()),
          ),
        ),
        menu(
          Icons.settings_outlined,
          'Settings',
          null,
          () => openSettings(context),
        ),
        menu(
          Icons.info_outline,
          'About Game Wallet',
          null,
          () => info(
            context,
            'Game Wallet',
            'Discover your next game across PC, console, Android and iOS.\n\nLive data and artwork: RAWG.\nLocal library: Hive.\nNo backend or account required for your personal collection.\n\nDemo content is fictional.',
          ),
        ),
        menu(
          Icons.privacy_tip_outlined,
          'Privacy & local data',
          null,
          () => info(
            context,
            'Privacy & local data',
            'Your display name, library, notes, ratings, preferences and RAWG key are stored on this device. Game Wallet does not operate a backend or sync service.\n\nDiscovery searches and your API key are sent directly to RAWG; images load from their providers. Opening an external link visits that provider.\n\nClearing app storage deletes local data. Clearing API cache in Settings preserves your library.',
          ),
        ),
      ],
    );
  }
}

class _NameDialog extends StatefulWidget {
  final String initial;
  const _NameDialog({required this.initial});
  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final controller = TextEditingController(text: widget.initial);
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void save() {
    if (controller.text.trim().isNotEmpty) {
      Navigator.pop(context, controller.text);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Edit local profile'),
    content: TextField(
      controller: controller,
      autofocus: true,
      maxLength: 40,
      decoration: const InputDecoration(labelText: 'Display name'),
      onSubmitted: (_) => save(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: save, child: const Text('Save')),
    ],
  );
}
