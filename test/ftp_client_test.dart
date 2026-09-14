import 'dart:convert';
import 'dart:io';

import 'package:charset/charset.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/models/network_connection.dart';
import 'package:moumou/services/network/ftp_client.dart';
import 'package:moumou/services/network/network_client.dart';

/// 极简 FTP 假服务器：只实现客户端真正会用的那几条命令。
///
/// 重点覆盖两件事：①`OPTS UTF8 ON` 的应答与列表字节的编码如何共同决定
/// 路径编解码；②控制连接不回话时是否有超时（黑洞主机不会永久转圈）。
class _FakeFtpServer {
  _FakeFtpServer({
    this.optsReply = '200 OK',
    List<int>? listing,
    this.silentAfterGreeting = false,
  }) : listing = listing ?? utf8.encode('type=file;size=10; a.mp4\r\n');

  final String optsReply;
  final List<int> listing;

  /// true = 只发 220 问候，之后不再回任何命令（模拟黑洞/半开连接）。
  final bool silentAfterGreeting;

  late final ServerSocket control;
  late final ServerSocket data;

  /// 控制连接上收到的**原始字节**（用于断言命令本身用的是哪套编码）。
  final List<int> rawBytes = <int>[];

  /// 按 UTF-8 解出来的命令行（ASCII 命令足够）。
  final List<String> commands = <String>[];

  final List<Socket> _sockets = <Socket>[];
  Socket? _controlSocket;
  Socket? _dataSocket;

  Future<void> start() async {
    control = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    data = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    control.listen(_handleControl);
    data.listen(_handleData);
  }

  Future<void> stop() async {
    for (final s in _sockets) {
      s.destroy();
    }
    await control.close();
    await data.close();
  }

  void _handleControl(Socket socket) {
    _sockets.add(socket);
    _controlSocket = socket;
    socket.write('220 fake ftp\r\n');
    if (silentAfterGreeting) return;
    final buffer = <int>[];
    socket.listen(
      (chunk) {
        rawBytes.addAll(chunk);
        buffer.addAll(chunk);
        while (true) {
          final nl = buffer.indexOf(0x0A);
          if (nl < 0) break;
          final line = utf8.decode(buffer.sublist(0, nl), allowMalformed: true);
          buffer.removeRange(0, nl + 1);
          if (line.trim().isEmpty) continue;
          commands.add(line.trim());
          _answer(socket, line.trim());
        }
      },
      onError: (_) {},
      cancelOnError: false,
    );
  }

  /// 数据连接：**等 MLSD/LIST 命令到了再发列表**（客户端是先连数据口再发命令的，
  /// 若在这里抢着发 226，客户端会把 226 当成 MLSD 的应答）。
  void _handleData(Socket socket) {
    _sockets.add(socket);
    _dataSocket = socket;
  }

  void _sendListing(Socket dataSocket) {
    dataSocket.add(listing);
    dataSocket.flush().then((_) {
      dataSocket.close();
      try {
        _controlSocket?.write('226 done\r\n');
      } catch (_) {
        // 控制连接可能已关闭
      }
    }).catchError((_) {});
  }

  void _answer(Socket socket, String line) {
    final command = line.split(' ').first.toUpperCase();
    switch (command) {
      case 'USER':
        socket.write('331 need password\r\n');
      case 'PASS':
        socket.write('230 logged in\r\n');
      case 'TYPE':
        socket.write('200 binary\r\n');
      case 'OPTS':
        socket.write('$optsReply\r\n');
      case 'EPSV':
        socket.write(
          '229 Entering Extended Passive Mode (|||${data.port}|)\r\n',
        );
      case 'PASV':
        socket.write('227 Entering Passive Mode (127,0,0,1,${data.port ~/ 256},${data.port % 256})\r\n');
      case 'MLSD':
      case 'LIST':
        socket.write('150 here comes the listing\r\n');
        final dataSocket = _dataSocket;
        if (dataSocket == null) {
          socket.write('226 no data\r\n');
        } else {
          _sendListing(dataSocket);
        }
      case 'SIZE':
        socket.write('213 1234\r\n');
      case 'CWD':
        socket.write('250 ok\r\n');
      case 'RETR':
        socket.write('150 opening data\r\n');
      default:
        socket.write('500 unknown\r\n');
    }
  }
}

NetworkConnection _connection(int port) => NetworkConnection(
      name: 'fake',
      protocol: NetworkProtocol.ftp,
      host: '127.0.0.1',
      port: port,
    );

void main() {
  test('OPTS UTF8 ON 应答 200 → 列表按 UTF-8 解，命令也按 UTF-8 发', () async {
    final server = _FakeFtpServer(
      optsReply: '200 OK',
      listing: utf8.encode('type=file;size=10; 年度总结.mp4\r\n'),
    );
    await server.start();
    addTearDown(server.stop);

    final client = FtpClient(_connection(server.control.port));
    await client.connect();
    final files = await client.listFiles('/');
    expect(files.single.name, '年度总结.mp4');

    await client.getFileSize('/年度总结.mp4');
    expect(
      _contains(server.rawBytes, utf8.encode('SIZE /年度总结.mp4\r\n')),
      isTrue,
      reason: '确认支持 UTF-8 时应按 UTF-8 发命令',
    );
    await client.disconnect();
  });

  test('OPTS 不支持 + GBK 列表 → 判定 GBK，列表与命令统一用 GBK', () async {
    final server = _FakeFtpServer(
      optsReply: '500 Unknown command',
      listing: gbk.encode('type=file;size=10; 中文.mp4\r\n'),
    );
    await server.start();
    addTearDown(server.stop);

    final client = FtpClient(_connection(server.control.port));
    await client.connect();
    final files = await client.listFiles('/');
    expect(files.single.name, '中文.mp4');

    await client.getFileSize('/中文.mp4');
    expect(
      _contains(server.rawBytes, gbk.encode('SIZE /中文.mp4\r\n')),
      isTrue,
      reason: '只是列表按 GBK 解、命令仍按 UTF-8 发的话，中文路径会 550',
    );
    await client.disconnect();
  });

  test('OPTS 不支持但服务器实际是 UTF-8 → 仍按 UTF-8（不回归）', () async {
    final server = _FakeFtpServer(
      optsReply: '500 Unknown command',
      listing: utf8.encode('type=file;size=10; 中文.mp4\r\n'),
    );
    await server.start();
    addTearDown(server.stop);

    final client = FtpClient(_connection(server.control.port));
    await client.connect();
    final files = await client.listFiles('/');
    expect(files.single.name, '中文.mp4');
    await client.disconnect();
  });

  test('控制连接不回话 → 12 秒内报超时（不永久转圈）', () async {
    final server = _FakeFtpServer(silentAfterGreeting: true);
    await server.start();
    addTearDown(server.stop);

    final client = FtpClient(_connection(server.control.port));
    final started = DateTime.now();
    await expectLater(
      client.connect(),
      throwsA(
        isA<NetworkClientException>().having(
          (e) => e.message,
          'message',
          contains('超时'),
        ),
      ),
    );
    expect(
      DateTime.now().difference(started).inSeconds,
      lessThan(14),
      reason: '一次尝试就报错（不重试成三次）',
    );
  });
}

bool _contains(List<int> haystack, List<int> needle) {
  for (var i = 0; i + needle.length <= haystack.length; i++) {
    var hit = true;
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) {
        hit = false;
        break;
      }
    }
    if (hit) return true;
  }
  return false;
}
