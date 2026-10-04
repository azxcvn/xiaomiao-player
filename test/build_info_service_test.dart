import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/services/build_info_service.dart';

void main() {
  group('BuildInfo', () {
    test('默认值：无版本、未注入哈希', () {
      const info = BuildInfo();
      expect(info.versionLabel, 'v—');
      expect(info.revisionLabel, 'dev build');
      expect(info.hasRevision, isFalse);
      expect(info.isDirty, isFalse);
      expect(info.hasVersion, isFalse);
      expect(info.buildTypeLabel, 'release');
    });

    test('版本胶囊只显示版本名（不带构建号）', () {
      expect(const BuildInfo(version: '1.3.6').versionLabel, 'v1.3.6');
      // 构建号刻意不进文案（见 versionLabel 注释），但仍能取到
      expect(
        const BuildInfo(version: '1.3.6', buildNumber: '4').versionLabel,
        'v1.3.6',
      );
      expect(
        const BuildInfo(version: '1.3.6', buildNumber: '4').buildNumber,
        '4',
      );
      expect(const BuildInfo(version: ' 1.3.6 ').versionLabel, 'v1.3.6');
      expect(const BuildInfo(version: '').versionLabel, 'v—');
    });

    test('构建类型标签', () {
      expect(const BuildInfo(isRelease: true).buildTypeLabel, 'release');
      expect(const BuildInfo(isRelease: false).buildTypeLabel, 'debug');
    });

    test('哈希胶囊文案：注入 / 未注入 / dirty', () {
      expect(const BuildInfo(revision: 'b7734f1').revisionLabel, 'b7734f1');
      expect(const BuildInfo(revision: 'b7734f1-dirty').revisionLabel, 'b7734f1');
      expect(const BuildInfo(revision: 'b7734f1-dirty').isDirty, isTrue);
      expect(const BuildInfo(revision: 'b7734f1').isDirty, isFalse);
      // 未注入：显示占位而不是编一个哈希
      expect(
        const BuildInfo(revision: BuildInfo.unknownRevision).revisionLabel,
        'dev build',
      );
      expect(const BuildInfo(revision: '').revisionLabel, 'dev build');
      expect(const BuildInfo(revision: '  ').hasRevision, isFalse);
    });

    test('normalizeRevision：剥 g 前缀与 dirty 后缀', () {
      expect(BuildInfo.normalizeRevision('g1a2b3c4'), '1a2b3c4');
      expect(BuildInfo.normalizeRevision('g1a2b3c4-dirty'), '1a2b3c4');
      expect(BuildInfo.normalizeRevision('1a2b3c4'), '1a2b3c4');
      expect(BuildInfo.normalizeRevision('UNKNOWN'), '');
      // 首字符是 g 但不是「g + 十六进制」时不该被吃掉
      expect(BuildInfo.normalizeRevision('gzz1234'), 'gzz1234');
      // 单个 g 不应剥成空串
      expect(BuildInfo.normalizeRevision('g'), 'g');
    });

    test('copyHint：注入成功 / dirty / 未注入三种反馈', () {
      expect(
        const BuildInfo(revision: 'b7734f1').copyHint(),
        BuildInfoCopyHint.copied,
      );
      expect(
        const BuildInfo(revision: 'b7734f1-dirty').copyHint(),
        BuildInfoCopyHint.copiedDirty,
      );
      expect(
        const BuildInfo(revision: BuildInfo.unknownRevision).copyHint(),
        BuildInfoCopyHint.noRevision,
      );
    });
  });
}
