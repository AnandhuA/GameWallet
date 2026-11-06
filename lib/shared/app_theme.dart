import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show LicenseRegistry, LicenseEntryWithLineBreaks;
import 'package:flutter/services.dart' show rootBundle;

/// Shared presentation tokens. No persisted preferences or catalog logic live here.
abstract final class WalletSpace {
  static const double xs = 4,
      sm = 8,
      md = 12,
      page = 16,
      lg = 20,
      xl = 24,
      wide = 32;
}

abstract final class WalletRadius {
  static const control = BorderRadius.all(Radius.circular(12));
  static const row = BorderRadius.all(Radius.circular(14));
  static const card = BorderRadius.all(Radius.circular(16));
  static const sheet = BorderRadius.all(Radius.circular(20));
}

@immutable
class WalletTokens extends ThemeExtension<WalletTokens> {
  final Color artworkText, artworkMuted, artworkBase;
  final double contentWidth, sheetWidth, detailsWidth;
  const WalletTokens({
    this.artworkText = Colors.white,
    this.artworkMuted = const Color(0xFFE0E2E8),
    this.artworkBase = const Color(0xFF0F1016),
    this.contentWidth = 1100,
    this.sheetWidth = 520,
    this.detailsWidth = 760,
  });
  static WalletTokens of(BuildContext context) =>
      Theme.of(context).extension<WalletTokens>() ?? const WalletTokens();
  static Duration motion(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : const Duration(milliseconds: 220);
  LinearGradient get scrim => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      artworkBase.withValues(alpha: .70),
      artworkBase.withValues(alpha: .82),
      artworkBase.withValues(alpha: .97),
    ],
    stops: const [0, .58, 1],
  );
  @override
  WalletTokens copyWith({
    Color? artworkText,
    Color? artworkMuted,
    Color? artworkBase,
    double? contentWidth,
    double? sheetWidth,
    double? detailsWidth,
  }) => WalletTokens(
    artworkText: artworkText ?? this.artworkText,
    artworkMuted: artworkMuted ?? this.artworkMuted,
    artworkBase: artworkBase ?? this.artworkBase,
    contentWidth: contentWidth ?? this.contentWidth,
    sheetWidth: sheetWidth ?? this.sheetWidth,
    detailsWidth: detailsWidth ?? this.detailsWidth,
  );
  @override
  WalletTokens lerp(covariant WalletTokens? other, double t) => other == null
      ? this
      : copyWith(
          artworkText: Color.lerp(artworkText, other.artworkText, t),
          artworkMuted: Color.lerp(artworkMuted, other.artworkMuted, t),
          artworkBase: Color.lerp(artworkBase, other.artworkBase, t),
        );
}

abstract final class WalletTheme {
  static TextStyle? moneyStyle(BuildContext context) =>
      Theme.of(context).textTheme.titleMedium?.copyWith(
        fontFamily: 'Figtree',
        fontFamilyFallback: const ['Bricolage Grotesque'],
        fontWeight: FontWeight.w600,
      );
  static void registerFontLicenses() {
    LicenseRegistry.addLicense(() async* {
      for (final font in ['BricolageGrotesque', 'Figtree']) {
        yield LicenseEntryWithLineBreaks([
          font,
        ], await rootBundle.loadString('assets/fonts/$font-OFL.txt'));
      }
    });
  }

  static const defaultAccent = Color(0xFF5CD0C6);
  static double contrast(Color a, Color b) {
    final x = a.computeLuminance(), y = b.computeLuminance();
    return (x > y ? (x + .05) / (y + .05) : (y + .05) / (x + .05));
  }

  static Color _readable(Color color, Color background, Color toward) {
    for (var step = 0; step <= 100; step++) {
      final candidate = Color.lerp(color, toward, step / 100)!;
      if (contrast(candidate, background) >= 4.5) return candidate;
    }
    return toward;
  }

  static ThemeData build(
    Brightness brightness,
    Color seed, {
    bool amoled = false,
  }) {
    final dark = brightness == Brightness.dark;
    final black = dark && amoled;
    final bg = Color(
      black
          ? 0xFF000000
          : dark
          ? 0xFF0F1016
          : 0xFFF4F4F7,
    );
    final surface = Color(
      black
          ? 0xFF080808
          : dark
          ? 0xFF181A24
          : 0xFFFFFFFF,
    );
    final high = Color(
      black
          ? 0xFF141414
          : dark
          ? 0xFF222533
          : 0xFFEBEBF1,
    );
    final outline = Color(
      black
          ? 0xFF262626
          : dark
          ? 0xFF2B2E3F
          : 0xFFDCDDE6,
    );
    final text = Color(dark ? 0xFFECECF2 : 0xFF15161D);
    final muted = Color(dark ? 0xFF9A9DB0 : 0xFF5B5E6D);
    final onAccent = Color(dark ? 0xFF07201E : 0xFFFFFFFF);
    final chosen = seed == defaultAccent && !dark
        ? const Color(0xFF0E8F86)
        : seed;
    final primary = _readable(
      chosen,
      onAccent,
      dark ? Colors.white : Colors.black,
    );
    final container = Color.lerp(surface, primary, dark ? .18 : .12)!;
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness)
        .copyWith(
          surface: bg,
          surfaceContainerLowest: bg,
          surfaceContainerLow: surface,
          surfaceContainer: surface,
          surfaceContainerHigh: high,
          surfaceContainerHighest: high,
          onSurface: text,
          onSurfaceVariant: muted,
          outline: outline,
          outlineVariant: outline,
          primary: primary,
          onPrimary: onAccent,
          primaryContainer: container,
          onPrimaryContainer: _readable(
            primary,
            container,
            dark ? Colors.white : Colors.black,
          ),
          secondaryContainer: high,
          onSecondaryContainer: text,
          error: Color(dark ? 0xFFFF8A80 : 0xFFB3261E),
        );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'Figtree',
    );
    final body = base.textTheme.apply(bodyColor: text, displayColor: text);
    TextStyle title(double size, FontWeight weight) => TextStyle(
      fontFamily: 'Bricolage Grotesque',
      fontSize: size,
      fontWeight: weight,
      height: 1.2,
      letterSpacing: -.2,
      color: text,
    );
    final shape = RoundedRectangleBorder(borderRadius: WalletRadius.control);
    return base.copyWith(
      extensions: const [WalletTokens()],
      scaffoldBackgroundColor: bg,
      textTheme: body.copyWith(
        displayLarge: title(32, FontWeight.w700),
        displayMedium: title(30, FontWeight.w700),
        displaySmall: title(28, FontWeight.w700),
        headlineLarge: title(28, FontWeight.w700),
        headlineMedium: title(24, FontWeight.w700),
        headlineSmall: title(22, FontWeight.w700),
        titleLarge: title(20, FontWeight.w700),
        titleMedium: title(17, FontWeight.w600),
        titleSmall: title(15, FontWeight.w600),
        bodyLarge: body.bodyLarge?.copyWith(fontSize: 15, height: 1.4),
        bodyMedium: body.bodyMedium?.copyWith(fontSize: 14, height: 1.4),
        bodySmall: body.bodySmall?.copyWith(
          fontSize: 13,
          height: 1.4,
          fontFamilyFallback: const ['Bricolage Grotesque'],
        ),
        labelLarge: body.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        labelSmall: body.labelSmall?.copyWith(fontSize: 12, height: 1.3),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: surface,
        shape: const RoundedRectangleBorder(borderRadius: WalletRadius.card),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: text,
        scrolledUnderElevation: 0,
        titleTextStyle: title(22, FontWeight.w700),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: shape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          minimumSize: const Size(44, 44),
          side: BorderSide(color: outline),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: shape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          shape: shape,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(44, 44),
          shape: shape,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: WalletRadius.control,
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: WalletRadius.control,
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: WalletRadius.control,
          borderSide: BorderSide(color: primary, width: 2),
        ),
        labelStyle: TextStyle(color: muted),
        hintStyle: TextStyle(color: muted),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: surface,
        side: BorderSide(color: outline),
        shape: shape,
        labelStyle: body.labelLarge?.copyWith(color: text),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          minimumSize: const Size(44, 44),
          shape: shape,
          selectedBackgroundColor: high,
          selectedForegroundColor: text,
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: const RoundedRectangleBorder(borderRadius: WalletRadius.row),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        iconColor: muted,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: const RoundedRectangleBorder(borderRadius: WalletRadius.sheet),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: muted,
        shape: const RoundedRectangleBorder(borderRadius: WalletRadius.sheet),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: WalletRadius.control),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: black ? bg : surface,
        elevation: 0,
        height: 72,
        indicatorColor: high,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => body.labelSmall?.copyWith(
            color: states.contains(WidgetState.selected) ? primary : muted,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: black ? bg : surface,
        indicatorColor: high,
        selectedIconTheme: IconThemeData(color: primary),
        unselectedIconTheme: IconThemeData(color: muted),
      ),
      dividerTheme: DividerThemeData(color: outline, thickness: 1, space: 16),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: WalletRadius.control),
      ),
    );
  }
}
