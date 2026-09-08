package com.azxcvn.moumou

import android.content.Context
import android.util.Log
import net.mediaarea.mediainfo.lib.MediaInfo
import java.io.File

/**
 * MediaInfo 库工具类（参考 fam4k007 项目的 MediaInfoHelper）：
 * 提取视频文件的详细媒体信息（通用 / 视频流 / 音频流 / 字幕流），
 * 以及列表字段所需的快速元数据（帧率 / 内嵌字幕）。
 *
 * 使用 JitPack 分发的 `com.github.marlboro-advance:mediainfoAndroid`，
 * 包路径 `net.mediaarea.mediainfo.lib.MediaInfo`，与参考项目一致。
 */
object MediaInfoHelper {
    private const val TAG = "MediaInfoHelper"

    private fun MediaInfo.getInfo(
        stream: MediaInfo.Stream,
        index: Int,
        parameter: String,
    ): String = Get(stream, index, parameter)

    /**
     * 快速提取基本元数据：帧率 / 是否有内嵌字幕 / 字幕编码。
     * 用于视频列表「帧率」「字幕指示器」字段（带磁盘缓存，见 MainActivity）。
     */
    fun extractBasicMetadata(context: Context, path: String): Map<String, Any> {
        val pfd = runCatching {
            android.os.ParcelFileDescriptor.open(
                File(path), android.os.ParcelFileDescriptor.MODE_READ_ONLY
            )
        }.getOrNull() ?: return emptyMap()

        val fd = pfd.detachFd()
        val mi = try {
            MediaInfo()
        } catch (e: Throwable) {
            // so 库缺失（如 x86 模拟器无 libzen.so）时为 UnsatisfiedLinkError，
            // 不是 Exception 子类——必须捕 Throwable 才能兜住
            Log.w(TAG, "MediaInfo native lib unavailable: ${e.message}")
            pfd.close()
            return emptyMap()
        }
        return try {
            mi.Open(fd, File(path).name)

            val fpsStr = mi.getInfo(MediaInfo.Stream.Video, 0, "FrameRate")
            val fps = fpsStr.toFloatOrNull() ?: 0f

            val textCount = mi.Count_Get(MediaInfo.Stream.Text)
            val hasSubtitles = textCount > 0

            val subtitleCodec = if (hasSubtitles) {
                val codecs = mutableSetOf<String>()
                for (i in 0 until textCount) {
                    val codecId = mi.getInfo(MediaInfo.Stream.Text, i, "CodecID")
                    val normalized = when {
                        codecId.contains("PGS", ignoreCase = true) -> "PGS"
                        codecId.contains("ASS", ignoreCase = true) -> "ASS"
                        codecId.contains("SSA", ignoreCase = true) -> "SSA"
                        codecId.contains("SRT", ignoreCase = true) -> "SRT"
                        codecId.contains("SUBRIP", ignoreCase = true) -> "SRT"
                        codecId.contains("VOBSUB", ignoreCase = true) -> "DVD"
                        codecId.contains("WEBVTT", ignoreCase = true) -> "VTT"
                        codecId.contains("UTF8", ignoreCase = true) -> "SRT"
                        codecId.contains("HDMV", ignoreCase = true) -> "PGS"
                        codecId.contains("MOV_TEXT", ignoreCase = true) -> "TX3G"
                        codecId.isNotEmpty() ->
                            codecId.substringAfterLast("/")
                                .substringAfterLast("_").uppercase()
                        else -> ""
                    }
                    if (normalized.isNotEmpty()) codecs.add(normalized)
                }
                codecs.joinToString(" ")
            } else ""

            mapOf(
                "frameRate" to fps,
                "hasSubtitles" to hasSubtitles,
                "subtitleCodec" to subtitleCodec,
            )
        } catch (e: Throwable) {
            Log.w(TAG, "extractBasicMetadata failed: ${e.message}")
            emptyMap()
        } finally {
            mi.Close()
            pfd.close()
        }
    }

    /** 提取完整的媒体信息（媒体信息页展示用） */
    fun getMediaInfo(context: Context, path: String): Map<String, Any>? {
        val pfd = runCatching {
            android.os.ParcelFileDescriptor.open(
                File(path), android.os.ParcelFileDescriptor.MODE_READ_ONLY
            )
        }.getOrNull() ?: return null

        val fd = pfd.detachFd()
        val mi = try {
            MediaInfo()
        } catch (e: Throwable) {
            Log.w(TAG, "MediaInfo native lib unavailable: ${e.message}")
            pfd.close()
            return null
        }
        return try {
            mi.Open(fd, File(path).name)

            val general = buildGeneralInfo(mi)
            val videoStreams = buildVideoStreams(mi)
            val audioStreams = buildAudioStreams(mi)
            val textStreams = buildTextStreams(mi)

            mapOf(
                "general" to general,
                "videoStreams" to videoStreams,
                "audioStreams" to audioStreams,
                "textStreams" to textStreams,
            )
        } catch (e: Throwable) {
            Log.w(TAG, "getMediaInfo failed: ${e.message}")
            null
        } finally {
            mi.Close()
            pfd.close()
        }
    }

    private fun buildGeneralInfo(mi: MediaInfo): Map<String, String> = mapOf(
        "format" to mi.getInfo(MediaInfo.Stream.General, 0, "Format"),
        "formatVersion" to mi.getInfo(MediaInfo.Stream.General, 0, "Format_Version"),
        "fileSize" to mi.getInfo(MediaInfo.Stream.General, 0, "FileSize/String"),
        "duration" to mi.getInfo(MediaInfo.Stream.General, 0, "Duration/String3"),
        "overallBitRate" to mi.getInfo(MediaInfo.Stream.General, 0, "OverallBitRate/String"),
        "frameRate" to mi.getInfo(MediaInfo.Stream.General, 0, "FrameRate/String"),
        "title" to mi.getInfo(MediaInfo.Stream.General, 0, "Title"),
        "encodedDate" to mi.getInfo(MediaInfo.Stream.General, 0, "Encoded_Date"),
        "writingApplication" to mi.getInfo(MediaInfo.Stream.General, 0, "Encoded_Application/String"),
        "writingLibrary" to mi.getInfo(MediaInfo.Stream.General, 0, "Encoded_Library/String"),
    )

    private fun buildVideoStreams(mi: MediaInfo): List<Map<String, String>> {
        val count = mi.Count_Get(MediaInfo.Stream.Video)
        return (0 until count).map { i ->
            mapOf(
                "id" to mi.getInfo(MediaInfo.Stream.Video, i, "ID"),
                "format" to mi.getInfo(MediaInfo.Stream.Video, i, "Format"),
                "formatProfile" to mi.getInfo(MediaInfo.Stream.Video, i, "Format_Profile"),
                "codecId" to mi.getInfo(MediaInfo.Stream.Video, i, "CodecID"),
                "duration" to mi.getInfo(MediaInfo.Stream.Video, i, "Duration/String3"),
                "bitRate" to mi.getInfo(MediaInfo.Stream.Video, i, "BitRate/String"),
                "width" to mi.getInfo(MediaInfo.Stream.Video, i, "Width/String"),
                "height" to mi.getInfo(MediaInfo.Stream.Video, i, "Height/String"),
                "displayAspectRatio" to mi.getInfo(MediaInfo.Stream.Video, i, "DisplayAspectRatio/String"),
                "frameRate" to mi.getInfo(MediaInfo.Stream.Video, i, "FrameRate/String"),
                "frameRateMode" to mi.getInfo(MediaInfo.Stream.Video, i, "FrameRate_Mode"),
                "colorSpace" to mi.getInfo(MediaInfo.Stream.Video, i, "ColorSpace"),
                "chromaSubsampling" to mi.getInfo(MediaInfo.Stream.Video, i, "ChromaSubsampling"),
                "bitDepth" to mi.getInfo(MediaInfo.Stream.Video, i, "BitDepth/String"),
                "streamSize" to mi.getInfo(MediaInfo.Stream.Video, i, "StreamSize/String"),
                "hdrFormat" to mi.getInfo(MediaInfo.Stream.Video, i, "HDR_Format"),
            )
        }
    }

    private fun buildAudioStreams(mi: MediaInfo): List<Map<String, String>> {
        val count = mi.Count_Get(MediaInfo.Stream.Audio)
        return (0 until count).map { i ->
            mapOf(
                "id" to mi.getInfo(MediaInfo.Stream.Audio, i, "ID"),
                "format" to mi.getInfo(MediaInfo.Stream.Audio, i, "Format"),
                "codecId" to mi.getInfo(MediaInfo.Stream.Audio, i, "CodecID"),
                "duration" to mi.getInfo(MediaInfo.Stream.Audio, i, "Duration/String3"),
                "bitRate" to mi.getInfo(MediaInfo.Stream.Audio, i, "BitRate/String"),
                "channels" to mi.getInfo(MediaInfo.Stream.Audio, i, "Channel(s)/String"),
                "samplingRate" to mi.getInfo(MediaInfo.Stream.Audio, i, "SamplingRate/String"),
                "language" to mi.getInfo(MediaInfo.Stream.Audio, i, "Language/String"),
                "title" to mi.getInfo(MediaInfo.Stream.Audio, i, "Title"),
            )
        }
    }

    private fun buildTextStreams(mi: MediaInfo): List<Map<String, String>> {
        val count = mi.Count_Get(MediaInfo.Stream.Text)
        return (0 until count).map { i ->
            mapOf(
                "id" to mi.getInfo(MediaInfo.Stream.Text, i, "ID"),
                "format" to mi.getInfo(MediaInfo.Stream.Text, i, "Format"),
                "codecId" to mi.getInfo(MediaInfo.Stream.Text, i, "CodecID"),
                "language" to mi.getInfo(MediaInfo.Stream.Text, i, "Language/String"),
                "title" to mi.getInfo(MediaInfo.Stream.Text, i, "Title"),
                "duration" to mi.getInfo(MediaInfo.Stream.Text, i, "Duration/String3"),
            )
        }
    }

    /**
     * 检测视频是否包含杜比视界（Dolby Vision）视频轨。
     *
     * 判断依据（任一命中即视为杜比视界）：
     * 1. 视频轨 HDR_Format 含 "Dolby Vision"；
     * 2. CodecID 含 dovi/dvhe/dvav；
     * 3. Format 含 "Dolby Vision"。
     *
     * 供播放页在未开 gpu-next / 软解时弹出偏色引导弹窗（对齐老项目
     * `DolbyVisionHintDialog`：检测 mime/codec 命中 dovi/dvhe）。
     * 返回 (Boolean, String)：是否杜比视界 + 命中的描述文本（未命中为空串）。
     */
    fun detectDolbyVision(context: Context, path: String): Pair<Boolean, String> {
        val pfd = runCatching {
            android.os.ParcelFileDescriptor.open(
                File(path), android.os.ParcelFileDescriptor.MODE_READ_ONLY
            )
        }.getOrNull() ?: return Pair(false, "")
        val fd = pfd.detachFd()
        val mi = try {
            MediaInfo()
        } catch (e: Throwable) {
            Log.w(TAG, "MediaInfo native lib unavailable: ${e.message}")
            pfd.close()
            return Pair(false, "")
        }
        return try {
            mi.Open(fd, File(path).name)
            val videoCount = mi.Count_Get(MediaInfo.Stream.Video)
            for (i in 0 until videoCount) {
                val hdr = mi.getInfo(MediaInfo.Stream.Video, i, "HDR_Format")
                val codecId = mi.getInfo(MediaInfo.Stream.Video, i, "CodecID")
                val format = mi.getInfo(MediaInfo.Stream.Video, i, "Format")
                val combined = "$hdr|$codecId|$format"
                when {
                    hdr.contains("Dolby Vision", ignoreCase = true) ->
                        return Pair(true, "Dolby Vision")
                    combined.contains("dovi", ignoreCase = true) ||
                        combined.contains("dvhe", ignoreCase = true) ||
                        combined.contains("dvav", ignoreCase = true) ->
                        return Pair(true, "Dolby Vision")
                    format.contains("Dolby Vision", ignoreCase = true) ->
                        return Pair(true, "Dolby Vision")
                }
            }
            Pair(false, "")
        } catch (e: Throwable) {
            Log.w(TAG, "detectDolbyVision failed: ${e.message}")
            Pair(false, "")
        } finally {
            mi.Close()
            pfd.close()
        }
    }
}
