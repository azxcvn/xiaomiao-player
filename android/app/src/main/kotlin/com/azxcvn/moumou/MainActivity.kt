package com.azxcvn.moumou

import android.app.Activity
import android.app.PictureInPictureParams
import android.app.WallpaperManager
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.database.Cursor
import android.graphics.Bitmap
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.media.AudioManager
import android.media.MediaMetadataRetriever
import android.media.MediaScannerConnection
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Uri
import android.os.BatteryManager
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.SystemClock
import android.os.storage.StorageManager
import android.os.storage.StorageVolume
import android.provider.DocumentsContract
import android.provider.MediaStore
import android.provider.OpenableColumns
import android.provider.Settings
import android.util.Log
import android.util.Rational
import android.view.View
import androidx.documentfile.provider.DocumentFile
import com.yubyf.truetypeparser.TTFFile
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import kotlin.system.exitProcess

class MainActivity : FlutterActivity() {
    private val channelName = "moumou/video_info"

    /**
     * 系统文件选择器（ACTION_OPEN_DOCUMENT）的待回结果：
     * invokeMethod 无法同步跨 onActivityResult 返回，先把 result 暂存，
     * onActivityResult 里再 complete（返回 content:// uri 字符串或 null）。
     */
    private var pendingDocumentPickerResult: MethodChannel.Result? = null

    /** 字体目录选择器（ACTION_OPEN_DOCUMENT_TREE）的待回结果。 */
    private var pendingFontDirPickerResult: MethodChannel.Result? = null

    /** 本地网络权限（Android 16+ ACCESS_LOCAL_NETWORK）请求的待回结果。 */
    private var pendingLocalNetworkResult: MethodChannel.Result? = null

    /**
     * 外部打开视频（系统「打开方式」ACTION_VIEW intent，工作.md：注册为播放器）
     * 待处理项：冷启动（onCreate）先暂存，Flutter 首帧后 Dart 调
     * takeExternalVideo 取走；热启动（onNewIntent，launchMode=singleTop）
     * 暂存后主动 invokeMethod("onExternalVideo") 通知 Dart 来取。
     */
    private var pendingExternalVideo: Map<String, String>? = null

    /** 主通道引用（onNewIntent 时向 Dart 推送通知用）。 */
    private var flutterChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Flutter 首帧前按 App 主题设置系统导航栏（三大金刚键区域）颜色，
        // 避免深色/AMOLED 下启动阶段露出白底；首帧后由 Dart 侧 SystemChrome 接管
        applySystemBarStyle()
        // 外部「打开方式」进来的视频（其他 App 分享/文件管理器打开）：
        // 暂存，等 Flutter 首帧后由 Dart 取走播放
        handleViewIntent(intent)
    }

    // ── 系统导航栏颜色（三大金刚键区域）────────────

    /**
     * 按 App 主题模式设置系统导航栏颜色：深色/AMOLED → 黑底白键；浅色 → 浅底深键。
     *
     * 主题模式读取 Dart 侧 ThemeController 持久化的 theme_mode
     * （shared_preferences 在 Android 存于 FlutterSharedPreferences，
     * 键带 `flutter.` 前缀；0=system 1=light 2=dark 3=amoled），
     * system/未设置时跟随系统深色模式。
     *
     * 注意：targetSdk 35+ 强制 edge-to-edge 时该颜色被系统忽略（系统栏透明），
     * 这里作为启动闪屏期与旧系统路径的兜底；实际可见效果由 Dart 侧
     * SystemChrome.setSystemUIOverlayStyle 保证。
     */
    private fun applySystemBarStyle() {
        // 启动路径绝不允许崩溃：读取失败/类型异常一律降级为 system 模式，
        // 否则 onCreate 抛异常会形成「每次启动必崩」的崩溃循环（debug/release 同理）。
        try {
            // API 29+ 默认 isNavigationBarContrastEnforced=true：系统会在导航栏上
            // 叠加半透明对比度 scrim，把纯黑底刷成灰白（深色/AMOLED 下三大金刚键
            // 区域发灰的根因）。关闭后 navigationBarColor 精确生效（内联 SDK 判断
            // 防 lint NewApi 报错）。
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                window.isNavigationBarContrastEnforced = false
            }
            val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            // 关键坑：shared_preferences 在 Android 把 Dart 的 int 一律存为 Long
            // （Dart int 是 64 位，插件 setInt → putLong）。若用 prefs.getInt(...) 读，
            // SharedPreferencesImpl 直接抛 ClassCastException: Long cannot be cast to
            // Integer（历史启动崩溃根因）。这里从 all 取值做类型兼容读取：
            // Int / Long 都接受，其余类型/缺失按「未设置(-1)」处理。
            val mode = when (val v = prefs.all["flutter.theme_mode"]) {
                is Int -> v
                is Long -> v.toInt()
                else -> -1
            }
            val isDark = when (mode) {
                2, 3 -> true // dark / amoled
                1 -> false // light
                else -> { // system / 未设置：跟随系统
                    val night = resources.configuration.uiMode and
                        Configuration.UI_MODE_NIGHT_MASK
                    night == Configuration.UI_MODE_NIGHT_YES
                }
            }
            @Suppress("DEPRECATION")
            window.navigationBarColor = if (isDark) {
                android.graphics.Color.BLACK
            } else {
                android.graphics.Color.WHITE
            }
            // 导航键图标亮度（API 26+；浅色主题用深色键，深色主题用浅色键）
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val flags = window.decorView.systemUiVisibility
                @Suppress("DEPRECATION")
                window.decorView.systemUiVisibility = if (isDark) {
                    flags and View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR.inv()
                } else {
                    flags or View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR
                }
            }
        } catch (e: Exception) {
            // 导航栏配色只是视觉效果：任何异常（prefs 损坏/类型异常等）都静默降级，
            // 保证 onCreate 永不因主题读取崩溃（debug/release 一致）
            Log.w("MainActivity", "applySystemBarStyle failed, fallback to system: ${e.message}")
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // 崩溃日志自动记录（未捕获异常 → files/crash_logs/）
        CrashHandler.init(this)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        flutterChannel = channel
        channel
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getVideoInfo" -> {
                        val path = call.argument<String>("path")
                        if (path == null) {
                            result.error("INVALID_ARG", "path is null", null)
                        } else {
                            // 耗时解码放到后台线程，避免阻塞 UI 线程
                            Thread {
                                val info = getVideoInfo(path)
                                runOnUiThread { result.success(info) }
                            }.start()
                        }
                    }
                    // 列表字段「帧率 / 字幕指示器」：MediaInfoLib 快速解析 + 磁盘缓存
                    "getVideoBasicMetadata" -> {
                        val path = call.argument<String>("path")
                        if (path == null) {
                            result.error("INVALID_ARG", "path is null", null)
                        } else {
                            Thread {
                                val meta = getVideoBasicMetadata(path)
                                runOnUiThread { result.success(meta) }
                            }.start()
                        }
                    }
                    // 媒体信息页：MediaInfoLib 完整解析（通用/视频/音频/字幕流）
                    "getMediaInfo" -> {
                        val path = call.argument<String>("path")
                        if (path == null) {
                            result.error("INVALID_ARG", "path is null", null)
                        } else {
                            Thread {
                                val info = MediaInfoHelper.getMediaInfo(this, path)
                                runOnUiThread { result.success(info) }
                            }.start()
                        }
                    }
                    // 杜比视界偏色检测：返回 {isDolbyVision, hdrFormat}
                    "detectDolbyVision" -> {
                        val path = call.argument<String>("path")
                        if (path == null) {
                            result.error("INVALID_ARG", "path is null", null)
                        } else {
                            Thread {
                                val (isDv, hdr) = MediaInfoHelper.detectDolbyVision(this, path)
                                runOnUiThread {
                                    result.success(
                                        mapOf("isDolbyVision" to isDv, "hdrFormat" to hdr)
                                    )
                                }
                            }.start()
                        }
                    }
                    // 设备硬件与编解码能力检测（屏幕 HDR / 关键编码器 / 解码器清单）
                    "getDeviceCapabilities" -> {
                        Thread {
                            val caps = DeviceCapabilities.inspect(this)
                            runOnUiThread { result.success(caps) }
                        }.start()
                    }
                    // 整应用重启（解码配置修改后一键重启，工作.md 迁移功能）
                    "restartApp" -> {
                        restartApp()
                        result.success(null)
                    }
                    // 动态色（壁纸取色，Material You）：返回主色 ARGB int 或 null
                    "getWallpaperColors" -> {
                        Thread {
                            val colors = getWallpaperColors()
                            runOnUiThread { result.success(colors) }
                        }.start()
                    }
                    // 媒体库全表扫描（MediaStore 全表 query + 逐条 exists/length +
                    // .nomedia 祖先链上溯 + MediaMetadataRetriever 时长兜底 + 可选的
                    // 深度 6 全盘递归）：本文件体量最大的通道方法，必须与相邻分支一致
                    // 放到后台线程，否则库大时主线程秒级阻塞 / ANR
                    "getVideos" -> {
                        val includeNoMedia = call.argument<Boolean>("includeNoMedia") ?: false
                        val includeHidden = call.argument<Boolean>("includeHidden") ?: false
                        Thread {
                            try {
                                val videos = getVideos(includeNoMedia, includeHidden)
                                runOnUiThread { result.success(videos) }
                            } catch (e: Throwable) {
                                // 没有兜底时异常会逃到通道线程；回结构化错误让 Dart 侧
                                // 进错误态（不再永久转圈）。用 Throwable 兜住 Error：
                                // 全盘递归扫描在大库/坏介质上确实可能抛
                                Log.w("MainActivity", "getVideos failed: ${e.message}")
                                runOnUiThread {
                                    result.error("GET_VIDEOS_FAILED", e.message, null)
                                }
                            }
                        }.start()
                    }
                    "getSystemVolume" -> result.success(getSystemVolume())
                    "setSystemVolume" -> {
                        setSystemVolume(call.argument<Double>("volume") ?: 0.0)
                        result.success(null)
                    }
                    "getBrightness" -> result.success(getBrightness())
                    "setWindowBrightness" -> {
                        setWindowBrightness(call.argument<Double>("brightness") ?: -1.0)
                        result.success(null)
                    }
                    // 播放界面顶部电量显示（工作.md 第 12 点）
                    "getBatteryLevel" -> result.success(getBatteryLevel())
                    // 播放界面顶部网络类型显示（工作.md 阶段1 第 1 点）
                    "getNetworkType" -> result.success(getNetworkType())
                    // 系统「自动旋转」开关（播放界面「跟随手机方向」用，只读无权限）
                    "isAutoRotateEnabled" -> result.success(isAutoRotateEnabled())
                    // 本地网络权限（Android 16+）：连局域网 NAS/自建服务器前请求；
                    // 16 以下无此权限直接视为已授权
                    "requestLocalNetworkPermission" -> {
                        if (Build.VERSION.SDK_INT < 36) {
                            result.success(true)
                        } else if (checkSelfPermission("android.permission.ACCESS_LOCAL_NETWORK") ==
                            PackageManager.PERMISSION_GRANTED
                        ) {
                            result.success(true)
                        } else {
                            pendingLocalNetworkResult = result
                            requestPermissions(
                                arrayOf("android.permission.ACCESS_LOCAL_NETWORK"),
                                2004,
                            )
                        }
                    }
                    // 听视频后台播放前台服务启停（工作.md 阶段1 第 2 点）
                    "startBackgroundPlayback" -> {
                        startBackgroundPlayback(call.argument<String>("title") ?: "")
                        result.success(true)
                    }
                    "stopBackgroundPlayback" -> {
                        stopBackgroundPlayback()
                        result.success(true)
                    }
                    // ── 字幕功能（工作.md 阶段1 第 3 点）────────────
                    "getSdkInt" -> result.success(Build.VERSION.SDK_INT)
                    "listDirectory" -> result.success(listDirectory(call.argument<String>("path") ?: ""))
                    // 存储卷根列表（内部存储 + SD 卡 / U 盘）。选择器靠它跳卷：
                    // `/storage` 目录本身在 Android 11+ 列不出来（开「所有文件访问」
                    // 也只授权到各卷根，不含 `/storage` 这个挂载点容器），
                    // 所以外置卡唯一的合法入口就是 StorageManager 的卷枚举。
                    "getStorageRoots" -> result.success(getStorageRoots())
                    "getSystemFonts" -> result.success(getSystemFonts())
                    "copySubtitleFromUri" -> {
                        val path = copySubtitleFromUri(
                            call.argument<String>("uri") ?: "",
                            call.argument<String>("name") ?: "subtitle.srt",
                        )
                        result.success(path)
                    }
                    // 弹幕功能：content:// 弹幕文件拷贝到 filesDir/danmaku/（返回真实路径）
                    "copyDanmakuFromUri" -> {
                        val path = copyDanmakuFromUri(
                            call.argument<String>("uri") ?: "",
                            call.argument<String>("name") ?: "danmaku.xml",
                        )
                        result.success(path)
                    }
                    // 字幕字体导入：content:// 拷贝到 filesDir/fonts/（返回真实路径）
                    "copyFontFromUri" -> {
                        val path = copyFontFromUri(
                            call.argument<String>("uri") ?: "",
                            call.argument<String>("name") ?: "font.ttf",
                        )
                        result.success(path)
                    }
                    // 字幕字体导入：文件路径拷贝到 filesDir/fonts/（返回真实路径）
                    "copyFontFromFile" -> {
                        val path = copyFontFromFile(
                            call.argument<String>("path") ?: "",
                            call.argument<String>("name") ?: "font.ttf",
                        )
                        result.success(path)
                    }
                    // 获取内部字体目录绝对路径
                    "getFontsDirectory" -> {
                        val fontDir = File(filesDir, "fonts")
                        if (!fontDir.exists()) fontDir.mkdirs()
                        ensureFallbackFont(fontDir)
                        result.success(fontDir.absolutePath)
                    }
                    // 读取字体内部家族名（libass 的 sub-font 按家族名匹配，不能直接用文件名）
                    "getFontFamilyName" -> {
                        result.success(getFontFamilyName(call.argument<String>("path") ?: ""))
                    }
                    // 打开哔哩哔哩客户端自动扫码（bilibili://browser 深链直接拉起）
                    "openBilibiliScan" -> {
                        val url = call.argument<String>("url") ?: ""
                        result.success(openBilibiliScan(url))
                    }
                    "openDocumentPicker" -> {
                        if (pendingDocumentPickerResult != null) {
                            result.error("BUSY", "picker already open", null)
                        } else {
                            pendingDocumentPickerResult = result
                            try {
                                startActivityForResult(buildDocumentPickerIntent(), 2002)
                            } catch (e: Exception) {
                                pendingDocumentPickerResult = null
                                result.success(null) // 失败 → Dart 侧回退自建选择器
                            }
                        }
                    }
                    // 本地弹幕选择器（弹幕专用 MIME 白名单含 text/xml，
                    // 系统选择器不再把 XML 弹幕置灰——用户反馈的根因）
                    "openDanmakuPicker" -> {
                        if (pendingDocumentPickerResult != null) {
                            result.error("BUSY", "picker already open", null)
                        } else {
                            pendingDocumentPickerResult = result
                            try {
                                startActivityForResult(
                                    buildDocumentPickerIntent(danmakuPickerMimeTypes),
                                    2002,
                                )
                            } catch (e: Exception) {
                                pendingDocumentPickerResult = null
                                result.success(null)
                            }
                        }
                    }
                    // 音频选择器（MIME 含 audio 类型，系统选择器不再置灰 .mp3/.m4a/.flac）
                    "openAudioPicker" -> {
                        if (pendingDocumentPickerResult != null) {
                            result.error("BUSY", "picker already open", null)
                        } else {
                            pendingDocumentPickerResult = result
                            try {
                                startActivityForResult(
                                    buildDocumentPickerIntent(audioPickerMimeTypes),
                                    2002,
                                )
                            } catch (e: Exception) {
                                pendingDocumentPickerResult = null
                                result.success(null)
                            }
                        }
                    }
                    // 音轨导入：content:// 拷贝到 filesDir/audio/（返回真实路径）
                    "copyAudioFromUri" -> {
                        val path = copyAudioFromUri(
                            call.argument<String>("uri") ?: "",
                            call.argument<String>("name") ?: "audio.mp3",
                        )
                        result.success(path)
                    }
                    // 字体选择器（MIME 含 font 类型，系统选择器不再置灰 .ttf/.otf）
                    "openFontPicker" -> {
                        if (pendingDocumentPickerResult != null) {
                            result.error("BUSY", "picker already open", null)
                        } else {
                            pendingDocumentPickerResult = result
                            try {
                                startActivityForResult(
                                    buildDocumentPickerIntent(fontPickerMimeTypes),
                                    2002,
                                )
                            } catch (e: Exception) {
                                pendingDocumentPickerResult = null
                                result.success(null)
                            }
                        }
                    }
                    // 壁纸图片选择器：Android 13+ 用系统 Photo Picker（缩略图网格，
                    // 无需权限）；以下版本回退 SAF（ACTION_OPEN_DOCUMENT + image/*）。
                    // 选中后**立即**把图拷进应用私有目录，直接返回真实绝对路径
                    // （Dart 侧解码用 FileImage，content:// 读不了），取消返回 null。
                    "pickWallpaperImage" -> {
                        if (pendingDocumentPickerResult != null) {
                            result.error("BUSY", "picker already open", null)
                        } else {
                            pendingDocumentPickerResult = result
                            if (!launchImagePicker(buildImagePickerIntents(), 2005)) {
                                // 所有候选都没有承接方（极罕见）：不静默失败，
                                // 让 Dart 侧能区分「取消」与「这台设备没有选择器」
                                pendingDocumentPickerResult = null
                                Log.w("MainActivity", "pickWallpaperImage: no picker available")
                                result.error("NO_PICKER", "no image picker available", null)
                            }
                        }
                    }
                    // 字体目录选择器（ACTION_OPEN_DOCUMENT_TREE）：返回 tree uri
                    "openFontDirectoryPicker" -> {
                        if (pendingFontDirPickerResult != null) {
                            result.error("BUSY", "picker already open", null)
                        } else {
                            pendingFontDirPickerResult = result
                            try {
                                startActivityForResult(buildOpenDocumentTreeIntent(), 2003)
                            } catch (e: Exception) {
                                pendingFontDirPickerResult = null
                                result.success(null)
                            }
                        }
                    }
                    // 批量拷贝字体目录里的所有字体到私有 fonts/（返回成功拷贝数）
                    "copyFontsFromDirectory" -> {
                        result.success(copyFontsFromDirectory(call.argument<String>("uri") ?: ""))
                    }
                    // 列出私有 fonts/ 目录内的字体条目（族名 + 文件名）
                    "listFontEntries" -> result.success(listFontEntries())
                    // 清空私有 fonts/ 目录
                    "clearFontsDirectory" -> {
                        clearFontsDirectory()
                        result.success(null)
                    }
                    "getCacheSizes" -> result.success(getCacheSizes())
                    "clearCache" -> {
                        clearCache(call.argument<String>("category") ?: "")
                        result.success(null)
                    }
                    "clearAllCaches" -> {
                        clearAllCaches()
                        result.success(null)
                    }
                    "getCrashLogDir" -> result.success(logDir().absolutePath)
                    "listCrashLogs" -> result.success(listLogs())
                    "readCrashLog" -> {
                        result.success(readLog(call.argument<String>("path") ?: ""))
                    }
                    "deleteCrashLog" -> {
                        result.success(deleteLog(call.argument<String>("path") ?: ""))
                    }
                    "clearCrashLogs" -> result.success(clearLogs())
                    "exportCrashLog" -> {
                        result.success(exportLog(call.argument<String>("path") ?: ""))
                    }
                    // Dart 侧未捕获异常 → 追加到崩溃日志目录（flutter_*.log）
                    "appendDartLog" -> {
                        val content = call.argument<String>("content") ?: ""
                        appendDartLog(content)
                        result.success(null)
                    }
                    // ── 画中画（小窗播放）────────────────────
                    "isPipSupported" -> result.success(isPipSupported())
                    "enterPip" -> {
                        // Dart 小整数经 MethodChannel 编码是 Integer 而非 Long，
                        // 用 Number 兼容，避免 ClassCastException（与抓帧同一坑）
                        val aspectWidth = call.argument<Number>("aspectWidth")?.toInt() ?: 16
                        val aspectHeight = call.argument<Number>("aspectHeight")?.toInt() ?: 9
                        result.success(enterPip(aspectWidth, aspectHeight))
                    }
                    "setAutoPipEnabled" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        setAutoPipEnabled(enabled)
                        result.success(true)
                    }
                    // ── B站视频下载：音视频 m4s 合并为 mp4（MediaMuxer 流直拷）────
                    "mergeM4s" -> {
                        val video = call.argument<String>("video") ?: ""
                        val audio = call.argument<String>("audio") ?: ""
                        val output = call.argument<String>("output") ?: ""
                        if (video.isEmpty() || audio.isEmpty() || output.isEmpty()) {
                            result.error("INVALID_ARG", "video/audio/output required", null)
                        } else {
                            Thread {
                                val ok = mergeM4s(video, audio, output)
                                runOnUiThread { result.success(ok) }
                            }.start()
                        }
                    }
                    // 触发系统媒体库扫描单个文件（下载产物写盘后调用，工作.md 第 5 点：
                    // 让 MediaStore 立即抽取时长/分辨率，避免列表里 duration=0 导致进度不显示）
                    "scanMediaFile" -> {
                        val path = call.argument<String>("path") ?: ""
                        if (path.isEmpty()) {
                            result.error("INVALID_ARG", "path required", null)
                        } else {
                            scanMediaFile(path)
                            result.success(true)
                        }
                    }
                    // ── 外部打开视频（注册为系统播放器，工作.md）──────
                    // 取走待处理的外部视频（返回 {uri, title} 或 null，取后即清）
                    "takeExternalVideo" -> {
                        val pending = pendingExternalVideo
                        pendingExternalVideo = null
                        result.success(pending)
                    }
                    // 解析外部视频 uri 为可播放路径（content:// 真实路径/拷贝缓存、
                    // file:// 路径、流媒体直链原样返回；可能拷贝大文件 → 后台线程）
                    "resolveVideoUri" -> {
                        val uri = call.argument<String>("uri") ?: ""
                        if (uri.isEmpty()) {
                            result.error("INVALID_ARG", "uri required", null)
                        } else {
                            Thread {
                                val resolved = resolveExternalVideo(uri)
                                runOnUiThread { result.success(resolved) }
                            }.start()
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // ── 外部打开视频（注册为系统播放器，工作.md）──────────────

    /**
     * 热启动：其他 App 以「打开方式」再次拉起本应用（launchMode=singleTop，
     * 不重建 Activity，走 onNewIntent）。暂存后通知 Dart 取走播放。
     */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleViewIntent(intent)
        if (pendingExternalVideo != null) {
            flutterChannel?.invokeMethod("onExternalVideo", null)
        }
    }

    /**
     * 解析外部「打开方式」intent：ACTION_VIEW 且为视频（或未声明 MIME /
     * 流媒体直链）时暂存待处理项。非视频 VIEW（网页/图片等）忽略。
     */
    private fun handleViewIntent(intent: Intent?) {
        if (intent == null || Intent.ACTION_VIEW != intent.action) return
        val uri = intent.data ?: return
        // 声明了非视频 MIME 的（text/html、image/* 等）不进播放器；
        // 未声明 MIME 的按直链处理（intent-filter 已保证只收到视频类 intent）。
        // ⚠️ 除 video/* 外还需接受注册过的 application/* 容器 MIME
        //（mkv=x-matroska、m3u8=vnd.apple.mpegurl 等，否则外部 App 用这些
        // MIME 拉起时被误拒、点了没反应）。
        val type = intent.type
        if (type != null && !isVideoMimeType(type)) return
        val title = try {
            queryDisplayName(uri) ?: uri.lastPathSegment ?: ""
        } catch (e: Exception) {
            ""
        }
        pendingExternalVideo = mapOf("uri" to uri.toString(), "title" to title)
    }

    /** 与 AndroidManifest intent-filter 注册的视频类 MIME 保持一致 */
    private fun isVideoMimeType(type: String): Boolean {
        if (type.startsWith("video/") || type == "*/*") return true
        return type in videoContainerMimeTypes
    }

    private val videoContainerMimeTypes = setOf(
        "application/x-matroska",
        "application/mp4",
        "application/mpeg",
        "application/vnd.apple.mpegurl",
        "application/x-mpegurl",
        "application/x-quicktimeplayer",
        "application/vnd.rn-realmedia",
        "application/vnd.rn-realmedia-vbr",
        "application/3gpp",
        "application/vnd.3gpp",
    )

    /**
     * 把外部视频 uri 解析为可播放路径 + 标题（后台线程执行，可能拷贝大文件）。
     * content:// → 优先解析真实路径（App 持有 MANAGE_EXTERNAL_STORAGE），
     * 解析不到再拷贝到 cacheDir/external_open/；file:// → 直接取路径；
     * http(s)/rtmp/rtsp 等流媒体直链 → 原样返回（mpv 直接拉流）。
     */
    private fun resolveExternalVideo(uriString: String): Map<String, Any?>? {
        return try {
            val uri = Uri.parse(uriString)
            when (uri.scheme?.lowercase()) {
                "content" -> resolveContentVideo(uri)
                "file" -> {
                    val path = uri.path ?: return null
                    mapOf("path" to File(path).absolutePath, "title" to File(path).name)
                }
                "http", "https", "rtmp", "rtmps", "rtsp", "rtsps",
                "rtp", "mms", "mmst", "mmsh" ->
                    mapOf("path" to uriString, "title" to null)
                else -> null
            }
        } catch (e: Exception) {
            Log.w("MainActivity", "resolveExternalVideo failed: ${e.message}")
            null
        }
    }

    /**
     * content:// 视频解析，三级回退：
     * 1. MediaStore 等 provider 的 DATA 列 → 真实路径（零拷贝）；
     * 2. ExternalStorageProvider 的 documentId（primary:xxx / raw:/path 形态）；
     * 3. 兜底拷贝到 cacheDir/external_open/（libmpv 无法直接读 content://，
     *    与字幕/音轨导入的拷贝思路一致；缓存目录交给系统回收）。
     */
    private fun resolveContentVideo(uri: Uri): Map<String, Any?>? {
        @Suppress("DEPRECATION")
        val dataPath = queryDataColumn(uri)
        if (dataPath != null && File(dataPath).isFile) {
            return mapOf("path" to dataPath, "title" to File(dataPath).name)
        }
        val docPath = resolveDocumentPath(uri)
        if (docPath != null && File(docPath).isFile) {
            return mapOf("path" to docPath, "title" to File(docPath).name)
        }
        val rawName = queryDisplayName(uri) ?: "external_video"
        val name = rawName.replace(Regex("[\\\\/:*?\"<>|]"), "_")
        val dir = File(cacheDir, "external_open")
        if (!dir.exists()) dir.mkdirs()
        val dest = File(dir, name)
        val input = try {
            contentResolver.openInputStream(uri)
        } catch (e: Exception) {
            null
        } ?: return null
        try {
            input.use { s -> FileOutputStream(dest).use { s.copyTo(it) } }
        } catch (e: Exception) {
            Log.w("MainActivity", "copyExternalVideo failed: ${e.message}")
            dest.delete()
            return null
        }
        if (!dest.isFile || dest.length() == 0L) {
            dest.delete()
            return null
        }
        return mapOf("path" to dest.absolutePath, "title" to name)
    }

    /** 查询 provider 的 DATA 列（MediaStore 视频的真实路径；无该列/失败返回 null） */
    @Suppress("DEPRECATION")
    private fun queryDataColumn(uri: Uri): String? {
        return try {
            contentResolver
                .query(uri, arrayOf(MediaStore.MediaColumns.DATA), null, null, null)
                ?.use { c -> if (c.moveToFirst()) c.getString(0) else null }
        } catch (e: Exception) {
            null
        }
    }

    /** DocumentsProvider documentId → 本地路径（primary:xxx 与 raw:/path 两种形态） */
    private fun resolveDocumentPath(uri: Uri): String? {
        return try {
            val docId = DocumentsContract.getDocumentId(uri)
            when {
                docId.startsWith("raw:") ->
                    docId.removePrefix("raw:")
                docId.startsWith("primary:") ->
                    Environment.getExternalStorageDirectory().toString() +
                        "/" + docId.removePrefix("primary:")
                else -> null
            }
        } catch (e: Exception) {
            null
        }
    }

    // ── B站视频下载：MediaExtractor + MediaMuxer 流直拷合并 ──────────

    /**
     * 把 B 站 DASH 的 video.m4s + audio.m4s 合并成单个 mp4（不重编码，流直拷）。
     * 对齐老项目（小喵 player）`mergeVideoAudio` 的 MediaMuxer 方案，避免引入
     * ffmpeg_kit 依赖。合并成功会顺手删除两个临时 m4s 文件。
     */
    private fun mergeM4s(videoPath: String, audioPath: String, outputPath: String): Boolean {
        // 三个资源都在 try 之外声明：任何一步抛错（setDataSource 打不开 m4s、
        // addTrack/start 失败、copyTrack 中途解码异常、stop 失败）都要在 finally 里
        // release。旧实现只在成功路径与「轨道缺失」分支 release，失败分支整条泄漏：
        // muxer 不释放会让 Dart 侧刚写的 `{id}.merge.mp4` 删不掉（_deleteQuietly 吞掉，
        // 只能等进程重启），extractor 泄漏则持续占着 fd。
        var muxer: android.media.MediaMuxer? = null
        var videoExtractor: android.media.MediaExtractor? = null
        var audioExtractor: android.media.MediaExtractor? = null
        var started = false
        return try {
            val mux = android.media.MediaMuxer(
                outputPath,
                android.media.MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4,
            )
            muxer = mux

            val vEx = android.media.MediaExtractor()
            videoExtractor = vEx
            vEx.setDataSource(videoPath)
            var videoFormat: android.media.MediaFormat? = null
            for (i in 0 until vEx.trackCount) {
                val fmt = vEx.getTrackFormat(i)
                val mime = fmt.getString(android.media.MediaFormat.KEY_MIME) ?: ""
                if (mime.startsWith("video/")) {
                    videoFormat = fmt
                    vEx.selectTrack(i)
                    break
                }
            }

            val aEx = android.media.MediaExtractor()
            audioExtractor = aEx
            aEx.setDataSource(audioPath)
            var audioFormat: android.media.MediaFormat? = null
            for (i in 0 until aEx.trackCount) {
                val fmt = aEx.getTrackFormat(i)
                val mime = fmt.getString(android.media.MediaFormat.KEY_MIME) ?: ""
                if (mime.startsWith("audio/")) {
                    audioFormat = fmt
                    aEx.selectTrack(i)
                    break
                }
            }

            if (videoFormat == null || audioFormat == null) {
                return false
            }
            // 提到不可变局部量：下面有局部函数（copyTrack），可变捕获变量无法智能转换
            val vFmt = videoFormat
            val aFmt = audioFormat

            val muxVideo = mux.addTrack(vFmt)
            val muxAudio = mux.addTrack(aFmt)
            mux.start()
            started = true

            fun copyTrack(
                extractor: android.media.MediaExtractor,
                trackIndex: Int,
            ) {
                val buffer = java.nio.ByteBuffer.allocate(1024 * 1024)
                val info = android.media.MediaCodec.BufferInfo()
                while (true) {
                    info.size = extractor.readSampleData(buffer, 0)
                    if (info.size < 0) break
                    info.presentationTimeUs = extractor.sampleTime
                    info.flags = extractor.sampleFlags
                    mux.writeSampleData(trackIndex, buffer, info)
                    extractor.advance()
                }
            }

            copyTrack(vEx, muxVideo)
            copyTrack(aEx, muxAudio)

            mux.stop()
            started = false
            mux.release()
            muxer = null
            vEx.release()
            videoExtractor = null
            aEx.release()
            audioExtractor = null

            File(videoPath).delete()
            File(audioPath).delete()
            true
        } catch (e: Throwable) {
            // 连 Error 一起兜：合并失败要让 Dart 侧拿到 false 去删中间文件，
            // 不能让异常逃到通道线程（且旧代码只捕 Exception）
            Log.w("MainActivity", "mergeM4s failed: ${e.message}")
            false
        } finally {
            // stop() 在「没写过任何样本」时会抛 → 静默兜住，release() 必须执行
            if (started) runCatching { muxer?.stop() }
            runCatching { muxer?.release() }
            runCatching { videoExtractor?.release() }
            runCatching { audioExtractor?.release() }
        }
    }

    /**
     * 触发系统媒体库扫描单个文件（下载产物写盘后调用，工作.md 第 5 点）。
     * MediaStore 对 dart:io / MediaMuxer 直写的文件不会立即抽取元数据，
     * 不主动扫描会导致列表里 duration=0（进度条/百分比显示「未观看」）。
     */
    private fun scanMediaFile(path: String) {
        try {
            MediaScannerConnection.scanFile(
                this,
                arrayOf(path),
                null,
            ) { _, _ -> }
        } catch (e: Exception) {
            Log.w("MainActivity", "scanMediaFile failed: ${e.message}")
        }
    }

    // ── 错误日志（崩溃日志自动记录）────────────────────────

    /** 日志目录：files/crash_logs/ */
    private fun logDir(): File = CrashHandler.logDir(this)

    /** 日志文件判定：原生崩溃日志 *.txt 与 Dart 侧 flutter_*.log 均计入 */
    private fun isLogFile(name: String): Boolean =
        name.endsWith(".txt") || name.endsWith(".log")

    /** 列出全部日志文件（按修改时间倒序；.txt 与 .log 都算） */
    private fun listLogs(): List<Map<String, Any>> {
        val dir = logDir()
        if (!dir.exists() || !dir.isDirectory) return emptyList()
        return dir.listFiles()
            ?.filter { it.isFile && isLogFile(it.name) }
            ?.sortedByDescending { it.lastModified() }
            ?.map { f ->
                mapOf(
                    "name" to f.name,
                    "path" to f.absolutePath,
                    "size" to f.length(),
                    "lastModified" to f.lastModified(),
                )
            }
            ?: emptyList()
    }

    /** 读取日志文件内容（UTF-8，失败返回错误信息） */
    private fun readLog(path: String): String {
        return try {
            File(path).readText()
        } catch (e: Exception) {
            "读取日志失败：${e.message}"
        }
    }

    /** 删除单个日志文件 */
    private fun deleteLog(path: String): Boolean {
        return try {
            File(path).delete()
        } catch (e: Exception) {
            false
        }
    }

    /** 清空全部日志（与 listLogs 同一过滤规则：.txt 与 .log 都清） */
    private fun clearLogs(): Boolean {
        return try {
            val dir = logDir()
            if (!dir.exists() || !dir.isDirectory) return true
            var ok = true
            dir.listFiles()?.forEach { f ->
                if (f.isFile && isLogFile(f.name) && !f.delete()) ok = false
            }
            ok
        } catch (e: Exception) {
            false
        }
    }

    /**
     * 导出日志到系统公共 Download 目录（App 有「管理所有文件」权限，
     * 可直写 /storage/emulated/0/Download/moumou_logs/），返回新路径。
     */
    private fun exportLog(path: String): String? {
        return try {
            val src = File(path)
            if (!src.exists()) return null
            val downloads =
                android.os.Environment.getExternalStoragePublicDirectory(
                    android.os.Environment.DIRECTORY_DOWNLOADS
                )
            val outDir = File(downloads, "moumou_logs")
            if (!outDir.exists()) outDir.mkdirs()
            val dst = File(outDir, src.name)
            src.copyTo(dst, overwrite = true)
            dst.absolutePath
        } catch (e: Exception) {
            null
        }
    }

    /**
     * Dart 侧未捕获异常日志：写入 `files/crash_logs/flutter_yyyy-MM-dd.log`，
     * 与原生崩溃日志同一目录（错误日志页统一展示）。
     */
    private fun appendDartLog(content: String) {
        try {
            val dir = logDir()
            if (!dir.exists()) dir.mkdirs()
            val timestamp = java.text.SimpleDateFormat(
                "yyyy-MM-dd", java.util.Locale.getDefault()
            ).format(java.util.Date())
            val file = File(dir, "flutter_$timestamp.log")
            file.appendText("\n$content\n")
        } catch (e: Exception) {
            Log.w("DartLog", "appendDartLog failed: ${e.message}")
        }
    }

    // ── 画中画（小窗播放）────────────────────────

    /** 设备是否支持画中画（API 26+ 且系统具备该特性） */
    private fun isPipSupported(): Boolean {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)
    }

    /**
     * 进入画中画小窗；宽高比由调用方传入（默认 16:9）。
     * 已在画中画时直接返回 true；不支持时返回 false。
     * （内联 SDK 判断：让 lint NewApi 能识别 API 26+ 调用路径）
     */
    private fun enterPip(aspectWidth: Int, aspectHeight: Int): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        if (!isPipSupported()) return false
        if (isInPictureInPictureMode) return true
        val params = PictureInPictureParams.Builder()
            .setAspectRatio(Rational(aspectWidth.coerceAtLeast(1), aspectHeight.coerceAtLeast(1)))
            .build()
        return enterPictureInPictureMode(params)
    }

    /**
     * 设置「返回桌面/上滑手势时自动进入画中画」（仅 API 31+ 生效，
     * 旧系统静默忽略，返回桌面即为普通退后台）。
     */
    private fun setAutoPipEnabled(enabled: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && isPipSupported()) {
            val params = PictureInPictureParams.Builder()
                .setAutoEnterEnabled(enabled)
                .build()
            setPictureInPictureParams(params)
        }
    }

    // ── 整应用重启（解码配置修改后一键重启，工作.md 迁移功能）────────

    /**
     * 重启整个应用：拉新任务的启动 Intent（清空返回栈）并结束当前进程。
     * 对齐老项目 `PlaybackSettingsScreen` 的解码配置一键重启机制
     * （拉新 Task 清栈重启，而非仅重建 Activity）。
     */
    private fun restartApp() {
        try {
            val launch = packageManager.getLaunchIntentForPackage(packageName)
                ?: return
            launch.addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TASK
            )
            startActivity(launch)
        } catch (e: Exception) {
            Log.w("MainActivity", "restartApp failed: ${e.message}")
        }
        // 结束当前进程（拉起新 Task 后再退出，保证应用确实重启）
        android.os.Process.killProcess(android.os.Process.myPid())
        exitProcess(0)
    }

    // ── 动态色（壁纸取色，Material You）────────────────

    /**
     * 动态色（壁纸取色，Material You）：提取系统壁纸的主色/次色/第三色。
     * 需 API 27+（WallpaperColors）且壁纸可读；失败返回 null（Dart 侧降级）。
     * 返回 {primary, secondary, tertiary} 三个 ARGB int；任一项缺失都视为失败。
     */
    private fun getWallpaperColors(): Map<String, Any>? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O_MR1) return null
        return try {
            val wm = WallpaperManager.getInstance(this)
            // 官方推荐：getWallpaperColors(FLAG_SYSTEM) 直接返回 WallpaperColors，
            // 不经过 getDrawable() 读壁纸图片。用 getDrawable 在部分 OEM（ColorOS/OPPO）
            // 会触发 READ_EXTERNAL_STORAGE 权限检查导致取色失败（真机日志已确认）。
            val colors = try {
                wm.getWallpaperColors(WallpaperManager.FLAG_SYSTEM)
            } catch (_: Exception) {
                null
            } ?: run {
                // 兜底：某些壁纸（如第三方动态壁纸）getWallpaperColors 返回 null，
                // 退回读 drawable 再解析（仅作最后手段，仍可能受权限限制）
                val drawable: Drawable = wm.drawable ?: return null
                @Suppress("DEPRECATION")
                android.app.WallpaperColors.fromDrawable(drawable)
            }
            val primary = colors.primaryColor
            val secondary = colors.secondaryColor
            val tertiary = colors.tertiaryColor
            if (primary == null && secondary == null && tertiary == null) return null
            mapOf(
                "primary" to (primary?.toArgb() ?: android.graphics.Color.TRANSPARENT),
                "secondary" to (secondary?.toArgb() ?: android.graphics.Color.TRANSPARENT),
                "tertiary" to (tertiary?.toArgb() ?: android.graphics.Color.TRANSPARENT),
            )
        } catch (e: Exception) {
            Log.w("MainActivity", "getWallpaperColors failed: ${e.message}")
            null
        }
    }

    // ── 音量（系统媒体音量，0 – 100 百分比）────────────────

    private fun getSystemVolume(): Double {
        val am = getSystemService(AUDIO_SERVICE) as AudioManager
        val max = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        return if (max > 0) {
            am.getStreamVolume(AudioManager.STREAM_MUSIC).toDouble() / max * 100.0
        } else {
            0.0
        }
    }

    /** 写入系统媒体音量（0 – 100）；[AudioManager.setStreamVolume] 需 MODIFY_AUDIO_SETTINGS（normal 权限） */
    private fun setSystemVolume(percent: Double) {
        val am = getSystemService(AUDIO_SERVICE) as AudioManager
        val max = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        if (max <= 0) return
        val target = (percent.coerceIn(0.0, 100.0) / 100.0 * max).toInt().coerceIn(0, max)
        am.setStreamVolume(AudioManager.STREAM_MUSIC, target, 0)
    }

    // ── 亮度（窗口亮度，只影响当前 Activity，无需任何权限）──

    /**
     * 读取当前有效亮度：窗口已设亮度优先，否则读系统亮度。
     * 返回 0 – 1；读取失败返回 -1（表示未知，调用方按系统默认处理）。
     */
    private fun getBrightness(): Double {
        val attrs = window.attributes
        if (attrs.screenBrightness >= 0f) return attrs.screenBrightness.toDouble()
        return try {
            Settings.System.getInt(
                contentResolver,
                Settings.System.SCREEN_BRIGHTNESS,
            ).toDouble() / 255.0
        } catch (e: Exception) {
            -1.0
        }
    }

    /** 设置窗口亮度（0 – 1）；传 < 0 恢复系统默认。退出播放后必须恢复。 */
    private fun setWindowBrightness(value: Double) {
        val attrs = window.attributes
        attrs.screenBrightness = if (value < 0) -1f else value.toFloat().coerceIn(0f, 1f)
        window.attributes = attrs
    }

    // ── 电量（播放界面顶部信息行，工作.md 第 12 点）──────────

    /**
     * 读取当前电池电量百分比（0 – 100）。
     * BatteryManager.BATTERY_PROPERTY_CAPACITY 无需任何权限（API 21+）；
     * 异常时返回 -1，Dart 侧按「未知」隐藏电量显示。
     */
    private fun getBatteryLevel(): Int {
        return try {
            val bm = getSystemService(BATTERY_SERVICE) as? BatteryManager
            bm?.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY) ?: -1
        } catch (e: Exception) {
            -1
        }
    }

    // ── 网络类型（播放界面顶部「数据类型」图标，工作.md 阶段1 第 1 点）────

    /**
     * 读取当前活动网络类型：返回 "wifi" / "cellular" / "ethernet" / "none"。
     * 需 ACCESS_NETWORK_STATE（normal 权限，安装即授予）；异常/无网络返回 "none"。
     */
    private fun getNetworkType(): String {
        return try {
            val cm = getSystemService(CONNECTIVITY_SERVICE) as? ConnectivityManager
                ?: return "none"
            val network = cm.activeNetwork ?: return "none"
            val caps = cm.getNetworkCapabilities(network) ?: return "none"
            when {
                caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "wifi"
                caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "cellular"
                caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> "ethernet"
                else -> "none"
            }
        } catch (e: Exception) {
            "none"
        }
    }

    // ── 系统「自动旋转」开关（播放界面跟随手机方向）────────────

    /**
     * 系统「自动旋转」是否开启（`Settings.System.ACCELEROMETER_ROTATION`）。
     *
     * 只读系统设置，无需任何权限。返回 1 = 开启、0 = 关闭、-1 = 读取失败
     * （Dart 侧把 -1 当「未知」，保留上一次的缓存值）。
     *
     * 播放页用它判断「跟随手机方向」是否生效：系统自动旋转关闭时系统根本
     * 不会随重力转窗口，跟随只会退化成「固定在当前方向」，因此回落到
     * 「按视频方向」的原行为。
     */
    private fun isAutoRotateEnabled(): Int {
        return try {
            Settings.System.getInt(
                contentResolver,
                Settings.System.ACCELEROMETER_ROTATION,
                -1,
            )
        } catch (e: Exception) {
            -1
        }
    }

    // ── 听视频后台播放（前台服务保活，工作.md 阶段1 第 2 点）──────

    /**
     * 启动后台播放前台服务（保活进程，使 mpv 音频在退后台后继续播放）。
     * Android 13+ 会先请求通知权限（未授予不影响服务运行，仅不显示通知）。
     */
    private fun startBackgroundPlayback(title: String) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                if (checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS)
                    != PackageManager.PERMISSION_GRANTED
                ) {
                    requestPermissions(
                        arrayOf(android.Manifest.permission.POST_NOTIFICATIONS),
                        2001,
                    )
                }
            }
            BackgroundPlaybackService.createNotificationChannel(this)
            val intent = Intent(this, BackgroundPlaybackService::class.java)
                .putExtra("media_title", title)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
        } catch (e: Exception) {
            Log.w("MainActivity", "startBackgroundPlayback failed: ${e.message}")
        }
    }

    /** 停止后台播放前台服务（退出听视频界面时调用） */
    private fun stopBackgroundPlayback() {
        try {
            stopService(Intent(this, BackgroundPlaybackService::class.java))
        } catch (e: Exception) {
            Log.w("MainActivity", "stopBackgroundPlayback failed: ${e.message}")
        }
    }

    // ── 字幕功能（工作.md 阶段1 第 3 点）────────────────────
    //
    // ⚠️ 下面这些 MIME 白名单一律用行注释写：白名单里会出现「星号 + 斜杠」的通配
    //   写法，放进 /* */ 块注释里会被当成注释结束符，把后面的代码整段吃掉
    //   （构建报「Syntax error: Missing '}'」的根因）。

    // 外挂字幕文件选择器的 MIME 白名单：
    // 放宽到 text 系 + application 系 + 全类型通配——系统选择器（DocumentsUI）会把
    // **不在** EXTRA_MIME_TYPES 里的文件置灰，而同一扩展名在不同 ROM/Provider 上
    // 可能报成完全不同的 MIME（.ass 可能是 text/x-ssa，.sub 可能是
    // text/vnd.dvb.subtitle，甚至 application/octet-stream）。内容校验交给导入
    // 那一侧（解析失败会提示「导入失败，请检查文件格式」），选择器只求「不误置灰」。
    // 参考项目小喵 player 的 SAF 白名单同样是 text 系 + application 系 + 全类型通配。
    private val subtitlePickerMimeTypes = arrayOf(
        "text/*",
        "application/*",
        "*/*",
    )

    // 本地弹幕文件选择器的 MIME 白名单（**必须与字幕分开**）：
    // .xml 的 MIME 是 text/xml（Android MimeTypeMap 把 xml 映射到 text/xml），
    // 以前弹幕复用字幕白名单（里面没有 xml 的两种 MIME），系统选择器把 XML 弹幕
    // 全部置灰、用户根本选不中（用户反馈：Android 11 上导入本地弹幕选不中文件）。
    private val danmakuPickerMimeTypes = arrayOf(
        "text/xml",
        "application/xml",
        "text/*",
        "application/*",
        "*/*",
    )

    /** 字体选择器的 MIME 白名单（含 font 类型，避免系统选择器把 .ttf/.otf 置灰） */
    private val fontPickerMimeTypes = arrayOf(
        "font/ttf",
        "font/otf",
        "font/sfnt",
        "font/collection",
        "application/x-font-ttf",
        "application/x-font-otf",
        "application/x-font-truetype",
        "application/vnd.ms-opentype",
        "application/octet-stream",
    )

    // 音频选择器的 MIME 白名单（工作.md 音频功能：.mp3/.m4a/.flac 等不置灰）：
    // 同样带上全类型通配——部分 ROM 把 .m4a 报成 video/mp4、把无损格式报成
    // application/octet-stream，白名单窄了就会被置灰。
    private val audioPickerMimeTypes = arrayOf(
        "audio/*",
        "application/octet-stream",
        "*/*",
    )

    // 壁纸图片选择器的 MIME 白名单（Android 13 以下走 SAF；.png/.jpg/.webp/.heic
    // 等不置灰——部分 ROM 会把图片报成 application/octet-stream，白名单窄了会被置灰）
    private val imagePickerMimeTypes = arrayOf(
        "image/*",
        "application/octet-stream",
        "*/*",
    )

    /**
     * 系统文件选择器 Intent（ACTION_OPEN_DOCUMENT，无需权限）。
     * @param mimeTypes 允许选择的文件类型白名单（默认字幕类型）。
     */
    private fun buildDocumentPickerIntent(
        mimeTypes: Array<String> = subtitlePickerMimeTypes,
    ): Intent {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT)
        intent.type = "*/*"
        intent.putExtra(Intent.EXTRA_MIME_TYPES, mimeTypes)
        intent.addCategory(Intent.CATEGORY_OPENABLE)
        intent.addFlags(
            Intent.FLAG_GRANT_READ_URI_PERMISSION or
                Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
        )
        return intent
    }

    /**
     * 壁纸图片选择器的候选 Intent，按优先级排列：
     * 1. Android 13+ 的系统 **Photo Picker**（`ACTION_PICK_IMAGES`，缩略图网格）；
     * 2. SAF（`ACTION_OPEN_DOCUMENT` + 图片 MIME 白名单，DocumentsUI）；
     * 3. `ACTION_GET_CONTENT`（相册 / 文件管理器，任何 Android 都有承接方）。
     *
     * Photo Picker 是**可选模块**：模拟器 / 精简 ROM 上可能根本没有这个 Activity
     * （用户实测 MuMu 上点了没反应——`startActivityForResult` 直接抛
     * ActivityNotFoundException）。所以这里不写死一个，而是列候选、依次尝试启动。
     *
     * 注意：KDoc 里**不能**写 `image` 加斜杠加星号那种 MIME 通配——Kotlin 的块注释
     * 可以嵌套，那个斜杠星号会开一层新注释，把后面整个文件吞掉（踩过一次）。
     */
    private fun buildImagePickerIntents(): List<Intent> {
        val intents = mutableListOf<Intent>()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intents.add(
                Intent(MediaStore.ACTION_PICK_IMAGES).apply {
                    type = "image/*"
                    putExtra(MediaStore.EXTRA_PICK_IMAGES_MAX, 1)
                }
            )
        }
        intents.add(buildDocumentPickerIntent(imagePickerMimeTypes))
        intents.add(
            Intent(Intent.ACTION_GET_CONTENT).apply {
                type = "image/*"
                addCategory(Intent.CATEGORY_OPENABLE)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
        )
        return intents
    }

    /**
     * 依次尝试候选 Intent，**启动成功即返回 true**；某个候选没有承接方
     * （`ActivityNotFoundException`，例如模拟器缺 Photo Picker 模块）就试下一个。
     *
     * 为什么不用 `resolveActivity` 预判：Android 11+ 的**包可见性**会让未在
     * `<queries>` 里声明的隐式 Intent 查不到承接方（返回 null），预判会把真机上
     * 明明能用的选择器误判成「没有」。直接试启动最可靠。
     */
    private fun launchImagePicker(candidates: List<Intent>, requestCode: Int): Boolean {
        for (intent in candidates) {
            try {
                startActivityForResult(intent, requestCode)
                return true
            } catch (e: ActivityNotFoundException) {
                Log.i("MainActivity", "image picker candidate unavailable: ${intent.action}")
            } catch (e: Exception) {
                Log.w("MainActivity", "image picker launch failed: ${e.message}")
            }
        }
        return false
    }

    /**
     * 系统目录选择器 Intent（ACTION_OPEN_DOCUMENT_TREE，无需权限）。
     * 带上读/写 + 持久化 + 前缀授权标志，便于 takePersistableUriPermission。
     */
    private fun buildOpenDocumentTreeIntent(): Intent {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
        intent.addFlags(
            Intent.FLAG_GRANT_READ_URI_PERMISSION or
                Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or
                Intent.FLAG_GRANT_PREFIX_URI_PERMISSION,
        )
        return intent
    }

    /**
     * 打开哔哩哔哩客户端自动扫码（工作.md 阶段一）：
     * 把扫码登录 url 包进 `bilibili://browser` 深链，直接 startActivity 拉起
     * （未安装/无 App 处理时抛 ActivityNotFoundException → 返回 false）。
     * 不用 queryIntentActivities 预检测：Android 11+ 包可见性下易误判为空。
     */
    private fun openBilibiliScan(url: String): Boolean {
        return try {
            val deepLink =
                "bilibili://browser?url=${java.net.URLEncoder.encode(url, "UTF-8")}"
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(deepLink))
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            true
        } catch (e: Exception) {
            Log.w("MainActivity", "openBilibiliScan failed: ${e.message}")
            false
        }
    }

    /** 系统文件选择器结果回传（content:// uri 字符串或 null） */
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        when (requestCode) {
            2002 -> {
                val pending = pendingDocumentPickerResult
                pendingDocumentPickerResult = null
                val uri = if (resultCode == Activity.RESULT_OK) data?.data?.toString() else null
                pending?.success(uri)
            }
            2003 -> {
                val pending = pendingFontDirPickerResult
                pendingFontDirPickerResult = null
                val uri = if (resultCode == Activity.RESULT_OK) data?.data else null
                if (uri != null) {
                    // 持久化目录读权限，否则重启后 tree uri 失效无法刷新
                    try {
                        contentResolver.takePersistableUriPermission(
                            uri, Intent.FLAG_GRANT_READ_URI_PERMISSION
                        )
                    } catch (e: Exception) {
                        Log.w("MainActivity", "takePersistableUriPermission failed: ${e.message}")
                    }
                }
                pending?.success(uri?.toString())
            }
            // 2005 = 壁纸图片选择器：选中即刻拷进私有目录，回传真实路径（取消回 null）
            2005 -> {
                val pending = pendingDocumentPickerResult
                pendingDocumentPickerResult = null
                // Photo Picker / SAF 都从 data.data 给 uri；个别实现只给 clipData，
                // 兜一下（单选用第一项）
                val uri = if (resultCode == Activity.RESULT_OK) {
                    data?.data ?: data?.clipData?.getItemAt(0)?.uri
                } else {
                    null
                }
                if (uri == null) {
                    pending?.success(null)
                } else {
                    val name = queryDisplayName(uri) ?: "wallpaper.png"
                    pending?.success(copyWallpaperFromUri(uri, name))
                }
            }
        }
    }

    /** 运行时权限结果回传（本地网络权限 ACCESS_LOCAL_NETWORK） */
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 2004) {
            val pending = pendingLocalNetworkResult
            pendingLocalNetworkResult = null
            val granted = grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            pending?.success(granted)
        }
    }

    /**
     * 列举目录内容（自建文件选择器用）：
     * 返回 name/path/isDirectory/size/modifiedMs 列表（排序在 Dart 侧完成）。
     * 目录不存在 / 不可读 / IO 错误返回 **null**（区别于真实存在的空目录），
     * 供选择器识别死路径并向上回退（小喵 player 记忆路径失效卡死的教训）。
     */
    private fun listDirectory(path: String): List<Map<String, Any>>? {
        val dir = File(path)
        if (!dir.exists() || !dir.isDirectory) return null
        return try {
            val files = dir.listFiles() ?: return null
            files.sortedBy { it.name.lowercase() }.map { f ->
                mapOf(
                    "name" to f.name,
                    "path" to f.absolutePath,
                    "isDirectory" to f.isDirectory,
                    "size" to (if (f.isFile) f.length() else 0L),
                    "modifiedMs" to f.lastModified(),
                )
            }
        } catch (e: Exception) {
            null
        }
    }

    /**
     * 存储卷根列表（自建文件选择器的「卷跳转」入口用）：
     * 返回 name/path/isPrimary/isRemovable，内部存储恒排第一。
     *
     * 走 `StorageManager.storageVolumes`（API 24+ 官方枚举接口，无需权限），
     * 路径优先 `StorageVolume.directory`（API 30+，未挂载时为 null）；API 30
     * 以下回退到隐藏的 `getPath()` 反射，再不行用 uuid 拼 `/storage/<uuid>`。
     * **不列 `/storage` 目录本身**——该目录在 Android 11+ 上即使持有
     * 「所有文件访问」也列不出来（授权只到各卷根），这正是「无法去往 TF 卡」
     * 的根因（用户反馈 issue #3）。
     *
     * 只返回 `MEDIA_MOUNTED` 且路径真实存在的卷；枚举失败返回空列表
     * （Dart 侧隐藏卷跳转行，行为退回「只能浏览内部存储」，不报错、不崩）。
     */
    private fun getStorageRoots(): List<Map<String, Any>> {
        return try {
            val manager = getSystemService(STORAGE_SERVICE) as? StorageManager
                ?: return emptyList()
            val roots = mutableListOf<Map<String, Any>>()

            for (volume in manager.storageVolumes) {
                if (volume.state != Environment.MEDIA_MOUNTED) continue
                val path = storageVolumePath(volume) ?: continue
                if (path.isEmpty() || !File(path).exists()) continue

                val isPrimary = volume.isPrimary
                val label = storageVolumeLabel(volume, isPrimary)

                roots.add(
                    mapOf(
                        "name" to label,
                        "path" to path,
                        "isPrimary" to isPrimary,
                        "isRemovable" to volume.isRemovable,
                    )
                )
            }

            // 内部存储恒排第一（卷跳转行顺序稳定，不随 ROM 返回顺序抖动）
            roots.sortedByDescending { it["isPrimary"] == true }
        } catch (e: Exception) {
            // 个别 ROM 的 StorageManager 异常：返回空表，选择器退回默认行为
            Log.w("MainActivity", "getStorageRoots failed: ${e.message}")
            emptyList()
        }
    }

    /** 取存储卷的展示名（系统描述优先，失败回退「内部存储 / SD 卡」） */
    private fun storageVolumeLabel(
        volume: StorageVolume,
        isPrimary: Boolean,
    ): String {
        return try {
            volume.getDescription(this)
        } catch (_: Exception) {
            null
        } ?: if (isPrimary) "内部存储" else "SD 卡"
    }

    /** 取存储卷的真实挂载路径（内部存储统一收敛到规范路径） */
    private fun storageVolumePath(volume: StorageVolume): String? {
        val directory = storageVolumeDirectory(volume)

        // 内部存储统一成 Environment 的规范路径：个别 ROM 的 volume.directory
        // 会给出 /storage/self/primary 这类别名，与扫描器产出的路径不一致，
        // 会导致「卷跳转后当前目录高亮不中」
        if (volume.isPrimary) {
            @Suppress("DEPRECATION")
            return Environment.getExternalStorageDirectory()?.absolutePath
                ?: directory?.absolutePath
        }
        directory?.absolutePath?.let { return it }

        // 最后兜底：uuid 即 /storage/<uuid> 的卷名（SD 卡为 XXXX-XXXX）
        return volume.uuid?.let { uuid ->
            val candidate = File("/storage/$uuid")
            if (candidate.exists()) candidate.absolutePath else null
        }
    }

    /** 卷挂载目录：API 30+ 公开接口，以下回退到隐藏的 `getPath()` 反射 */
    private fun storageVolumeDirectory(
        volume: StorageVolume,
    ): File? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            return storageVolumeDirectoryApi30(volume)
        }
        return try {
            volume.javaClass.getMethod("getPath").invoke(volume) as? File
        } catch (_: Exception) {
            null
        }
    }

    @android.annotation.TargetApi(Build.VERSION_CODES.R)
    private fun storageVolumeDirectoryApi30(
        volume: StorageVolume,
    ): File? = volume.directory

    /**
     * 系统字体列表（字幕字体设置用）：扫描 /system/fonts 下的 .ttf/.otf/.ttc
     * 文件，返回去重后的字体名（文件主名，如 "NotoSansCJK"）。失败返回空列表。
     */
    private fun getSystemFonts(): List<String> {
        val dir = File("/system/fonts")
        if (!dir.exists() || !dir.isDirectory) return emptyList()
        return try {
            dir.listFiles()
                ?.map { it.name }
                ?.filter { n ->
                    val lower = n.lowercase()
                    lower.endsWith(".ttf") || lower.endsWith(".otf") ||
                        lower.endsWith(".ttc")
                }
                ?.map { n -> n.substringBeforeLast('.') }
                ?.distinct()
                ?.sorted()
                ?: emptyList()
        } catch (e: Exception) {
            emptyList()
        }
    }

    /**
     * 把 content:// 字幕 uri 拷贝到 filesDir/subtitles/<name>（libmpv 无法直接
     * 读 content://，参考小喵 player SubtitleManager.copyContentUriToFile），
     * 返回真实绝对路径；失败返回 null。
     */
    private fun copySubtitleFromUri(uriString: String, name: String): String? {
        return try {
            val uri = Uri.parse(uriString)
            val subtitleDir = File(filesDir, "subtitles")
            if (!subtitleDir.exists()) subtitleDir.mkdirs()
            val safeName = name.replace(Regex("[^a-zA-Z0-9.\\-_]|\\s"), "_")
            val target = File(subtitleDir, "${uri.hashCode()}_$safeName")
            contentResolver.openInputStream(uri)?.use { input ->
                target.outputStream().use { output -> input.copyTo(output) }
            }
            if (target.exists() && target.length() > 0) target.absolutePath else null
        } catch (e: Exception) {
            Log.w("MainActivity", "copySubtitleFromUri failed: ${e.message}")
            null
        }
    }

    /**
     * 把 content:// 音轨 uri 拷贝到 filesDir/audio/<name>（libmpv 无法直接读
     * content://，工作.md 音频功能：外部音轨临时、退出播放后不再引用），
     * 返回真实绝对路径；失败返回 null。
     */
    private fun copyAudioFromUri(uriString: String, name: String): String? {
        return try {
            val uri = Uri.parse(uriString)
            val audioDir = File(filesDir, "audio")
            if (!audioDir.exists()) audioDir.mkdirs()
            // 优先用真实文件名（DISPLAY_NAME），回退到 Dart 传入的 name
            val displayName = queryDisplayName(uri) ?: name
            val safeName = displayName.replace(Regex("[^a-zA-Z0-9.\\-_]|\\s"), "_")
            val target = File(audioDir, "${uri.hashCode()}_$safeName")
            contentResolver.openInputStream(uri)?.use { input ->
                target.outputStream().use { output -> input.copyTo(output) }
            }
            if (target.exists() && target.length() > 0) target.absolutePath else null
        } catch (e: Exception) {
            Log.w("MainActivity", "copyAudioFromUri failed: ${e.message}")
            null
        }
    }

    /**
     * 把 content:// 弹幕 uri 拷贝到 filesDir/danmaku/<name>（弹幕 XML 解析走
     * dart:io，无法直接读 content://，弹幕功能阶段1），
     * 返回真实绝对路径；失败返回 null。
     */
    private fun copyDanmakuFromUri(uriString: String, name: String): String? {
        return try {
            val uri = Uri.parse(uriString)
            val danmakuDir = File(filesDir, "danmaku")
            if (!danmakuDir.exists()) danmakuDir.mkdirs()
            // 优先用真实文件名（DISPLAY_NAME），回退到 Dart 传入的 name
            val displayName = queryDisplayName(uri) ?: name
            val safeName = displayName.replace(Regex("[^a-zA-Z0-9.\\-_]|\\s"), "_")
            val target = File(danmakuDir, "${uri.hashCode()}_$safeName")
            contentResolver.openInputStream(uri)?.use { input ->
                target.outputStream().use { output -> input.copyTo(output) }
            }
            if (target.exists() && target.length() > 0) target.absolutePath else null
        } catch (e: Exception) {
            Log.w("MainActivity", "copyDanmakuFromUri failed: ${e.message}")
            null
        }
    }

    /**
     * 把 content:// 字体文件（.ttf/.otf）拷贝到 filesDir/fonts/<name>，返回真实绝对路径。
     * 用户自导入字幕字体用（工作.md 阶段1 第 3 点：字幕字体支持自导入）。
     */
    private fun copyFontFromUri(uriString: String, name: String): String? {
        return try {
            val uri = Uri.parse(uriString)
            val fontDir = File(filesDir, "fonts")
            if (!fontDir.exists()) fontDir.mkdirs()
            // 优先用真实文件名（DISPLAY_NAME），回退到 Dart 传入的 name
            // （后者可能是 document ID 而非文件名，如 "msf%3A..."）。
            val displayName = queryDisplayName(uri) ?: name
            val safeName = displayName.replace(Regex("[^a-zA-Z0-9.\\-_]|\\s"), "_")
            val target = File(fontDir, safeName)
            contentResolver.openInputStream(uri)?.use { input ->
                target.outputStream().use { output -> input.copyTo(output) }
            }
            if (target.exists() && target.length() > 0) target.absolutePath else null
        } catch (e: Exception) {
            Log.w("MainActivity", "copyFontFromUri failed: ${e.message}")
            null
        }
    }

    /**
     * 系统图片选择器选中的图拷进应用**导入目录**（`filesDir/wallpaper_import/`），
     * 返回真实绝对路径；失败返回 null。
     *
     * 为什么不直接写进壁纸目录：壁纸文件的最终位置与命名（时间戳 + 参数落盘）
     * 统一由 Dart 侧 [WallpaperSettings] 管，这里只负责把 `content://` 变成
     * 真实路径（Dart 读不了 content://）。每次选择前清空导入目录，只留本次这张，
     * 保存成功后 Dart 侧会把这张临时文件删掉。
     */
    private fun copyWallpaperFromUri(uri: Uri, name: String): String? {
        return try {
            val importDir = File(filesDir, "wallpaper_import")
            if (importDir.exists()) {
                importDir.listFiles()?.forEach { it.delete() }
            } else {
                importDir.mkdirs()
            }
            // 优先真实文件名（DISPLAY_NAME），回退 Dart 传/默认名；不确定的字符换下划线
            val displayName = queryDisplayName(uri) ?: name
            val safeName = displayName.replace(Regex("[^a-zA-Z0-9.\\-_]|\\s"), "_")
            val target = File(importDir, "pick_$safeName")
            contentResolver.openInputStream(uri)?.use { input ->
                target.outputStream().use { output -> input.copyTo(output) }
            }
            if (target.exists() && target.length() > 0) target.absolutePath else null
        } catch (e: Exception) {
            Log.w("MainActivity", "copyWallpaperFromUri failed: ${e.message}")
            null
        }
    }

    /** 查询 content:// 的真实显示文件名（DISPLAY_NAME），失败返回 null。 */
    private fun queryDisplayName(uri: Uri): String? {
        return try {
            contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                val idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (idx >= 0 && cursor.moveToFirst()) cursor.getString(idx) else null
            }
        } catch (e: Exception) {
            null
        }
    }

    /**
     * 把文件路径的字体文件（.ttf/.otf/.ttc）拷贝到 filesDir/fonts/<name>，返回真实绝对路径。
     * 自建选择器选择字体后安全复制到私有目录，确保 libass 始终能读取。
     */
    private fun copyFontFromFile(sourcePath: String, name: String): String? {
        return try {
            val src = File(sourcePath)
            if (!src.exists()) return null
            val fontDir = File(filesDir, "fonts")
            if (!fontDir.exists()) fontDir.mkdirs()
            val safeName = name.replace(Regex("[^a-zA-Z0-9.\\-_]|\\s"), "_")
            val target = File(fontDir, safeName)
            src.copyTo(target, overwrite = true)
            if (target.exists() && target.length() > 0) target.absolutePath else null
        } catch (e: Exception) {
            Log.w("MainActivity", "copyFontFromFile failed: ${e.message}")
            null
        }
    }

    private fun ensureFallbackFont(fontsDir: File) {
        try {
            val systemCandidates = listOf(
                File("/system/fonts/NotoSansCJK-Regular.ttc"),
                File("/system/fonts/NotoSansSC-Regular.otf"),
                File("/system/fonts/NotoSansHans-Regular.otf"),
                File("/system/fonts/DroidSansFallback.ttf")
            )
            for (candidate in systemCandidates) {
                if (!candidate.exists() || !candidate.canRead()) continue
                val target = File(fontsDir, candidate.name)
                if (target.exists() && target.length() > 0) return
                try {
                    // 直接复制系统字库（不用 symlink + 隐藏文件名）：
                    // fontconfig 可能跳过 `.` 开头的隐藏文件、且不 follow symlink，
                    // 导致兜底字体不被识别 → sub-fonts-dir 指向私有目录后
                    // ASS 字幕整条空白。复制成普通文件名可被 fontconfig 稳定识别。
                    candidate.copyTo(target, overwrite = true)
                    return
                } catch (_: Exception) {}
            }
        } catch (e: Exception) {
            Log.w("MainActivity", "ensureFallbackFont failed: ${e.message}")
        }
    }

    /**
     * 读取字体文件的内部家族名（family name，name 表 nameID=1 / 16 / 4）。
     * libass 的 sub-font / ASS 样式 Fontname 均按家族名匹配。
     * 支持 TTF/OTF/TTC（TTC 取第一个 face）；解析失败返回文件名无后缀。
     */
    /**
     * 读取字体文件的家族名（family name），用 truetypeparser（对齐小喵 player）。
     * libass 的 sub-font / ASS 样式 Fontname 均按家族名匹配。
     * 解析失败返回文件名无后缀。
     */
    private fun getFontFamilyName(fontPath: String): String {
        return try {
            val file = File(fontPath)
            if (!file.exists() || file.length() < 12) return ""
            val family = file.inputStream().use { input ->
                TTFFile.open(input).families.values.firstOrNull()
            }
            family?.ifBlank { null } ?: file.nameWithoutExtension
        } catch (e: Exception) {
            Log.w("MainActivity", "getFontFamilyName failed: ${e.message}")
            try {
                File(fontPath).nameWithoutExtension
            } catch (_: Exception) {
                ""
            }
        }
    }

    /** 是否为字体文件（.ttf/.otf/.ttc/.otc，大小写不敏感）。 */
    private fun isFontFile(name: String): Boolean {
        val lower = name.lowercase()
        return lower.endsWith(".ttf") || lower.endsWith(".otf") ||
            lower.endsWith(".ttc") || lower.endsWith(".otc")
    }

    /** 兜底系统字库文件名（列表里隐藏，仅用于渲染时缺字兜底）。 */
    private val fallbackFontNames = setOf(
        "NotoSansCJK-Regular.ttc",
        "NotoSansSC-Regular.otf",
        "NotoSansHans-Regular.otf",
        "DroidSansFallback.ttf",
    )

    /**
     * 把用户选中的目录（SAF tree uri）里所有 .ttf/.otf/.ttc/.otc 字体一次性
     * 拷贝到 filesDir/fonts/（仅顶层文件，不递归），并补兜底字库；返回成功拷贝数。
     */
    private fun copyFontsFromDirectory(treeUriString: String): Int {
        return try {
            val treeUri = Uri.parse(treeUriString)
            val fontDir = File(filesDir, "fonts")
            if (!fontDir.exists()) fontDir.mkdirs()
            var count = 0
            val doc = DocumentFile.fromTreeUri(this, treeUri) ?: return 0
            doc.listFiles()?.forEach { file ->
                if (!file.isFile) return@forEach
                val name = file.name ?: return@forEach
                if (!isFontFile(name)) return@forEach
                try {
                    contentResolver.openInputStream(file.uri)?.use { input ->
                        File(fontDir, name).outputStream().use { out -> input.copyTo(out) }
                    }
                    count++
                } catch (e: Exception) {
                    Log.w("MainActivity", "copyFont ${file.name} failed: ${e.message}")
                }
            }
            ensureFallbackFont(fontDir)
            count
        } catch (e: Exception) {
            Log.w("MainActivity", "copyFontsFromDirectory failed: ${e.message}")
            0
        }
    }

    /**
     * 列出 filesDir/fonts/ 内的自定义字体（族名 + 文件名），按族名去重、按族名排序；
     * 隐藏兜底字库（fallbackFontNames）。
     */
    private fun listFontEntries(): List<Map<String, String>> {
        val fontDir = File(filesDir, "fonts")
        if (!fontDir.exists() || !fontDir.isDirectory) return emptyList()
        val seen = mutableSetOf<String>()
        val result = mutableListOf<Map<String, String>>()
        fontDir.listFiles()
            ?.filter { it.isFile && isFontFile(it.name) && it.name !in fallbackFontNames }
            ?.sortedBy { it.name.lowercase() }
            ?.forEach { f ->
                val family = getFontFamilyName(f.absolutePath)
                if (family.isNotEmpty() && seen.add(family)) {
                    result.add(mapOf("family" to family, "file" to f.name))
                }
            }
        return result
    }

    /** 清空 filesDir/fonts/ 下的全部文件（含兜底字库，下次拷贝会重建）。 */
    private fun clearFontsDirectory() {
        try {
            val fontDir = File(filesDir, "fonts")
            if (!fontDir.exists() || !fontDir.isDirectory) return
            fontDir.listFiles()?.forEach { if (it.isFile) it.delete() }
        } catch (e: Exception) {
            Log.w("MainActivity", "clearFontsDirectory failed: ${e.message}")
        }
    }

    // ── 缩略图缓存管理（列表封面，手动清理）───────────────
    // 进度条缩略图已切换为 FFmpeg 快速引擎（libmpv.so 内核）+ Dart 内存缓存，
    // 不再产生磁盘缓存；此处仅管理列表封面（cacheDir/thumbs/）。

    private fun thumbsDir(): File =
        File(cacheDir, "thumbs").apply { if (!exists()) mkdirs() }

    /** 各类别缓存占用（字节）：thumbs 目录全部计入列表封面（含历史进度条缩略图残留） */
    private fun getCacheSizes(): Map<String, Long> {
        var list = 0L
        thumbsDir().listFiles()?.forEach { f ->
            if (f.isFile) list += f.length()
        }
        // 未来类别（弹幕/字幕等）尚未启用，恒为 0
        return mapOf("listThumbs" to list, "other" to 0L)
    }

    /** 清除指定类别缓存（listThumbs 清空 thumbs 目录，顺带清掉历史残留） */
    private fun clearCache(category: String) {
        when (category) {
            "listThumbs" -> thumbsDir().listFiles()?.forEach {
                if (it.isFile) it.delete()
            }
            // "other"：未来类别（弹幕/字幕），暂无可清
        }
    }

    /** 一键清除所有缓存 */
    private fun clearAllCaches() {
        thumbsDir().listFiles()?.forEach { it.delete() }
    }

    // ── 列表基本元数据（帧率 / 字幕，MediaInfoLib + 磁盘缓存）───────

    /** 基本元数据磁盘缓存目录（JSON 按 path+lastModified 分文件） */
    private fun metaCacheFile(path: String): File {
        val dir = File(cacheDir, "metainfo")
        if (!dir.exists()) dir.mkdirs()
        return File(dir, "${path.hashCode()}_${File(path).lastModified()}.json")
    }

    /**
     * 列表字段「帧率 / 字幕指示器」数据：MediaInfoLib 快速解析，
     * 结果落盘缓存（重开视频零解析）。失败返回空 Map（字段不显示）。
     */
    private fun getVideoBasicMetadata(path: String): Map<String, Any> {
        val cacheFile = metaCacheFile(path)
        if (cacheFile.exists()) {
            val cached = runCatching { cacheFile.readText() }.getOrNull()
            if (cached != null && cached.isNotEmpty()) {
                // 缓存是 JSON：反序列化为 Map
                val parsed = runCatching {
                    org.json.JSONObject(cached)
                }.getOrNull()
                if (parsed != null) {
                    return mapOf(
                        "frameRate" to parsed.optDouble("frameRate", 0.0),
                        "hasSubtitles" to parsed.optBoolean("hasSubtitles", false),
                        "subtitleCodec" to parsed.optString("subtitleCodec", ""),
                    )
                }
            }
        }

        val meta = MediaInfoHelper.extractBasicMetadata(this, path)
        if (meta.isNotEmpty()) {
            runCatching {
                val obj = org.json.JSONObject()
                obj.put("frameRate", meta["frameRate"] as? Number ?: 0.0)
                obj.put("hasSubtitles", meta["hasSubtitles"] as? Boolean ?: false)
                obj.put("subtitleCodec", meta["subtitleCodec"] as? String ?: "")
                // 原子写入：先写临时文件再改名
                val tmp = File(cacheFile.parentFile, cacheFile.name + ".tmp")
                java.io.FileOutputStream(tmp).use { o ->
                    o.write(obj.toString().toByteArray())
                    o.flush()
                }
                if (!tmp.renameTo(cacheFile)) {
                    tmp.delete()
                    java.io.FileOutputStream(cacheFile).use { o ->
                        o.write(obj.toString().toByteArray())
                        o.flush()
                    }
                }
            }
        }
        return meta
    }

    // ── 列表缩略图（优化：等比缩放 + 16:9 居中裁剪 + 低质量 JPEG）──────

    /**
     * 列表封面缩略图目标尺寸（参考项目 ThumbnailCacheManager 的 384×216，
     * 等比缩放填满后居中裁剪为 16:9，宽高比一致的卡片封面观感统一）。
     */
    private val coverThumbWidth = 384
    private val coverThumbHeight = 216

    /** 列表封面磁盘文件：按**身份串**命名（本地 = 路径+修改时间；远端 = 连接+远端路径+大小+时间）。
     *  `_v3` 是版本标记：v2 及以前抓的是第 0 秒帧，改名后旧封面自动失效重建。 */
    private fun thumbFileFor(cacheKey: String): File =
        File(thumbsDir(), "${cacheKey.hashCode()}_${cacheKey.length}_v3.jpg")

    /** 列表封面抓帧位置：片长 1/4 处（第 0 秒常是黑场/台标，什么都看不到）。
     *  时长未知（0）时退回第 0 秒——算不出 1/4 也不能不抓。 */
    private fun coverFrameTimeUs(durationMs: Long): Long =
        if (durationMs <= 0L) 0L else durationMs * 1000L / 4L

    /**
     * 本地视频封面（列表卡片，[MediaMetadataRetriever] 直接读本地文件）。
     *
     * 身份串 = 路径 + 修改时间（文件被替换/修改后自动失效）；抓 1/4 处帧；
     * 输出等比缩放 + 居中裁剪成 384×216 的 JPEG（质量 70）。
     */
    private fun getVideoInfo(path: String): Map<String, Any?> {
        val cacheFile = thumbFileFor("$path|${File(path).lastModified()}")
        // 磁盘缓存命中：直接返回，完全跳过解码
        // （时长由 MediaStore 提供，列表不需要这里的 duration）
        if (cacheFile.exists()) {
            return mapOf("durationMs" to 0L, "thumbPath" to cacheFile.absolutePath)
        }

        val retriever = MediaMetadataRetriever()
        var bitmap: Bitmap? = null
        var cover: Bitmap? = null
        return try {
            retriever.setDataSource(path)
            val durationMs = retriever
                .extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                ?.toLongOrNull() ?: 0L

            @Suppress("DEPRECATION")
            val frame = retriever.getFrameAtTime(
                coverFrameTimeUs(durationMs),
                MediaMetadataRetriever.OPTION_CLOSEST_SYNC,
            )
            bitmap = frame
            val thumbPath = if (frame != null) {
                // 用局部 val 承接：可空字段的智能转换在 finally 之后不可靠
                val cv = cropCover(frame)
                cover = cv
                FileOutputStream(cacheFile).use { out ->
                    cv.compress(Bitmap.CompressFormat.JPEG, 70, out)
                }
                cacheFile.absolutePath
            } else {
                null
            }

            mapOf(
                "durationMs" to durationMs,
                "thumbPath" to thumbPath,
            )
        } catch (e: Throwable) {
            // 之前只捕 Exception：Bitmap 分配失败是 OutOfMemoryError（Error，不是 Exception），
            // 漏掉后 result.success() 永不执行 → Dart 侧 Future 永久挂起（封面卡在「生成中」）。
            // 这里连 Error 一起兜住，任何失败都回一个「无封面」结果，卡片不再永久转圈。
            Log.w("MainActivity", "getVideoInfo failed: ${e.message}")
            mapOf("durationMs" to 0L, "thumbPath" to null)
        } finally {
            // 位图与 retriever 一律在 finally 回收：原来 recycle() 散在正常路径里，
            // 中途抛错（如 compress 失败）就漏回收；压缩成 JPEG 之后原件已无用，
            // 再留一份 4K 位图（约 24MB）只会加速下一次 OOM
            if (cover !== bitmap) runCatching { bitmap?.recycle() }
            runCatching { cover?.recycle() }
            retriever.release()
        }
    }

    /**
     * 等比缩放填满 16:9 目标区后居中裁剪（与参考项目封面算法一致）。
     *
     * 关键：先按「被填满的那个维度」等比缩放（高度填满或宽度填满），
     * 再居中裁剪超出部分——保证画面不变形（横屏/竖屏/超宽屏均不失真）。
     *
     * 4K 源（3840×2160，ARGB_8888 约 24MB）先按 2 的幂降采样到刚够 384×216 之上再裁剪：
     * 目标封面只有 8.3 万像素，直接 `createScaledBitmap` 仍要先持有整帧 4K 位图，
     * 叠加上 `getFrameAtTime` 的原始帧极易 OOM（P1-19 的触发场景）。
     */
    private fun cropCover(src: Bitmap): Bitmap {
        val srcWidth = src.width
        val srcHeight = src.height
        if (srcWidth <= 0 || srcHeight <= 0) return src
        val targetRatio = coverThumbWidth.toFloat() / coverThumbHeight // 384/216 ≈ 1.7778
        val srcRatio = srcWidth.toFloat() / srcHeight

        // 降采样档位（2 的幂）：把长边压到 coverThumb 长边的 2 倍以内，画质对封面足够
        var sample = 1
        val longEdge = maxOf(srcWidth, srcHeight)
        val longEdgeTarget = maxOf(coverThumbWidth, coverThumbHeight) * 2
        while (longEdge / (sample * 2) >= longEdgeTarget) {
            sample *= 2
        }

        val workWidth = if (sample > 1) (srcWidth / sample).coerceAtLeast(1) else srcWidth
        val workHeight = if (sample > 1) (srcHeight / sample).coerceAtLeast(1) else srcHeight
        val work = if (sample > 1) {
            Bitmap.createScaledBitmap(src, workWidth, workHeight, true)
        } else {
            src
        }

        val scaledWidth: Int
        val scaledHeight: Int
        if (srcRatio > targetRatio) {
            // 源更宽（横屏/超宽屏）：按高度填满，宽度等比放大后居中裁剪
            scaledHeight = coverThumbHeight
            scaledWidth = (workWidth * coverThumbHeight.toFloat() / workHeight).toInt()
        } else {
            // 源更高（竖屏/方屏）：按宽度填满，高度等比放大后居中裁剪
            scaledWidth = coverThumbWidth
            scaledHeight = (workHeight * coverThumbWidth.toFloat() / workWidth).toInt()
        }

        val scaled = if (workWidth == scaledWidth && workHeight == scaledHeight) {
            work
        } else {
            Bitmap.createScaledBitmap(work, scaledWidth, scaledHeight, true)
        }
        if (work !== src && work !== scaled) work.recycle()
        val x = ((scaledWidth - coverThumbWidth) / 2).coerceAtLeast(0)
        val y = ((scaledHeight - coverThumbHeight) / 2).coerceAtLeast(0)
        val final = Bitmap.createBitmap(
            scaled, x, y,
            minOf(coverThumbWidth, scaledWidth),
            minOf(coverThumbHeight, scaledHeight),
        )
        if (scaled !== final && scaled !== src) scaled.recycle()
        return final
    }

    /**
     * 「自己走文件系统」的补充扫描用视频扩展名（MediaStore 索引到的格式不受此表限制）。
     * 与 Dart 侧 `FileOps.videoExtensions` 保持同源。
     */
    private val fsVideoExts = setOf(
        "mp4", "mkv", "avi", "mov", "wmv", "flv", "ts", "m4v", "webm", "3gp", "mpg", "mpeg"
    )

    /**
     * **非主**存储卷根（外置卡 / U 盘 / 模拟器共享目录等），供 [getVideos] 的文件系统
     * 补充扫描使用。
     *
     * 与 [getStorageRoots] 同源（`StorageManager.storageVolumes` + [storageVolumePath]），
     * 三点差异：
     * 1. 只取非主卷——主卷由 MediaStore 覆盖，另有一条受开关控制的补充扫描（见 [getVideos] 4.1）；
     * 2. **放宽挂载状态判断**：不要求 `MEDIA_MOUNTED`，路径存在且可读即算（个别 ROM /
     *    模拟器把共享目录报成别的状态，卡状态会白白漏掉整卷）；
     * 3. 返回 [File] 而不是 Map——调用方直接拿它 `listFiles()`。
     *
     * 枚举失败返回空表（退回「只有主卷」，不报错、不崩）。
     */
    private fun externalStorageRoots(): List<File> {
        val primaryPath = try {
            @Suppress("DEPRECATION")
            val primary = Environment.getExternalStorageDirectory()
            primary?.absolutePath
        } catch (_: Exception) {
            null
        }
        // 按绝对路径去重：个别 ROM 会把同一卷报两次
        val roots = LinkedHashMap<String, File>()
        try {
            val manager = getSystemService(STORAGE_SERVICE) as? StorageManager
                ?: return emptyList()
            for (volume in manager.storageVolumes) {
                if (volume.isPrimary) continue
                val path = storageVolumePath(volume) ?: continue
                if (path.isEmpty() || path == primaryPath) continue
                val dir = File(path)
                if (!dir.isDirectory || !dir.canRead()) continue
                if (!roots.containsKey(dir.absolutePath)) {
                    roots[dir.absolutePath] = dir
                }
            }
        } catch (e: Exception) {
            Log.w("MainActivity", "externalStorageRoots failed: ${e.message}")
            return emptyList()
        }
        return roots.values.toList()
    }

    /**
     * 通过 MediaStore 查询所有本地视频（可配置是否包含 .nomedia 与隐藏文件夹）。
     *
     * MediaStore 不认识的位置（外置卡上未被索引的目录、模拟器共享目录等）由末尾的
     * **文件系统补充扫描**补齐：单靠 MediaStore 会整片漏掉这些位置（用户反馈：模拟器
     * 共享目录里的视频文件夹不出现在首页）。
     */
    private fun getVideos(
        includeNoMedia: Boolean = false,
        includeHidden: Boolean = false
    ): List<Map<String, Any>> {
        val videos = mutableListOf<Map<String, Any>>()
        val visitedPaths = mutableSetOf<String>()
        val noMediaDirCache = mutableMapOf<String, Boolean>()

        fun checkDirectoryHasNoMedia(dir: File): Boolean {
            val dirPath = dir.absolutePath
            noMediaDirCache[dirPath]?.let { return it }
            var curr: File? = dir
            var hasNoMedia = false
            while (curr != null && curr.path != "/" && curr.path != "/storage/emulated") {
                val test = File(curr, ".nomedia")
                if (test.exists()) {
                    hasNoMedia = true
                    break
                }
                curr = curr.parentFile
            }
            noMediaDirCache[dirPath] = hasNoMedia
            return hasNoMedia
        }

        val projection = arrayOf(
            MediaStore.Video.Media._ID,
            MediaStore.Video.Media.DISPLAY_NAME,
            MediaStore.Video.Media.DURATION,
            MediaStore.Video.Media.SIZE,
            MediaStore.Video.Media.WIDTH,
            MediaStore.Video.Media.HEIGHT,
            MediaStore.Video.Media.DATE_MODIFIED,
            MediaStore.Video.Media.DATA,
            MediaStore.Video.Media.RELATIVE_PATH,
        )
        val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL)
        } else {
            MediaStore.Video.Media.EXTERNAL_CONTENT_URI
        }
        val cursor: Cursor? = contentResolver.query(
            collection, projection, null, null,
            "${MediaStore.Video.Media.DATE_ADDED} DESC"
        )
        cursor?.use { c ->
            val nameCol = c.getColumnIndexOrThrow(MediaStore.Video.Media.DISPLAY_NAME)
            val durCol = c.getColumnIndexOrThrow(MediaStore.Video.Media.DURATION)
            val sizeCol = c.getColumnIndexOrThrow(MediaStore.Video.Media.SIZE)
            val widthCol = c.getColumnIndexOrThrow(MediaStore.Video.Media.WIDTH)
            val heightCol = c.getColumnIndexOrThrow(MediaStore.Video.Media.HEIGHT)
            val dateCol = c.getColumnIndexOrThrow(MediaStore.Video.Media.DATE_MODIFIED)
            val dataCol = c.getColumnIndex(MediaStore.Video.Media.DATA)
            val relCol = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                c.getColumnIndex(MediaStore.Video.Media.RELATIVE_PATH)
            } else -1

            while (c.moveToNext()) {
                val origName = c.getString(nameCol) ?: continue
                val duration = c.getLong(durCol)
                val width = c.getInt(widthCol)
                val height = c.getInt(heightCol)

                // 优先读取 DATA 绝对路径（兼容 SD 卡与内置存储），找不到再通过 RELATIVE_PATH 拼接
                val dataPath = if (dataCol >= 0) c.getString(dataCol) else null
                val path = if (!dataPath.isNullOrEmpty()) {
                    dataPath
                } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && relCol >= 0) {
                    val rel = c.getString(relCol) ?: ""
                    "/storage/emulated/0/$rel$origName"
                } else {
                    continue
                }

                // 核心防脏数据校验：
                // 1. 检查物理文件是否真实存在且大小非空
                val file = File(path)
                if (!file.exists() || !file.isFile || file.length() == 0L) {
                    continue
                }

                val realName = file.name

                // 2. 隐藏文件/隐藏目录过滤策略（根据开关判断）
                val isHiddenItem = realName.startsWith(".") || path.split("/").any { it.startsWith(".") && it.isNotEmpty() }
                if (!includeHidden && isHiddenItem) {
                    continue
                }

                // 3. .nomedia 目录过滤策略（根据开关判断）
                if (!includeNoMedia && file.parentFile != null && checkDirectoryHasNoMedia(file.parentFile!!)) {
                    continue
                }

                val realSize = file.length()
                val realDateModified = file.lastModified()
                val normPath = file.absolutePath

                // 工作.md 第 5 点：dart:io / MediaMuxer 直写的下载产物，MediaStore
                // 可能尚未抽取时长（duration=0），此时列表里进度条/百分比永远显示
                // 「未观看」。duration==0 时用 MediaMetadataRetriever 兜底抽一次。
                val finalDuration = if (duration > 0) duration else extractDurationMs(normPath)

                if (visitedPaths.add(normPath)) {
                    videos.add(
                        mapOf(
                            "path" to normPath,
                            "name" to realName,
                            "durationMs" to finalDuration,
                            "size" to realSize,
                            "width" to width,
                            "height" to height,
                            "dateModifiedMs" to if (realDateModified > 0) realDateModified else (c.getLong(dateCol) * 1000L),
                        )
                    )
                }
            }
        }

        // 4. 文件系统补充扫描（MediaStore 不认识的位置只能自己走文件系统）
        //
        // 4.1 主卷：仅在开启 includeNoMedia / includeHidden 时补扫（MediaStore 绝不会
        //     自动索引 .nomedia 目录），深度与判定保持原样；
        // 4.2 非主卷（外置卡 / U 盘 / 模拟器共享目录等）：**恒扫**——这些卷 MediaStore
        //     根本不索引，不扫就永远看不到里面的视频。深度 4 对齐参考项目 mpvEx 的
        //     shallow scan（MediaFileRepository.scanExternalVolumeShallow）。
        fun scanFsFolder(
            folder: File,
            depth: Int,
            maxDepth: Int,
            extractDuration: Boolean,
            durationDeadlineMs: Long,
            noMediaSelfOnly: Boolean,
        ) {
            if (depth > maxDepth) return
            if (!folder.exists() || !folder.isDirectory || !folder.canRead()) return
            val folderName = folder.name
            if (!includeHidden && folderName.startsWith(".")) return
            if (!includeNoMedia) {
                if (noMediaSelfOnly) {
                    // 非主卷：只看目录**自身**的 .nomedia，不上溯到卷外（/mnt、/ 上的 .nomedia
                    // 与这一卷无关，照算会让整卷消失）；卷根（depth 0）也豁免——模拟器 / 个别
                    // ROM 会在共享目录根上放 .nomedia，那不是「用户不想扫这个目录」的意思
                    if (depth > 0 && File(folder, ".nomedia").exists()) return
                } else if (checkDirectoryHasNoMedia(folder)) {
                    // 主卷：与上面 MediaStore 分支同一套祖先链判定（原先补充扫描漏了这一步，
                    // 于是「只开隐藏文件夹」时 .nomedia 目录里的视频会从补充扫描漏进来）
                    return
                }
            }

            val files = folder.listFiles() ?: return
            for (f in files) {
                if (f.isDirectory) {
                    scanFsFolder(
                        f, depth + 1, maxDepth, extractDuration, durationDeadlineMs,
                        noMediaSelfOnly,
                    )
                } else if (f.isFile && f.length() > 0) {
                    val ext = f.extension.lowercase()
                    if (ext !in fsVideoExts) continue
                    val fName = f.name
                    if (!includeHidden && fName.startsWith(".")) continue
                    val normPath = f.absolutePath
                    if (!visitedPaths.add(normPath)) continue
                    // MediaStore 没索引到 → 时长必为 0，而列表的进度条 / 已看状态全靠它，
                    // 故兜底抽一次；非主卷可能整卷很大，给一个总时间预算，超预算就不再抽
                    //（留 0 不影响列出与播放，只是这几条少了进度显示）
                    val duration = if (extractDuration &&
                        SystemClock.elapsedRealtime() < durationDeadlineMs
                    ) {
                        extractDurationMs(normPath)
                    } else {
                        0L
                    }
                    videos.add(
                        mapOf(
                            "path" to normPath,
                            "name" to fName,
                            "durationMs" to duration,
                            "size" to f.length(),
                            "width" to 0,
                            "height" to 0,
                            "dateModifiedMs" to f.lastModified(),
                        )
                    )
                }
            }
        }

        if (includeNoMedia || includeHidden) {
            try {
                @Suppress("DEPRECATION")
                val primaryStorage = Environment.getExternalStorageDirectory()
                if (primaryStorage != null && primaryStorage.exists()) {
                    // 主卷不抽时长：整盘补扫可能上千个文件，逐个开容器代价太大（保持原行为）
                    scanFsFolder(
                        primaryStorage, 0, 6,
                        extractDuration = false,
                        durationDeadlineMs = 0L,
                        noMediaSelfOnly = false,
                    )
                }
            } catch (_: Exception) {}
        }

        // 非主卷恒扫。总时长抽取预算 4s：超了后面的文件留 0，避免整卷很大时首屏扫描被拖长
        val externalDurationDeadlineMs = SystemClock.elapsedRealtime() + 4000L
        for (root in externalStorageRoots()) {
            scanFsFolder(
                root, 0, 4,
                extractDuration = true,
                durationDeadlineMs = externalDurationDeadlineMs,
                noMediaSelfOnly = true,
            )
        }

        return videos
    }

    /** MediaStore 时长为 0 时兜底抽取（工作.md 第 5 点：下载产物直写导致元数据缺失）。 */
    private fun extractDurationMs(path: String): Long {
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(path)
            retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                ?.toLongOrNull() ?: 0L
        } catch (_: Exception) {
            0L
        } finally {
            retriever.release()
        }
    }
}
