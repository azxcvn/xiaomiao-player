/// 播放器着色器链的统一出口：超分（Anime4K）与后处理都把自己那一段登记到
/// 这里，由本类拼成**一条** `glsl-shaders` 链写给 mpv。
///
/// 为什么需要：两套功能都会写 `change-list glsl-shaders set`，谁后写谁就把
/// 对方整条链覆盖掉（表现就是"开超分后后处理失效"或反过来）。收口到一处后，
/// 两边各自只登记自己的链，拼接顺序固定：**超分 → 后处理**（先放大再加效果）。
///
/// 换播放器实例（新一次进播放页）时两段链都清空：新 mpv 实例没有旧着色器，
/// 两边会各自重新 apply。
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

/// 拼链纯函数（可单测）：超分链在前、后处理链在后，空链不产生空段
List<String> composeShaderChain(
  List<String> animePaths,
  List<String> postPaths,
) {
  return [
    ...animePaths.where((p) => p.isNotEmpty),
    ...postPaths.where((p) => p.isNotEmpty),
  ];
}

class PlayerShaderPipeline {
  PlayerShaderPipeline._();

  static final PlayerShaderPipeline instance = PlayerShaderPipeline._();

  Player? _player;
  List<String> _anime = const [];
  List<String> _post = const [];

  /// 串行化写链命令：两套服务可能同时 apply，交错执行会让 mpv 收到半条链
  Future<void> _queue = Future<void>.value();

  /// 登记超分链（传空 = 关闭超分）
  Future<void> setAnime(Player player, List<String> paths) {
    _rememberPlayer(player);
    _anime = List<String>.unmodifiable(paths);
    return _enqueueApply();
  }

  /// 登记后处理链（传空 = 关闭后处理）
  Future<void> setPost(Player player, List<String> paths) {
    _rememberPlayer(player);
    _post = List<String>.unmodifiable(paths);
    return _enqueueApply();
  }

  void _rememberPlayer(Player player) {
    if (identical(_player, player)) return;
    _player = player;
    _anime = const [];
    _post = const [];
  }

  Future<void> _enqueueApply() {
    final player = _player;
    if (player == null) return Future<void>.value();
    final next = _queue.then((_) => _apply(player));
    _queue = next;
    return next;
  }

  Future<void> _apply(Player player) async {
    try {
      final native = player.platform as NativePlayer;
      final chain = composeShaderChain(_anime, _post);
      if (chain.isEmpty) {
        await native.command(const [
          'change-list',
          'glsl-shaders',
          'clr',
          '',
        ]);
        return;
      }
      await native.command([
        'change-list',
        'glsl-shaders',
        'set',
        chain.join(Platform.isWindows ? ';' : ':'),
      ]);
    } catch (e) {
      // 播放器未就绪 / 渲染器不支持：静默失败，不打断播放
      debugPrint('PlayerShaderPipeline: 应用着色器链失败: $e');
    }
  }

  /// 测试用：清空登记状态（单例在测试间共享，避免互相影响）
  @visibleForTesting
  void resetForTest() {
    _player = null;
    _anime = const [];
    _post = const [];
    _queue = Future<void>.value();
  }
}
