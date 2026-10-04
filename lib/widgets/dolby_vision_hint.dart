/// 杜比视界（Dolby Vision）偏色检测与引导（横屏 / 竖屏播放页共用，B4/P1-6）。
///
/// 历史：只在横屏页实现了这套检测 + 引导弹窗，竖屏页切集后**不检测**
/// （竖屏连看剧集时遇到杜比视界视频，画面发绿/发紫却没有任何提示）。
/// 抽成共用函数后两页行为一致；「每个媒体只测一次」由调用方用自身标志位控制
/// （切集时重置），与本函数内的设置/抑制判断分离。
///
/// 文案在 ARB：`dolbyVisionHintTitle` / `dolbyVisionHintBody` /
/// `commonDontAskAgain` / `commonGotIt`。
library;

import 'package:flutter/material.dart';
import 'package:moumou/l10n/app_localizations.dart';
import 'package:moumou/services/decode_settings.dart';
import 'package:moumou/services/dolby_vision_settings.dart';
import 'package:moumou/services/video_info_service.dart';
import 'package:moumou/utils/app_dialog.dart';
import 'package:moumou/utils/formatters.dart';

/// 本地文件为杜比视界、且未开 gpu-next、未被「不再提示」抑制时，弹窗引导
/// 用户启用 GPU-next 或切软解。
///
/// 在线播放（直链 / B 站）跳过：MediaInfo 需要真实路径。
/// [context] 为播放页的 State context，异步间隙后页面已销毁则静默放弃。
Future<void> showDolbyVisionHintIfNeeded(
  BuildContext context,
  String path,
) async {
  if (path.isEmpty || isOnlineMedia(path)) return;
  // 已开 gpu-next 或已软解：无需引导（硬解+ 也可能直通，同样提示）
  if (DecodeSettings.instance.gpuNext) return;
  await DolbyVisionSettings.instance.ensureLoaded();
  if (DolbyVisionSettings.instance.suppressed) return;
  final detected = await VideoInfoService.detectDolbyVision(path);
  if (!context.mounted) return;
  if (!detected.isDolbyVision) return;
  // 上面的 await 之后 context 可能已换帧，l10n 在弹窗**前**现取一次
  final l10n = AppLocalizations.of(context);
  final suppressed = await showAppDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.dolbyVisionHintTitle),
      content: Text(
        l10n.dolbyVisionHintBody,
        style: const TextStyle(fontSize: 14, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop('dismiss'),
          child: Text(l10n.commonDontAskAgain),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(null),
          child: Text(l10n.commonGotIt),
        ),
      ],
    ),
  );
  if (suppressed == 'dismiss') {
    await DolbyVisionSettings.instance.setSuppressed(true);
  }
}
