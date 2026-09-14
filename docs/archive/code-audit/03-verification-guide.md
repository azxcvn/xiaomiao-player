# 开工前必验：4 条「会改变批次内容」的待验证项

> 背景：体检报告 §8 有 17 条「待验证」，其中 4 条会**实质改变修复计划**（多一条修复、少一条修复、或批次内顺序变化）。本文给出这 4 条的**可执行验证步骤**。
> 本轮已把其中 **2 条静态查清**（不需要你动手，结论直接采纳）；剩下 **2 条必须真机验**，步骤在 §2、§3。
> 全部步骤都不改代码，或只改**临时插桩**（验完即撤）。本文未改动任何代码，工作树干净。

---

## 0. 结论速览

| # | 待验证项 | 状态 | 对计划的影响 |
|---|---|---|---|
| 1 | `MediaInfo.Open(int fd, String name)` 重载是否存在 | **✅ 已查清：存在** | B13 的 P1-18 按 `Open(pfd.fd, name)` 修，**不必**用 `adoptFd` 回吞所有权 |
| 2 | x86/x86_64 是否缺 MediaInfo 原生库 | **✅ 已查清：确认缺** | **P1-18 在 x86_64 上必现**，B13 里升为第一条 |
| 3 | `player_seek_bar` 松手回跳的复现率 | **✅ 已真机验证：不复现** | 从 B3 移出 → **B16** 的 3 行防御性修复（可选做） |
| 4 | `_markCompleted` 是否被 `_saveProgress` 覆盖 | **✅ 已真机验证：确认发生** | **B3 已追加**该修复条目（详见 §3.5） |
| 5 | 【新增】x86_64 媒体信息页是否要可用 | **✅ 已决策：D9 选 A** | B13 **只修 fd 泄漏**，不换依赖；x86_64 上媒体信息页保持「无可解析数据」 |

---

## 1. 已查清的两条（结论 + 证据，无需你动手）

### 1.1 `Open(int fd, String name)` 重载：**存在**

- **怎么查的**：从 Gradle 缓存里的 AAR 取出 `classes.jar` → 抽 `net/mediaarea/mediainfo/lib/MediaInfo.class` → 读常量池里的方法描述符。
- **证据**：`C:\Users\root\.gradle\caches\modules-2\files-2.1\com.github.marlboro-advance\...\mediainfoAndroid-v1.1.0.aar` → `classes.jar` → `MediaInfo.class` 常量池含：
  - `(ILjava/lang/String;)I` ← **`Open(int, String)`，正是修复所需**
  - `(Ljava/lang/String;)I` ← 另有 `Open(String)` 档案名重载
  - 其余为 `getInfo(...)`/`Count_Get(...)` 等
- **对修复的意义**：`MediaInfoHelper.kt` 三处可以改为
  ```kotlin
  android.os.ParcelFileDescriptor.open(File(path), MODE_READ_ONLY).use { pfd ->
      val mi = MediaInfo()            // 先建，失败直接返回，pfd 由 use 关闭
      try { mi.Open(pfd.fd, File(path).name) } finally { mi.Close() }
  }
  ```
  即**根本不需要 `detachFd()`**，从而彻底消除「detach 后 close 是空操作」这一类泄漏。
- **注意**：`mi.Open(pfd.fd, …)` 用的是 `pfd.fd`（int 字段），仍需 `pfd` 活着 → 所以必须是 `use { }` 包住整个调用，不能先 close。

### 1.2 x86 / x86_64 缺 MediaInfo 原生库：**确认缺**（P1-18 必现）

- **怎么查的**：直接解压本项目**已产出的 release APK** 比对 `lib/` 目录（`System.IO.Compression`，未安装未运行）。
- **证据**：

  | APK | `libmediainfo.so` / `libzen.so` | lib 条目数 |
  |---|---|---|
  | `app-arm64-v8a-release.apk` | **有**（`lib/arm64-v8a/`） | 8 |
  | `app-x86_64-release.apk` | **没有** | 6 |

  差异清单：arm64 独有 `libmediainfo.so`、`libzen.so`；x86_64 独有：无。
  根因：`android/app/build.gradle.kts:68` 依赖的 `mediainfoAndroid:v1.1.0` 的 aar **只打包了 arm64-v8a 与 armeabi-v7a** 的 `jni/*`（机器上另有一个 `mediainfoAndroid-v1.0.0-fix.aar` 是四 ABI 齐全的旧包，当前未被使用）。
- **结论**：在任何 **x86 / x86_64 环境（模拟器、部分平板/Chromebook）**上，`MediaInfo()` 构造都会抛 `UnsatisfiedLinkError`（代码注释 `MediaInfoHelper.kt:40-41` 自己也写明了这点）→ 走到 `:43` 的 `pfd.close()`，而它**在 `detachFd()` 之后是空操作** → 每次调用泄漏 1 个 fd。
- **影响面（重要，避免误判严重性）**：
  - **真机（ARM）不受影响** —— 有 so，正常走 `mi.Close()`。
  - **x86_64 模拟器/设备受影响**：
    - `detectDolbyVision` → `extractBasicMetadata`（`player_page.dart:765`，**每个本地视频 open 时调用一次**）→ 每播一个本地视频泄漏 1 个 fd；
    - `getMediaInfo` 只在 `media_info_page.dart:32` 调用 → 每开一次媒体信息页泄漏 1 个 fd。
  - 累积到进程 fd 上限后，表现为「列表封面全空 / 字幕音频导入失败 / 媒体信息页空白」，且日志只有一句 `MediaInfo native lib unavailable` —— **极难定位**。
- **额外发现（需要你决策的新问题，见 §4）**：x86_64 上媒体信息页本来就**没有数据**（so 缺失 → `emptyMap()`），所以「修 fd 泄漏」只解决泄漏，**不解决功能缺失**。要让 x86_64 也能看媒体信息，得把依赖换成四 ABI 齐全的 `v1.0.0-fix`（或让作者的 v1.1.0 补 x86 产物）。

---

## 2. 待验 #3：进度条松手是否「回跳」（影响 B3）

### 2.1 为什么需要验

代码事实（已确认）：
- `player_seek_bar.dart:76` `final valueMs = widget.valueMs;` 在 `build` 里捕获；
- 拖动中 `handleAt()`（`:93-97`）**只把目标值往外抛**（`widget.onChanged`），**本 State 不保存**；
- 松手时 `onHorizontalDragEnd`（`:123-126`）用的是**那次 build 捕获的 `valueMs`**，而不是最后一次拖动的位置；
- 该值最终进 `player_page.dart:3315-3316` 的 `_player.seek(...)`。
- 点击轨道走的 `onTapUp`（`:106-112`）**用的是实时坐标**，所以点击不会回跳——只有拖动可能。

是否会真回跳，取决于「最后一次 `onChanged` 触发的重建」是否赶在 `onHeaderDragEnd` 之前发生（帧序问题），**静态无法定论**。

### 2.2 步骤 A：零代码盲测（先做这个）

1. 真机进入播放页（**横屏**），拖进度条到中段并**极其快速地甩动后立刻松手**（手指离开屏幕的动作要快）。
2. 看松手瞬间：**浮层预览显示的落点时间**与**松手后实际跳到的位置**是否一致。
3. 重复 10 次（快甩 5 次、慢拖 5 次作对照），记录：
   - 快甩：是否出现「跳到的位置比预览位置靠后一点」（回跳）
   - 慢拖：应当每次都准
4. **另做对照**：直接**点击**轨道某处（不拖）→ 应当每次都准确（因为 `onTapUp` 用实时坐标）。
5. **竖屏页同样测一遍**（`player_portrait_page.dart:2066-2075` 同款 `onSeekEnd`）。

**判定**：
- 若「快甩必回跳、点击必准」→ **复现**，P1 保留在 B3。
- 若 20 次都准 → **不复现**，从 B3 移出，降为 B16 的防御性修复（改动只有 3 行：State 记 `_lastDragMs`，`onChangeEnd` 传它）。

> 建议测试素材：一个**时长较长**（>30 分钟）且**能快速解码**的本地视频——回跳距离与「两次事件间手指移动的像素数」成正比，视频越长越容易察觉。

### 2.3 步骤 B：插桩量化（可选，只在步骤 A 拿不准时做）

在 `player_seek_bar.dart` 的 `onHorizontalDragEnd` 里临时插一行日志（**验完必须撤掉**）：

```dart
onHorizontalDragEnd: (d) {
  _setInteracting(false);
  // ==== 临时插桩，验完删除 ====
  final recomputed = trackWidth <= 0 || maxMs <= 0
      ? valueMs
      : ((d.localPosition.dx - trackLeft) / trackWidth).clamp(0.0, 1.0) * maxMs;
  debugPrint('[SEEKPROBE] 松手用值=${valueMs.round()}  实时坐标值=${recomputed.round()}  '
      '差=${(recomputed - valueMs).round()}ms');
  // ==========================
  widget.onChangeEnd(valueMs);
},
```

- **判定阈值**：在 1080p 手机上，横向拖 1 像素约等于 `maxMs / trackWidth` 毫秒。**差值持续 > 2000ms（约一屏宽度的 2%）** 即认为「陈旧的 `valueMs` 导致了可感知的回跳」→ 复现。
- 若差值恒为 0 或个别几十毫秒 → 不复现（属正常抖动）。
- 验证完请把这段插桩**完整删除**并重跑一次确认无残留（`debugPrint('[SEEKPROBE]` 全仓应搜不到）。

### 2.4 两种结果分别对应的动作

| 结果 | 动作 |
|---|---|
| 复现 | P1 留在 **B3**；修法：State 内记 `_lastDragMs`（`handleAt` 里更新），`onChangeEnd(_lastDragMs)`；`onHorizontalDragCancel` 同 |
| 不复现 | 从 B3 移出 → 进 **B16**（防御性，低成本，可选做） |

---

## 3. 待验 #4：「已看完」标记是否被退出保存覆盖（影响 B3）

### 3.1 为什么需要验

代码事实（已确认）：
- `_onPlaybackCompleted`（`player_page.dart:2925-2962`）在 EOF 分支里先 `_markCompleted()`，再 `_playNext()`/`_playFirst()`/`_exitPlayer()`/`pauseAtEnd`；
- `_markCompleted()`（`:2966-2969`）写的是 `save(_path, _duration)`，即**进度 = 时长（100%）**；
- 注意 `EndOfFileAction.replayCurrent`（单集循环）**不调 `_markCompleted`**；
- 而 `_saveProgress`（退出/切集时）写的是**当前位置** `_position`；
- `_exitPlayer()` 路径上 `_saveProgress(forcePersist: true)` 的时间点**晚于** `_markCompleted()`。

所以：**若退出时 `_position < _duration`（哪怕只差 1 秒），最终落盘的就是 `_position`，把 100% 覆盖掉** → 卡片不算「已看完」。
而 `_onPlaybackCompleted` 前面有一道门（`:2928-2929`）：
```dart
if (_duration <= Duration.zero) return;
if (_position < _duration - const Duration(seconds: 1)) return;
```
即允许**最多 1 秒**的差值进来 → 这个「1 秒窗口」正是覆盖能否发生的关键。

**发生的后果**：
1. 卡片显示「未看完」（视阈值而定），且下次重播会**从 99% 处恢复**（按 §4.1/§7 规则，≥已观看阈值才不恢复；默认阈值 95% 时 99% 也会被判定为看完，所以**默认阈值下大概率无害**）；
2. 但把「已观看进度阈值」调到 **100%** 的用户（设置允许 5%–100% 步进 5%）→ **每次播完都不会被标记为已看完**，且下次会尝试恢复。
3. 另一个潜在症状：`pauseAtEnd` 分支先 `_markCompleted()` 再 `seek(_duration)`+`pause()`，随后若用户退出 → `_saveProgress` 写 `_position`（≈duration）→ 无害。

### 3.2 步骤（不需要插桩，纯行为验证）

准备：一个**短视频**（1~3 分钟，方便反复播完）、把「已观看进度阈值」设为 **100%**（设置 → 播放器设置 → 已观看进度阈值拉满）；播放模式设为**自动暂停**（避免自动连播/退出干扰）。

1. 进入播放页播到**自然结束**（不要手动拖到结尾），观察是否进入 `pauseAtEnd`（停在结尾、暂停）。
2. **按返回键退出**播放器，回到列表。
3. 看该视频卡片：
   - **期望（若未覆盖）**：显示「已看完」（置灰）。
   - **疑似 bug**：仍显示「观看中」。
4. **再进一次**该视频：
   - **期望**：从头播（因为已看完不恢复）。
   - **疑似 bug**：从末尾附近开始（进度恢复到了 ~99%）。
5. 为排除偶然，把阈值改回默认 95%，重做 1~4 —— 若 95% 下正常、100% 下异常，则**确认覆盖发生**（说明最终落盘值确实 < 100%）。

### 3.3 辅助确认（可选，读盘验证最终值）

若步骤 3/4 拿不准，直接看落盘的进度值（debug 包）：

```powershell
adb shell run-as com.azxcvn.moumou cat /data/data/com.azxcvn.moumou/shared_prefs/*.xml | Select-String 'playback_progress'
```

- **判定**：找到 `playback_progress` 这个键，读出该视频路径对应的毫秒值。
  - 若等于该视频**时长**（或与时长差 < 1000ms）→ 已看完标记**未被覆盖**（或覆盖幅度可忽略）。
  - 若明显小于时长（差额 > 1 秒）→ **确认被覆盖**。
- 对照实验：同一视频，**手动拖到结尾**再退出（不经 EOF）→ 此时理应不是「已看完」，用来确认读法正确。

### 3.4 两种结果分别对应的动作

| 结果 | 动作 |
|---|---|
| 确认覆盖 | **B3 追加一条**：「EOF 标记已看完后退出 → `_saveProgress` 不得覆盖更高进度」（修法：`_saveProgress` 写入前比较现有值，或加 `_completedMarked` 标志跳过本次保存） |
| 未覆盖 | 不追加；但仍建议在 B3 加一条注释说明「EOF 先标记、退出后写」的时序是有意为之，防后续改坏 |

### 3.5 ✅ 实测结果（已回填，2026-02）

| 观测项 | 结果 |
|---|---|
| 自然播完 → 进入 `pauseAtEnd` | 是（停在结尾、暂停） |
| 退出后卡片显示 | **100%** |
| 重进该视频 | **从末尾开始（~99%，非从头播）** → 说明落盘进度 < 时长，**「已看完」判定失败** |
| 阈值 60% | 正常（不暴露） |
| 阈值 95%（**默认值**） | 正常（不暴露） |
| 阈值 100% | **异常（暴露）** |

**结论：确认 `_markCompleted()` 被 `_saveProgress()` 覆盖**——EOF 时 `_position` 比 `_duration` 少 ≤1 秒（`_onPlaybackCompleted` 开头的 `_position < _duration - 1s → return` 守卫允许这个窗口），退出时 `_saveProgress(forcePersist: true)` 用 `_position` 覆盖了刚写入的 100%。

**严重性校正（重要）**：该缺陷**只在「已观看进度阈值」被设为 100% 时可见**——任何 <100% 的阈值都会因为「落盘值 ≈99% > 阈值」而掩盖它。默认阈值是 **95%**（`player_controls_settings.dart:169/288/722` 均为 `0.95`，`ARCHITECTURE.md` §5.3 同），所以影响面小，**定为 P3**。
**但修复成本极低（2~3 行）且能消除一个「显示 100% 却不算看完」的逻辑矛盾**，故仍**保留在 B3**（不单独占时段，顺手做掉）。

> ⚠️ 附带澄清：设置页滑杆把 95% 显示成 `100%` 属显示层取整/吸附正常现象，与阈值原值无关；以代码里的 `0.95` 为准。

---

## 4. 本轮新冒出来的一个决策点（需你定，D9）—— ✅ 已决策

因为 §1.2 查实了 **x86_64 缺 MediaInfo 原生库**，衍生出一个新问题：

| 编号 | 问题 | 选项 | 影响 |
|---|---|---|---|
| **D9** | x86_64（模拟器）上媒体信息页**本来就没有数据**，是否要让它在 x86_64 上可用？ | **A. 只修 fd 泄漏**（B13 按原计划）；x86_64 上媒体信息页保持「无可解析数据」 | 改动最小；模拟器上该功能不可用（但真机可用） |
| | | **B. 同时换用四 ABI 齐全的 `mediainfoAndroid:v1.0.0-fix`**（机器上 gradle 缓存里已有该 aar，含 x86/x86_64 的 so） | x86_64 也能看媒体信息、杜比检测；**需要你验证 v1.0.0-fix 的 API 是否与 v1.1.0 兼容**（`MediaInfo` 类名/方法一致，但要编译验证）+ APK 体积增大（该 aar 13.7MB vs 5.2MB） |
| | | **C. 暂不处理**，只记录到 §7 已知注意事项 | 泄漏与功能缺失都留着 |

**✅ 决策（用户拍板）：选 A** —— B13 只修 fd 泄漏、不换依赖；x86_64（模拟器）上媒体信息页保持「无可解析数据」。
**对 B15 的附带要求**：把「x86/x86_64 无 MediaInfo 原生库 → 媒体信息页与杜比检测在该 ABI 下不可用；`getMediaInfo` 每次调用泄漏 1 个 fd（已修）」写进 `ARCHITECTURE.md` §7 已知注意事项，避免以后有人在模拟器上把它当 bug 反复查。

---

## 5. 验证结果回填表（✅ 已全部回填）

| 项 | 结果 | 实测数据 | 对计划的调整 |
|---|---|---|---|
| seek 松手回跳 | **✅ 不复现** | 快甩/慢拖/点击各 10 次均准确，无回跳 | **降 B16**（3 行防御性修复，可选） |
| 已看完标记被覆盖 | **✅ 发生** | 阈值 100% → 卡片显示 100%、重进从 ~99% 播；95%/60% 正常 | **B3 追加一条**（P3，顺手做） |
| D9 x86_64 媒体信息页 | **✅ 选 A** | — | **B13 只修泄漏**，不换依赖；§7 记一条 |

---

## 6. 【2026-09 追加】真机 bug 的复验步骤（P1-39 / P1-40，随 B0.5 一起验）

> 背景：真机播放「TrueHD 英语轨 + AC-3 国语轨 + 4 条 PGS 中文字幕」的 MKV 时发现
> ①切英语（TrueHD）音轨完全无声；②四条 PGS 字幕选哪条都不显示。
> **真因已查明在自编内核的 ffmpeg 解码器白名单里**（不在应用层）：
> `buildscripts/flavors/default.sh` 的 `--disable-decoders` 白名单漏了
> `pgssub`（PGS 字幕）与 `truehd`（TrueHD 音频）。
> 结论：内核已改为**解码器/解封装器/解析器全开**（最终 commit **`b5da4f2`**，CI run #8），
> 产物 **4 个 ABI 已验证通过**（解码器符号 **161 → 523 个**）**并已替换进**
> `third_party/media_kit_libs_android_video/android/jars/`（无需改 Dart 代码）。
> 应用侧的兜底与收口见体检报告 §2.6.1、`ARCHITECTURE.md` §4.32。

### 6.1 ✅ 已验（2026-09，旧内核）

| # | 步骤 | 结果 |
|---|---|---|
| 1 | 切到 TrueHD（英语）轨 | **确实放不出来**（旧内核无 truehd 解码器），且**已自动回退到可用声道并正常出声** → 应用层兜底生效 |

### 6.2 换新内核 jar 后要验的（按顺序）

> 新 jar **已经替换进项目**、`flutter analyze` / 1151 个测试 / release APK 编译均已通过，
> 你只需要装到手机上做行为复验。

| # | 步骤 | 期望 |
|---|---|---|
| 1 | 编译安装（`tools\build_and_install.ps1`，默认 release；无需改任何 Dart 代码） | 编译通过、安装成功 |
| 2 | 播放该 MKV → 音频面板切到 TrueHD（英语）轨 | **直接出声**；**不再**弹「当前音轨无法播放…」（若还弹，说明 APK 里还是旧内核） |
| 3 | 同一 MKV → 字幕面板依次选中 ID 4/5/6/7 四条 PGS | **每条都能显示** |
| 4 | 换一个**只有一条音轨**的普通视频 → 播放/拖动/切集 | 全程**不出现**音轨回退提示（无误报） |
| 5 | 导入一个外挂 .ass / .srt 字幕；拖字幕样式滑杆 | 正常显示、样式生效、不卡顿 |
| 6 | 字幕字体页导入自定义字体 → 退出播放器重进 | 字幕按新字体渲染（§4.10 未回归） |

**已知限制（不算失败）**：TrueHD 即使能解码，也会被 mpv **下混成 stereo** —— Android 上
media_kit 写死 `ao=opensles`，而 OpenSL ES 输出只支持双声道。要真多声道需在内核里改用
`audiotrack`/`aaudio` AO（OpenSL ES 在 mpv 0.42 已被移除），属独立立项。

**排查用自检**（判断 APK 里的内核到底是不是新的，只看**符号名**）：

```bash
# 从 APK 里取 libmpv.so（APK 就是 zip）
unzip -o app-release.apk 'lib/arm64-v8a/libmpv.so' -d /tmp/apkcheck
SO=/tmp/apkcheck/lib/arm64-v8a/libmpv.so

# 1) 三个关键能力各应为 1
for s in ff_pgssub_decoder ff_mlp_decoder ff_truehd_decoder mk_thumbnail_grab; do
  echo "$s = $(strings $SO | grep -c $s)"
done

# 2) 解码器总数：旧内核 161，全开后应为 523（明显更多即说明是全开版）
echo "decoders = $(strings $SO | grep -o 'ff_[a-z0-9_]*_decoder' | sort -u | wc -l)"
```
⚠️ 别用 `strings ... | grep truehd` 判断：那会命中 `--enable-demuxer=truehd` 带来的
**解封装器**名字，据此判断"解码器已编入"是错的（本项目踩过）。

**若第 3 步仍不显示**：说明 PGS 还有第二根因，请把播放时的 `track-list/selected`、`sid`、
`sub-visibility`、`codec`、`sub-text` 属性值（播放器内置「播放诊断」页已能看一部分）贴回来；
同时抓一份 mpv 日志：
```powershell
adb logcat -s media_kit:* mpv:* flutter:* | Select-String -Pattern 'sub|ass|pgs|decoder'
```

> 说明：第 2/3 步是唯一权威判据；不要用 `docs/archive/ARCHITECTURE.md` §4.32 的静态结论替代真机验证。

---

*本文档只读产出（除 §2.3 的临时插桩需你手动加/删），未改动任何代码。§1 两条结论来自静态查证、§3.5 与 §5 来自你的真机实测，全部可直接采纳，开工前无剩余阻塞项。*
