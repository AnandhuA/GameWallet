# Game Wallet presentation system

The Flutter presentation follows the supplied `Game Wallet.html` prototype. The HTML is a visual reference only: its sample catalog, fixed prices/rates, simplified journal and simulated actions are not used by the app.

## Theme and typography

`lib/shared/app_theme.dart` is the central theme layer. `AtlasApp.theme` delegates to `WalletTheme.build`; theme mode and accent preferences come from SettingsProvider. The default accent fallback is teal. Persisted accent choices are never overwritten. All previous choices remain available, with Default teal added to the palette.

| Role | Dark | Light |
| --- | --- | --- |
| Background | `#0F1016` | `#F4F4F7` |
| Surface | `#181A24` | `#FFFFFF` |
| Raised surface | `#222533` | `#EBEBF1` |
| Outline | `#2B2E3F` | `#DCDDE6` |
| Main text | `#ECECF2` | `#15161D` |
| Muted text | `#9A9DB0` | `#5B5E6D` |
| Default accent seed | `#5CD0C6` | `#0E8F86` |
| On accent | `#07201E` | `#FFFFFF` |
| Error | `#FF8A80` | `#B3261E` |

The light accent is darkened where white action text otherwise falls below 4.5:1. Other selected accents use the same contrast adjustment. Do not substitute fixed accent colors in feature widgets.

### Pure black (AMOLED)

Appearance provides System, Light, Dark and **Pure black**. Pure black selects dark mode and enables an optional persisted `amoled` preference. Selecting a standard mode clears the flag; it does not affect System mode or Light mode. Existing installations without the preference retain their normal appearance.

`WalletTheme.build(..., amoled: true)` uses `#000000` for dark page backgrounds, app bars, bottom navigation and the navigation rail. Cards, sheets and inputs use `#080808`; raised surfaces use `#141414` and outlines use `#262626`. Text, fonts, artwork and accent selections are preserved. The flag is ignored when building a light theme. No storage adapter or personal-data migration is required.

Titles use bundled **Bricolage Grotesque 600/700**; body text uses **Figtree 400/500/600**. Files and SIL Open Font Licenses are in `assets/fonts/`, sourced from the official [Google Fonts repository](https://github.com/google/fonts). Fonts load locally; no font package or runtime font service is used. The licenses are also registered with Flutter's license registry during startup.

## Geometry and motion

- Spacing tokens: 4, 8, 12, 16, 20, 24 and 32dp.
- Radii: controls/posters 12dp, list rows 14dp, feature cards 16dp, sheets 20dp.
- Minimum standard action target: 44dp.
- Posters: 3:4, with two-line titles beneath the artwork.
- Main content: up to 1100dp. Details: up to 760dp. Forms/sheets: up to 520dp.
- NavigationRail begins at 900dp; compact screens retain NavigationBar.
- Adaptive sheets are bottom-aligned below 700dp and centered above it.
- Shared transitions use 220ms, reduced to zero with `MediaQuery.disableAnimations`. The existing wheel retains its intentional spin animation and reduced-motion behavior.
- Gradients are restricted to artwork scrims. Missing-image presentation uses a neutral theme surface; image loading/fallback remains in the existing loader.

## Component inventory

The reusable presentation components live in `lib/shared/wallet_components.dart`; existing names in `widgets.dart` remain compatible.

| Component | Purpose |
| --- | --- |
| `WalletViewport` | Centered main content or bounded editor forms |
| `GameCover` | Rounded 3:4/16:9 artwork, delegated to existing GameArt |
| `GamePosterCard` | Poster, two-line title and optional duration/metadata caption |
| `GameListRow` | Cover, title, metadata and optional existing actions |
| `PlayingCard` | Artwork scrim, day count, editable date and completion/journal actions |
| `GameInteraction` | Tap, long press, right click, Menu key and Shift+F10 |
| `StatusPill` | Compact textual status with optional icon |
| `SectionHeader` | Consistent section hierarchy and optional trailing action |
| `FilterChipBar` | Shared wrapping chip layout for feature composition |
| `AppBottomSheet` / `showWalletSheet` | Adaptive, scrollable presentation of existing handlers |
| `ConfirmDialog` | Standard confirmation result without owning persistence |
| Existing `EmptyState`, `Notice`, `LoadingCards` | Preserved state/callback interfaces with inherited theme styling |

Never put repository calls or Hive access in these components. Interaction widgets invoke existing providers or supplied callbacks. Existing GameArt/CachedCatalogImage source order, corrupt-image handling and gallery session state remain authoritative.

## Screen composition

My games retains its center/default destination, search expansion, counts, saved layout settings and status handlers. Playing cards form responsive columns on wider screens and a single column with enlarged text. Plans and recent dated finishes appear only below Playing. Played/Saved use poster or list presentations; secondary actions remain accessible by long press/right click and keyboard.

Home uses an artwork-backed recommendation, a Play shortcut to the existing startPlaying operation, compact recommendation rows, platform chips and shared poster shelves. Explore retains its existing filter sheet, query/filter state, sort controls and pagination. Details retains all existing actions with smaller section headings and a bounded reading width.

LineUps show the chosen game cover and a progress indicator derived from the existing completion selector. Profile uses an initial avatar, consolidated counters and consistent destination rows. Journal/calendar/LineUp editors, preferences and settings use bounded forms. Completion/date editing changes presentation only; cancellation, validation, review handoff, duplicate guards and persistence stay with existing handlers.

Stores & prices uses compact responsive offer rows. CheapShark matching/redirects, Frankfurter estimates, USD fallback, stale labels and attribution remain unchanged.

## Preview and test workflow

All redesign previews use isolated temporary Hive boxes and clearly fictional demo data. Pricing previews are explicitly labeled controlled fixtures. They contain no user API keys or personal library data. See [preview index](redesign-previews.md).

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter test test/redesign_ui_test.dart --dart-define=WALLET_PREVIEWS=true
flutter build web --release
```

The preview command loads the bundled fonts and Material icons for readable screenshots. Normal regression tests remain independent of live services. Existing tests are unchanged; redesign-specific tests cover adaptive sheets, cancellation, layout selection, keyboard menus, reduced motion, all accent choices and phone/desktop layouts at 1×/2× text size.

## Deals

The fourth destination is Deals, replacing LineUp while My games remains the default center destination. Source-neutral list presentation uses compact theme cards, platform icons, recorded dates, optional labeled ratings and a Check on Epic action. No placeholder artwork or current availability badges are inferred. Search and wrapping platform chips work at enlarged text sizes. Historical LineUp screen previews describe earlier UI; their personal records remain stored but have no current navigation entry point.

Deals rows now include a 64 × 86 cover thumbnail and open a dedicated detail route. Cover/banner loading uses the existing cached-image fallback component. Images come only from a feed-supplied Steam app ID or a uniquely matched RAWG game; ambiguous search results require manual confirmation. The detail page keeps giveaway facts separate from RAWG metadata and links to the existing full game-detail flow.
