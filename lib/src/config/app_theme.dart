import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/prediction.dart';
import '../models/usage_log.dart';

/// Central theme + design tokens for LoopAware.
///
/// Static constants are the brand values that read well on both light and
/// dark surfaces (icons, fills). Anything that must adapt to brightness —
/// surfaces, text, soft status fills — lives in [AppColors], reached through
/// `AppColors.of(context)`.
class AppTheme {
  AppTheme._();

  // Brand
  static const Color primary = Color(0xFF1D6B62);
  static const Color primaryDark = Color(0xFF175850);
  static const Color secondary = Color(0xFF7FB5AB);
  static const Color tertiary = Color(0xFFB7791F);

  // Status
  static const Color good = Color(0xFF1E8A5A);
  static const Color moderate = Color(0xFFB7791F);
  static const Color severe = Color(0xFFC2413A);
  static const Color info = Color(0xFF3569B5);

  // Shape
  static const double radiusSm = 8;
  static const double radiusMd = 10;
  static const double radiusLg = 16;

  // Layout breakpoints (logical pixels of available width).
  static const double compactMax = 600;
  static const double wideMin = 900;
  static const double sidebarMin = 1024;

  /// Tabular figures so numbers in tables and metrics don't jitter.
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final c = isDark ? AppColors.dark : AppColors.light;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
    ).copyWith(
      primary: c.primary,
      onPrimary: c.onPrimary,
      primaryContainer: c.primarySoft,
      onPrimaryContainer: c.onPrimarySoft,
      secondary: c.primary,
      onSecondary: c.onPrimary,
      secondaryContainer: c.primarySoft,
      onSecondaryContainer: c.onPrimarySoft,
      tertiary: tertiary,
      surface: c.surface,
      onSurface: c.textPrimary,
      onSurfaceVariant: c.textSecondary,
      surfaceContainerHighest: c.surfaceMuted,
      surfaceContainerHigh: c.surfaceMuted,
      surfaceContainer: c.surfaceMuted,
      surfaceContainerLow: c.surface,
      surfaceContainerLowest: c.surface,
      outline: c.borderStrong,
      outlineVariant: c.border,
      error: c.critical.solid,
      onError: Colors.white,
    );

    TextStyle font({
      required double size,
      required double height,
      required FontWeight weight,
      required Color color,
      double spacing = 0,
    }) {
      return GoogleFonts.manrope(
        fontSize: size,
        height: height / size,
        fontWeight: weight,
        color: color,
        letterSpacing: spacing,
      );
    }

    final textTheme = GoogleFonts.manropeTextTheme(
      isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
    ).copyWith(
      displaySmall: font(
        size: 40,
        height: 44,
        weight: FontWeight.w700,
        color: c.textPrimary,
        spacing: -1,
      ),
      headlineMedium: font(
        size: 26,
        height: 34,
        weight: FontWeight.w700,
        color: c.textPrimary,
        spacing: -0.4,
      ),
      headlineSmall: font(
        size: 21,
        height: 28,
        weight: FontWeight.w700,
        color: c.textPrimary,
        spacing: -0.3,
      ),
      titleLarge: font(
        size: 18,
        height: 24,
        weight: FontWeight.w700,
        color: c.textPrimary,
        spacing: -0.2,
      ),
      titleMedium: font(
        size: 15,
        height: 22,
        weight: FontWeight.w700,
        color: c.textPrimary,
      ),
      titleSmall: font(
        size: 14,
        height: 20,
        weight: FontWeight.w700,
        color: c.textPrimary,
      ),
      bodyLarge: font(
        size: 15,
        height: 22,
        weight: FontWeight.w500,
        color: c.textPrimary,
      ),
      bodyMedium: font(
        size: 14,
        height: 20,
        weight: FontWeight.w500,
        color: c.textSecondary,
      ),
      bodySmall: font(
        size: 12,
        height: 16,
        weight: FontWeight.w600,
        color: c.textTertiary,
      ),
      labelLarge: font(
        size: 14,
        height: 20,
        weight: FontWeight.w700,
        color: c.textPrimary,
      ),
      labelMedium: font(
        size: 13,
        height: 18,
        weight: FontWeight.w700,
        color: c.textSecondary,
      ),
      labelSmall: font(
        size: 11,
        height: 16,
        weight: FontWeight.w700,
        color: c.textTertiary,
        spacing: 0.5,
      ),
    );

    final buttonText = GoogleFonts.manrope(
      fontSize: 14,
      fontWeight: FontWeight.w700,
    );
    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusMd),
    );

    OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      extensions: [c],
      scaffoldBackgroundColor: c.background,
      canvasColor: c.surface,
      visualDensity: VisualDensity.standard,
      textTheme: textTheme,
      dividerColor: c.border,
      dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: c.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(color: c.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: BorderSide(color: c.border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: c.onPrimary,
          disabledBackgroundColor: c.surfaceMuted,
          disabledForegroundColor: c.textTertiary,
          elevation: 0,
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: controlShape,
          textStyle: buttonText.copyWith(fontSize: 15),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: c.onPrimary,
          elevation: 0,
          minimumSize: const Size(64, 40),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: controlShape,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.textPrimary,
          backgroundColor: c.surface,
          minimumSize: const Size(64, 40),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          side: BorderSide(color: c.borderStrong),
          shape: controlShape,
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.primary,
          minimumSize: const Size(44, 40),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: controlShape,
          textStyle: buttonText,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: c.textPrimary,
          minimumSize: const Size(44, 44),
          shape: controlShape,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: inputBorder(c.borderStrong),
        enabledBorder: inputBorder(c.borderStrong),
        focusedBorder: inputBorder(c.primary, 1.6),
        errorBorder: inputBorder(c.critical.solid),
        focusedErrorBorder: inputBorder(c.critical.solid, 1.6),
        labelStyle: textTheme.bodyMedium,
        floatingLabelStyle: textTheme.bodyMedium?.copyWith(color: c.primary),
        hintStyle: textTheme.bodyMedium?.copyWith(color: c.textTertiary),
        prefixIconColor: c.textTertiary,
        suffixIconColor: c.textTertiary,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 68,
        indicatorColor: c.primarySoft,
        indicatorShape: const StadiumBorder(),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 22,
            color:
                states.contains(WidgetState.selected)
                    ? c.onPrimarySoft
                    : c.textSecondary,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => GoogleFonts.manrope(
            fontSize: 12,
            fontWeight:
                states.contains(WidgetState.selected)
                    ? FontWeight.w700
                    : FontWeight.w600,
            color:
                states.contains(WidgetState.selected)
                    ? c.onPrimarySoft
                    : c.textSecondary,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: c.surface,
        indicatorColor: c.primarySoft,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        labelType: NavigationRailLabelType.all,
        selectedIconTheme: IconThemeData(color: c.onPrimarySoft, size: 22),
        unselectedIconTheme: IconThemeData(color: c.textSecondary, size: 22),
        selectedLabelTextStyle: GoogleFonts.manrope(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: c.onPrimarySoft,
        ),
        unselectedLabelTextStyle: GoogleFonts.manrope(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: c.textSecondary,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected)
                  ? c.onPrimary
                  : (isDark ? c.textSecondary : Colors.white),
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected)
                  ? c.primary
                  : c.borderStrong,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: c.primary,
        inactiveTrackColor: c.surfaceMuted,
        thumbColor: c.primary,
        overlayColor: c.primary.withValues(alpha: 0.12),
        trackHeight: 4,
        valueIndicatorColor: c.textPrimary,
        valueIndicatorTextStyle: GoogleFonts.manrope(
          color: c.surface,
          fontWeight: FontWeight.w700,
        ),
        activeTickMarkColor: Colors.transparent,
        inactiveTickMarkColor: Colors.transparent,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surface,
        selectedColor: c.primarySoft,
        labelStyle: textTheme.labelMedium?.copyWith(color: c.textPrimary),
        side: BorderSide(color: c.borderStrong),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? c.surfaceMuted : c.textPrimary,
          borderRadius: BorderRadius.circular(radiusSm),
        ),
        textStyle: GoogleFonts.manrope(
          color: isDark ? c.textPrimary : c.surface,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? c.surfaceMuted : c.textPrimary,
        contentTextStyle: GoogleFonts.manrope(
          color: isDark ? c.textPrimary : c.surface,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.primary,
        linearTrackColor: c.surfaceMuted,
      ),
      iconTheme: IconThemeData(color: c.textSecondary),
    );
  }
}

/// A foreground / background pair for status chips and tinted icons.
class StatusTone {
  const StatusTone({
    required this.solid,
    required this.soft,
    required this.onSoft,
  });

  /// Saturated color for bars, rings and icons.
  final Color solid;

  /// Low-emphasis fill behind [onSoft] text.
  final Color soft;

  /// Readable text color on [soft].
  final Color onSoft;
}

/// Brightness-aware design tokens, installed as a [ThemeExtension].
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.segmentTrack,
    required this.border,
    required this.borderSubtle,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.primary,
    required this.onPrimary,
    required this.primarySoft,
    required this.onPrimarySoft,
    required this.good,
    required this.warning,
    required this.critical,
    required this.info,
    required this.chartMuted,
    required this.chartAccent,
    required this.chartNight,
    required this.shadow,
    required bool isDark,
  }) : _isDark = isDark;

  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color segmentTrack;
  final Color border;
  final Color borderSubtle;
  final Color borderStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color primary;
  final Color onPrimary;
  final Color primarySoft;
  final Color onPrimarySoft;
  final StatusTone good;
  final StatusTone warning;
  final StatusTone critical;
  final StatusTone info;

  /// De-emphasised bars (history days, background series).
  final Color chartMuted;

  /// Secondary series color.
  final Color chartAccent;

  /// Late-night usage highlight.
  final Color chartNight;

  final Color shadow;
  final bool _isDark;

  bool get isDark => _isDark;

  static const AppColors light = AppColors(
    isDark: false,
    background: Color(0xFFF5F6F4),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF0F2EF),
    segmentTrack: Color(0xFFE9ECE8),
    border: Color(0xFFE2E5E1),
    borderSubtle: Color(0xFFEEF0ED),
    borderStrong: Color(0xFFD3D7D2),
    textPrimary: Color(0xFF151B19),
    textSecondary: Color(0xFF4A5450),
    textTertiary: Color(0xFF6B7570),
    primary: Color(0xFF1D6B62),
    onPrimary: Color(0xFFFFFFFF),
    primarySoft: Color(0xFFE4F0EC),
    onPrimarySoft: Color(0xFF16574F),
    good: StatusTone(
      solid: Color(0xFF1E8A5A),
      soft: Color(0xFFE3F3EA),
      onSoft: Color(0xFF1E7A51),
    ),
    warning: StatusTone(
      solid: Color(0xFFB7791F),
      soft: Color(0xFFFBF1DE),
      onSoft: Color(0xFF8A5A0F),
    ),
    critical: StatusTone(
      solid: Color(0xFFC2413A),
      soft: Color(0xFFFBE8E6),
      onSoft: Color(0xFFA8362F),
    ),
    info: StatusTone(
      solid: Color(0xFF3569B5),
      soft: Color(0xFFE6EEF9),
      onSoft: Color(0xFF2F5E9E),
    ),
    chartMuted: Color(0xFFC5DDD7),
    chartAccent: Color(0xFF7FB5AB),
    chartNight: Color(0xFF8C82C4),
    shadow: Color(0x0A151B19),
  );

  static const AppColors dark = AppColors(
    isDark: true,
    background: Color(0xFF0E1211),
    surface: Color(0xFF151A19),
    surfaceMuted: Color(0xFF1C2321),
    segmentTrack: Color(0xFF1C2321),
    border: Color(0xFF262D2B),
    borderSubtle: Color(0xFF1F2624),
    borderStrong: Color(0xFF323A38),
    textPrimary: Color(0xFFE7ECEA),
    textSecondary: Color(0xFFB4BEBA),
    textTertiary: Color(0xFF8E9994),
    primary: Color(0xFF5FB8AA),
    onPrimary: Color(0xFF06201C),
    primarySoft: Color(0xFF173430),
    onPrimarySoft: Color(0xFF8FD3C7),
    good: StatusTone(
      solid: Color(0xFF4DBB85),
      soft: Color(0xFF15302A),
      onSoft: Color(0xFF7DD3A8),
    ),
    warning: StatusTone(
      solid: Color(0xFFE0A447),
      soft: Color(0xFF33291A),
      onSoft: Color(0xFFEBC07A),
    ),
    critical: StatusTone(
      solid: Color(0xFFEE7A70),
      soft: Color(0xFF3A1F1D),
      onSoft: Color(0xFFF4A39B),
    ),
    info: StatusTone(
      solid: Color(0xFF74A2E6),
      soft: Color(0xFF1A2638),
      onSoft: Color(0xFFA3C2F0),
    ),
    chartMuted: Color(0xFF3A625C),
    chartAccent: Color(0xFF34574F),
    chartNight: Color(0xFF9D94D6),
    shadow: Color(0x00000000),
  );

  static AppColors of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<AppColors>() ??
        (theme.brightness == Brightness.dark ? dark : light);
  }

  /// Maps a risk band onto a status tone.
  StatusTone severity(Severity severity) => switch (severity) {
    Severity.low => good,
    Severity.moderate => warning,
    Severity.high => critical,
  };

  /// Chart color for an app category. Muted, distinguishable hues that
  /// don't collide with the status palette.
  Color category(AppCategory category) => switch (category) {
    AppCategory.social => const Color(0xFF6C7BD9),
    AppCategory.entertainment => const Color(0xFFD9825B),
    AppCategory.communication => const Color(0xFF4A9BB8),
    AppCategory.games => const Color(0xFF9B7BC8),
    AppCategory.productivity => const Color(0xFF3E9B7A),
    AppCategory.education => const Color(0xFFC9A23F),
    AppCategory.health => const Color(0xFFD46D8C),
    AppCategory.news => const Color(0xFF8A9A5B),
    AppCategory.shopping => const Color(0xFFC4789F),
    AppCategory.utilities => const Color(0xFF8C96A0),
    AppCategory.other => const Color(0xFFB3BAB6),
  };

  /// Tinted background behind a category icon.
  Color categorySoft(AppCategory c) =>
      category(c).withValues(alpha: _isDark ? 0.18 : 0.13);

  /// Card elevation: a hairline shadow in light mode, none in dark.
  List<BoxShadow> get cardShadow =>
      _isDark
          ? const []
          : [
            BoxShadow(color: shadow, blurRadius: 2, offset: const Offset(0, 1)),
          ];

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return t < 0.5 ? this : other;
  }
}
