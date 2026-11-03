import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/image_cache_service.dart';

class CachedCatalogImage extends StatefulWidget {
  final String source;
  final BoxFit fit;
  final Widget placeholder;
  const CachedCatalogImage(
    this.source, {
    super.key,
    this.fit = BoxFit.cover,
    required this.placeholder,
  });
  @override
  State<CachedCatalogImage> createState() => _CachedCatalogImageState();
}

class _CachedCatalogImageState extends State<CachedCatalogImage> {
  Future<Uint8List>? future;
  ImageCacheService? service;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = context.read<ImageCacheService?>();
    if (service != next || future == null) {
      service = next;
      _load();
    }
  }

  void _load() {
    future = service?.load(widget.source);
  }

  @override
  void didUpdateWidget(covariant CachedCatalogImage old) {
    super.didUpdateWidget(old);
    if (old.source != widget.source) _load();
  }

  @override
  Widget build(BuildContext context) {
    if (service == null) {
      return Image.network(
        widget.source,
        fit: widget.fit,
        errorBuilder: (_, e, s) => widget.placeholder,
      );
    }
    return FutureBuilder<Uint8List>(
      key: ValueKey(widget.source),
      future: future,
      initialData: service!.peek(widget.source),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Image.memory(
            snapshot.data!,
            fit: widget.fit,
            gaplessPlayback: true,
            errorBuilder: (_, e, s) => widget.placeholder,
          );
        }
        if (kIsWeb && snapshot.hasError) {
          return Image.network(
            widget.source,
            fit: widget.fit,
            webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
            errorBuilder: (_, e, s) => widget.placeholder,
          );
        }
        return widget.placeholder;
      },
    );
  }
}
