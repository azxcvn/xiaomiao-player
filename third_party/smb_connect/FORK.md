# smb_connect 本地魔改说明（FORK.md）

> 本目录是 `smb_connect` 的**本地 fork**（通过根目录 `pubspec.yaml` 的
> `dependency_overrides` 以 `path:` 方式接入）。本文件记录**基线版本、补丁清单、
> 升级步骤与验证方法**。
>
> 本文件是本地新增文件，**不属于上游仓库**；上游的 `README.md` 保持原样未改。
> 姊妹文档：`third_party/media_kit/FORK.md`（另一个 fork）。

---

## 1. 为什么需要 fork

上游 0.0.9 用**一把全局互斥锁**（`SmbTransport.sendrecvMutex`）把**所有** SMB 请求
串行化：同一时刻只允许一个请求在途。于是吞吐上限被压成

```
单次读取块 ÷ 往返延迟 ≈ 64KB / 40ms ≈ 1.5 MB/s
```

访问 NAS 播放高码率视频时严重不够用。

本 fork 的目标：**允许多个请求并发在途**（pipelining），同时**不破坏 SMB2 响应匹配
的正确性**——为此必须显式补上上游靠那把锁"隐式"获得的两处串行化保证（见补丁 2、3）。

## 2. 基线版本

| 项 | 值 |
|---|---|
| 上游包 | `smb_connect` |
| 基线版本 | **0.0.9**（pub.dev 发布版） |
| 本地版本 | **0.0.9-mk.1**（`pubspec.yaml`，后缀用于区分本地魔改版） |
| 校验方式 | 与 pub 缓存中的 `smb_connect-0.0.9` 逐文件 diff |
| 差异规模 | **6 个文件**（`lib/` 下）+ `pubspec.yaml`，约 +71 / −114 行 |
| 依赖差异 | 上游声明 `mutex: ^3.1.0`，本 fork **已移除**（补丁 1 后不再引用） |

对照物（本机路径，升级时换成本机 pub 缓存里的目标版本）：

```
%LOCALAPPDATA%\Pub\Cache\hosted\pub.flutter-io.cn\smb_connect-0.0.9
```

## 3. 补丁清单

### 补丁 1：去掉全局互斥锁，改为请求并发在途（核心）

文件：`lib/src/connect/smb_transport.dart`（`sendrecv`）

- 删除 `sendrecvMutex`（`Mutex`）及 `acquire()` / `release()` 包裹，并移除
  `package:mutex/mutex.dart` 导入 → 请求不再被全局串行化
- 新增 `ensureMid(request)`：在**发送之前**遍历请求链，为尚未分配 messageId 的请求
  分配 mid，并返回链头 mid
- **发送前先注册 completer**：`responses[key] = (response:…, completer:…)` →
  `await doSend(…)` → 再 `await completer.future.timeout(waitResponseTimeout)`。
  上游是在 `doSend` **之后**才调用 `waitResponse(...)` 注册的——串行时无所谓，
  一旦并发就会出现「响应比挂载先到」的竞态，因此这一步是去锁的**必要配套**
- 保留 5 次重试与 `waitResponseTimeout` 超时语义不变

### 补丁 2：读取侧串行化（`_readQueue`）

文件：同上（`onListenReader` → `_drainResponses`）

- 上游 `onListenReader()` 直接在回调里跑响应分发。存在多个并发在途请求时，回调会被
  **重入**，`_peekKey()` / `_doRecv()` 会并发读写共享的 `_sbuf` 与 `_inp` 游标，
  导致**响应错位、匹配失败、completer 超时**
- fork 改为把所有处理串成单条 future 队列：

  ```dart
  Future<void> _readQueue = Future<void>.value();
  void onListenReader() {
    _readQueue = _readQueue.then((_) => _drainResponses());
  }
  ```

### 补丁 3：发送侧串行化（`_sendQueue`）

文件：同上（新增 `_enqueueSend`，`doSend` 改为调用它）

- Dart 的 `Socket` 写入端（`_StreamSinkImpl`）**不是重入安全的**：一个协程在
  `flush()` 期间 `_isBound = true`，此时另一个协程 `add()` 会抛
  `StreamSink is bound to a stream`。原库靠那把全局锁隐式串行化了这一步
- fork 新增 `_enqueueSend()`，用 future 链把「编码 + 写 socket + flush」串行化：

  ```dart
  final run = _sendQueue.then((_) async { … _out.write(…); await _out.flush(); });
  _sendQueue = run.catchError((_) {});
  ```

- **关键权衡**：**响应等待是并发的，只有「写」仍串行**。吞吐瓶颈在网络往返而不在写
  请求，因此不影响提速效果

### 补丁 4：`SocketWriter.write` 由 `async void` 改回同步

文件：`lib/src/utils/socket/socket_writer.dart`

- 上游签名为 `void write(Uint8List buffer, int offset, int length) async`。
  `async void` 中抛出的异常会**绕过调用方**（`doSend` → `sendrecv`），变成
  Zone 级 Unhandled Exception —— socket 关闭后大量刷屏，且上层 `try/catch` 捕获不到
- fork 去掉 `async`，保持同步，让异常沿调用栈正常向上传播

### 补丁 5：analyzer 清理（无效注解与冗余写法）

均属上游继承来的瑕疵，**全部行为零变化**，仅消除 analyzer 提示：

**(a) 移除无效的 `@override`** —— `lib/src/spnego/neg_token_init.dart`、
`lib/src/spnego/neg_token_targ.dart`

- `factory NegTokenInit.parse(...)` / `factory NegTokenTarg.parse(...)` 上原本标有
  `@override`，但基类 `SpnegoToken` **并未声明 `parse`**，且 Dart 中构造函数不可被
  重写 —— 注解无效（analyzer：`invalid_annotation_target`）
- 已移除并留注释说明（注解无运行时语义）

**(b) 移除多余的库名** —— `lib/smb_connect.dart`

- 删除 `library smb_connect;`（analyzer：`unnecessary_library_name`）。库名无功能
  用途、仅供 dartdoc 引用；该文件也没有需要挂在库上的文档注释，故整条指令可删

**(c) 移除多余的 `this.` 限定** —— `lib/src/connect/impl/smb2/server_message_block2_request.dart`

- 删除 2 处（analyzer：`unnecessary_this`）：`getOverrideTimeout()` 内的
  `return this.overrideTimeout;` 与 `setResponse()` 内的 `this.response = ...`
- 两者作用域内**均无同名局部变量/参数遮蔽**，去掉限定后语义完全相同
  （`setResponse` 的参数名是 `msg` 而非 `response`）

## 4. 应用层配套（不在本 fork 内，但依赖本 fork）

| 位置 | 作用 |
|---|---|
| `lib/services/network/smb_client.dart` | 并发预读管线：`const workers = 4`，用 4 个独立文件句柄并发读取不同块、按块序号合并输出。**依赖本 fork 的并发在途能力**——若退回上游的全局锁，多句柄也只是排队，吞吐不会提升 |
| `lib/services/network/network_streaming_proxy.dart` | 本地 HTTP 流代理（Range 转发） |

## 5. 升级步骤

1. 从 pub 缓存取到目标版本源码。
2. 与当前 fork 做差异对照：
   ```powershell
   git diff --no-index --ignore-cr-at-eol `
     'third_party\smb_connect\lib' `
     "$env:LOCALAPPDATA\Pub\Cache\hosted\pub.flutter-io.cn\smb_connect-<新版本>\lib"
   ```
3. 若上游已支持并发在途（例如自行移除了全局锁），**优先改用上游并删除本 fork**。
4. 否则以新版本源码为基线，重新施加补丁 1～5。补丁 1 集中在 `sendrecv` 一处，
   补丁 2/3 各一处，冲突面都很小。
5. 更新本文件第 2 节的「基线版本」，并在 commit message 里注明。

## 6. 验证方法

| 验证项 | 做法 |
|---|---|
| 补丁完整（结构标记） | `Select-String -Path third_party\smb_connect\lib\src\connect\smb_transport.dart -Pattern 'ensureMid\|_readQueue\|_sendQueue\|_drainResponses'` 应能列出全部标记点 |
| 全局锁确已移除 | 该文件内不应再出现 `sendrecvMutex.acquire` / `mutex.dart` 导入 |
| 功能正确 | SMB 浏览目录、播放视频正常；并发预读时**不应**出现 `SmbTransport cant send request`、`TimeoutException` 或响应错位 |
| 吞吐确实提升 | 对比「并发读」与「单请求串行」的读取速度：若退回 ≈1.5 MB/s 量级，说明并发在途没生效 |
| 无刷屏异常 | socket 关闭/网络中断时，不应出现 Zone 级 Unhandled Exception 刷屏（补丁 4 的验证点） |
| analyzer 无残留 | `flutter analyze` 中本包不应出现 `invalid_annotation_target` / `unnecessary_this` / `unnecessary_library_name`（补丁 5 的验证点） |

## 7. 已知遗留与版本约定

**无未决遗留。**

- ✅ **移除未使用的 `mutex` 依赖**：上游声明 `mutex: ^3.1.0`，但补丁 1 移除了它唯一
  的用处，且全包（含 `example/`）与应用层 `lib/` 均不再引用 `package:mutex`，已从
  `pubspec.yaml` 删除。`pubspec.lock` 需 `flutter pub get` 后同步（若没有其它包依赖
  `mutex`，它会从 lock 中消失）。
- ✅ **本地版本号加后缀**：`0.0.9` → **`0.0.9-mk.1`**，与
  `third_party/media_kit_libs_android_video` 的 `1.3.8-mk.1` 命名风格统一，便于
  排查问题时一眼确认跑的是本地魔改版。

> **版本号约定**：本地 fork 建议采用 `<上游版本>-mk.<本地修订号>`，便于在日志/崩溃
> 上报中区分「上游原版」与「本地魔改版」。当前 `third_party/` 下三个 path 依赖的
> 实际状态：
>
> | 本地包 | 版本 | 是否采用后缀 |
> |---|---|---|
> | `media_kit_libs_android_video` | `1.3.8-mk.1` | ✅ 已采用 |
> | `smb_connect` | `0.0.9-mk.1` | ✅ 已采用（本次） |
> | `media_kit` | `1.2.6` | ❌ 未加后缀（如需统一可改为 `1.2.6-mk.1`） |
>
> ⚠️ 修改任何 `third_party/` 下 path 依赖的版本号后，需跑一次 `flutter pub get`
> 让 `pubspec.lock` 同步，否则 lock 中的版本记录会与实际不符。
