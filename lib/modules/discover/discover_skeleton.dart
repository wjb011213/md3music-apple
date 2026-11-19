import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/apple_theme.dart';
import '../../widgets/app_animation.dart';

/// 首页内容与骨架共用尺寸，避免淡入时封面、标题或行高跳动。
abstract final class DiscoverCoverLayout {
  static const double size = 156;
  static const double radius = 6;
  static const double spacing = 16;
  static const double artworkGap = 7;
  static const double textGap = 2;
  static const borderRadius = BorderRadius.all(Radius.circular(radius));
  static const railPadding = EdgeInsets.symmetric(horizontal: 20);
  static const headerPadding = EdgeInsets.fromLTRB(20, 24, 20, 8);
  static const titleStyle = TextStyle(
    fontSize: 15, height: 1.3, fontWeight: FontWeight.w400,
  );
  static const subtitleStyle = TextStyle(
    fontSize: 13, height: 1.3, fontWeight: FontWeight.w400,
  );

  static double titleHeight(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(15) * 1.3;

  static double subtitleHeight(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(13) * 1.3;

  static double height(BuildContext context) =>
      size + artworkGap + titleHeight(context) + textGap +
      subtitleHeight(context) + 4;
}

/// 区块「骨架 → 真实内容」的淡入替换容器（发现页冷启动用）。
///
/// [loading] 为 true 时渲染「真实标题 + 骨架内容」，否则淡入 [content]。
/// 骨架标题不复用内容的 GlobalKey，避免交叉淡入期间出现重复 key。
class DiscoverSectionFadeSwap extends StatelessWidget {
  const DiscoverSectionFadeSwap({
    super.key,
    required this.title,
    required this.loading,
    required this.skeleton,
    required this.content,
  });

  final String title;
  final bool loading;
  final Widget skeleton;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      // 新旧两棵树钉住顶边，过渡只改变透明度，不改变区块起点。
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: AlignmentDirectional.topStart,
        children: [...previousChildren, ?currentChild],
      ),
      child: loading
          ? KeyedSubtree(
              key: ValueKey('discover-skeleton-$title'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: DiscoverCoverLayout.headerPadding,
                    child: Row(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.xs),
                            child: Text(
                              title,
                              style: AppleTypography.sectionTitle(
                                AppleColors.label(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        // 与真实 TextButton 同高，不放按钮或可聚焦对象。
                        const SizedBox(width: 48, height: 48),
                      ],
                    ),
                  ),
                  skeleton,
                ],
              ),
            )
          : KeyedSubtree(key: ValueKey('discover-content-$title'), child: content),
    );
  }
}

/// 歌曲区块的横向封面骨架；保留原构造参数以兼容已有调用方。
class DiscoverSongRowsSkeleton extends StatelessWidget {
  const DiscoverSongRowsSkeleton({super.key, this.rows = 4});

  final int rows;

  @override
  Widget build(BuildContext context) => _CoverCardsSkeleton(count: rows);
}

/// 新碟区块使用与歌曲相同的横向封面骨架。
class DiscoverAlbumGridSkeleton extends StatelessWidget {
  const DiscoverAlbumGridSkeleton({super.key, this.cells = 4});

  final int cells;

  @override
  Widget build(BuildContext context) => _CoverCardsSkeleton(count: cells);
}

class _CoverCardsSkeleton extends StatelessWidget {
  const _CoverCardsSkeleton({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: DiscoverCoverLayout.height(context),
        child: ListView.separated(
          primary: false,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: DiscoverCoverLayout.railPadding,
          itemCount: count,
          separatorBuilder: (_, _) =>
              const SizedBox(width: DiscoverCoverLayout.spacing),
          itemBuilder: (context, index) => SizedBox(
            key: ValueKey('discover-skeleton-card-$index'),
            width: DiscoverCoverLayout.size,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ShimmerLoading(
                  width: DiscoverCoverLayout.size,
                  height: DiscoverCoverLayout.size,
                  radius: DiscoverCoverLayout.radius,
                  diagonal: true,
                ),
                const SizedBox(height: DiscoverCoverLayout.artworkGap),
                SizedBox(
                  height: DiscoverCoverLayout.titleHeight(context),
                  child: const Align(
                    alignment: Alignment.centerLeft,
                    child: ShimmerLoading(
                      width: 136, height: 14, radius: 3, diagonal: true,
                    ),
                  ),
                ),
                const SizedBox(height: DiscoverCoverLayout.textGap),
                SizedBox(
                  height: DiscoverCoverLayout.subtitleHeight(context),
                  child: const Align(
                    alignment: Alignment.centerLeft,
                    child: ShimmerLoading(
                      width: 100, height: 12, radius: 3, diagonal: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
