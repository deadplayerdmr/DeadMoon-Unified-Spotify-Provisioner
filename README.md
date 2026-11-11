<div align="center">

# 🌕 DeadMoon-Unified-Spotify-Provisioner 🌙

**Automated Windows Polyglot Provisioner for Spotify Premium Web Cookies (`sp_dc`) & Android Widevine L3 CDMs (`device.wvd`) with 3-Layer Frida Trigger & Standalone Emulator Bootstrapper**

[![DeadMoon Suite](https://img.shields.io/badge/🌕_DeadMoon-Tool_Suite-111827?style=for-the-badge&labelColor=000000)](https://github.com/Deadplayerdmr/)
[![Platform](https://img.shields.io/badge/Platform-Windows_10_%7C_11-0078D6?style=for-the-badge&logo=windows&logoColor=white)](https://www.microsoft.com/windows)
[![Python 3.13](https://img.shields.io/badge/Python-3.13-3776AB?style=for-the-badge&logo=python&logoColor=white)](https://www.python.org/)
[![KeyDive](https://img.shields.io/badge/KeyDive-v3.0.6-FF6600?style=for-the-badge)](https://github.com/hyugogirubato/KeyDive)
[![Frida](https://img.shields.io/badge/Frida-Widevine_L3-EF4444?style=for-the-badge)](https://github.com/frida/frida)
[![License](https://img.shields.io/badge/License-MIT-10B981?style=for-the-badge)](LICENSE)

*Part of the [DeadMoon Tool Suite](https://github.com/Deadplayerdmr/) by [@Deadplayerdmr](https://github.com/Deadplayerdmr)*

</div>

---

## 🖥️ Terminal Preview

```text
          .       +        .================.        *        .
       +    d~~b      .==='  .------------.  '===.      d~~b     .
          . d  b    /   .-'    .      o    '-.   \     d  b   +
                   /  .'   o       .      .   '.  \        .
        *         [===]  .    /        \    .  [===]   +       *
             .--- [===]     \____/    \____/   [===] ---.
            (     [===]   o      .----.      O [===]     )   d~b
        .    '--- [===]    .    /      \   .   [===] ---'    d b
           +       \  '.     .            o  .'  /       *
        .           '.  '-.    o   .   .  .-'  .'     .       +
             *        '===='--------------'===='          .
```

---

## 🌙 Overview

**DeadMoon-Unified-Spotify-Provisioner** is a self-contained Windows Batch / PowerShell / Python 3.13 polyglot provisioning utility designed for the **[DeadMoon-Download-Bot](https://github.com/Deadplayerdmr/DeadMoon-Download-Bot)** audio acquisition engine. It automates the extraction and cryptographic verification of:

1. **🍪 `spotify_cookies.txt`**: Netscape-formatted `.spotify.com` web session cookies (`sp_dc`, `sp_key`, `sp_t`) extracted from desktop Gecko browsers (Firefox, Floorp, Waterfox, LibreWolf, Zen) or rooted Android browsers over ADB.
2. **🔐 `device.wvd`**: Verified Android Widevine L3 Content Decryption Modules (`ANDROID`, Security Level `3`, 2048-bit RSA) extracted via live Frida instrumentation from either a connected rooted Android device or an auto-bootstrapped local Android API 30 `x86_64` emulator.

---

## ✨ Key Features & Architecture (Version 1)

- **🌕 Animated DeadMoon Boot Splash & Progress UI**: Features a 12-frame ANSI-colored ASCII animation of the DeadMoon headphone crest with floating music notes, radiating headphone soundwaves, twinkling stars, and an in-place single-line `25% -> 50% -> 75% -> 100%` progress bar.
- **🧪 Isolated Virtualenv (`.dm_tools\kd_venv`)**: Automatically builds an isolated Python 3.13 environment pinning `keydive==3.0.6`, `construct==2.10.70`, `protobuf>=5.29.5,<6.0.0`, `frida`, `requests`, and `cryptography` so KeyDive's `protobuf<6.0.0` requirement never conflicts with `DeadMoon-Download-Bot`'s runtime `pywidevine==1.9.0` (`protobuf==6.33.6`).
- **⚡ 3-Layer Widevine L3 Trigger Engine**:
  1. Launches a live DRM test stream (`bitmovin.com` / `shaka-player-demo`) in the target's browser without hooking the browser process.
  2. Injects a Java `android.media.MediaDrm` L3 session inside `com.android.settings` / `com.android.systemui` (carrying a valid Android `AttributionSource` on Android 12–16 / API 37 to bypass NDK `-10003` errors).
  3. Falls back to native NDK `AMediaDrm` (`libmediandk.so`) with automatic Google Widevine L3 certificate provisioning (`certificateprovisioning/v1/devicecertificates/create`) if the target CDM is unprovisioned (`-20001`).
- **🧹 Guaranteed Widevine HAL Cleanup**: Automatically terminates `frida-server`, restarts the Widevine DRM HAL (`android.hardware.drm-service.widevine` / `mediadrmserver`), and restores SELinux enforcing mode (`setenforce 1`) in a `finally:` block so the phone's browser never crashes after dumping.
- **📱 Phone-Free Standalone Emulator Mode (Mode `[2]`)**: If you don't have a rooted physical Android phone on hand, Mode `[2]` automatically downloads portable OpenJDK 17 (Adoptium) and Google Android `commandlinetools-win`, installs `system-images;android-30;google_apis;x86_64`, boots `DeadMoon_API30_L3`, provisions L3 with Google, extracts `device.wvd`, and shuts down the emulator.
- **🔒 Deep Cryptographic Verification & NTFS ACL Locking**: Parses and verifies the generated `.wvd` v2 structure, `ClientIdentification` protobuf, and `>=2048-bit` RSA private key before syncing `spotify_cookies.txt` and `device.wvd` into `local_resources/` and locking Windows NTFS permissions to the current user via `icacls.exe`.

---

## 🚀 Quick Start (Windows 10 / 11)

1. Ensure **Python 3.13** is installed on Windows.
2. Download **`DeadMoon_Unified_Spotify_Provisioner.cmd`** and place it in your project root (or alongside `DeadMoon-Download-Bot`).
3. Double-click **`DeadMoon_Unified_Spotify_Provisioner.cmd`** to launch:
   - **Step 1/2 (`spotify_cookies.txt`)**: Auto-detects active `.spotify.com` sessions from connected Android Firefox/Fennec/Iceraven or desktop Firefox/Floorp/Waterfox/LibreWolf/Zen profiles, or accepts a pasted `sp_dc` cookie string.
   - **Step 2/2 (`device.wvd`)**: Choose **`[1]`** Rooted USB Android Device, **`[2]`** Auto-Bootstrapped Local Android Emulator, or **`[3]`** Compile from existing `client_id.bin` + `private_key.pem`.

---

## 🔗 Integration with `DeadMoon-Download-Bot`

Once provisioned, copy or sync `spotify_cookies.txt` and `device.wvd` into `DeadMoon-Download-Bot/local_resources/` (`chmod 600` on Linux VPS). For optimal direct Spotify acquisition with `dotify-cli==3.0.6` and Android Widevine L3 CDMs without triggering Widevine HTTP `403` → `429` license rate-limits, ensure `token.env` contains:

```ini
SPOTIFY_ENABLED=1
SPOTIFY_AUDIO_QUALITY=aac-high,aac-medium
SPOTIFY_BULK_WAIT_SECONDS=4
```

*(Note: Raw `client_id.bin` and `private_key.pem` blobs remain on the provisioning host only and are never deployed to the production container.)*

---

## 📚 Credits, Citations & Upstream Attributions

This provisioning toolkit builds upon and orchestrates the following open-source projects:

- **[hyugogirubato/KeyDive (`keydive==3.0.6`)](https://github.com/hyugogirubato/KeyDive)** — Created by **[hyugogirubato](https://github.com/hyugogirubato)** for Widevine L3 CDM extraction and `.wvd` structure parsing.
- **[Frida (`frida` / `frida-server`)](https://github.com/frida/frida)** — Dynamic instrumentation toolkit used for hooking the Android Widevine HAL and executing the Java/NDK `MediaDrm` L3 trigger.
- **[devine-dl/pywidevine (`pywidevine`)](https://github.com/devine-dl/pywidevine)** — Created by **[rlaphoenix](https://github.com/rlaphoenix)** for the `.wvd` v2 container specification used by downstream acquisition engines.
- **[dotify-cli](https://pypi.org/project/dotify-cli/)** — Downstream Spotify web session and Widevine L3 audio acquisition engine used in `DeadMoon-Download-Bot`.
- **[Eclipse Adoptium (Temurin OpenJDK 17)](https://adoptium.net/)** & **[Google Android SDK Command-Line Tools](https://developer.android.com/tools)** — Used for automated local `x86_64` AVD emulator bootstrapping.

---

## 📄 License

Distributed under the [MIT License](LICENSE). All upstream packages and binaries downloaded at runtime (`keydive`, `frida-server`, `OpenJDK`, and Android SDK tools) remain under their respective authors' licenses.

---

## 🌌 The DeadMoon Tool Suite

| Repository | Role in the Ecosystem |
| :--- | :--- |
| 🌕 **[DeadMoon-Download-Bot](https://github.com/Deadplayerdmr/DeadMoon-Download-Bot)** | Whitelisted 8-platform Telegram audio acquisition bot with direct lossless engines, lock-free scheduler & 477 offline tests |
| 📻 **[DeadMoon-Telegram-Broadcaster-Bot](https://github.com/Deadplayerdmr/DeadMoon-Telegram-Broadcaster-Bot)** | 24/7 automated Telegram-to-Icecast radio broadcaster with smooth 22% audio-ducked ads, `/replaytrack` & fallback rotation |
| 🌾 **[DeadMoon-Credential-Harvester](https://github.com/Deadplayerdmr/DeadMoon-Credential-Harvester)** | Local Tampermonkey userscript (`2.3v`) for harvesting streaming ARLs, OAuth tokens, Netscape cookies & Widevine `.wvd` bundles |
| 🔐 **[DeadMoon-Unified-Spotify-Provisioner](https://github.com/Deadplayerdmr/DeadMoon-Unified-Spotify-Provisioner)** | Automated Windows polyglot provisioner for Spotify Premium `sp_dc` cookies & Android Widevine L3 `device.wvd` CDMs |
| 🎶 **[DeadMoon-Playlist-Transfer-Tool](https://github.com/Deadplayerdmr/DeadMoon-Playlist-Transfer-Tool)** | Single-file Windows polyglot tool for migrating Deezer Favorites (Artists, Albums & Playlists) via CSV |
| 🤖 **[DeadMoon-OpenHands-Launcher](https://github.com/Deadplayerdmr/DeadMoon-OpenHands-Launcher)** | Zero-friction Windows launcher & installer for OpenHands with kinetic ASCII UI & automatic `winnat` port recovery |
| 🔍 **[DeadMoon-Universal-API-Verify-Script](https://github.com/Deadplayerdmr/DeadMoon-Universal-API-Verify-Script)** | Self-contained Windows LLM statistical fingerprint verifier (`lmfpd`) with Smart Auto-Heal & catalog scanner |

---

<div align="center">

**🌕 DeadMoon-Unified-Spotify-Provisioner 🌙** — Crafted by [@Deadplayerdmr](https://github.com/Deadplayerdmr/)

</div>
