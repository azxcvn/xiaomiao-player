import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/services/tls_ca_bundle.dart';

/// CA 证书库兜底件的容错测试（§4.15 mbedTLS 无默认证书库）。
///
/// 这里只验证「拿不到沙盒目录时不抛异常」这一条：单测环境没有 path_provider
/// 平台实现，`getApplicationSupportDirectory()` 会失败——**播放不能被它阻断**。
/// 真机上的实际拷贝与 https 播放恢复由人工实测覆盖。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('平台目录不可用时返回 null（不抛异常，调用方不写 tls-ca-file）', () async {
    TlsCaBundle.resetForTest();
    final path = await TlsCaBundle.ensurePath();
    expect(path, isNull);
  });

  test('失败结果不缓存：resetForTest 后可重试', () async {
    TlsCaBundle.resetForTest();
    expect(await TlsCaBundle.ensurePath(), isNull);
    TlsCaBundle.resetForTest();
    expect(await TlsCaBundle.ensurePath(), isNull);
  });
}
