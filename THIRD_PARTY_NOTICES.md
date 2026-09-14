> 第三方组件声明 / Third-Party Notices（与仓库根目录的 `LICENSE` 配套；独立成文
> 以便 GitHub 正确识别仓库的 GPL-3.0 许可证）。

## 第三方组件声明 / Third-Party Notices

小喵Player（moumou）基于以下开源组件构建。各组件版权归其各自作者所有，并
在各自许可证条款下分发。应用内「设置 → 关于 → 许可证书」页面（Flutter
LicenseRegistry / showLicensePage）会自动汇总并展示已随包分发的全部许可证
全文，本清单为概要说明。

### 本项目自身的许可

- **小喵Player（moumou）自身代码以 GNU General Public License v3.0 发布**
  （全文见仓库根目录 `LICENSE`）。GPL-3.0 是 **copyleft** 许可：任何衍生分发
  必须以同一许可开源并提供对应源码，同时保留原作者版权声明。
- **与本清单的兼容性**：GPL-3.0 与下列各组件的许可**兼容**——MIT / BSD-2 /
  BSD-3 / ISC / Apache-2.0 均与 GPL-3.0 兼容；LGPL 组件（libmpv / FFmpeg）可被
  GPL-3.0 程序链接。⚠️ **注意**：因本项目含 Apache-2.0 组件（`smb_connect`、
  mbedTLS），**不能改为 GPL-2.0**（Apache-2.0 与 GPL-2.0 不兼容）。

### Flutter / Dart 依赖（完整列出 pubspec.yaml 的全部直接依赖；版本以 pubspec.lock 解析结果为准，本地 fork 取其 `third_party/` 下 pubspec 的版本号）

| 组件 | 解析版本 | 许可证 |
| --- | --- | --- |
| [media_kit](https://pub.dev/packages/media_kit)（本地 fork：新增 `libassAndroidFontsDir` 支持运行时字体目录，见 third_party/media_kit/FORK.md） | 1.2.6 | MIT |
| [media_kit_video](https://pub.dev/packages/media_kit_video) | 1.3.1 | MIT |
| [media_kit_libs_video](https://pub.dev/packages/media_kit_libs_video)（含 ios/linux/macos/windows video 四个平台包，均 MIT） | 1.0.7 | MIT |
| [media_kit_libs_android_video](https://pub.dev/packages/media_kit_libs_android_video)（本地 fork：自建 Android 内核，内含 **mpv v0.41.0-110-g32a164cc**（LGPL-2.1+）+ **FFmpeg 7.1.3**（LGPL-3.0+）+ `mk_thumbnail_*` 导出符号；构建开关见文末「说明」） | 1.3.8-mk.1 | MIT（包本身；捆绑库见文末说明） |
| [permission_handler](https://pub.dev/packages/permission_handler) | 11.4.0 | MIT |
| [shared_preferences](https://pub.dev/packages/shared_preferences) | 2.5.5 | BSD-3-Clause |
| [path_provider](https://pub.dev/packages/path_provider) | 2.1.6 | BSD-3-Clause |
| [path](https://pub.dev/packages/path) | 1.9.1 | BSD-3-Clause |
| [flex_seed_scheme](https://pub.dev/packages/flex_seed_scheme) | 4.0.1 | BSD-3-Clause |
| [saver_gallery](https://pub.dev/packages/saver_gallery) | 5.1.0 | MIT |
| [ffi](https://pub.dev/packages/ffi) | 2.2.0 | BSD-3-Clause |
| [package_info_plus](https://pub.dev/packages/package_info_plus) | 9.0.1 | BSD-3-Clause |
| [flutter_svg](https://pub.dev/packages/flutter_svg) | 2.3.0 | MIT |
| [canvas_danmaku](https://pub.dev/packages/canvas_danmaku) | 0.3.3 | MIT |
| [url_launcher](https://pub.dev/packages/url_launcher) | 6.3.2 | BSD-3-Clause |
| [http](https://pub.dev/packages/http) | 1.6.0 | BSD-3-Clause |
| [crypto](https://pub.dev/packages/crypto) | 3.0.7 | BSD-3-Clause |
| [qr_flutter](https://pub.dev/packages/qr_flutter) | 4.1.0 | BSD-3-Clause |
| [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage) | 9.2.4 | BSD-3-Clause |
| [smb_connect](https://pub.dev/packages/smb_connect)（本地 fork：去掉全局串行锁以支持请求并发在途，见 third_party/smb_connect/FORK.md） | 0.0.9-mk.1 | Apache-2.0 |
| [dlna_dart](https://pub.dev/packages/dlna_dart) | 0.1.1 | BSD-3-Clause |
| [flutter_markdown](https://pub.dev/packages/flutter_markdown) | 0.7.7+1 | BSD-3-Clause |
| [flutter_color_picker_plus](https://pub.dev/packages/flutter_color_picker_plus) | 2.2.1 | MIT |
| [permission_handler_platform_interface](https://pub.dev/packages/permission_handler_platform_interface)（dev） | 4.4.0 | MIT |
| [flutter_lints](https://pub.dev/packages/flutter_lints)（dev） | 6.0.0 | BSD-3-Clause |
| [flutter_launcher_icons](https://pub.dev/packages/flutter_launcher_icons)（dev） | 0.14.4 | MIT |

### Android 原生侧

| 组件 | 版本 | 许可证 |
| --- | --- | --- |
| [mediainfoAndroid](https://github.com/marlboro-advance/mediainfoAndroid)（JitPack：`com.github.marlboro-advance:mediainfoAndroid:v1.1.0`，MediaInfoLib 的 Android 绑定，参考 fam4k007 项目） | v1.1.0 | BSD-2-Clause |

### 资源 / 着色器

| 组件 | 说明 | 许可证 |
| --- | --- | --- |
| [Anime4K](https://github.com/bloc97/Anime4K) 着色器（assets/shaders/*.glsl，超分/恢复/降噪） | 每个 .glsl 文件头部均内嵌版权声明 | MIT（Copyright (c) 2019-2021 bloc97） |

### 说明 / Notes

- **本项目自带的自建内核（`third_party/media_kit_libs_android_video`）以 LGPL 方式构建，未启用任何 GPL 组件**。
  内核仓库 `azxcvn/libmpv-android-video-build-thumbnail` 的默认 flavor 编译开关为：
  FFmpeg `--disable-gpl --disable-nonfree --enable-version3`（→ **LGPL-3.0-or-later**）、
  mpv `-Dgpl=false`（→ **LGPL-2.1-or-later**）。仓库另有一个 `encoders-gpl` flavor（启用 libx264 等），
  **本项目未使用**。上述结论可由发布物 `libmpv.so` 内嵌的许可字符串
  （`libavcodec/avformat/avutil/swscale/swresample license: LGPL version 3 or later`）
  与「不存在 `ff_libx264_encoder` / `ff_libx265_encoder` 等 GPL-only 符号」交叉验证。
- **随包分发的原生库清单与版本**（每个 ABI 一个 `libmpv.so`；FFmpeg 静态链入其中）：
  mpv `v0.41.0-110-g32a164cc`（**LGPL-2.1-or-later**）· FFmpeg `7.1.3`（**LGPL-3.0-or-later**）·
  libass `0.17.1`（ISC）· libplacebo（LGPL-2.1+）· dav1d（BSD-2-Clause）· libxml2 `2.10.3`（MIT）·
  mbedTLS `3.4.0`（Apache-2.0）· MediaInfoLib / ZenLib（**BSD-2-Clause**）·
  media-kit-android-helper（MIT）。构建脚本、补丁与依赖版本表见内核仓库的 `buildscripts/`
  （`depinfo.sh` 为版本真值）。
- **LGPL 合规（本项目实际做法）**：上述 LGPL 组件以**独立动态库**（`libmpv.so`）形式随包分发，
  未静态链接进应用自身代码；其**完整对应源码**（含全部构建脚本与 `mk_thumbnail.patch` 等自有改动）
  公开于内核仓库 <https://github.com/azxcvn/libmpv-android-video-build-thumbnail>，
  任何人可获取、重建并**替换**该库。许可证全文亦随包分发，可在应用内
  「设置 → 关于 → 许可证书」查看。
- **本地 fork 组件**：`smb_connect`（Apache-2.0）、`media_kit` 与
  `media_kit_libs_android_video`（均 MIT）为本地魔改版，置于 `third_party/` 下并以
  `path:` 方式接入，版本号带 `-mk.N` 后缀（如 `0.0.9-mk.1`）。其中 `smb_connect` 与
  `media_kit` 的魔改内容、补丁清单与升级步骤见各自目录下的 `FORK.md`；
  `media_kit_libs_android_video` 为自建 Android 内核（内核来源见 docs/archive/ARCHITECTURE.md §4.9）。
  上游版权归属与许可证条款均不变。
- **图标素材**：assets/icons/ 下的 SVG 为 Material Design 图标风格素材
  （Apache-2.0 / 各素材原许可证），github.svg / email.svg 源自参考项目图标素材，
  仅作界面展示用途。
- **参考项目（仅参考设计与思路，未复制代码）**：本项目开发过程中参考了
  PiliPlus-main（GPL-3.0）、Kazumi-main（GPL-3.0）、mpvRx-master（AGPL-3.0）及
  fam4k007 示例工程的设计与思路。**这些参考项目的代码未以任何形式复制进本仓库**，
  故其 GPL/AGPL 条款不对本项目生效；若日后引入其任何代码，必须先按对应原始许可证处理。
- 各依赖包内的 LICENSE 文件副本随 pub 缓存分发，亦可在上述许可证链接处获取。
