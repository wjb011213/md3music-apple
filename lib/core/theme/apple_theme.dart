import 'package:flutter/widgets.dart'
    show
        BouncingScrollPhysics,
        ScrollBehavior,
        ScrollPhysics,
        ScrollableDetails;
import 'package:material_ui/material_ui.dart';

/// iOS / Apple Music 设计语言的基础令牌与共享组件。
///
/// 这里只放「跨页面复用」的视觉原语，不承载业务逻辑。颜色一律走
/// `Theme.of(context).colorScheme` 或本文件的语义色，避免页面里再写死
/// Material 3 的 surface 层级。
abstract final class AppleColors {
  AppleColors._();

  // Aria Music 的品牌强调色在浅色与深色中保持一致。
  static const Color musicRed = Color(0xFFFA2D48);
  static const Color blue = Color(0xFF007AFF);
  static const Color green = Color(0xFF34C759);
  static const Color indigo = Color(0xFF5856D6);
  static const Color orange = Color(0xFFFF9500);
  static const Color pink = Color(0xFFFF2D55);
  static const Color purple = Color(0xFFAF52DE);
  static const Color red = Color(0xFFFF3B30);
  static const Color teal = Color(0xFF5AC8FA);
  static const Color yellow = Color(0xFFFFCC00);

  // ---- 中性色 ----
  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightGroupedBackground = Color(0xFFF2F2F7);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightFill = Color(0xFFE9E9EE);
  static const Color lightLabel = Color(0xFF000000);
  static const Color lightSecondaryLabel = Color(0xFF6E6E73);
  static const Color lightTertiaryLabel = Color(0xFFAEAEB2);
  static const Color lightSeparator = Color(0xFFE5E5EA);

  static const Color darkBackground = Color(0xFF000000);
  static const Color darkGroupedBackground = Color(0xFF000000);
  static const Color darkCard = Color(0xFF1C1C1E);
  static const Color darkFill = Color(0xFF2C2C2E);
  static const Color darkLabel = Color(0xFFFFFFFF);
  static const Color darkSecondaryLabel = Color(0xFF98989F);
  static const Color darkTertiaryLabel = Color(0xFF636366);
  static const Color darkSeparator = Color(0xFF2C2C2E);

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color background(BuildContext context) =>
      isDark(context) ? darkBackground : lightBackground;

  static Color groupedBackground(BuildContext context) =>
      isDark(context) ? darkGroupedBackground : lightGroupedBackground;

  static Color card(BuildContext context) =>
      isDark(context) ? darkCard : lightCard;

  static Color cardOf(Brightness brightness) =>
      brightness == Brightness.dark ? darkCard : lightCard;

  static Color backgroundOf(Brightness brightness) =>
      brightness == Brightness.dark ? darkBackground : lightBackground;

  static Color fill(BuildContext context) =>
      isDark(context) ? darkFill : lightFill;

  static Color label(BuildContext context) =>
      isDark(context) ? darkLabel : lightLabel;

  static Color secondaryLabel(BuildContext context) =>
      isDark(context) ? darkSecondaryLabel : lightSecondaryLabel;

  static Color tertiaryLabel(BuildContext context) =>
      isDark(context) ? darkTertiaryLabel : lightTertiaryLabel;

  static Color separator(BuildContext context) =>
      isDark(context) ? darkSeparator : lightSeparator;

  static Color accent(BuildContext context) =>
      Theme.of(context).colorScheme.primary;

  /// 导航栏 / 标签栏底色：与页面同色但略透，滚动内容从下方掠过时不会突兀。
  static Color bar(BuildContext context, {double opacity = 0.94}) =>
      (isDark(context) ? darkCard : lightBackground).withValues(alpha: opacity);
}

/// iOS 字号 / 字重 / 行高。
abstract final class AppleTypography {
  AppleTypography._();

  static const String fontFamily = 'Inter';
  static const List<String> fontFamilyFallback = [
    'MiSans',
    'HarmonyOS Sans SC',
    'PingFang SC',
    'Hiragino Sans GB',
    'Noto Sans CJK SC',
    'Noto Sans SC',
    'Source Han Sans SC',
    'Microsoft YaHei',
    'sans-serif',
  ];

  static TextStyle largeTitle(Color color) => TextStyle(
    color: color,
    fontSize: 34,
    fontWeight: FontWeight.w700,
    height: 1.18,
    letterSpacing: -0.8,
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
  );

  static TextStyle navTitle(Color color) => TextStyle(
    color: color,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: -0.2,
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
  );

  static TextStyle sectionTitle(Color color) => TextStyle(
    color: color,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.24,
    letterSpacing: -0.4,
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
  );

  static TextTheme textTheme(ColorScheme cs) {
    TextStyle style(
      double size,
      FontWeight weight,
      double height,
      double spacing, {
      Color? color,
    }) => TextStyle(
      color: color ?? cs.onSurface,
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: spacing,
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
    );

    return TextTheme(
      displayLarge: style(34, FontWeight.w700, 1.18, -0.8),
      displayMedium: style(28, FontWeight.w700, 1.2, -0.6),
      displaySmall: style(24, FontWeight.w700, 1.22, -0.5),
      headlineLarge: style(34, FontWeight.w700, 1.18, -0.8),
      headlineMedium: style(28, FontWeight.w700, 1.2, -0.6),
      headlineSmall: style(22, FontWeight.w700, 1.24, -0.4),
      titleLarge: style(20, FontWeight.w600, 1.25, -0.3),
      titleMedium: style(17, FontWeight.w600, 1.29, -0.2),
      titleSmall: style(15, FontWeight.w500, 1.27, -0.1),
      bodyLarge: style(17, FontWeight.w400, 1.29, -0.2),
      bodyMedium: style(15, FontWeight.w400, 1.33, -0.1),
      bodySmall: style(13, FontWeight.w400, 1.31, 0),
      labelLarge: style(15, FontWeight.w500, 1.27, -0.1),
      labelMedium: style(12, FontWeight.w500, 1.25, 0),
      labelSmall: style(10, FontWeight.w500, 1.2, 0.1),
    );
  }
}

/// 页面转场：新页自右滑入、旧页向左轻推（iOS 风格），并带轻微淡入。
class ApplePageTransitionsBuilder extends PageTransitionsBuilder {
  const ApplePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (route.isFirst) return child;
    final enter = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final exit = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final slide = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(enter);
    final fade = Tween<double>(begin: 0.92, end: 1).animate(enter);
    final parallax = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-0.28, 0),
    ).animate(exit);
    final transitioned = SlideTransition(
      position: parallax,
      child: SlideTransition(
        position: slide,
        child: FadeTransition(opacity: fade, child: child),
      ),
    );
    // 壁纸模式：转场期间不叠加任何局部不透明背景，被覆盖的旧页先让位，
    // 避免与全局壁纸层交接时闪色（沿用原主题的处理口径）。
    final wallpaper =
        Theme.of(context).scaffoldBackgroundColor == Colors.transparent;
    if (!wallpaper) return transitioned;
    return AnimatedBuilder(
      animation: secondaryAnimation,
      child: transitioned,
      builder: (context, content) => Offstage(
        offstage:
            secondaryAnimation.status != AnimationStatus.dismissed &&
            !route.popGestureInProgress,
        child: content,
      ),
    );
  }
}

/// 开启「预测性返回」时使用的同一套 iOS 转场（保留类型区分，便于设置页与测试
/// 判断当前是否走预测性返回分支）。
class ApplePredictiveBackPageTransitionsBuilder
    extends ApplePageTransitionsBuilder {
  const ApplePredictiveBackPageTransitionsBuilder();
}

/// 全局滚动行为：橡皮筋 + 去掉 Android 的拉伸辉光。
class AppleScrollBehavior extends ScrollBehavior {
  const AppleScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}

/// Aria 的文字分栏：选中项下方固定 22dp 短线，不填充整个标签。
class AppleTabIndicator extends Decoration {
  const AppleTabIndicator({required this.color});

  final Color color;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _AppleTabIndicatorPainter(color, onChanged);
}

class _AppleTabIndicatorPainter extends BoxPainter {
  _AppleTabIndicatorPainter(this.color, super.onChanged);
  final Color color;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null) return;
    final width = size.width.clamp(0.0, 22.0).toDouble();
    final rect = Rect.fromLTWH(
      offset.dx + (size.width - width) / 2,
      offset.dy + size.height - 3,
      width,
      2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(1)),
      Paint()..color = color,
    );
  }
}

/// iOS 大标题（页面内容顶部使用，不放进 AppBar）。
class AppleLargeTitle extends StatelessWidget {
  const AppleLargeTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 12),
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final color = AppleColors.label(context);
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppleTypography.largeTitle(color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: AppleColors.secondaryLabel(context),
                      fontSize: 15,
                      height: 1.3,
                      letterSpacing: -0.1,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
  }
}

/// 区块标题 +「查看全部」。
class AppleSectionHeader extends StatelessWidget {
  const AppleSectionHeader({
    super.key,
    required this.title,
    this.trailingLabel,
    this.onTrailing,
    this.padding = const EdgeInsets.fromLTRB(20, 18, 16, 8),
  });

  final String title;
  final String? trailingLabel;
  final VoidCallback? onTrailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final accent = AppleColors.accent(context);
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: AppleTypography.sectionTitle(AppleColors.label(context)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onTrailing != null)
            InkWell(
              onTap: onTrailing,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      trailingLabel ?? '查看全部',
                      style: TextStyle(
                        color: accent,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.1,
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 18, color: accent),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// iOS 分组列表（设置 / 账户等页面使用）。
class AppleListSection extends StatelessWidget {
  const AppleListSection({
    super.key,
    this.header,
    this.footer,
    required this.children,
    this.margin = const EdgeInsets.fromLTRB(20, 0, 20, 18),
  });

  final String? header;
  final String? footer;
  final List<Widget> children;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(
          Divider(
            height: 0.5,
            thickness: 0.5,
            indent:
                children[i] is AppleListRow &&
                    (children[i] as AppleListRow).icon != null
                ? 57
                : 16,
            endIndent: 0,
            color: AppleColors.separator(context).withValues(alpha: 0.55),
          ),
        );
      }
      rows.add(children[i]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (header != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 0, 32, 7),
            child: Text(
              header!.toUpperCase(),
              style: TextStyle(
                color: AppleColors.secondaryLabel(context),
                fontSize: 13,
                fontWeight: FontWeight.w400,
                letterSpacing: -0.1,
              ),
            ),
          ),
        Container(
          margin: margin,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(children: rows),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 0, 32, 18),
            child: Text(
              footer!,
              style: TextStyle(
                color: AppleColors.secondaryLabel(context),
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
      ],
    );
  }
}

/// iOS 列表行：彩色图标方块 + 标题 + 副标题 + 右侧内容。
class AppleListRow extends StatelessWidget {
  const AppleListRow({
    super.key,
    this.icon,
    this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.showChevron = false,
    this.titleColor,
  });

  final IconData? icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final titleStyle = TextStyle(
      color: titleColor ?? AppleColors.label(context),
      fontSize: 17,
      height: 1.3,
      letterSpacing: -0.2,
    );
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: 29,
              height: 29,
              decoration: BoxDecoration(
                color: iconColor ?? AppleColors.accent(context),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(icon, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: titleStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: AppleColors.secondaryLabel(context),
                      fontSize: 13,
                      height: 1.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
          if (showChevron)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Icon(
                Icons.chevron_right,
                size: 20,
                color: AppleColors.tertiaryLabel(context),
              ),
            ),
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(onTap: onTap, child: content);
  }
}

/// iOS 搜索框：灰底、圆角 10、左侧放大镜。
class AppleSearchField extends StatelessWidget {
  const AppleSearchField({
    super.key,
    required this.controller,
    this.focusNode,
    this.hintText = '搜索',
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.onClear,
    this.autofocus = false,
    this.height = 38,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final VoidCallback? onClear;
  final bool autofocus;
  final double height;

  @override
  Widget build(BuildContext context) {
    final hasText = controller.text.isNotEmpty;
    return SizedBox(
      height: height,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: autofocus,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        onTap: onTap,
        textAlignVertical: TextAlignVertical.center,
        style: TextStyle(
          color: AppleColors.label(context),
          fontSize: 16,
          letterSpacing: -0.2,
        ),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: AppleColors.fill(context),
          hintText: hintText,
          hintStyle: TextStyle(
            color: AppleColors.secondaryLabel(context),
            fontSize: 16,
            letterSpacing: -0.2,
          ),
          prefixIcon: Icon(
            Icons.search,
            size: 18,
            color: AppleColors.secondaryLabel(context),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 34,
            minHeight: 34,
          ),
          suffixIcon: hasText && onClear != null
              ? IconButton(
                  onPressed: onClear,
                  icon: Icon(
                    Icons.cancel,
                    size: 17,
                    color: AppleColors.tertiaryLabel(context),
                  ),
                  visualDensity: VisualDensity.compact,
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 8,
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
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
