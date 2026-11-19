import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';

/// 设置分类与详情页共用的分组标题，不额外制造独立卡片。
class SettingsGroupHeading extends StatelessWidget {
  const SettingsGroupHeading(
    this.title, {
    super.key,
    this.first = false,
  });

  final String title;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    // iOS 分组标题：小号灰色大写标签，直接落在分组卡片上方，不再画分隔线。
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        first ? AppSpacing.lg : AppSpacing.xl,
        AppSpacing.xxl,
        AppSpacing.sm,
      ),
      child: Semantics(
        header: true,
        child: Text(
          title,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
            fontSize: 13,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.1,
          ),
        ),
      ),
    );
  }
}

/// 分区内的子组标签：层级低于 [SettingsGroupHeading]、高于普通设置行。
///
/// 用于按钮组等非 ListTile 控件的组标题（如「网络音质」「失去音频焦点时」）。
/// 不加分隔线、不用 primary 色，避免像段标题一样过度切割分区。
class SettingsSubGroupLabel extends StatelessWidget {
  const SettingsSubGroupLabel(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: theme.textTheme.titleSmall?.copyWith(
        color: theme.colorScheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
