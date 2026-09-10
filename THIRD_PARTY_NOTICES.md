> 第三方组件声明 / Third-Party Notices（原 LICENSE 文件中的附注部分，独立存档
> 以便 GitHub 正确识别仓库 MIT 许可证）。

## 第三方组件声明 / Third-Party Notices

小喵Player（moumou）基于以下开源组件构建。各组件版权归其各自作者所有，并
在各自许可证条款下分发。应用内「设置 → 关于 → 许可证书」页面（Flutter
LicenseRegistry / showLicensePage）会自动汇总并展示已随包分发的全部许可证
全文，本清单为概要说明。

### Flutter / Dart 依赖（完整列出 pubspec.yaml 的全部直接依赖；版本以 pubspec.lock 解析结果为准，本地 fork 取其 `third_party/` 下 pubspec 的版本号）

| 组件 | 解析版本 | 许可证 |
| --- | --- | --- |
| [media_kit](https://pub.dev/packages/media_kit)（本地 fork：新增 `libassAndroidFontsDir` 支持运行时字体目录，见 third_party/media_kit/FORK.md） | 1.2.6 | MIT |
| [media_kit_video](https://pub.dev/packages/media_kit_video) | 1.3.1 | MIT |
| [media_kit_libs_video](https://pub.dev/packages/media_kit_libs_video)（含 ios/linux/macos/windows video 四个平台包，均 MIT） | 1.0.7 | MIT |
| [media_kit_libs_android_video](https://pub.dev/packages/media_kit_libs_android_video)（本地 fork：自建 Android 内核，内含 mpv v0.41.0 与 `mk_thumbnail_*` 导出符号） | 1.3.8-mk.1 | MIT |
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

- **media_kit 捆绑的原生库**：media_kit 系列包以 MIT 授权，但其 Android/iOS 等平台
  包会捆绑预编译的 libmpv / FFmpeg 原生库，这些库自身遵循 mpv（GPL-2.0+）与
  FFmpeg（LGPL-2.1+，部分组件 GPL）等许可证。进行二进制分发前请核实并遵守对应
  许可证义务。
- **本地 fork 组件**：`smb_connect`（Apache-2.0）、`media_kit` 与
  `media_kit_libs_android_video`（均 MIT）为本地魔改版，置于 `third_party/` 下并以
  `path:` 方式接入，版本号带 `-mk.N` 后缀（如 `0.0.9-mk.1`）。其中 `smb_connect` 与
  `media_kit` 的魔改内容、补丁清单与升级步骤见各自目录下的 `FORK.md`；
  `media_kit_libs_android_video` 为自建 Android 内核（内核来源见 ARCHITECTURE.md §4.9）。
  上游版权归属与许可证条款均不变。
- **图标素材**：assets/icons/ 下的 SVG 为 Material Design 图标风格素材
  （Apache-2.0 / 各素材原许可证），github.svg / email.svg 源自参考项目图标素材，
  仅作界面展示用途。
- **参考项目**：本项目开发过程中参考了 PiliPlus-main（GPL-3.0）、Kazumi-main
  （GPL-3.0）、mpvRx-master（AGPL-3.0）及 fam4k007 示例工程的设计与思路，但未
  复制其受保护代码；若日后引入参考项目代码，请另行遵守其原始许可证。
- 各依赖包内的 LICENSE 文件副本随 pub 缓存分发，亦可在上述许可证链接处获取。
