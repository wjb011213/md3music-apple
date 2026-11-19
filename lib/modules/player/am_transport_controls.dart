import 'package:material_ui/material_ui.dart';

import '../../core/build_flags.dart';
import '../../core/remote/tv_player_back_focus.dart';
import 'widgets/play_pause_morph_icon.dart';

/// AM 播放器的传输控件：白色实心切歌图标 + 白色圆底播放键。
/// 中央黑色 [PlayPauseMorphIcon] 保留原有双轨形变与播放态驱动。
class AMTransportControls extends StatefulWidget {
  const AMTransportControls({
    super.key,
    required this.isPlaying,
    this.onPrevious,
    this.onPlayPause,
    this.onNext,
    this.skipIconSize = 34,
    this.playIconSize = 42,
    this.spacing = 12,
    this.strokeWidth = 2.0,
    this.playIconColor = Colors.black,
    this.skipIconColor = Colors.white,
    this.morphDuration = const Duration(milliseconds: 280),
  });

  /// 当前是否正在播放：true 显示暂停形态，false 显示播放形态。
  final bool isPlaying;

  final VoidCallback? onPrevious;
  final VoidCallback? onPlayPause;
  final VoidCallback? onNext;

  /// 左右两侧按钮图标尺寸。
  final double skipIconSize;

  /// 中央播放按钮图标尺寸。
  final double playIconSize;

  /// 按钮间距。
  final double spacing;

  /// 保留旧调用方的参数兼容性；实心切歌图标不再使用描边宽度。
  final double strokeWidth;

  final Color playIconColor;
  final Color skipIconColor;

  /// play↔pause 形变时长。
  final Duration morphDuration;

  @override
  State<AMTransportControls> createState() => _AMTransportControlsState();
}

class _AMTransportControlsState extends State<AMTransportControls> {
  /// tv: 中央播放键的焦点节点——播放页返回键把焦点交回播放键
  /// （见 `tv_player_back_focus.dart` 的 `TvPlayerPlayFocusBridge`）。
  /// 非 TV 构建恒 null：不创建、不登记，`IconButton` 自建节点，触屏路径零变化。
  FocusNode? _tvPlayFocus;

  /// tv: 取播放键节点并登记到移交桥（登记幂等）。
  FocusNode? get _tvPlayFocusNode {
    if (!kTvBuild) return null;
    final FocusNode node = _tvPlayFocus ??= FocusNode(
      debugLabel: 'am_transport_play',
    );
    TvPlayerPlayFocusBridge.instance.register(node);
    return node;
  }

  @override
  void dispose() {
    // tv: 播放键节点随本 State 销毁，先摘登记再释放。
    final FocusNode? tvPlayFocus = _tvPlayFocus;
    if (tvPlayFocus != null) {
      TvPlayerPlayFocusBridge.instance.unregister(tvPlayFocus);
      tvPlayFocus.dispose();
      _tvPlayFocus = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 标准档 72dp 圆底 / 42dp 图标；窄面板按图标尺寸同比收缩。
    final playButtonSize = (widget.playIconSize * 72 / 42).clamp(48.0, 72.0);
    // 整簇自建重绘边界（修「Windows 鼠标点暂停整窗卡一下」）。
    //
    // 三颗按钮的按压水波画在各自 `IconButton` 内层 `Material` 的 ink 层上，
    // `markNeedsPaint` 会一路冒泡到**最近的重绘边界**；本簇外层没有边界时，
    // 一次点击的整段涟漪动画（约 200~600ms、满帧）会把最近边界内的整页重绘
    // ——AM 播放页里那是流光背景 + 歌词 + 写真，Windows 上表现为整窗掉帧。
    // 按空格不产生水波，所以同一条链路不卡，这正是历史反馈里的差异来源。
    // 在本簇自建边界后，涟漪只重绘这三颗按钮的矩形。纯增量：无布局、无焦点、
    // 无动画时长变化，TV / 触屏构建同构。
    return RepaintBoundary(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: '上一首',
            iconSize: widget.skipIconSize,
            color: widget.skipIconColor,
            onPressed: widget.onPrevious,
            icon: const Icon(Icons.skip_previous_rounded),
          ),
          SizedBox(width: widget.spacing),
          // 中央按钮：实心双轨形变。PlayPauseMorphIcon 内部自驱动
          // （isPlaying 翻转时前进/倒放），无需外部控制器。
          IconButton(
            tooltip: widget.isPlaying ? '暂停' : '播放',
            iconSize: widget.playIconSize,
            // tv: 播放键用本组件自持的节点（非 TV 构建传 null，IconButton 自建）。
            focusNode: _tvPlayFocusNode,
            onPressed: widget.onPlayPause,
            style: IconButton.styleFrom(
              foregroundColor: widget.playIconColor,
              backgroundColor: Colors.white,
              disabledBackgroundColor: Colors.white54,
              fixedSize: Size.square(playButtonSize),
              padding: EdgeInsets.zero,
              shape: const CircleBorder(),
            ),
            icon: PlayPauseMorphIcon(
              isPlaying: widget.isPlaying,
              size: widget.playIconSize.clamp(0.0, playButtonSize),
              color: widget.onPlayPause == null
                  ? Colors.black38
                  : widget.playIconColor,
              duration: widget.morphDuration,
            ),
          ),
          SizedBox(width: widget.spacing),
          IconButton(
            tooltip: '下一首',
            iconSize: widget.skipIconSize,
            color: widget.skipIconColor,
            onPressed: widget.onNext,
            icon: const Icon(Icons.skip_next_rounded),
          ),
        ],
      ),
    );
  }
}
