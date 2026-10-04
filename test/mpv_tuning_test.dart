import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/utils/mpv_tuning.dart';

/// mpv 移动端缓存/网络调参纯函数测试（§4.26）：
/// - `demuxer-lavf-o` **整串重建**：必须带上带方括号的完整协议白名单
///   （回归：早期「读回来再合并」会把白名单切碎成只剩 `udp`，导致 http/https 全被
///   ffmpeg 拒绝 → 在线播放全灭）；
/// - 调参表：本地/在线两档的差异 + 关键项取值；
/// - CA 证书库：给了才写 `tls-ca-file`。
void main() {
  group('buildDemuxerLavfO', () {
    test('白名单带方括号且协议齐全（含 http/https/rtmp/rtsp/ftp）', () {
      final s = buildDemuxerLavfO(isOnline: true);
      expect(s, contains('protocol_whitelist=['));
      expect(s, contains('https'));
      expect(s, contains('http,'));
      for (final proto in ['udp', 'rtp', 'tcp', 'tls', 'crypto', 'rtmp', 'rtsp', 'ftp']) {
        expect(s, contains(proto));
      }
      // media_kit 的三项默认值不能被丢掉
      expect(s, contains('seg_max_retry=5'));
      expect(s, contains('strict=experimental'));
      expect(s, contains('allowed_extensions=ALL'));
    });

    test('回归：白名单必须是完整的带方括号段（不能被切碎成只剩 udp）', () {
      final s = buildDemuxerLavfO(isOnline: true);
      // 被切碎的形态长这样：protocol_whitelist=udp,rtp=,tcp=…（方括号丢了）
      expect(s.contains('protocol_whitelist=udp'), isFalse);
      final m = RegExp(r'protocol_whitelist=\[([^\]]*)\]').firstMatch(s);
      expect(m, isNotNull, reason: '白名单段必须带方括号：$s');
      final protos = m!.group(1)!.split(',');
      expect(
        protos,
        containsAll([
          'udp', 'rtp', 'tcp', 'tls', 'data', 'file', 'http', 'https', 'crypto',
          'rtmp', 'rtsp', 'ftp',
        ]),
      );
      // 整串里只应出现一次 protocol_whitelist=
      expect('protocol_whitelist='.allMatches(s).length, 1);
    });

    test('在线档带重连参数，且不含 reconnect_at_eof', () {
      final s = buildDemuxerLavfO(isOnline: true);
      expect(s, contains('reconnect=1'));
      expect(s, contains('reconnect_on_network_error=1'));
      expect(s, contains('reconnect_streamed=1'));
      expect(s, contains('reconnect_delay_max=5'));
      expect(s, contains('reconnect_max_retries=5'));
      expect(s, contains('reconnect_delay_total_max=20'));
      expect(s, contains('http_persistent=0'));
      expect(s, isNot(contains('reconnect_at_eof')));
    });

    test('非在线档不带重连参数（但仍带白名单）', () {
      final s = buildDemuxerLavfO(isOnline: false);
      expect(s, contains('protocol_whitelist=['));
      expect(s, isNot(contains('reconnect=')));
    });

    test('白名单常量与 media_kit 默认值兼容（前 9 项一致）', () {
      expect(
        kPlaybackProtocolWhitelist.take(9),
        ['udp', 'rtp', 'tcp', 'tls', 'data', 'file', 'http', 'https', 'crypto'],
      );
    });
  });

  group('buildMpvTuning', () {
    test('本地档：只写来源无关项 + 本地缓存上限，不写网络项', () {
      final t = buildMpvTuning(isOnline: false);
      expect(t['video-sync'], 'audio');
      expect(t['framedrop'], 'vo');
      expect(t['demuxer-max-bytes'], '$kLocalDemuxerMaxBytes');
      expect(t['demuxer-max-back-bytes'], '$kLocalDemuxerBackBytes');
      expect(t.containsKey('network-timeout'), isFalse);
      expect(t.containsKey('cache-pause'), isFalse);
      expect(t.containsKey('demuxer-lavf-o'), isFalse);
      expect(t.containsKey('hls-bitrate'), isFalse);
    });

    test('在线档：缓存/超时/HLS/白名单齐备且缓存更大', () {
      final t = buildMpvTuning(isOnline: true);
      expect(t['video-sync'], 'audio');
      expect(t['framedrop'], 'vo');
      expect(t['cache'], 'yes');
      expect(t['cache-pause'], 'yes');
      expect(t['cache-pause-wait'], '2');
      expect(t['network-timeout'], '15');
      expect(t['http-allow-redirect'], 'yes');
      expect(t['hls-bitrate'], 'no');
      expect(t['demuxer-max-bytes'], '$kOnlineDemuxerMaxBytes');
      expect(t['demuxer-max-back-bytes'], '$kOnlineDemuxerBackBytes');
      expect(kOnlineDemuxerMaxBytes, greaterThan(kLocalDemuxerMaxBytes));
      final lavf = t['demuxer-lavf-o']!;
      expect(lavf, contains('protocol_whitelist=['));
      expect(lavf, contains('https'));
      expect(lavf, contains('reconnect=1'));
    });

    test('CA 证书库：给了就写 tls-ca-file（本地档同样写，设了无害）', () {
      final on = buildMpvTuning(
        isOnline: true,
        tlsCaFile: '/data/user/0/pkg/files/cacert.pem',
      );
      expect(on['tls-ca-file'], '/data/user/0/pkg/files/cacert.pem');
      final off = buildMpvTuning(
        isOnline: false,
        tlsCaFile: '/x/cacert.pem',
      );
      expect(off['tls-ca-file'], '/x/cacert.pem');
    });

    test('CA 证书库：没给或为空时不写该键（不覆盖 mpv 现有行为）', () {
      expect(
        buildMpvTuning(isOnline: true).containsKey('tls-ca-file'),
        isFalse,
      );
      expect(
        buildMpvTuning(isOnline: true, tlsCaFile: '').containsKey('tls-ca-file'),
        isFalse,
      );
    });
  });
}
