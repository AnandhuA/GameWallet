import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../shared/widgets.dart';
import 'settings_provider.dart';

class RawgKeyForm extends StatefulWidget {
  const RawgKeyForm({super.key});
  @override
  State<RawgKeyForm> createState() => _RawgKeyFormState();
}

class _RawgKeyFormState extends State<RawgKeyForm> {
  final controller = TextEditingController();
  bool saving = false;
  String? error;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> connect() async {
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await context.read<SettingsProvider>().saveApiKey(controller.text);
      controller.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connected to RAWG. Real games are now enabled.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString());
      }
    }
    if (mounted) {
      setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final connected = context.select<SettingsProvider, bool>(
      (p) => p.hasApiKey,
    );
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              connected ? 'RAWG key configured' : 'Connect real games',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Get a free personal API key from RAWG, paste it here, and connect. The app talks directly to RAWG—no server to run.',
            ),
            TextButton.icon(
              onPressed: () => openExternal(context, 'https://rawg.io/apidocs'),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Get a RAWG API key'),
            ),
            TextField(
              controller: controller,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              enabled: !saving,
              decoration: InputDecoration(
                labelText: connected ? 'Replace RAWG API key' : 'RAWG API key',
                errorText: error,
                errorMaxLines: 4,
              ),
              onSubmitted: (_) => saving ? null : connect(),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: saving ? null : connect,
              icon: Icon(connected ? Icons.refresh : Icons.link),
              label: Text(
                saving ? 'Checking key…' : 'Connect & load real games',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
