/// 多语言测试夹具（阶段 0 建，各阶段复用）。
///
/// 为什么需要：widget 测试环境的平台 locale 实测是 `en_US`
/// （`locales = [en_US, zh_CN]`，见 `docs/archive/i18n-migration-plan/04-data-baseline.md` §10）。
/// 接入 l10n 并支持 `en` 之后，**没钉 locale 的 widget 测试会渲染英文**，
/// 185 个测试文件里的 535 处 `find.text('中文')` 断言会整片失败。
/// 夹具的作用就是把测试 locale 钉回简体中文。
///
/// 用法（三选一，挑对被测文件改动最小的那个）：
/// 1. 全局钉平台 locale：[pinPlatformLocaleZh]（放 `setUp` 里，或文件首个测试开头）；
/// 2. 直接替换 pumpWidget：`await pumpAppZh(tester, MyWidget())`；
/// 3. 测试自带 `MaterialApp` 结构（本仓库多数如此）时，把三件套拼进原有
///    `MaterialApp`：`locale: kTestLocaleZh`、
///    `localizationsDelegates: kTestLocalizationDelegates`、
///    `supportedLocales: kTestSupportedLocales`。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/l10n/app_localizations.dart';
import 'package:moumou/services/app_locale_settings.dart';

/// 测试钉死的语言：简体中文（与 App 默认语言一致）
const Locale kTestLocaleZh = Locale(AppLocaleSettings.zhCode);

/// 测试用的**繁体** locale（繁体轮阶段 6 新增）。
///
/// ⚠️ 必须与生成物 `supportedLocales` 里的写法**逐字一致**：
/// `Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')`。
/// 写成 `Locale('zh_Hant')`（languageCode 变成 `zh_Hant`、scriptCode 为空）
/// 既不等于这一项、也不等于 `Locale('zh')`，解析时**静默回落简体**。
const Locale kTestLocaleZhHant =
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');

/// `MaterialApp.localizationsDelegates` 的测试直用值
const List<LocalizationsDelegate<dynamic>> kTestLocalizationDelegates =
    AppLocalizations.localizationsDelegates;

/// `MaterialApp.supportedLocales` 的测试直用值
const List<Locale> kTestSupportedLocales = AppLocalizations.supportedLocales;

/// 把平台 locale 钉成简体中文。
///
/// `locales` 才是 `WidgetsApp` 解析 locale 时读的列表（`locale` 只是首项），
/// 两个都设，避免不同 Flutter 版本读不同字段。
void pinPlatformLocaleZh() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  binding.platformDispatcher.localeTestValue = kTestLocaleZh;
  binding.platformDispatcher.localesTestValue = const <Locale>[kTestLocaleZh];
}

/// 用简体中文环境 pump 一个 widget（自带 `MaterialApp` 外壳）。
Future<void> pumpAppZh(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: kTestLocaleZh,
      localizationsDelegates: kTestLocalizationDelegates,
      supportedLocales: kTestSupportedLocales,
      home: child,
    ),
  );
}
