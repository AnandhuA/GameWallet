# Game Wallet

<img src="assets/art/icon.png" width="112" alt="Game Wallet app icon">

**Discover your next game. Keep track of every adventure.**

Game Wallet is a Flutter game discovery and personal library app for PC, console, Android, and iOS games. Find something new, organize your backlog, track playthroughs, and keep your gaming memories in one place.

Built with **Flutter, Dart, Provider, Hive Community Edition, and Dio**. Live discovery connects directly to **RAWG**—no backend, account, or cloud service is required.

## Features

### Your games, front and center

- **My games** is the default screen and the center navigation tab.
- Organize games into **Playing, Played, and Saved**, with favorites and Dropped status available in the library.
- Track each playthrough from **Day 1**, edit start/end dates, and see completion duration when dates are known.
- Keep replay history without resetting earlier completions or reviews.
- Search your collection from a smoothly expanding header search field.
- Choose list or grid layouts, including **2–5 columns**, with remembered preferences.
- Long press a card—or right-click on desktop—for game actions.

### Discover something new

- Browse featured, popular, top-rated, recently released, and upcoming games.
- Search with debounce, Best match ordering, platform/genre/year filters, and paginated results.
- View descriptions, ratings, release dates, genres, platforms, developers, publishers, screenshots, and official websites when available.
- Personalize discovery through a skippable first-launch questionnaire. Selected platforms filter discovery; favorite genres rank recommendations.
- Edit your gaming preferences from **Profile or Settings**.
- Playing, previously completed, and hidden games stay out of Home and Explore. Your saved personal collection remains accessible.

### More than a backlog

- **LineUp:** create, reorder, and favorite custom game lists; follow completion progress and clone curated starter lists.
- **Journal:** record playthrough reviews, optional half-star ratings, reactions, tags, notes, favorite moments, quotes, and recommendations.
- **Play calendar:** plan local sessions with optional times and notes. Completing a session does not automatically complete a game.
- **Spin wheel:** choose your next game from discovery, saved games, favorites, or a LineUp.
- **Smart Pick:** get a choice using transparent local platform, genre, mood, and status rules.
- **Profile and statistics:** view real collection counts, review ratings, and genre/platform breakdowns.
- **Appearance:** dark, light, and system themes, editable accent colors, responsive desktop navigation, keyboard access, and text scaling.

## Getting started

### Requirements

- Flutter compatible with the project's Dart `^3.10.0` constraint. The project has been developed with Flutter **3.38.1 / Dart 3.10.0**.
- Platform tooling for your target: Android SDK, a browser, Visual Studio C++ tooling for Windows, or macOS/Xcode for iOS.
- A RAWG API key for live discovery. The clearly labeled fictional demo works without a key.

Clone or download this repository, open its root directory, then run:

```sh
flutter pub get
flutter run
```

For a specific target:

```sh
flutter run -d chrome
flutter run -d windows
```

Use `flutter devices` to find an Android device or emulator ID, then run `flutter run -d DEVICE_ID`.

### Connect RAWG

1. Obtain your own key from [RAWG API](https://rawg.io/apidocs).
2. Open **Profile → Settings**.
3. Enter the key in the RAWG key field.
4. Select **Connect & load real games**.

The app validates the key, saves it locally, and enables live discovery. You do not need Twitch credentials, Node.js, a proxy URL, or a server running on your computer.

An optional development configuration is also supported:

```sh
flutter run --dart-define=RAWG_API_KEY=YOUR_RAWG_API_KEY
```

A key saved in Settings takes precedence. Keep real keys out of source control. Keys stored in a client application can be extracted and are not backend secrets; use your own credentials and follow RAWG's usage and attribution requirements.

### Demo mode

Without a key, Game Wallet starts with **fictional sample games**, clearly labeled as demo data. Demo and live saves use separate identities. A failed live request never silently substitutes demo results.

## Offline storage and caching

Your library, favorites, preferences, journals, LineUps, plans, and playthrough dates stay on the device and remain available offline.

| Cache | Default limits | Behavior |
| --- | --- | --- |
| Game metadata | 24-hour expiry; 200 entries | Expired results can be shown as a labeled fallback when requests fail. |
| Artwork | 100 MiB; 500 images; 30-day freshness | Viewed images are cached; Saved/Playing artwork is queued automatically. Older images are evicted when limits are reached. |

Settings offers separate **Clear game data**, **Clear images**, and **Clear all cache** actions. These preserve personal records and API configuration. Clearing application/browser storage removes local data.

To change metadata cache expiry:

```sh
flutter run --dart-define=CACHE_HOURS=12
```

Web artwork caching depends on CDN cross-origin permissions and browser storage limits. Online images may still render when byte caching is unavailable; offline artwork is not guaranteed.

### Automatic image fallback

Covers try the game's cover, artwork, then screenshots in API order. Wide banners try artwork, cover, then screenshots. Blank/duplicate sources are ignored, and the first working image stays selected during normal rebuilds. Discovery cards, Playing cards, and wheel artwork use the same loader; images are never borrowed from another game.

Broken gallery thumbnails are removed. Fullscreen viewing advances to a surviving image and updates its counter; if all images fail, it shows **No images available**. Reopening the page retries failed sources. Usable stale cached images remain available during network failures; only confirmed corrupt cached bytes are removed, without deleting a newer replacement or personal data. Web rendering retains its HTML-image fallback when cross-origin byte requests are blocked.

Playthrough durations count **calendar dates inclusively**, not hours played: starting today is Day 1, and finishing tomorrow is 2 days. Unknown legacy dates stay unknown rather than being inferred.

## Project structure

```text
lib/
  core/        Models, API access, repositories, Hive storage, and caches
  features/    Discovery, details, library, journal, LineUp, calendar, pick,
               profile, and settings screens with focused providers
  shared/      Responsive navigation, cards, cached images, and UI components
test/          Persistence, provider, cache, API, and widget tests
assets/art/    Fictional demo artwork and generated icon preview
assets/branding/ Original supplied Game Wallet icon
tools/         Demo-art and platform-icon generators
docs/          Historical verification notes and preview screenshots
```

Widgets delegate network and storage work to providers and repositories. Search cancels obsolete requests and rejects stale responses; game details use separate state per route. Personal Hive records are kept separate from disposable API and image caches.

The display name is **Game Wallet**. The existing Dart package name (`game_atlas`) and platform application IDs are retained for compatibility with existing installations and saved data.

Stable IDs preserve catalog identity: `rawg:`, legacy `igdb:`, and `demo:`. Existing migrations retain saved records, completion history, and imported reviews. Hive adapters are hand-written; no adapter generation step is required.

The obsolete IGDB backend source has been removed. Any retained ignored local configuration under `backend/` is unused and is never bundled into the app.

## Development and builds

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Build the target you need:

```sh
flutter build web --release
flutter build apk --debug
flutter build windows --release
```

On macOS with Xcode and CocoaPods:

```sh
flutter build ios --no-codesign
```

Android/iOS distribution requires your application IDs and release signing. Windows distribution requires the complete release folder, not only the executable. With the local Flutter 3.38 / Visual Studio 2026 combination, Windows may require explicit CMake configuration with the installed VS 2026 generator.

### Verification

The latest image-fallback update passed **68 tests** and Flutter static analysis. The earlier cleanup and icon updates also passed web release builds. The web build emits a documented Flutter Cupertino font-family warning; see [verification notes](VERIFICATION.md).

Native Android, Windows, and iOS builds were not repeated during that cleanup. Earlier live-service and device checks are separated from fixture-based tests in the [verification history](docs/verification-history.md).

## Limitations

- No accounts, cloud sync, or calendar notifications.
- No fabricated playtime, completion dates, ratings, or missing catalog metadata.
- Smart Pick uses local rules, not AI.
- Trailer playback, store integrations, and similar-game services are not implemented in the current direct RAWG client.
- Artwork is supplied by RAWG and may be a background image rather than a box cover. Optional data and screenshots may be unavailable.

## Credits and previews

- Game catalog and live artwork: [RAWG](https://rawg.io/).
- Visual and interaction inspiration: [Cinemava](https://github.com/AnandhuA/Cinemava).
- Historical UI captures: [preview archive](docs/previews/). These may show earlier designs and are not bundled app assets.


### App icon

The supplied wallet/gamepad artwork is preserved at `assets/branding/app-icon.png`. Android, iOS, web, and Windows icons are generated from that image. Web maskable icons include safe padding; iOS icons are opaque, and the Windows ICO includes seven sizes.

To regenerate on Windows:

```powershell
pwsh -File tools/generate_icons.ps1
```

Rebuild the app to update the installed launcher icon; hot reload does not replace native icons. Browsers and launchers may keep a cached icon until refreshed.
