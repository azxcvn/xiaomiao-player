# media_kit 本地魔改说明（FORK.md）

> 本目录是 `media_kit` 的**本地 fork**（通过 `pubspec.yaml` 的 `dependency_overrides`
> 以 `path:` 方式接入）。本文件记录**基线版本、补丁清单、升级步骤与验证方法**，
> 目的只有一个：**半年后升级 media_kit 时，不用重新读代码才知道改了什么。**
>
> 本文件是本地新增文件，**不属于上游仓库**；上游的 `README.md` 保持原样未改。
> 姊妹文档：`third_party/smb_connect/FORK.md`（另一个 fork）。

---

## 1. 为什么需要 fork

上游 `media_kit` 在 Android 上只暴露 `PlayerConfiguration.libassAndroidFont`
（**APK 内 asset 路径**）：该值会被 `AndroidAssetLoader.load()` 处理，只能读取打包进
APK 的 `flutter_assets/`。

本应用需要「**用户从存储导入字体**」，字体文件位于应用私有目录（运行时绝对路径），
上游没有对应的公开入口。而 `sub-fonts-dir` 又必须在 `mpv_initialize` **之前**通过
option 注入（运行时 `setProperty('sub-fonts-dir')` 会破坏 libass 字体缓存导致字幕
消失，见 `docs/ARCHITECTURE.md` §4.10），因此无法在应用层绕开——只能加字段。

## 2. 基线版本

| 项 | 值 |
|---|---|
| 上游包 | `media_kit` |
| 基线版本 | **1.2.6**（与 pub.dev 发布版一致，非 main 分支） |
| 本地版本 | **1.2.6**（未加 `-mk.N` 后缀；`media_kit_libs_android_video` 与 `smb_connect` 已采用该后缀，如需统一可改为 `1.2.6-mk.1`） |
| 校验方式 | 与 pub 缓存中的 `media_kit-1.2.6` 逐文件 diff |
| 差异规模 | **3 个文件**（`lib/src/player/platform_player.dart`、`lib/src/player/native/player/real.dart`、`pubspec.yaml`），Dart 部分约 +32 / −15 行 |

对照物（本机路径，升级时换成本地 pub 缓存里的目标版本即可）：

```
%LOCALAPPDATA%\Pub\Cache\hosted\pub.flutter-io.cn\media_kit-1.2.6
```

本 fork 只保留 `lib/` 与 `assets/`，未附带上游的 `screenshots/`、`test/` 等目录。

## 3. 补丁清单

所有改动点在源码中以 **`【魔改】`** 注释标记，可用以下命令一次列全：

```powershell
Select-String -Path (Get-ChildItem -Recurse -File third_party\media_kit\lib | ForEach-Object FullName) -Pattern '【魔改】'
```

> 注：补丁 4 位于 `pubspec.yaml`（不在 `lib/` 下），以 `# 本地 fork：` 注释标记，
> 上面的命令覆盖不到，需单独核对。

### 补丁 1：新增 `PlayerConfiguration.libassAndroidFontsDir`

文件：`lib/src/player/platform_player.dart`

- 新增字段 `final String? libassAndroidFontsDir;`（含文档，写明生效条件）
- 构造函数新增 `this.libassAndroidFontsDir` 命名参数
- 构造函数新增初始化列表断言：`libassAndroidFontsDir == null || libassAndroidFontName != null`
  （libass 的 `sub-font` 按**字体家族名**匹配，只给目录无法定位到具体字体）

### 补丁 2：`_create()` 中注入运行时字体目录

文件：`lib/src/player/native/player/real.dart`（`NativePlayer._create()`）

- 触发条件由 `libassAndroidFont != null` 放宽为
  `libassAndroidFont != null || libassAndroidFontsDir != null`
  （`libassAndroidFontName != null` 这一条上游要求保持不变）
- 原 asset 分支**原样保留**在 `else` 里：不传新字段时行为与上游完全一致（纯增量、零回归）
- 新增分支：`libassAndroidFontsDir` 非空时**直接使用该绝对路径**，跳过
  `AndroidAssetLoader`
- **新增注入前校验**：调用 `_hasFontFile()` 确认目录存在且含
  `.ttf`/`.otf`/`.ttc`/`.otc`；否则**不注入**并打印告警 —— 空目录会让 libass
  字体解析全部失败，比不设置 `sub-fonts-dir` 更糟（中文字幕变方块）
- 异常日志补充上下文（目录 / asset / 家族名），避免"字体没生效"无从定位
- **新增配置错误告警**：只设了 `libassAndroidFontsDir` 而没设
  `libassAndroidFontName` 时打印告警（`assert` 只在 debug 生效，release 靠这条日志）

### 补丁 3：新增顶层私有辅助函数

文件：`lib/src/player/native/player/real.dart`（文件末尾）

- `bool _hasFontFile(String path)`：目录存在性 + 字体扩展名（`.ttf`/`.otf`/`.ttc`/`.otc`）
  检查，任何异常一律返回 `false`（不可用），由调用方回落到系统字库

> ⚠️ **跨仓库耦合提醒**：`_hasFontFile()` 的扩展名清单必须与宿主应用
> `lib/models/subtitle_track.dart` 的 `kFontExtensions` 保持一致。应用层用它筛选
> 「要拷进字体目录的文件」，本函数用它判断「目录是否可用」；两边不一致会出现
> 「字体已导入但被判为不可用」的静默失效（例如应用层支持 `.otc` 而这里漏写）。
> **改动其中之一时必须同步另一个。**

### 补丁 4：提升 SDK 约束下界（`>=3.1.0` → `>=3.10.0`）

文件：`pubspec.yaml`（`environment.sdk`）

- 上游写作 `">=3.1.0 <4.0.0"`，但代码使用了 **SDK 3.10 才提供**的 Web API
  （`lib/src/player/web/player/real.dart` 的 `web.URL.createObjectURL`），
  导致 analyzer 报警告 `sdk_version_since`：

  ```
  This API is available since SDK 3.10.0, but constraints '>=3.1.0 <4.0.0'
  don't guarantee it.
  ```

- 将下界提到 `3.10.0`，使**声明与代码一致**（属修正根因，而非抑制告警）。
  本应用 Dart SDK 为 3.12+，对依赖解析与产物**零影响**
- ⚠️ 这是本 fork 中**唯一一处 `lib/` 之外的改动**，升级时最容易漏掉，特此记录

### 应用层配套（不在本 fork 内，但依赖本补丁）

| 位置 | 作用 |
|---|---|
| `lib/pages/player/player_page.dart` | 构造 `Player` 时注入 `libassAndroidFontsDir` / `libassAndroidFontName` |
| `lib/models/subtitle_font_injection.dart` | 纯函数 `shouldInjectCustomSubtitleFont()`：决定是否注入（可单测） |
| `lib/services/subtitle_service.dart` | 默认系统字库场景才 set `sub-fonts-dir`，避免运行时覆盖构造注入 |
| `lib/services/device_services.dart` | 字体落盘、家族名解析、默认字体兜底拷贝 |

## 4. 升级步骤

1. 从 pub 缓存取到目标版本源码（或从 GitHub Release 下载对应 tag）。
2. 与当前 fork 做差异对照，确认本文件列出的 4 处补丁仍需要：
   ```powershell
   # Dart 源码（补丁 1~3）
   git diff --no-index --ignore-cr-at-eol `
     'third_party\media_kit\lib' `
     "$env:LOCALAPPDATA\Pub\Cache\hosted\pub.flutter-io.cn\media_kit-<新版本>\lib"
   # pubspec.yaml（补丁 4：SDK 约束下界）
   git diff --no-index --ignore-cr-at-eol `
     'third_party\media_kit\pubspec.yaml' `
     "$env:LOCALAPPDATA\Pub\Cache\hosted\pub.flutter-io.cn\media_kit-<新版本>\pubspec.yaml"
   ```
3. 若上游已合并等价能力（例如新增了通用的「初始化 option 透传」或「运行时字体目录」
   入口），**优先改用上游 API 并删除本 fork** —— 少一个 fork 就少一份维护成本。
4. 否则以新版本源码为基线，重新施加上述 4 处补丁（`real.dart` 的补丁集中在
   `_create()` 开头一处，`pubspec.yaml` 仅改 SDK 下界一行，冲突面都很小）。
5. 更新本文件第 2 节的「基线版本」，并在 commit message 里注明。

## 5. 验证方法

| 验证项 | 做法 |
|---|---|
| 补丁完整 | 上面的 `Select-String 【魔改】` 应能列出全部标记点（补丁 4 在 `pubspec.yaml`，需单独核对） |
| SDK 约束生效 | `flutter analyze` 输出中**不应出现** `sdk_version_since` 或 `media_kit` 路径 |
| 纯增量未破坏上游 | 与新版本 diff，除补丁点外**不应有其它差异** |
| 扩展名清单一致 | `_hasFontFile()` 的 4 项扩展名 == `lib/models/subtitle_track.dart` 的 `kFontExtensions` |
| 新字段不传时行为如常 | 播放任意视频，字幕走 `/system/fonts` 系统字库正常显示 |
| 自定义字体生效 | 导入字体后重开视频，字幕按新字体渲染（`sub-font` / `sub-fonts-dir` 生效） |

## 6. 需要留意的上游未发布改动

上游 `main` 分支在 1.2.6 之后已有若干**未发布**提交（pub.dev 最新发布版仍是 1.2.6），
其中一条与本项目 Flutter 版本相关，升级时值得关注：

- `real.dart` 的 `nativeEnsureInitialized()` dispose 路径新增
  `mpv_set_wakeup_callback(handle, nullptr, nullptr)`，用于避免 mpv 调用已释放的
  Dart `NativeCallable`（上游 issue #1314，表现为 **Flutter 3.38+ 上的 SIGABRT**）。
- 另有 `Player.observeEvent()` 公开 API、`PlayerConfiguration.iosManageAudioSession`
  等新增能力。

本项目当前 Flutter 版本为 3.44.x，若遇到 SIGABRT 类崩溃，可优先排查此项。
