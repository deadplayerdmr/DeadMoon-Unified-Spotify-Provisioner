<# : batch portion
@echo off
setlocal EnableExtensions
chcp 65001 >nul 2>&1
title DeadMoon Unified Spotify Provisioner - Version 1 (Phone + Emulator + WVD)
cd /d "%~dp0"
set "PROVISION_SCRIPT=%~f0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$env:ORIG_USER=$env:USERNAME; $env:ORIG_LOCALAPPDATA=$env:LOCALAPPDATA; $env:ORIG_APPDATA=$env:APPDATA; $env:SCRIPT_DIR=$PWD.Path; Invoke-Expression ([System.IO.File]::ReadAllText($env:PROVISION_SCRIPT))"
set "PS_EXIT=%ERRORLEVEL%"
echo.
pause
exit /b %PS_EXIT%
#>

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"
$ScriptDir   = if ($env:SCRIPT_DIR) { $env:SCRIPT_DIR.TrimEnd('\') } else { (Get-Location).Path }
$TargetUser  = if ($env:ORIG_USER) { $env:ORIG_USER } else { $env:USERNAME }
$ToolsDir    = Join-Path $ScriptDir ".dm_tools"
$VenvDir     = Join-Path $ToolsDir "kd_venv"
$VenvPy      = Join-Path $VenvDir "Scripts\python.exe"
$CookiesOut  = Join-Path $ScriptDir "spotify_cookies.txt"
$WvdOut      = Join-Path $ScriptDir "device.wvd"
$ClientIdOut = Join-Path $ScriptDir "client_id.bin"
$PrivKeyOut  = Join-Path $ScriptDir "private_key.pem"
$LegacyCreds = Join-Path $ScriptDir "spotify_credentials.json"

$E = [char]27
$C_RESET  = "$E[0m"
$C_BOLD   = "$E[1m"
$C_RED    = "$E[91m"
$C_GREEN  = "$E[92m"
$C_YELLOW = "$E[93m"
$C_BLUE   = "$E[94m"
$C_PURPLE = "$E[95m"
$C_CYAN   = "$E[96m"
$C_WHITE  = "$E[97m"
$C_GRAY   = "$E[90m"

function Show-StaticMoonCrest {
    Write-Host "      $C_CYAN.       +$C_RESET        $C_BLUE.================.$C_RESET        $C_CYAN*        .$C_RESET"
    Write-Host "   $C_CYAN+    $C_YELLOW`d~~b$C_RESET      $C_BLUE.==='  $C_YELLOW.------------.$C_BLUE  '===.$C_RESET      $C_YELLOW`d~~b$C_RESET     $C_CYAN.$C_RESET"
    Write-Host "      $C_CYAN. $C_YELLOW`d  b$C_RESET    $C_BLUE/   $C_YELLOW.-'    .      o    '-.$C_BLUE   \$C_RESET     $C_YELLOW`d  b$C_RESET   $C_CYAN+$C_RESET"
    Write-Host "               $C_BLUE/  $C_YELLOW.'   o       .      .   '.$C_BLUE  \$C_RESET        $C_CYAN.$C_RESET"
    Write-Host "    $C_CYAN*$C_RESET         $C_BLUE[===]$C_YELLOW  .    $C_WHITE/        \$C_YELLOW    .  $C_BLUE[===]$C_RESET   $C_CYAN+       *$C_RESET"
    Write-Host "         $C_BLUE.--- [===]$C_YELLOW     $C_WHITE\____/    \____/$C_YELLOW   $C_BLUE[===] ---.$C_RESET"
    Write-Host "        $C_BLUE(     [===]$C_YELLOW   o      $C_WHITE.----.$C_YELLOW      O $C_BLUE[===]     )$C_RESET   $C_YELLOW`d~b$C_RESET"
    Write-Host "    $C_CYAN.$C_RESET    $C_BLUE'--- [===]$C_YELLOW    .    $C_WHITE/      \$C_YELLOW   .   $C_BLUE[===] ---'$C_RESET    $C_YELLOW`d b$C_RESET"
    Write-Host "       $C_CYAN+$C_RESET       $C_BLUE\  $C_YELLOW'.     .            o  .'$C_BLUE  /$C_RESET       $C_CYAN*$C_RESET"
    Write-Host "    $C_CYAN.$C_RESET           $C_BLUE'.  $C_YELLOW'-.    o   .   .  .-'$C_BLUE  .'$C_RESET     $C_CYAN.       +$C_RESET"
    Write-Host "         $C_CYAN*$C_RESET        $C_BLUE'===='$C_YELLOW--------------$C_BLUE'===='$C_RESET          $C_CYAN.$C_RESET"
}

if (Test-Path -LiteralPath $LegacyCreds) {
    Remove-Item -LiteralPath $LegacyCreds -Force -ErrorAction SilentlyContinue
}

function Invoke-Native {
    param([scriptblock]$Command)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try { & $Command } finally { $ErrorActionPreference = $prev }
}

function Lock-FileAcl {
    param([string]$FilePath, [string]$User)
    if (Test-Path -LiteralPath $FilePath) {
        Invoke-Native { & icacls.exe $FilePath /inheritance:r /grant:r "${User}:(R,W)" >$null 2>&1 }
    }
}

function Find-Python313 {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA "Programs\Python\DeadMoon-Python313\python.exe"),
        (Join-Path $env:LOCALAPPDATA "Programs\Python\Python313\python.exe"),
        "C:\Program Files\Python313\python.exe",
        "C:\Python313\python.exe"
    )
    foreach ($c in $candidates) {
        if (Test-Path -LiteralPath $c) { return $c }
    }
    $py = Get-Command python.exe -ErrorAction SilentlyContinue
    if ($py) { return $py.Source }
    throw "Python 3.13 not found. Please install Python 3.13."
}

$BasePy = Find-Python313
if (-not (Test-Path -LiteralPath $VenvPy)) {
    Clear-Host
    Show-StaticMoonCrest
    Write-Host ""
    Write-Host "$C_PURPLE============================================================================$C_RESET"
    Write-Host "  $C_BOLD$C_YELLOW`First-Time Setup: Creating isolated virtualenv at .dm_tools\kd_venv...$C_RESET"
    Write-Host "$C_PURPLE============================================================================$C_RESET"
    Invoke-Native { & $BasePy -m venv $VenvDir }
}

Invoke-Native { & $VenvPy -c "import frida, keydive, construct, cryptography, requests, google.protobuf; assert construct.__version__ == '2.10.70'" >$null 2>&1 }
if ($LASTEXITCODE -ne 0) {
    Clear-Host
    Show-StaticMoonCrest
    Write-Host ""
    Write-Host "$C_PURPLE============================================================================$C_RESET"
    Write-Host "  $C_BOLD$C_YELLOW`Installing/Repairing KeyDive 3.0.6 + Frida in .dm_tools\kd_venv...$C_RESET"
    Write-Host "$C_PURPLE============================================================================$C_RESET"
    Invoke-Native { & $VenvPy -m pip install --upgrade pip }
    Invoke-Native { & $VenvPy -m pip uninstall -y pywidevine pymp4 >$null 2>&1 }
    Invoke-Native { & $VenvPy -m pip install --upgrade "keydive==3.0.6" "construct==2.10.70" "protobuf>=5.29.5,<6.0.0" "frida" "requests" "cryptography" }
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install KeyDive + Frida dependencies into .dm_tools\kd_venv."
    }
}

$TempPy = Join-Path ([System.IO.Path]::GetTempPath()) ("dm_unified_v1_" + [guid]::NewGuid().ToString("N") + ".py")

$PySource = @'
from __future__ import annotations
import ctypes
import glob
import json
import lzma
import os
import shutil
import sqlite3
import stat
import struct
import subprocess
import sys
import tempfile
import threading
import time
import urllib.parse
import urllib.request
import zipfile
from http.cookiejar import MozillaCookieJar
from pathlib import Path

AVD_NAME = "DeadMoon_API30_L3"
SYS_IMG  = "system-images;android-30;google_apis;x86_64"

def enable_windows_vt_ansi() -> None:
    if os.name != "nt":
        return
    try:
        kernel32 = ctypes.windll.kernel32
        handle = kernel32.GetStdHandle(-11)
        mode = ctypes.c_ulong()
        if kernel32.GetConsoleMode(handle, ctypes.byref(mode)):
            kernel32.SetConsoleMode(handle, mode.value | 0x0004)
    except Exception:
        pass

class C:
    reset  = "\x1b[0m"
    bold   = "\x1b[1m"
    dim    = "\x1b[2m"
    red    = "\x1b[91m"
    green  = "\x1b[92m"
    yellow = "\x1b[93m"
    blue   = "\x1b[94m"
    purple = "\x1b[95m"
    cyan   = "\x1b[96m"
    white  = "\x1b[97m"
    gray   = "\x1b[90m"

def get_moon_frame(frame_idx: int) -> str:
    f = frame_idx % 4
    n_col1 = C.yellow if f % 2 == 0 else C.cyan
    n_col2 = C.purple if f % 2 == 0 else C.yellow
    s1 = "*" if f == 0 else "+" if f == 1 else "." if f == 2 else "+"
    s2 = "." if f == 0 else "*" if f == 1 else "+" if f == 2 else "."

    top_note_l = (n_col1 + "d~~b" + C.reset) if f in (1, 2) else "    "
    mid_note_l = (n_col1 + "d  b" + C.reset) if f in (1, 2) else (n_col1 + "d~~b" + C.reset)
    bot_note_l = "    " if f in (1, 2) else (n_col1 + "d  b" + C.reset)

    top_note_r = (n_col2 + "d~~b" + C.reset) if f in (2, 3) else "    "
    mid_note_r = (n_col2 + "d  b" + C.reset) if f in (2, 3) else (n_col2 + "d~~b" + C.reset)
    bot_note_r = "    " if f in (2, 3) else (n_col2 + "d  b" + C.reset)

    low_note1 = (n_col1 + "d~b" + C.reset) if f in (0, 3) else "   "
    low_note2 = (n_col1 + "d b" + C.reset) if f in (0, 3) else (n_col2 + "d~b" + C.reset)
    low_note3 = "   " if f in (0, 3) else (n_col2 + "d b" + C.reset)

    wave_l = " .--- " if f == 0 else "(( .--" if f == 1 else "((( .-" if f == 2 else " ( .--"
    wave_r = " ---. " if f == 0 else "--. ))" if f == 1 else "-. )))" if f == 2 else "--. ) "
    mid_wave_l = "((    " if f in (1, 2) else " (    "
    mid_wave_r = "    ))" if f in (1, 2) else "    ) "

    eyes = "\\____/    \\____/"
    mouth = " .----. " if f == 2 else "  .---. "

    return "\n".join([
        "      " + C.cyan + s1 + "   " + top_note_l + "  " + s2 + C.reset + "        " + C.blue + ".================." + C.reset + "        " + C.cyan + s2 + "   " + top_note_r + "   " + s1 + C.reset,
        "   " + C.cyan + s2 + "    " + mid_note_l + C.reset + "      " + C.blue + ".==='  " + C.yellow + ".------------." + C.blue + "  '===." + C.reset + "      " + mid_note_r + "     " + C.cyan + s2 + C.reset,
        "      " + C.cyan + s1 + " " + bot_note_l + C.reset + "    " + C.blue + "/   " + C.yellow + ".-'    .      o    '-." + C.blue + "   \\" + C.reset + "     " + bot_note_r + "   " + C.cyan + s1 + C.reset,
        "               " + C.blue + "/  " + C.yellow + ".'   o       .      .   '." + C.blue + "  \\" + C.reset + "        " + C.cyan + s2 + C.reset,
        "    " + C.cyan + s1 + C.reset + "         " + C.blue + "[===]" + C.yellow + "  .    " + C.white + "/        \\" + C.yellow + "    .  " + C.blue + "[===]" + C.reset + "   " + C.cyan + s2 + "       " + s1 + C.reset,
        "        " + C.blue + wave_l + "[===]" + C.yellow + "     " + C.white + eyes + C.yellow + "   " + C.blue + "[===]" + wave_r + C.reset + "   " + low_note1,
        "        " + C.blue + mid_wave_l + "[===]" + C.yellow + "   o     " + C.white + mouth + C.yellow + "     O " + C.blue + "[===]" + mid_wave_r + C.reset + "   " + low_note2,
        "    " + C.cyan + s2 + C.reset + "   " + C.blue + " '--- [===]" + C.yellow + "    .    " + C.white + "/      \\" + C.yellow + "   .   " + C.blue + "[===] ---' " + C.reset + "   " + low_note3,
        "       " + C.cyan + s1 + C.reset + "       " + C.blue + "\\  " + C.yellow + "'.     .            o  .'" + C.blue + "  /" + C.reset + "       " + C.cyan + s1 + C.reset,
        "    " + C.cyan + s2 + C.reset + "           " + C.blue + "'.  " + C.yellow + "'-.    o   .   .  .-'" + C.blue + "  .'" + C.reset + "     " + C.cyan + s2 + "       " + s1 + C.reset,
        "         " + C.cyan + s1 + C.reset + "        " + C.blue + "'===='" + C.yellow + "--------------" + C.blue + "'===='" + C.reset + "          " + C.cyan + s2 + C.reset,
    ])

def run_boot_animation(script_dir: Path, cookies_out: Path, wvd_out: Path) -> None:
    stages = [
        (25,  "###---------", C.yellow, "Tuning frequencies & ADB bridge... "),
        (50,  "######------", C.cyan,   "Loading KeyDive 3.0.6 & Frida...   "),
        (75,  "#########---", C.purple, "Arming Widevine L3 CDM triggers... "),
        (100, "############", C.green,  "Ready.                             "),
    ]
    sys.stdout.write("\x1b[2J\x1b[H\x1b[?25l")
    sys.stdout.flush()
    try:
        for i in range(12):
            pct, bar, col, txt = stages[min(i // 3, 3)]
            frame = (
                "\x1b[H\n"
                + get_moon_frame(i)
                + "\n\n"
                + f"  {C.purple}============================================================================{C.reset}\n"
                + f"    {C.bold}{C.white}D E A D M O O N   U N I F I E D   S P O T I F Y   P R O V I S I O N E R{C.reset}\n"
                + f"    {C.cyan}Powered by KeyDive 3.0.6, Frida & Android Widevine L3 CDM Engine (Version 1){C.reset}\n"
                + f"  {C.purple}============================================================================{C.reset}\n"
                + f"    {C.gray}Working Folder :{C.reset} {C.white}{script_dir}{C.reset}\n"
                + f"    {C.gray}Cookie Target  :{C.reset} {C.yellow}{cookies_out}{C.reset}\n"
                + f"    {C.gray}WVD Target     :{C.reset} {C.cyan}{wvd_out}{C.reset}\n"
                + f"  {C.purple}============================================================================{C.reset}\n\n"
                + f"    {col}[Moonlight Engine] {C.white}{txt} {col}[{bar}] {pct:>3}%{C.reset}   \n"
            )
            sys.stdout.write(frame)
            sys.stdout.flush()
            time.sleep(0.15)
    finally:
        sys.stdout.write("\x1b[?25h")
        sys.stdout.flush()

def run_pulse_animation(msg: str) -> None:
    steps = [
        (25,  "###---------", "d~b  .  * "),
        (50,  "######------", " .  d~~b *"),
        (75,  "#########---", " *   . d~b"),
        (100, "############", "d~~b *  . "),
    ]
    sys.stdout.write("\n\x1b[?25l")
    sys.stdout.flush()
    try:
        for pct, bar, note in steps:
            sys.stdout.write(
                f"\r  {C.purple}( {C.yellow}{note}{C.purple} ){C.reset} "
                f"{C.cyan}[{bar}] {pct:>3}%{C.reset} {C.white}{msg}{C.reset}   "
            )
            sys.stdout.flush()
            time.sleep(0.085)
        sys.stdout.write("\n")
        sys.stdout.flush()
    finally:
        sys.stdout.write("\x1b[?25h")
        sys.stdout.flush()

def atomic_write_lf(dest: Path, payload: bytes) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_str = tempfile.mkstemp(prefix=".dm_v1_", dir=str(dest.parent), text=False)
    tmp_path = Path(tmp_str)
    try:
        with os.fdopen(fd, "wb") as handle:
            handle.write(payload)
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(tmp_path, stat.S_IRUSR | stat.S_IWUSR)
        tmp_path.replace(dest)
    except Exception:
        tmp_path.unlink(missing_ok=True)
        raise

def ensure_adb(tools_dir: Path) -> str:
    for cand in (
        tools_dir / "platform-tools" / "adb.exe",
        tools_dir / "android_sdk" / "platform-tools" / "adb.exe",
    ):
        if cand.is_file():
            os.environ["PATH"] = str(cand.parent) + os.pathsep + os.environ.get("PATH", "")
            return str(cand)
    which_adb = shutil.which("adb")
    if which_adb:
        return which_adb
    run_pulse_animation("Downloading Google Android platform-tools (ADB)...")
    tools_dir.mkdir(parents=True, exist_ok=True)
    zip_p = tools_dir / "platform-tools.zip"
    urllib.request.urlretrieve("https://dl.google.com/android/repository/platform-tools-latest-windows.zip", zip_p)
    with zipfile.ZipFile(zip_p, "r") as zf:
        zf.extractall(tools_dir)
    zip_p.unlink(missing_ok=True)
    adb_exe = tools_dir / "platform-tools" / "adb.exe"
    os.environ["PATH"] = str(adb_exe.parent) + os.pathsep + os.environ.get("PATH", "")
    return str(adb_exe)

def list_usb_devices(adb: str) -> list[str]:
    subprocess.run([adb, "start-server"], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    res = subprocess.run([adb, "devices"], capture_output=True, text=True, check=False)
    out: list[str] = []
    for line in res.stdout.splitlines():
        line = line.strip()
        if "\tdevice" in line and not line.startswith("emulator-"):
            out.append(line.split("\t")[0])
    return out

def run_root_cmd(adb: str, serial: str, shell_cmd: str, timeout: int = 20) -> subprocess.CompletedProcess:
    id_check = subprocess.run([adb, "-s", serial, "shell", "id"], capture_output=True, text=True, check=False)
    if "uid=0(root)" in (id_check.stdout or ""):
        return subprocess.run([adb, "-s", serial, "shell", shell_cmd], capture_output=True, text=True, timeout=timeout, check=False)
    escaped = shell_cmd.replace('"', '\\"')
    return subprocess.run([adb, "-s", serial, "shell", f'su -c "{escaped}"'], capture_output=True, text=True, timeout=timeout, check=False)

def elevate_device_root(adb: str, serial: str) -> str:
    subprocess.run([adb, "-s", serial, "root"], capture_output=True, text=True, check=False)
    time.sleep(1.2)
    subprocess.run([adb, "-s", serial, "wait-for-device"], check=False)
    id_res = subprocess.run([adb, "-s", serial, "shell", "id"], capture_output=True, text=True, check=False)
    if "uid=0(root)" in (id_res.stdout or ""):
        return "adb_root"
    su_res = run_root_cmd(adb, serial, "id")
    if "uid=0(root)" in (su_res.stdout or ""):
        return "su_binary"
    raise RuntimeError(
        f"Device {serial} did not grant root via 'adb root' or 'su -c id'. "
        "Unlock your phone screen and grant Superuser permission in Magisk/KernelSU, or enable Rooted Debugging."
    )

def verify_cookies_file(cookies_path: Path) -> str | None:
    if not cookies_path.is_file() or cookies_path.stat().st_size == 0:
        return None
    try:
        jar = MozillaCookieJar(str(cookies_path))
        jar.load(ignore_discard=True, ignore_expires=True)
        for cookie in jar:
            if (
                cookie.domain == ".spotify.com"
                and cookie.name == "sp_dc"
                and cookie.value
                and cookie.value != "REPLACE_WITH_SPOTIFY_WEB_SESSION_COOKIE"
                and not cookie.value.startswith("BQ")
                and len(cookie.value) >= 30
            ):
                return cookie.value
    except Exception:
        return None
    return None

def write_netscape_cookie_file(dest: Path, sp_dc: str, sp_key: str = "", sp_t: str = "") -> None:
    expiry = int(time.time()) + 31536000
    lines = [
        "# Netscape HTTP Cookie File",
        "# Generated by DeadMoon Unified Provisioner (Version 1)",
        f".spotify.com\tTRUE\t/\tTRUE\t{expiry}\tsp_dc\t{sp_dc.strip()}",
    ]
    if sp_key.strip():
        lines.append(f".spotify.com\tTRUE\t/\tTRUE\t{expiry}\tsp_key\t{sp_key.strip()}")
    if sp_t.strip():
        lines.append(f".spotify.com\tTRUE\t/\tTRUE\t{expiry}\tsp_t\t{sp_t.strip()}")
    atomic_write_lf(dest, ("\n".join(lines) + "\n").encode("utf-8"))

def inspect_sqlite_for_sp_dc(db_file: Path, source_label: str) -> list[tuple[str, str, str, str]]:
    found: list[tuple[str, str, str, str]] = []
    tmp_db = Path(tempfile.mktemp(suffix=".sqlite"))
    try:
        shutil.copy2(db_file, tmp_db)
        for sfx in ("-wal", "-shm"):
            w = Path(str(db_file) + sfx)
            if w.is_file():
                shutil.copy2(w, Path(str(tmp_db) + sfx))
        conn = sqlite3.connect(str(tmp_db))
        cur = conn.cursor()
        cur.execute(
            "SELECT name, value FROM moz_cookies "
            "WHERE host LIKE '%spotify.com' AND name IN ('sp_dc', 'sp_key', 'sp_t')"
        )
        rows = {name: val for name, val in cur.fetchall() if val}
        conn.close()
        if "sp_dc" in rows and len(rows["sp_dc"]) >= 30 and not rows["sp_dc"].startswith("BQ"):
            found.append((source_label, rows["sp_dc"], rows.get("sp_key", ""), rows.get("sp_t", "")))
    except Exception:
        pass
    finally:
        for sfx in ("", "-wal", "-shm"):
            Path(str(tmp_db) + sfx).unlink(missing_ok=True)
    return found

def discover_pc_browser_sp_dc() -> list[tuple[str, str, str, str]]:
    appdata = os.environ.get("ORIG_APPDATA") or os.environ.get("APPDATA") or ""
    if not appdata:
        return []
    search_roots = [
        ("Firefox", os.path.join(appdata, "Mozilla", "Firefox", "Profiles", "*", "cookies.sqlite")),
        ("Floorp", os.path.join(appdata, "Floorp", "Profiles", "*", "cookies.sqlite")),
        ("Waterfox", os.path.join(appdata, "Waterfox", "Profiles", "*", "cookies.sqlite")),
        ("LibreWolf", os.path.join(appdata, "librewolf", "Profiles", "*", "cookies.sqlite")),
        ("Zen", os.path.join(appdata, "zen", "Profiles", "*", "cookies.sqlite")),
    ]
    results: list[tuple[str, str, str, str]] = []
    for browser_name, pattern in search_roots:
        for db_str in glob.glob(pattern):
            db_path = Path(db_str)
            results.extend(inspect_sqlite_for_sp_dc(db_path, f"PC {browser_name} ({db_path.parent.name})"))
    return results

def discover_phone_browser_sp_dc(adb: str, serial: str | None) -> list[tuple[str, str, str, str]]:
    if not serial:
        return []
    try:
        elevate_device_root(adb, serial)
    except Exception:
        return []
    find_cmd = (
        "find /data/data/org.mozilla.firefox* /data/data/org.mozilla.fenix* "
        "/data/data/io.github.forkmaintainers.iceraven* "
        "-name 'cookies.sqlite' 2>/dev/null || true"
    )
    res = run_root_cmd(adb, serial, find_cmd)
    remote_dbs = [ln.strip() for ln in (res.stdout or "").splitlines() if ln.strip().endswith("cookies.sqlite")]
    results: list[tuple[str, str, str, str]] = []
    for idx, remote_db in enumerate(remote_dbs):
        with tempfile.TemporaryDirectory(prefix=f"dm_phone_cookie_{idx}_") as tmp_dir:
            stage_remote = f"/data/local/tmp/dm_ff_cookies_{idx}.sqlite"
            run_root_cmd(adb, serial, f"cp '{remote_db}' '{stage_remote}' && chmod 666 '{stage_remote}'")
            local_db = Path(tmp_dir) / "cookies.sqlite"
            pull_res = subprocess.run([adb, "-s", serial, "pull", stage_remote, str(local_db)], capture_output=True, check=False)
            run_root_cmd(adb, serial, f"rm -f '{stage_remote}'")
            if pull_res.returncode == 0 and local_db.is_file():
                parts = remote_db.split("/")
                pkg_label = parts[3] if len(parts) > 3 else "Android-Firefox"
                results.extend(inspect_sqlite_for_sp_dc(local_db, f"Android Phone ({serial}) {pkg_label}"))
    return results

def provision_cookies(cookies_out: Path, adb: str, usb_serial: str | None) -> None:
    run_pulse_animation("Step 1/2: Scanning for Spotify Premium sp_dc Session Cookie...")
    print(f"\n{C.purple}============================================================================{C.reset}")
    print(f"  {C.bold}{C.yellow}[Step 1/2] Provisioning spotify_cookies.txt (Netscape Format){C.reset}")
    print(f"{C.purple}============================================================================{C.reset}")
    existing = verify_cookies_file(cookies_out)
    if existing:
        masked = f"{existing[:6]}...{existing[-6:]}"
        print(f"  {C.green}[+] Existing spotify_cookies.txt is VALID Netscape format ({C.cyan}sp_dc: {masked}{C.green}, len={len(existing)}).{C.reset}")
        ans = input(f"  {C.cyan}Keep existing spotify_cookies.txt? [Y/n]: {C.reset}").strip().lower()
        if ans in ("", "y", "yes", "1"):
            return

    candidates = discover_phone_browser_sp_dc(adb, usb_serial) + discover_pc_browser_sp_dc()
    for label, sp_dc, sp_key, sp_t in candidates:
        masked = f"{sp_dc[:6]}...{sp_dc[-6:]}"
        print(f"\n  {C.yellow}[*] Found active Spotify session in [{C.white}{label}{C.yellow}] ({C.cyan}sp_dc: {masked}{C.yellow}, len={len(sp_dc)}){C.reset}")
        ans = input(f"  {C.cyan}Use this sp_dc cookie from {label}? [Y/n]: {C.reset}").strip().lower()
        if ans in ("", "y", "yes", "1"):
            write_netscape_cookie_file(cookies_out, sp_dc, sp_key, sp_t)
            verified = verify_cookies_file(cookies_out)
            if not verified:
                raise RuntimeError("Failed MozillaCookieJar verification after writing cookie.")
            print(f"  {C.green}[+] Wrote and verified Netscape cookie file: {cookies_out}{C.reset}")
            return

    print(f"\n  {C.yellow}[*] Manual Entry:{C.reset} Log into {C.cyan}https://open.spotify.com{C.reset} (Premium) -> F12 -> Storage/Application -> Cookies -> copy {C.green}'sp_dc'{C.reset}")
    raw = input(f"  {C.cyan}Paste your sp_dc value (or path to exported cookies.txt): {C.reset}").strip().strip('"').strip("'")
    if not raw:
        raise RuntimeError("No sp_dc value or cookie file path provided.")
    cand_path = Path(raw).expanduser()
    if cand_path.is_file():
        extracted = verify_cookies_file(cand_path)
        if not extracted:
            raise RuntimeError(f"File '{cand_path}' does not contain a valid .spotify.com sp_dc cookie.")
        write_netscape_cookie_file(cookies_out, extracted)
    else:
        if raw.startswith("BQ"):
            raise RuntimeError("Rejected BQ... OAuth bearer token. You must copy the 'sp_dc' cookie value (starts with AQ...).")
        if len(raw) < 30:
            raise RuntimeError("Provided sp_dc value is too short (<30 chars).")
        write_netscape_cookie_file(cookies_out, raw)

    verified = verify_cookies_file(cookies_out)
    if not verified:
        raise RuntimeError("Failed MozillaCookieJar validation on spotify_cookies.txt.")
    print(f"  {C.green}[+] Provisioned and verified: {cookies_out} (sp_dc: {verified[:6]}...{verified[-6:]}, len={len(verified)}){C.reset}")

def verify_wvd_deep(wvd_path: Path) -> str | None:
    if not wvd_path.is_file() or wvd_path.stat().st_size < 64:
        return None
    try:
        from cryptography.hazmat.primitives import serialization
        from cryptography.hazmat.primitives.asymmetric.rsa import RSAPrivateKey
        from keydive.drm.device import Device
        from keydive.drm.protocol.license_pb2 import ClientIdentification

        raw = wvd_path.read_bytes()
        if raw[:3] != b"WVD" or raw[3] != 2:
            return None
        dev = Device.supported_structure.parse(raw)
        if str(dev.type_) != "ANDROID" or int(dev.security_level) != 3:
            return None
        cid = ClientIdentification()
        cid.ParseFromString(dev.client_id)
        if not cid.IsInitialized():
            return None
        key = serialization.load_der_private_key(dev.private_key, password=None)
        if not isinstance(key, RSAPrivateKey) or key.key_size < 2048:
            return None
        info_map = {entry.name: entry.value for entry in cid.client_info}
        company = info_map.get("company_name", "Android")
        model = info_map.get("model_name", "L3")
        return f"type=ANDROID, L3, rsa={key.key_size}b, cid={len(dev.client_id)}B, device={company}/{model}"
    except Exception:
        return None

def build_wvd_from_blobs(cid_path: Path, pk_path: Path, wvd_out: Path) -> None:
    from cryptography.hazmat.primitives import serialization
    from cryptography.hazmat.primitives.asymmetric.rsa import RSAPrivateKey
    from keydive.drm.protocol.license_pb2 import ClientIdentification

    raw_pk = pk_path.read_bytes()
    if b"-----BEGIN" in raw_pk:
        priv = serialization.load_pem_private_key(raw_pk, password=None)
    else:
        priv = serialization.load_der_private_key(raw_pk, password=None)
    if not isinstance(priv, RSAPrivateKey) or priv.key_size < 2048:
        raise RuntimeError(f"{pk_path.name} is not a valid >=2048-bit RSA private key.")
    der_key = priv.private_bytes(
        encoding=serialization.Encoding.DER,
        format=serialization.PrivateFormat.TraditionalOpenSSL,
        encryption_algorithm=serialization.NoEncryption(),
    )
    client_id = cid_path.read_bytes()
    cid = ClientIdentification()
    cid.ParseFromString(client_id)
    if not cid.IsInitialized():
        raise RuntimeError(f"{cid_path.name} is not a valid ClientIdentification protobuf.")
    header = b"WVD" + struct.pack(">BBBB", 2, 2, 3, 0)
    body = struct.pack(">H", len(der_key)) + der_key + struct.pack(">H", len(client_id)) + client_id
    atomic_write_lf(wvd_out, header + body)

def post_google_provision(server_url: str, req_bytes: bytes) -> bytes:
    req_str = req_bytes.decode("utf-8", errors="ignore").strip()
    if req_str.startswith("{"):
        try:
            parsed = json.loads(req_str)
            if isinstance(parsed, dict) and "signedRequest" in parsed:
                req_str = str(parsed["signedRequest"]).strip()
        except Exception:
            pass
    sep = "&" if "?" in server_url else "?"
    for u in (
        f"{server_url}{sep}signedRequest={req_str}",
        f"{server_url}{sep}signedRequest={urllib.parse.quote(req_str, safe='')}",
    ):
        try:
            req = urllib.request.Request(
                u, data=b"",
                headers={"User-Agent": "Widevine CDM v1.0", "Content-Type": "application/json"},
                method="POST",
            )
            with urllib.request.urlopen(req, timeout=20) as resp:
                body = resp.read()
                if body and len(body) > 64:
                    return body
        except Exception:
            pass
    raise RuntimeError("Failed to POST Widevine L3 provisioning request to Google.")

def stage_frida_on_target(adb: str, serial: str, tools_dir: Path, is_emulator: bool) -> None:
    import frida
    fver = frida.__version__
    abi_res = subprocess.run([adb, "-s", serial, "shell", "getprop", "ro.product.cpu.abi"], capture_output=True, text=True, check=True)
    abi = abi_res.stdout.strip()
    if "arm64" in abi:
        arch = "arm64"
    elif "arm" in abi:
        arch = "arm"
    elif "x86_64" in abi:
        arch = "x86_64"
    else:
        arch = "x86"

    print(f"  {C.cyan}[*] Target {serial} ABI={abi} -> frida-server-{fver}-android-{arch}{C.reset}")
    fbin = tools_dir / f"frida-server-{fver}-android-{arch}"
    if not fbin.is_file() or fbin.stat().st_size == 0:
        url = f"https://github.com/frida/frida/releases/download/{fver}/frida-server-{fver}-android-{arch}.xz"
        xz_p = tools_dir / f"frida-server-{fver}-android-{arch}.xz"
        run_pulse_animation(f"Downloading frida-server-{fver}-android-{arch}.xz...")
        urllib.request.urlretrieve(url, xz_p)
        fbin.write_bytes(lzma.decompress(xz_p.read_bytes()))
        xz_p.unlink(missing_ok=True)

    root_mode = elevate_device_root(adb, serial)
    print(f"  {C.green}[*] Root access confirmed on {serial} (mode: {root_mode}). Pushing frida-server...{C.reset}")
    subprocess.run([adb, "-s", serial, "push", str(fbin), "/data/local/tmp/frida-server"], check=True)
    start_cmd = (
        "setenforce 0 2>/dev/null || true; "
        "chmod 755 /data/local/tmp/frida-server; "
        "killall -9 frida-server 2>/dev/null || true; "
        "killall -9 android.hardware.drm@1.3-service.widevine "
        "android.hardware.drm@1.4-service.widevine "
        "android.hardware.drm-service.widevine "
        "mediadrmserver 2>/dev/null || true; "
        "nohup /data/local/tmp/frida-server >/dev/null 2>&1 &"
    )
    run_root_cmd(adb, serial, start_cmd)
    time.sleep(2.0)

def cleanup_target_hal(adb: str, serial: str) -> None:
    print(f"\n  {C.cyan}[*] Cleaning up frida-server & restarting clean Widevine HAL on {serial} (prevents browser crashes)...{C.reset}")
    clean_cmd = (
        "killall -9 frida-server 2>/dev/null || true; "
        "killall -9 android.hardware.drm@1.3-service.widevine "
        "android.hardware.drm@1.4-service.widevine "
        "android.hardware.drm-service.widevine "
        "mediadrmserver mediaserver 2>/dev/null || true; "
        "setenforce 1 2>/dev/null || true"
    )
    run_root_cmd(adb, serial, clean_cmd)

def fire_multi_layer_l3_trigger(adb: str, serial: str, attempt: int) -> None:
    drm_url = "https://bitmovin.com/demos/drm" if attempt % 2 == 1 else "https://shaka-player-demo.appspot.com/"
    run_root_cmd(
        adb, serial,
        f"input keyevent KEYCODE_WAKEUP; wm dismiss-keyguard 2>/dev/null; "
        f"am start -a android.settings.SETTINGS >/dev/null 2>&1 || true; "
        f"am start -a android.intent.action.VIEW -d '{drm_url}' >/dev/null 2>&1 || true"
    )
    time.sleep(1.2)

    pids: list[int] = []
    for pkg in ("com.android.settings", "com.android.systemui", "mediaserver"):
        r = run_root_cmd(adb, serial, f"pidof {pkg}")
        for t in (r.stdout or "").split():
            if t.isdigit() and int(t) not in pids:
                pids.append(int(t))
    if not pids:
        return

    js = r"""
    (function() {
        var PSSH_BYTES = [
            0x00,0x00,0x00,0x34,0x70,0x73,0x73,0x68,0x00,0x00,0x00,0x00,
            0xed,0xef,0x8b,0xa9,0x79,0xd6,0x4a,0xce,0xa3,0xc8,0x27,0xdc,0xd5,0x1d,0x21,0xed,
            0x00,0x00,0x00,0x14,0x08,0x01,0x12,0x10,
            0xeb,0xdd,0x62,0xf1,0x68,0x14,0x27,0x7b,0x68,0xef,0x12,0x2a,0xfc,0xe4,0xae,0x3c
        ];

        function jBytesToHex(jb) {
            var out = [];
            for (var i = 0; i < jb.length; i++) {
                var b = jb[i] < 0 ? jb[i] + 256 : jb[i];
                var h = b.toString(16);
                out.push(h.length === 1 ? '0' + h : h);
            }
            return out.join('');
        }
        function hexToSignedJBytes(hex) {
            var out = [];
            for (var i = 0; i < hex.length; i += 2) {
                var b = parseInt(hex.substr(i, 2), 16);
                out.push(b > 127 ? b - 256 : b);
            }
            return out.join('');
        }

        if (typeof Java !== 'undefined' && Java.available) {
            Java.perform(function() {
                var drm = null;
                try {
                    var UUID = Java.use('java.util.UUID');
                    var MediaDrm = Java.use('android.media.MediaDrm');
                    var HashMap = Java.use('java.util.HashMap');
                    var wvUuid = UUID.fromString('edef8ba9-79d6-4ace-a3c8-27dcd51d21ed');
                    drm = MediaDrm.$new(wvUuid);
                    try { drm.setPropertyString('securityLevel', 'L3'); } catch (e) {}
                    try { drm.setPropertyString('privacyMode', 'disable'); } catch (e) {}

                    var signedPssh = PSSH_BYTES.map(function(b) { return b > 127 ? b - 256 : b; });
                    var jPssh = Java.array('byte', signedPssh);
                    var opt = HashMap.$new();

                    var sid = null;
                    try {
                        sid = drm.openSession();
                    } catch (oe) {
                        if (String(oe).indexOf('NotProvisioned') !== -1) {
                            var provReq = drm.getProvisionRequest();
                            send({
                                event: 'provision',
                                url: String(provReq.getDefaultUrl()),
                                hex: jBytesToHex(provReq.getData())
                            });
                            recv('prov_resp', function(m) {
                                try {
                                    var rawHex = m.hex || '';
                                    var sArr = [];
                                    for (var k = 0; k < rawHex.length; k += 2) {
                                        var bv = parseInt(rawHex.substr(k, 2), 16);
                                        sArr.push(bv > 127 ? bv - 256 : bv);
                                    }
                                    var respArr = Java.array('byte', sArr);
                                    drm.provideProvisionResponse(respArr);
                                    var sid2 = drm.openSession();
                                    var req2 = drm.getKeyRequest(sid2, jPssh, 'video/mp4', 1, opt);
                                    var len2 = req2 ? req2.getData().length : 0;
                                    drm.closeSession(sid2);
                                    drm.release();
                                    send({ event: 'done', mode: 'java_prov', ok: len2 > 0, bytes: len2 });
                                } catch (pe) {
                                    try { drm.release(); } catch (e2) {}
                                    send({ event: 'done', mode: 'java_prov', ok: false, err: String(pe) });
                                }
                            });
                            return;
                        }
                        throw oe;
                    }

                    var req = drm.getKeyRequest(sid, jPssh, 'video/mp4', 1, opt);
                    var len = req ? req.getData().length : 0;
                    drm.closeSession(sid);
                    drm.release();
                    send({ event: 'done', mode: 'java_mediadrm', ok: len > 0, bytes: len });
                } catch (je) {
                    if (drm !== null) {
                        try { drm.release(); } catch (e3) {}
                    }
                    send({ event: 'done', mode: 'java_mediadrm', ok: false, err: String(je) });
                }
            });
            return;
        }

        function findExp(lib, sym) {
            if (typeof Module.findExportByName === 'function') return Module.findExportByName(lib, sym);
            if (lib) { var m = Process.findModuleByName(lib); return m ? m.findExportByName(sym) : null; }
            return Module.findGlobalExportByName(sym);
        }
        var dlopenPtr = findExp(null, 'dlopen');
        if (dlopenPtr) {
            var dlopen = new NativeFunction(dlopenPtr, 'pointer', ['pointer', 'int']);
            dlopen(Memory.allocUtf8String('libmediandk.so'), 2);
        }
        var pCreate = findExp('libmediandk.so', 'AMediaDrm_createByUUID');
        var pSetProp = findExp('libmediandk.so', 'AMediaDrm_setPropertyString');
        var pOpen = findExp('libmediandk.so', 'AMediaDrm_openSession');
        var pGetProv = findExp('libmediandk.so', 'AMediaDrm_getProvisionRequest');
        var pProvideProv = findExp('libmediandk.so', 'AMediaDrm_provideProvisionResponse');
        var pGetReq = findExp('libmediandk.so', 'AMediaDrm_getKeyRequest');
        var pClose = findExp('libmediandk.so', 'AMediaDrm_closeSession');
        var pRelease = findExp('libmediandk.so', 'AMediaDrm_release');
        if (!pCreate || !pOpen || !pGetReq) { send({ event: 'done', ok: false, st: -404 }); return; }
        var createByUUID = new NativeFunction(pCreate, 'pointer', ['pointer']);
        var setProp = new NativeFunction(pSetProp, 'int', ['pointer', 'pointer', 'pointer']);
        var openSession = new NativeFunction(pOpen, 'int', ['pointer', 'pointer']);
        var getProv = new NativeFunction(pGetProv, 'int', ['pointer', 'pointer', 'pointer', 'pointer']);
        var provideProv = new NativeFunction(pProvideProv, 'int', ['pointer', 'pointer', 'size_t']);
        var getKeyReq = new NativeFunction(pGetReq, 'int', [
            'pointer', 'pointer', 'pointer', 'size_t', 'pointer', 'int',
            'pointer', 'size_t', 'pointer', 'pointer'
        ]);
        var closeSession = new NativeFunction(pClose, 'int', ['pointer', 'pointer']);
        var releaseDrm = new NativeFunction(pRelease, 'void', ['pointer']);
        function toHex(ab) {
            var u8 = new Uint8Array(ab), out = [];
            for (var i = 0; i < u8.length; i++) { var h = u8[i].toString(16); out.push(h.length === 1 ? '0' + h : h); }
            return out.join('');
        }
        function fromHex(hex) {
            var out = [];
            for (var i = 0; i < hex.length; i += 2) out.push(parseInt(hex.substr(i, 2), 16));
            return out;
        }
        function fireReq(drm, sid) {
            var pssh = Memory.alloc(PSSH_BYTES.length); pssh.writeByteArray(PSSH_BYTES);
            var reqPtr = Memory.alloc(8), reqSize = Memory.alloc(8);
            var st = getKeyReq(drm, sid, pssh, PSSH_BYTES.length, Memory.allocUtf8String('video/mp4'), 1, NULL, 0, reqPtr, reqSize);
            closeSession(drm, sid); releaseDrm(drm);
            return st;
        }
        var uuid = Memory.alloc(16);
        uuid.writeByteArray([0xed,0xef,0x8b,0xa9,0x79,0xd6,0x4a,0xce,0xa3,0xc8,0x27,0xdc,0xd5,0x1d,0x21,0xed]);
        var drm = createByUUID(uuid);
        if (drm.isNull()) { send({ event: 'done', ok: false, st: -999 }); return; }
        setProp(drm, Memory.allocUtf8String('securityLevel'), Memory.allocUtf8String('L3'));
        setProp(drm, Memory.allocUtf8String('privacyMode'), Memory.allocUtf8String('disable'));
        var sid = Memory.alloc(32);
        var stOpen = openSession(drm, sid);
        if (stOpen === 0) {
            var st = fireReq(drm, sid);
            send({ event: 'done', mode: 'ndk', ok: st === 0, st: st });
            return;
        }
        if (stOpen === -20001) {
            var pPtr = Memory.alloc(8), pSize = Memory.alloc(8), pUrl = Memory.alloc(8);
            if (getProv(drm, pPtr, pSize, pUrl) === 0) {
                var rLen = pSize.readU64().toNumber();
                var rHex = toHex(pPtr.readPointer().readByteArray(rLen));
                var uStr = pUrl.readPointer().isNull() ? 'https://www.googleapis.com/certificateprovisioning/v1/devicecertificates/create?alt=proto' : pUrl.readPointer().readUtf8String();
                send({ event: 'provision', url: uStr, hex: rHex });
                recv('prov_resp', function(m) {
                    var b = fromHex(m.hex || '');
                    var buf = Memory.alloc(b.length); buf.writeByteArray(b);
                    provideProv(drm, buf, b.length);
                    var sid2 = Memory.alloc(32);
                    if (openSession(drm, sid2) === 0) {
                        var st2 = fireReq(drm, sid2);
                        send({ event: 'done', mode: 'ndk_prov', ok: st2 === 0, st: st2 });
                    } else { releaseDrm(drm); send({ event: 'done', ok: false, st: -1 }); }
                });
                return;
            }
        }
        releaseDrm(drm); send({ event: 'done', mode: 'ndk', ok: false, st: stOpen });
    })();
    """
    import frida
    try:
        dev = frida.get_device(serial, timeout=5)
    except Exception:
        dev = frida.get_usb_device(timeout=5)
    for pid in pids:
        session = None
        state = {"ok": False}
        evt = threading.Event()
        try:
            session = dev.attach(pid)
            script = session.create_script(js)
            def on_msg(m, d):
                if m.get("type") == "send" and isinstance(m.get("payload"), dict):
                    pl = m["payload"]
                    if pl.get("event") == "provision":
                        print(f"    {C.yellow}[*] Target L3 CDM needs Google certificate provisioning; fetching cert...{C.reset}", flush=True)
                        resp = post_google_provision(pl["url"], bytes.fromhex(pl["hex"]))
                        script.post({"type": "prov_resp", "hex": resp.hex()})
                        return
                    if pl.get("ok"):
                        state["ok"] = True
                    print(f"    {C.cyan}[Trigger PID={pid}] -> {pl}{C.reset}", flush=True)
                evt.set()
            script.on("message", on_msg)
            script.load()
            evt.wait(timeout=12.0)
            if state["ok"]:
                break
        except Exception:
            pass
        finally:
            if session:
                try:
                    session.detach()
                except Exception:
                    pass

def execute_keydive_capture(adb: str, serial: str, dump_dir: Path, is_emulator: bool) -> None:
    if dump_dir.exists():
        shutil.rmtree(dump_dir, ignore_errors=True)
    dump_dir.mkdir(parents=True, exist_ok=True)

    attached_evt = threading.Event()
    stop_evt = threading.Event()

    def trigger_worker() -> None:
        attached_evt.wait(timeout=12.0)
        time.sleep(0.8)
        for i in range(1, 6):
            if stop_evt.is_set() or list(dump_dir.rglob("*.wvd")):
                return
            print(f"\n  {C.yellow}[*] [Trigger #{i}] Launching DRM page + firing Java/NDK MediaDrm L3 session on {serial}...{C.reset}")
            fire_multi_layer_l3_trigger(adb, serial, i)
            for _ in range(10):
                if stop_evt.is_set() or list(dump_dir.rglob("*.wvd")):
                    return
                time.sleep(0.5)

    t = threading.Thread(target=trigger_worker, daemon=True)
    t.start()

    proc = subprocess.Popen(
        [sys.executable, "-m", "keydive", "-s", serial, "-w", "-k", "--unencrypt", "-o", str(dump_dir)],
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1,
    )
    try:
        t0 = time.time()
        for line in iter(proc.stdout.readline, ""):
            if not line:
                break
            sys.stdout.write(line)
            sys.stdout.flush()
            if "Successfully attached hook" in line:
                attached_evt.set()
            if list(dump_dir.rglob("*.wvd")):
                time.sleep(1.0)
                break
            if time.time() - t0 > 60:
                break
    finally:
        stop_evt.set()
        if proc.poll() is None:
            proc.terminate()
        if not is_emulator:
            cleanup_target_hal(adb, serial)

def ensure_portable_jdk(tools_dir: Path) -> Path:
    jdk_root = tools_dir / "jdk17"
    existing = list(jdk_root.glob("**/bin/java.exe"))
    if existing:
        java_home = existing[0].parent.parent
        os.environ["JAVA_HOME"] = str(java_home)
        os.environ["PATH"] = str(java_home / "bin") + os.pathsep + os.environ.get("PATH", "")
        return java_home

    run_pulse_animation("Downloading portable OpenJDK 17 (Adoptium)...")
    jdk_root.mkdir(parents=True, exist_ok=True)
    jdk_zip = tools_dir / "openjdk17.zip"
    jdk_url = "https://api.adoptium.net/v3/binary/latest/17/ga/windows/x64/jdk/hotspot/normal/eclipse?project=jdk"
    req = urllib.request.Request(jdk_url, headers={"User-Agent": "DeadMoon-Bootstrap/1.0"})
    with urllib.request.urlopen(req, timeout=120) as resp, open(jdk_zip, "wb") as out:
        shutil.copyfileobj(resp, out)
    with zipfile.ZipFile(jdk_zip, "r") as zf:
        zf.extractall(jdk_root)
    jdk_zip.unlink(missing_ok=True)
    java_exe = list(jdk_root.glob("**/bin/java.exe"))[0]
    java_home = java_exe.parent.parent
    os.environ["JAVA_HOME"] = str(java_home)
    os.environ["PATH"] = str(java_home / "bin") + os.pathsep + os.environ.get("PATH", "")
    return java_home

def ensure_android_sdk_and_avd(tools_dir: Path) -> tuple[Path, Path]:
    ensure_portable_jdk(tools_dir)
    sdk_root = tools_dir / "android_sdk"
    avd_home = tools_dir / "avd_home"
    sdk_root.mkdir(parents=True, exist_ok=True)
    avd_home.mkdir(parents=True, exist_ok=True)

    os.environ["ANDROID_HOME"] = str(sdk_root)
    os.environ["ANDROID_SDK_ROOT"] = str(sdk_root)
    os.environ["ANDROID_AVD_HOME"] = str(avd_home)

    cmdline_latest = sdk_root / "cmdline-tools" / "latest"
    sdkmanager = cmdline_latest / "bin" / "sdkmanager.bat"
    avdmanager = cmdline_latest / "bin" / "avdmanager.bat"

    if not sdkmanager.is_file():
        run_pulse_animation("Downloading Google Android commandlinetools-win...")
        zip_path = tools_dir / "cmdline-tools.zip"
        url = "https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip"
        urllib.request.urlretrieve(url, zip_path)
        tmp_extract = tools_dir / "cmdline_extract"
        if tmp_extract.exists():
            shutil.rmtree(tmp_extract, ignore_errors=True)
        with zipfile.ZipFile(zip_path, "r") as zf:
            zf.extractall(tmp_extract)
        zip_path.unlink(missing_ok=True)
        cmdline_latest.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(tmp_extract / "cmdline-tools"), str(cmdline_latest))
        shutil.rmtree(tmp_extract, ignore_errors=True)

    emu_exe = sdk_root / "emulator" / "emulator.exe"
    adb_exe = sdk_root / "platform-tools" / "adb.exe"
    sys_img_dir = sdk_root / "system-images" / "android-30" / "google_apis" / "x86_64"

    if not emu_exe.is_file() or not adb_exe.is_file() or not sys_img_dir.is_dir():
        run_pulse_animation("Installing Android SDK packages (emulator + android-30 x86_64)...")
        yes_input = ("y\n" * 40).encode("ascii")
        subprocess.run([str(sdkmanager), f"--sdk_root={sdk_root}", "--licenses"], input=yes_input, check=False, stdout=subprocess.DEVNULL)
        subprocess.run(
            [str(sdkmanager), f"--sdk_root={sdk_root}", "platform-tools", "emulator", "platforms;android-30", SYS_IMG],
            input=yes_input, check=True,
        )

    avd_ini = avd_home / f"{AVD_NAME}.ini"
    if not avd_ini.is_file():
        print(f"  {C.cyan}[*] Creating x86_64 AVD '{AVD_NAME}'...{C.reset}")
        subprocess.run(
            [str(avdmanager), "create", "avd", "-n", AVD_NAME, "-k", SYS_IMG, "-d", "pixel_4", "--force"],
            input=b"no\n", check=True,
        )

    os.environ["PATH"] = str(adb_exe.parent) + os.pathsep + os.environ.get("PATH", "")
    return adb_exe, emu_exe

def find_running_emulator(adb: str) -> str | None:
    res = subprocess.run([adb, "devices"], capture_output=True, text=True, check=False)
    for ln in res.stdout.splitlines():
        ln = ln.strip()
        if ln.startswith("emulator-") and "\tdevice" in ln:
            return ln.split("\t")[0]
    return None

def boot_emulator(adb: str, emu_exe: Path) -> tuple[str, subprocess.Popen | None]:
    subprocess.run([adb, "start-server"], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    existing = find_running_emulator(adb)
    if existing:
        print(f"  {C.green}[+] Attached to already-running emulator: {existing}{C.reset}")
        return existing, None

    run_pulse_animation(f"Booting local Android Emulator '{AVD_NAME}'...")
    emu_proc = subprocess.Popen(
        [str(emu_exe), "-avd", AVD_NAME, "-no-snapshot", "-no-audio", "-no-boot-anim", "-gpu", "swiftshader_indirect"],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
    serial = None
    for _ in range(90):
        if emu_proc.poll() is not None:
            raise RuntimeError("emulator.exe exited prematurely. Ensure Windows Hyper-V / WHPX or HAXM is enabled.")
        serial = find_running_emulator(adb)
        if serial:
            break
        time.sleep(2.0)
    if not serial:
        emu_proc.terminate()
        raise RuntimeError("Timed out waiting for emulator-* to appear on ADB.")

    print(f"  {C.yellow}[*] Waiting for {serial} Android OS boot to complete...{C.reset}")
    for _ in range(90):
        r = subprocess.run([adb, "-s", serial, "shell", "getprop", "sys.boot_completed"], capture_output=True, text=True, check=False)
        if r.stdout.strip() == "1":
            print(f"  {C.green}[+] Emulator {serial} booted!{C.reset}")
            time.sleep(3.0)
            return serial, emu_proc
        time.sleep(2.0)
    emu_proc.terminate()
    raise RuntimeError("Timed out waiting for emulator sys.boot_completed=1.")

def provision_wvd(wvd_out: Path, script_dir: Path, tools_dir: Path, adb: str) -> None:
    run_pulse_animation("Step 2/2: Preparing Widevine L3 CDM Provisioning Engine...")
    print(f"\n{C.purple}============================================================================{C.reset}")
    print(f"  {C.bold}{C.yellow}[Step 2/2] Provisioning device.wvd (Android Widevine L3 CDM){C.reset}")
    print(f"{C.purple}============================================================================{C.reset}")
    existing_info = verify_wvd_deep(wvd_out)
    if existing_info:
        print(f"  {C.green}[+] Valid device.wvd already exists ({C.cyan}{existing_info}{C.green}).{C.reset}")
        ans = input(f"  {C.cyan}Keep existing device.wvd? [Y/n]: {C.reset}").strip().lower()
        if ans in ("", "y", "yes", "1"):
            return

    for cand in [p for p in script_dir.glob("*.wvd") if p.resolve() != wvd_out.resolve()]:
        cand_info = verify_wvd_deep(cand)
        if cand_info:
            print(f"  {C.yellow}[*] Found valid WVD file '{cand.name}' ({cand_info}).{C.reset}")
            if input(f"  {C.cyan}Use '{cand.name}' as device.wvd? [Y/n]: {C.reset}").strip().lower() in ("", "y", "yes", "1"):
                atomic_write_lf(wvd_out, cand.read_bytes())
                print(f"  {C.green}[+] Copied {cand.name} -> {wvd_out}{C.reset}")
                return

    print(f"\n  {C.bold}{C.yellow}Select Widevine L3 Provisioning Mode:{C.reset}")
    print(f"    {C.cyan}[1]{C.reset} Dump from Connected Rooted Android Device {C.gray}(USB - Any Rooted Phone/Tablet){C.reset}")
    print(f"    {C.cyan}[2]{C.reset} Auto-Download & Dump from Local Standalone Android Emulator {C.gray}(No Phone Needed){C.reset}")
    print(f"    {C.cyan}[3]{C.reset} Build from existing client_id.bin + private_key.pem {C.gray}(or provide .wvd path){C.reset}")
    choice = input(f"\n  {C.bold}{C.cyan}Select [1/2/3] (default 1): {C.reset}").strip() or "1"

    dump_dir = script_dir / "wvd_dump"

    if choice == "1":
        usb_list = list_usb_devices(adb)
        if not usb_list:
            input(f"  {C.yellow}[!] Plug in your rooted Android device with USB Debugging enabled and press ENTER...{C.reset}")
            usb_list = list_usb_devices(adb)
        if not usb_list:
            raise RuntimeError("No physical Android USB device detected.")
        serial = usb_list[0]
        print(f"  {C.green}[+] Using rooted USB Android device: {serial}{C.reset}")
        stage_frida_on_target(adb, serial, tools_dir, is_emulator=False)
        execute_keydive_capture(adb, serial, dump_dir, is_emulator=False)
    elif choice == "2":
        adb_emu, emu_exe = ensure_android_sdk_and_avd(tools_dir)
        serial, emu_proc = boot_emulator(str(adb_emu), emu_exe)
        try:
            stage_frida_on_target(str(adb_emu), serial, tools_dir, is_emulator=True)
            execute_keydive_capture(str(adb_emu), serial, dump_dir, is_emulator=True)
        finally:
            if emu_proc is not None and emu_proc.poll() is None:
                print(f"  {C.cyan}[*] Shutting down temporary emulator {serial}...{C.reset}")
                subprocess.run([str(adb_emu), "-s", serial, "emu", "kill"], check=False)
                emu_proc.terminate()
    elif choice == "3":
        cid_p = script_dir / "client_id.bin"
        pk_p  = script_dir / "private_key.pem"
        if not cid_p.is_file():
            cid_p = Path(input(f"  {C.cyan}Enter path to client_id.bin (or .wvd file): {C.reset}").strip().strip('"'))
        if cid_p.suffix.lower() == ".wvd":
            atomic_write_lf(wvd_out, cid_p.read_bytes())
        else:
            if not pk_p.is_file():
                pk_p = Path(input(f"  {C.cyan}Enter path to private_key.pem: {C.reset}").strip().strip('"'))
            build_wvd_from_blobs(cid_p, pk_p, wvd_out)
    else:
        raise RuntimeError(f"Unknown option: {choice}")

    if choice in ("1", "2"):
        wvds = sorted(dump_dir.rglob("*.wvd"), key=lambda p: p.stat().st_mtime, reverse=True)
        cids = sorted(dump_dir.rglob("client_id.bin"), key=lambda p: p.stat().st_mtime, reverse=True)
        pks  = sorted([p for p in dump_dir.rglob("*.pem") if "oem" not in p.name.lower()], key=lambda p: p.stat().st_mtime, reverse=True)
        if wvds:
            atomic_write_lf(wvd_out, wvds[0].read_bytes())
        elif cids and pks:
            build_wvd_from_blobs(cids[0], pks[0], wvd_out)
        if cids:
            atomic_write_lf(script_dir / "client_id.bin", cids[0].read_bytes())
        if pks:
            atomic_write_lf(script_dir / "private_key.pem", pks[0].read_bytes())

    final_info = verify_wvd_deep(wvd_out)
    if not final_info:
        raise RuntimeError(f"Generated {wvd_out} failed deep ANDROID L3 verification.")
    print(f"\n  {C.green}[+] Provisioned and verified: {wvd_out} ({C.cyan}{final_info}{C.green}){C.reset}")

def sync_to_bot_local_resources(script_dir: Path, cookies_out: Path, wvd_out: Path) -> None:
    search_dirs = [
        script_dir / "local_resources",
        script_dir / "DeadMoon_Download_BotV3" / "local_resources",
        script_dir.parent / "local_resources",
        script_dir.parent / "DeadMoon_Download_BotV3" / "local_resources",
    ]
    for lr in search_dirs:
        if lr.is_dir():
            ans = input(f"\n  {C.yellow}[*] Found bot folder '{lr}'. Copy spotify_cookies.txt + device.wvd there now? [Y/n]: {C.reset}").strip().lower()
            if ans in ("", "y", "yes", "1"):
                atomic_write_lf(lr / "spotify_cookies.txt", cookies_out.read_bytes())
                atomic_write_lf(lr / "device.wvd", wvd_out.read_bytes())
                (lr / "spotify_credentials.json").unlink(missing_ok=True)
                print(f"  {C.green}[+] Synced spotify_cookies.txt and device.wvd -> {lr}{C.reset}")
            break

def main() -> int:
    enable_windows_vt_ansi()
    script_dir  = Path(sys.argv[1]).resolve()
    cookies_out = Path(sys.argv[2]).resolve()
    wvd_out     = Path(sys.argv[3]).resolve()
    tools_dir   = script_dir / ".dm_tools"

    run_boot_animation(script_dir, cookies_out, wvd_out)

    adb = ensure_adb(tools_dir)
    usb_devices = list_usb_devices(adb)
    usb_serial = usb_devices[0] if usb_devices else None
    if usb_serial:
        print(f"\n  {C.green}[+] Detected USB Android device: {C.cyan}{usb_serial}{C.reset}")

    provision_cookies(cookies_out, adb, usb_serial)
    provision_wvd(wvd_out, script_dir, tools_dir, adb)
    sync_to_bot_local_resources(script_dir, cookies_out, wvd_out)
    run_pulse_animation("DeadMoon Provisioning Complete. Stay safe in the cosmos!")
    return 0

if __name__ == "__main__":
    sys.exit(main())
'@

try {
    [System.IO.File]::WriteAllText($TempPy, $PySource, [System.Text.UTF8Encoding]::new($false))
    Invoke-Native { & $VenvPy $TempPy $ScriptDir $CookiesOut $WvdOut }
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Lock-FileAcl -FilePath $CookiesOut  -User $TargetUser
    Lock-FileAcl -FilePath $WvdOut      -User $TargetUser
    Lock-FileAcl -FilePath $ClientIdOut -User $TargetUser
    Lock-FileAcl -FilePath $PrivKeyOut  -User $TargetUser
    Write-Host "`n$C_GREEN[+] Locked NTFS ACLs on provisioned credentials for user '$TargetUser'.$C_RESET"
}
finally {
    Remove-Item -LiteralPath $TempPy -Force -ErrorAction SilentlyContinue
}
