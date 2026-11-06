import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models.dart';
import '../../shared/cached_catalog_image.dart';
import '../settings/settings_provider.dart';
import 'deal_record.dart';
import 'deals_catalog_provider.dart';
import 'deals_provider.dart';

class DealCover extends StatefulWidget {
  final DealRecord record;
  final Game? game;
  final bool wide;
  const DealCover(this.record, {super.key, this.game, this.wide = false});
  @override
  State<DealCover> createState() => _DealCoverState();
}

class _DealCoverState extends State<DealCover> {
  String? attempted;
  bool loading = false;
  int seenRevision = 0;
  final Set<String> failed = {};
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  @override
  void didUpdateWidget(covariant DealCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.record.key != widget.record.key) failed.clear();
    _load();
  }

  void _load({bool steamFailed = false}) {
    final settings = context.read<SettingsProvider?>();
    final revision = context.read<DealsProvider?>()?.artworkRevision ?? 0;
    if (revision != seenRevision) {
      failed.clear();
      seenRevision = revision;
    }
    final attemptKey =
        '${widget.record.key}:${settings?.connectionRevision}:precise-v1:$revision';
    final catalog = context.read<DealsCatalogProvider?>();
    if (catalog == null ||
        attempted == attemptKey ||
        widget.game != null ||
        (widget.record.coverSources.isNotEmpty && !steamFailed) ||
        !((settings?.hasApiKey ?? false) || catalog.supportsKeyless)) {
      return;
    }
    attempted = attemptKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && attempted == attemptKey) {
        setState(() => loading = true);
        catalog
            .lookup(widget.record, refresh: revision > 0)
            .then<void>(
              (_) {
                if (mounted) setState(() => loading = false);
              },
              onError: (Object error, StackTrace stack) {
                if (mounted) setState(() => loading = false);
              },
            );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    context.watch<SettingsProvider?>();
    final revision = context.watch<DealsProvider?>()?.artworkRevision ?? 0;
    final catalog = context.watch<DealsCatalogProvider?>();
    final game = widget.game ?? catalog?.coverGame(widget.record);
    final placeholder = ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Center(
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Tooltip(
                message:
                    'No verified cover available. Open details to check matching games.',
                child: Icon(
                  Icons.videogame_asset_outlined,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
      ),
    );
    final sources = catalogImageSources([
      if (game != null) ...[
        if (widget.wide) game.artwork,
        game.cover,
        if (!widget.wide) game.artwork,
        ...game.screenshots,
        ...game.fallbackImages,
      ],
      ...(widget.wide
          ? widget.record.coverSources.reversed
          : widget.record.coverSources),
    ]);
    return Semantics(
      label: '${widget.record.title} artwork',
      image: true,
      child: sources.isEmpty
          ? placeholder
          : CachedCatalogImage(
              sources.first,
              key: ValueKey('${widget.record.key}:$revision'),
              fallbackSources: sources.skip(1).toList(),
              placeholder: placeholder,
              onUnavailable: (source) {
                failed.add(source);
                if (mounted &&
                    game == null &&
                    widget.record.coverSources.isNotEmpty &&
                    widget.record.coverSources.every(failed.contains)) {
                  _load(steamFailed: true);
                }
              },
            ),
    );
  }
}
