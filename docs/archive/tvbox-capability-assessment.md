# TVBox（影视TV / TV-fongmi）能力引入评估

> 只读调研 + 方案设计，**未改动任何代码、未编译**（AGENTS.md：禁止私自编译）。
> 参考项目：`杂项文件/参考项目/TV-fongmi/TV-fongmi/`（下称「参考项目」）
> 本项目：小喵Player（Flutter + 自建 libmpv，下称「本项目」）
> 日期：2026-09-30

---

## 0. 结论先行

| 问题 | 结论 |
|---|---|
| 能不能引入？ | **能**，但不是「搬一部分 Dart 代码」那种引入：参考项目的 TVBox 能力是 **Android Java 原生能力**，必须在本项目 `android/` 里新增原生模块，再用 MethodChannel 暴露给 Dart |
| 引入后「网盘」是哪来的？ | **参考项目自身没有任何网盘实现**（全仓库搜不到阿里云盘/夸克/115 等，见 §2.3）。网盘、`csp_` 站点、绝大部分内容源**全部由外部 spider jar/JS 提供**。所以：**没有 spider 运行时，就没有网盘能力** |
| 最省事的路线 | 只做 HTTP 接口（type 0/1/4）→ 纯 Dart，零原生改动、零体积增加，但拿不到 spider/网盘 |
| 完整能力路线 | 移植 `catvod` 模块 + 外部 jar 加载 + JS 运行时（quickjs）→ 覆盖 type 3 站点与网盘；再做 WebView 解析与 Python spider 则成本陡增 |
| 最大不确定性 | ① 本项目 AGP 9.0.1 / Java 17 / compileSdk 36，参考项目 AGP 9.3.1 / **Java 21** / compileSdk 37 —— **能否顺利降级引入，我没有编译验证过，无法下结论**；② 第三方 spider jar 是预编译产物，只能靠实际样本验证兼容性 |
| 已知风险 | TVBox spider 生态的内容源普遍涉及未授权影视与网盘直链，引入即绑定这类源（用户已知悉，见 §7） |

---

## 1. TVBox 能力拆解（参考项目的真实组成）

参考项目是一个多模块 Android 工程（`settings.gradle:23-26`）：

```
include ':app'      # 26,101 行 Java（app/src/main/java），UI + 播放器 + 站点/解析调度
include ':catvod'   # 2,267 行，28 个文件 —— CatVod 接口层（Spider 基类 + OkHttp 封装）
include ':chaquo'   # Python 3.10 运行时（chaquo 插件），292 行 Java + 4 个 .py
+ quickjs           # JS 运行时（QuickJS），845 行 Java + 1.05 MB JS 辅助库
+ hook/jianpian/thunder/tvbus/zlive/forcetech  # 特定 P2P/迅雷/直播核心（预编译 AAR）
```

按「用户可感知的能力」拆成 6 块：

| # | 能力 | 实现位置 | 是否可移植 | 运行时依赖 |
|---|---|---|---|---|
| 1 | **配置解析**（站点/解析器/直播/规则） | `app/api/config/VodConfig.java` 等 | ✅ 纯 Java 逻辑 | OkHttp + Gson |
| 2 | **HTTP 站点调用**（type 0/1/4） | `app/api/SiteApi.java` | ✅ 逻辑简单，**可用 Dart 重写** | 仅 HTTP |
| 3 | **Spider 运行时**（type 3：jar / JS / Python） | `app/api/loader/*` + `catvod` + `quickjs` + `chaquo` | ⚠️ 可行但工作量大 | DexClassLoader / QuickJS / Python |
| 4 | **播放地址解析**（parse） | `app/player/parse/ParseJob.java` | ⚠️ type 1/2/3 可做，**type 0 必须 WebView** | WebView / jar |
| 5 | **本地 HTTP 服务**（`/proxy` 委派 spider、`/cache` KV、`/file` 文件、Range/206） | `app/server/*`（NanoHTTPD 2.3.1） | ⚠️ 必须搬（外部 spider 硬编码访问），部分端点可砍 | 无（HTTP server） |
| 6 | **网盘** | **不存在于参考项目**，来自外部 spider | ❌ 无内置可搬 | 同 #3 |

> 注：**头部注入与 302 跟随不在本地服务里**，分别在播放器数据源与 OkHttp 拦截器（详见 §2.5 的纠正表）。

---

## 2. 逐项核实（证据）

### 2.1 配置解析：纯 HTTP + JSON

`VodConfig.java:113-116` 拉配置：`Decoder.getJson(UrlUtil.convert(config.getUrl()))` → `Json.parse(json)`。
字段处理见 `VodConfig.java:142-191`：

- `initList`：`headers` / `proxy` / `rules` / `doh` / `flags` / `hosts` / `ads`
- `initSite`：`spider`（全局 jar 地址）→ `BaseLoader.parseJar(spider, true)`；`sites[]` → `Site.objectFrom`
- `initParse`：`parses[]` → `Parse.objectFrom`

**没有额外运行时依赖**，Gson + OkHttp 而已（`catvod/build.gradle:31-40`）。

**Site 字段语义**（`bean/Site.java:37-108` + 官方配置字典）：

| 字段 | 语义 |
|---|---|
| `key` / `name` | 唯一标识 / 显示名 |
| `type` | `0`=XML HTTP、`1`=JSON HTTP、`3`=Spider（JAR/JS/PY）、`4`=HTTP 扩展（ext 以 Base64 传） |
| `api` | HTTP 端点、`csp_类名`、或 `./x.js` / `./x.py` 相对路径 |
| `ext` | type 3 时传给 `Spider.init(context, ext)`；HTTP 站点以 `extend` 参数发送（`SiteApi.java:40`）。**可以是字符串/对象/数组**——`gson/ExtAdapter.java:14-16` 把对象/数组序列化成字符串 |
| `jar` | 覆盖全局 spider 的 jar 地址（`Site.java:137` 缺省回填全局 `spider`） |
| `playUrl` | type 0/1 的 URL 前缀，支持 `json:` / `parse:` 前缀（`ParseJob.java:66-67`） |
| `header` | HTTP 站点请求头；type 3 不会自动套到 spider 自己的请求上 |
| `searchable` / `changeable` / `quickSearch` / `danmaku` / `hide` / `indexs` | 开关类（`Site.java:221-235` 默认值）；`searchable`：`1`=参与搜索、`0`=不可改、`2`=用户手动关闭 |
| `flags`（**顶层**，非 site 字段） | 传给 `playerContent(flag, id, vipFlags)` 的 `vipFlags`（`VodConfig.java:159,241-247` → `SiteApi.java:148`） |

> 补充两点：① `playerType` 字段在本参考项目**不存在**（全仓 0 命中），若你的配置里有它，不会被解析；② `type` 在 `Site.java:68-69` 声明为 `Integer`，而配置里常写成 `"3"`，Gson 对 number 字段读 string token 是宽松的，但**这一点我没有实测验证**（列入 §8 不确定项）。

### 2.2 Spider 运行时：三条链路，三种代价

**JAR 链路**（`api/loader/JarLoader.java`）：
- `:58` `new DexClassLoader(jar, cachePath, cachePath, App.get().getClassLoader())` —— 标准 Android 动态 dex 加载，缓存目录 `cacheDir/jar`（`catvod/utils/Path.java:88-90,148-150`），**无额外 dex 优化步骤**
- `:66-72` 反射调用 jar 内 `com.github.catvod.spider.Init.init(Context)`
- `:76-78` 反射取 `com.github.catvod.spider.Proxy.proxy(Map)`
- `:123-125` `loader.loadClass("com.github.catvod.spider." + api.split("csp_")[1]).newInstance()` → `spider.init(context, ext)`
- `:90-99` 支持 `jar地址;md5;校验值`（md5 本身也可以是 URL，会去 GET）
- **硬约束**：jar 是预编译产物，**编译期就绑定了 `com.github.catvod.crawler.Spider`、`com.github.catvod.net.OkHttp`、`com.github.catvod.utils.*` 这些绝对类名**。要跑现成 jar，**必须原样提供这些包名/类名，不能改名**（R8 之外还需自己加 keep 规则）
- **额外要求**：`Prefers` 依赖 `Init.context()`，所以宿主 `Application.attachBaseContext` 里必须先 `Init.set(base)`（参考 `app/App.java:76-79`），否则 jar 内的 KV 存取会失效

**JS 链路**（`api/loader/JsLoader.java` + `quickjs` 模块）：
- `JsLoader.java:37` `loader.spider(api, BaseLoader.get().dex(jar))` —— **JS spider 也要求先有一个 jar**，jar 里提供 `com.github.catvod.js.Function` 桥接类（`quickjs/crawler/Spider.java:179-186`，反射失败会忽略）
- `quickjs/crawler/Spider.java:161-196` 初始化顺序：`QuickJSContext.create()` → `evaluate(assets/js/lib/http.js)` → 注入 `globalThis.local`（KV）→ `setModuleLoader(BytecodeModuleLoader)` → `Global.create(ctx, executor)`（挂 `_http/req/setTimeout/joinUrl/md5X/aesX/desX/rsaX/s2t/t2s/getPort/getProxy/js2Proxy`）→ `evaluateModule(spider 源码 + assets/js/lib/spider.js)`
- 需要随包的 JS 辅助库（`quickjs/src/main/assets/js/lib/`，共 **1,100,842 字节 = 1.05 MB**）：`cat.js` 486,451、`cheerio.min.js` 356,592、`crypto-js.js` 198,120、`gbk.js` 56,203、`http.js` 879、`similarity.js` 2,264、`spider.js` 333。启动必读 `http.js` / `spider.js`，其余按需拉取（`quickjs/utils/Module.java:22-29`，LRU 50，支持 `http(s)` / `assets` / `lib/`）
- **QuickJS 无 DOM**：HTML 解析全靠 JS 里的 `cheerio` / `cat.js`——这正是那 1 MB assets 存在的原因
- 原生库：`wang.harlon.quickjs:wrapper-android:3.2.3`，AAR **2,274,650 字节（2.17 MB）**，含 4 个 ABI 的 `libquickjs-android-wrapper.so`：arm64-v8a 1,327,232 / armeabi-v7a 946,424 / x86 1,357,880 / x86_64 1,400,768（子代理已下载 AAR 实测核对）

**Python 链路**（`api/loader/PyLoader.java` + `chaquo` 模块）：
- 依赖 `com.chaquo.python` Gradle 插件（`chaquo/build.gradle:3`），Python **3.10**，`abiFilters "arm64-v8a","armeabi-v7a"`
- `chaquo/requirements.txt`：`lxml` / `ujson` / `pyquery` / `requests` / `cachetools` / `pycryptodome` / `beautifulsoup4`
- 需要 **构建期 Python 3.10 环境**（参考项目 README 明确要求），且 Python 运行时 + 这些带 C 扩展的包会显著增大 APK

### 2.3 网盘：参考项目里没有

证据（三方独立核对）：
1. 全仓关键词搜索 —— 中文 `网盘|云盘|阿里云盘|夸克|天翼|115` 零命中；英文 `aliyun|quark|pan.baidu|cloud.189|drive.115|openlist|alist|cloudreve|netdisk|oauth|devicecode|qrlogin|refresh_token|access_token` 在 `.java` 里命中的全是词形巧合（`TypeToken` / `ClickableSpan` / `SessionToken` / `Proxy-Authorization` 等），`.py` 与 `website/` 均零命中
2. 模块清单里没有网盘模块：`app / catvod / quickjs / chaquo / hook / jianpian / thunder / tvbus / zlive / forcetech`；预编译依赖只有 `forcetech / hook / jianpian / thunder / tvbus` 这些播放/下载类 AAR
3. Room 数据库实体只有 `Keep / Site / Live / Track / Config / Device / History`（`db/AppDatabase.java:25`），**没有任何网盘实体**；且 `Site` 表实际只持久化 `key / searchable / changeable` 三列（`app/schemas/.../35.json`），`api` / `ext` / `jar` 全是 `@Ignore`（`bean/Site.java:42-57`）—— 也就是说**网盘 token 之类的东西不进数据库**
4. App 侧唯一的「凭据持久化」是给 spider 用的通用 KV：`server/process/Cache.java:21-34`（`cache_<rule>_<key>`，底层 `SharedPreferences`，见 `catvod/utils/Prefers.java:11-13`），端口由 `catvod/Proxy.java` 提供。spider 是**硬编码 HTTP 访问**它的（`chaquo/src/main/python/base/spider.py:123-148`）
5. App 里所有 `QRCode` 都是「把本机服务地址/同步参数生成二维码给手机扫」（`PushActivity.java:46` 等），**没有扫码登录网盘的代码**

结论：**参考项目不内置任何网盘驱动**。网盘（阿里云盘/夸克/115…）以及 `csp_` 站点，都是用户配置里 `spider` 字段指向的外部 jar/JS 里的 `com.github.catvod.spider.*` 类。App 提供的只是「加载器 + 调度 + 本地代理 + KV 存储」这套**运行时**。配置里 `ext` 字段叫什么（`token` / `refresh_token` / `cookie`）**完全由外部 spider 定义，参考项目不认识**。

> 这一条直接决定：想把「网盘配置」引进来，**绕不开 spider 运行时**（上表 #3），没有捷径。

### 2.4 播放地址解析（parse）：5 种类型，其中一种必须 WebView

`ParseJob.java:96-114` 按 `parse.getType()` 分支：

| type | 做法 | 可移植性 |
|---|---|---|
| 0 | `startWeb(...)` → `CustomWebView` 嗅探（`:185-191`，且 `WebViewUtil.support()` 为假直接失败） | ❌ 依赖 Android WebView + Activity 生命周期 |
| 1 | JSON API：`OkHttp` 请求 `parse.url + 视频地址`，取 `url`/`data.url`（`:116-124`） | ✅ 纯 Dart 可做 |
| 2 | JAR 扩展解析：反射 jar 内 `com.github.catvod.parser.Json<Key>.parse(...)`（`JarLoader.java:140-144`） | ⚠️ 要 jar 运行时 |
| 3 | JAR 混合解析：`com.github.catvod.parser.Mix<Key>.parse(...)` | ⚠️ 同上 |
| 4 | 并发：所有 type 1 解析器并行 + 一个 type 0 WebView（`CountDownLatch`，`:138-147`） | ⚠️ 含 WebView |

WebView 侧的硬绑定（`ui/custom/CustomWebView.java`）：靠 `shouldInterceptRequest` 嗅探（`:120-129`）、`onPageFinished` 注入 click/规则脚本（`:132-136`）、遇 Cloudflare 挑战要弹 `WebDialog` 且**显式判 `App.activity() == null` 就放弃**（`:156-161`）。多解析并发时靠本地服务生成的 `/parse?jxs=...` 多 iframe 页面（`assets/parse.html:12-23`）。

`utils/Sniffer.java` 本身是**纯静态判定**（正则 + `RuleConfig` 的 `exclude/regex`，`:26-54`），不依赖 WebView，可移植；但它的调用方在 WebView 里。它还被用来决定要不要二次解析：`api/SiteApi.java:184`。

### 2.5 本地 HTTP 服务：不是「头部注入器」，但外部 spider 会硬编码访问它

参考项目 `app/server/`（**NanoHTTPD 2.3.1**，`gradle/libs.versions.toml:42,96`）是一个**单例本地 HTTP 服务**，端口从 9978 起自增到 9998，启动时机是**配置加载时**而非播放时（`api/config/BaseConfig.java:47-56` 的 `ensureLoaded` 里 `Server.get().start()`）。

路由（`server/Nano.java:34-43,62-70`）：`Action / Cache / Image / Local / Media / Parse / Proxy`，兜底是静态资源。

**必须先纠正一个常见误解**：这个本地服务**不做 Referer/UA 注入，也不做 m3u8 重写**。真实分工是：

| 职责 | 实际位置 |
|---|---|
| 头部注入（Referer/UA/Cookie） | 播放器的数据源：`player/exo/ExoMediaSourceFactory.java:72-75,116-117`（`setDefaultRequestProperties`） |
| 302 跟随 | App 手动跟：`catvod/net/OkHttp.java:193` 全局 `followRedirects(false)` + `catvod/net/ProxyRedirectInterceptor.java:30-55,64-83` 手写重定向循环 |
| m3u8 重写 / 加密流解密 / 拼 302 后真实地址 | **spider 自己的 `proxy()`**，本地服务只做透传 |

`/proxy` 的语义（`server/process/Proxy.java:27-46`）：把 query + header 全塞进 `params`，交给 `BaseLoader.get().proxy(params)`（`:79-84` 按 `siteKey`/`do=js`/`do=py` 分派到对应 spider 的 `proxy`），返回值是固定 4 元组 `[status, mime, InputStream, headers]`，由 `NanoHTTPD.newChunkedResponse` 转成 HTTP 响应。

**为什么不能只靠 Dart 侧顶替**（关键约束）：
- JS / Python spider 里的代理地址是**硬编码 HTTP 访问**：
  - `quickjs/method/Global.java:106-113`：`getProxy()` → `Proxy.getUrl(local) + "?do=js"`；`js2Proxy(...)` 再拼 `&from=catvod&siteType=&siteKey=&header=&url=`
  - `chaquo/src/main/python/base/spider.py:114-115,123-149`：`getProxyUrl()` → `...?do=py`；`getCache/setCache/delCache` → `http://127.0.0.1:{port}/cache?do=get|set|del`
- 端口存在 native 侧（`catvod/Proxy.java:9-15` 的 `Proxy.getPort()`），并会**注入 JS 沙箱**。也就是说：**`/cache` 这个 KV 端点必须由 Java 侧以同形提供**，否则依赖它的 spider（含网盘类）拿不到 token 持久化；`/proxy` 也必须先由 native 侧承接再决定怎么落地
- 其余端点可砍：`Media / Parse / Image / Action` 都绑播放器状态或 WebView 嗅探（`Local` 提供文件 + Range/ETag/206，视需要保留）

**本项目已有同型能力**（可复用其「回环代理 + 头注入 + Range」范式，但要落在 native 侧才能满足上面的硬编码端点）：
- `lib/services/network/network_streaming_proxy.dart:1-7,122` —— `dart:io HttpServer.bind(loopbackIPv4, 0)`，远端文件转 `127.0.0.1` 无凭据 URL，支持 Range/HEAD + 测速
- `lib/services/bilibili/bili_stream_proxy.dart:1-11,100-114` —— 同类代理，注入 `Referer`/`User-Agent`
- `lib/services/cast/lan_media_server.dart:144-224` —— Range/206/CORS

### 2.6 播放器耦合度：低，且头部注入已有现成通道

- 参考项目的 extractor（`player/extractor/`）分两类：
  - **纯逻辑可移植**：`Video`（剥 `video://`）、`Strm`（读 `.strm` 首行）、`Source`（聚合器）
  - **必须 Android / Activity / so**：`Force`（绑厂商 IPTV 服务）、`JianPian`（`com.p2p.P2PClass` JNI）、`Thunder`（迅雷 so）、`TVBus`（`TVCore` so）、`Push`（跳 `VideoActivity`）、`YouTube`（NewPipeExtractor 的 Java 库）
  - 配套预编译库体积（仓库内实测）：`thunder-release.aar` 4.32 MB、`jianpian-release.aar` 2.64 MB、`forcetech-release.aar` 2.61 MB、`tvbus-release.aar` 0.02 MB、`hook-release.aar` 0.01 MB；各模块 `jniLibs` 还有 thunder/jianpian/zlive 的 .so —— **这些与本项目 mpv 路线无关，不需要引入**
- 本项目播放在线地址：`PlayerPage(path:, title:, ...)`（`lib/pages/player/player_page.dart:108-142`）**没有 header 参数**
- **但头部注入不需要动播放页**：本项目魔改过的 media_kit **已支持** `Media(url, httpHeaders: {...})` → mpv `http-header-fields`（`third_party/media_kit/lib/src/player/native/player/real.dart:2145-2168`；字段定义 `lib/src/models/media/media_native.dart:85-88,107-119`）。这是把 TVBox `Result.header` 送进 mpv 的最省事通道（见 §4.3）
- 现有在线链路里，只有 B 站走的是「本地代理注入头」：`lib/pages/player/player_page.dart:850-866` + `bili_stream_proxy.dart`；普通直链（`lib/pages/home/open_link_dialog.dart` → `home_page.dart:451-462`）不带任何头

---

## 3. 三条路线

### 路线 A：只做 HTTP 接口（type 0/1/4）—— 纯 Dart

**做什么**：Dart 侧实现配置拉取/解析、站点列表、分类/详情/搜索/播放链接获取、`parse` type 1（JSON 解析接口）。

**改动面**：全部在 `lib/`（新增 `lib/services/content/` 域 + `lib/pages/content/` 页面 + 设置页入口）。**零原生改动、零新依赖、体积零增加。**

**能拿到**：`type 0`（XML/CMS）、`type 1`（JSON/CMS）、`type 4`（扩展 HTTP）、`parse type 1`。这类配置在 TVBox 生态里占比不小，且是最"干净"的一类。

**拿不到**：所有 `type 3`（`csp_`/JS/PY）、全部网盘、`parse type 0/2/3/4`、`/proxy` 类能力（不需要）。

**优点**：可验证、可回滚、不碰原生；对 GPL 与体积无影响。
**缺点**：TVBox 用户最看重的「一条配置吃遍全网」体验，主要靠 type 3 spider，A 路线撑不起来。

### 路线 B（推荐起点）：配置解析 + Spider 运行时（jar + JS）

**做什么**：把 `catvod` 模块与 jar 加载器搬进本项目 `android/`，加一个 JS 运行时，用 MethodChannel 暴露给 Dart。

**新增原生模块**：

| 模块 | 来源 | 说明 |
|---|---|---|
| `catvod` | `参考项目/catvod`（28 文件 2,267 行） | **必须原样保留包名** `com.github.catvod.*` |
| jar 加载器 | `app/api/loader/JarLoader.java`（171 行） | `DexClassLoader` + `cacheDir/jar` + `;md5;` 校验 + 下载 |
| JS 运行时 | `参考项目/quickjs`（845 行 + 1.05 MB assets） | 依赖 `wang.harlon.quickjs:wrapper-android:3.2.3` |
| **本地 HTTP 服务** | `app/server/{Nano,Server}.java` + `process/{Proxy,Cache,Local}.java` | **硬依赖**：外部 spider 硬编码访问 `/proxy?do=js\|py` 与 `/cache?do=get\|set\|del`，端口由 native 侧 `catvod/Proxy.java` 保存并注入 JS 沙箱 |
| 配置解析 | `app/api/config/{BaseConfig,VodConfig}.java` 等 | **可改写**：建议只搬「json → 模型」（`Decoder` + `Site/Result/Class/Filter/Vod` + `ExtAdapter`），整块 `VodConfig` 绑了 Room/EventBus 不建议搬 |

**附加硬约束**：宿主 `Application.attachBaseContext` 必须先 `Init.set(base)`（参考 `app/App.java:76-79`），否则 `catvod` 的 `Prefers`（`Init.context()`）与 jar 内 KV 存取失效。

**MethodChannel 接口设计（建议）**：

```
通道：moumou/tvbox（新通道，不动现有 moumou/video_info）
  loadConfig({url})            -> {sites:[...], parses:[...], flags:[...]}
  homeContent({key, filter})   -> Result JSON
  categoryContent({key,tid,pg,filter,extend}) -> Result JSON
  detailContent({key,id})      -> Result JSON
  searchContent({key,wd,quick,pg}) -> Result JSON
  playerContent({key,flag,id}) -> {url, header:{...}, parse:0|1, flag}
  proxyUrl({...params})        -> 本地代理 URL（或 null）
  clearLoader({key})           -> void
```

**Dart 侧新增**：内容源域（配置/站点/列表/详情/搜索）、内容浏览页、起播适配（把 `Result.header` 注入播放）。

**体积代价**：
- `catvod` 依赖树（`catvod/build.gradle:31-40`）：okhttp 5.5.0 + gson + guava + brotli + juniversalchardet + **sardine（WebDAV）** + **smbj（SMB）** + zxing-core + androidx preference/startup + logger + desugar_jdk_libs_nio。**经 R8 裁剪后估 +2~4 MB**（未实测；若确认不需要 SMB/WebDAV，可试删 smbj/sardine）
- quickjs：AAR 实测 **+2.17 MB（4 ABI 全包，若只留 arm64-v8a + armeabi-v7a 会小一截）** + JS assets **+1.05 MB**
- NanoHTTPD 2.3.1：约 60 KB 级

**能拿到**：`type 3` 全部（`csp_` JAR 站点 + JS 站点）、**网盘**（只要来源 jar 里有对应 spider）、`parse type 2/3`、`/proxy` 与 `/cache` 端点。
**拿不到**：Python spider（`api` 以 `.py` 结尾的站点）、`parse type 0`（WebView 嗅探）。

**主要风险**：
1. **三大版本差异未验证**：本项目 AGP **9.0.1** / Kotlin 2.3.20 / Java **17** / compileSdk **36**（`android/settings.gradle.kts:22-23`、`android/app/build.gradle.kts:19,22-25,71`）；参考项目 AGP **9.3.1** / Java **21** / compileSdk **37**（`gradle/libs.versions.toml:2-5`、`app/build.gradle:78-81`）。`catvod` 开了 `coreLibraryDesugaringEnabled`（`catvod/build.gradle:23`），本项目未开。**Java 21 → 17、compileSdk 37 → 36 能否平滑降级，只能试编译才知道**
2. **jar 兼容性只能实测**：现成 spider jar 是否用了我们没提供的类（`com.github.catvod.bean.*`、`utils.*`、`R`、`BuildConfig`），必须拿真实样本试
3. **第三方 jar 的内置依赖冲突**：某些 jar 自带 okhttp/gson 副本，可能与主工程版本冲突
4. proguard/R8：必须 keep `com.github.catvod.crawler.**`、`com.github.catvod.spider.**`、被反射加载的类

### 路线 C：全量（+ Python spider + WebView 解析）

在 B 之上再加：

- **Python**：`chaquo` 插件 + Python 3.10 + `lxml/ujson/pyquery/requests/cachetools/pycryptodome/beautifulsoup4`。代价：构建环境要装 Python 3.10；APK 增加显著（Python 运行时 + 带 C 扩展的包，**具体数值我没有核实**）；chaquo 是商业授权分层的插件，需确认许可
- **WebView 解析（parse type 0）**：Flutter 侧需引入 `webview_flutter` 或写原生 `AndroidView` 平台视图，把 `parse.html` + `rules`（click/script/regex）逻辑搬过来，还要处理「不可见 WebView 嗅探 + 生命周期 + 多 WebView 并发」（参考项目 `ParseJob` 用线程池并发开多个 `CustomWebView`）。**这是三条里最脏的一块**

**结论**：C 路线只有在「确认有实际需要的 Python/WebView 源」时才值得做；否则先做 B 更合理。

---

## 4. 与本项目现有能力的对接

### 4.1 不需要重造的部分

| 需求 | 本项目已有的等价物 |
|---|---|
| 本地回环流代理（Range/HEAD/测速） | `lib/services/network/network_streaming_proxy.dart`（Dart）／native 侧仍需自建 `/proxy` `/cache` |
| 代理 + 请求头注入（Referer/UA/Cookie） | `lib/services/bilibili/bili_stream_proxy.dart:150-156` 的 `registerStreams(headers:)` |
| **播放器侧的请求头** | 魔改 media_kit 的 `Media(httpHeaders:)` → mpv `http-header-fields`（`third_party/media_kit/lib/src/player/native/player/real.dart:2145-2168`） |
| 原生桥范式 | `MainActivity.kt:147-605` 的 `moumou/video_info` 单通道（含「后台线程 + runOnUiThread 回结果」写法、`invokeMethod` 反向推送） |
| 播放页入口扩展 | `PlayerPage`（`lib/pages/player/player_page.dart:108-142`）已是多来源结构（本地/网络存储/B 站） |
| 加密存储 | `flutter_secure_storage`（B 站 Cookie / 网络存储密码已在用），可存内容源账号 |

### 4.2 建议的架构（路线 B）

```
Dart（lib/services/content/）              原生（android/ 新模块）
  ContentConfigService  ──┐                 ┌─ Application：Init.set(ctx)（必须）
  ContentSiteService      ├─ MethodChannel ─→ TvboxBridge.kt
  ContentPlayResolver     │  'moumou/tvbox'  ├─ catvod（原样包名 com.github.catvod.*）
                          │                  ├─ JarLoader（DexClassLoader + cacheDir/jar）
  PlayerPage ← header 注入 ┘                  ├─ QuickJs 运行时（assets/js/lib/*.js）
                                             └─ NanoHTTPD 本地服务（/proxy、/cache、/file）
                                                  ↑ 外部 spider 硬编码访问它
```

- 配置解析放 Dart 还是原生：**建议放 Dart**（配置是 JSON，改起来快、能复用现有设置持久化与 UI），只把 `spider` jar 地址与 `sites[].{key,api,ext,jar}` 下发给原生。**但 `/cache` KV 端点必须由原生提供**（spider 硬编码）
- `loadConfig` 若要完全对齐参考项目行为，注意 `Decoder`（`api/Decoder.java:22-79`）：`**` 前缀 → base64、`2423` → AES-CBC、`__JS1__/__JS2__` 相对路径修正
- `playerContent` 返回的 `header`：优先用 `Media(httpHeaders:)` 直接注入 mpv；只有 spider 要求走它自己的 `proxy()`（返回代理 URL）时，才必须经过 `/proxy`

### 4.3 起播链路的三种接法

| 接法 | 做法 | 适用 |
|---|---|---|
| 直连 + header | `Media(url, httpHeaders: Result.header)` 交给 mpv | 简单直链、单层 302（最常见） |
| spider 自带代理 | `Result.url` 本身就是 `http://127.0.0.1:<port>/proxy?...`，直接播 | spider 用 `proxy()` 做 m3u8 重写/解密 |
| 自建回环代理 | 复用 `BiliStreamProxy` 范式，注册带 header 的代理 URL | mpv 直连失败、需要改写播放列表 |

---

## 5. 工作量与风险总表

| 项 | 路线 A | 路线 B | 路线 C（含 Python+WebView） |
|---|---|---|---|
| 原生代码 | 0 | ~3,000 行（catvod 2,267 + 加载器 + 桥） | + chaquo 292 行 + WebView 解析逻辑 |
| Dart 代码 | 中（配置/站点/列表/详情/搜索/起播） | 中（同 A，但请求走原生） | 中 |
| 新依赖 | 0 | okhttp/gson/guava/smbj/... + quickjs + NanoHTTPD | + chaquo + Python 包 |
| 体积 | 0 | **实测部分**：quickjs AAR 2.17 MB + JS assets 1.05 MB + NanoHTTPD ~0.06 MB；**估算部分**：catvod 依赖树 R8 后 +2~4 MB | 再 + Python 运行时与 7 个 pip 包（**数值未核实**） |
| 构建环境 | 不变 | 不变（但要试编译验证 Java 17/compileSdk 36） | **需要 Python 3.10 构建环境** |
| 能拿到的站点 | type 0/1/4 | 全部 type 3（jar/JS） | 全部 |
| 网盘 | ❌ | ✅（取决于来源 jar） | ✅ |
| 解析 | 仅 type 1 | type 1/2/3 | 全部 |
| 主要风险 | 覆盖不足 | jar 兼容性、版本降级、R8 keep | 构建环境、体积、chaquo 许可、WebView 复杂度 |

---

## 6. 分阶段建议（若最终选路线 B）

1. **P0 试编译**：只把 `catvod` 作为 library module 加入 `android/`，改 Java 17 / compileSdk 36 对齐，跑一次编译。**这一步的目的就是验证 §3-B 的风险 1**。不通过就回到路线 A 或调整版本。
2. **P1 桥 + 配置**：`Application` 里 `Init.set(this)`；新增 `TvboxBridge.kt` + `moumou/tvbox` 通道，先只做 `loadConfig` + `detailContent`（HTTP 站点走原生、type 3 走 spider），验证 jar 加载与类名兼容（§3-B 风险 2）。
3. **P2 本地服务**：native 侧起 NanoHTTPD，先只实装 `/proxy` 与 `/cache`（`/cache` 是外部 spider 的硬需求），把端口塞进 `catvod/Proxy`。
4. **P3 起播**：接 `playerContent` → `Media(httpHeaders:)`；跑通一个真实 jar 站点的完整「分类 → 详情 → 播放」。
5. **P4 内容源 UI**：新增内容浏览域页面（与本地媒体库并列），并入首页速拨。
6. **P5（可选）**：JS 站点（接 quickjs）；再评估 Python 与 WebView 解析是否真的需要。

---

## 7. 非技术风险（用户已知悉，此处只做如实记录）

- 参考项目 `LICENSE.md` 为 **GPL-3.0**，本项目 `LICENSE` 也是 **GPL-3.0** —— 许可层面兼容，但引入代码需在 `THIRD_PARTY_NOTICES.md` 登记（catvod、quickjs wrapper 等）
- TVBox 生态的 spider 与配置源普遍涉及**未授权影视内容与网盘直链**，且该生态的默认预期是「App 不内置任何内容源，全部由用户配置」。引入后本项目的定位与合规风险会变化
- 参考项目 README 自己也写明：「**App 本身不內建或提供任何內容來源**」——即能力与内容源是分离的，引入能力不等于引入内容

---

## 8. 不确定 / 没查到的部分（必须实测才能定论）

1. **未做任何编译验证**（AGENTS.md 禁止私自编译）。因此 Java 21→17、compileSdk 37→36、AGP 9.3.1→9.0.1 的降级可行性、以及 `catvod` 能否直接编译通过，**都只是分析，不是结论**。
2. **chaquo 的实际体积**：本机无 Gradle 缓存、参考项目无 `build/` 产物；Chaquo 以 Gradle 插件分发、GitHub Release 无二进制附件、官方文档未给体积数字 → **不知道**，需一次真实构建后看 APK 内 `lib/*/libpython3.10.so` 与 `assets/chaquopy/*`。
   （quickjs AAR 与 JS assets 的体积已实测：2,274,650 + 1,100,842 字节。）
3. **第三方 spider jar 的兼容性**：没有样本 jar，无法验证类名依赖、dex 版本、R8 keep 需求。
4. `Site.type` 在实际配置中若写成字符串（`"type": "3"`）是否被 Gson 正确解析 —— 未实测。
5. **Chaquopy 与 Flutter Gradle 插件能否共存**：官方约束是「全 App 只能一个模块应用该插件」（AGP 上限 9.2.x，本项目 9.0.1 在范围内），但与 `dev.flutter.flutter-gradle-plugin` 的实测共存情况**未验证**。
6. 参考项目的 `app/src/leanback`、`app/src/mobile` 两个 flavor 的 UI 未细读（与能力移植无关）。
7. 参考项目里 `thunder` / `jianpian` / `tvbus` / `zlive` / `forcetech` 这些预编译库的内部实现未读（判断为与 mpv 路线无关，故未深入）。
8. 未评估「配置仓（`urls` / Depot）」多配置订阅与切换的迁移成本（`VodConfig.java:133-140`）。
9. `catvod` 里 `net/interceptor/{AuthInterceptor,RequestInterceptor,ResponseInterceptor}` 具体注入哪些头未逐行读；`OkHttp.java:193` 关掉自动重定向、由 `ProxyRedirectInterceptor` 手写重定向循环这一点已确认，但细节未展开。
