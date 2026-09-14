/// SMB 客户端：纯 Dart 实现（基于 `smb_connect` 包），替代此前的 jcifs-ng 原生桥接。
///
/// 路径约定（对齐其余协议的 `NetworkPath` 语义）：`/` 表示服务器根（列共享），
/// `/share/...` 的第一段为共享名。`openRead(file, start, end)` 原生支持 offset 分段读取。
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:smb_connect/smb_connect.dart';
import 'package:moumou/models/network_connection.dart';
import 'package:moumou/models/network_file.dart';
import 'package:moumou/services/network/network_client.dart';
import 'package:moumou/services/network/smb_pipeline.dart';
import 'package:moumou/utils/network_mime_types.dart';

class SmbClient implements NetworkClient {
  final NetworkConnection connection;

  SmbClient(this.connection);

  SmbConnect? _connect;

  @override
  bool isConnected() => _connect != null;

  @override
  Future<void> connect() async {
    await disconnect();
    try {
      SmbConnect? created;
      created = await SmbConnect.connectAuth(
        host: connection.host,
        username: connection.isAnonymous ? '' : connection.username,
        password: connection.isAnonymous ? '' : connection.password,
        domain: '',
        // socket 真正断开（拔网线 / 服务端踢连接）时清掉引用：否则
        // `isConnected()` 会一直报 true，代理据此复用死连接（P2-20）。
        onDisconnect: (_) {
          if (identical(_connect, created)) _connect = null;
        },
      );
      _connect = created;
    } catch (e) {
      throw NetworkClientException(_friendly(e));
    }
  }

  @override
  Future<void> disconnect() async {
    final c = _connect;
    _connect = null;
    if (c == null) return;
    try {
      await c.close();
    } catch (_) {
      // 幂等断开，忽略异常
    }
  }

  @override
  Future<List<NetworkFile>> listFiles(String path) async {
    final c = _requireConnect();
    try {
      if (path == '/' || path.isEmpty) {
        final shares = await c.listShares();
        return [
          for (final f in shares)
            // 过滤管理/隐藏共享：ADMIN$、C$、D$、IPC$ 等以 $ 结尾，只保留普通共享。
            if (!f.name.endsWith(r'$'))
              NetworkFile(name: f.name, path: f.path, isDirectory: true),
        ];
      }
      final folder = await c.file(path);
      final files = await c.listFiles(folder);
      return files.map(_toFile).toList();
    } catch (e) {
      throw NetworkClientException(_friendly(e));
    }
  }

  @override
  Future<int> getFileSize(String path) async {
    final c = _requireConnect();
    try {
      final f = await c.file(path);
      return f.size;
    } catch (e) {
      debugPrint('[SMB] getFileSize($path) 失败: $e');
      return -1;
    }
  }

  @override
  Future<Stream<List<int>>> openStream(String path, {int offset = 0}) async {
    final c = _requireConnect();
    try {
      final f = await c.file(path);
      if (f.size > 0) {
        // 并发预读管线：取消/背压/出错停止都在 `smb_pipeline.dart` 里（P1-22），
        // 每次 `open` 都取一个**独立句柄**，让多个读请求同时在途。
        return pipelinedSmbStream(
          open: () => c.open(f, mode: FileMode.read),
          size: f.size,
          offset: offset,
        );
      }
      return await c.openRead(f, offset);
    } catch (e) {
      debugPrint('[SMB] openStream($path, $offset) 失败: $e');
      throw NetworkClientException(_friendly(e));
    }
  }

  SmbConnect _requireConnect() {
    final c = _connect;
    if (c == null) throw const NetworkClientException('SMB 尚未连接');
    return c;
  }

  NetworkFile _toFile(SmbFile f) {
    final isDir = f.isDirectory();
    return NetworkFile(
      name: f.name,
      path: f.path,
      isDirectory: isDir,
      size: isDir ? -1 : f.size,
      lastModified: _epochMs(f.lastModified),
      mimeType: isDir ? null : networkMimeTypeForFileName(f.name),
    );
  }

  /// smb_connect 的时间为 Windows FILETIME（100ns 自 1601-01-01），转成毫秒；
  /// 若已经是以毫秒为单位的 timestamp 或未知值（<=0）则直接回退。
  int _epochMs(int t) {
    if (t <= 0) return 0;
    if (t > 100000000000000) {
      return ((t - 116444736000000000) / 10000).floor();
    }
    return t;
  }

  String _friendly(Object e) {
    final s = e.toString();
    final lower = s.toLowerCase();
    if (lower.contains('logon') || lower.contains('password')) {
      return '用户名或密码错误';
    }
    if (lower.contains('denied') || lower.contains('access')) {
      return '拒绝访问（权限不足）';
    }
    if (lower.contains('not found') || lower.contains('no such')) {
      return '路径不存在';
    }
    if (s.trim().isEmpty) return 'SMB 请求失败';
    return s.length > 120 ? 'SMB 请求失败' : s;
  }
}