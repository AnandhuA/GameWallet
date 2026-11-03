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

## Stores & prices — 3 November 2026

- Added an expandable **Stores & prices** section to real game details, backed by direct CheapShark requests without additional credentials or a backend. Requests begin on expansion. The section identifies PC/US/USD pricing and explicitly distinguishes it from Indian checkout prices.
- Added typed pricing models, a dedicated Dio service/repository and route-scoped Provider. Exact normalized titles auto-match only when unambiguous; edition/DLC/bundle distinctions remain intact. Ambiguous matches require selection, and selected listing titles remain visible. Listings can be changed. Original RAWG/IGDB/demo identities, metadata and library snapshots are untouched.
- Offers use the dynamic active-store directory, integer-cent sorting, optional original prices/discounts and provider-required redirects. Redirect IDs are encoded once. Unknown/inactive stores are omitted; absent offers do not imply unavailability elsewhere. No redirects were fetched automatically.
- Prices/search/store responses use one-hour freshness in the existing bounded data-cache box. Cached listing mappings are source-aware and disposable. Stale fallback keeps its original check time and loses current-lowest badges. Clearing game data also clears pricing/matches; generation guards prevent earlier requests from restoring cleared cache. Overlapping requests are coalesced, abandoned requests cancel, and numeric/HTTP-date Retry-After values are respected.
- **Formatting:** passed for all lib/test files. **Flutter analysis:** no issues. **Full regression suite:** 88 passed, with the opt-in live check skipped. The 20 new fixture/widget tests cover matching ambiguity, missing/invalid data, edition separation, offers/store mapping, discounts, redirect safety, cache reopening/expiry/refresh, stale fallback, preservation of personal data, clearing in flight, cancellation/deduplication/disposal, rate limits, HTTP-date Retry-After, timeout errors and empty/error states.
- **Responsive review:** layout tests passed at 360px and 1100px widths with normal and 2× text. Readable-font fixture previews were rendered and visually inspected: [phone](docs/previews/store-prices-360-fixture.png), [desktop](docs/previews/store-prices-1100-fixture.png). Their example prices/store combinations are controlled fixtures, not claimed live offers.
- **Live service:** public HTTP requests succeeded for Portal 2 search, game offers and the store directory. The separate opt-in Flutter/Dart client smoke test also passed with real HTTP, finding Portal 2 and a Steam offer. The first attempt was blocked by Flutter's test-only HTTP override; the opt-in test now explicitly restores real networking in its own zone. Routine fixture tests retain network blocking. No live RAWG test was needed or performed for this feature.
- **Release web build:** passed, including Wasm compatibility dry-run. The previously documented Material-only Cupertino font warning remains. Browser CORS/checkout interaction and new Android/Windows/iOS installation checks were not performed. No APK generated.
- **Limits:** supported PC stores only; US/USD prices are not local INR prices. No universal store-coverage claim, currency conversion, giveaways/deals feeds, background polling or notifications were added. Provider and final checkout availability/prices can change.

## Rupee display — 3 November 2026

- Updated Stores & prices to show **estimated ₹ amounts** first, converting CheapShark USD offers using a fetched Frankfurter USD/INR reference rate. Original USD prices remain visible. Converted original prices use the same rate, two decimal places and Indian digit grouping. Labels explicitly distinguish converted estimates from Indian store quotes; no fixed exchange rate is embedded in the app.
- Added validated currency/rate/date parsing and a 24-hour reference-rate cache in the existing disposable data cache. Refresh bypasses that cache; network failure retains a labeled outdated rate. If no usable rate exists, store offers remain available in USD with an explanation. Clearing game data removes the rate without touching personal data. Provider-specific rate-limit cooldowns avoid an FX outage blocking CheapShark requests.
- Formatting and Flutter analysis passed with no issues. **91 regression tests passed**, with the external-service test skipped by default. Added coverage for paise rounding, Indian grouping, invalid rates, daily freshness/forced refresh, stale/offline fallback and failed conversion preserving offers. Existing request cancellation/cache-clearing and source-isolation tests also pass with the FX request included.
- Updated phone/desktop fixture previews were rendered and visually checked. Layout tests passed at 360px/1100px and 1×/2× text scaling. Preview rates and offers are fixtures, not claimed live quotes.
- A real Frankfurter USD/INR HTTP request succeeded. The opt-in Dart live smoke test passed against both CheapShark and Frankfurter, including a valid nonzero rate. Release web build and Wasm dry-run passed; the previously documented Cupertino font warning remains. No new native/device/CORS checkout verification and no APK generated.
