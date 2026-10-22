"""GitHub-release based updater for the Windows one-file build.

The UI never leaves the application: it checks the public release feed,
downloads the replacement executable and starts a small PowerShell helper that
waits for this process to exit before copying the new file into place.
"""

from __future__ import annotations

import hashlib
import json
import os
import re
import subprocess
import sys
import threading
import urllib.error
import urllib.request
from pathlib import Path

from PySide6.QtCore import QCoreApplication, QObject, Property, QTimer, Signal, Slot

try:
    from .version import APP_VERSION, GITEE_RELEASES_API, GITEE_RELEASES_PAGE, RELEASES_API
except ImportError:  # pragma: no cover
    from version import APP_VERSION, GITEE_RELEASES_API, GITEE_RELEASES_PAGE, RELEASES_API


RELEASES_PAGE = GITEE_RELEASES_PAGE
RELEASE_ENDPOINTS = (
    GITEE_RELEASES_API,
    RELEASES_API,
    "https://gh-proxy.com/" + RELEASES_API,
    "https://ghfast.top/" + RELEASES_API,
    "https://ghproxy.net/" + RELEASES_API,
)
DOWNLOAD_PROXIES = (
    "https://gh-proxy.com/",
    "https://ghfast.top/",
    "https://ghproxy.net/",
)


def _url_opener(use_system_proxy: bool):
    if use_system_proxy:
        return urllib.request.build_opener()
    return urllib.request.build_opener(urllib.request.ProxyHandler({}))


def _friendly_network_error(exc: Exception) -> str:
    if isinstance(exc, urllib.error.HTTPError):
        if exc.code == 404:
            return "还没有发布版本"
        if exc.code == 403:
            return "更新服务暂时受限，请稍后再试，或手动打开下载页。"
    return "无法连接更新服务器。请检查网络或代理是否开启；也可以手动打开下载页下载。"


def _version_key(value: str) -> tuple[int, ...]:
    parts = [int(item) for item in re.findall(r"\d+", str(value or ""))]
    return tuple((parts + [0, 0, 0])[:4])


def _update_dir() -> Path:
    base = os.environ.get("LOCALAPPDATA") or str(Path.home())
    path = Path(base) / "词序桌面版" / "updates"
    path.mkdir(parents=True, exist_ok=True)
    return path


class Updater(QObject):
    changed = Signal()
    _check_finished = Signal(object, str)
    _download_progress = Signal(int)
    _download_finished = Signal(str)
    _download_failed = Signal(str)

    def __init__(self, backend, parent=None):
        super().__init__(parent)
        self._backend = backend
        self._state = "idle"
        self._latest = ""
        self._available = False
        self._download_url = ""
        self._download_size = 0
        self._digest = ""
        self._notes = ""
        self._error = ""
        self._progress = 0
        self._download_path: Path | None = None
        self._busy = False
        self._serial = 0

        self._check_finished.connect(self._on_check_finished)
        self._download_progress.connect(self._on_download_progress)
        self._download_finished.connect(self._on_download_finished)
        self._download_failed.connect(self._on_download_failed)

    # ---------------------------------------------------------------- properties
    @Property(str, notify=changed)
    def currentVersion(self):
        return APP_VERSION

    @Property(str, notify=changed)
    def latestVersion(self):
        return self._latest

    @Property(bool, notify=changed)
    def available(self):
        return self._available

    @Property(str, notify=changed)
    def state(self):
        return self._state

    @Property(int, notify=changed)
    def progress(self):
        return self._progress

    @Property(str, notify=changed)
    def releaseNotes(self):
        return self._notes

    @Property(str, notify=changed)
    def errorText(self):
        return self._error

    @Property(str, notify=changed)
    def releasePage(self):
        return RELEASES_PAGE

    @Property(str, notify=changed)
    def statusText(self):
        if self._state == "checking":
            return "正在检查更新…"
        if self._state == "available":
            return "发现新版本 v" + self._latest
        if self._state == "downloading":
            return "正在下载更新… " + str(self._progress) + "%"
        if self._state == "ready":
            return "更新包已下载，准备安装"
        if self._state == "installing":
            return "正在退出并安装新版本…"
        if self._state == "latest":
            return "已是最新版本"
        if self._state == "error":
            return self._error or "检查更新失败"
        return "尚未检查更新"

    # ---------------------------------------------------------------- lifecycle
    @Slot()
    def startAutoCheck(self):
        QTimer.singleShot(3200, self.autoCheck)

    @Slot()
    def autoCheck(self):
        settings = getattr(self._backend, "settings", {}) or {}
        if settings.get("autoCheckUpdates") is False:
            return
        if self._state in {"checking", "downloading", "ready", "installing"}:
            return
        self.checkForUpdates()

    @Slot()
    def checkForUpdates(self):
        if self._busy:
            return
        self._busy = True
        self._serial += 1
        serial = self._serial
        self._state = "checking"
        self._error = ""
        self._available = False
        self.changed.emit()
        threading.Thread(target=self._check_worker, args=(serial,), daemon=True).start()

    # ---------------------------------------------------------------- network
    def _fetch_release(self):
        last_error = None
        headers = {
            "User-Agent": "Cixu-Vocabulary-Studio-Updater",
            "Accept": "application/vnd.github+json",
        }
        for endpoint in RELEASE_ENDPOINTS:
            for use_proxy in (True, False):
                try:
                    request = urllib.request.Request(endpoint, headers=headers)
                    with _url_opener(use_proxy).open(request, timeout=7) as response:
                        payload = json.loads(response.read().decode("utf-8"))
                    if isinstance(payload, dict) and (payload.get("tag_name") or payload.get("name")):
                        return payload
                except Exception as exc:  # noqa: BLE001 - try the next route
                    last_error = exc
        raise last_error or RuntimeError("no update route")

    def _check_worker(self, serial: int):
        try:
            payload = self._fetch_release()
            tag = str(payload.get("tag_name") or payload.get("name") or "").strip()
            latest = tag[1:] if tag.lower().startswith("v") else tag
            assets = payload.get("assets") or []
            exe_assets = [item for item in assets
                          if str(item.get("name", "")).lower().endswith(".exe")]
            preferred = [item for item in exe_assets
                         if "cixu" in str(item.get("name", "")).lower()
                         or "词序" in str(item.get("name", ""))]
            asset = (preferred or exe_assets or [None])[0]
            if _version_key(latest) <= _version_key(APP_VERSION):
                self._check_finished.emit({"status": "latest", "version": latest}, "")
                return
            if not asset:
                self._check_finished.emit({}, "新版本还没有可下载的 exe 安装包")
                return
            notes = str(payload.get("body") or "").strip()
            if len(notes) > 5000:
                notes = notes[:5000] + "…"
            download_url = str(asset.get("browser_download_url") or asset.get("url") or "")
            self._check_finished.emit({
                "status": "available",
                "version": latest,
                "url": download_url,
                "size": int(asset.get("size") or 0),
                "digest": str(asset.get("digest") or ""),
                "notes": notes,
                "serial": serial,
            }, "")
        except Exception as exc:  # noqa: BLE001 - network errors are user-facing
            self._check_finished.emit({}, _friendly_network_error(exc))

    @Slot(object, str)
    def _on_check_finished(self, payload: object, error: str):
        self._busy = False
        data = payload if isinstance(payload, dict) else {}
        if error:
            self._state = "error"
            self._error = error
            self.changed.emit()
            return
        if data.get("status") == "latest":
            self._state = "latest"
            self._available = False
            self._latest = str(data.get("version") or "")
            self.changed.emit()
            return
        self._latest = str(data.get("version") or "")
        self._download_url = str(data.get("url") or "")
        self._download_size = int(data.get("size") or 0)
        self._digest = str(data.get("digest") or "")
        self._notes = str(data.get("notes") or "本次更新包含问题修复与体验改进。")
        self._available = bool(self._download_url)
        self._state = "available" if self._available else "error"
        self._error = "" if self._available else "更新包地址无效"
        self.changed.emit()

    # ---------------------------------------------------------------- download
    @Slot()
    def downloadAndInstall(self):
        if not self._available or self._busy:
            return
        self._busy = True
        self._state = "downloading"
        self._progress = 0
        self._error = ""
        self.changed.emit()
        threading.Thread(target=self._download_worker, daemon=True).start()

    def _download_worker(self):
        target = _update_dir() / ("词序-" + (self._latest or "new") + ".exe")
        part = target.with_suffix(".exe.part")
        if target.exists() and target.stat().st_size == self._download_size and self._download_size > 5_000_000:
            self._download_finished.emit(str(target))
            return
        base_url = self._download_url
        candidates = [base_url] + [proxy + base_url for proxy in DOWNLOAD_PROXIES]
        last_error = None
        for url in candidates:
            for use_proxy in (True, False):
                try:
                    request = urllib.request.Request(
                        url,
                        headers={
                            "User-Agent": "Cixu-Vocabulary-Studio-Updater",
                            "Accept": "application/octet-stream",
                        },
                    )
                    digest = hashlib.sha256()
                    received = 0
                    with _url_opener(use_proxy).open(request, timeout=30) as response, part.open("wb") as handle:
                        total = int(response.headers.get("Content-Length") or self._download_size or 0)
                        while True:
                            chunk = response.read(262144)
                            if not chunk:
                                break
                            handle.write(chunk)
                            digest.update(chunk)
                            received += len(chunk)
                            if total > 0:
                                self._download_progress.emit(min(99, int(received * 100 / total)))
                    if received < 5_000_000:
                        raise RuntimeError("下载文件不完整")
                    if self._digest.lower().startswith("sha256:"):
                        expected = self._digest.split(":", 1)[1].strip().lower()
                        if digest.hexdigest().lower() != expected:
                            raise RuntimeError("更新包校验失败")
                    with part.open("rb") as handle:
                        if handle.read(2) != b"MZ":
                            raise RuntimeError("下载的文件不是 Windows 程序")
                    part.replace(target)
                    self._download_finished.emit(str(target))
                    return
                except Exception as exc:  # noqa: BLE001 - try the next route
                    last_error = exc
                    try:
                        part.unlink(missing_ok=True)
                    except OSError:
                        pass
        self._download_failed.emit("下载失败：" + _friendly_network_error(last_error or RuntimeError("no route")))

    @Slot(int)
    def _on_download_progress(self, value: int):
        self._progress = max(0, min(99, int(value)))
        self.changed.emit()

    @Slot(str)
    def _on_download_finished(self, path: str):
        self._busy = False
        self._download_path = Path(path)
        self._state = "ready"
        self._progress = 100
        self.changed.emit()
        QTimer.singleShot(750, self.install)

    @Slot(str)
    def _on_download_failed(self, message: str):
        self._busy = False
        self._state = "error"
        self._error = message
        self.changed.emit()

    # ---------------------------------------------------------------- install
    @Slot()
    def install(self):
        if not self._download_path or not self._download_path.exists():
            self._state = "error"
            self._error = "更新包已丢失，请重新下载"
            self.changed.emit()
            return
        if not getattr(sys, "frozen", False):
            self._state = "error"
            self._error = "开发模式不支持自动覆盖安装"
            self.changed.emit()
            return
        target = Path(sys.executable).resolve()
        script = _update_dir() / "apply_update.ps1"
        try:
            script.write_text(
                """param(
    [int]$ProcessId,
    [string]$Source,
    [string]$Target
)
try {
    Wait-Process -Id $ProcessId -Timeout 30 -ErrorAction SilentlyContinue
} catch {}
Start-Sleep -Milliseconds 700
for ($i = 0; $i -lt 30; $i++) {
    try {
        Copy-Item -LiteralPath $Source -Destination $Target -Force -ErrorAction Stop
        break
    } catch {
        Start-Sleep -Milliseconds 500
    }
}
Start-Process -FilePath $Target
Remove-Item -LiteralPath $PSCommandPath -Force -ErrorAction SilentlyContinue
""",
                encoding="utf-8-sig",
            )
            flags = getattr(subprocess, "CREATE_NO_WINDOW", 0)
            subprocess.Popen(
                ["powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass",
                 "-WindowStyle", "Hidden", "-File", str(script),
                 "-ProcessId", str(os.getpid()),
                 "-Source", str(self._download_path),
                 "-Target", str(target)],
                stdin=subprocess.DEVNULL,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                creationflags=flags,
            )
        except OSError as exc:
            self._state = "error"
            self._error = "无法启动安装程序：" + str(exc)
            self.changed.emit()
            return
        self._state = "installing"
        self._progress = 100
        self.changed.emit()
        QTimer.singleShot(500, QCoreApplication.quit)
