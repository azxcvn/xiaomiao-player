/// 弹幕「指定颜色」的**调色板取色**纯函数/小状态机。
///
/// 背景：原先「指定颜色」只能定一种色，所有弹幕一个颜色；用户诉求是
/// 「自选几种颜色，弹幕随机用这几种」。取色策略：
/// - 从已选列表里**随机抽**一个（不是色轮顺序步进——用户选的是具体色，
///   顺序推进会让相邻弹幕排成彩虹，随机才符合「随机这几种颜色」的诉求）；
/// - **相邻两条不重色**（列表 ≥ 2 时生效）：否则连着两条同色看起来像没生效。
///
/// 抽色是逐条弹幕发生的（[DanmakuController._addEntry]），因此这里做成一个小
/// 状态机（记住上一条颜色）而不是无状态函数；随机源可注入，单测用固定种子。
library;

import 'dart:math';

/// 调色板抽色器：持有「上一条颜色」，保证相邻两条不重色。
class DanmakuPalettePicker {
  DanmakuPalettePicker({List<int> colors = const [], Random? random})
    : _colors = List.of(colors),
      _random = random ?? Random();

  /// 已选颜色（`0xRRGGBB` 整数，与渲染层同格式）
  List<int> _colors;

  final Random _random;

  /// 上一次抽出的颜色（null = 还没抽过；模式切换/换调色板时重建对象即重置）
  int? _last;

  /// 当前已选颜色数量
  int get length => _colors.length;

  /// 替换调色板（用户改已选色时调用），并忘掉上一条颜色
  /// （集合变了，「相邻不重色」的约束重新开始）
  void updateColors(List<int> colors) {
    _colors = List.of(colors);
    _last = null;
  }

  /// 抽下一条弹幕的颜色；调色板为空返回 null（调用方自行回退）。
  ///
  /// 列表只有 1 种时只能返回它（去重无从谈起）；≥ 2 种时在上一条之外的
  /// 候选里等概率抽，且**只在**上一条仍在候选里时才排除它（防止越界）。
  int? next() {
    if (_colors.isEmpty) return null;
    if (_colors.length == 1) {
      _last = _colors.first;
      return _last;
    }
    final candidates = _last == null
        ? _colors
        : _colors.where((c) => c != _last).toList(growable: false);
    // 理论上 candidates 非空（≥2 种且 _last 来自本列表）；兜底用全量
    final pool = candidates.isEmpty ? _colors : candidates;
    final picked = pool[_random.nextInt(pool.length)];
    _last = picked;
    return picked;
  }
}
