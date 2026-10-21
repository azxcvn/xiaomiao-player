import 'package:flutter/widgets.dart';

/// 关掉 [context] 所在路由上方的全部路由（面板 / 弹窗），再关掉该路由本身。
///
/// 播放页的面板、设备选择弹窗都是独立路由。自动退出时若只 `Navigator.pop()`
/// 一次，弹掉的是最上面的面板而不是播放页；此时播放页的退出标志已置位，
/// 返回键与左上角返回都会被当成「重复退出」忽略，页面卡死只能杀后台
/// （用户反馈：播放完成自动退出 + 打开「更多」面板）。
///
/// 以调用方路由为锚点先清掉上方路由，再关调用方路由，与上方叠了几层无关。
/// - 锚点路由不在栈里 / 上方路由没关干净时不 pop 锚点，避免误关下层页面；
/// - `isFirst` 兜底：不会一路清到首页。
void popRouteAndAbove(BuildContext context) {
  final navigator = Navigator.of(context);
  final route = ModalRoute.of(context);
  if (route == null) {
    navigator.pop();
    return;
  }
  navigator.popUntil((r) => r == route || r.isFirst);
  if (!route.isCurrent) return;
  navigator.pop();
}

/// 关掉压在 [context] 所在路由上方的弹层（播放器面板 / 弹窗），返回是否
/// 真的关掉了东西。
///
/// 只动 [PopupRoute]：竖屏播放页（普通页面路由）也压在横屏播放页之上，
/// 但它不是弹层，不能在这里被提前关掉（关掉会露出尚未黑化的横屏页）。
bool popOverlaysAbove(BuildContext context) {
  final navigator = Navigator.of(context);
  final route = ModalRoute.of(context);
  if (route == null) return false;
  var popped = false;
  navigator.popUntil((r) {
    if (r == route || r is! PopupRoute) return true;
    popped = true;
    return false;
  });
  return popped;
}

