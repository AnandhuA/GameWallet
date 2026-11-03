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
