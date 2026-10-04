# 阶段 4 子任务说明（播放器群 l10n 替换）

仓库根：`C:\Users\root\Desktop\moumou`

## 任务
按 `_stage4_groupX.md` 里的清单（`文件 | 行号 | 中文文案 → 建议调用`），把硬编码中文替换成
`AppLocalizations` 调用。**只改清单里属于你的文件**，其它文件一概不碰。

## 硬性规则
1. **禁止修改** `lib/l10n/app_zh.arb`、`lib/l10n/app_en.arb`、`lib/l10n/label_maps.dart`、
   `lib/l10n/app_localizations*.dart`（键都已生成好，改了会与协调者冲突）。
2. **禁止运行** `flutter gen-l10n`、`flutter test`、`flutter analyze`、`dart analyze`
   （协调者会在全部改完后统一跑；并发跑会互相干扰）。
3. 禁止 `dart format`；禁止整篇重排；禁止改行尾风格（本目录部分文件是 CRLF，部分是 LF，保持原样）。
4. 中文显示文本**一个字都不许改**（ARB 里就是原文）；你不用写英文。
5. 不顺手重构、不改业务逻辑、不动无关代码。
6. 日志（`debugPrint` / `AppLog` / `log(...)` 之类）不改。

## 取 l10n
```dart
import 'package:moumou/l10n/app_localizations.dart';
// ...
final l10n = AppLocalizations.of(context); // 非空，不用 !
Text(l10n.commonBack)
```
- 在 `build`（或其它有 context 的位置）里就地取。
- 拿不到 context 的**静态方法 / 顶层纯函数**：把 `AppLocalizations l10n` 加成参数，调用处传进去；
  不要为了拿 context 把类改成 StatefulWidget。
- 需要「枚举 → 文案」时用 `lib/l10n/label_maps.dart` 里已有的函数（如 `playerTopActionLabel(l10n, a)`），
  不要自己写 switch；只有本文件内部定义的枚举（`audio_player_panels.dart` 的两个）才在本文件里写映射函数。

## 占位符
- 建议里的 `l10n.xxx(expr)`：`expr` 就是原来 `$x` / `${...}` 里的表达式，照抄。
- 建议里出现 `<name>` 形式的：按上下文自己填（分组说明里会写清楚）。

## const 处理
`const Text('删除')` → `Text(l10n.commonDelete)`；`const _SectionLabel('更多')` → `_SectionLabel(l10n.commonMore)`。
**任何 const 子树里出现 `l10n.` 都必须去掉对应的 const**（必要时连父级 const 一起去掉）。
去掉 const 是唯一允许的副作用，不要顺手把别的 const 也去掉。

## 自检（必做）
每个文件改完后，在仓库根运行（PowerShell）：

```
& "C:\Users\root\.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\python\python.exe" `
  "docs\archive\i18n-migration-plan\tools\i18n_scan.py" residual --path "lib/pages/player/views/你的文件.dart"
```

看到打印的 `residual: N` → 要求 **N = 0**（日志里的中文由脚本排除，不计入）。不是 0 就继续改到 0。

> `05-residual-chinese-report.md` 是共享文件，可能被别人覆盖，**只看命令行打印的数字**。

## 回报格式
```
文件 → residual 0
文件 → residual 0
疑问/拿不准的地方
```
不要贴 diff，不要复述规则。
