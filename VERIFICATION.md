# Game Wallet verification — 3 November 2026

## Cleanup scope

- Removed the disabled personal-overview game banner, its parameters/imports, and the unused dashboard featured-game selector.
- Removed unreachable Playing branches beneath the dedicated Playing-card return, plus unused local parameters and layout scaffolding. All 43 Dart files remain reachable from the app entry point.
- Removed the unused `cupertino_icons` dependency. Offline dependency resolution changed only that package; remaining package versions are unchanged.
- Removed obsolete IGDB backend source/tests, Node manifests, Docker files, and backend documentation. `backend/.env` and `backend/.gitignore` remain untouched; the app never reads them.
- Moved 27 root-level PNG previews into `docs/previews/`. Retained demo assets, generator tools, platform scaffolding, IDE configuration, and generated build/cache directories.
- Kept Hive model/adapters, migrations, source IDs, preferences, and personal-data behavior unchanged.

## Checks

- Dart formatting and Flutter analysis: passed with no issues.
- Full Flutter suite: all 55 tests passed after the final structural simplification.
- Release web build: passed (`flutter build web --release`), with the documented Flutter font-family warning.
- No APK generated. Android, Windows and iOS native builds were not repeated for this maintenance change.

Regression coverage includes library persistence/reopening and migrations, playthrough dates/replays, completion cancellation and rollback, editable dates, dense Played/Saved cards, animated search, onboarding/preferences, responsive navigation with enlarged text, metadata/image caches, and API errors using controlled fixtures.

## Service and platform limits

No live API requests or browser/device checks were performed during cleanup. Earlier live checks are historical evidence, not new verification. Web offline artwork still depends on CDN CORS and browser storage limits. iOS compilation requires macOS/Xcode.

Previous feature-delivery checks and preview references are preserved in [verification history](docs/verification-history.md). Historical previews may show older UI.

The web compiler reports a Cupertino font-family warning after removal of the unused package. The app has no Cupertino icon references; the same warning for Material-only apps is tracked in [Flutter issue #119074](https://github.com/flutter/flutter/issues/119074). The warning does not prevent the release build. No framework code or tree-shaking settings were changed to suppress it.


## Display-name update

Renamed the app-facing name to Game Wallet in Flutter UI, profile/settings/about text, Android label, iOS display/bundle name, web title/manifest, Windows window/product labels, README and the VS Code launch label. Dart package name, platform application/bundle identifiers, Windows binary name and Hive storage identities remain unchanged to preserve existing installs and personal data. Platform metadata was parsed and checked; native builds were not generated for this rename.


## Supplied app icon

Replaced platform icons using the supplied teal wallet/gamepad artwork, preserving an identical source copy in `assets/branding/app-icon.png`. Updated the reproducible PowerShell generator. Checked PNG dimensions and opaque RGB output for five Android sizes, 19 iOS catalog entries, four web manifest icons, favicon, and the generated 256px preview. Parsed the Windows ICO header and all seven embedded PNG sizes (16–256px). Web maskable icons include padding. No APK or native installation was generated for this asset update.

The release web build passed for the icon update; generated web icon and favicon hashes match the packaged files.


## Automatic image fallback — 3 November 2026

- Verified the existing shared source order: cover/artwork/screenshots for covers, artwork/cover/screenshots for wide banners, ignoring blank and duplicate sources. Cards, details, Playing and wheel artwork use GameArt/CachedCatalogImage; selected fallback URLs are not written to game metadata or personal snapshots.
- Gallery and fullscreen share temporary image exclusions, remove failed thumbnails, advance to available images, preserve selection and correct counters, and show No images available when exhausted. Reopening creates a new session and retries failures.
- Added confirmed-corruption cache invalidation with a byte-match guard, protecting newer downloads and valid stale data. Downloads now validate a decoded frame before caching. Corruption cleanup runs outside widget build and does not block fallback rendering. Web HTML-image fallback remains in place before final failure.
- Guarded fullscreen callbacks from retired page controllers; fixed duplicate description/gallery keys uncovered by the full regression suite.
- Dart formatting and Flutter analysis passed. All 68 tests passed; focused image coverage includes 12 tests for ordered fallback, corruption, all-failed/missing sources, rebuilds, stale responses, disposal, game changes, gallery reopening and fullscreen recovery. Cache tests cover invalidation, valid replacements, offline stale data and personal-data preservation.
- These failure scenarios use controlled fixtures. No live RAWG/CDN outage or browser CORS failure was induced, and no APK/native build was generated for this update.


## Android adaptive icon

Added Android 8+ adaptive icon definitions for both regular and round launcher entries, a dark full-bleed background, and foreground artwork at all five density sizes (108–432px for 108dp layers). The supplied image is inset within the foreground safe area so the launcher mask fills with artwork/background rather than wrapping a small legacy square in white. Older devices retain bitmap resources. The manifest declares both icon variants, and the icon generator reproduces all resources. Parsed XML/PNG resources and rendered a circular-mask preview at `docs/previews/android-adaptive-circle.png`. Nothing Phone 1 hardware was not directly tested; an updated native build is needed, not hot reload. Android resource compilation was run without requesting an APK assembly task; its result is recorded below.

Android validation passed: `gradlew.bat :app:processDebugResources --offline` completed successfully (57 tasks). No APK assembly or device installation was performed.
