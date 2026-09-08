package com.azxcvn.moumou

import android.content.Context
import android.media.MediaCodecInfo
import android.media.MediaCodecList
import android.os.Build
import android.util.Log
import android.view.Display
import android.view.WindowManager

/**
 * 设备硬件与编解码能力检测（对齐参考项目 mpvRx 的 `CodecCapabilitiesScreen`
 * 与 `VideoCodecSupport`，以及老项目 `DeviceInfoDetector`）。
 *
 * 产出三类信息的结构化 Map，供 Flutter「设备信息」页可视化：
 * 1. 屏幕 HDR 能力（Display.getHdrCapabilities：HDR10/HDR10+/HLG/杜比视界）；
 * 2. 关键视频编解码器硬解/软解支持（H.264/H.265/AV1/VP9/杜比视界 等）；
 * 3. 系统全部**解码器**清单（硬解/软解、视频/音频、profile/level、最大分辨率等）。
 */
object DeviceCapabilities {

    private const val TAG = "DeviceCapabilities"

    data class CodecEntry(
        val name: String,
        val canonicalName: String,
        val mimeType: String,
        val formatName: String,
        val isHardware: Boolean,
        val mediaType: String, // "video" / "audio"
        val maxResolution: String,
        val maxChannels: Int,
        val profiles: List<String>,
        val isHdrSupported: Boolean,
    )

    /** Flutter 侧调用的统一入口：返回可序列化的 Map。 */
    fun inspect(context: Context): Map<String, Any?> {
        return mapOf(
            "device" to deviceInfo(),
            "hdrCapabilities" to hdrCapabilities(context),
            "keyCodecs" to keyCodecs(),
            "decoders" to allDecoders(),
        )
    }

    private fun deviceInfo(): Map<String, String> = mapOf(
        "manufacturer" to (Build.MANUFACTURER ?: ""),
        "model" to (Build.MODEL ?: ""),
        "brand" to (Build.BRAND ?: ""),
        "release" to (Build.VERSION.RELEASE ?: ""),
        "sdkInt" to Build.VERSION.SDK_INT.toString(),
    )

    /** 屏幕 HDR 能力：HDR10 / HDR10+ / HLG / 杜比视界（Dolby Vision）。 */
    private fun hdrCapabilities(context: Context): List<String> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return emptyList()
        return try {
            val display = (context.getSystemService(Context.WINDOW_SERVICE) as? WindowManager)
                ?.defaultDisplay
                ?: return emptyList()
            val info = display.hdrCapabilities ?: return emptyList()
            val types = info.supportedHdrTypes
            val set = linkedSetOf<String>()
            for (t in types) {
                when (t) {
                    Display.HdrCapabilities.HDR_TYPE_HDR10 -> set.add("HDR10")
                    Display.HdrCapabilities.HDR_TYPE_HDR10_PLUS -> set.add("HDR10+")
                    Display.HdrCapabilities.HDR_TYPE_HLG -> set.add("HLG")
                    Display.HdrCapabilities.HDR_TYPE_DOLBY_VISION -> set.add("Dolby Vision")
                    else -> set.add("HDR($t)")
                }
            }
            set.toList()
        } catch (e: Exception) {
            Log.w(TAG, "hdrCapabilities failed: ${e.message}")
            emptyList()
        }
    }

    /** 关键视频编解码器硬解/软解支持汇总（对齐 mpvRx getKeyVideoCodecs）。 */
    private fun keyCodecs(): List<Map<String, Any?>> {
        val keyFormats = listOf(
            "video/avc" to "H.264 / AVC",
            "video/hevc" to "H.265 / HEVC",
            "video/av01" to "AV1",
            "video/x-vnd.on2.vp9" to "VP9",
            "video/dolby-vision" to "Dolby Vision",
        )
        val codecs = allDecoders()
        return keyFormats.map { (mime, label) ->
            val matching = codecs.filter {
                (it["mimeType"] as? String).equals(mime, ignoreCase = true)
            }
            val hw = matching.firstOrNull { it["isHardware"] == true }
            val any = matching.firstOrNull()
            val hasHw = hw != null
            val hasSw = matching.any { it["isHardware"] == false }
            mapOf(
                "formatName" to label,
                "mimeType" to mime,
                "hasHardware" to hasHw,
                "hasSoftware" to hasSw,
                "decoderName" to ((hw ?: any)?.get("name") as? String),
                "maxResolution" to ((hw ?: any)?.get("maxResolution") as? String),
                "isHdrSupported" to (matching.any { it["isHdrSupported"] == true }),
            )
        }
    }

    /** 遍历系统全部解码器（MediaCodecList.ALL_CODECS，过滤编码器）。 */
    private fun allDecoders(): List<Map<String, Any?>> {
        val results = mutableListOf<Map<String, Any?>>()
        try {
            val infos = MediaCodecList(MediaCodecList.ALL_CODECS).codecInfos
            for (info in infos) {
                if (info.isEncoder) continue
                val isHw = isHardwareDecoder(info)
                val canonical = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    info.canonicalName
                } else {
                    info.name
                }
                val isAlias = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    info.isAlias
                } else {
                    false
                }
                for (mime in info.supportedTypes) {
                    val mediaType = when {
                        mime.startsWith("video/", ignoreCase = true) -> "video"
                        mime.startsWith("audio/", ignoreCase = true) -> "audio"
                        else -> continue
                    }
                    var maxRes = ""
                    var minRes = ""
                    var maxChan = 0
                    var maxInst = 0
                    var isHdr = false
                    var align = ""
                    var bitrate = ""
                    val profiles = mutableListOf<String>()
                    val colorFormats = mutableListOf<String>()
                    val features = mutableListOf<String>()
                    val sampleRates = mutableListOf<String>()
                    try {
                        val caps = info.getCapabilitiesForType(mime)

                        // 硬件特性（对齐 mpvRx）
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT_WATCH &&
                            caps.isFeatureSupported(
                                MediaCodecInfo.CodecCapabilities.FEATURE_AdaptivePlayback
                            )
                        ) features.add("Adaptive Res")
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                            if (caps.isFeatureSupported(
                                    MediaCodecInfo.CodecCapabilities.FEATURE_TunneledPlayback
                                )
                            ) features.add("Direct Tunneling")
                            if (caps.isFeatureSupported(
                                    MediaCodecInfo.CodecCapabilities.FEATURE_SecurePlayback
                                )
                            ) features.add("Hardware DRM (L1)")
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R &&
                            caps.isFeatureSupported(
                                MediaCodecInfo.CodecCapabilities.FEATURE_LowLatency
                            )
                        ) features.add("Low Latency")

                        if (mediaType == "video") {
                            val vc = caps.videoCapabilities
                            if (vc != null) {
                                val maxW = vc.supportedWidths.upper
                                val maxH = vc.supportedHeights.upper
                                val minW = vc.supportedWidths.lower
                                val minH = vc.supportedHeights.lower
                                val maxF = vc.supportedFrameRates.upper.toInt()
                                maxRes = "${maxW}x${maxH} @ ${maxF}fps"
                                minRes = "${minW}x${minH}"
                                align = "${vc.widthAlignment}x${vc.heightAlignment}"
                                val bitRange = vc.bitrateRange
                                if (bitRange != null) {
                                    bitrate = "${formatBitrate(bitRange.lower)} - ${formatBitrate(bitRange.upper)}"
                                }
                            }
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                maxInst = caps.maxSupportedInstances
                            }
                            // 色彩格式
                            val colors = caps.colorFormats
                            if (colors != null) {
                                for (cf in colors) {
                                    val cfName = getColorFormatName(cf)
                                    if (cfName !in colorFormats) colorFormats.add(cfName)
                                }
                            }
                            // profile + level
                            val pls = caps.profileLevels
                            if (pls != null) {
                                for (pl in pls) {
                                    val pName = profileLevelName(mime, pl.profile, pl.level)
                                    if (pName != null && pName !in profiles) {
                                        profiles.add(pName)
                                    }
                                    if (isHdrProfile(mime, pl.profile)) isHdr = true
                                }
                            }
                        } else {
                            val ac = caps.audioCapabilities
                            if (ac != null) {
                                maxChan = ac.maxInputChannelCount
                                val rates = ac.supportedSampleRates
                                if (rates != null && rates.isNotEmpty()) {
                                    sampleRates.addAll(rates.map { "${it / 1000.0} kHz" })
                                }
                                val bitRange = ac.bitrateRange
                                if (bitRange != null) {
                                    bitrate = "${formatBitrate(bitRange.lower)} - ${formatBitrate(bitRange.upper)}"
                                }
                            }
                        }
                    } catch (_: Exception) {
                        // 厂商解码器能力查询异常时忽略该项
                    }
                    results.add(
                        mapOf(
                            "name" to info.name,
                            "canonicalName" to canonical,
                            "mimeType" to mime,
                            "formatName" to formatName(mime),
                            "isHardware" to isHw,
                            "isAlias" to isAlias,
                            "mediaType" to mediaType,
                            "maxResolution" to maxRes,
                            "minResolution" to minRes,
                            "maxChannels" to maxChan,
                            "maxInstances" to maxInst,
                            "alignment" to align,
                            "bitrateRange" to bitrate,
                            "profiles" to profiles,
                            "colorFormats" to colorFormats,
                            "features" to features,
                            "sampleRates" to sampleRates,
                            "isHdrSupported" to isHdr,
                        )
                    )
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "allDecoders failed: ${e.message}")
        }
        return results.sortedWith(
            compareBy(
                { !(it["isHardware"] as Boolean) },
                { it["mediaType"] as String },
                { it["formatName"] as String },
                { it["name"] as String },
            )
        )
    }

    /** profile + level 组合名（对齐 mpvRx getProfileAndLevelName）。 */
    private fun profileLevelName(mime: String, profile: Int, level: Int): String? {
        val pName = profileName(mime, profile) ?: "Profile $profile"
        val lName = levelName(mime, level)
        return if (lName != null) "$pName ($lName)" else pName
    }

    private fun levelName(mime: String, level: Int): String? = when (mime.lowercase()) {
        "video/hevc" -> when (level) {
            MediaCodecInfo.CodecProfileLevel.HEVCMainTierLevel1 -> "Level 1"
            MediaCodecInfo.CodecProfileLevel.HEVCMainTierLevel2 -> "Level 2"
            MediaCodecInfo.CodecProfileLevel.HEVCMainTierLevel21 -> "Level 2.1"
            MediaCodecInfo.CodecProfileLevel.HEVCMainTierLevel3 -> "Level 3"
            MediaCodecInfo.CodecProfileLevel.HEVCMainTierLevel31 -> "Level 3.1"
            MediaCodecInfo.CodecProfileLevel.HEVCMainTierLevel4 -> "Level 4"
            MediaCodecInfo.CodecProfileLevel.HEVCMainTierLevel41 -> "Level 4.1"
            MediaCodecInfo.CodecProfileLevel.HEVCMainTierLevel5 -> "Level 5"
            MediaCodecInfo.CodecProfileLevel.HEVCMainTierLevel51 -> "Level 5.1"
            MediaCodecInfo.CodecProfileLevel.HEVCMainTierLevel52 -> "Level 5.2"
            MediaCodecInfo.CodecProfileLevel.HEVCMainTierLevel6 -> "Level 6"
            MediaCodecInfo.CodecProfileLevel.HEVCMainTierLevel61 -> "Level 6.1"
            MediaCodecInfo.CodecProfileLevel.HEVCMainTierLevel62 -> "Level 6.2"
            else -> null
        }
        "video/avc" -> when (level) {
            MediaCodecInfo.CodecProfileLevel.AVCLevel1 -> "Level 1"
            MediaCodecInfo.CodecProfileLevel.AVCLevel11 -> "Level 1.1"
            MediaCodecInfo.CodecProfileLevel.AVCLevel12 -> "Level 1.2"
            MediaCodecInfo.CodecProfileLevel.AVCLevel13 -> "Level 1.3"
            MediaCodecInfo.CodecProfileLevel.AVCLevel2 -> "Level 2"
            MediaCodecInfo.CodecProfileLevel.AVCLevel21 -> "Level 2.1"
            MediaCodecInfo.CodecProfileLevel.AVCLevel22 -> "Level 2.2"
            MediaCodecInfo.CodecProfileLevel.AVCLevel3 -> "Level 3"
            MediaCodecInfo.CodecProfileLevel.AVCLevel31 -> "Level 3.1"
            MediaCodecInfo.CodecProfileLevel.AVCLevel32 -> "Level 3.2"
            MediaCodecInfo.CodecProfileLevel.AVCLevel4 -> "Level 4"
            MediaCodecInfo.CodecProfileLevel.AVCLevel41 -> "Level 4.1"
            MediaCodecInfo.CodecProfileLevel.AVCLevel42 -> "Level 4.2"
            MediaCodecInfo.CodecProfileLevel.AVCLevel5 -> "Level 5"
            MediaCodecInfo.CodecProfileLevel.AVCLevel51 -> "Level 5.1"
            MediaCodecInfo.CodecProfileLevel.AVCLevel52 -> "Level 5.2"
            else -> null
        }
        else -> null
    }

    /** 色彩格式名（对齐 mpvRx getColorFormatName）。 */
    @Suppress("DEPRECATION")
    private fun getColorFormatName(format: Int): String = when (format) {
        MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Planar -> "YUV 420 Planar"
        MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420PackedPlanar -> "YUV 420 Packed Planar"
        MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420SemiPlanar -> "YUV 420 Semi-Planar (NV12)"
        MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420PackedSemiPlanar -> "YUV 420 Packed Semi-Planar"
        MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV422Planar -> "YUV 422 Planar"
        MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV422PackedPlanar -> "YUV 422 Packed Planar"
        MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV422SemiPlanar -> "YUV 422 Semi-Planar"
        MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV444Interleaved -> "YUV 444 Interleaved"
        MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface -> "Surface (Hardware Texture)"
        MediaCodecInfo.CodecCapabilities.COLOR_Format24bitRGB888 -> "24-bit RGB 888"
        MediaCodecInfo.CodecCapabilities.COLOR_Format32bitARGB8888 -> "32-bit ARGB 8888"
        MediaCodecInfo.CodecCapabilities.COLOR_Format32bitABGR8888 -> "32-bit ABGR 8888"
        MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Flexible -> "YUV 420 Flexible"
        0x7F000789 -> "P010 (10-bit YUV)"
        else -> "0x${Integer.toHexString(format).uppercase()}"
    }

    private fun formatBitrate(bps: Int): String = when {
        bps >= 1_000_000 -> "${bps / 1_000_000} Mbps"
        bps >= 1_000 -> "${bps / 1_000} kbps"
        else -> "$bps bps"
    }

    private fun isHardwareDecoder(info: MediaCodecInfo): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            return info.isHardwareAccelerated
        }
        return !isSoftwareName(info.name)
    }

    private fun isSoftwareName(name: String): Boolean {
        val lower = name.lowercase()
        return lower.startsWith("omx.google.") ||
            lower.startsWith("c2.android.") ||
            lower.startsWith("omx.ffmpeg.") ||
            lower.contains(".sw.") ||
            lower.contains("software")
    }

    private fun formatName(mime: String): String = when (mime.lowercase()) {
        "video/avc" -> "H.264 / AVC"
        "video/hevc" -> "H.265 / HEVC"
        "video/av01" -> "AV1"
        "video/x-vnd.on2.vp9" -> "VP9"
        "video/x-vnd.on2.vp8" -> "VP8"
        "video/mp4v-es" -> "MPEG-4 Part 2"
        "video/mpeg2" -> "MPEG-2"
        "video/vc1", "video/wvc1", "video/x-ms-wmv" -> "VC-1 / WMV"
        "video/dolby-vision" -> "Dolby Vision"
        "video/3gpp" -> "H.263"
        "video/raw" -> "Raw Uncompressed Video"
        "video/mjpeg" -> "Motion JPEG"
        "audio/mp4a-latm" -> "AAC"
        "audio/mpeg" -> "MP3"
        "audio/mpeg-l2" -> "MP2"
        "audio/flac" -> "FLAC"
        "audio/opus" -> "Opus"
        "audio/vorbis" -> "Vorbis"
        "audio/ac3" -> "AC-3 (Dolby Digital)"
        "audio/eac3" -> "E-AC-3 (Dolby Digital Plus)"
        "audio/eac3-joc" -> "E-AC-3 JOC (Dolby Atmos)"
        "audio/ac4" -> "AC-4"
        "audio/dts" -> "DTS"
        "audio/dts-hd" -> "DTS-HD"
        "audio/dts-uhd" -> "DTS:X / DTS-UHD"
        "audio/raw" -> "PCM (Uncompressed Audio)"
        "audio/alac" -> "ALAC (Apple Lossless)"
        "audio/truehd" -> "Dolby TrueHD"
        "audio/amr-wb" -> "AMR-WB"
        "audio/3gpp" -> "AMR-NB"
        "audio/wma", "audio/x-ms-wma" -> "WMA"
        else -> mime.removePrefix("video/").removePrefix("audio/")
            .removePrefix("image/").uppercase()
    }

    private fun profileName(mime: String, profile: Int): String? = when (mime.lowercase()) {
        "video/hevc" -> when (profile) {
            MediaCodecInfo.CodecProfileLevel.HEVCProfileMain -> "Main"
            MediaCodecInfo.CodecProfileLevel.HEVCProfileMain10 -> "Main 10 (10-bit)"
            MediaCodecInfo.CodecProfileLevel.HEVCProfileMainStill -> "Main Still"
            else -> null
        }
        "video/avc" -> when (profile) {
            MediaCodecInfo.CodecProfileLevel.AVCProfileBaseline -> "Baseline"
            MediaCodecInfo.CodecProfileLevel.AVCProfileMain -> "Main"
            MediaCodecInfo.CodecProfileLevel.AVCProfileHigh -> "High"
            MediaCodecInfo.CodecProfileLevel.AVCProfileHigh10 -> "High 10"
            else -> null
        }
        "video/av01" -> when (profile) {
            MediaCodecInfo.CodecProfileLevel.AV1ProfileMain8 -> "Main (8-bit)"
            MediaCodecInfo.CodecProfileLevel.AV1ProfileMain10 -> "Main 10 (10-bit)"
            else -> null
        }
        "video/x-vnd.on2.vp9" -> when (profile) {
            MediaCodecInfo.CodecProfileLevel.VP9Profile0 -> "Profile 0 (8-bit)"
            MediaCodecInfo.CodecProfileLevel.VP9Profile2 -> "Profile 2 (10-bit)"
            else -> null
        }
        else -> null
    }

    private fun isHdrProfile(mime: String, profile: Int): Boolean = when (mime.lowercase()) {
        "video/hevc" -> profile == MediaCodecInfo.CodecProfileLevel.HEVCProfileMain10 ||
            (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N &&
                profile == MediaCodecInfo.CodecProfileLevel.HEVCProfileMain10HDR10)
        "video/av01" -> profile == MediaCodecInfo.CodecProfileLevel.AV1ProfileMain10
        "video/x-vnd.on2.vp9" -> profile == MediaCodecInfo.CodecProfileLevel.VP9Profile2
        else -> false
    }
}