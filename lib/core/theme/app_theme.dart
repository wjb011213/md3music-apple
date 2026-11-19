import 'dart:math' as math;

import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'apple_theme.dart';

/// 全局主题：以 iOS / Apple Music 的视觉语言为基准。
///
/// 颜色仍由「种子色」驱动（保留莫奈取色 / 封面取色 / 手动主题色），但只把
/// 种子色当作强调色，中性色、背景、卡片、分隔线一律使用 iOS 系统语义色，
/// 不再使用 Material 3 的 tonal surface 梯度。
class AppTheme {
  AppTheme._();

  /// 默认使用 Aria Music 玫红，保留其余可选强调色。
  /// 索引 0 是默认色，与 [defaultSeedColor] 保持一致。
  static const List<Color> presetSeedColors = [
    AppleColors.musicRed,
    AppleColors.blue,
    AppleColors.purple,
    AppleColors.teal,
    AppleColors.green,
    AppleColors.yellow,
    AppleColors.orange,
    AppleColors.red,
    AppleColors.pink,
  ];

  static const Color defaultSeedColor = AppleColors.musicRed;

  static ThemeData get lightTheme {
    final colorScheme = appleScheme(defaultSeedColor, Brightness.light);
    return _buildTheme(colorScheme, Brightness.light);
  }

  static ThemeData get darkTheme {
    final colorScheme = appleScheme(defaultSeedColor, Brightness.dark);
    return _buildTheme(colorScheme, Brightness.dark);
  }

  static ThemeData lightThemeFromSeed(
    Color seedColor, {
    String? fontFamily,
    Color? textColor,
    bool emphasized = false,
    NavigationDestinationLabelBehavior labelBehavior =
        NavigationDestinationLabelBehavior.alwaysShow,
    bool predictiveBack = false,
  }) {
    final colorScheme = appleScheme(
      seedColor,
      Brightness.light,
      textColor: textColor,
    );
    return _buildTheme(
      colorScheme,
      Brightness.light,
      fontFamily: fontFamily,
      emphasized: emphasized,
      labelBehavior: labelBehavior,
      predictiveBack: predictiveBack,
    );
  }

  static ThemeData darkThemeFromSeed(
    Color seedColor, {
    bool useOledBlack = false,
    String? fontFamily,
    Color? textColor,
    bool emphasized = false,
    NavigationDestinationLabelBehavior labelBehavior =
        NavigationDestinationLabelBehavior.alwaysShow,
    bool predictiveBack = false,
  }) {
    final colorScheme = appleScheme(
      seedColor,
      Brightness.dark,
      textColor: textColor,
      useOledBlack: useOledBlack,
    );
    return _buildTheme(
      colorScheme,
      Brightness.dark,
      fontFamily: fontFamily,
      emphasized: emphasized,
      labelBehavior: labelBehavior,
      predictiveBack: predictiveBack,
    );
  }

  /// 由种子色构建 iOS 语义色板。
  static ColorScheme appleScheme(
    Color seed,
    Brightness brightness, {
    Color? textColor,
    bool useOledBlack = false,
  }) {
    final isDark = brightness == Brightness.dark;
    final accent = _accent(seed, brightness);
    final surface = isDark
        ? (useOledBlack ? Colors.black : AppleColors.darkBackground)
        : AppleColors.lightBackground;
    final label = isDark ? AppleColors.darkLabel : AppleColors.lightLabel;
    final secondary = isDark
        ? AppleColors.darkSecondaryLabel
        : AppleColors.lightSecondaryLabel;
    final tertiary = isDark
        ? AppleColors.darkTertiaryLabel
        : AppleColors.lightTertiaryLabel;
    final separator = isDark
        ? AppleColors.darkSeparator
        : AppleColors.lightSeparator;
    final container = isDark
        ? (useOledBlack ? const Color(0xFF141414) : const Color(0xFF1C1C1E))
        : const Color(0xFFF2F2F7);
    final containerHigh = isDark
        ? (useOledBlack ? const Color(0xFF1A1A1A) : const Color(0xFF2C2C2E))
        : const Color(0xFFE9E9EE);
    final containerHighest = isDark
        ? const Color(0xFF3A3A3C)
        : const Color(0xFFE1E1E6);
    final primaryContainer = Color.alphaBlend(
      accent.withValues(alpha: isDark ? 0.24 : 0.12),
      surface,
    );
    final onPrimaryContainer = isDark
        ? _mix(accent, Colors.white, 0.35)
        : _mix(accent, Colors.black, 0.18);

    var scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness)
        .copyWith(
          primary: accent,
          onPrimary: _onColor(accent),
          primaryContainer: primaryContainer,
          onPrimaryContainer: onPrimaryContainer,
          secondary: accent,
          onSecondary: _onColor(accent),
          secondaryContainer: primaryContainer,
          onSecondaryContainer: onPrimaryContainer,
          tertiary: accent,
          onTertiary: _onColor(accent),
          tertiaryContainer: primaryContainer,
          onTertiaryContainer: onPrimaryContainer,
          error: isDark ? const Color(0xFFFF6961) : AppleColors.red,
          onError: Colors.white,
          surface: surface,
          onSurface: label,
          onSurfaceVariant: secondary,
          surfaceContainerLowest: surface,
          surfaceContainerLow: isDark
              ? (useOledBlack
                    ? const Color(0xFF0C0C0C)
                    : const Color(0xFF141416))
              : const Color(0xFFF7F7FA),
          surfaceContainer: container,
          surfaceContainerHigh: containerHigh,
          surfaceContainerHighest: containerHighest,
          surfaceDim: isDark ? Colors.black : const Color(0xFFE8E8ED),
          surfaceBright: isDark ? const Color(0xFF2C2C2E) : Colors.white,
          outline: tertiary,
          outlineVariant: separator,
          surfaceTint: Colors.transparent,
          inverseSurface: isDark ? Colors.white : const Color(0xFF1C1C1E),
          onInverseSurface: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          inversePrimary: _accent(
            seed,
            isDark ? Brightness.light : Brightness.dark,
          ),
          shadow: Colors.black,
          scrim: Colors.black,
        );

    if (textColor != null) {
      scheme = scheme.copyWith(
        onSurface: textColor,
        onSurfaceVariant: Color.lerp(textColor, scheme.surface, 0.35)!,
      );
    }
    return scheme;
  }

  static ThemeData _buildTheme(
    ColorScheme colorScheme,
    Brightness brightness, {
    String? fontFamily,
    bool emphasized = false,
    NavigationDestinationLabelBehavior labelBehavior =
        NavigationDestinationLabelBehavior.alwaysShow,
    bool predictiveBack = false,
  }) {
    final isLight = brightness == Brightness.light;
    final family = fontFamily ?? AppleTypography.fontFamily;
    final fallback = AppleTypography.fontFamilyFallback;
    final textTheme = emphasized
        ? M3ETypography.emphasized(
            AppleTypography.textTheme(
              colorScheme,
            ).apply(fontFamily: family, fontFamilyFallback: fallback),
            rond: 0,
          )
        : AppleTypography.textTheme(
            colorScheme,
          ).apply(fontFamily: family, fontFamilyFallback: fallback);
    final accent = colorScheme.primary;
    final secondary = colorScheme.onSurfaceVariant;

    TextStyle navStyle(
      Color color, {
      double size = 17,
      FontWeight weight = FontWeight.w600,
    }) => TextStyle(
      color: color,
      fontSize: size,
      fontWeight: weight,
      height: 1.25,
      letterSpacing: size >= 20 ? -0.4 : -0.2,
      fontFamily: family,
      fontFamilyFallback: fallback,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: brightness,
      scaffoldBackgroundColor: colorScheme.surface,
      // iOS 页面转场：新页右侧滑入，旧页左移 28%。
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          TargetPlatform.android: predictiveBack
              ? const ApplePredictiveBackPageTransitionsBuilder()
              : const ApplePageTransitionsBuilder(),
          TargetPlatform.iOS: const ApplePageTransitionsBuilder(),
          TargetPlatform.macOS: const ApplePageTransitionsBuilder(),
          TargetPlatform.windows: const ApplePageTransitionsBuilder(),
          TargetPlatform.linux: const ApplePageTransitionsBuilder(),
        },
      ),
      fontFamily: family,
      fontFamilyFallback: fallback,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      splashFactory: InkRipple.splashFactory,
      highlightColor: accent.withValues(alpha: 0.06),
      hoverColor: accent.withValues(alpha: 0.04),
      focusColor: accent.withValues(alpha: 0.08),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        titleTextStyle: navStyle(colorScheme.onSurface),
        iconTheme: IconThemeData(color: colorScheme.onSurface, size: 22),
        actionsIconTheme: IconThemeData(color: colorScheme.onSurface, size: 22),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
          statusBarBrightness: isLight ? Brightness.light : Brightness.dark,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        // 与参考一致：黑白纯色标签栏，靠极细分隔线界定边缘。
        backgroundColor: colorScheme.surface,
        indicatorColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        labelBehavior: labelBehavior,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? accent : secondary,
            size: selected ? 25 : 24,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? accent : secondary,
            fontSize: 10.5,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            letterSpacing: 0.1,
            height: 1.1,
            fontFamily: family,
            fontFamilyFallback: fallback,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: Colors.transparent,
        elevation: 0,
        minWidth: 80,
        minExtendedWidth: 256,
        selectedIconTheme: IconThemeData(color: accent, size: 24),
        unselectedIconTheme: IconThemeData(color: secondary, size: 24),
        selectedLabelTextStyle: TextStyle(
          color: accent,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          fontFamily: family,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: secondary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          fontFamily: family,
        ),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: AppleColors.cardOf(brightness),
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(16)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppleColors.cardOf(brightness),
        surfaceTintColor: Colors.transparent,
        elevation: 24,
        shadowColor: Colors.black.withValues(alpha: 0.25),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        titleTextStyle: navStyle(colorScheme.onSurface, size: 17),
        contentTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 13,
          height: 1.4,
          fontFamily: family,
          fontFamilyFallback: fallback,
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppleColors.cardOf(brightness),
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: AppleColors.cardOf(brightness),
        elevation: 0,
        modalElevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppleColors.cardOf(brightness),
        surfaceTintColor: Colors.transparent,
        elevation: 16,
        shadowColor: Colors.black.withValues(alpha: 0.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        textStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 15,
          letterSpacing: -0.1,
          fontFamily: family,
          fontFamilyFallback: fallback,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isLight
            ? const Color(0xFF1C1C1E)
            : const Color(0xFF2C2C2E),
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          height: 1.3,
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: _onColor(accent),
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: const CircleBorder(),
        sizeConstraints: const BoxConstraints.tightFor(width: 52, height: 52),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
        selectedColor: primaryContainerOf(colorScheme),
        labelStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          fontFamily: family,
          fontFamilyFallback: fallback,
        ),
        secondaryLabelStyle: TextStyle(
          color: colorScheme.onPrimaryContainer,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          fontFamily: family,
          fontFamilyFallback: fallback,
        ),
        shape: const StadiumBorder(),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accent,
        inactiveTrackColor: colorScheme.surfaceContainerHighest,
        thumbColor: Colors.white,
        overlayColor: accent.withValues(alpha: 0.12),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(
          enabledThumbRadius: 10,
          elevation: 3,
          pressedElevation: 5,
        ),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
        trackShape: const RoundedRectSliderTrackShape(),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: colorScheme.surfaceContainerHighest,
        circularTrackColor: colorScheme.surfaceContainerHighest,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accent;
          return isLight ? const Color(0xFFE9E9EA) : const Color(0xFF39393D);
        }),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accent;
          return Colors.transparent;
        }),
        checkColor: WidgetStatePropertyAll(_onColor(accent)),
        side: BorderSide(color: colorScheme.outline, width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accent;
          return colorScheme.outline;
        }),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? AppleColors.lightFill : AppleColors.darkFill,
        hintStyle: TextStyle(
          color: secondary,
          fontSize: 16,
          letterSpacing: -0.2,
          fontFamily: family,
          fontFamilyFallback: fallback,
        ),
        labelStyle: TextStyle(color: secondary, fontSize: 15),
        floatingLabelStyle: TextStyle(color: accent, fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: accent, width: 1.2),
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        minVerticalPadding: 8,
        iconColor: secondary,
        textColor: colorScheme.onSurface,
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 17,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.2,
          fontFamily: family,
          fontFamilyFallback: fallback,
        ),
        subtitleTextStyle: TextStyle(
          color: secondary,
          fontSize: 13,
          height: 1.3,
          fontFamily: family,
          fontFamilyFallback: fallback,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 0.5,
        space: 0.5,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: accent,
        unselectedLabelColor: secondary,
        labelStyle: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          fontFamily: family,
          fontFamilyFallback: fallback,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.2,
          fontFamily: family,
          fontFamilyFallback: fallback,
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        splashFactory: NoSplash.splashFactory,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: _onColor(accent),
          elevation: 0,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          // iOS 主按钮为胶囊形（Apple Music 的「播放」等均为全圆角）。
          shape: const StadiumBorder(),
          textStyle: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
            fontFamily: family,
            fontFamilyFallback: fallback,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          side: BorderSide(color: colorScheme.outlineVariant),
          // 与主按钮配套，次级按钮同样为胶囊形。
          shape: const StadiumBorder(),
          textStyle: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            fontFamily: family,
            fontFamilyFallback: fallback,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            fontFamily: family,
            fontFamilyFallback: fallback,
          ),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isLight ? const Color(0xFF3A3A3C) : const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 13),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      extensions: <ThemeExtension<dynamic>>[
        M3EBottomSheetThemeData(
          style: M3EBottomSheetStyle(
            backgroundColor: AppleColors.cardOf(brightness),
            borderRadius: 16,
            padding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  static Color primaryContainerOf(ColorScheme cs) => cs.primaryContainer;

  static Color _accent(Color seed, Brightness brightness) {
    if (seed == AppleColors.musicRed) return AppleColors.musicRed;
    final hsl = HSLColor.fromColor(seed);
    final isDark = brightness == Brightness.dark;
    return hsl
        .withSaturation(math.max(hsl.saturation, 0.62))
        .withLightness(isDark ? 0.66 : 0.48)
        .toColor();
  }

  static Color _onColor(Color color) =>
      color.computeLuminance() > 0.62 ? Colors.black : Colors.white;

  static Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t) ?? a;

  /// 文字阴影磅数默认值与可调范围。
  static const double defaultTextShadowBlur = 4.0;
  static const double minTextShadowBlur = 0.0;
  static const double maxTextShadowBlur = 50.0;

  static List<Shadow> textShadowsFor(
    Brightness brightness, {
    double blurRadius = defaultTextShadowBlur,
  }) {
    final isLight = brightness == Brightness.light;
    final blur = blurRadius.clamp(minTextShadowBlur, maxTextShadowBlur);
    final t =
        ((blur - defaultTextShadowBlur) /
                (maxTextShadowBlur - defaultTextShadowBlur))
            .clamp(0.0, 1.0);
    final shadow = Shadow(
      color: (isLight ? Colors.white : Colors.black).withValues(
        alpha: 0.6 + 0.35 * t,
      ),
      blurRadius: blur,
      offset: const Offset(0, 1),
    );
    return List<Shadow>.filled(1 + (3 * t).round(), shadow);
  }

  static TextTheme applyTextShadows(TextTheme base, List<Shadow> shadows) {
    TextStyle? withShadows(TextStyle? style) =>
        style?.copyWith(shadows: shadows);
    return base.copyWith(
      displayLarge: withShadows(base.displayLarge),
      displayMedium: withShadows(base.displayMedium),
      displaySmall: withShadows(base.displaySmall),
      headlineLarge: withShadows(base.headlineLarge),
      headlineMedium: withShadows(base.headlineMedium),
      headlineSmall: withShadows(base.headlineSmall),
      titleLarge: withShadows(base.titleLarge),
      titleMedium: withShadows(base.titleMedium),
      titleSmall: withShadows(base.titleSmall),
      bodyLarge: withShadows(base.bodyLarge),
      bodyMedium: withShadows(base.bodyMedium),
      bodySmall: withShadows(base.bodySmall),
      labelLarge: withShadows(base.labelLarge),
      labelMedium: withShadows(base.labelMedium),
      labelSmall: withShadows(base.labelSmall),
    );
  }

  static TextTheme stripTextShadows(TextTheme base) =>
      applyTextShadows(base, const <Shadow>[]);

  static TextStyle? withoutTextShadow(TextStyle? style) =>
      style?.copyWith(shadows: const <Shadow>[]);
}
