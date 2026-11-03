import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/image_cache_service.dart';

/// Keep catalog order while ignoring blank and repeated image sources.
List<String> catalogImageSources(Iterable<String?> sources) => <String>{
  for (final source in sources)
    if (source != null && source.trim().isNotEmpty) source.trim(),
}.toList(growable: false);

class CachedCatalogImage extends StatefulWidget {
  final String source;
  final List<String> fallbackSources;
  final BoxFit fit;
  final Widget placeholder;
  final ValueChanged<String>? onUnavailable;
  const CachedCatalogImage(
    this.source, {
    super.key,
    this.fallbackSources = const [],
    this.fit = BoxFit.cover,
    required this.placeholder,
    this.onUnavailable,
  });
  @override
  State<CachedCatalogImage> createState() => _CachedCatalogImageState();
}

class _CachedCatalogImageState extends State<CachedCatalogImage> {
  late List<String> sources;
  int index = 0, generation = 0;
  bool failureScheduled = false;
  final Set<String> corruptionScheduled = {};
  Future<Uint8List>? future;
  ImageCacheService? service;

  @override
  void initState() {
    super.initState();
    sources = catalogImageSources([widget.source, ...widget.fallbackSources]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = context.read<ImageCacheService?>();
    if (service != next) {
      service = next;
      _reset(sources);
    }
  }

  void _reset(List<String> next) {
    generation++;
    sources = next;
    index = 0;
    failureScheduled = false;
    corruptionScheduled.clear();
    _load();
  }

  void _load() {
    future = index < sources.length ? service?.load(sources[index]) : null;
    // A fallback request may fail before the next frame subscribes to it.
    // Observe failures immediately; FutureBuilder still receives the error.
    future?.then<void>((_) {}, onError: (Object error, StackTrace stack) {});
  }

  @override
  void didUpdateWidget(covariant CachedCatalogImage old) {
    super.didUpdateWidget(old);
    final next = catalogImageSources([
      widget.source,
      ...widget.fallbackSources,
    ]);
    if (!listEquals(sources, next)) _reset(next);
  }

  Widget _failed(int attempt, String source) {
    if (!failureScheduled && generation == attempt) {
      failureScheduled = true;
      // Image error builders and FutureBuilder builders run during build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            generation != attempt ||
            index >= sources.length ||
            sources[index] != source) {
          return;
        }
        setState(() {
          index++;
          generation++;
          failureScheduled = false;
          _load();
        });
        widget.onUnavailable?.call(source);
      });
    }
    return widget.placeholder;
  }

  Widget _network(int attempt, String source, {bool webFallback = false}) {
    return Image.network(
      source,
      key: ValueKey('network:$attempt:$source'),
      fit: widget.fit,
      webHtmlElementStrategy: webFallback
          ? WebHtmlElementStrategy.fallback
          : WebHtmlElementStrategy.never,
      frameBuilder: (_, child, frame, synchronous) =>
          synchronous || frame != null ? child : widget.placeholder,
      errorBuilder: (_, error, stack) => _failed(attempt, source),
    );
  }

  Widget _rejected(int attempt, String source, {Uint8List? rejectedBytes}) {
    final cache = service;
    if (rejectedBytes != null &&
        cache != null &&
        generation == attempt &&
        corruptionScheduled.add(source)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || generation != attempt || service != cache) return;
        unawaited(
          cache
              .discardCorrupt(source, rejectedBytes)
              .then<void>((_) {}, onError: (Object error, StackTrace stack) {}),
        );
      });
    }
    return kIsWeb
        ? _network(attempt, source, webFallback: true)
        : _failed(attempt, source);
  }

  @override
  Widget build(BuildContext context) {
    if (index >= sources.length) return widget.placeholder;
    final source = sources[index];
    final attempt = generation;
    if (source.startsWith('assets/art/')) {
      return Image.asset(
        source,
        fit: widget.fit,
        frameBuilder: (_, child, frame, synchronous) =>
            synchronous || frame != null ? child : widget.placeholder,
        errorBuilder: (_, error, stack) => _failed(attempt, source),
      );
    }
    if (service == null) return _network(attempt, source, webFallback: kIsWeb);
    return FutureBuilder<Uint8List>(
      key: ValueKey('$attempt:$source'),
      future: future,
      initialData: service!.peek(source),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Image.memory(
            snapshot.data!,
            key: ValueKey('$attempt:$source'),
            fit: widget.fit,
            frameBuilder: (_, child, frame, synchronous) =>
                synchronous || frame != null ? child : widget.placeholder,
            errorBuilder: (_, error, stack) =>
                _rejected(attempt, source, rejectedBytes: snapshot.data!),
          );
        }
        if (snapshot.hasError) return _rejected(attempt, source);
        return widget.placeholder;
      },
    );
  }
}
