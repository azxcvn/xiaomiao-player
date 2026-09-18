/// 弹幕服务器设置（工作.md 第 6/7 点）：全局单例 ChangeNotifier +
/// shared_preferences 持久化，管理：
/// - 弹幕服务器列表（内置弹弹Play 默认服务器 + 用户自建服务器，可增删/启停）；
/// - 「切集自动匹配弹幕」开关；
/// - 「搜索结果自动去重」开关（多台服务器返回同一部番剧时只留先到的那条）。
///
/// 启用的服务器同时用于网络弹幕搜索与自动匹配；搜索按各服务器返回顺序
/// **逐台实时呈现**（不再等全部返回再合并），见
/// `services/danmaku_network_service.dart` 的 `searchStream`。
///
/// **互斥约束（工作.md 第 7 点，收尾阶段恢复）**：默认弹弹Play 服务器启用时
/// 不允许开启「切集自动匹配」。为避免 UI 与运行时各判一次而漂移，互斥统一
/// 由本服务裁决——[autoMatchEnabled] 是唯一生效值（默认服务器启用时恒 false），
/// [autoMatchAllowed] / [autoMatchBlockedReason] 供 UI 变灰与提示文案复用。
/// 用户原始偏好保留在 [autoMatchPreference]，停用默认服务器后自动恢复生效。
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moumou/models/danmaku_server.dart';

class DanmakuServerSettings extends ChangeNotifier {
  static final DanmakuServerSettings instance = DanmakuServerSettings._();

  DanmakuServerSettings._();

  static const _keyServers = 'dandanplay_servers';
  static const _keyAutoMatch = 'danmaku_auto_match_enabled';
  static const _keySearchDedupe = 'danmaku_search_dedupe';
  static const _keySearchDedupeHint = 'danmaku_search_dedupe_hint_dismissed';

  /// 加载去重（risk_audit #9）：setter 在改设置前 await [ensureLoaded]。
  Future<void>? _loadFuture;

  Future<void> ensureLoaded() => _loadFuture ??= load();

  List<DanmakuServer> _servers = [DanmakuServer.createDefault()];
  bool _autoMatchEnabled = false;
  bool _searchDedupe = false;
  bool _searchDedupeHintDismissed = false;

  /// 全部服务器（含默认）
  List<DanmakuServer> get servers => List.unmodifiable(_servers);

  /// 已启用的服务器（搜索 / 匹配用）
  List<DanmakuServer> get enabledServers =>
      _servers.where((s) => s.isEnabled).toList();

  /// 「切集自动匹配弹幕」**生效值**（UI 显示与运行时判定都用这个）。
  ///
  /// 与默认弹弹Play 服务器**互斥**（工作.md 第 7 点收尾恢复的限制）：默认
  /// 服务器启用时恒为 false，无论用户此前存过什么偏好。
  bool get autoMatchEnabled => _autoMatchEnabled && !isDefaultEnabled;

  /// 用户存下来的原始偏好（**不含互斥判定**，仅供设置页/测试观察）。
  ///
  /// 保留原始值的意义：用户停用默认服务器 → 开启自动匹配 → 又启用默认服务器
  /// 时，只是「暂时不生效」；再次停用默认服务器即恢复其选择，不静默丢偏好。
  bool get autoMatchPreference => _autoMatchEnabled;

  /// 当前是否允许开启「切集自动匹配」（默认服务器启用时不允许）
  bool get autoMatchAllowed => !isDefaultEnabled;

  /// 不允许开启时的**短**原因文案（副标题用）；允许时为 null。
  ///
  /// 副标题空间有限（窄屏两行就显挤），这里只给动作指引；完整解释见
  /// [autoMatchBlockedMessage]（点击时的 toast）。两句都放在服务层，
  /// 页面里不出现文案字面量，避免多处措辞漂移。
  String? get autoMatchBlockedReason =>
      autoMatchAllowed ? null : '请先停用弹弹Play 服务器';

  /// 不允许开启时的**完整**说明（toast 用）；允许时为 null。
  String? get autoMatchBlockedMessage => autoMatchAllowed
      ? null
      : '已启用「${DanmakuServer.defaultName}」服务器时不可开启'
            '「切集自动匹配弹幕」，如需使用请先停用该服务器';

  /// 默认（弹弹Play）服务器当前是否启用
  bool get isDefaultEnabled => _servers.any((s) => s.isDefault && s.isEnabled);

  /// 网络弹幕搜索结果是否**跨服务器去重**（默认**关**）。
  ///
  /// - 开：同一部番剧（animeId 相同）只保留一条。先返回的先上屏（不为比较而
  ///   等待），后面某台返回的**集数更多**时替换掉那张卡；集数相同/更少则丢弃。
  /// - 关：每台服务器的结果各自成卡，同一部番剧可能出现多条（各带来源胶囊），
  ///   由用户按来源自己挑。
  ///
  /// 默认关的理由：去重会"合并掉"某些服务器的结果，属于用户需要知情的动作——
  /// 由用户在设置页主动开启（开启时给二次确认，文案见
  /// [searchDedupeHintDismissed] 对应的弹窗）。
  ///
  /// 只在 `DanmakuNetworkService.searchStream` 里读取，UI 不做二次判定
  /// （同 [autoMatchEnabled] 的纪律：单一事实来源）。
  bool get searchDedupe => _searchDedupe;

  /// 用户是否勾过「不再提示」（开启去重前的二次确认弹窗）。
  ///
  /// 只在 UI 层（弹幕服务器设置页）用来决定弹不弹；勾过一次后不再打扰。
  bool get searchDedupeHintDismissed => _searchDedupeHintDismissed;

  /// 服务器地址 → 展示名（弹幕「来源」显示的单一事实来源）。
  ///
  /// - [url] 为 null（默认服务器）→ [DanmakuServer.defaultName]；
  /// - 命中自建服务器 → 其名称；
  /// - 地址已不存在（服务器被删除，但缓存里仍记着）→ 原样回显地址，
  ///   至少让用户知道"来自哪里"，而不是显示空白。
  ///
  /// ⚠️ 文案只在本层出现：网络弹幕面板与加载成功的 toast 都用它，
  /// 避免"来源"在两处各写一份措辞而漂移（同 [autoMatchBlockedMessage] 的纪律）。
  String serverLabelFor(String? url) {
    if (url == null || url.isEmpty) return DanmakuServer.defaultName;
    for (final s in _servers) {
      if (!s.isDefault && s.url == url) return s.name;
    }
    return url;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _servers = _decodeServers(prefs.getString(_keyServers));
    _autoMatchEnabled = prefs.getBool(_keyAutoMatch) ?? false;
    _searchDedupe = prefs.getBool(_keySearchDedupe) ?? false;
    _searchDedupeHintDismissed = prefs.getBool(_keySearchDedupeHint) ?? false;
    notifyListeners();
  }

  /// 防御性解码：损坏数据回退「仅默认服务器」，且始终兜底保留默认服务器。
  List<DanmakuServer> _decodeServers(String? raw) {
    if (raw == null || raw.isEmpty) {
      return [DanmakuServer.createDefault()];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final list = <DanmakuServer>[];
        for (final item in decoded) {
          if (item is Map) {
            final s = DanmakuServer.fromJson(item.cast<String, dynamic>());
            if (s != null) list.add(s);
          }
        }
        if (list.every((s) => !s.isDefault)) {
          list.insert(0, DanmakuServer.createDefault());
        }
        return list;
      }
    } catch (_) {
      // 损坏数据回退默认
    }
    return [DanmakuServer.createDefault()];
  }

  Future<void> _persistServers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyServers,
      jsonEncode([for (final s in _servers) s.toJson()]),
    );
  }

  /// 添加自建服务器（名称 + 地址；地址统一去掉末尾 `/`）。
  Future<void> addServer(String name, String url) async {
    await ensureLoaded();
    final trimmedName = name.trim();
    var trimmedUrl = url.trim();
    while (trimmedUrl.endsWith('/')) {
      trimmedUrl = trimmedUrl.substring(0, trimmedUrl.length - 1);
    }
    if (trimmedName.isEmpty || trimmedUrl.isEmpty) return;
    _servers = [
      ..._servers,
      DanmakuServer(
        id: 'custom-${DateTime.now().microsecondsSinceEpoch}',
        name: trimmedName,
        url: trimmedUrl,
        isEnabled: true,
        isDefault: false,
      ),
    ];
    notifyListeners();
    await _persistServers();
  }

  /// 删除服务器（默认服务器不可删除，忽略该请求）。
  Future<void> removeServer(String id) async {
    await ensureLoaded();
    final target = _servers.where((s) => s.id == id).firstOrNull;
    if (target == null || target.isDefault) return;
    _servers = _servers.where((s) => s.id != id).toList();
    notifyListeners();
    await _persistServers();
  }

  /// 切换服务器启停。
  Future<void> setServerEnabled(String id, bool enabled) async {
    await ensureLoaded();
    _servers = [
      for (final s in _servers) s.id == id ? s.copyWith(isEnabled: enabled) : s,
    ];
    notifyListeners();
    await _persistServers();
  }

  /// 设置「切集自动匹配弹幕」开关。
  ///
  /// 限制（工作.md 第 7 点，收尾阶段恢复）：默认弹弹Play 服务器启用时
  /// **拒绝开启**，返回 false 供 UI 弹 toast；关闭永远允许。写偏好本身
  /// 不做互斥擦除——互斥在读取侧（[autoMatchEnabled]）生效，用户停用默认
  /// 服务器后其选择自动恢复。
  Future<bool> setAutoMatchEnabled(bool enabled) async {
    await ensureLoaded();
    if (enabled && !autoMatchAllowed) return false;
    if (_autoMatchEnabled == enabled) return true;
    _autoMatchEnabled = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoMatch, enabled);
    return true;
  }

  /// 设置「搜索结果自动去重」开关（写偏好 + 立即通知 UI）。
  ///
  /// ⚠️ 开启前 UI 会先弹二次确认说明它会做什么（集数更全的源替换先到的、
  /// 某台的结果可能不单独出现），确认后才调这里。
  Future<void> setSearchDedupe(bool enabled) async {
    await ensureLoaded();
    if (_searchDedupe == enabled) return;
    _searchDedupe = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySearchDedupe, enabled);
  }

  /// 记录用户勾了「不再提示」（此后开启去重不再弹二次确认）。
  Future<void> setSearchDedupeHintDismissed(bool dismissed) async {
    await ensureLoaded();
    if (_searchDedupeHintDismissed == dismissed) return;
    _searchDedupeHintDismissed = dismissed;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySearchDedupeHint, dismissed);
  }

  /// 测试用：恢复默认值并清加载标记（单例在测试间共享，避免状态泄漏）。
  @visibleForTesting
  void resetForTest() {
    _loadFuture = null;
    _servers = [DanmakuServer.createDefault()];
    _autoMatchEnabled = false;
    _searchDedupe = false;
    _searchDedupeHintDismissed = false;
    notifyListeners();
  }
}
