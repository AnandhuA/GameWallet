import '../features/settings/preferences_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../features/explore/explore_page.dart';
import '../features/explore/search_provider.dart';
import '../features/home/home_page.dart';
import '../features/home/home_provider.dart';
import '../features/lineup/lineup_pages.dart';
import '../features/pick/smart_pick_page.dart';
import '../features/profile/profile_page.dart';
import '../features/library/play_tracking_page.dart';
import '../features/settings/settings_page.dart';
import '../features/settings/settings_provider.dart';

void openSettings(BuildContext context) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: const SettingsPage(),
    ),
  ),
);

enum AppDestination { home, explore, myGames, lineup, profile }

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int selected = AppDestination.myGames.index;
  bool onboardingOpened = false;
  String? configuration;
  static const labels = ['Home', 'Explore', 'My games', 'LineUp', 'Profile'];
  static const icons = [
    Icons.home_outlined,
    Icons.auto_awesome_outlined,
    Icons.sports_esports_outlined,
    Icons.view_list_outlined,
    Icons.person_outline,
  ];
  static const selectedIcons = [
    Icons.home,
    Icons.auto_awesome,
    Icons.sports_esports,
    Icons.view_list,
    Icons.person,
  ];
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = context.watch<SettingsProvider>();
    if (settings.needsOnboarding && !onboardingOpened) {
      onboardingOpened = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const PreferencesPage(onboarding: true),
            ),
          );
        }
      });
    }
    final key =
        '${settings.demo}:${settings.connectionRevision}:${settings.platforms.join(',')}:${settings.genres.join(',')}';
    if (key != configuration) {
      configuration = key;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        context.read<HomeProvider>().load(settings.demo, settings.platforms);
        context.read<SearchProvider>().configure(
          settings.demo,
          settings.platforms,
        );
      });
    }
  }

  void browse({String? genre, String? platform}) {
    final search = context.read<SearchProvider>();
    search.apply(
      genreValue: genre,
      platformValue:
          platform ??
          (search.preferredPlatforms.isEmpty
              ? null
              : SearchProvider.myPlatforms),
    );
    setState(() => selected = AppDestination.explore.index);
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final settings = context.watch<SettingsProvider>();
    final pages = [
      HomePage(
        onBrowse: browse,
        onSearch: () => setState(() => selected = AppDestination.explore.index),
        onPick: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const SmartPickPage()),
        ),
      ),
      const ExplorePage(),
      PlayTrackingPage(
        onExplore: () =>
            setState(() => selected = AppDestination.explore.index),
      ),
      const LineUpPage(),
      const ProfilePage(),
    ];
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Row(
          children: [
            if (wide)
              NavigationRail(
                leading: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Icon(
                    Icons.sports_esports,
                    color: Theme.of(context).colorScheme.primary,
                    size: 32,
                  ),
                ),
                selectedIndex: selected,
                extended: MediaQuery.sizeOf(context).width >= 1200,
                onDestinationSelected: (i) => setState(() => selected = i),
                destinations: List.generate(
                  labels.length,
                  (i) => NavigationRailDestination(
                    icon: Icon(icons[i]),
                    selectedIcon: Icon(selectedIcons[i]),
                    label: Text(labels[i]),
                  ),
                ),
              ),
            Expanded(
              child: Column(
                children: [
                  if (settings.demo)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 5,
                      ),
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                      child: const Text(
                        'Demo · fictional sample data',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                  if (!settings.hasApiKey && settings.demo)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => openSettings(context),
                        icon: Icon(Icons.link, size: 16),
                        label: const Text(
                          'Connect RAWG',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  Expanded(
                    child: HeroMode(
                      enabled: false,
                      child: IndexedStack(index: selected, children: pages),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: selected,
              onDestinationSelected: (i) => setState(() => selected = i),
              destinations: List.generate(
                labels.length,
                (i) => NavigationDestination(
                  icon: Icon(icons[i]),
                  selectedIcon: Icon(selectedIcons[i]),
                  label: labels[i],
                ),
              ),
            ),
    );
  }
}
