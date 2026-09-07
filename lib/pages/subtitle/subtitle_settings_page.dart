import 'package:flutter/material.dart';
import 'package:moumou/pages/subtitle/views/subtitle_settings_section.dart';

/// 字幕设置页：WYZIE API 密钥、字幕来源、字幕语言、首选格式、首选编码。
///
/// 由字幕下载页的「字幕设置」入口进入，五项设置集中在独立子页，避免把
/// 下载主页占得太长。
class SubtitleSettingsPage extends StatelessWidget {
  const SubtitleSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('字幕设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: const [SubtitleSettingsSection()],
      ),
    );
  }
}
