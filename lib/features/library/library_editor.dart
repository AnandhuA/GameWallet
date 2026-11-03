import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models.dart';
import '../journal/journal_pages.dart';
import 'library_provider.dart';

Future<void> editLibrary(BuildContext context, Game game) => showDialog<void>(
  context: context,
  builder: (_) => LibraryEditor(game: game),
);

class LibraryEditor extends StatefulWidget {
  final Game game;
  const LibraryEditor({super.key, required this.game});
  @override
  State<LibraryEditor> createState() => _LibraryEditorState();
}

class _LibraryEditorState extends State<LibraryEditor> {
  late final old = context.read<LibraryProvider>().entry(widget.game);
  late LibraryStatus? status = old == null
      ? LibraryStatus.wantToPlay
      : old!.status;
  late bool favorite = old?.favorite ?? false;
  bool saving = false;
  String? error;
  Future<void> save({bool remove = false}) async {
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final library = context.read<LibraryProvider>();
      if (remove) {
        await library.remove(widget.game);
      } else if (status == LibraryStatus.completed &&
          old?.status != LibraryStatus.completed) {
        final accepted = await completeGame(
          context,
          widget.game,
          favorite: favorite,
        );
        if (!accepted) {
          if (mounted) {
            setState(() => saving = false);
          }
          return;
        }
      } else {
        await library.updateLibrary(
          widget.game,
          status: status,
          favorite: favorite,
        );
      }
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          error = 'Could not save. Try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.game.title),
    content: SizedBox(
      width: 430,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<LibraryStatus>(
              initialValue: status,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Library status'),
              items: [
                const DropdownMenuItem(value: null, child: Text('No status')),
                ...LibraryStatus.values.map(
                  (s) => DropdownMenuItem(value: s, child: Text(s.label)),
                ),
              ],
              onChanged: saving ? null : (v) => setState(() => status = v),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: favorite,
              onChanged: saving ? null : (v) => setState(() => favorite = v!),
              title: const Text('Favorite'),
            ),
            TextButton.icon(
              onPressed: saving
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => JournalPage(game: widget.game),
                      ),
                    ),
              icon: const Icon(Icons.edit_note),
              label: const Text('Review & notes'),
            ),
            if (error != null) Text(error!),
          ],
        ),
      ),
    ),
    actions: [
      if (old != null)
        TextButton(
          onPressed: saving ? null : () => save(remove: true),
          child: const Text('Remove'),
        ),
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: saving ? null : save,
        child: Text(saving ? 'Saving…' : 'Save'),
      ),
    ],
  );
}
