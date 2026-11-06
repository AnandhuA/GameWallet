# Game Wallet verification — 5 November 2026

## RAWG + FreeToGame catalog — 5 November 2026

- Added FreeToGame service/adapter, independent cached repository, federated GameRepository and persistent catalog identity links. RAWG remains primary; FreeToGame supplies free-to-play PC/browser discovery and details without another key. Console/mobile coverage still depends on RAWG.
- Explore now deduplicates source-aware keys rather than numeric IDs. Confirmed cross-source matches become one card; exact titles require supporting official links or compatible release year/company metadata. Uncertain same-title secondary cards are suppressed and offered for explicit confirmation in details. Editions/sequels remain distinct. Canonical identities and frozen supplementary snapshots remain stable across paging; refresh starts a new snapshot.
- Home gains attributed free-to-play recommendations/shelf. Popular and Top rated retain RAWG ordering; supplementary ratings are never fabricated. Effective platform/genre/year filters are applied explicitly, including PC/browser mapping. Failed sources produce partial-results notices; Explore exposes Refresh sources. Web CORS restrictions never introduce a proxy or another API key.
- Detail loading routes by source and supplements missing fields/artwork only after confirmation. Optional Game JSON provenance/fallback-image fields retain compatibility with existing Hive adapters. Source-specific IDs and personal records are never moved. Alias-aware library actions preserve saved IDs, review lookup resolves linked sources, and Playing/Completed/Hidden exclusions span confirmed aliases. Linked metadata provides same-game image fallback through the existing cached-image loader.
- Source caches use existing expiry/budget, stale fallback, force refresh and generation checks during clearing. FreeToGame downloads deduplicate across readers, cancel unused requests, run with two concurrent downloads and 125ms minimum start spacing. Personal identity links survive API cache clearing; concurrent confirmations serialize to preserve transitive groups.
- Baseline: 134 tests passed. Current regression suite: **156 tests passed**, three opt-in live checks skipped. Twenty-two new fixture tests cover normalization, source-local ID collisions, strong/ambiguous matching, canonical paging identity, frozen snapshots, alias persistence/reopening, personal-action ID preservation, review lookup, cross-source exclusions, partial/both-source failures, restrictive filters, rating integrity, independent stale caches, cancellation/concurrency, cache clearing and full supplementary detail loading. Phone/desktop details run at 390/1280 widths with 200% text.
- The opt-in **live FreeToGame smoke check passed** against the real list and detail endpoints and decoded a returned cover through ImageCacheService. The public feed contained 421 records when checked. Live RAWG cross-source matching, browser CORS behavior and physical-device interaction were not tested.
- Web release build and Wasm dry run passed. The pre-existing Cupertino font-family warning remains. No dependencies, app IDs, icon, backend or account flow were added. No APK generated. README documents integration, limits, attribution and exact live-test command.


## Deals missing-cover correction — 4 November 2026

- Confirmed that several latest public feed records have neither Steam links nor artwork. Direct Epic page inspection was challenged, so no page scraping or challenge bypass was added. The supplied repository assets contain store/platform icons, not game covers.
- Artwork lookups now use opt-in precise/exact RAWG search flags, with distinct cache keys. Normal Explore searches keep their previous behavior. Automatic selection still rejects ambiguous titles, editions and wrong-platform games.
- Feed cache version 2 refreshes legacy version-1 records that may have discarded Steam links; legacy data remains a labeled offline fallback. Personal records and image bytes are not deleted.
- Cover lookup shows a loading indicator. Refresh Deals increments an artwork revision, retries failed cached-image candidates and forces catalog enrichment to retry, including when the prior result had no usable cover.
- Added real image-decoding widget fixtures for direct RAWG lookup, failed Steam candidates followed by RAWG artwork, and retry after an empty cover result; added legacy-cache refresh/offline coverage and precise-request assertions. Test repository overrides only gained the new optional precise parameter.
- Formatting, analysis and diff checks passed. **134 tests passed**, two opt-in live tests skipped. Images were decoded from controlled fixture bytes using the actual cached-image widget. Live RAWG enrichment and physical-device loading were not verified; unavailable source artwork still uses placeholders. No APK generated.


## Deals cover artwork and details — 4 November 2026

- Deal rows now include cover thumbnails and open a dedicated in-app detail route with a banner, cover, title, source, recorded date, platform, optional ratings and external Epic action. The historical/possibly expired giveaway disclaimer remains prominent.
- Valid HTTPS Steam app links supplied by the feed generate matching Steam cover/header image candidates. Steam URLs survive feed-cache serialization; legacy records without the field remain readable. If linked Steam artwork fails, a configured RAWG key can attempt the same safe catalog matching used for records without Steam links.
- Additional metadata uses the existing GameRepository, cached RAWG search/details and stable rawg IDs. Only a unique exact normalized title/platform match from a complete result set is automatic; editions, ambiguous results and wrong-platform matches are not guessed. Ambiguous candidates require explicit selection. Details show available description/release/genres and link to full game details for library actions, journal, screenshots and store prices.
- The shared cached-image loader retains same-game fallback order, placeholders, offline images and web fallback behavior. Search lookups deduplicate, run at a maximum concurrency of two, expire with existing metadata freshness, respect cache generation and keep at most 200 in-memory results. Superseded/disposed detail loads cannot overwrite newer selections.
- Added eight focused tests: safe Steam links and serialization, exact/edition/platform/ambiguity matching, shared-search concurrency and cache clearing, metadata/stale state/manual selection, failures/disposal, late responses, and navigation from real app Deals to details without a key at 390/1280 widths and 200% text. Existing image fallback tests remain intact.
- **130 tests passed**, two opt-in live checks skipped; analysis clean, formatting and diff checks passed. A public Steam cover URL derived from the feed's Subnautica app link returned HTTP 200 and image/jpeg. No live RAWG enrichment was claimed or tested; catalog behavior uses fixtures. Web release build and Wasm dry run passed; the pre-existing Cupertino font-family warning remains. No APK or native-device test.


## Deals replaces LineUp — 4 November 2026

- Navigation is Home / Explore / My games / Deals / Profile. My games remains centered and selected at launch. Deals loads only when selected, independently of the RAWG key or demo catalog; fictional demo labels are suppressed for this real feed.
- Added a source record model, isolated Epic JSON parser, Dio service, bounded-cache repository, focused Provider and responsive searchable page. Latest recorded giveaway groups and older history support All/PC/Android/iOS/unspecified filters, labeled optional Epic/Metacritic ratings, validated Epic links, source attribution and last-fetched timestamps.
- The feed supplies history, not verified live offers, end dates, prices or artwork. No current-free claims, deadlines, price estimates, guessed RAWG matches or unrelated images are added. No upstream updater code is copied; the source is attributed.
- LineUp navigation, details/menu actions, wheel sources and statistics are removed. Compatibility models/providers, existing list records and legacy direct-screen tests remain; no personal boxes, IDs, migrations or saved lists are deleted.
- Metadata cache is reused with one-hour feed freshness, forced refresh and labeled stale fallback. Malformed cache can recover, invalid responses do not replace valid cache, superseded/disposed requests are cancelled, and cache generation prevents in-flight requests from repopulating cleared cache.
- Baseline: 110 tests passed, one live check skipped. Current suite: **122 tests passed**, two opt-in live checks skipped. Twelve new fixture tests cover parsing/date/link validation, duplicates, optional values, platform occurrences, cache expiry/refresh/reopening, rate/error fallback, clear-during-download with personal-data preservation, provider deduplication/stale responses/disposal, and phone/desktop layouts at 200% text in dark/light/AMOLED themes. Two existing UI expectations were updated for the intentionally removed LineUp tab/action; legacy persistence tests remain.
- Opt-in **live Epic giveaway feed smoke check passed** using the real Dio service and parser against the published GitHub JSON. This verifies feed access and parsing, not Epic checkout availability. The test explicitly restores real networking within its opt-in zone; normal fixture tests retain Flutter's network blocking.
- Formatting, Flutter analysis and regression tests passed. Web release build passed, including Wasm dry run. The existing Material-only Cupertino font-family warning remains. Native device and browser interaction/CORS checks were not performed; no APK generated.


## Pure black (AMOLED) appearance — 4 November 2026

- Added Pure black as the fourth Appearance choice. It saves the existing dark ThemeMode plus an optional `amoled` preference. System, Light and Dark clear that flag, so the choices are mutually exclusive. Old preferences default to standard themes with no migration or adapter changes.
- The central theme builder accepts an optional AMOLED flag. Dark page backgrounds, app bars, bottom navigation and navigation rails become `#000000`; cards, sheets and inputs use `#080808`, raised surfaces `#141414` and outlines `#262626`. Existing accent colors, typography, artwork and standard theme palettes remain intact. The flag has no effect on light-theme construction.
- Added six focused tests for legacy defaults, persistence after reopening Hive, unchanged accent/personal records, cache clearing, all four appearance selections, exact black/surface colors and readable contrast across every accent choice. Widget tests exercise immediate updates at 390px/1280px with 200% text scaling, including System mode under a light OS appearance.
- Formatting, analysis and `git diff --check` passed. **110 tests passed**, with the opt-in live-service test skipped. Existing tests were not edited.
- README and design-system documentation now describe the option. No native-device checks, web/native build or external-service retest was needed for this theme-only change. No APK generated.

## HTML UI redesign — 4 November 2026

### Presentation changes

- Applied the supplied `Game Wallet.html` visual language through a central Material 3 theme, ThemeExtension tokens and shared presentation components. Added bundled Bricolage Grotesque/Figtree assets and SIL Open Font Licenses, registered during startup. No font package, backend or dependency upgrade was added.
- Added dark/light palettes, accessible accent tones, shared radii/spacing, compact poster/list cards, artwork-backed Playing cards, status pills, section headers, adaptive sheets and keyboard context actions. Bright-artwork scrims are checked against a white image for readable foreground text. Preserved all saved accent choices; the only provider edit is the user-approved teal fallback.
- Kept Home/Explore/My games/LineUp/Profile destinations, center/default My games, IndexedStack and existing route callbacks. My games uses a compact greeting, search expansion, saved layout preferences, responsive Playing columns and plans/recent finishes only under Playing.
- Re-laid out details, completion/date editing, recommendations, Explore cards, collection rows/progress, Profile counters and supporting forms. Journal/calendar/collection editors, preferences and settings use bounded form widths. Store offers use compact rows and retain their original matching, caching, currency and redirect handlers.
- Existing `GameArt`/CachedCatalogImage source order and cache/session logic remain intact. Gallery changes are limited to presentation radii and reduced-motion navigation. Home's Play shortcut delegates to the existing LibraryProvider operation; existing completion/favorite actions remain reachable through the game menu/details.

### Checks and evidence

- Baseline before edits: **91 tests passed**, with the explicit live-service check skipped.
- Original six test files are unchanged. Added **13 redesign tests** covering all available accent choices, keyboard/long-press/right-click menus, adaptive layout/filter sheets, layout persistence, completion cancellation, reduced motion, all five destinations and supporting screens at 390px/1280px and 100%/200% text.
- Final regression suite: **104 tests passed**, with one opt-in live-service check skipped. The separate readable-font preview suite also passed all 13 tests.
- Dart formatting and Flutter analysis passed with no issues. `git diff --check` passed.
- Rendered **40 fixture screenshots** across phone and desktop layouts, including details, completion, editors, calendar, wheel, preferences, settings and prices. Reviewed representative dark/light, card, sheet, form and pricing renders. See the [preview index](docs/redesign-previews.md) and [design system](docs/design-system.md).
- Release web build passed, including Wasm compatibility dry-run. The previously recorded Material-only Cupertino font-family warning remains; no framework files or tree-shaking settings were changed to suppress it.
- Protected-file audit: core models/adapters/migrations/API/storage/cache/repositories, all other providers, application IDs/icons and the dependency lockfile are unchanged. Existing API keys and user records were not opened, overwritten or used for screenshots.

### Limits

Screenshots and new visual tests use isolated temporary Hive boxes, fictional demo records and explicitly labeled price fixtures. They are not live offers or personal-library screenshots. No external service integration was retested during this presentation-only update. Native Android/iOS/Windows builds, physical-device installs and browser checkout/CORS interactions were not repeated. No APK generated. The HTML file was inspected as source; its local-file browser preview was blocked, so its CSS tokens, sizing and source-defined interactions guided implementation.

Earlier verification entries below are historical and retain their original scope.

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
