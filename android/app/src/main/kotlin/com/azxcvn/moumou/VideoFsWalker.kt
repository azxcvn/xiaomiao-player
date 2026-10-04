package com.azxcvn.moumou

import android.content.Context
import android.os.SystemClock
import android.util.Log
import java.io.File
import java.util.Locale

private const val TAG = "FsVideoWalker"

/**
 * 父目录（`/a/b/c.mp4` → `/a/b`）。
 *
 * 放文件级而不是 [FsVideoWalker] 的成员：索引 [FsVideoIndex] 按父目录给视频分组，
 * 也要用它（原来写成成员函数 → `FsVideoIndex` 里 Unresolved reference，编译不过）。
 */
private fun parentOf(path: String): String {
    val index = path.lastIndexOf('/')
    return if (index <= 0) "/" else path.substring(0, index)
}

/** 文件名（取路径最后一段） */
private fun nameOf(path: String): String = path.substringAfterLast('/')

/**
 * 整盘文件系统补扫的持久化索引（`filesDir/fs_video_index_<key>.tsv`）。
 *
 * 为什么要有它（用户反馈：开了「扫描 .nomedia / 隐藏文件夹」后进 App 转圈十几秒）：
 * MediaStore 覆盖不到的位置只能自己递归文件系统，而递归成本跟**整个存储上有多少
 * 目录和文件**成正比、跟视频库大小无关。原来每次进 App 都从零整盘递归一遍，用户
 * 存储上几十万个文件时就是十几秒。
 *
 * 这里把「已经走过哪些目录（lastScanned + 目录指纹）」和「在那里找到过哪些视频」
 * 记下来：
 * - 视频直接从索引里出，不再重新走一遍树；
 * - 目录按 [FsVideoWalker] 的重扫间隔旧的重扫（最旧的优先），一轮没扫完就把
 *   待扫队列（frontier）存下来，下次接着扫；
 * - 指纹是目录自身的 mtime，用来**提前**发现「刚扫完又被改」的目录（见
 *   [probeChangedDirs]）；它不改变原来的时间戳重扫规则。
 *
 * 格式：TSV，首行版本号，其后每行 `类型 \t 字段…`（目录行多一列指纹，缺列读作 0）。
 * 路径里含制表符/换行的条目不入索引（Android 上极罕见；这类条目仍然会在**当轮**
 * 扫描结果里出现，只是下次不记得）。
 * 文件损坏 / 版本不符 / 扫描条件（key）变化 → 整体作废重扫，不会读到脏数据。
 */
internal class FsVideoIndex(private val file: File) {
    private companion object {
        const val HEADER = "moumou-fs-index v1"
        const val TYPE_KEY = "key"
        const val TYPE_DIR = "d"
        const val TYPE_VIDEO = "v"
        const val TYPE_FRONTIER = "f"
        const val MAX_DIRS = 60000
        const val MAX_VIDEO_DIRS = 60000
        const val MAX_FRONTIER = 20000
    }

    /** 扫描条件指纹：不匹配说明开关/名单变了，索引直接作废 */
    var key: String = ""

    /**
     * 目录 → 记录。
     *
     * 索引格式仍然是 `v1`（**不升版本**：老索引缺指纹列，读成 0 = 指纹未知，
     * 探针跳过它、由 15 分钟时间戳照旧兜住；升版本会让所有人的索引作废重扫一遍）。
     */
    val dirs = LinkedHashMap<String, FsDirEntry>()

    /** 目录 → 该目录下的视频（索引里的唯一视频来源） */
    val videos = LinkedHashMap<String, MutableList<FsVideoEntry>>()

    /** 上次没扫完、下次要接着扫的目录 */
    val frontier = LinkedHashSet<String>()

    fun hasDir(path: String): Boolean = dirs.containsKey(path)

    /** 目录已不存在 / 被规则剪掉：连同它记下的视频一起摘掉 */
    fun removeDir(path: String) {
        dirs.remove(path)
        videos.remove(path)
    }

    /**
     * 摘掉 [path] 自身及整棵子树（文件操作改动过的地方；[path] 是文件时只可能
     * 影响它所在目录的列表，这里不会误伤 —— 文件路径不会是任何目录记录的前缀）。
     *
     * 返回是否真的摘掉了东西（调用方据此决定要不要落盘）。
     */
    fun removeSubtree(path: String): Boolean {
        if (path.isEmpty()) return false
        val prefix = "$path/"
        val removedDirs = dirs.keys.removeAll { it == path || it.startsWith(prefix) }
        val removedVideos = videos.keys.removeAll { it == path || it.startsWith(prefix) }
        return removedDirs || removedVideos
    }

    /**
     * 记下一个目录本轮的结果（[found] 为空表示这个目录现在没有视频，覆盖旧记录）。
     *
     * [fingerprint] 是**列目录之前**取的目录自身 mtime（不是列完再取：列目录期间
     * 刚好被改动时，存下「旧时间」才能让下一次探针把这次改动认出来）。取不到
     * （stat 失败）记 0 = 指纹未知，探针会跳过它。
     */
    fun applyDir(
        path: String,
        lastScannedMs: Long,
        fingerprint: Long,
        found: List<FsVideoEntry>,
    ) {
        dirs[path] = FsDirEntry(lastScannedMs, fingerprint)
        if (found.isEmpty()) {
            videos.remove(path)
        } else {
            videos[path] = ArrayList(found)
        }
    }

    /** 早于 [scannedBeforeMs] 扫过的目录，最旧的先返回（重扫用） */
    fun staleDirs(scannedBeforeMs: Long, limit: Int): List<String> {
        val out = ArrayList<String>()
        val sorted = dirs.entries.sortedBy { it.value.lastScannedMs }
        for (entry in sorted) {
            if (entry.value.lastScannedMs > scannedBeforeMs) break
            out.add(entry.key)
            if (out.size >= limit) break
        }
        return out
    }

    /**
     * 变更探针（P1-2）：对**还没到重扫间隔**的目录做一次 stat，目录自身 mtime
     * 和记下的指纹不一致的返回给调用方 —— 说明这个目录的条目被增删/改名过。
     *
     * 为什么用「目录 mtime」而不是参考项目 mpvRx 的指纹（目录 mtime + 条目数 +
     * 每条的 name/类型/length/mtime 混合哈希）：算 mpvRx 那种指纹**本身就要**
     * `listFiles()` + 逐条目 stat（已核对其源码），只省下「重算聚合计数」——
     * 而小喵的索引存的是「目录 → 视频列表」，没有聚合计数要重算，照抄等于付了
     * 全部 stat 却什么都省不下；而且它的 15 分钟重扫仍然只按时间戳调度，指纹
     * **不参与调度**，所以「时间戳法会漏掉刚扫完就被改」这个毛病它也没有解决。
     *
     * 所以这里把指纹（一次 stat）用在**提前发现变更**上：探到了就立刻重列该目录，
     * 不必等 15 分钟。15 分钟的时间戳重扫照旧保留 —— 它兜的是「原地改写文件」
     * （目录 mtime 不变）这类探针看不到的变化。
     *
     * 只探 [maxCount] 个、且不超过 [deadlineMs]：先探「刚扫过、离下次重扫最远」的
     * （按 lastScanned 倒序），没探到的那些本来就更接近重扫间隔，由时间戳规则兜。
     * 探针**不修改指纹**（只有真正列过目录的 [applyDir] 才更新），否则会把「有变更」
     * 这件事自己抹掉。
     */
    fun probeChangedDirs(deadlineMs: Long, maxCount: Int): List<String> {
        if (maxCount <= 0) return emptyList()
        val out = ArrayList<String>()
        val candidates = dirs.entries
            .filter { it.value.fingerprint != 0L }
            .sortedByDescending { it.value.lastScannedMs }
        for (entry in candidates) {
            if (out.size >= maxCount) break
            if (SystemClock.elapsedRealtime() > deadlineMs) break
            val dir = File(entry.key)
            if (!dir.isDirectory) {
                // 目录已经没了：交给这一轮 BFS 走一遍 removeDir（顺带把它的视频摘掉）
                out.add(entry.key)
                continue
            }
            if (dir.lastModified() != entry.value.fingerprint) out.add(entry.key)
        }
        return out
    }

    /**
     * 已经顶到容量上限的部分（没顶到返回 null）。
     *
     * 上限存在的意义是「宁可截断也不能让索引撑爆内存」，但**截断了必须能看见** ——
     * 原来只是静默地少记几条，用户看到的症状是「有些文件夹永远不出现」，从日志
     * 上一眼看不出来（对齐 mpvRx 的 `Paused ... with N directories queued`）。
     */
    fun capacityNote(): String? {
        val parts = ArrayList<String>(3)
        if (dirs.size >= MAX_DIRS) parts.add("目录=${dirs.size}/$MAX_DIRS")
        if (videos.size >= MAX_VIDEO_DIRS) parts.add("视频目录=${videos.size}/$MAX_VIDEO_DIRS")
        if (frontier.size >= MAX_FRONTIER) parts.add("待扫队列=${frontier.size}/$MAX_FRONTIER")
        return if (parts.isEmpty()) null else parts.joinToString("、")
    }

    /** 载入索引；[expectedKey] 不匹配或文件不可用 → 置空（下次全量重建） */
    fun load(expectedKey: String) {
        dirs.clear()
        videos.clear()
        frontier.clear()
        key = ""
        if (!file.isFile) return
        // 顶到上限被丢掉的条数：静默截断会表现成「有些文件夹永远不出现」，必须留痕
        var droppedDirs = 0
        var droppedVideoDirs = 0
        var droppedFrontier = 0
        try {
            file.bufferedReader(Charsets.UTF_8).use { reader ->
                if (reader.readLine() != HEADER) return
                while (true) {
                    val line = reader.readLine() ?: break
                    if (line.isEmpty()) continue
                    val parts = line.split('\t')
                    when (parts[0]) {
                        TYPE_KEY -> key = parts.getOrNull(1) ?: ""
                        TYPE_DIR -> if (parts.size >= 3) {
                            if (dirs.size < MAX_DIRS) {
                                dirs[parts[1]] = FsDirEntry(
                                    lastScannedMs = parts[2].toLongOrNull() ?: 0L,
                                    // 老索引没有这一列 → 0 = 指纹未知，探针跳过它
                                    fingerprint = parts.getOrNull(3)?.toLongOrNull() ?: 0L,
                                )
                            } else {
                                droppedDirs++
                            }
                        }
                        TYPE_VIDEO -> if (parts.size >= 5) {
                            if (videos.size < MAX_VIDEO_DIRS) {
                                val path = parts[1]
                                videos.getOrPut(parentOf(path)) { ArrayList() }.add(
                                    FsVideoEntry(
                                        path = path,
                                        size = parts[2].toLongOrNull() ?: 0L,
                                        modifiedMs = parts[3].toLongOrNull() ?: 0L,
                                        durationMs = parts[4].toLongOrNull() ?: 0L,
                                    )
                                )
                            } else {
                                droppedVideoDirs++
                            }
                        }
                        TYPE_FRONTIER -> if (parts.size >= 2) {
                            if (frontier.size < MAX_FRONTIER) {
                                frontier.add(parts[1])
                            } else {
                                droppedFrontier++
                            }
                        }
                    }
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "fs index load failed: ${e.message}")
            clear()
            return
        }
        if (droppedDirs > 0 || droppedVideoDirs > 0 || droppedFrontier > 0) {
            Log.w(
                TAG,
                "fs index load: 顶到上限被截断 —— 丢弃目录=$droppedDirs " +
                    "丢弃视频记录=$droppedVideoDirs 丢弃待扫目录=$droppedFrontier " +
                    "（上限 目录=$MAX_DIRS 视频目录=$MAX_VIDEO_DIRS 待扫=$MAX_FRONTIER）",
            )
        }
        if (key != expectedKey) clear()
    }

    /** 写索引：先写临时文件再改名，写坏也不会留下半截索引；空索引不落盘 */
    fun save() {
        if (dirs.isEmpty() && videos.isEmpty() && frontier.isEmpty()) {
            clear()
            return
        }
        if (file.parentFile?.isDirectory != true) return
        val tmp = File(file.absolutePath + ".tmp")
        try {
            tmp.bufferedWriter(Charsets.UTF_8).use { writer ->
                writer.write(HEADER)
                writer.newLine()
                writer.write("$TYPE_KEY\t$key")
                writer.newLine()
                for ((path, dir) in dirs) {
                    writer.write("$TYPE_DIR\t$path\t${dir.lastScannedMs}\t${dir.fingerprint}")
                    writer.newLine()
                }
                for (list in videos.values) {
                    for (v in list) {
                        writer.write("$TYPE_VIDEO\t${v.path}\t${v.size}\t${v.modifiedMs}\t${v.durationMs}")
                        writer.newLine()
                    }
                }
                for (path in frontier) {
                    writer.write("$TYPE_FRONTIER\t$path")
                    writer.newLine()
                }
            }
            if (!tmp.renameTo(file)) {
                file.delete()
                if (!tmp.renameTo(file)) {
                    file.writeText(tmp.readText(), Charsets.UTF_8)
                    tmp.delete()
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "fs index save failed: ${e.message}")
            try {
                tmp.delete()
            } catch (_: Exception) {
            }
        }
    }

    fun clear() {
        dirs.clear()
        videos.clear()
        frontier.clear()
        key = ""
        try {
            file.delete()
        } catch (_: Exception) {
        }
    }
}

/**
 * 索引里的一条目录记录。
 *
 * [fingerprint] = 上次**列这个目录之前**取到的目录自身 mtime（列目录期间有增删/
 * 改名，mtime 就会变；0 = 没取到 / 老索引没这一列，探针跳过）。
 */
internal class FsDirEntry(
    var lastScannedMs: Long,
    var fingerprint: Long,
)

/**
 * 索引/结果里的一条视频。
 *
 * [durationMs]：`> 0` = 已知时长（历史抽到的 / 卡片兜底拿到的，会跨轮复用）；
 * `0` = 未知（补扫本身不抽时长，交给卡片按需懒加载）。
 */
internal class FsVideoEntry(
    val path: String,
    val size: Long,
    val modifiedMs: Long,
    val durationMs: Long,
)

/** 一次整盘补扫的请求参数（MainActivity.getVideos 组装） */
internal class FsScanRequest(
    /** Dart 侧本次扫描的代次：原样回传，Dart 只认最新代次的增量推送 */
    val scanId: Int,
    val includeNoMedia: Boolean,
    val includeHidden: Boolean,
    /** 白名单目录（空 = 不剪枝）；目录只有「在白名单内」或「是白名单的祖先」才会进 */
    val allowedPrefixes: List<String>,
    /** 黑名单目录（命中即整棵不进） */
    val blockedPrefixes: List<String>,
    /** 用户主动刷新（下拉刷新 / 一键清缓存）：**忽略重扫间隔重新走一遍**，但不清索引 */
    val forceRescan: Boolean,
    /** 文件操作改动过的路径（目录含整棵子树）：从索引摘掉并优先重扫，其余目录原地保留 */
    val invalidatePaths: List<String>,
    val primaryRoot: File?,
    val externalRoots: List<File>,
    /**
     * MediaStore 这一轮**已经给过**的路径（绝对路径）。
     *
     * 补扫索引只负责「系统看不到的东西」，这些文件**不再记进索引**：同一个文件在
     * MediaStore 与索引里各存一份是双份内存 + 双份落盘，取用时还会被 `getVideos`
     * 按「MediaStore 优先」丢掉 —— 纯死重量。对「大容量外置卡 + 普通库」的用户，
     * 这一条能把索引从「整张卡的文件表」缩到「几乎只剩系统看不到的那些文件」。
     *
     * 传的是**本次查询确实返回过**的集合，所以「MediaStore 一时查不到、靠索引兜底」
     * 的能力不受影响：查不到就不会进这个集合，补扫照旧把那一条存下来。
     *
     * ⚠️ 后台那一轮会读这个集合（`FsVideoWalker.walkInBackground`），交给它之后
     * **就不能再改动这个集合**。
     */
    val mediaStorePaths: Set<String>,
)

/** 扫描根的属性 */
private class FsRootInfo(
    val path: String,
    val isPrimary: Boolean,
    val maxDepth: Int,
)

/**
 * 整盘文件系统补扫：**带预算、带跳过名单、带黑白名单剪枝、带续扫**的 BFS。
 *
 * 与参考项目 mpvRx 的做法对齐（`FolderViewScanner` + `DirectoryScanDao`）：
 * 1. **只枚举、不解析**：一轮里只做目录列举 + `length()` + `lastModified()`，
 *    **不开容器抽时长**（抽取交给卡片按需懒加载）—— 两者塞进同一个预算时，
 *    抽取（贵）会把枚举（便宜）饿死，导致「每轮只能多枚举一个目录」；同时
 *    **不重复记 MediaStore 已经给过的文件**（`FsScanRequest.mediaStorePaths`），
 *    索引只留系统看不到的那部分；
 * 2. **跳过名单**：缩略图/缓存/临时/回收站/obb 这类目录整棵不进；
 * 3. **预算**：单轮递归最多 [WALK_BUDGET_MS] 毫秒，超了就把待扫目录存进索引，
 *    下次进 App 接着扫（不会为了扫完而转圈十几秒）；
 * 4. **重扫间隔**：[DIR_RESCAN_INTERVAL_MS] 内扫过的目录不重复列目录，过期的最旧优先；
 * 5. **黑白名单剪枝**：白名单模式下只走「白名单目录及其祖先」，黑名单整棵跳过
 *    ——名单是用户意图，能省下的递归量最大（原来名单只在 Dart 侧过滤结果，
 *    整盘递归一个目录都没少）；
 * 6. **广度优先**：浅层目录先扫，视频通常就在浅层，首轮就能覆盖大部分。
 */
internal object FsVideoWalker {
    private const val WALK_BUDGET_MS = 1500L
    private const val DIR_RESCAN_INTERVAL_MS = 15 * 60_000L
    /**
     * 主卷（内部存储）最大递归深度。
     *
     * 原来只有 6 —— 深度判定卡的是**目录**（文件不判），depth ≥ 7 的目录整个不被
     * 列目录，里面的视频永远不出现。用户 2026-10 实测：`.nomedia` / 隐藏目录放在
     * `/storage/emulated/0/素材收集清单/M07/多级子目录/子目录1/…/子目录4/xxx`（8 层）
     * 这类深路径下扫不到，放在根目录或一两层则正常。
     *
     * 递归成本由 [WALK_BUDGET_MS] 时间预算 + 广度优先 + frontier 续扫 +
     * [DIR_RESCAN_INTERVAL_MS] 控制，不靠深度上限兜 → 与非主卷统一到 20。
     */
    private const val PRIMARY_MAX_DEPTH = 20

    /**
     * 非主卷最大递归深度。
     *
     * 原来只有 4 —— 深度判定卡的是**目录**（文件不判），所以 depth 4 的目录里
     * 的视频能扫到，但 depth ≥ 5 的目录**整个不被列目录**，里面的视频永远不出现：
     *
     * ```
     * /storage/CARD/Anime/2024/Season1/<番名>/Sub/ep01.mkv
     *      ↑depth0  ↑1   ↑2     ↑3        ↑4   ↑5 ← 这个目录被跳过
     * ```
     *
     * 番剧库常见的「番名/字幕组或分卷子目录」正好落在 depth 5 上。对齐参考项目
     * mpvRx 的 20（它是所有卷根统一 20）。
     */
    private const val EXTERNAL_MAX_DEPTH = 20
    private const val VALIDATE_MAX_PER_RUN = 8000
    private const val STALE_SEED_MAX = 4000

    /**
     * 变更探针的单轮预算与探测上限（P1-2）。
     *
     * 只探「还没到 15 分钟重扫间隔、且离下次重扫最远」的那些目录，一次 stat 一个目录；
     * 单轮最多花 [PROBE_BUDGET_MS] 毫秒 / [PROBE_MAX_PER_RUN] 个 —— 外置卡 stat 慢
     * （U 盘 / 机械盘更慢）时靠时间预算兜住，不让探针把这一轮的枚举预算吃光。
     */
    private const val PROBE_BUDGET_MS = 200L
    private const val PROBE_MAX_PER_RUN = 8000
    private const val KEEP_INDEX_FILES = 3
    private const val INDEX_PREFIX = "fs_video_index_"

    /** 增量推送的批大小：扫到这么多新条目就先推一批，首屏不必等整轮扫完 */
    private const val BATCH_SIZE = 64

    /** 两轮补扫之间的最小间隔：防页面来回切时把递归打成一串 */
    private const val WALK_MIN_INTERVAL_MS = 2000L

    /**
     * 补扫时整棵跳过的目录名（小写比较）：系统 / 缓存 / 缩略图 / 临时 / 回收站 / obb。
     *
     * 只放「一定不是用户视频库」的名字；`backup` / `logs` / `stickers` 这类
     * 可能真被用户拿来放视频的名字**不跳**（宁可多走几步也不吞用户的视频）。
     * 注意 `Android/data` 也**不跳**：个别 ROM 上能读到别的应用目录，那里确实
     * 会有视频（对齐 mpvRx 的刻意保留），代价由预算兜住。
     */
    private val SKIP_DIR_NAMES = setOf(
        ".thumbnails", "thumbnails", ".thumbs", "thumbs",
        ".cache", "cache", ".tmp", "tmp", ".temp", "temp",
        "lost.dir", ".trash", "trash", ".trashbin", ".trashed", "recycle", "recycler",
        ".android_secure", "android_secure", "obb",
    )

    /** 与 Dart 侧 `FileOps.videoExtensions` 同源的视频扩展名（MediaStore 不认的格式不受此限） */
    private val VIDEO_EXTS = setOf(
        "mp4", "mkv", "avi", "mov", "wmv", "flv", "ts", "m4v", "webm", "3gp", "mpg", "mpeg",
    )

    /** 浅层优先、同级按路径排序（稳定顺序 = 续扫可预期） */
    private val PATH_ORDER = Comparator<String> { a, b ->
        val da = a.count { it == '/' }
        val db = b.count { it == '/' }
        if (da != db) da - db else a.compareTo(b)
    }

    /** 同一时刻只跑一轮补扫；跑着的时候新的请求只读索引，不再起线程 */
    private val WALK_LOCK = Any()

    @Volatile
    private var walkRunning = false

    @Volatile
    private var lastWalkFinishedAt = 0L

    /**
     * 条目失效序号：`readCached` 每真的摘掉东西（失效路径 / 存活校验）就 +1。
     *
     * 后台那一轮是在此之前载入索引的，它落盘时如果发现序号变了，说明期间有更新的
     * 失效被写进文件了 —— 这一轮就不落盘（它扫到的结果已经推给 Dart 了），否则会
     * 把刚摘掉的条目又写回去。
     */
    @Volatile
    private var invalidateStamp = 0

    /** 最近一次 getVideos 的代次与条件指纹：推送只按最新代次回，旧代次 Dart 会丢 */
    @Volatile
    private var latestScanId = -1

    @Volatile
    private var latestScanKey = ""

    /** 「每进程一次」的索引校验标记：外部删除的文件不必每轮都 stat 一遍 */
    @Volatile
    private var validatedCachedOnce = false

    /**
     * 正在跑的那一轮的代次（没有在跑时为 -1）；配合 [cancelRequested] 判断
     * 「新请求来了，旧那一轮已经没人要了」。
     */
    @Volatile
    private var runningScanId = -1

    /**
     * 取消标志：置位后 BFS 在下一个目录边界收尾 —— 已扫到的结果照常落盘、照常推给
     * Dart，没扫到的进 frontier 下次接着扫（与预算截断同一条收尾路径）。
     *
     * 由 [walkInBackground] 起新的一轮时清掉，所以「现在没在跑」时置位是空操作。
     */
    @Volatile
    private var cancelRequested = false

    /**
     * 请求停掉当前这一轮（用户离开媒体库页面 → Dart 侧 `cancelFsScan`；
     * 或新的扫描请求到了 → [readCached]）。
     *
     * 参考项目 mpvRx 靠 `currentScanJob?.cancel()` + 页面 viewModelScope 做到
     * 同一件事；小喵的扫描器是静态 object，没有生命周期，所以留这个显式入口。
     */
    fun requestCancel() {
        cancelRequested = true
    }

    /**
     * 快速路径（同步、不递归）：只把**索引里已知**的补扫条目读出来。
     *
     * 这是「不等文件系统遍历」的延迟边界（对齐 mpvRx 的 `getAllVideoFoldersFast`
     * + `getIndexedNoMediaFolders`）：首屏先拿到 MediaStore + 上次索引的结果，
     * 递归交给 [walkInBackground] 在后台跑，边扫边把增量推给 Dart。
     *
     * **非主卷恒扫**（这些卷 MediaStore 未必索引，不扫就永远看不到里面的视频，见
     * `externalStorageRoots`）；**主卷只在 `.nomedia` / 隐藏文件夹开关打开时才进**
     * （MediaStore 绝不会自动索引 `.nomedia` 目录）。两种情形的索引按 key 分开存，
     * 开关关掉时不会端出旧的隐藏视频。
     */
    fun readCached(context: Context, request: FsScanRequest): List<Map<String, Any>> {
        val handle = openIndex(context, request)
        // 新的扫描请求 = 正在跑的那一轮的推送已经没人要了（Dart 只认自己那代）：
        // 让它别再占着 IO 往下扫（对齐 mpvRx 的 `currentScanJob?.cancel()`）
        if (walkRunning && request.scanId != runningScanId) requestCancel()
        // 记下最新代次：后台补扫推送按它回，Dart 只认自己那代
        latestScanId = request.scanId
        latestScanKey = handle.key

        val index = handle.index
        var changed = false
        // 文件操作改动过的路径：连整棵子树摘掉，交给这一轮补扫重新走
        //（**不整片清空** —— 清了就会出现「下拉刷新时 .nomedia / 隐藏文件夹 /
        // 外置卡的文件夹先消失再回来」的视觉跳跃）
        for (path in normalizePrefixes(request.invalidatePaths)) {
            if (index.removeSubtree(path)) changed = true
        }
        // 每个进程校验一次缓存里的视频是否还在（外部删除）
        if (!validatedCachedOnce) {
            if (validateCached(index)) changed = true
            validatedCachedOnce = true
        }
        // 这里的改动必须落盘：随后 walkInBackground 会重新载入索引文件，不落盘的话
        // 刚摘掉的条目会被读回来、最后再写回文件（等于白改）
        if (changed) {
            index.save()
            invalidateStamp++
        }
        return toMaps(index, handle.allowed, handle.blocked)
    }

    /**
     * 后台路径：跑一轮预算内的 BFS，**边扫边推增量**，结束后推一份完整快照
     * （快照是权威值，Dart 用它覆盖增量累计，顺带清掉已删除的条目）。
     *
     * [onBatch] / [onDone] 在后台线程上执行，带的是**当前最新**代次；期间条件变了
     * （开关 / 名单 / 代次）就不推 —— Dart 只认自己那代，推旧的没意义。
     *
     * 起这一轮时清掉取消标志、记下代次：期间的 [requestCancel] 只作用于这一轮，
     * 不会把下一轮一起取消掉。
     *
     * 返回是否真的起了线程（已有补扫在跑 / 距上轮太近 → false，不是错误）。
     */
    fun walkInBackground(
        context: Context,
        request: FsScanRequest,
        onBatch: (Int, List<Map<String, Any>>) -> Unit,
        onDone: (Int, List<Map<String, Any>>) -> Unit,
    ): Boolean {
        synchronized(WALK_LOCK) {
            if (walkRunning) return false
            if (!request.forceRescan &&
                SystemClock.elapsedRealtime() - lastWalkFinishedAt < WALK_MIN_INTERVAL_MS
            ) {
                return false
            }
            walkRunning = true
            runningScanId = request.scanId
            cancelRequested = false
        }

        // 后台线程可能比 Activity 活得久：只抓 Application 上下文，别把 Activity 拖住
        val appContext = context.applicationContext ?: context
        val stampAtStart = invalidateStamp
        Thread {
            try {
                val handle = openIndex(appContext, request)
                val index = handle.index
                val key = handle.key

                val startedAt = SystemClock.elapsedRealtime()
                val truncated = walk(handle, request) { batch ->
                    val scanId = if (latestScanKey == key) latestScanId else -1
                    if (scanId >= 0) onBatch(scanId, batch)
                }
                // 期间有更新的失效落盘了（文件操作 / 存活校验）→ 这一轮不落盘，
                // 免得把刚摘掉的条目写回去；扫到的结果照样已经推给 Dart
                if (stampAtStart == invalidateStamp) {
                    index.save()
                } else {
                    Log.d(TAG, "fs walk: skip save (索引期间被失效过)")
                }
                pruneIndexFiles(appContext, handle.file)
                // frontier = 这一轮没扫完、留到下次接着扫的目录数（「暂停了、还剩多少」
                // 的可观测点，对齐 mpvRx 的 "Paused hidden-folder indexing with N
                // directories queued"）
                Log.d(
                    TAG,
                    "fs walk: elapsed=${SystemClock.elapsedRealtime() - startedAt}ms truncated=$truncated " +
                        "dirs=${index.dirs.size} videos=${index.videos.values.sumOf { it.size }} " +
                        "frontier=${index.frontier.size}",
                )
                index.capacityNote()?.let { Log.w(TAG, "fs index 顶到容量上限：$it（超出部分会被丢弃）") }

                val scanId = if (latestScanKey == key) latestScanId else -1
                if (scanId >= 0) onDone(scanId, toMaps(index, handle.allowed, handle.blocked))
            } catch (e: Exception) {
                Log.w(TAG, "fs walk failed: ${e.message}")
            } finally {
                synchronized(WALK_LOCK) {
                    walkRunning = false
                    runningScanId = -1
                    lastWalkFinishedAt = SystemClock.elapsedRealtime()
                }
            }
        }.start()
        return true
    }

    /** 一次扫描的索引句柄：归一化后的条件 + 索引实例 + key */
    private class FsIndexHandle(
        val index: FsVideoIndex,
        val file: File,
        val allowed: List<String>,
        val blocked: List<String>,
        val primaryEnabled: Boolean,
        val key: String,
    )

    private fun openIndex(context: Context, request: FsScanRequest): FsIndexHandle {
        val primaryEnabled = request.includeNoMedia || request.includeHidden
        val allowed = normalizePrefixes(request.allowedPrefixes)
        val blocked = normalizePrefixes(request.blockedPrefixes)
        val key = buildKey(
            primaryEnabled,
            request.includeNoMedia,
            request.includeHidden,
            allowed,
            blocked,
        )
        val file = File(context.filesDir, "$INDEX_PREFIX${Integer.toHexString(key.hashCode())}.tsv")
        val index = FsVideoIndex(file)
        index.load(key)
        return FsIndexHandle(index, file, allowed, blocked, primaryEnabled, key)
    }

    /** 同一套开关 + 名单共用一个索引文件；只保留最近 [KEEP_INDEX_FILES] 份 */
    private fun pruneIndexFiles(context: Context, keep: File) {
        try {
            val all = context.filesDir.listFiles()?.filter { it.name.startsWith(INDEX_PREFIX) } ?: return
            if (all.size <= KEEP_INDEX_FILES) return
            val others = all.filter { it.absolutePath != keep.absolutePath }
            val sorted = others.sortedByDescending { it.lastModified() }
            for (i in (KEEP_INDEX_FILES - 1) until sorted.size) sorted[i].delete()
        } catch (e: Exception) {
            Log.w(TAG, "prune fs index failed: ${e.message}")
        }
    }

    private fun buildKey(
        primaryEnabled: Boolean,
        includeNoMedia: Boolean,
        includeHidden: Boolean,
        allowed: List<String>,
        blocked: List<String>,
    ): String {
        val inKey = allowed.sorted().joinToString(";")
        val exKey = blocked.sorted().joinToString(";")
        return "v2|primary=$primaryEnabled|nomedia=$includeNoMedia|hidden=$includeHidden|in=$inKey|ex=$exKey"
    }

    /**
     * 缓存视频的存活校验：外部删掉的条目要从列表里消失。每个进程只做一次，
     * 超出 [VALIDATE_MAX_PER_RUN] 的部分**放行不校验**（宁可留一条播不出来的
     * 条目，也不能因为预算把用户的视频丢了）。返回是否改动过（改过要落盘）。
     */
    private fun validateCached(index: FsVideoIndex): Boolean {
        var changed = false
        var checked = 0
        val emptyDirs = ArrayList<String>()
        for ((dir, list) in index.videos) {
            val kept = ArrayList<FsVideoEntry>(list.size)
            for (v in list) {
                if (checked >= VALIDATE_MAX_PER_RUN) {
                    kept.add(v)
                    continue
                }
                checked++
                val f = File(v.path)
                if (!f.isFile) {
                    changed = true
                    continue
                }
                val size = f.length()
                if (size > 0L && size != v.size) {
                    kept.add(FsVideoEntry(v.path, size, v.modifiedMs, v.durationMs))
                    changed = true
                } else {
                    kept.add(v)
                }
            }
            list.clear()
            list.addAll(kept)
            if (list.isEmpty()) {
                emptyDirs.add(dir)
                changed = true
            }
        }
        for (dir in emptyDirs) index.videos.remove(dir)
        return changed
    }

    /**
     * 预算内的 BFS：边扫边把新条目按 [BATCH_SIZE] 成批交给 [onBatch]。
     * 返回是否被预算截断（截断时待扫目录已存进索引的 frontier）。
     */
    private fun walk(
        handle: FsIndexHandle,
        request: FsScanRequest,
        onBatch: (List<Map<String, Any>>) -> Unit,
    ): Boolean {
        val index = handle.index
        val allowed = handle.allowed
        val blocked = handle.blocked
        val primaryEnabled = handle.primaryEnabled

        val startedAt = SystemClock.elapsedRealtime()
        val deadline = startedAt + WALK_BUDGET_MS
        val now = System.currentTimeMillis()

        val roots = ArrayList<FsRootInfo>()
        if (primaryEnabled) {
            request.primaryRoot?.let {
                roots.add(
                    FsRootInfo(
                        path = it.absolutePath,
                        isPrimary = true,
                        maxDepth = PRIMARY_MAX_DEPTH,
                    )
                )
            }
        }
        for (root in request.externalRoots) {
            roots.add(
                FsRootInfo(
                    path = root.absolutePath,
                    isPrimary = false,
                    maxDepth = EXTERNAL_MAX_DEPTH,
                )
            )
        }
        if (roots.isEmpty()) return false

        // 强制刷新（下拉刷新 / 一键清缓存）＝ **忽略重扫间隔重新走一遍，但不清索引**：
        // 期间列表照旧显示索引里的条目，扫完再用完整快照替换（对齐 mpvRx 的
        // 「先发布旧快照、扫完再 Replace」），所以刷新时不会少东西
        val staleBefore = if (request.forceRescan) Long.MAX_VALUE else now - DIR_RESCAN_INTERVAL_MS
        var level: List<String> = if (!request.forceRescan && index.frontier.isNotEmpty()) {
            // 上一轮没扫完：接着扫，不从根重来（这一轮不跑变更探针，先把欠的扫完）
            val pending = index.frontier.toList()
            index.frontier.clear()
            pending
        } else {
            // 一轮扫完了（或强制刷新）：重新从各个卷根 + 过期目录（最旧优先）起种子
            val seed = ArrayList<String>()
            for (root in roots) seed.add(root.path)
            seed.addAll(index.staleDirs(staleBefore, STALE_SEED_MAX))
            // 还没到重扫间隔、但目录 mtime 变了的（刚扫完又被改）也一起排进来：
            // 有它就等于「新增/删除/改名的视频最多等一轮就能看见」，不必等 15 分钟
            if (!request.forceRescan) {
                seed.addAll(
                    index.probeChangedDirs(
                        SystemClock.elapsedRealtime() + PROBE_BUDGET_MS,
                        PROBE_MAX_PER_RUN,
                    )
                )
            }
            // 强制刷新时别丢下没扫完的部分
            seed.addAll(index.frontier)
            index.frontier.clear()
            seed
        }
        // 文件操作改动过的目录排最前：这一轮一定重扫到它们，其余目录原地保留
        val priority = normalizePrefixes(request.invalidatePaths)
            .map { parentOf(it) }
            .distinct()
            .sortedWith(PATH_ORDER)
        val prioritySet = priority.toSet()
        val rest = level.distinct().filter { !prioritySet.contains(it) }.sortedWith(PATH_ORDER)
        level = priority + rest

        val noMediaCache = HashMap<String, Boolean>()
        val pending = ArrayList<Map<String, Any>>()
        var truncated = false

        while (level.isNotEmpty()) {
            val next = LinkedHashSet<String>()
            var cutAt = -1
            for (i in level.indices) {
                if (SystemClock.elapsedRealtime() > deadline) {
                    cutAt = i
                    break
                }
                if (cancelRequested) {
                    // 用户已经离开媒体库 / 换了一轮扫描：不再往下走。已扫到的结果
                    // 照常落盘、照常推给 Dart，剩下的进 frontier 下次接着扫
                    // （与预算截断走同一条收尾路径）
                    Log.d(TAG, "fs walk: cancelled（用户离开 / 换了扫描代次）")
                    cutAt = i
                    break
                }
                val path = level[i]
                val root = rootOf(path, roots) ?: continue
                val depth = depthIn(path, root.path)
                if (depth > root.maxDepth) continue

                val dir = File(path)
                if (!dir.isDirectory || !dir.canRead()) {
                    index.removeDir(path)
                    continue
                }
                if (!isAllowed(path, allowed, blocked)) {
                    index.removeDir(path)
                    continue
                }
                if (!request.includeHidden && dir.name.startsWith(".")) {
                    index.removeDir(path)
                    continue
                }
                if (!request.includeNoMedia) {
                    val pruned = if (root.isPrimary) {
                        // 主卷：与 MediaStore 分支同一套祖先链判定；卷根上的 .nomedia
                        // 是模拟器 / 个别 ROM 放的，不当作「不想扫这一卷」
                        hasNoMediaAncestor(dir, noMediaCache)
                    } else {
                        // 非主卷：只看目录自身，不上溯到卷外
                        depth > 0 && File(dir, ".nomedia").isFile
                    }
                    if (pruned) {
                        index.removeDir(path)
                        continue
                    }
                }

                // 指纹要在**列目录之前**取：列目录期间刚好有增删/改名的话，存下的是
                // 改动前的 mtime，下一次探针就能把这次改动认出来（宁可多走一遍，
                // 也不能把一次变更永久漏掉）
                val dirMtime = dir.lastModified()
                val files = try {
                    dir.listFiles()
                } catch (_: Exception) {
                    null
                } ?: continue

                val found = ArrayList<FsVideoEntry>()
                // 索引里这个目录上一轮的结果：文件没变就沿用已知时长的判定依据
                // （补扫自己**不抽**时长，只把历史抽到过的正面结果传下去，不白丢）
                val known = index.videos[path]?.associateBy { it.path }
                for (f in files) {
                    val name = f.name
                    if (f.isDirectory) {
                        if (SKIP_DIR_NAMES.contains(name.lowercase(Locale.ROOT))) continue
                        if (!request.includeHidden && name.startsWith(".")) continue
                        val childPath = f.absolutePath
                        // 已知目录由「过期重扫」负责，不在这里重复排队
                        if (!index.hasDir(childPath)) next.add(childPath)
                    } else {
                        if (!request.includeHidden && name.startsWith(".")) continue
                        val dot = name.lastIndexOf('.')
                        // 与 Dart 侧同口径：点开头的文件视为无扩展名
                        if (dot <= 0 || dot == name.length - 1) continue
                        if (!VIDEO_EXTS.contains(name.substring(dot + 1).lowercase(Locale.ROOT))) continue
                        if (!f.isFile) continue
                        // MediaStore 这一轮已经给过 → 不记进索引（索引只管系统看不到的
                        // 东西）。放在两次 stat **之前**：这类文件连大小/修改时间都不必读，
                        // 外置卡上每个文件省两次系统调用
                        if (request.mediaStorePaths.contains(f.absolutePath)) continue
                        val size = f.length()
                        if (size <= 0L) continue
                        val modifiedMs = f.lastModified()
                        val old = known?.get(f.absolutePath)
                        // **这一轮不开容器**：只枚举（目录列举 + 上面两次 stat）。
                        // 时长沿用索引里已有的正面结果（size + mtime 都没变才敢用），
                        // 否则留 0；0 的条目由卡片按需调 getVideoDuration 补，补不到
                        // 也只是列表上没有进度条，不会把枚举拖慢（P0-2）。
                        val duration = if (old != null && old.durationMs > 0L &&
                            old.size == size && old.modifiedMs == modifiedMs
                        ) {
                            old.durationMs
                        } else {
                            0L
                        }
                        found.add(FsVideoEntry(f.absolutePath, size, modifiedMs, duration))
                    }
                }
                index.applyDir(path, now, dirMtime, found)
                // 边扫边推：够一批就先给 Dart，首屏不必等整轮扫完
                if (found.isNotEmpty()) {
                    for (entry in found) pending.add(videoMap(entry))
                    if (pending.size >= BATCH_SIZE) {
                        onBatch(ArrayList(pending))
                        pending.clear()
                    }
                }
            }

            if (cutAt >= 0) {
                // 本层没走完 + 下一层已发现的，全留下来下次接着扫
                for (i in cutAt until level.size) index.frontier.add(level[i])
                index.frontier.addAll(next)
                truncated = true
                break
            }
            if (pending.isNotEmpty()) {
                onBatch(ArrayList(pending))
                pending.clear()
            }
            level = next.sortedWith(PATH_ORDER)
        }
        // 被预算截断时也要把不足一批的推出去
        if (pending.isNotEmpty()) onBatch(ArrayList(pending))
        return truncated
    }

    private fun toMaps(
        index: FsVideoIndex,
        allowed: List<String>,
        blocked: List<String>,
    ): List<Map<String, Any>> {
        val out = ArrayList<Map<String, Any>>()
        for ((dir, list) in index.videos) {
            if (!isAllowed(dir, allowed, blocked)) continue
            for (v in list) out.add(videoMap(v))
        }
        return out
    }

    /** 一条补扫视频 → 与 MediaStore 分支同字段的 Map（`fs` 标记给 Dart 区分“补扫那份”） */
    private fun videoMap(v: FsVideoEntry): Map<String, Any> = mapOf(
        "path" to v.path,
        "name" to nameOf(v.path),
        // 时长未知（补扫不抽）就是 0，Dart 侧按「未知」处理、由卡片按需补
        "durationMs" to if (v.durationMs > 0L) v.durationMs else 0L,
        "size" to v.size,
        "width" to 0,
        "height" to 0,
        "dateModifiedMs" to v.modifiedMs,
        "fs" to true,
    )

    private fun rootOf(path: String, roots: List<FsRootInfo>): FsRootInfo? {
        var best: FsRootInfo? = null
        for (root in roots) {
            if (path != root.path && !path.startsWith("${root.path}/")) continue
            val current = best
            if (current == null || root.path.length > current.path.length) best = root
        }
        return best
    }

    private fun depthIn(path: String, rootPath: String): Int {
        if (path == rootPath) return 0
        val relative = path.removePrefix(rootPath)
        var count = 0
        for (c in relative) if (c == '/') count++
        return count
    }

    /** 主卷的 `.nomedia` 祖先链判定（与原实现一致：上溯到 /storage/emulated 为止） */
    private fun hasNoMediaAncestor(dir: File, cache: MutableMap<String, Boolean>): Boolean {
        val dirPath = dir.absolutePath
        cache[dirPath]?.let { return it }
        var current: File? = dir
        var hasNoMedia = false
        while (current != null && current.path != "/" && current.path != "/storage/emulated") {
            if (File(current, ".nomedia").exists()) {
                hasNoMedia = true
                break
            }
            current = current.parentFile
        }
        cache[dirPath] = hasNoMedia
        return hasNoMedia
    }

    /**
     * 目录是否允许进：黑名单命中即不进；白名单非空时，只有「在白名单内」或
     * 「是某个白名单目录的祖先」（去往它的必经路径）才进。语义与 Dart 侧
     * `MediaScanSettings.isPathAllowed` 对齐，只是提前到剪枝这一步。
     */
    private fun isAllowed(path: String, allowed: List<String>, blocked: List<String>): Boolean {
        val p = normalizePath(path)
        if (p.isEmpty()) return true
        for (b in blocked) {
            if (isSubPathOrSame(p, b)) return false
        }
        if (allowed.isEmpty()) return true
        for (w in allowed) {
            if (isSubPathOrSame(p, w) || isSubPathOrSame(w, p)) return true
        }
        return false
    }

    private fun isSubPathOrSame(path: String, parent: String): Boolean {
        if (parent.isEmpty()) return false
        if (path == parent) return true
        return path.startsWith("$parent/")
    }

    private fun normalizePrefixes(raw: List<String>): List<String> =
        raw.map { normalizePath(it) }.filter { it.isNotEmpty() }.distinct()

    /** 与 Dart 侧 `MediaScanSettings._normalizePath` 同一套归一化（不转小写：Android 路径大小写敏感） */
    private fun normalizePath(raw: String): String {
        var path = raw.trim().replace('\\', '/')
        while (path.contains("//")) path = path.replace("//", "/")
        if (path.length > 1 && path.endsWith("/")) path = path.dropLast(1)
        return path
    }
}
