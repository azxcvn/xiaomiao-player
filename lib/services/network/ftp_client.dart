/// FTP 客户端（纯 Dart，基于 `dart:io` Socket，学习 mpvRx `FtpClient` 采用
/// Apache Commons Net 的分层思路，但自行实现控制/数据双连接与被动模式）。
///
/// 要点：
/// - 浏览（列表/大小）走一条共享控制连接；流式传输（[openStream]）为专用
///   控制连接，避免与浏览共享状态；
/// - 目录列表优先 RFC 3659 `MLSD`，服务器不支持时回退 Unix `LIST`；
/// - 偏移读取用 `REST`，不接受时直接报错而非返回损坏的偏移流；
/// - **所有等待都有超时**（分级超时来自 `utils/retry_policy.dart`）：黑洞主机下
///   「测试连接/浏览」不会永久转圈；浏览类操作对连接类失败自动重试；
/// - **中文文件名**：登录时探测 `OPTS UTF8 ON` 的应答。应答 200 就一律 UTF-8；
///   否则严格 UTF-8 试解目录列表，解不通才判定为 GBK（老 IIS / Serv-U），此后
///   该连接的**列表与命令**统一用这一套编码——只列表按 GBK 解、命令仍按 UTF-8
///   发的话，中文路径永远 `550`。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:charset/charset.dart';
import 'package:flutter/foundation.dart';
import 'package:moumou/models/network_connection.dart';
import 'package:moumou/models/network_file.dart';
import 'package:moumou/services/network/network_client.dart';
import 'package:moumou/utils/ftp_parser.dart';
import 'package:moumou/utils/network_mime_types.dart';
import 'package:moumou/utils/network_path.dart';
import 'package:moumou/utils/retry_policy.dart';

/// GBK 解码用宽松模式：个别坏字节只产生替换字符，不让整份列表解析失败。
const GbkCodec _gbk = GbkCodec(allowMalformed: true);

class FtpClient implements NetworkClient {
  final NetworkConnection connection;

  FtpClient(this.connection);

  /// 浏览类操作的默认重试策略（只重试连接类失败，见 [isRetryableNetworkError]）。
  static const _retryPolicy = RetryPolicy();

  /// 黑洞地址 / 服务器半开时的统一提示（12 秒 = 分级超时的常规 API 档）。
  static const _timeoutMessage = '连接超时：服务器无响应，请检查地址与端口';

  _FtpControl? _control;

  /// 已确定的路径编解码：`null` = 尚未确定（按 UTF-8 处理）。
  ///
  /// 由 `OPTS UTF8 ON` 的应答或目录列表的试解结果确定，并被后续新建的控制
  /// 连接继承——`openStream` 是**另一条**控制连接，而它要访问的中文路径正是
  /// 列表解出来的那个字符串，编码必须一致。
  Encoding? _encoding;

  @override
  bool isConnected() => _control?.isAlive ?? false;

  @override
  Future<void> connect() async {
    await disconnect();
    // 「测试连接」是单次尝试：黑洞地址下重试只会把一次 12 秒超时拖成三次（§4.28）。
    try {
      _control = await _openControl();
    } on TimeoutException {
      throw const NetworkClientException(_timeoutMessage);
    } on SocketException catch (error) {
      // `Socket.connect(timeout:)` 超时抛的是 SocketException("Connection timed out")
      if (error.message.toLowerCase().contains('timed out')) {
        throw const NetworkClientException(_timeoutMessage);
      }
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    final ctrl = _control;
    _control = null;
    ctrl?.close();
  }

  @override
  Future<List<NetworkFile>> listFiles(String path) async {
    final dir = NetworkPath.from(path);
    return _withControlRetry((ctrl) async {
      final mlsd = await _tryMlsd(ctrl, dir);
      final List<FtpListEntry> entries;
      if (mlsd != null) {
        entries = mlsd.map(parseMlsdLine).whereType<FtpListEntry>().toList();
      } else {
        final unix = await _tryListUnix(ctrl, dir);
        entries = unix.map(parseUnixListLine).whereType<FtpListEntry>().toList();
      }

      final files = <NetworkFile>[];
      for (final e in entries) {
        final childPath = _childOrNull(dir, e.name);
        if (childPath == null) continue;
        files.add(
          NetworkFile(
            name: e.name,
            path: childPath,
            isDirectory: e.isDirectory,
            size: e.isDirectory ? -1 : e.size,
            lastModified: e.lastModifiedMs,
            mimeType: e.isDirectory ? null : networkMimeTypeForFileName(e.name),
          ),
        );
      }
      return files;
    });
  }

  @override
  Future<int> getFileSize(String path) async {
    final p = _remotePath(NetworkPath.from(path));
    return _withControlRetry((ctrl) async {
      await ctrl.sendCommand('SIZE $p');
      if (ctrl.replyCode == 213) {
        final size = int.tryParse(ctrl.replyText.substring(4).trim());
        if (size != null && size >= 0) return size;
      }
      await ctrl.sendCommand('MLST $p');
      if (ctrl.replyCode == 250) {
        final m = RegExp(r'size=(\d+)', caseSensitive: false)
            .firstMatch(ctrl.replyText);
        final size = m == null ? null : int.tryParse(m.group(1)!);
        if (size != null && size >= 0) return size;
      }
      return -1;
    });
  }

  @override
  Future<Stream<List<int>>> openStream(String path, {int offset = 0}) async {
    // 流式路径**不重试**（§4.28）：重发 RETR 会重复拉流；只加超时。
    final socket = await Socket.connect(
      connection.host,
      connection.port,
      timeout: NetworkTimeoutTier.api.timeout,
    );
    final ctrl = _FtpControl(socket, connection.host);
    try {
      await ctrl.readReply();
      _expect(ctrl.replyCode == 220, 'FTP 服务器拒绝连接（代码 ${ctrl.replyCode}）');
      await _login(ctrl);

      if (offset > 0) {
        await ctrl.sendCommand('REST $offset');
        _expect(ctrl.replyCode == 350, 'FTP 服务器不支持断点续传（REST）');
      }

      final data = await ctrl.openPassiveData();
      await ctrl.sendCommand('RETR ${_remotePath(NetworkPath.from(path))}');
      _expect(
        ctrl.replyCode == 150 || ctrl.replyCode == 125,
        'FTP 服务器拒绝文件传输（代码 ${ctrl.replyCode}）',
      );
      return _managedStream(data, ctrl);
    } catch (_) {
      ctrl.close();
      rethrow;
    }
  }

  /// 建连 + 登录 + 切到连接根目录，返回一条可用的控制连接。
  Future<_FtpControl> _openControl() async {
    final socket = await Socket.connect(
      connection.host,
      connection.port,
      timeout: NetworkTimeoutTier.api.timeout,
    );
    final ctrl = _FtpControl(socket, connection.host);
    try {
      await ctrl.readReply();
      _expect(ctrl.replyCode == 220, 'FTP 服务器拒绝连接（代码 ${ctrl.replyCode}）');
      await _login(ctrl);
      final root = _remotePath(NetworkPath.root);
      if (root != '/') {
        await ctrl.sendCommand('CWD $root');
        _expect(ctrl.replyCode == 250, 'FTP 根目录不可用（代码 ${ctrl.replyCode}）');
      }
      return ctrl;
    } catch (_) {
      ctrl.close();
      rethrow;
    }
  }

  /// 浏览类操作的统一入口：每次尝试保证一条**可用**的控制连接。
  ///
  /// 控制连接一旦超时/断开就作废（`_FtpControl.isOpen` 只在 `close()` 里置位，
  /// 光看它分辨不出死连接），下一次尝试重新建连登录——否则「重试」只是在死连接
  /// 上再等一次超时。
  Future<T> _withControlRetry<T>(Future<T> Function(_FtpControl ctrl) run) {
    return withRetry(
      () async {
        final existing = _control;
        final ctrl = (existing != null && existing.isAlive)
            ? existing
            : await _openControl();
        try {
          return await run(ctrl);
        } catch (error) {
          if (isRetryableNetworkError(error) || !ctrl.isAlive) {
            _discardControl(ctrl);
          }
          rethrow;
        }
      },
      policy: _retryPolicy,
      onRetry: (error, nextAttempt) =>
          debugPrint('[FTP] 第 $nextAttempt 次尝试（$error）'),
    );
  }

  void _discardControl(_FtpControl ctrl) {
    ctrl.close();
    if (identical(_control, ctrl)) _control = null;
  }

  /// 登录并按 `OPTS UTF8 ON` 的应答确定编码。
  Future<void> _login(_FtpControl ctrl) async {
    final user = connection.isAnonymous ? 'anonymous' : connection.username;
    await ctrl.sendCommand('USER $user');
    if (ctrl.replyCode == 331) {
      final pass = connection.isAnonymous ? 'anonymous@' : connection.password;
      await ctrl.sendCommand('PASS $pass');
    }
    _expect(ctrl.replyCode == 230 || ctrl.replyCode == 202, 'FTP 登录失败，请检查账号密码');
    await ctrl.sendCommand('TYPE I');
    _expect(ctrl.replyCode == 200, 'FTP 服务器拒绝二进制模式');
    // `OPTS UTF8 ON`：RFC 2640 规定成功回 200。失败（500/501/502/504）说明
    // 服务器不认这个命令——**不等于**它用 GBK，所以这里不写死结论，
    // 交给列表试解（见 _decodeListing）。
    await ctrl.sendCommand('OPTS UTF8 ON');
    if (ctrl.replyCode == 200) _encoding = utf8;
    ctrl.encoding = _encoding ?? utf8;
  }

  Future<List<String>?> _tryMlsd(_FtpControl ctrl, NetworkPath dir) async {
    final data = await ctrl.openPassiveData();
    try {
      await ctrl.sendCommand('MLSD ${_remotePath(dir)}');
      if (ctrl.replyCode != 150 && ctrl.replyCode != 125) {
        return null; // 服务器不支持 MLSD
      }
      final text = _decodeListing(ctrl, await _readAllBytes(data));
      await ctrl.readReply(); // 226
      return text.split('\n');
    } finally {
      data.destroy();
    }
  }

  Future<List<String>> _tryListUnix(_FtpControl ctrl, NetworkPath dir) async {
    final data = await ctrl.openPassiveData();
    try {
      await ctrl.sendCommand('LIST ${_remotePath(dir)}');
      _expect(
        ctrl.replyCode == 150 || ctrl.replyCode == 125,
        'FTP 目录列表失败（代码 ${ctrl.replyCode}）',
      );
      final text = _decodeListing(ctrl, await _readAllBytes(data));
      await ctrl.readReply(); // 226
      return text.split('\n');
    } finally {
      data.destroy();
    }
  }

  /// 目录列表的字节 → 字符串，决定该连接的路径编码（两条列表路径共用）。
  ///
  /// 顺序：① `OPTS UTF8 ON` 已确认 → 直接 UTF-8；② 未确认 → 先按**严格** UTF-8
  /// 试解（能解通就说明本来就是 UTF-8，不改动既有行为）；③ UTF-8 解不通 →
  /// 判定 GBK 并记住，后续列表与命令都用 GBK。
  String _decodeListing(_FtpControl ctrl, List<int> bytes) {
    final known = _encoding;
    if (known != null) {
      return _decodeBytes(known, bytes);
    }
    try {
      final text = const Utf8Decoder().convert(bytes);
      return text;
    } on FormatException {
      _encoding = _gbk;
      ctrl.encoding = _gbk;
      debugPrint('[FTP] 目录列表非 UTF-8，按 GBK 处理');
      return _decodeBytes(_gbk, bytes);
    }
  }

  String _decodeBytes(Encoding encoding, List<int> bytes) {
    if (encoding == utf8) return utf8.decode(bytes, allowMalformed: true);
    return encoding.decode(bytes);
  }

  /// 读走数据连接的全部字节。
  ///
  /// 用**空闲超时**（`Stream.timeout`，非总时长）：目录列表在黑洞主机上不会
  /// 永久挂起。⚠️ 媒体流（[openStream]）**不能**套这个超时——mpv 暂停时数据
  /// 连接本来就长时间无数据。
  Future<List<int>> _readAllBytes(Socket socket) async {
    final bytes = <int>[];
    await for (final chunk in socket.timeout(NetworkTimeoutTier.text.timeout)) {
      bytes.addAll(chunk);
    }
    return bytes;
  }

  String _remotePath(NetworkPath p) {
    final segments = [...NetworkPath.from(connection.path).segments, ...p.segments];
    return segments.isEmpty ? '/' : '/${segments.join('/')}';
  }

  static void _expect(bool condition, String message) {
    if (!condition) throw NetworkClientException(message);
  }

  static String? _childOrNull(NetworkPath dir, String name) {
    try {
      return dir.child(name).value;
    } catch (_) {
      return null;
    }
  }

  Stream<List<int>> _managedStream(Socket data, _FtpControl ctrl) {
    final controller = StreamController<List<int>>();
    StreamSubscription<List<int>>? sub;
    var cleaned = false;

    void cleanup() {
      if (cleaned) return;
      cleaned = true;
      ctrl.close();
    }

    controller.onListen = () {
      sub = data.listen(
        (chunk) {
          if (!controller.isClosed) controller.add(chunk);
        },
        onError: (Object e, StackTrace st) {
          if (!controller.isClosed) controller.addError(e, st);
          cleanup();
        },
        onDone: () {
          if (!controller.isClosed) controller.close();
          cleanup();
        },
      );
    };
    controller.onCancel = () {
      sub?.cancel();
      data.destroy();
      cleanup();
    };
    return controller.stream;
  }
}

/// 单条 FTP 控制连接：按行读取应答（兼容多行 `code-... code ...` 格式），
/// 并提供被动模式数据连接建立能力。
class _FtpControl {
  final Socket _socket;
  final String host;

  /// 已到达但还没被 [_readLine] 取走的原始分片。
  final List<List<int>> _chunks = <List<int>>[];

  /// 尚未切分成行的字节（GBK 是多字节编码，必须**整行**解码，
  /// 不能拿 `utf8.decoder` 那种按 chunk 流式解码去凑）。
  final List<int> _pending = <int>[];

  late final StreamSubscription<List<int>> _sub;

  /// 等待「下一片数据 / 连接结束」的信号。
  Completer<void>? _chunkArrived;

  /// 控制连接的编解码：登录时确定（ASCII 命令与中文路径共用同一套）。
  Encoding encoding = utf8;

  int replyCode = 0;
  String replyText = '';
  bool _closed = false;

  /// 远端已断开 / socket 出错。
  bool _dead = false;

  /// 等待一条应答的超时（分级超时里的常规 API 档）。
  static final replyTimeout = NetworkTimeoutTier.api.timeout;

  _FtpControl(this._socket, this.host) {
    // **自己持有 socket 订阅**（不用 `StreamIterator`）：只有这样才能在远端
    // 断开（FIN）/ 出错时**立刻**知道 → `isConnected()` 不再恒真、代理也不会
    // 一直复用死连接（P2-20）。实测 `socket.done` 只在**我们自己**关闭时完成，
    // 远端 FIN 不会触发它，所以不能用它当断线信号。
    _sub = _socket.listen(
      (chunk) {
        _chunks.add(chunk);
        _wake();
      },
      onError: (Object _) => _markDead(),
      onDone: _markDead,
      cancelOnError: false,
    );
  }

  void _wake() {
    final waiter = _chunkArrived;
    _chunkArrived = null;
    if (waiter != null && !waiter.isCompleted) waiter.complete();
  }

  void _markDead() {
    _dead = true;
    _wake();
  }

  bool get isOpen => !_closed;

  /// 连接是否**真的**还活着（我们没关 + 远端也没断）。
  bool get isAlive => !_closed && !_dead;

  void close() {
    if (_closed) return;
    _closed = true;
    unawaited(_sub.cancel());
    try {
      _socket.destroy();
    } catch (_) {
      // 忽略关闭异常。
    }
  }

  Future<void> readReply() async {
    final buffer = StringBuffer();
    final first = await _readLine();
    if (first == null) {
      throw const NetworkClientException('FTP 连接被服务器关闭');
    }
    buffer.write(first);

    final code = int.tryParse(first.length >= 3 ? first.substring(0, 3) : '');
    if (code == null) {
      throw const NetworkClientException('FTP 服务器返回异常响应');
    }
    final multiline = first.length >= 4 && first[3] == '-';
    if (multiline) {
      final terminator = '$code ';
      while (true) {
        final line = await _readLine();
        if (line == null) {
          throw const NetworkClientException('FTP 连接中断');
        }
        buffer.write('\n$line');
        if (line.startsWith(terminator)) break;
      }
    }
    replyCode = code;
    replyText = buffer.toString();
  }

  /// 读一行（到 `\n` 为止）并按 [encoding] 解码；连接关闭返回 null。
  ///
  /// **每条应答都有超时**：服务器半开（accept 后不回话）时不能永久挂起。
  Future<String?> _readLine() async {
    while (true) {
      final newline = _pending.indexOf(0x0A);
      if (newline >= 0) {
        final line = _decodeLine(_pending.sublist(0, newline));
        _pending.removeRange(0, newline + 1);
        return line;
      }
      if (_chunks.isEmpty) {
        // 已经没有待处理数据：远端已断开就到此为止（不再等超时）
        if (_dead) return null;
        final waiter = Completer<void>();
        _chunkArrived = waiter;
        await waiter.future.timeout(replyTimeout);
        continue;
      }
      _pending.addAll(_chunks.removeAt(0));
    }
  }

  String _decodeLine(List<int> bytes) {
    var end = bytes.length;
    if (end > 0 && bytes[end - 1] == 0x0D) end--;
    final body = bytes.sublist(0, end);
    if (encoding == utf8) return utf8.decode(body, allowMalformed: true);
    return encoding.decode(body);
  }

  Future<void> sendCommand(String command) async {
    // 命令也按协商出的编码发：GBK 服务器上 UTF-8 的中文路径会 550。
    _socket.add(encoding.encode('$command\r\n'));
    await _socket.flush().timeout(replyTimeout);
    await readReply();
  }

  /// 建立被动模式数据连接：优先 EPSV（IPv6 友好），回退 PASV。
  Future<Socket> openPassiveData() async {
    await sendCommand('EPSV');
    if (replyCode == 229) {
      final m = RegExp(r'\(\|\|\|(\d+)\|\)').firstMatch(replyText);
      if (m != null) {
        final port = int.parse(m.group(1)!);
        return Socket.connect(host, port,
            timeout: NetworkTimeoutTier.api.timeout);
      }
    }
    await sendCommand('PASV');
    if (replyCode != 227) {
      throw const NetworkClientException('FTP 服务器不支持被动模式');
    }
    final m = RegExp(r'\((\d+),(\d+),(\d+),(\d+),(\d+),(\d+)\)')
        .firstMatch(replyText);
    if (m == null) {
      throw const NetworkClientException('FTP 被动模式响应无法解析');
    }
    var ip =
        '${m.group(1)!}.${m.group(2)!}.${m.group(3)!}.${m.group(4)!}';
    if (ip == '0.0.0.0') ip = host;
    final port = int.parse(m.group(5)!) * 256 + int.parse(m.group(6)!);
    return Socket.connect(ip, port,
        timeout: NetworkTimeoutTier.api.timeout);
  }
}
