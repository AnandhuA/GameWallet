import '../../shared/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models.dart';
import '../../shared/widgets.dart';
import 'settings_provider.dart';

class PreferencesPage extends StatefulWidget {
  final bool onboarding;
  const PreferencesPage({super.key, this.onboarding = false});
  @override
  State<PreferencesPage> createState() => _PreferencesPageState();
}

class _PreferencesPageState extends State<PreferencesPage> {
  late final settings = context.read<SettingsProvider>();
  late final name = TextEditingController(text: settings.displayName);
  late final genres = [...settings.genres];
  late final platforms = [...settings.platforms];
  late Future<CatalogFilters> metadata = settings.loadPlatforms();
  int step = 0;
  bool saving = false;
  String? error;
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Map<String, List<String>> groups(CatalogFilters data) {
    final result = <String, List<String>>{};
    for (final entry in data.platforms.entries) {
      final label = entry.value.toLowerCase();
      final group =
          label.contains('playstation') ||
              label.startsWith('psp') ||
              label.contains('vita')
          ? 'PlayStation'
          : label.contains('xbox')
          ? 'Xbox'
          : label.contains('nintendo') ||
                label.contains('wii') ||
                label.contains('game boy') ||
                label.contains('gamecube')
          ? 'Nintendo'
          : label.contains('android')
          ? 'Android'
          : label == 'ios'
          ? 'iOS'
          : label == 'pc' ||
                label.contains('windows') ||
                label.contains('linux') ||
                label.contains('mac')
          ? 'PC'
          : null;
      if (group != null) (result[group] ??= []).add(entry.key);
    }
    return {
      for (final key in [
        'PC',
        'PlayStation',
        'Xbox',
        'Nintendo',
        'Android',
        'iOS',
      ])
        key: result[key] ?? <String>[],
    };
  }

  Future<void> finish() async {
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await settings.saveSetup(
        name.text.trim().isEmpty ? 'Player' : name.text,
        genres,
        platforms,
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          error = 'Could not save preferences. Try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !widget.onboarding,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Gaming preferences'),
        automaticallyImplyLeading: !widget.onboarding,
        actions: [
          if (widget.onboarding)
            TextButton(
              onPressed: saving
                  ? null
                  : () async {
                      await settings.dismissOnboarding();
                      if (context.mounted) Navigator.pop(context);
                    },
              child: const Text('Skip for now'),
            ),
        ],
      ),
      body: WalletViewport(
        form: true,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 650),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    'STEP ${step + 1} OF 3',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: (step + 1) / 3,
                    borderRadius: WalletRadius.control,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    [
                      'What should we call you?',
                      'What do you love playing?',
                      'Where do you play?',
                    ][step],
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    [
                      'Your profile stays on this device.',
                      'Choose a few genres. We will prioritize these in recommendations.',
                      'Choose any platforms. Discovery will match any of your choices.',
                    ][step],
                  ),
                  const SizedBox(height: 24),
                  if (step == 0)
                    TextField(
                      controller: name,
                      maxLength: 40,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Display name',
                        hintText: 'Player',
                      ),
                    ),
                  if (step > 0)
                    FutureBuilder<CatalogFilters>(
                      future: metadata,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return EmptyState(
                            'Preferences unavailable',
                            'Your library is still available. Retry online or skip for now.',
                            retry: () => setState(
                              () => metadata = settings.loadPlatforms(),
                            ),
                          );
                        }
                        if (!snapshot.hasData) {
                          return const LinearProgressIndicator();
                        }
                        final data = snapshot.data!;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 10,
                              children: [
                                if (step == 1)
                                  for (final genre
                                      in data.genres.values.toSet())
                                    FilterChip(
                                      label: Text(genre),
                                      selected: genres.contains(genre),
                                      onSelected: (selected) => setState(() {
                                        selected
                                            ? genres.add(genre)
                                            : genres.remove(genre);
                                      }),
                                    ),
                                if (step == 2)
                                  for (final group in groups(data).entries)
                                    FilterChip(
                                      label: Text(group.key),
                                      selected: group.value.any(
                                        platforms.contains,
                                      ),
                                      onSelected: group.value.isEmpty
                                          ? null
                                          : (selected) => setState(() {
                                              platforms.removeWhere(
                                                group.value.contains,
                                              );
                                              if (selected) {
                                                platforms.addAll(group.value);
                                              }
                                            }),
                                    ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              step == 1
                                  ? (genres.isEmpty
                                        ? 'No genres selected means all interests.'
                                        : '${genres.length} genres selected')
                                  : (platforms.isEmpty
                                        ? 'No platforms selected means all platforms.'
                                        : '${platforms.length} devices selected'),
                            ),
                            if (step == 2 && platforms.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              ExpansionTile(
                                title: const Text('Choose specific devices'),
                                children: [
                                  Wrap(
                                    spacing: 6,
                                    children: [
                                      for (final p in data.platforms.entries)
                                        FilterChip(
                                          label: Text(p.value),
                                          selected: platforms.contains(p.key),
                                          onSelected: (v) => setState(() {
                                            v
                                                ? platforms.add(p.key)
                                                : platforms.remove(p.key);
                                          }),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  if (error != null) Notice(error!),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      if (step > 0) ...[
                        OutlinedButton(
                          onPressed: saving
                              ? null
                              : () => setState(() => step--),
                          child: const Text('Back'),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: FilledButton(
                          onPressed: saving
                              ? null
                              : step == 2
                              ? finish
                              : () {
                                  if (name.text.trim().length > 40) return;
                                  setState(() => step++);
                                },
                          child: Text(
                            saving
                                ? 'Saving...'
                                : step == 2
                                ? 'Finish'
                                : 'Continue',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'You can change these choices in Profile or Settings.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
