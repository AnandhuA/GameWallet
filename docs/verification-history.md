# Game Atlas 2.2 verification — 31 October 2026

## Completed checks

- Dart formatting passed for source and tests.

- Flutter static analysis passed with no issues.

- All **53 Flutter tests pass** (`flutter test`).

- Web release build passed (`flutter build web --release --no-wasm-dry-run`).

- No APK was generated, as requested. Native Android/iOS/Windows compilation and device execution were not repeated for this update.

## Playthrough coverage

Tests cover inclusive calendar counting, same-day completion, DST-date/month/year/leap-day boundaries, midnight/app-resume updates, repeated Playing taps, resuming unfinished runs, separate replays, completion deduplication, future/reversed-date rejection, legacy unknown dates, date edits preserving counts, and typed Hive reopening. A regression test verifies older replaying saves edit an unknown active start rather than inventing historical completion dates.

Widget tests cover cancellation of completion and review flows, rollback after review-write failure, visible failure feedback, enlarged-text date validation, and the existing navigation/library/search/grid flows. Journal records reference stable playthrough IDs; linked dates are read from the library record. Completion counts and old imported reviews remain intact.

## Cache coverage

Tests verify persistent image bytes across reopening, request deduplication, three-download concurrency, LRU entry/byte eviction, invalid-image rejection, stale image fallback, cancellation while clearing, automatic-download failure preserving personal saves, malformed metadata recovery, explicit force-refresh, and prevention of late cache writes. Clearing data/images preserves game records and playthrough dates. Existing cache expiry, metadata eviction, API failure, search debounce/cancellation/race/pagination tests remain passing.

Images use a separate Hive box with a 100 MiB / 500-image limit and 30-day freshness. API metadata retains its configurable 24-hour default and 200-entry limit. Fresh artwork access updates small LRU metadata rather than rewriting image payloads. Cached artwork may be evicted; it is not a permanent download guarantee.

## Browser review

Reviewed at **390 × 844** and **1366 × 900**:

- Existing RAWG connection and saved library survived the schema update. An older replaying record initially displayed Dates not recorded.

- Explicitly selected October 30 as a QA start date; Playing displayed Day 2 on October 31.

- Completion sheet showed October 30–31 and Completed in 2 days. Complete without review moved the game into Played without adding a review.

- History retained the new dated run and displayed the earlier undated completion separately. Desktop Edit dates showed both recorded dates and the same duration; Cancel left them unchanged.

- Live CDN caching reached **21 images / 13.4 MB**. Clear images changed usage to **0 images / 0.0 MB**, while retaining **19 metadata cache entries** and the personal library.

These browser play dates are deliberate local QA interactions, not imported API play history. Screenshots: `previews/playthrough-day-counter.png`, `previews/playthrough-completion-sheet.png`, `previews/playthrough-history-phone.png`, `previews/playthrough-dates-desktop.png`, `previews/cache-settings-verified.png`.

## Limitations

Browser image persistence depends on CDN CORS and browser quota/eviction. The implemented fallback keeps online image rendering when byte caching is blocked; unavailable offline artwork shows a placeholder. Offline failure behavior is tested with controlled adapters; no browser-wide offline-mode test was performed. The live CDN check covers observed images only, not all RAWG assets or outage/quota scenarios.

No backend, new package dependencies, notifications, playtime inference, or background timer service was added. Day counts are derived from local calendar dates and refresh when the app is visible/resumed.

### Discovery and search follow-up — 31 October 2026

- Home and Explore reactively exclude currently Playing games and games with completed history. Saved games remain discoverable; source identities remain separate.

- Entering a text search selects Best match and leaves RAWG relevance ordering intact. Explicit popularity/rating/release ordering remains available. Request whitespace is normalized and metadata cache keys were versioned to avoid reusing old search rankings.

- Verified: Dart formatting, clean Flutter static analysis, and all 43 Flutter tests. New controlled-fixture tests cover request ordering/normalization and discovery exclusions. Live RAWG search was not reverified in this follow-up. No APK generated.

### Grid layout customization

- Explore and My games Played/Saved support Auto, 2, 3, 4 and 5 columns with independent persistent preferences. Dense cells simplify metadata and keep game actions in the overflow menu. Choosing a column count switches My games from list back to grid. Playing keeps its date/action-focused list.

- Flutter analysis passed; the full suite passed 44 tests. No APK generated.

### Card interaction cleanup

- A single My games View style button combines compact/large/list styles and grid column choices. Removed poster overflow icons; long press and desktop right-click open the shared game-action sheet. Tap still opens details.

- Widget regression covers a single layout control, absence of poster more icons, and long-press action sheet opening.

### Completion dialog redesign

- Replaced the crowded action wrap with full-width review/complete buttons and a separate Cancel action. Added distinct date cards, localized date labels, explicit calendar controls, and a highlighted calendar-duration summary. Unknown dates retain their meaning; clear controls appear only for recorded dates. Dialog content scrolls for small screens and enlarged text.

- Formatting and static analysis passed; all 44 regression tests passed.

### Personal-first dashboard and gaming preferences — 31 October 2026
- My games is the opening destination. Navigation uses named destinations; discovery shortcuts target Explore. Local selectors choose the latest Playing game, fallback Saved game, next two pending sessions, and three dated finishes. Unknown legacy dates remain unmodified.
- Added one-time fresh-install onboarding, reusable Profile/Settings editor, draft/back/finish/skip behavior, family and individual platform selection, per-source saved platform choices, and offline metadata retry/skip.
- Home requests all selected platforms, Explore exposes My platforms/all/explicit overrides, and interests rank recommendations without changing explicit shelf ordering or title-search relevance. Home cancels obsolete discovery requests. Personal records remain unrestricted.
- Added 9 focused tests covering onboarding migration, source-separated preferences, OR platform matching, cancellation, Explore overrides, demo filtering, dashboard selection, questionnaire persistence and offline skip, startup navigation, and phone/desktop layouts at 1.8x text. Full suite: 53 tests.
- No APK generated. Android and iOS were not reverified in this follow-up; live multi-platform RAWG query verification is not claimed from fixture tests.

- Final checks: clean Flutter analysis, full suite 53 passing tests, targeted 9-test dashboard/preferences suite passing after the desktop-only spacing refinement, and release web build passing. Reviewed the live-preview My games collection at 390x844 and 1280x900; both Profile and Settings opened the shared questionnaire. Draft choices were discarded rather than changing existing preferences. Browser screenshots: previews/gaming-preferences-phone.png, previews/personal-dashboard-phone.png, previews/personal-dashboard-desktop.png. The preview loaded real catalog filter metadata; personalized multi-platform game requests were covered with fixtures, not claimed as live verification.

### Animated My games search
- Search starts as a header icon and expands into a focused search field using a 260ms horizontal expansion/fade (200ms reverse). Close/Escape clears the query and collapses the header. Reduced-motion mode bypasses the transition. The FocusNode and controller are disposed.
- Removed the permanent search toolbar; layout and sort actions remain beside the collection heading. Added coverage for mid-animation layout, focus, filtering, Escape, close and disabled animations.

### Playing card and completion-duration refinement
- Playing uses a clean poster panel, prominent Day N badge, editable Started/Add start date action, Complete game and Journal controls. Removed layered backdrop imagery from collection list cards.
- Starting records Day 1 once; completion retains the existing editable start/end-date flow. Played duration reads the latest completed run, independently from any active replay. Unknown durations are omitted, including dense 3–5-column cards.
- Added regression coverage for start-date editing access, known/unknown dense-grid captions, replay duration retention and legacy unknown dates. Static analysis passed; 25 focused tests passed before the final full run. No APK generated.

### Professional Playing view refinement
- Suppressed the repeated featured-game banner while viewing Playing; other collection views retain the overview feature. Search also hides the overview while filtering.
- Playing list cards now use restrained neutral surfaces, larger clean cover/title rows, inline editable start dates, and a compact day/complete/journal footer. Selected collection tabs use neutral surfaces rather than large accent fills.
- Verified Dart formatting, clean static analysis, all 55 tests including enlarged-text/phone/desktop layout checks, completion-date editing, search, dense completed durations, and existing persistence behavior. No APK generated.

### Artwork-card polish
- Playing cards retain artwork with a restrained side fade, solid dark text backing, aligned day badges and a separate opaque action footer. Enlarged-text headers are flexible; actions wrap when needed. Editable start dates and completion/journal actions remain available.
- Formatter and static analysis passed; full regression suite run recorded in the accompanying delivery message.
