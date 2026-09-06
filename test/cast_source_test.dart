import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/utils/cast_source.dart';

void main() {
  test('classifyCastSource：本地/直链/loopback/content 分类', () {
    expect(
      classifyCastSource('/storage/emulated/0/Movies/a.mp4'),
      CastSource.localFile,
    );
    expect(
      classifyCastSource('file:///storage/emulated/0/a.mp4'),
      CastSource.localFile,
    );
    expect(
      classifyCastSource('https://example.com/a.mp4'),
      CastSource.remoteUrl,
    );
    expect(
      classifyCastSource('http://127.0.0.1:1234/token'),
      CastSource.loopback,
    );
    expect(
      classifyCastSource('http://localhost:1234/token'),
      CastSource.loopback,
    );
    expect(
      classifyCastSource('content://media/external/video/1'),
      CastSource.unsupported,
    );
  });

  test('isLoopbackUrl：识别 loopback 主机', () {
    expect(isLoopbackUrl('http://127.0.0.1:1/x'), isTrue);
    expect(isLoopbackUrl('http://LOCALHOST/x'), isTrue);
    expect(isLoopbackUrl('http://0.0.0.0/x'), isTrue);
    expect(isLoopbackUrl('http://192.168.1.5/x'), isFalse);
    expect(isLoopbackUrl('not a url'), isFalse);
  });

  test('localFilePath：本地路径原样返回、file:// 去前缀、非本地返回 null', () {
    expect(localFilePath('/storage/a.mp4'), '/storage/a.mp4');
    expect(localFilePath('file:///storage/a.mp4'), '/storage/a.mp4');
    expect(localFilePath('http://127.0.0.1:1/x'), isNull);
    expect(localFilePath('content://x'), isNull);
  });
}
