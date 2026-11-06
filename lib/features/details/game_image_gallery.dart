import '../../shared/app_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../shared/cached_catalog_image.dart';
import '../../shared/widgets.dart';

/// A detail-page session, shared with its full-screen viewer, never persisted.
class GameImageSession extends ChangeNotifier {
  List<String> _sources;
  final Set<String> _failed = {};
  bool _disposed = false;
  GameImageSession(Iterable<String> sources)
    : _sources = catalogImageSources(sources);
  List<String> get images =>
      _sources.where((s) => !_failed.contains(s)).toList(growable: false);

  void replaceSources(Iterable<String> sources) {
    final next = catalogImageSources(sources);
    if (listEquals(next, _sources) || _disposed) return;
    _sources = next;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) notifyListeners();
    });
  }

  void reject(String source) {
    if (!_disposed && _sources.contains(source) && _failed.add(source)) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class GameImageGallery extends StatefulWidget {
  final List<String> sources;
  const GameImageGallery({super.key, required this.sources});
  @override
  State<GameImageGallery> createState() => _GameImageGalleryState();
}

class _GameImageGalleryState extends State<GameImageGallery> {
  late final session = GameImageSession(widget.sources);
  @override
  void didUpdateWidget(covariant GameImageGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    session.replaceSources(widget.sources);
  }

  @override
  void dispose() {
    session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: session,
    builder: (context, _) {
      final images = session.images;
      if (images.isEmpty) return const Text('No images available');
      return SizedBox(
        height: 180,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: images.length,
          separatorBuilder: (_, i) => const SizedBox(width: 12),
          itemBuilder: (_, i) => SizedBox(
            key: ValueKey(images[i]),
            width: 250,
            child: ClipRRect(
              borderRadius: WalletRadius.row,
              child: Material(
                child: InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => ScreenshotViewer(
                        session: session,
                        initialSource: images[i],
                      ),
                    ),
                  ),
                  child: CatalogImage(
                    images[i],
                    fit: BoxFit.cover,
                    onUnavailable: session.reject,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class ScreenshotViewer extends StatefulWidget {
  final GameImageSession session;
  final String initialSource;
  const ScreenshotViewer({
    super.key,
    required this.session,
    required this.initialSource,
  });
  @override
  State<ScreenshotViewer> createState() => _ScreenshotViewerState();
}

class _ScreenshotViewerState extends State<ScreenshotViewer> {
  late List<String> images;
  late PageController controller;
  int current = 0;
  final List<PageController> _retired = [];

  @override
  void initState() {
    super.initState();
    images = widget.session.images;
    final selected = images.indexOf(widget.initialSource);
    current = selected < 0 ? 0 : selected;
    controller = PageController(initialPage: current);
    widget.session.addListener(_updateImages);
  }

  void _updateImages() {
    if (!mounted) return;
    final selected = images.isNotEmpty ? images[current] : null;
    final next = widget.session.images;
    if (listEquals(images, next)) return;
    final preserved = selected == null ? -1 : next.indexOf(selected);
    final index = next.isEmpty
        ? 0
        : preserved >= 0
        ? preserved
        : current.clamp(0, next.length - 1);
    final oldController = controller;
    _retired.add(oldController);
    setState(() {
      images = next;
      current = index;
      controller = PageController(initialPage: current);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_retired.remove(oldController)) oldController.dispose();
    });
  }

  @override
  void dispose() {
    widget.session.removeListener(_updateImages);
    controller.dispose();
    for (final retired in _retired) {
      retired.dispose();
    }
    _retired.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Game images')),
    body: images.isEmpty
        ? const Center(child: Text('No images available'))
        : Column(
            children: [
              Expanded(
                child: Builder(
                  builder: (context) {
                    final activeController = controller;
                    return PageView.builder(
                      key: ObjectKey(activeController),
                      controller: activeController,
                      itemCount: images.length,
                      onPageChanged: (value) {
                        if (mounted &&
                            identical(activeController, controller) &&
                            value < images.length) {
                          setState(() => current = value);
                        }
                      },
                      itemBuilder: (_, i) => InteractiveViewer(
                        key: ValueKey(images[i]),
                        child: CatalogImage(
                          images[i],
                          onUnavailable: widget.session.reject,
                        ),
                      ),
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Previous screenshot',
                    onPressed: current == 0
                        ? null
                        : () => controller.previousPage(
                            duration: WalletTokens.motion(context),
                            curve: Curves.easeOut,
                          ),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text('${current + 1} / ${images.length}'),
                  IconButton(
                    tooltip: 'Next screenshot',
                    onPressed: current >= images.length - 1
                        ? null
                        : () => controller.nextPage(
                            duration: WalletTokens.motion(context),
                            curve: Curves.easeOut,
                          ),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ],
          ),
  );
}
