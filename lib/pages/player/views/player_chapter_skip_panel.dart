import 'package:flutter/material.dart';
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
        final s = ChapterSkipSettings.instance;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '自动跳过',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '进入对应片段时自动跳到片段结束；关闭则仅弹出跳过胶囊',
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
              const Text(
                '自定义关键词',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '按章节标题匹配，支持逗号 / 分号 / 换行分隔',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 12),
              _KeywordField(
                label: '片头关键词',
                accent: ChapterSkipType.intro.color,
                hint: '如 ap、op、开场',
                value: s.customIntroKeywords,
                onChanged: s.setCustomIntroKeywords,
              ),
              const SizedBox(height: 12),
              _KeywordField(
                label: '片尾关键词',
                accent: ChapterSkipType.outro.color,
                hint: '如 ed、ending、结尾',
                value: s.customOutroKeywords,
                onChanged: s.setCustomOutroKeywords,
              ),
              const SizedBox(height: 12),
              Text(
                '关键词归属由你填入的位置决定：填进「片头关键词」即判为片头、'
                '填进「片尾关键词」即判为片尾；同一标题命中多类时按固定优先级'
                '（前情提要 > 正片前段 > 制作人员 > 下集预告 > 片尾 > 片头）取一类。',
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
              type.label,
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
