import 'models.dart';

// Entirely fictional review fixtures. Never presented as IGDB records.
final demoGames = List<Game>.generate(12, (i) {
  const names = [
    'Echoes of the Astral Sea',
    'Neon Outriders',
    'The Last Orchard',
    'Citadel of Glass',
    'Drift Protocol',
    'Moonlit Cartographer',
    'Ember & Iron',
    'Tidal Frontier',
    'Pocket Skykeepers',
    'Wild Circuit',
    'After the Aurora',
    'Paper Kingdoms',
  ];
  const genres = ['Adventure', 'Racing', 'Role-playing', 'Strategy'];
  return Game(
    id: i + 1,
    title: names[i],
    demo: true,
    summary:
        'A fictional Game Wallet demo adventure. Explore unfamiliar worlds, discover hidden paths, and shape your own journey. This sample exists to review discovery and personal-library features; its metadata is not real game information.',
    rating: i == 3 ? null : 78 + (i * 3 % 20).toDouble(),
    release: DateTime.now().add(Duration(days: (i - 7) * 18)),
    genres: [genres[i % 4]],
    platforms: i % 3 == 0
        ? ['Android', 'iOS']
        : ['PC', 'PlayStation 5', 'Xbox Series X|S'],
    developers: ['Fictional Studio ${i + 1}'],
    publishers: ['Atlas Demo Collective'],
    screenshots: [
      'assets/art/${i + 1}.png',
      'assets/art/${((i + 1) % 12) + 1}.png',
    ],
    similar: [((i + 1) % 12) + 1, ((i + 2) % 12) + 1],
  );
});
