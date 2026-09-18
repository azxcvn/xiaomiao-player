/// 网络弹幕**搜索会话状态**（跨面板重建存活）。
///
/// 为什么必须放在面板外面：外壳（PlayerPanel / PlayerBottomPanel）只构建页面
/// 栈**栈顶**那一页——从搜索结果点进「集数二级界面」时，网络弹幕面板会被卸载，
/// 返回后 State 重建。结果若存在面板 State 里就会全丢，用户得重搜一次，而重复
/// 向弹弹Play 发同样的搜索请求既没意义，也容易触发风控。
///
/// 生命周期（用户拍板，见 [beginPanelSession] / [markKeepOnClose]）：
/// - **面板内前进/后退**（进集数页再点返回/误触返回）：结果、关键词、结果列表
///   滚动位置全部保留，不重新请求；
/// - **选完某一集导致的自动关闭**：不算用户主动关面板，结果继续留着，下次打开
///   面板仍能看到上次的搜索（省一次请求）；
/// - **用户主动关掉面板**（点 X / 点遮罩 / 返回键）：等价于关掉搜索结果——
///   下次打开弹幕面板时清空（[beginPanelSession] 收尾）。
///
/// 只在 App 运行期间保留（不落盘）：重启 App 自然从干净状态开始。
library;

import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:moumou/services/danmaku_network_service.dart';
import 'package:moumou/utils/async_session.dart';

class DanmakuSearchStore extends ChangeNotifier {
  /// 注入网络服务（测试用假服务）；不传则自建一个（本类持有到进程结束——
  /// 单例场景下比"每开一次面板新建/释放一个 http.Client"更省）。
  DanmakuSearchStore({DanmakuNetworkService? network})
    : _network = network ?? DanmakuNetworkService();

  /// 应用级单例：面板关闭后它还在，所以结果能跨面板存活
  static final DanmakuSearchStore instance = DanmakuSearchStore();

  final DanmakuNetworkService _network;

  /// 搜索会话令牌（[AsyncSession]，§4.29）：后发起的搜索作废在途的那次
  final AsyncSession _session = AsyncSession();

  StreamSubscription<DanmakuServerSearchOutcome>? _sub;

  String _keyword = '';
  List<DanmakuSearchItem> _results = [];
  bool _searching = false;
  bool _stopped = false;
  List<String> _serverErrors = [];
  String? _error;
  bool _keepOnClose = false;

  /// 最近一次搜索的关键词（面板输入框与折叠条都读它）
  String get keyword => _keyword;

  /// 已到达的结果（只读视图，顺序 = 服务器返回顺序）
  List<DanmakuSearchItem> get results => UnmodifiableListView(_results);

  /// 还有服务器没返回
  bool get searching => _searching;

  /// 用户手动停止了本次搜索
  bool get stopped => _stopped;

  /// 各服务器失败原因（有结果时以状态条提示）
  List<String> get serverErrors => UnmodifiableListView(_serverErrors);

  /// 一条结果都没有时的整条错误文案
  String? get error => _error;

  /// 结果列表滚动位置（返回面板时原地复原）。
  ///
  /// 故意是可变公开字段、且**不**通知监听者：它由面板的滚动控制器每次滚动写入，
  /// 通知会导致"滚动 → 重建 → 再滚"的循环。
  double listOffset = 0;

  /// 发起搜索：先清空上一轮，再逐台服务器**边到边**把结果挂上来。
  ///
  /// 搜索中再搜不被吞（键盘搜索键 / 历史胶囊 / 搜索箭头都照常发起），
  /// 由 [_session]（会话令牌）保证结果永远属于**最后一次**输入的关键词。
  Future<void> search(String keyword) async {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) return;
    final session = _session.start();
    _cancelStream(); // 旧流立刻断开：不在网里堆请求
    _keyword = trimmed;
    _results = [];
    _searching = true;
    _stopped = false;
    _serverErrors = [];
    _error = null;
    listOffset = 0;
    notifyListeners();
    _sub = _network
        .searchStream(trimmed)
        .listen(
          (outcome) => _onOutcome(session, outcome),
          onError: (Object error) => _onOutcome(
            session,
            DanmakuServerSearchOutcome(
              serverName: '',
              serverUrl: null,
              error: '$error',
            ),
          ),
          onDone: () => _onDone(session),
          cancelOnError: false,
        );
  }

  /// 用户点「停止」：中断后续服务器，已到达的结果**保留**
  void stop() {
    _cancelStream();
    _session.invalidate();
    _searching = false;
    _stopped = true;
    notifyListeners();
  }

  /// 打开弹幕面板时调用（面板页构造处）。
  ///
  /// 上一次如果是**用户主动关面板**，此时等价于"关掉了搜索结果" → 清空；
  /// 上一次如果是**选完一集自动关闭**（[markKeepOnClose] 标记过）→ 保留一次，
  /// 让用户打开面板还能接着上次挑。
  void beginPanelSession() {
    if (_keepOnClose) {
      _keepOnClose = false;
      return;
    }
    if (_keyword.isEmpty && _results.isEmpty && !_searching && _error == null) {
      return; // 本来就没有东西要清
    }
    clear();
  }

  /// 标记"这次面板关闭是选完一集导致的自动关闭"（集数界面选中某集时调用）
  void markKeepOnClose() {
    _keepOnClose = true;
  }

  /// 是否已打上"下次面板关闭要保留结果"的标记（测试观察用）
  @visibleForTesting
  bool get keepOnClose => _keepOnClose;

  /// 测试用：清空会话并复位保留标记（单例在测试间共享，避免状态泄漏）
  @visibleForTesting
  void resetForTest() {
    _keepOnClose = false;
    clear();
  }

  /// 清空搜索会话（结果、关键词、进度、滚动位置）
  void clear() {
    _cancelStream();
    _session.invalidate();
    _keyword = '';
    _results = [];
    _searching = false;
    _stopped = false;
    _serverErrors = [];
    _error = null;
    listOffset = 0;
    notifyListeners();
  }

  void _cancelStream() {
    final sub = _sub;
    _sub = null;
    if (sub != null) unawaited(sub.cancel());
  }

  void _onOutcome(int session, DanmakuServerSearchOutcome outcome) {
    if (!_session.isCurrent(session)) return;
    final error = outcome.error;
    if (error != null && error.isNotEmpty) _serverErrors.add(error);
    _results.addAll(outcome.items);
    // 同一 animeId 若这台集数更全 → 就地覆盖旧卡（不新增重复项）
    for (final upgraded in outcome.upgrades) {
      final at = _results.indexWhere(
        (r) => r.anime.animeId == upgraded.anime.animeId,
      );
      if (at >= 0) {
        _results[at] = upgraded;
      } else {
        _results.add(upgraded);
      }
    }
    notifyListeners();
  }

  void _onDone(int session) {
    if (!_session.isCurrent(session)) return;
    _sub = null;
    _searching = false;
    _error = _results.isEmpty
        ? (_serverErrors.isEmpty
              ? '未找到相关番剧，请尝试其他关键词'
              : '搜索失败：${_serverErrors.join('；')}')
        : null;
    notifyListeners();
  }

  @override
  void dispose() {
    _cancelStream();
    super.dispose();
  }
}
