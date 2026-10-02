import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/main.dart';
import 'package:moumou/services/app_locale_settings.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_page_permission_test.dart' show MockPermissionHandlerPlatform;

/// **真实 App 冒烟测试**（必须有，别再删）。
///
/// 由来：阶段 2 曾在这里翻车——`main.dart` 拿 `MaterialApp` **之上**的 context 去
/// `AppLocalizations.of(context).navHome`，而 `Localizations` 是 MaterialApp 建在
/// 自己内部的 → 取到 null、它的 `!` 直接抛
/// `Null check operator used on a null value`，**启动即崩**。
/// `flutter analyze` 查不出这种错，当时 1805 个测试也全绿（因为**没有一个测试
/// pump 过真正的 `MoumouApp`**），只有真机安装才暴露。本文件就是那道防线：
/// 以后凡是改 `main.dart`（导航文案、locale、主题接线、首帧门禁）都必须先过它。
void main() {
  const channel = MethodChannel('moumou/video_info');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppLocaleSettings.instance.resetForTest();
    PermissionHandlerPlatform.instance = MockPermissionHandlerPlatform();
    // 原生通道一律回空：冒烟测试不依赖真机
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getVideos') return <dynamic>[];
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('MoumouApp 能起起来：无异常，底部两个导航项都在（中文）', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MoumouApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    expect(find.text('首页'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
  });

  testWidgets('语言偏好为 en 时，导航项是英文（locale 接线有效）', (tester) async {
    SharedPreferences.setMockInitialValues({'app_locale': 'en'});
    AppLocaleSettings.instance.resetForTest();

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MoumouApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Mine'), findsOneWidget);
  });
}
