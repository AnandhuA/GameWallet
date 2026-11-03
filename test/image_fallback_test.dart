import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:game_atlas/core/image_cache_service.dart';
import 'package:game_atlas/core/models.dart';
import 'package:game_atlas/shared/cached_catalog_image.dart';
import 'package:game_atlas/shared/widgets.dart';
import 'package:game_atlas/features/details/game_image_gallery.dart';

class FakeImages extends ImageCacheService {
  final Map<String, Object> answers;
  final Map<String, Uint8List> cached;
  final List<String> requests = [];
  final List<String> discarded = [];
  FakeImages(this.answers, {Map<String, Uint8List> cached = const {}})
    : cached = Map.of(cached),
      super(null);
  @override
  Future<bool> discardCorrupt(String url, Uint8List rejectedBytes) async {
    final removed = await super.discardCorrupt(url, rejectedBytes);
    if (removed) {
      cached.remove(url);
      discarded.add(url);
    }
    return removed;
  }

  @override
  Uint8List? peek(String url) => cached[url];
  @override
  Future<Uint8List> load(String url) {
    requests.add(url);
    final answer = answers[url];
    if (answer is Uint8List) return Future.value(answer);
    if (answer is Completer<Uint8List>) return answer.future;
    return Future.error(StateError('Unavailable: $url'));
  }
}

Widget host(ImageCacheService cache, Widget child) =>
    ChangeNotifierProvider<ImageCacheService>.value(
      value: cache,
      child: MaterialApp(
        home: Scaffold(body: SizedBox(width: 400, height: 300, child: child)),
      ),
    );

Future<void> settleImages(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
}

void main() {
  final png = File('assets/art/1.png').readAsBytesSync();
  test('normalizes and preserves candidate order', () {
    expect(catalogImageSources([' ', null, ' a ', 'b', 'a', '', 'b']), [
      'a',
      'b',
    ]);
  });

  testWidgets(
    'tries ordered unique fallbacks, stops after success, does not retry on rebuild',
    (tester) async {
      final cache = FakeImages({'c': png});
      final unavailable = <String>[];
      Widget image() => CachedCatalogImage(
        ' a ',
        fallbackSources: const ['', 'b', 'a', 'c', 'd'],
        placeholder: const Text('placeholder'),
        onUnavailable: unavailable.add,
      );
      await tester.pumpWidget(host(cache, image()));
      await settleImages(tester);
      expect(cache.requests, ['a', 'b', 'c']);
      expect(unavailable, ['a', 'b']);
      expect(find.text('placeholder'), findsNothing);
      await tester.pumpWidget(host(cache, image()));
      await settleImages(tester);
      expect(cache.requests, ['a', 'b', 'c']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'decoding a corrupt cached image advances to the next candidate',
    (tester) async {
      final invalid = Uint8List.fromList([1, 2, 3]);
      final cache = FakeImages(
        {'bad': invalid, 'good': png},
        cached: {'bad': invalid},
      );
      await tester.pumpWidget(
        host(
          cache,
          const CachedCatalogImage(
            'bad',
            fallbackSources: ['good'],
            placeholder: Text('placeholder'),
          ),
        ),
      );
      await settleImages(tester);
      expect(cache.requests, ['bad', 'good']);
      expect(cache.discarded, ['bad']);
      expect(cache.cached.containsKey('bad'), false);
      expect(find.text('placeholder'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'empty list and complete failure keep the placeholder without looping',
    (tester) async {
      final cache = FakeImages({});
      await tester.pumpWidget(
        host(
          cache,
          const CachedCatalogImage(' ', placeholder: Text('placeholder')),
        ),
      );
      await settleImages(tester);
      expect(cache.requests, isEmpty);
      await tester.pumpWidget(
        host(
          cache,
          const CachedCatalogImage(
            'bad',
            fallbackSources: ['bad', 'also bad'],
            placeholder: Text('placeholder'),
          ),
        ),
      );
      await settleImages(tester);
      expect(cache.requests, ['bad', 'also bad']);
      expect(find.text('placeholder'), findsOneWidget);
      await tester.pump();
      expect(cache.requests.length, 2);
    },
  );

  testWidgets(
    'keeps placeholder while loading and ignores stale completion after candidate change',
    (tester) async {
      final pending = Completer<Uint8List>();
      final cache = FakeImages({'old': pending, 'new': png});
      await tester.pumpWidget(
        host(
          cache,
          const CachedCatalogImage('old', placeholder: Text('placeholder')),
        ),
      );
      expect(find.text('placeholder'), findsOneWidget);
      await tester.pumpWidget(
        host(
          cache,
          const CachedCatalogImage('new', placeholder: Text('placeholder')),
        ),
      );
      pending.completeError(StateError('old request failed'));
      await settleImages(tester);
      expect(cache.requests, ['old', 'new']);
      expect(find.text('placeholder'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'resets when fallback list changes and ignores failures after disposal',
    (tester) async {
      final pending = Completer<Uint8List>();
      final cache = FakeImages({'pending': pending, 'good': png});
      await tester.pumpWidget(
        host(
          cache,
          const CachedCatalogImage('bad', placeholder: Text('placeholder')),
        ),
      );
      await settleImages(tester);
      await tester.pumpWidget(
        host(
          cache,
          const CachedCatalogImage(
            'bad',
            fallbackSources: ['good'],
            placeholder: Text('placeholder'),
          ),
        ),
      );
      await settleImages(tester);
      expect(cache.requests, ['bad', 'bad', 'good']);
      await tester.pumpWidget(
        host(
          cache,
          const CachedCatalogImage('pending', placeholder: Text('placeholder')),
        ),
      );
      await tester.pumpWidget(const SizedBox());
      pending.completeError(StateError('disposed'));
      await settleImages(tester);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets("a different game never keeps another game's selected fallback", (
    tester,
  ) async {
    final cache = FakeImages({'first-shot': png, 'second-shot': png});
    const first = Game(
      id: 101,
      title: 'First',
      cover: 'first-bad',
      screenshots: ['first-shot'],
    );
    const second = Game(
      id: 102,
      title: 'Second',
      cover: 'second-bad',
      screenshots: ['second-shot'],
    );
    await tester.pumpWidget(host(cache, const GameArt(first)));
    await settleImages(tester);
    await tester.pumpWidget(host(cache, const GameArt(second)));
    await settleImages(tester);
    expect(cache.requests, [
      'first-bad',
      'first-shot',
      'second-bad',
      'second-shot',
    ]);
    final image = tester.widget<CachedCatalogImage>(
      find.byType(CachedCatalogImage),
    );
    expect(image.source, 'second-bad');
    expect(image.fallbackSources, ['second-shot']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cover and header follow their respective orders', (
    tester,
  ) async {
    final cache = FakeImages({'screenshot': png});
    const game = Game(
      id: 1,
      title: 'Fixture',
      cover: 'cover',
      artwork: 'artwork',
      screenshots: ['screenshot'],
    );
    await tester.pumpWidget(host(cache, const GameArt(game)));
    await settleImages(tester);
    expect(cache.requests, ['cover', 'artwork', 'screenshot']);
    cache.requests.clear();
    await tester.pumpWidget(host(cache, const GameArt(game, wide: true)));
    await settleImages(tester);
    expect(cache.requests, ['artwork', 'cover', 'screenshot']);
  });

  testWidgets(
    'gallery hides failures, viewer shares exclusions, reopening retries',
    (tester) async {
      final cache = FakeImages({'good': png});
      Widget gallery(Key key) =>
          GameImageGallery(key: key, sources: const ['bad', 'good']);
      await tester.pumpWidget(host(cache, gallery(const ValueKey('first'))));
      await settleImages(tester);
      expect(find.byType(CatalogImage), findsOneWidget);
      await tester.tap(find.byType(CatalogImage));
      await tester.pumpAndSettle();
      expect(find.text('1 / 1'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pumpWidget(host(cache, gallery(const ValueKey('second'))));
      await settleImages(tester);
      expect(cache.requests.where((r) => r == 'bad').length, 2);
    },
  );

  testWidgets(
    'viewer preserves selection, advances after current removal, handles all failed',
    (tester) async {
      final cache = FakeImages({
        for (final source in ['a', 'b', 'c']) source: Completer<Uint8List>(),
      });
      final session = GameImageSession(['a', 'b', 'c']);
      await tester.pumpWidget(
        host(cache, ScreenshotViewer(session: session, initialSource: 'b')),
      );
      expect(find.text('2 / 3'), findsOneWidget);
      session.reject('a');
      await tester.pump();
      expect(find.text('1 / 2'), findsOneWidget);
      expect(
        tester.widget<PageView>(find.byType(PageView)).controller!.initialPage,
        0,
      );
      session.reject('b');
      await tester.pump();
      expect(find.text('1 / 1'), findsOneWidget);
      session.reject('c');
      await tester.pump();
      expect(find.text('No images available'), findsOneWidget);
      expect(find.byType(PageView), findsNothing);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'fullscreen skips a failed current image and keeps its counter aligned',
    (tester) async {
      final cache = FakeImages({'a': png, 'c': png});
      final session = GameImageSession(['a', 'bad', 'c']);
      await tester.pumpWidget(
        host(cache, ScreenshotViewer(session: session, initialSource: 'bad')),
      );
      await settleImages(tester);
      expect(session.images, ['a', 'c']);
      expect(find.text('2 / 2'), findsOneWidget);
      final page = tester.widget<PageView>(find.byType(PageView));
      expect(page.controller!.page, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );

  testWidgets('gallery shows an empty state when every image fails', (
    tester,
  ) async {
    final cache = FakeImages({});
    await tester.pumpWidget(
      host(cache, const GameImageGallery(sources: ['bad', 'other'])),
    );
    await settleImages(tester);
    expect(find.text('No images available'), findsOneWidget);
    expect(find.byType(CatalogImage), findsNothing);
  });
}
