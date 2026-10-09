# Meow Player

<p align="center">
  <a href="../README.md">简体中文</a> · <b>English</b> · <a href="README.zh-Hant.md">繁體中文</a>
</p>

<p align="center">
  <b>Meow Player</b> — a local video player for Android, built around local media library playback,<br>
  with online playback, the Bilibili ecosystem, network storage, danmaku &amp; subtitles, downloads and casting alongside it.
</p>

<p align="center">
  <a href="../LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0-blue.svg" alt="License: GPL-3.0"></a>
  <img src="https://img.shields.io/badge/platform-Android-3DDC84.svg" alt="Platform: Android">
  <img src="https://img.shields.io/badge/Flutter-3.44%2B-02569B.svg" alt="Flutter">
</p>

---

## Screenshots

<p align="center">
  <img src="Pictures/screenshot-1.jpg" width="36%" alt="">
  <img src="Pictures/screenshot-2.jpg" width="44%" alt="">
</p>

---

## Features

### Media library / Home
List and tree browsing modes · MediaStore scanning (including hidden and `.nomedia` directories — [must read](nomedia-scan-notice.md)) · Configurable sorting and fields · Blacklist/whitelist filtering · Pinned folders · Multi-select batch operations · Search · Speed-dial entry · Playback history · Playback progress · Watched threshold · External video intake · Open link

### Player
Immersive landscape playback · Portrait player page · Seamless landscape/portrait switching · Double-tap gestures · Horizontal swipe to seek · Vertical swipe gestures · Long-press speed · Pinch to zoom · Progress bar thumbnails · Chapter name chips · Chapter list · Chapter skip · Intro/outro skipping · Anime4K super resolution · Aspect ratio · Decode mode (hardware decoding+ by default) · One-tap restart after changing profiles · Playback diagnostics · Volume boost (up to 200%) · Screenshot · Lock · Picture-in-picture · Dolby Vision guidance · Top info · Custom control bar · Player settings

### Audio
Audio track switching · External audio tracks · Automatic audio track fallback · Audio channels (safe auto by default) · Audio processing · Equalizer · Equalizer presets · Listen to video · Background playback · Sleep timer · Random playback at a time mark · Speed playback

### Subtitles
Embedded subtitle tracks · Chinese track priority (on by default) · External subtitle import · Automatic same-name subtitle loading · Subtitle delay · Subtitle styles · Background color and background box · Embedded style override · Custom subtitle fonts · External subtitle memory · Movie/TV subtitle downloads (Wyzie / custom endpoint)

### Danmaku
Local danmaku · Manual danmaku import · Online danmaku (DandanPlay) · Automatic matching · Automatic matching on episode switch · Bilibili native danmaku · Danmaku server management · Search history · Danmaku styles · Random gradient colors · Fixed colors (multi-color palette) · Display area and line height · Three visibility types · Massive danmaku and deduplication · Blocked words · Timeline offset · Danmaku fonts

### Network storage
WebDAV / SMB / FTP · Directory browsing · Direct playback · Range and seek · Reconnect after disconnection · Timeouts and retries · FTP Chinese encoding · Encrypted password storage

### Bilibili
TV QR-code login · Cookie import · Encrypted credentials · Anime index · Anime search · Anime details · Fullscreen episode picker · Follow-list schedule · Recommendations · Online playback · Quality switching · Anime episode list · Native danmaku · OP / ED chapters · Video downloads · Danmaku downloads

### Downloads
Task queue · Resumable transfers · Pause / resume / retry · Native merging · Failures never corrupt files · Task persistence · Download manager page

### Casting
DLNA device discovery · Stream playback · LAN media server

### File management
Copy / move · Rename · Delete · Pin / unpin · Multi-select batch operations · Transfer progress · Name conflict avoidance

### Appearance & fonts
23 theme colors · 21 palette styles · Dynamic color (Android 12+) · Custom theme color · Light/dark mode · Global app font

### System & settings
System player registration · Device info · Decoder details · Cache management · Crash logs · App updates · Privacy gate · Privacy policy and agreement · Licenses

### Languages
简体中文 / 繁體中文 / English UI · Language picker on first launch · Switch any time in Settings, effective immediately · Privacy policy and user agreement in all three languages

---

## Tech stack

| Item | Notes |
|---|---|
| Framework | Flutter 3.44+ / Dart 3.12+ |
| Playback core | media_kit + self-built libmpv (local fork, with frame-capture API `mk_thumbnail_*`) |
| State management | `ChangeNotifier` + `ListenableBuilder` |
| Persistence | `shared_preferences`; secrets use `flutter_secure_storage` |
| Danmaku rendering | `canvas_danmaku` |
| Theming | `flex_seed_scheme` (Material 3 palette derivation) |
| Networking | `http` (pure Dart) + `smb_connect` (local fork) |
| Native | Kotlin: MethodChannel `moumou/video_info` + foreground service + crash handling |

**Full technical documentation**: [`docs/PROJECT.md`](PROJECT.md) — per-file responsibilities, module implementation notes, directory layout and layering conventions, native layer.

---

## Acknowledgements

This project stands on the shoulders of many open-source projects, and we thank them. They are listed below as "foundations → self-built core → upstream libraries → reference projects".

### 1. Project foundations

The skeleton of this project comes from the following open-source projects:

| Project | Purpose |
|---|---|
| [media-kit](https://github.com/media-kit/media-kit) | Playback core |
| [canvas_danmaku](https://github.com/Predidit/canvas_danmaku) | Danmaku rendering |
| [Anime4K](https://github.com/bloc97/Anime4K) | Super resolution shaders |
| [DandanPlay](https://www.dandanplay.com/) | Online danmaku API |

### 2. Self-built core

The Android playback core is compiled by this project itself (mpv + FFmpeg + libass + libplacebo and more).
Core source, build scripts and a description of our own changes:

- [libmpv-android-video-build-thumbnail](https://github.com/azxcvn/libmpv-android-video-build-thumbnail)
- Upstream dependencies in the build chain: [FFmpeg](https://ffmpeg.org/) · [mpv](https://mpv.io/) · [libass](https://github.com/libass/libass) · [libplacebo](https://code.videolan.org/videolan/libplacebo) · [dav1d](https://code.videolan.org/videolan/dav1d) · [libxml2](https://gitlab.gnome.org/GNOME/libxml2) · [mbedTLS](https://github.com/Mbed-TLS/mbedtls) · [MediaInfoLib](https://mediaarea.net/MediaInfo)

### 3. Upstream libraries

The following libraries are locally forked by this project (placed under `third_party/`; patches and upgrade notes live in each `FORK.md`). Copyright and licenses belong to their original authors:

| Project | Purpose | License |
|---|---|---|
| [media_kit](https://github.com/media-kit/media-kit) | Player API layer (adds runtime font directory support) | MIT |
| [smb_connect](https://github.com/ikanamori/smb_connect) | SMB client (removes the global serial lock to allow concurrent requests in flight) | Apache-2.0 |
| [mediainfoAndroid](https://github.com/marlboro-advance/mediainfoAndroid) | Android bindings for MediaInfoLib | BSD-2-Clause |

### 4. Reference projects

The design and implementation ideas of the following projects were referenced during development. The scope is broad, so specific areas are not listed one by one:

- [Kazumi](https://github.com/Predidit/Kazumi)
- [mpvRx](https://github.com/Riteshp2001/mpvRx)
- [PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus)
- [Bili23-Downloader](https://github.com/ScottSloan/Bili23-Downloader) — device fingerprint and WBI signing algorithm

### 5. Icon assets

The cat-paw motif in the app icon was inspired by the cat-paw element in the bottom-left corner of another app's icon; this project extracted it and redrew it as this app's icon with the help of AI.

### 6. Other dependencies

The list of Flutter / Dart dependencies and native libraries, along with their licenses, is in [`THIRD_PARTY_NOTICES.md`](../THIRD_PARTY_NOTICES.md).

---

## License

This project is open source (copyleft) under the **[GNU General Public License v3.0](../LICENSE)**:

- You are free to use, modify and distribute the code of this project;
- **Any derivative distribution must be open sourced under the same license (GPL-3.0)**, must provide the complete corresponding source code, and must retain the original author's copyright notice.

The list of third-party components and their licenses is in [`THIRD_PARTY_NOTICES.md`](../THIRD_PARTY_NOTICES.md); the full text of every open-source license is also available in the app under "Settings → About → Licenses".
