import 'dart:math';

import 'package:flutter/material.dart';
import 'package:moumou/l10n/app_localizations.dart';
import 'package:moumou/models/video_file.dart';

/// 从当前可见视频中等概率抽取一项，沿用页面原有的播放入口。
class RandomVideoButton extends StatelessWidget {
  final List<VideoFile> videos;
  final ValueChanged<VideoFile> onSelected;

  const RandomVideoButton({
    super.key,
    required this.videos,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.shuffle_rounded),
      tooltip: AppLocalizations.of(context).homeRandomPlay,
      onPressed: videos.isEmpty
          ? null
          : () => onSelected(videos[Random().nextInt(videos.length)]),
    );
  }
}
