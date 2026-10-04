import 'package:flutter/material.dart';
import 'package:moumou/l10n/app_localizations.dart';
import 'package:moumou/l10n/label_maps.dart';
import 'package:moumou/models/chapter_info.dart';
import 'package:moumou/services/chapter_skip_settings.dart';

/// 章节跳段设置面板内容（章节列表面板「章节跳段」入口进入的二级页，
/// 横屏经 [showPlayerPanel] 右侧滑入、竖屏经 [showPlayerBottomPanel] 底部弹出）。
///
/// 针对**有章节信息**的视频：按章节标题识别出六类片段，本面板配置
/// ① 哪些类型进入时自动跳过；② 用户自定义片头/片尾关键词（与内置
/// 关键词表共同参与标题分类）。
class PlayerChapterSkipPanel extends StatelessWidget {
  const PlayerChapterSkipPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ChapterSkipSettings.instance,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context);
        final s = ChapterSkipSettings.instance;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.playerChapterSkipAuto,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.playerChapterSkipAutoDesc,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 8),
              for (final type in ChapterSkipType.values)
                _TypeToggleRow(
                  type: type,
                  enabled: s.autoSkip(type),
                  onChanged: (v) => s.setAutoSkip(type, v),
                ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: Colors.white12),
              const SizedBox(height: 16),
              Text(
                l10n.playerChapterSkipCustomKeywords,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.playerChapterSkipKeywordsHint,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 12),
              _KeywordField(
                label: l10n.playerIntroKeywords,
                accent: ChapterSkipType.intro.color,
                hint: l10n.playerIntroKeywordsHint,
                value: s.customIntroKeywords,
                onChanged: s.setCustomIntroKeywords,
              ),
              const SizedBox(height: 12),
              _KeywordField(
                label: l10n.playerOutroKeywords,
                accent: ChapterSkipType.outro.color,
                hint: l10n.playerOutroKeywordsHint,
                value: s.customOutroKeywords,
                onChanged: s.setCustomOutroKeywords,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.playerChapterSkipKeywordOwnerHint,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 单个片段类型的自动跳过开关行：类型色圆点 + 名称 + Switch。
class _TypeToggleRow extends StatelessWidget {
  final ChapterSkipType type;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _TypeToggleRow({
    required this.type,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: type.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              chapterSkipTypeLabel(AppLocalizations.of(context), type),
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          Switch(
            value: enabled,
            onChanged: onChanged,
            activeTrackColor: type.color.withValues(alpha: 0.7),
            activeThumbColor: type.color,
          ),
        ],
      ),
    );
  }
}

/// 自定义关键词输入框（暗底圆角，样式对齐片头片尾面板的 [TextStyle] 装饰）。
class _KeywordField extends StatefulWidget {
  final String label;
  final Color accent;
  final String hint;
  final String value;
  final ValueChanged<String> onChanged;

  const _KeywordField({
    required this.label,
    required this.accent,
    required this.hint,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_KeywordField> createState() => _KeywordFieldState();
}

class _KeywordFieldState extends State<_KeywordField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value);
  late final FocusNode _focus = FocusNode();

  @override
  void didUpdateWidget(covariant _KeywordField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 外部改值（如切换关键词）时同步文本；正在输入时不覆盖
    if (!_focus.hasFocus && oldWidget.value != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.73),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _controller,
          focusNode: _focus,
          onChanged: widget.onChanged,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          cursorColor: widget.accent,
          decoration: InputDecoration(
            isDense: true,
            hintText: widget.hint,
            hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
            filled: true,
            fillColor: const Color(0xFF1A2332),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
