# 02 · 实施方案（英文阶段 / AI 执行版）

> **本文件回答"怎么改"。** 硬约束在 `01-执行协议.md`，现状数字与不可翻译清单在 `04-数据基线.md`，逐文件待办在 `03-任务清单.md`。
> 与本文冲突时：`AGENTS.md` > `01-执行协议.md` > 本文。
> 涉及具体数字（处数/文件数/枚举清单）时**一律引用 `04-数据基线.md`，不要自己重新统计**。

---

## 0. 已定决策（**用户已拍板，不要再讨论、不要自行更改**）

| 项 | 决策 |
|---|---|
| 迁移方式 | **方案 C：全量搬入 ARB**。禁止在代码里保留"中文兜底字段"或双份文案 |
| 语言范围 | 本阶段只做 `zh` + `en`。**不做**繁体、**不做** RTL |
| **默认语言** | **简体中文**（`app_locale` 缺省/异常一律回落 `'zh'`） |
| **语言选项** | **只有 `简体中文` / `English` 两项，没有「跟随系统」**（`app_locale` 值只允许 `'zh'` / `'en'`） |
| **首启语言弹窗** | 首次启动、**同意隐私政策之后立即弹**语言选择窗；默认选中简体中文；选项 简体中文 / English；**只对全新安装的首次启动弹一次**；升级老用户**不弹**（保持简体中文） |
| **设置入口** | 设置页新增一组「**语言**」，组内一项「**语言设置**」；位置在「弹幕」组**下方**、「下载」组**上方**（现有组序：外观 → 播放 → 媒体库 → 弹幕 → 下载 → 其他） |
| **英文应用名** | **`Meow Player`**（中文侧仍为 `小喵Player`）。Dart `appTitle`：zh=`小喵Player`、en=`Meow Player`；Android `app_name` 同理 |
| 模板 ARB | `app_zh.arb`（中文是源语言，键的权威定义在中文文件） |
| 生成器 | Flutter 官方 `gen_l10n`（`flutter gen-l10n`）；`--synthetic-package` 已废弃，生成物落地 `lib/l10n/` |
| 生成物 | **入库**（提交到仓库） |
| getter | `nullable-getter: false`（调用处不写 `!`） |
| 无 context 层 | 服务/模型/工具只产出**码 + 参数**，文案由 UI 层翻译 |
| 表改造 | 删中文标签字段，UI 侧 `labelOf(context, x)` 映射；**枚举顺序/名称一个都不许动** |
| **长文（隐私政策/协议）** | **按语言拆 Dart 文件**（`lib/l10n/legal_zh.dart` / `legal_en.dart`），**不塞进 ARB**；英文由 AI 翻译即可，**无需专业/法务审校** |
| **日志** | **永远保持中文**：无论将来增加多少语言，日志都不翻译（永久规则） |
| **截图文件名** | 保持现状（`小喵Player-yyyy-…`），**不随语言变化** |
| 第三方工具 | 不引入（用户明确否决） |
| 阶段推进 | **每个阶段结束后停下来等用户确认**，不自动进入下一阶段 |

---

## 1. 技术方案（逐项照做）

### 1.1 目录与文件布局

```
l10n.yaml                                  # 新增：gen_l10n 配置
lib/l10n/app_zh.arb                        # 新增：模板（源语言，含 @ 元数据）
lib/l10n/app_en.arb                        # 新增：英文
lib/l10n/app_localizations.dart            # 生成物（入库）
lib/l10n/app_localizations_zh.dart         # 生成物（入库）
lib/l10n/app_localizations_en.dart         # 生成物（入库）
lib/l10n/label_maps.dart                   # 新增：枚举/表 → 文案 的 UI 侧映射
lib/services/app_locale_settings.dart      # 新增：语言偏好持久化 + 通知
l10n_untranslated.json                     # 生成：未翻译键清单（阶段收口必须为空）
```

### 1.2 依赖与 pubspec 改动（只允许改这两处 + 一个开关）

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:      # 新增
    sdk: flutter
  intl: any                   # 新增：先写 any，让 pub 解析到与 SDK 匹配的版本

flutter:
  uses-material-design: true
  generate: true              # 新增
```

**禁止**：手写 `intl` 的具体版本号（可能与 `flutter_localizations` 冲突）；升 `version:`；加任何其它依赖。

### 1.3 `l10n.yaml`（逐字段照抄）

```yaml
arb-dir: lib/l10n
template-arb-file: app_zh.arb
output-localization-file: app_localizations.dart
output-class: AppLocalizations
output-dir: lib/l10n
nullable-getter: false
preferred-supported-locales: [zh]
untranslated-messages-file: l10n_untranslated.json
```

| 字段 | 为什么这么设 |
|---|---|
| `template-arb-file: app_zh.arb` | 源语言是中文；模板是键的唯一权威。英文缺键时生成器只警告并用模板语言回退（并在 `untranslated` 里列出） |
| `nullable-getter: false` | 调用处不用 `!`，与仓库"少写防御式样板"的风格一致 |
| `preferred-supported-locales: [zh]` | 设备语言不在支持列表时回落中文，**不改变老用户现状** |
| `untranslated-messages-file` | 阶段收口的硬门禁（见 `01-执行协议.md` §5 G3） |

### 1.4 生成物入库（决策依据）

检索本机 Flutter SDK（`D:\allexe\flutter`）源码确认：`generateLocalizations()` 只被 `build_system/targets/localizations.dart`（构建系统目标）与 `commands/generate_localizations.dart`（`flutter gen-l10n`）调用。
**`flutter test` 是否会触发该目标未验证**，而本仓库只跑 `flutter analyze` / `flutter test`——所以生成物入库，从根上避免"忘了生成 → analyze 报找不到 `AppLocalizations`"。

### 1.5 `MaterialApp` 接线（现状：`lib/main.dart:416`）

改造前：`MaterialApp(title: '小喵Player', ...)`，无 `localizationsDelegates` / `supportedLocales` / `locale`。

```dart
return MaterialApp(
  onGenerateTitle: (context) => AppLocalizations.of(context).appTitle, // zh=小喵Player / en=Meow Player
  localizationsDelegates: AppLocalizations.localizationsDelegates,     // 含 Material/Widgets/Cupertino
  supportedLocales: AppLocalizations.supportedLocales,
  locale: AppLocaleSettings.instance.locale,                           // 非空 Locale，默认简体中文（无「跟随系统」）
  // 其余字段（theme/darkTheme/themeMode/navigatorKey/builder/navigatorObservers/home）保持不变
);
```

同文件还有导航项文案：`lib/main.dart:444`（`'首页'`）、`:451`（`'我的'`）——该处在 `build` 内，`context` 可用。

### 1.6 语言状态与持久化（新增 `lib/services/app_locale_settings.dart`）

对齐仓库既有约定（设置单例：`ensureLoaded()` + 所有 setter 首行 `await`，与 `main.dart` 共享同一 load Future）：

- 键：`app_locale`（ASCII，**禁止中文键**）
- 值：**只允许 `'zh'` / `'en'`**；缺省、空值、非法值一律回落 **`'zh'`（简体中文）**
- **没有 `'system'`**：用户已定不提供「跟随系统」，因此 `locale` 永远是非空 `Locale`
- 暴露：`Locale get locale => Locale(_value)`、`String get rawValue => _value`
- setter 写入后 `notifyListeners()` → `MaterialApp.locale` 立即生效（无需重启）
- 与 `privacy_policy_settings.dart` 同风格：`main()` 在 `runApp` 前 `await` 加载，首帧即可读到正确语言

**注意（不要顺手改）**：`lib/services/subtitle_service.dart:707` 用**系统语言**决定简/繁外挂字幕优先，这与 App 界面语言无关，**保持现状**，不要改成 `app_locale`。

### 1.7 语言选择入口（两处，都要做）

#### A. 首启语言选择弹窗（新增 `lib/widgets/language_picker_dialog.dart`）

**时机**：挂在现有首启隐私门禁里——`lib/main.dart:189` 首帧门禁 → `_ensurePrivacyAgreed()`（`:293–299`）→ `showPrivacyPolicyDialog(context)` **返回 true（本次刚同意）之后立即弹**。
这个位置天然满足两条要求：**只对全新安装的首次启动弹一次**；**已同意过隐私政策的老用户不进该分支 → 不弹**（保持简体中文）。

**内容**：标题「选择语言 / Choose Language」；两个选项 **简体中文** / **English**（用**自称**，不翻译）；**默认选中简体中文**；确认后写入 `app_locale` 并立即生效。

**约定（可被用户否决）**：这是"选择"而非"门禁"，因此**允许通过遮罩/返回键关闭，关闭等同保持简体中文**，避免把用户卡在弹窗里。

**实现注意**：弹窗在首帧门禁流程内，`context` 可用；不要在 `initState` 里取 l10n；选择后 `notifyListeners()` 会让 `MaterialApp` 重建，无需手动 `setState`。

#### B. 设置页入口

位置：`lib/pages/settings/settings_page.dart`，在 `SettingsGroupTitle(title: '弹幕')`（现 `:149`）与 `SettingsGroupTitle(title: '下载')`（现 `:165`）之间，插入新组：

```dart
// ── 语言 ──────────────────────────────
const SettingsGroupTitle(title: '语言'),
SettingsItem(                       // 沿用本页现有 item 组件与样式
  title: '语言设置',
  subtitle: const Text('简体中文 / English'),
  onTap: ...  // 打开语言选择（复用 A 的弹窗，或就地弹 BottomSheet）
),
```

选项文案用**自称**（不翻译）：`简体中文` / `English`。设置里改完立即生效并持久化。

### 1.8 无 context 层的取文案规则（本方案核心，459 处 / 396 条）

| 层 | 职责 | 示例 |
|---|---|---|
| `services` / `models` / `utils` | 只产出**语义**：错误码枚举 + 参数 | `throw NetworkClientException(NetworkError.ftpLoginFailed, code: 530)` |
| `pages` / `widgets` | 只做**翻译** | `l10n.networkErrorFtpLoginFailed(530)` |

落地优先级：

1. **错误码枚举**（首选）：网络/播放/下载/文件操作等异常改成 `code + args`；UI 层集中用一个 `errorText(context, e)` 翻译。现有异常类型（`NetworkClientException`、`UpdateCheckException`、`FileOpException` 等）**保留类型名**，只替换其中的 `String message`。
2. **调用方传入文案**（次选）：服务只组织数据，标题/标签由页面给，例如 `InfoCard(title: l10n.deviceCpu, value: x)`。
3. **全局持有者**（兜底，默认不用）：只有在确实无法拿到 `context` 时才用；用了必须登记原因。

**必须保持纯 Dart 的文件**（禁止引入 Flutter/l10n）：`lib/utils/chapter_utils.dart`、`subtitle_language.dart`、`subtitle_auto_match.dart`、`danmaku_episode.dart`、`danmaku_*`、`natural_compare.dart` 等纯函数与其单测；它们的显示文案（如章节类型名）在 UI 层翻译。

### 1.9 表改造规范（方案 C 执行细则）

**范围**：31 个枚举 / 128 项 + 主题色 23 + 调色板风格 21 + 101 条 `'键': '中文值'` 映射项（清单见 `04-数据基线.md` §6 与附录 B）。

**枚举**：

```dart
// 改造前（player_action.dart 风格）
enum PlayerVideoFit { contain('适应屏幕'), cover('铺满屏幕'); const PlayerVideoFit(this.label); final String label; }

// 改造后：枚举只留稳定值，中文进 ARB
enum PlayerVideoFit { contain, cover }

// lib/l10n/label_maps.dart（UI 侧映射）
String playerVideoFitLabel(AppLocalizations l10n, PlayerVideoFit v) => switch (v) {
  PlayerVideoFit.contain => l10n.playerVideoFitContain,
  PlayerVideoFit.cover   => l10n.playerVideoFitCover,
};
```

**硬约束**：

1. **禁止调整枚举项顺序**（`view_settings.dart` 用 index 持久化；`player_controls_settings.dart:250` 用 `byId`）。只允许删除 `label` 字段、构造参数与 `final String label;` 声明。
2. **禁止在枚举里保留"中文兜底字段"**（方案 C 的意义就是不留双份）。
3. **禁止在 `models/`、`utils/` 里 import l10n**，翻译一律 UI 侧映射。
4. 映射函数集中在 `lib/l10n/label_maps.dart`，命名 `<模块><枚举名>Label`，`switch` 用表达式形式（穷尽性由 `analyze` 兜住）。

**主题色 / 调色板（44 项）**：删除 `theme_controller.presetColors` 的 `label` 字段与 `FlexSchemeVariant` 中文映射，改按**下标/枚举值**查 ARB（`themeColorLabel(l10n, index)`、`paletteVariantLabel(l10n, variant)`）。
⚠️ 代码注释要求「名称统一 3 字」——英文做不到，阶段 1 需人工看溢出（见 §4.E）。

**映射表项（101 条）**：`'键': '中文值'` 改成 `'键' → ARB 键`，取文案的调用点改为查 l10n。最多的是 `lib/pages/media_info/media_info_page.dart`（19 项）。

**`switch` 直接返回中文**（如 `lib/services/media_scan_settings.dart:16–24`）：改成返回枚举/键，文案在 UI 层。

### 1.10 ARB 键规范与复用

1. **先建 `common.*`**：全仓有 **189 条**去重文案出现在 ≥2 个文件（`取消` 20 个文件、`确定`/`删除` 各 8 个…）。同一句中文必须复用同一个键，**禁止**在两个键里重复定义。
2. 插值一律用 `placeholders`（共 258 处：`${}` 136 + `$var` 122），占位符名用英文。
3. **裸花括号只有 2 处**（`lib/pages/subtitle/views/subtitle_settings_section.dart`，讲 `{name}` 占位符语法的帮助文案）→ 必须转义或改写，否则 ARB 解析失败。
4. 含 `\n` 的 37 处：ARB 里写 `\n`。
5. 复数用 ARB `plural` 语法，禁止手拼 `s`。
6. `app_en.arb` 里**禁止出现中文**（用 `untranslated-messages-file` 每阶段核对）。
7. 键前缀按模块：`common.` / `home.` / `player.` / `settings.` / `network.` / `bili.` / `danmaku.` / `subtitle.` / `download.` / `cast.` / `mediaInfo.` / `error.` / `legal.`（`gen_l10n` 不支持点号分组时用拼接式，保持前缀可读）。

### 1.11 长文（隐私政策 / 用户协议）——**已定：按语言拆 Dart 文件（不塞 ARB）**

现状：`lib/services/privacy_policy_content.dart` 是 4 个 `const String`（`kPrivacyPolicyTitle` / `kPrivacyPolicyBody` / `kUserAgreementTitle` / `kUserAgreementBody`），正文 **3418 中文字**，`'''…'''` 多行；两处消费点都是纯 `Text()`（`lib/widgets/privacy_policy_dialog.dart:100`、`lib/pages/settings/privacy_policy_page.dart:57`）。

**用户已拍板**：拆成按语言的 Dart 常量文件；英文**由 AI 直接翻译即可，无需专业/法务审校**。

执行步骤：

1. 新建 `lib/l10n/legal_zh.dart`：把现有 4 个常量的中文原文**原样**迁入（保留 `'''…'''` 多行排版，便于 diff 与校对）。
2. 新建 `lib/l10n/legal_en.dart`：同名常量，英文全文（AI 翻译；术语用 `Meow Player` 指代本应用）。
3. 两个文件都暴露一个按 locale 取值的入口，例如：

   ```dart
   // lib/l10n/legal.dart（或直接放在 legal_zh/legal_en 之一里）
   ({String policyTitle, String policyBody, String agreementTitle, String agreementBody})
       legalTextsFor(Locale locale) =>
       locale.languageCode == 'en' ? legalEn : legalZh;
   ```

4. 两处消费点改为按 `Localizations.localeOf(context)`（或 `AppLocaleSettings.instance.locale`）取对应文本，删除 `privacy_policy_content.dart` 的 4 个常量（或让它只做转发，避免两处真源）。
5. **翻译纪律**：译文不要照抄原文里的 `**不会**` 这类 Markdown 强调符（纯 `Text()` 下会原样显示星号，属现状问题，不在本阶段修）。
6. 加一个测试兜底：断言每种支持语言（zh / en）的 4 个字段都非空，防止将来加语言时漏文件。
7. 条款更新时的纪律：改中文条款必须同步改英文（在两个文件头部写明这条约定）。

### 1.12 Android 原生（阶段 8）

1. 新增 `android/app/src/main/res/values/strings.xml`（默认=中文）与 `values-en/strings.xml`（英文）。
   **应用名固定值**：`values/` 的 `app_name` = `小喵Player`；`values-en/` 的 `app_name` = `Meow Player`。**不许自创别的名字。**
2. `AndroidManifest.xml` 的 `android:label="小喵Player"` → `@string/app_name`。
3. `BackgroundPlaybackService.kt`：渠道名/描述/标题/正文改 `getString(R.string.…)`；**渠道 ID `moumou_background_playback` 不许改**（改了会变成新渠道）。
4. `MainActivity.kt:1552` 的 `"内部存储"` / `"SD 卡"`、`:916` 的 `"读取日志失败：…"` 改资源。
5. `CrashHandler.kt`：18 条日志表头改资源；**崩溃路径取资源可行性未验证**，不行就保留中文并在报告里写明。
6. 其它语言设备会拿到 `values/`（中文）——与 Dart 侧 `preferred-supported-locales: [zh]` 一致，本阶段接受。
7. Android 13 per-app language（`localeConfig`）**本阶段不做**。

---

## 2. 阶段 0–8

> 每阶段的固定要求：单文件循环 + 阶段收口（见 `01-执行协议.md` §2），门禁 G1–G6，收口后按 §9 模板报告并**停下来等用户确认**。
> 每阶段的文件清单与处数：直接看 `03-任务清单.md` 对应小节（已按阶段分组）。

### 阶段 0 · 基建与测试夹具（**必须最先做，且此时不许改任何业务文案**）

**步骤**

1. 改 `pubspec.yaml`（§1.2）。
2. 新增 `l10n.yaml`（§1.3）。
3. 新增 `lib/l10n/app_zh.arb` 与 `app_en.arb`，先只放 2 个键：`appTitle`、`commonCancel`。
4. `flutter gen-l10n`，确认 `lib/l10n/app_localizations*.dart` 生成。
5. 改 `lib/main.dart` 接线（§1.5）。
6. 新增 `lib/services/app_locale_settings.dart`（§1.6）。
7. **测试夹具**（关键）：
   - 新增 `test/l10n_test_helper.dart`，提供 `pumpAppZh(tester, widget)`；或
   - 在测试入口统一设 `tester.binding.platformDispatcher.localeTestValue = const Locale('zh')`。
   - 目的：让 185 个既有测试文件在"支持 en 之后"仍解析到中文，**保住 535 处 `find.text('中文')` 断言**（依据：测试默认 locale = `en_US`，见 `04-数据基线.md` §10）。
8. 跑**全量** `flutter test`，确认**仍然全绿**（此时未改任何文案，绿即证明夹具有效）。

**验收**：G1 通过；`flutter gen-l10n` 成功；全量 `flutter test` 全绿；`l10n_untranslated.json` 只含阶段 0 的少量键。
**停止条件**：夹具无法让既有测试全绿 → 停下来报告，不许改断言迁就。

### 阶段 1 · 公共层与表改造（25 文件 / 240 处）

**步骤**

1. **第一件事**：把 `lib/widgets/folder_actions.dart:260,380` 的 `'取消'` 哨兵值改成常量/枚举（行为必须完全等价），改完从 `tools/whitelist.json` 删除对应两条白名单并重跑 `residual`。
2. 按 `03-任务清单.md` 阶段 1 的文件逐条推进（枚举所在 models/services/theme、主题色与调色板表、映射表项、`switch` 返回中文的服务）。
3. 建立 `common.*` 词表并归并 189 条重复文案。
4. 建 `lib/l10n/label_maps.dart`（§1.9）。
5. 阶段收口：`residual --path lib/models`、`--path lib/services`、`--path lib/utils`、`--path lib/theme` 全部为 0（白名单项除外，见 `04-数据基线.md` §13）。

**必测界面**（人工，由用户执行）：

| 界面 | 看什么 |
|---|---|
| 我的 → 外观（主题模式 / 23 色 / 21 风格） | 名称是否英文、**网格是否溢出**、选中态正常 |
| 播放器 → 更多 → 视频适配 / 解码 / 弹幕颜色 / 弹幕字体 | 枚举名英文、默认值仍正确 |
| 首页 → 排序 / 字段设置（列表与树状各一套） | 名称英文后是否溢出；**改过设置后重启，选择是否还在**（验证 index 持久化未被破坏） |
| 媒体信息页 | 19 条映射表项全部有译文 |
| 播放器自定义控制栏（顶/底按钮增删） | 按钮名英文后胶囊是否溢出；重启后自定义顺序保留 |

**风险**：G5（枚举顺序）必须逐文件 `git diff` 核对；`const` 报错按 `01-执行协议.md` §7 处理。

### 阶段 2 · 入口、导航与语言入口（2 文件 / 39 处 + 1 个新建文件）

**文件**：`lib/main.dart`（已接线，此处清剩余文案 + `onGenerateTitle`）、`lib/pages/settings/settings_page.dart`（语言设置入口）、**新建** `lib/widgets/language_picker_dialog.dart`。

**步骤**

1. 完成 `main.dart` 剩余文案 + `onGenerateTitle`（`appTitle`：zh=`小喵Player`、en=`Meow Player`）。
2. **新建首启语言弹窗**（§1.7 A）：两个选项、默认选中简体中文、确认后写 `app_locale` 并立即生效。
3. 挂到首启门禁：`main.dart` 的 `_ensurePrivacyAgreed()` 里，`showPrivacyPolicyDialog` 返回 true（本次刚同意）之后弹语言选择；**老用户（已同意）不进该分支，因此不弹**。
4. 设置页插入「语言」组 + 「语言设置」项（§1.7 B），位置在 `SettingsGroupTitle(title: '弹幕')` 与 `SettingsGroupTitle(title: '下载')` 之间。
5. 阶段收口：G1–G6。

**必测**（人工）：

| 场景 | 判定 |
|---|---|
| 全新安装首启 | 隐私弹窗 → 同意 → **立即弹语言选择窗**，默认选中**简体中文** |
| 语言弹窗点 English | 界面立即变英文（无需重启）；杀进程重开仍是英文 |
| 语言弹窗直接关闭 | 保持简体中文，不报错、不卡住 |
| 升级安装（已同意过隐私） | **不弹语言窗**，界面仍简体中文 |
| 设置 → 语言 → 语言设置 | 在「弹幕」组下方、「下载」组上方；改成 English 后当前页立即变 |
| 冷启动标题 | 任务切换器标题跟随语言（zh=小喵Player / en=Meow Player） |
| 底部导航（首页/我的） | 英文变长后是否挤压/换行 |
| 外部 App 分享进来的播放页 | 语言与 App 设置一致 |
| 字幕简/繁优先 | **仍按系统语言**（不要被 App 语言影响，见 §1.6 注意事项） |

### 阶段 3 · 设置页群（13 文件 / 375 处）

从 `03-任务清单.md` 阶段 3 小节取清单（`player_settings_page.dart` 94 处最大）。

**必测**：播放器设置（逐项标题+副标题+选项，长句换行）、媒体扫描设置（黑白名单模式说明文案）、缓存管理/字体/解码器详情（数值单位、字体名保持原文）、设备信息（技术字段中英混排）、播放历史（日期格式、空态、清空确认）、关于页/许可证书/隐私政策（第三方许可全文是英文，**不要翻**）、错误日志页（表头英文后列宽；日志内容仍是中文，预期）、壁纸编辑。

### 阶段 4 · 播放器（35 文件 / 428 处，最大一块）

`player_page.dart`(60)、`player_portrait_page.dart`(43)、`views/subtitle_panel.dart`(69)、`views/player_danmaku_settings_panel.dart`(57)、`views/player_diagnostics_panel.dart`(30)、`views/audio_player_panels.dart`(21)、`views/audio_panel.dart`(14) 等。

**必测**：横屏播放页（顶栏/底栏/章节胶囊/锁定态）、**更多面板逐个打开**（倍速/画面比例/解码/超分/章节/片头片尾/循环/播放列表/字幕/弹幕/音频/均衡器/诊断/投屏）、竖屏播放页（**横竖屏是两套代码，必须分别验**）、横竖屏切换（文案一致、无残留闪烁、`const` 拆分后重建范围变化是否引起卡顿或控件状态丢失）、手势提示（双击快退/快进、音量/亮度、倍速）、进度条缩略图、诊断面板长句、音频播放页、画中画/后台播放通知。

### 阶段 5 · 其余业务页（38 文件 / 500 处）

`pages/bilibili`、`pages/subtitle`、`pages/network`、`pages/media_info`、`pages/home`、`pages/download`、`widgets/*`。

**必测**：首页（列表/树状、空态、搜索、多选工具栏、速拨 FAB、文件夹卡片副标题、已观看标记）、文件夹详情与树状浏览（面包屑、排序、文件操作菜单与**删除确认弹窗**含文件名插值）、网络存储（账号编辑协议与字段标签、浏览页连接中/失败/重试、`NetworkTimeoutTier` 档位名）、哔哩哔哩（登录扫码提示、索引/搜索/详情/选集/时间表、下载页）、字幕（轨道类型、下载、样式：对齐/边框样式/颜色名）、下载管理（状态文案、单位、批量确认）、投屏（发现过程与失败原因）、通用组件（`options_sheet` / `file_operations_ui` / `update_dialog`；更新说明来自 GitHub Release 正文，**可能仍是中文，预期**）。

### 阶段 6 · 服务/模型/工具层（48 文件 / 264 处）

按 §1.8 执行。文件清单见 `03-任务清单.md` 阶段 6。

**必测**：网络存储断网/错密码/服务器拒绝（错误提示是否英文且**信息完整**，含 530 之类插值）、播放 URL 失效（播放页错误卡片长句是否溢出）、B 站未登录/登录过期、字幕下载无结果与接口异常、下载失败/空间不足、检查更新失败与「已是最新」、文件操作失败（含文件名插值）、投屏失败。

### 阶段 7 · 长文（3 文件 / 9 处 + 2 个新建文件）——**已定：按语言拆 Dart 文件**

**步骤**（详见 §1.11）

1. 新建 `lib/l10n/legal_zh.dart`：中文原文原样迁入（保留 `'''…'''` 排版）。
2. 新建 `lib/l10n/legal_en.dart`：英文全文（AI 翻译，术语用 `Meow Player`）。
3. 加按 locale 取文本的入口；两处消费点（`privacy_policy_dialog.dart:100`、`privacy_policy_page.dart:57`）改为按当前 locale 取。
4. 删除 `lib/services/privacy_policy_content.dart` 的 4 个常量（避免两处真源），或让它只做转发。
5. 加测试：断言 zh / en 两种语言的 4 个字段都非空。
6. 阶段收口：G1–G6。

**必测**：首次启动隐私弹窗（倒计时/勾选/不同意退出）、关于→用户协议、关于→隐私政策、隐私门禁；英文模式下正文完整、可滚动、无明显机器翻译硬伤。
注意：正文里 `**不会**` 这类 Markdown 强调符在纯 `Text()` 下会**原样显示星号**（现状问题，不在本阶段修），译文不要照抄。

### 阶段 8 · Android 原生与收尾

1. 按 §1.12 完成 Android 侧。
2. **残留清零**：`python tools/i18n_scan.py residual --include-android` → 残留仅剩白名单项。
3. `l10n_untranslated.json` 为空（英文无缺键）。
4. `flutter analyze` + 全量 `flutter test` 收口。

**必测**：应用名（桌面/最近任务/设置-应用信息）、通知渠道名（**已装旧版升级后**是否更新，见 §4.F）、崩溃日志页表头、存储卷选择器、系统「打开方式」里的应用名。

---

## 3. 测试方案

### 3.1 测试夹具（阶段 0 完成，后续复用）

```dart
// test/l10n_test_helper.dart
Future<void> pumpAppZh(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  ));
}
```

或全局：`tester.binding.platformDispatcher.localeTestValue = const Locale('zh');`

**验收证据**：阶段 0 结束时，未改任何文案的情况下全量 `flutter test` 全绿。

### 3.2 自动化门禁

复用 `01-执行协议.md` §3 的命令；门禁标准见其 §5（G1–G6）。
**每次改 ARB 后必须** `flutter gen-l10n`；**每阶段收口必须** 全量 `flutter test` + `residual` + `untranslated` 检查。

### 3.3 人工验收清单（阶段 8 前必须逐项过）

| # | 项目 | 判定 |
|---|---|---|
| 1 | **首启语言弹窗** | 全新安装：隐私弹窗 → 同意 → 立即弹语言选择；**默认选中简体中文**；可自由选 English |
| 2 | **升级用户不弹** | 已同意过隐私政策的旧版升级上来：**不弹**语言窗，界面保持简体中文 |
| 3 | 语言切换即时生效 | 弹窗或设置里切 English，当前页立刻变 |
| 4 | 语言持久化 | 杀进程重开保持所选语言 |
| 5 | **无「跟随系统」** | 语言选项只有 简体中文 / English；改系统语言不影响 App 界面语言 |
| 6 | **设置入口位置** | 「语言」组在「弹幕」下方、「下载」上方；组内项为「语言设置」 |
| 7 | 设置不丢 | 主题/调色板/自定义控制栏/排序与字段/解码档位/字幕样式/弹幕设置 **逐项改后重启检查** |
| 8 | 枚举顺序未变 | 抽查 `view_settings`（index）与 `PlayerTopAction.byId` 的旧存档仍可读 |
| 9 | 播放行为不变 | 本地/网络/B 站在线各播一次；字幕弹幕正常；横竖屏切换正常 |
| 10 | 字幕简/繁优先 | **仍按系统语言**（不被 App 语言影响） |
| 11 | 无文案溢出 | 外观页网格、胶囊导航、播放器面板标题、诊断面板长句、所有按钮 |
| 12 | 插值正确 | 删除确认（含文件名）、错误码、大小/时间/速度 |
| 13 | 复数正确 | 任何"N 个/项/文件"在 1 与 2 时形式正确 |
| 14 | 无中文残留 | 英文模式遍历全部页面（脚本 + 人工看高频页）；日志仍为中文（预期，不算残留） |
| 15 | Android 侧 | 应用名（zh=小喵Player / en=Meow Player）、通知渠道、存储卷名、崩溃日志表头 |
| 16 | 长文 | 首次启动隐私弹窗 / 关于页协议，中英两版完整可滚动 |
| 17 | 截图文件名 | 两种语言下都仍是 `小喵Player-yyyy-…`（不跟语言） |

### 3.4 测试文件收口策略

- 阶段 0：夹具生效，**不改断言**。
- 各阶段：只跑相关测试文件；若某测试因为"UI 文案断言"必须改，**改成引用 l10n 的值**（`find.text(l10n.commonCancel)`），不要硬编码英文。
- 阶段 8：全量 `flutter test` + 处理 24 个访问 `.label` 的测试文件（枚举删字段后会编译失败，改为 `labelOf(l10n, x)` 或直接断言枚举值）。

---

## 4. 问题与对策（遇到时查）

### A. ARB / 生成机制

| 症状 | 原因 | 对策 |
|---|---|---|
| analyze 找不到 `AppLocalizations` | 生成物没生成/没入库 | 生成物入库（§1.4）；或先跑 `flutter gen-l10n` |
| 生成报非法 ARB | 裸花括号被当占位符（全仓仅 2 处） | 转义或改写（`subtitle_settings_section.dart`） |
| 英文句子丢参数 | 插值手写成拼接 | 一律用 `placeholders`（258 处） |
| 换行丢失 | ARB 里真换行 | 写 `\n`（37 处） |
| `intl` 版本冲突 | 手写版本号 | `intl: any` 或 `flutter pub add intl` |
| 键重复/漏键 | 1855 处手工搬运 | 先 `common.*`（189 条重复）+ 每次核对 `untranslated` |

### B. `context` 与 `const`

| 症状 | 原因 | 对策 |
|---|---|---|
| "const 表达式不能包含运行时值" | 381 处同行含 `const` | 去掉该处 `const`，逐个确认重建范围 |
| `Undefined name 'context'` | 无 `BuildContext`（回调/静态/纯函数） | §1.8 服务出码、UI 出文案；`initState` 改 `didChangeDependencies` |
| 静态常量表带中文 | 常量不能查 l10n | 改成键/下标表 + UI 侧翻译 |
| Dialog/SnackBar 文案在打开后固化 | 文案在打开时已取值 | 可接受；需实时则改为在 builder 内取 |

### C. 表改造

| 症状 | 原因 | 对策 |
|---|---|---|
| 用户设置错乱 | 动了枚举顺序而持久化用 index | **禁止重排**（G5 逐文件 diff 核对） |
| 某处仍显示中文 | 漏改 `.label` 调用点（252 处 / 97 文件） | 删字段后编译器会全部报错→逐个改；不留兜底字段 |
| models 单测挂 | 在 models/utils 里 import 了 Flutter/l10n | 翻译只在 UI 侧映射 |
| switch 不穷尽 | 删字段后漏分支 | `analyze` 会报，正好兜住 |

### D. 测试

| 症状 | 原因 | 对策 |
|---|---|---|
| 535 处断言失败 | 测试默认 locale = `en_US` | 阶段 0 夹具（§3.1） |
| 某测试找不到中文 | 夹具没覆盖 | 统一走 helper |
| 24 个测试 `.label` 编译失败 | 字段被删 | 改 `labelOf(l10n, x)` |
| `expect` 含中文的 882 行误判 | 那些中文可能是**数据** | 只改 UI 文案断言，数据类断言保持 |

### E. UI / 布局

| 症状 | 原因 | 对策 |
|---|---|---|
| 外观页网格溢出 | 注释要求「名称统一 3 字」，英文更长 | 人工看溢出；必要时缩短英文词或调列数（**调布局属 UI 改动，需用户同意**） |
| 胶囊/chip 挤压 | ≤4 字短文案 1102 处，英文更长 | 优先查短文案清单；`Flexible`/`ellipsis` 兜底 |
| 诊断面板长句溢出 | 长句英文更长 | 允许换行、检查行高与滚动 |
| 自定义字体无拉丁字形 | `AppFontSettings` 可能只覆盖中文 | 真机确认；必要时为 en 指定 fallback |

### F. Android

| 症状 | 原因 | 对策 |
|---|---|---|
| 通知渠道名仍中文 | Android 对已创建渠道名的系统行为 | **需真机实测**；不行则接受（只影响设置页显示）或删渠道重建（会丢用户对该渠道的通知偏好） |
| 应用名没变 | label 仍硬编码 | §1.12 |
| 崩溃日志表头仍中文 | 崩溃路径取资源失败 | 实测；不行保留中文并报告 |
| 日语/韩语设备显示中文 | 默认 `values/` 是中文 | 本阶段接受 |

### G. 第三方与内容

| 症状 | 原因 | 对策 |
|---|---|---|
| 播放错误提示为原生英文 | mpv/ffmpeg/media_kit 内部 | 不翻；UI 包一层友好提示 |
| B 站页面出现中文 | 接口内容（番剧名/简介/弹幕） | 不翻（数据） |
| 更新弹窗正文中文 | GitHub Release 正文由仓库维护 | 接受，或以后维护双语 Release 正文 |
| 字幕/集数识别失效 | 误翻了不可翻译清单 | `residual` 白名单兜住；误翻必须回滚 |

---

## 5. 明确不做（本阶段）

- 不做繁体 `zh_Hant`、不做其它语言、不做 RTL。
- 不改业务逻辑（唯一例外：`folder_actions` 哨兵值常量化）。
- 不改版本号、不提交、不推送。
- 不动 `docs/`、`README.md`、第三方库文案、内容匹配关键词、日志。
- 不做应用商店资料、不做 Android per-app language。

---

## 6. 决策状态

### 6.1 已拍板（用户答复，见 §0，不要再问、不要自行更改）

| # | 问题 | 结论 |
|---|---|---|
| 1 | 英文应用名 | **`Meow Player`**（中文仍 `小喵Player`） |
| 2 | 长文落地方式 | **按语言拆 Dart 文件**（`lib/l10n/legal_zh.dart` / `legal_en.dart`），不进 ARB |
| 3 | 默认语言策略 | **简体中文**；首启同意隐私政策后弹语言选择窗；设置里可改 |
| 4 | 语言入口位置 | 设置页新组「**语言**」+ 项「**语言设置**」，位于「弹幕」组下方、「下载」组上方 |
| 5 | 长文英文翻译 | **AI 翻译即可**，不需要专业/法务审校 |
| 6 | 日志 | **永远保持中文**（无论增加多少语言都不翻） |
| 7 | 生成物入库 | **入库** |
| 8 | 截图文件名 | **不跟随语言**，保持 `小喵Player-yyyy-…` |
| 9 | 每阶段停止确认 | **需要**，每阶段结束停下来等用户确认 |

### 6.2 由上述答复推导出的约定（已写入文档，如不认同请告知）

| # | 约定 | 位置 |
|---|---|---|
| a | 语言选项**只有 简体中文 / English**，没有「跟随系统」；`app_locale` 值只允许 `'zh'` / `'en'`，缺省回落 `'zh'` | §1.6、§1.7 |
| b | 语言弹窗**只对全新安装的首次启动弹一次**（挂在隐私门禁的"本次刚同意"分支上），**升级老用户不弹** | §1.7 A、阶段 2 |
| c | 语言弹窗是"选择"而非"门禁"：**允许关闭，关闭=保持简体中文** | §1.7 A |
| d | `subtitle_service.dart:707` 的简/繁字幕优先**仍按系统语言**，不改用 App 语言——**用户已确认同意**（2026 版拍板追加确认） | §1.6、§3.3 第 10 项 |
