import '../../shared/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models.dart';
import '../../shared/widgets.dart';
import 'rawg_key_form.dart';
import 'preferences_page.dart';
import 'settings_provider.dart';
import 'cache_settings_panel.dart';

const accentColors = <String, int>{
  'Default teal': 0xFF5CD0C6,
  'Cyan': 0xFF06B6D4,
  'Blue': 0xFF3B82F6,
  'Violet': 0xFF8B5CF6,
  'Green': 0xFF1DB954,
  'Amber': 0xFFFFB020,
  'Pink': 0xFFEC4899,
  'Teal': 0xFF009688,
  'Mint': 0xFF34D399,
  'Lime': 0xFF84CC16,
  'Lemon': 0xFFFACC15,
  'Orange': 0xFFF97316,
  'Coral': 0xFFFF7F50,
  'Red': 0xFFEF4444,
  'Rose': 0xFFF43F5E,
  'Indigo': 0xFF6366F1,
  'Lavender': 0xFFA78BFA,
  'Magenta': 0xFFD946EF,
  'Slate': 0xFF64748B,
};

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Future<CatalogFilters>? metadata;
  String? source;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = context.watch<SettingsProvider>();
    final configuration = '${settings.demo}:${settings.connectionRevision}';
    if (configuration != source) {
      source = configuration;
      metadata = context.read<SettingsProvider>().loadPlatforms();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<SettingsProvider>();
    return WalletViewport(
      form: true,
      child: ListView(
        padding: const EdgeInsets.all(WalletSpace.page),
        children: [
          Text(
            'Make it yours.',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 24),
          Text('Appearance', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Text(
            'Accent color · ${accentColors.entries.where((e) => e.value == p.accentColor.toARGB32()).firstOrNull?.key ?? 'Custom'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in accentColors.entries)
                IconButton.filled(
                  tooltip: entry.key,
                  isSelected: p.accentColor.toARGB32() == entry.value,
                  style: IconButton.styleFrom(
                    backgroundColor: Color(entry.value),
                    foregroundColor:
                        Color(entry.value).computeLuminance() > .179
                        ? Colors.black
                        : Colors.white,
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: () =>
                      guarded(context, () => p.setAccentColor(entry.value)),
                  selectedIcon: const Icon(Icons.check),
                  icon: const Icon(Icons.circle_outlined, size: 20),
                ),
            ],
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.tune),
            title: const Text('Gaming preferences'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const PreferencesPage()),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in ThemeMode.values)
                ChoiceChip(
                  label: Text(t.name),
                  selected: p.theme == t && !p.amoled,
                  onSelected: (_) => guarded(context, () => p.setTheme(t)),
                ),
              ChoiceChip(
                tooltip: 'AMOLED dark theme with pure black backgrounds',
                label: const Text('Pure black'),
                selected: p.amoled,
                onSelected: (_) => guarded(context, () => p.setAmoled(true)),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text('Data source', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          const RawgKeyForm(),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Demo mode'),
            subtitle: const Text(
              'Fictional samples for review. Save a RAWG key above to switch to real games automatically.',
            ),
            value: p.demo,
            onChanged: (v) => guarded(context, () => p.setDemo(v)),
          ),
          if (!p.demo)
            const Notice(
              'Live catalogs use RAWG and FreeToGame. FreeToGame adds free PC/browser games; console and mobile coverage uses RAWG. No backend is required.',
            ),
          const SizedBox(height: 20),
          Text(
            'Preferred platforms',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Discovery matches any selected platform. Explore lets you choose other platforms without changing these preferences.',
          ),
          const SizedBox(height: 12),
          FutureBuilder<CatalogFilters>(
            future: metadata,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return EmptyState(
                  'Platform options unavailable',
                  'Check your RAWG key and internet connection.',
                  retry: () => setState(() => metadata = p.loadPlatforms()),
                );
              }
              if (!snapshot.hasData) {
                return const LinearProgressIndicator();
              }
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: snapshot.data!.platforms.entries
                    .map(
                      (entry) => FilterChip(
                        label: Text(entry.value),
                        selected: p.platforms.contains(entry.key),
                        onSelected: (selected) {
                          final values = [...p.platforms];
                          if (selected) {
                            values.add(entry.key);
                          } else {
                            values.remove(entry.key);
                          }
                          guarded(context, () => p.setPlatforms(values));
                        },
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 28),
          const CacheSettingsPanel(),
          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 16),
          Text(
            'About Game Wallet',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const RawgAttribution(),
          const SizedBox(height: 8),
          const Text(
            'Find your next world.\n\nGame data and images provided by RAWG. Original IGDB library snapshots remain on this device with their notes. Game information and artwork belong to their respective owners.\n\nRAWG free access is for personal/non-commercial projects and has request limits. API keys in a client app can be extracted; use your own key. No Twitch secrets are used.\n\nDemo games and abstract artwork are fictional review assets. Clearing app/browser storage removes local saves and the locally configured key.',
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
