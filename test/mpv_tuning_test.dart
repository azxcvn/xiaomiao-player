import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/utils/mpv_tuning.dart';

/// mpv 移动端缓存/网络调参纯函数测试（§4.26）：
/// - 顶层逗号切分（`protocol_whitelist=[...]` 内的逗号不算分隔符）；
/// - `demuxer-lavf-o` 合并：保留 media_kit 的 protocol_whitelist、覆盖同名键、
///   旧值缺失/为空时返回 null（宁可不设也不覆盖）；
/// - 调参表：本地/在线两档的差异 + 关键项取值。
void main() {
  // media_kit 实际写入的 demuxer-lavf-o 形态（值内含逗号）
  const mediaKitLavfO = 'seg_max_retry=5,strict=experimental,'
      'allowed_extensions=ALL,'
      'protocol_whitelist=[udp,rtp,tcp,tls,data,file,http,https,crypto]';

  group('splitLavfOptions', () {
    test('方括号内的逗号不切分', () {
      final parts = splitLavfOptions(
        'a=1,protocol_whitelist=[udp,rtp,tcp],b=2',
      );
      expect(parts, [
        'a=1',
        'protocol_whitelist=[udp,rtp,tcp]',
        'b=2',
      ]);
    });

    test('无括号时按逗号切分并去空白', () {
      expect(splitLavfOptions(' a=1 , b=2 '), ['a=1', 'b=2']);
      expect(splitLavfOptions('a=1,,b=2'), ['a=1', 'b=2']);
      expect(splitLavfOptions(''), isEmpty);
    });

    test('嵌套括号也不切分', () {
      expect(splitLavfOptions('x=[a,[b,c],d],y=2'),
          ['x=[a,[b,c],d]', 'y=2']);
    });
  });

  group('mergeDemuxerLavfOptions', () {
    test('保留 protocol_whitelist 并追加重连参数', () {
      final merged =
          mergeDemuxerLavfOptions(mediaKitLavfO, kOnlineLavfOverrides)!;
      final parts = splitLavfOptions(merged);
      expect(parts, contains('protocol_whitelist=[udp,rtp,tcp,tls,data,file,http,https,crypto]'));
      expect(parts, contains('seg_max_retry=5'));
      expect(parts, contains('reconnect=1'));
      expect(parts, contains('reconnect_on_network_error=1'));
      expect(parts, contains('reconnect_streamed=1'));
      expect(parts, contains('reconnect_delay_max=5'));
      expect(parts, contains('reconnect_max_retries=5'));
      expect(parts, contains('reconnect_delay_total_max=20'));
      expect(parts, contains('http_persistent=0'));
    });

    test('明确不含 reconnect_at_eof（合法 VOD EOF 必须正常结束）', () {
      final merged =
          mergeDemuxerLavfOptions(mediaKitLavfO, kOnlineLavfOverrides)!;
      expect(merged, isNot(contains('reconnect_at_eof')));
    });

    test('同名键被覆盖且保持原位置', () {
      final merged = mergeDemuxerLavfOptions(
        'reconnect=0,strict=experimental',
        {'reconnect': '1'},
      )!;
      expect(merged, 'reconnect=1,strict=experimental');
    });

    test('旧值缺失/为空返回 null（防覆盖 protocol_whitelist）', () {
      expect(mergeDemuxerLavfOptions(null, kOnlineLavfOverrides), isNull);
      expect(mergeDemuxerLavfOptions('', kOnlineLavfOverrides), isNull);
      expect(mergeDemuxerLavfOptions('   ', kOnlineLavfOverrides), isNull);
    });

    test('无值标志位往返不丢', () {
      final merged = mergeDemuxerLavfOptions('flag,a=1', {'b': '2'})!;
      expect(merged, 'flag,a=1,b=2');
    });
  });

  group('buildMpvTuning', () {
    test('本地档：只写来源无关项 + 本地缓存上限', () {
      final t = buildMpvTuning(isOnline: false, existingDemuxerLavfO: null);
      expect(t['video-sync'], 'audio');
      expect(t['framedrop'], 'vo');
      expect(t['demuxer-max-bytes'], '$kLocalDemuxerMaxBytes');
      expect(t['demuxer-max-back-bytes'], '$kLocalDemuxerBackBytes');
      // 本地不需要网络相关调参
      expect(t.containsKey('network-timeout'), isFalse);
      expect(t.containsKey('cache-pause'), isFalse);
      expect(t.containsKey('demuxer-lavf-o'), isFalse);
      expect(t.containsKey('hls-bitrate'), isFalse);
    });

    test('在线档：缓存/超时/重连/HLS 齐备且缓存更大', () {
      final t = buildMpvTuning(
        isOnline: true,
        existingDemuxerLavfO: mediaKitLavfO,
      );
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
      expect(t['demuxer-lavf-o'], contains('protocol_whitelist='));
      expect(t['demuxer-lavf-o'], contains('reconnect=1'));
    });

    test('在线档读不到旧 demuxer-lavf-o 时跳过该键但保留其余调参', () {
      final t = buildMpvTuning(isOnline: true, existingDemuxerLavfO: null);
      expect(t.containsKey('demuxer-lavf-o'), isFalse);
      expect(t['cache'], 'yes');
      expect(t['network-timeout'], '15');
    });
  });
}
