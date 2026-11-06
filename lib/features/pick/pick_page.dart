import '../../shared/app_theme.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models.dart';
import '../../shared/widgets.dart';
import '../home/home_page.dart';
import '../home/home_provider.dart';
import '../library/library_provider.dart';
import '../settings/settings_provider.dart';
import '../companion/companion_providers.dart';
import '../companion/game_selector.dart';

class PickPage extends StatefulWidget {
  final VoidCallback onExplore;
  final List<Game>? initialCandidates;
  const PickPage({super.key, required this.onExplore, this.initialCandidates});
  @override
  State<PickPage> createState() => _PickPageState();
}

class _PickPageState extends State<PickPage>
    with SingleTickerProviderStateMixin {
  late final controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );
  Animation<double> rotation = const AlwaysStoppedAnimation(0);
  double angle = 0;
  bool skipFinished = true;
  String source = 'discovery';
  bool? seededDemo;
  bool sourceSeeded = false;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  List<Game> filtered(Iterable<Game> games) {
    final library = context.read<LibraryProvider>();
    final hidden = context.read<DiscoveryPreferencesProvider>();
    final settings = context.read<SettingsProvider>();
    final demo = settings.demo;
    final filters = context.read<HomeProvider>().filters;
    final pool = games
        .where(
          (g) => source != 'discovery' || settings.matchesPlatforms(g, filters),
        )
        .toList();
    return smartCandidates(
          pool,
          library,
          hidden,
          unfinished: false,
          preferredGenres: settings.genres,
        )
        .where(
          (g) =>
              g.demo == demo &&
              !hidden.hidden(g) &&
              (!skipFinished ||
                  ![
                    LibraryStatus.completed,
                    LibraryStatus.dropped,
                  ].contains(library.entry(g)?.status)),
        )
        .toList();
  }

  void apply() {
    final library = context.read<LibraryProvider>();
    final demo = context.read<SettingsProvider>().demo;
    Iterable<Game> pool = context.read<HomeProvider>().sections.values.expand(
      (g) => g,
    );
    if (source == 'want') {
      pool = library
          .entries(demo)
          .where((e) => e.status == LibraryStatus.wantToPlay)
          .map((e) => e.game);
    } else if (source == 'favorites') {
      pool = library.entries(demo).where((e) => e.favorite).map((e) => e.game);
    }
    context.read<WheelProvider>().replace(filtered(pool));
  }

  Future<void> spin() async {
    final wheel = context.read<WheelProvider>();
    wheel.replace(filtered(wheel.candidates));
    if (!wheel.begin()) {
      return;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      angle = wheel.targetAngle;
      rotation = AlwaysStoppedAnimation(angle);
      wheel.finish();
      return;
    }
    rotation = Tween<double>(
      begin: angle,
      end: wheel.targetAngle,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOutCubic));
    controller.reset();
    try {
      await controller.forward().orCancel;
      if (mounted) {
        angle = wheel.targetAngle;
        wheel.finish();
      }
    } catch (_) {
      if (mounted) {
        wheel.finish();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final wheel = context.watch<WheelProvider>();
    final home = context.watch<HomeProvider>();
    final demo = context.watch<SettingsProvider>().demo;
    context.watch<DiscoveryPreferencesProvider>();
    if (seededDemo != demo) {
      seededDemo = demo;
      sourceSeeded = widget.initialCandidates != null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !context.read<WheelProvider>().spinning) {
          context.read<WheelProvider>().replace(
            filtered(widget.initialCandidates ?? []),
          );
        }
      });
    }
    if (!wheel.spinning && !sourceSeeded && home.sections.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !context.read<WheelProvider>().spinning) {
          sourceSeeded = true;
          source = 'discovery';
          apply();
        }
      });
    }
    final sources = {
      'discovery': 'Discovery',
      'want': 'Want to Play',
      'favorites': 'Favorites',
    };
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Random Pick', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        if (wheel.winner != null) ...[
          FeatureGameCard(wheel.winner!),
          const SizedBox(height: 16),
        ],
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: AspectRatio(
              aspectRatio: 1,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: controller,
                    builder: (_, child) =>
                        Transform.rotate(angle: rotation.value, child: child),
                    child: RepaintBoundary(
                      child: ArtworkWheel(
                        games: wheel.spinning ? wheel.frozen : wheel.candidates,
                        accent: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const Align(
                    alignment: Alignment.topCenter,
                    child: Icon(
                      Icons.arrow_drop_down,
                      size: 44,
                      color: Colors.white,
                    ),
                  ),
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    child: Icon(
                      Icons.sports_esports,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: wheel.spinning || wheel.candidates.isEmpty ? null : spin,
          icon: const Icon(Icons.rotate_right),
          label: Text(wheel.spinning ? 'Spinning…' : 'Spin'),
        ),
        const SizedBox(height: 18),
        DropdownButtonFormField<String>(
          key: ValueKey(source),
          initialValue: sources.containsKey(source) ? source : 'discovery',
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Candidate source'),
          items: sources.entries
              .map(
                (e) => DropdownMenuItem(
                  value: e.key,
                  child: Text(e.value, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: wheel.spinning
              ? null
              : (v) {
                  setState(() => source = v!);
                  apply();
                },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: skipFinished,
          onChanged: wheel.spinning
              ? null
              : (v) {
                  setState(() => skipFinished = v);
                  apply();
                },
          title: const Text('Keep it fresh'),
          subtitle: const Text('Exclude completed, dropped, and hidden games'),
        ),
        Wrap(
          spacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: wheel.spinning
                  ? null
                  : () async {
                      final game = await selectGame(context);
                      if (game != null && context.mounted) {
                        context.read<WheelProvider>().replace(
                          filtered([...wheel.candidates, game]),
                        );
                      }
                    },
              icon: const Icon(Icons.add),
              label: const Text('Add candidate'),
            ),
            TextButton(
              onPressed: wheel.spinning ? null : apply,
              child: const Text('Reload source'),
            ),
          ],
        ),
        Text(
          '${wheel.candidates.length} candidates · maximum 12',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        for (final g in wheel.candidates)
          ListTile(
            leading: SizedBox(width: 36, height: 48, child: GameArt(g)),
            title: Text(g.title),
            trailing: IconButton(
              tooltip: 'Remove ${g.title}',
              onPressed: wheel.spinning ? null : () => wheel.remove(g),
              icon: const Icon(Icons.close),
            ),
          ),
        if (home.loading) const LinearProgressIndicator(),
        if (home.error != null) Notice(home.error!),
        if (wheel.candidates.isEmpty && !home.loading)
          const EmptyState(
            'No eligible games',
            'Choose another source, add candidates, or turn off Keep it fresh.',
          ),
        TextButton(
          onPressed: widget.onExplore,
          child: const Text('Explore games'),
        ),
      ],
    );
  }
}

class WheelPainter extends CustomPainter {
  final List<Game> games;
  final Color accent;
  final bool artworkBehind;
  WheelPainter(this.games, this.accent, {this.artworkBehind = false});
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 8;
    final rect = Rect.fromCircle(center: center, radius: radius);
    if (games.isEmpty) {
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = accent.withValues(alpha: .16),
      );
      return;
    }
    final segment = 2 * pi / games.length;
    for (var i = 0; i < games.length; i++) {
      final start = -pi / 2 + i * segment;
      if (!artworkBehind) {
        canvas.drawArc(
          rect,
          start,
          segment,
          true,
          Paint()
            ..color = Color.lerp(
              accent,
              const WalletTokens().artworkBase,
              (i % 3) * .3,
            )!,
        );
      }
      canvas.drawArc(
        rect,
        start,
        segment,
        true,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = Colors.white24
          ..strokeWidth = 1,
      );
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(start + segment / 2);
      final title = games[i].title;
      final text = TextPainter(
        text: TextSpan(
          text: title.length > 21 ? '${title.substring(0, 19)}…' : title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            shadows: [Shadow(color: Colors.black, blurRadius: 4)],
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 2,
      )..layout(maxWidth: radius * .58);
      text.paint(canvas, Offset(radius * .35, -text.height / 2));
      text.dispose();
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant WheelPainter old) =>
      old.games != games ||
      old.accent != accent ||
      old.artworkBehind != artworkBehind;
}

/// Images are clipped with the same start angle and segment order as the painter.
/// The whole wheel rotates as one cached layer; candidates remain frozen in a spin.
class ArtworkWheel extends StatelessWidget {
  final List<Game> games;
  final Color accent;
  const ArtworkWheel({super.key, required this.games, required this.accent});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final radius = min(box.maxWidth, box.maxHeight) / 2 - 8;
      final segment = games.isEmpty ? 0.0 : 2 * pi / games.length;
      return Stack(
        fit: StackFit.expand,
        children: [
          for (var i = 0; i < games.length; i++)
            ClipPath(
              clipper: _WheelSlice(i, games.length),
              child: ExcludeSemantics(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(color: accent),
                    if (games.length == 1)
                      GameArt(games[i])
                    else
                      Transform.rotate(
                        angle: (i + .5) * segment,
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: SizedBox(
                            width: 2 * radius * sin(min(segment, pi) / 2) + 16,
                            height: radius + 16,
                            child: GameArt(games[i]),
                          ),
                        ),
                      ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            Colors.black.withValues(alpha: .7),
                            Colors.black.withValues(alpha: .22),
                          ],
                          stops: const [.15, 1],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          IgnorePointer(
            child: CustomPaint(
              painter: WheelPainter(games, accent, artworkBehind: true),
            ),
          ),
        ],
      );
    },
  );
}

class _WheelSlice extends CustomClipper<Path> {
  final int index, count;
  const _WheelSlice(this.index, this.count);
  @override
  Path getClip(Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(
      center: center,
      radius: min(size.width, size.height) / 2 - 8,
    );
    if (count == 1) return Path()..addOval(rect);
    final sweep = 2 * pi / count;
    return Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(rect, -pi / 2 + index * sweep, sweep, false)
      ..close();
  }

  @override
  bool shouldReclip(covariant _WheelSlice oldClipper) =>
      oldClipper.index != index || oldClipper.count != count;
}
