// AM 传输控件回归：72dp 白色圆底 / 42dp 黑色形变图标、实心 rounded
// 切歌图标、播放态与独立回调，以及窄面板布局和 TV 焦点桥生命周期。
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:md3music/core/build_flags.dart';
import 'package:md3music/core/remote/tv_player_back_focus.dart';
import 'package:md3music/modules/player/am_transport_controls.dart';
import 'package:md3music/modules/player/widgets/play_pause_morph_icon.dart';

void _noop() {}

void main() {
  const panelKey = ValueKey('transport-panel');
  final buttons = find.byType(IconButton);
  final morphIcon = find.byType(PlayPauseMorphIcon);

  Widget host({
    required bool isPlaying,
    VoidCallback? onPrevious = _noop,
    VoidCallback? onPlayPause = _noop,
    VoidCallback? onNext = _noop,
    double width = 320,
    double height = 96,
    double skipIconSize = 34,
    double playIconSize = 42,
    double spacing = 12,
    bool scaleDown = false,
  }) {
    final controls = AMTransportControls(
      isPlaying: isPlaying,
      onPrevious: onPrevious,
      onPlayPause: onPlayPause,
      onNext: onNext,
      skipIconSize: skipIconSize,
      playIconSize: playIconSize,
      spacing: spacing,
    );
    return MaterialApp(
      theme: ThemeData(platform: TargetPlatform.android),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            key: panelKey,
            width: width,
            height: height,
            child: Center(
              child: scaleDown
                  ? FittedBox(fit: BoxFit.scaleDown, child: controls)
                  : controls,
            ),
          ),
        ),
      ),
    );
  }

  void expectButtonsInsidePanel(WidgetTester tester) {
    final panel = tester.getRect(find.byKey(panelKey));
    expect(buttons, findsNWidgets(3));
    for (var i = 0; i < 3; i++) {
      final rect = tester.getRect(buttons.at(i));
      expect(rect.left, greaterThanOrEqualTo(panel.left - 1e-6));
      expect(rect.right, lessThanOrEqualTo(panel.right + 1e-6));
      expect(rect.top, greaterThanOrEqualTo(panel.top - 1e-6));
      expect(rect.bottom, lessThanOrEqualTo(panel.bottom + 1e-6));
    }
    expect(tester.takeException(), isNull);
  }

  testWidgets('默认形变时长 280ms 传入中央图标', (tester) async {
    await tester.pumpWidget(host(isPlaying: false));

    final controls = tester.widget<AMTransportControls>(
      find.byType(AMTransportControls),
    );
    expect(controls.morphDuration, const Duration(milliseconds: 280));
    expect(
      tester.widget<PlayPauseMorphIcon>(morphIcon).duration,
      controls.morphDuration,
    );
  });

  testWidgets('中央按钮为实际 72dp 白色圆底、居中 42dp 黑色图标', (tester) async {
    await tester.pumpWidget(host(isPlaying: false));
    await tester.pumpAndSettle();

    final middle = tester.widget<IconButton>(buttons.at(1));
    final style = middle.style!;
    expect(style.backgroundColor!.resolve(<WidgetState>{}), Colors.white);
    expect(style.foregroundColor!.resolve(<WidgetState>{}), Colors.black);
    expect(style.shape!.resolve(<WidgetState>{}), isA<CircleBorder>());
    expect(style.fixedSize!.resolve(<WidgetState>{}), const Size.square(72));
    expect(style.padding!.resolve(<WidgetState>{}), EdgeInsets.zero);
    expect(tester.getSize(buttons.at(1)), const Size.square(72));

    final material = find.descendant(
      of: buttons.at(1),
      matching: find.byType(Material),
    );
    expect(tester.getSize(material), const Size.square(72));
    expect(tester.widget<Material>(material).color, Colors.white);
    expect(tester.widget<Material>(material).shape, isA<CircleBorder>());

    final icon = tester.widget<PlayPauseMorphIcon>(morphIcon);
    expect(icon.color, Colors.black);
    expect(icon.size, 42.0);
    expect(tester.getSize(morphIcon), const Size.square(42));
    expect(tester.getCenter(morphIcon), tester.getCenter(buttons.at(1)));
  });

  testWidgets('上一首/下一首为 34dp 白色实心 rounded 图标', (tester) async {
    await tester.pumpWidget(host(isPlaying: false));

    expect(buttons, findsNWidgets(3));
    expect(morphIcon, findsOneWidget);
    for (final entry in <int, IconData>{
      0: Icons.skip_previous_rounded,
      2: Icons.skip_next_rounded,
    }.entries) {
      final button = tester.widget<IconButton>(buttons.at(entry.key));
      expect(button.icon, isA<Icon>());
      expect((button.icon as Icon).icon, entry.value);
      expect(button.iconSize, 34.0);
      expect(button.color, Colors.white);
      expect(find.byIcon(entry.value), findsOneWidget);
      expect(tester.getSize(find.byIcon(entry.value)), const Size.square(34));
    }
    expect(find.byTooltip('上一首'), findsOneWidget);
    expect(find.byTooltip('下一首'), findsOneWidget);
  });

  for (final isPlaying in <bool>[false, true]) {
    testWidgets('isPlaying=$isPlaying 初始形态与播放/暂停提示一致', (tester) async {
      await tester.pumpWidget(host(isPlaying: isPlaying));

      expect(tester.widget<PlayPauseMorphIcon>(morphIcon).isPlaying, isPlaying);
      expect(
        tester.state<PlayPauseMorphIconState>(morphIcon).progress,
        isPlaying ? 1.0 : 0.0,
      );
      expect(find.byTooltip(isPlaying ? '暂停' : '播放'), findsOneWidget);
      expect(find.byTooltip(isPlaying ? '播放' : '暂停'), findsNothing);
    });

    testWidgets('isPlaying=$isPlaying 三个按钮分别只触发自己的回调一次', (tester) async {
      final calls = <int>[0, 0, 0];
      await tester.pumpWidget(
        host(
          isPlaying: isPlaying,
          onPrevious: () => calls[0]++,
          onPlayPause: () => calls[1]++,
          onNext: () => calls[2]++,
        ),
      );

      await tester.tap(find.byTooltip('上一首'));
      await tester.pumpAndSettle();
      expect(calls, <int>[1, 0, 0]);
      await tester.tap(find.byTooltip(isPlaying ? '暂停' : '播放'));
      await tester.pumpAndSettle();
      expect(calls, <int>[1, 1, 0]);
      await tester.tap(find.byTooltip('下一首'));
      await tester.pumpAndSettle();
      expect(calls, <int>[1, 1, 1]);
      // 控件只发回调，不自行改变外部传入的播放态。
      expect(
        tester.state<PlayPauseMorphIconState>(morphIcon).progress,
        isPlaying ? 1.0 : 0.0,
      );
    });
  }

  testWidgets('播放态双向更新保留 State，经过中间帧到达正确端点', (tester) async {
    await tester.pumpWidget(host(isPlaying: false));
    final state = tester.state<PlayPauseMorphIconState>(morphIcon);

    for (final isPlaying in <bool>[true, false]) {
      await tester.pumpWidget(host(isPlaying: isPlaying));
      expect(tester.state<PlayPauseMorphIconState>(morphIcon), same(state));
      expect(find.byTooltip(isPlaying ? '暂停' : '播放'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 60));
      expect(state.progress, greaterThan(0.0));
      expect(state.progress, lessThan(1.0));
      await tester.pumpAndSettle();
      expect(state.progress, isPlaying ? 1.0 : 0.0);
      expect(tester.getSize(buttons.at(1)), const Size.square(72));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('空回调禁用三键，中央保留淡白圆底与黑色禁用图标', (tester) async {
    await tester.pumpWidget(
      host(isPlaying: false, onPrevious: null, onPlayPause: null, onNext: null),
    );

    for (final button in tester.widgetList<IconButton>(buttons)) {
      expect(button.onPressed, isNull);
    }
    final middle = tester.widget<IconButton>(buttons.at(1));
    expect(
      middle.style!.backgroundColor!.resolve(<WidgetState>{
        WidgetState.disabled,
      }),
      Colors.white54,
    );
    expect(tester.widget<PlayPauseMorphIcon>(morphIcon).color, Colors.black38);
    expect(tester.getSize(buttons.at(1)), const Size.square(72));
    await tester.tap(buttons.at(1));
    await tester.pumpAndSettle();
    expect(tester.state<PlayPauseMorphIconState>(morphIcon).progress, 0.0);
    expect(tester.takeException(), isNull);
  });

  // 窄面板使用调用方的 30/36/8 档；更小图标还必须守住 48dp 圆底下限。
  for (final scenario in [
    (width: 200.0, height: 72.0, skip: 34.0, play: 42.0, gap: 12.0, size: 72.0),
    (
      width: 180.0,
      height: 64.0,
      skip: 30.0,
      play: 36.0,
      gap: 8.0,
      size: 432 / 7,
    ),
    (width: 160.0, height: 48.0, skip: 24.0, play: 24.0, gap: 8.0, size: 48.0),
  ]) {
    testWidgets('${scenario.width}dp 窄面板两态及形变帧不溢出', (tester) async {
      for (final isPlaying in <bool>[false, true]) {
        await tester.pumpWidget(
          host(
            isPlaying: isPlaying,
            width: scenario.width,
            height: scenario.height,
            skipIconSize: scenario.skip,
            playIconSize: scenario.play,
            spacing: scenario.gap,
          ),
        );
        expectButtonsInsidePanel(tester);
        await tester.pump(const Duration(milliseconds: 60));
        expectButtonsInsidePanel(tester);
        await tester.pumpAndSettle();
        expectButtonsInsidePanel(tester);
        final size = tester.getSize(buttons.at(1));
        expect(size.width, closeTo(scenario.size, 1e-6));
        expect(size.height, closeTo(scenario.size, 1e-6));
        expect(tester.getSize(morphIcon), Size.square(scenario.play));
      }
    });
  }

  testWidgets('调用方 scaleDown 适配 120dp 极窄槽，三键仍可点击且无溢出', (tester) async {
    final calls = <int>[0, 0, 0];
    await tester.pumpWidget(
      host(
        isPlaying: false,
        width: 120,
        height: 72,
        scaleDown: true,
        onPrevious: () => calls[0]++,
        onPlayPause: () => calls[1]++,
        onNext: () => calls[2]++,
      ),
    );
    expectButtonsInsidePanel(tester);
    for (var i = 0; i < 3; i++) {
      await tester.tap(buttons.at(i));
      await tester.pumpAndSettle();
      expectButtonsInsidePanel(tester);
    }
    expect(calls, <int>[1, 1, 1]);
  });

  testWidgets('播放键焦点节点按 TV 构建登记、重建复用、卸载清理', (tester) async {
    final bridge = TvPlayerPlayFocusBridge.instance;
    expect(bridge.hasNodes, isFalse);
    await tester.pumpWidget(host(isPlaying: false));
    final node = tester.widget<IconButton>(buttons.at(1)).focusNode;

    if (kTvBuild) {
      expect(node, isNotNull);
      expect(node!.debugLabel, 'am_transport_play');
      expect(bridge.hasNodes, isTrue);
      expect(bridge.focusPlay(), isTrue);
      await tester.pumpAndSettle();
      expect(node.hasFocus, isTrue);
    } else {
      expect(node, isNull);
      expect(bridge.hasNodes, isFalse);
    }

    await tester.pumpWidget(host(isPlaying: true));
    await tester.pumpAndSettle();
    expect(tester.widget<IconButton>(buttons.at(1)).focusNode, same(node));
    if (kTvBuild) expect(node!.hasFocus, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(bridge.hasNodes, isFalse);
    expect(bridge.focusPlay(), isFalse);
    expect(tester.takeException(), isNull);
  });
}
