import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moumou/models/video_file.dart';
import 'package:moumou/pages/player/views/player_playlist_panel.dart';
import 'package:moumou/services/view_settings.dart';
import 'package:moumou/widgets/player_option_chip.dart';

import 'l10n_test_helper.dart';

VideoFile _v(String name, {int size = 0}) => VideoFile(
      path: '/videos/$name',
      name: name,
      size: size,
    );

/// 播放列表面板（新排序区）回归测试：
///
/// 顶部三枚胶囊 =「排序方式」（名称/日期/大小/时长）+「排序方向」（升序/降序）
/// + 右侧固定「跟随主界面」。排序只回报给播放页（[onChoiceChanged]），
/// 面板展示的列表始终来自 [playlistListenable]（播放页维护的实际播放顺序）。
void main() {
  // 主界面排序 = 大小降序 → 入口顺序 4,2,3,1（与名称降序 4,3,2,1 区分开）
  final entry = [
    _v('4.mp4', size: 40),
    _v('2.mp4', size: 30),
    _v('3.mp4', size: 20),
    _v('1.mp4', size: 10),
  ];
  const mainSort = (field: VideoSortField.size, order: SortOrder.desc);

  testWidgets('打开时跟随主界面：显示主界面排序，列表按入口顺序', (tester) async {
    final host = await _pumpPanel(tester, entry: entry, mainSort: mainSort);

    expect(_orderedNames(tester, ['1.mp4', '2.mp4', '3.mp4', '4.mp4']),
        ['4.mp4', '2.mp4', '3.mp4', '1.mp4']);
    // 两枚排序胶囊显示主界面的字段/方向
    expect(find.text('大小'), findsOneWidget);
    expect(find.text('降序'), findsOneWidget);
    // 「跟随主界面」选中
    expect(_followChip(tester).selected, isTrue);
    expect(host.choices, isEmpty);
  });

  testWidgets('点「排序方式」选名称：切到自定义并重排列表', (tester) async {
    final host = await _pumpPanel(tester, entry: entry, mainSort: mainSort);

    await tester.tap(find.byKey(const Key('playlist-sort-field')));
    await tester.pumpAndSettle();
    // 小菜单弹出（名称/日期/大小/时长），当前项打勾
    expect(find.text('名称'), findsOneWidget);
    expect(find.text('时长'), findsOneWidget);

    await tester.tap(find.text('名称'));
    await tester.pumpAndSettle();

    // 方向沿用主界面的「降序」→ 名称降序 4,3,2,1
    expect(host.choices, [(field: VideoSortField.name, order: SortOrder.desc)]);
    expect(_orderedNames(tester, ['1.mp4', '2.mp4', '3.mp4', '4.mp4']),
        ['4.mp4', '3.mp4', '2.mp4', '1.mp4']);
    expect(_followChip(tester).selected, isFalse);
    expect(find.text('名称'), findsOneWidget); // 胶囊文案已更新
  });

  testWidgets('点「排序方向」选升序：保留字段、切到自定义', (tester) async {
    final host = await _pumpPanel(tester, entry: entry, mainSort: mainSort);

    await tester.tap(find.byKey(const Key('playlist-sort-order')));
    await tester.pumpAndSettle();
    expect(find.text('升序'), findsOneWidget);

    await tester.tap(find.text('升序'));
    await tester.pumpAndSettle();

    // 字段沿用主界面的「大小」→ 大小升序 1,3,2,4
    expect(host.choices, [(field: VideoSortField.size, order: SortOrder.asc)]);
    expect(_orderedNames(tester, ['1.mp4', '2.mp4', '3.mp4', '4.mp4']),
        ['1.mp4', '3.mp4', '2.mp4', '4.mp4']);
    expect(_followChip(tester).selected, isFalse);
  });

  testWidgets('自定义后点「跟随主界面」：恢复入口顺序并重新高亮', (tester) async {
    final host = await _pumpPanel(tester, entry: entry, mainSort: mainSort);

    // 先切到自定义（名称降序）
    await tester.tap(find.byKey(const Key('playlist-sort-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('名称'));
    await tester.pumpAndSettle();
    expect(_followChip(tester).selected, isFalse);

    await tester.tap(find.byKey(const Key('playlist-sort-follow')));
    await tester.pumpAndSettle();

    expect(host.choices.last, isNull);
    expect(_orderedNames(tester, ['1.mp4', '2.mp4', '3.mp4', '4.mp4']),
        ['4.mp4', '2.mp4', '3.mp4', '1.mp4']);
    expect(_followChip(tester).selected, isTrue);
    expect(find.text('大小'), findsOneWidget);
  });

  testWidgets('网络播放只给名称/日期两个排序字段', (tester) async {
    await _pumpPanel(
      tester,
      entry: entry,
      mainSort: (field: VideoSortField.date, order: SortOrder.desc),
      sortFields: const [VideoSortField.name, VideoSortField.date],
    );

    // 跟随状态：胶囊显示网络页的「日期」
    expect(find.text('日期'), findsOneWidget);

    await tester.tap(find.byKey(const Key('playlist-sort-field')));
    await tester.pumpAndSettle();
    // 菜单只有名称/日期，没有大小/时长
    expect(find.text('名称'), findsOneWidget);
    expect(find.text('大小'), findsNothing);
    expect(find.text('时长'), findsNothing);
  });
}

/// 模拟播放页：持有播放列表与排序选择，排序变化时按同一规则重排。
Future<_HostState> _pumpPanel(
  WidgetTester tester, {
  required List<VideoFile> entry,
  required VideoSortChoice mainSort,
  List<VideoSortField> sortFields = VideoSortField.values,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: kTestLocaleZh,
      localizationsDelegates: kTestLocalizationDelegates,
      supportedLocales: kTestSupportedLocales,
      home: _Host(entry: entry, mainSort: mainSort, sortFields: sortFields),
    ),
  );
  await tester.pumpAndSettle();
  return tester.state<_HostState>(find.byType(_Host));
}

class _Host extends StatefulWidget {
  final List<VideoFile> entry;
  final VideoSortChoice mainSort;
  final List<VideoSortField> sortFields;

  const _Host({
    required this.entry,
    required this.mainSort,
    required this.sortFields,
  });

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late final ValueNotifier<List<VideoFile>> _playlist =
      ValueNotifier(widget.entry);

  VideoSortChoice? _choice;

  /// 面板回报过的排序选择（null = 跟随主界面）
  final List<VideoSortChoice?> choices = [];

  void _onChoiceChanged(VideoSortChoice? choice) {
    choices.add(choice);
    _choice = choice;
    _playlist.value = choice == null
        ? widget.entry
        : sortVideosBy(widget.entry, choice.field, choice.order);
  }

  @override
  void dispose() {
    _playlist.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PlayerPlaylistPanel(
        playlistListenable: _playlist,
        folder: '/videos',
        currentPath: '2.mp4',
        mainSort: widget.mainSort,
        sortFields: widget.sortFields,
        initialChoice: _choice,
        onChoiceChanged: _onChoiceChanged,
        onSelect: (_) {},
      ),
    );
  }
}

PlayerOptionChip _followChip(WidgetTester tester) => tester.widget<PlayerOptionChip>(
      find.byKey(const Key('playlist-sort-follow')),
    );

/// 按屏幕纵向位置排出列表项的先后（从 [names] 里返回实际顺序）
List<String> _orderedNames(WidgetTester tester, List<String> names) {
  final copy = [...names];
  copy.sort((a, b) {
    final ya = tester.getTopLeft(find.text(a)).dy;
    final yb = tester.getTopLeft(find.text(b)).dy;
    return ya.compareTo(yb);
  });
  return copy;
}
