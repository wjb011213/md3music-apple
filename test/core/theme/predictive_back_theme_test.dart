import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:md3music/core/theme/app_theme.dart';
import 'package:md3music/core/theme/apple_theme.dart';

void main() {
  group('iOS 页面转场主题接线', () {
    test('predictiveBack=false 使用标准 iOS 滑入转场', () {
      final theme = AppTheme.lightThemeFromSeed(
        AppTheme.presetSeedColors.first,
        predictiveBack: false,
      );
      final builder =
          theme.pageTransitionsTheme.builders[TargetPlatform.android];
      expect(builder, isA<ApplePageTransitionsBuilder>());
      expect(builder, isNot(isA<ApplePredictiveBackPageTransitionsBuilder>()));
    });

    test('predictiveBack=true 切换到预测性返回过渡', () {
      final theme = AppTheme.lightThemeFromSeed(
        AppTheme.presetSeedColors.first,
        predictiveBack: true,
      );
      final builder =
          theme.pageTransitionsTheme.builders[TargetPlatform.android];
      expect(builder, isA<ApplePredictiveBackPageTransitionsBuilder>());
    });

    test('深色主题同两态生效', () {
      final off = AppTheme.darkThemeFromSeed(
        AppTheme.presetSeedColors.first,
        predictiveBack: false,
      );
      final on = AppTheme.darkThemeFromSeed(
        AppTheme.presetSeedColors.first,
        predictiveBack: true,
      );
      expect(
        on.pageTransitionsTheme.builders[TargetPlatform.android],
        isA<ApplePredictiveBackPageTransitionsBuilder>(),
      );
      expect(
        off.pageTransitionsTheme.builders[TargetPlatform.android],
        isNot(isA<ApplePredictiveBackPageTransitionsBuilder>()),
      );
    });
  });

  group('Aria 视觉规范', () {
    test('浅深色都保持品牌玫红和纯色底栏', () {
      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        expect(theme.colorScheme.primary, const Color(0xFFFA2D48));
        expect(
          theme.navigationBarTheme.backgroundColor,
          theme.colorScheme.surface,
        );
        expect(theme.navigationBarTheme.indicatorColor, Colors.transparent);
        expect(theme.textTheme.displayLarge?.fontSize, 34);
        expect(theme.textTheme.bodyLarge?.fontWeight, FontWeight.w400);
      }
      expect(
        AppTheme.lightTheme.colorScheme.surfaceContainerLow,
        const Color(0xFFF7F7FA),
      );
      expect(
        AppTheme.darkTheme.colorScheme.onSurfaceVariant,
        const Color(0xFF98989F),
      );
    });

    test('自定义强调色仍可用', () {
      final theme = AppTheme.lightThemeFromSeed(AppleColors.green);
      expect(theme.colorScheme.primary, isNot(AppleColors.musicRed));
      expect(theme.colorScheme.surface, Colors.white);
    });

    for (final dark in [false, true]) {
      testWidgets('窄屏大字体下标题与分栏不溢出 dark=$dark', (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(1.5)),
              child: child!,
            ),
            home: DefaultTabController(
              length: 3,
              child: Scaffold(
                body: SafeArea(
                  child: Column(
                    children: [
                      const AppleLargeTitle(title: '现在就听'),
                      TabBar(
                        indicator: const AppleTabIndicator(
                          color: AppleColors.musicRed,
                        ),
                        tabs: const [
                          Tab(text: '歌单'),
                          Tab(text: '专辑'),
                          Tab(text: '歌手'),
                        ],
                      ),
                      const AppleListSection(
                        children: [
                          AppleListRow(
                            icon: Icons.history,
                            title: '最近播放',
                            showChevron: true,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('现在就听'), findsOneWidget);
      });
    }
  });
}
