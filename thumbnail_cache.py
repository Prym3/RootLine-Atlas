from __future__ import annotations

import hashlib
import json
import os
import shutil
import time
import threading
from pathlib import Path

from PySide6.QtCore import QObject, QUrl, Signal, Slot, Qt, QRunnable, QThreadPool
from PySide6.QtGui import QImage

_MAX_CACHE_BYTES = 10 * 1024 * 1024 * 1024
_THUMB_SIZE = 200
_FOLDER_CAP = 1000
_CACHE_ROOT = Path(__file__).with_name("cache")
_CACHE_DIR = _CACHE_ROOT / "thumbnails"

_VID_CACHE_DIR = _CACHE_ROOT / "video_thumbnails"
_VID_INDEX_PATH = _VID_CACHE_DIR / ".index.json"
_VID_STATE_PATH = _VID_CACHE_DIR / ".state.json"

_INDEX_PATH = _CACHE_DIR / ".index.json"
_STATE_PATH = _CACHE_DIR / ".state.json"


def _file_key(path: str) -> str:
    try:
        st = os.stat(path)
        payload = f"{path}\n{st.st_mtime}\n{st.st_size}"
    except OSError:
        payload = path
    return hashlib.md5(payload.encode()).hexdigest()


def _walk_cache_size() -> int:
    total = 0
    if _CACHE_DIR.exists():
        for p in _CACHE_DIR.rglob("*"):
            if p.is_file() and not p.name.startswith("."):
                try:
                    total += p.stat().st_size
                except OSError:
                    pass
    return total


def _walk_root_size() -> int:
    total = 0
    try:
        for p in _CACHE_ROOT.rglob("*"):
            if p.is_file():
                try:
                    total += p.stat().st_size
                except OSError:
                    pass
    except Exception:
        pass
    return total


def _evict_lru_global(target_bytes: int) -> int:
    try:
        files = []
        for p in _CACHE_ROOT.rglob("*"):
            if p.is_file() and not p.name.startswith("."):
                try:
                    files.append((p, p.stat().st_atime, p.stat().st_size))
                except OSError:
                    pass
        if not files:
            return 0
        files.sort(key=lambda x: x[1])
        current = sum(sz for _, _, sz in files)
        freed = 0
        for p, _, sz in files:
            if current <= target_bytes:
                break
            try:
                p.unlink()
                current -= sz
                freed += sz
            except OSError:
                pass
        for d in sorted(_CACHE_ROOT.rglob("*"), key=lambda x: len(str(x)), reverse=True):
            if d.is_dir() and d != _CACHE_ROOT:
                try:
                    d.rmdir()
                except OSError:
                    pass
        return freed
    except Exception:
        return 0




def _load_index() -> tuple[dict, int, int]:
    idx: dict[str, dict] = {}
    folder = 0
    count = 0
    if _INDEX_PATH.exists():
        try:
            with open(_INDEX_PATH, "r", encoding="utf-8") as f:
                idx = json.load(f)
        except Exception:
            idx = {}
    if _STATE_PATH.exists():
        try:
            with open(_STATE_PATH, "r", encoding="utf-8") as f:
                s = json.load(f)
                folder = s.get("folder", 0)
                count = s.get("count", 0)
        except Exception:
            pass
    return idx, folder, count


def _save_index(idx: dict, folder: int, count: int) -> None:
    try:
        with open(_INDEX_PATH, "w", encoding="utf-8") as f:
            json.dump(idx, f)
        with open(_STATE_PATH, "w", encoding="utf-8") as f:
            json.dump({"folder": folder, "count": count}, f)
    except Exception:
        pass


class _ThumbnailSignals(QObject):
    ready = Signal(str, str)
    failed = Signal(str)


class _ThumbnailWorker(QRunnable):
    def __init__(
        self,
        path: str,
        key: str,
        signals: _ThumbnailSignals,
        cache: ThumbnailCache,
    ) -> None:
        super().__init__()
        self.path = path
        self.key = key
        self.signals = signals
        self._cache = cache
        self.setAutoDelete(True)

    def run(self) -> None:
        try:
            pil_img = self._cache._decode_image_robust(self.path)
            if pil_img is None:
                self.signals.failed.emit(self.path)
                return
            data = pil_img.tobytes("raw", "RGB")
            img = QImage(data, pil_img.width, pil_img.height, pil_img.width * 3, QImage.Format.Format_RGB888)
            if img.isNull():
                self.signals.failed.emit(self.path)
                return

            scaled = img.scaled(
                _THUMB_SIZE, _THUMB_SIZE,
                Qt.AspectRatioMode.KeepAspectRatio,
                Qt.TransformationMode.SmoothTransformation,
            )

            with self._cache._lock:
                folder_idx = self._cache._current_folder
                if self._cache._current_count >= _FOLDER_CAP:
                    folder_idx += 1
                    self._cache._current_folder = folder_idx
                    self._cache._current_count = 0

                folder_name = f"{folder_idx:03d}"
                dest_dir = _CACHE_DIR / folder_name
                dest_dir.mkdir(parents=True, exist_ok=True)
                dest = dest_dir / f"{self.key}.jpg"

                ok = scaled.save(str(dest), format="JPEG", quality=92)
                if not ok:
                    self.signals.failed.emit(self.path)
                    return

                try:
                    os.utime(dest, (time.time(), dest.stat().st_mtime))
                except OSError:
                    pass

                self._cache._index[self.key] = {"folder": folder_idx, "file": f"{self.key}.jpg"}
                self._cache._current_count += 1
                _save_index(self._cache._index, self._cache._current_folder, self._cache._current_count)

                self._cache._cache_size[0] += dest.stat().st_size
                if self._cache._cache_size[0] > _MAX_CACHE_BYTES:
                    freed = _evict_lru_global(_MAX_CACHE_BYTES)
                    self._cache._cache_size[0] = max(0, self._cache._cache_size[0] - freed)

            self.signals.ready.emit(self.path, QUrl.fromLocalFile(str(dest)).toString())
        except Exception:
            self.signals.failed.emit(self.path)


class ThumbnailCache(QObject):
    thumbnailReady = Signal(str, str)

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        _CACHE_DIR.mkdir(parents=True, exist_ok=True)
        self._pool = QThreadPool()
        self._pool.setMaxThreadCount(2)
        self._pending: set[str] = set()
        self._sig = _ThumbnailSignals()
        self._sig.ready.connect(self._on_ready)
        self._sig.failed.connect(self._on_failed)

        self._lock = threading.Lock()
        self._index, self._current_folder, self._current_count = _load_index()
        self._cache_size: list[int] = [0]
        
        def load_size():
            sz = _walk_root_size()
            with self._lock:
                self._cache_size[0] = sz
        threading.Thread(target=load_size, daemon=True).start()

    def _on_ready(self, path: str, url: str) -> None:
        self._pending.discard(path)
        self.thumbnailReady.emit(path, url)

    def _on_failed(self, path: str) -> None:
        self._pending.discard(path)

    def _dest_from_index(self, key: str) -> Path | None:
        entry = self._index.get(key)
        if entry is None:
            return None
        return _CACHE_DIR / f"{entry['folder']:03d}" / entry["file"]

    @Slot(str, result=bool)
    def isCached(self, path: str) -> bool:
        if not path:
            return False
        key = _file_key(path)
        with self._lock:
            return key in self._index

    @Slot(str, result=str)
    def get(self, path: str) -> str:
        if not path:
            return ""

        key = _file_key(path)

        with self._lock:
            dest = self._dest_from_index(key)
            if dest:
                return QUrl.fromLocalFile(str(dest)).toString()

        if path not in self._pending:
            self._pending.add(path)
            self._pool.start(_ThumbnailWorker(path, key, self._sig, self))

        return ""

    @Slot(result=int)
    def cacheSizeBytes(self) -> int:
        with self._lock:
            return self._cache_size[0]

    @Slot(result=str)
    def cacheSizeText(self) -> str:
        with self._lock:
            sz = self._cache_size[0]
        if sz >= 1024 ** 3:
            return f"{sz / 1024 ** 3:.2f} GB"
        if sz >= 1024 ** 2:
            return f"{sz / 1024 ** 2:.1f} MB"
        if sz >= 1024:
            return f"{sz / 1024:.1f} KB"
        return f"{sz} B"

    @Slot()
    def clearCache(self) -> None:
        with self._lock:
            if _CACHE_ROOT.exists():
                try:
                    for item in _CACHE_ROOT.iterdir():
                        if item.name == "tabs.json":
                            continue
                        if item.is_file():
                            item.unlink()
                        elif item.is_dir():
                            shutil.rmtree(item)
                except OSError:
                    pass
            _CACHE_ROOT.mkdir(parents=True, exist_ok=True)
            _CACHE_DIR.mkdir(parents=True, exist_ok=True)
            self._index.clear()
            self._current_folder = 0
            self._current_count = 0
            self._cache_size[0] = 0
            _save_index(self._index, 0, 0)

    @Slot(str, result=str)
    def safeImageUrl(self, path: str) -> str:
        if not path:
            return ""
        try:
            key = _file_key(path)
            safe_dir = _CACHE_ROOT / "safe"
            safe_dir.mkdir(parents=True, exist_ok=True)
            dest = safe_dir / f"{key}.jpg"
            if dest.exists():
                return QUrl.fromLocalFile(str(dest)).toString()
            img = self._decode_image_robust(path)
            if img is not None:
                img.save(str(dest), format="JPEG", quality=92)
                return QUrl.fromLocalFile(str(dest)).toString()
            shell_img = _shell_thumbnail(path, _THUMB_SIZE)
            if shell_img is not None and not shell_img.isNull():
                shell_img.save(str(dest), format="JPEG", quality=92)
                return QUrl.fromLocalFile(str(dest)).toString()
        except Exception:
            pass
        return QUrl.fromLocalFile(path).toString()

    @staticmethod
    def _decode_image_robust(path: str):
        from PIL import Image
        try:
            img = Image.open(path)
            if img.mode not in ("RGB", "RGBA"):
                img = img.convert("RGB")
            if img.mode == "RGBA":
                background = Image.new("RGB", img.size, (0, 0, 0))
                background.paste(img, mask=img.split()[3])
                img = background
            return img
        except Exception:
            pass
        try:
            import cv2
            bgr = cv2.imread(path, cv2.IMREAD_COLOR)
            if bgr is not None and bgr.size > 0:
                import numpy as np
                rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
                return Image.fromarray(rgb)
        except Exception:
            pass
        import shutil
        if shutil.which("ffmpeg"):
            import subprocess, tempfile
            try:
                tmp = tempfile.mktemp(suffix=".png")
                subprocess.run(
                    ["ffmpeg", "-y", "-i", path, "-vframes", "1", "-f", "apng", tmp],
                    capture_output=True, timeout=15, check=True
                )
                img = Image.open(tmp)
                if img.mode not in ("RGB", "RGBA"):
                    img = img.convert("RGB")
                if img.mode == "RGBA":
                    background = Image.new("RGB", img.size, (0, 0, 0))
                    background.paste(img, mask=img.split()[3])
                    img = background
                try:
                    os.unlink(tmp)
                except OSError:
                    pass
                return img
            except Exception:
                pass
        return None



def _vid_load_index() -> tuple[dict, int, int]:
    idx: dict[str, dict] = {}
    folder = 0
    count = 0
    if _VID_INDEX_PATH.exists():
        try:
            with open(_VID_INDEX_PATH, "r", encoding="utf-8") as f:
                idx = json.load(f)
        except Exception:
            idx = {}
    if _VID_STATE_PATH.exists():
        try:
            with open(_VID_STATE_PATH, "r", encoding="utf-8") as f:
                s = json.load(f)
                folder = s.get("folder", 0)
                count = s.get("count", 0)
        except Exception:
            pass
    return idx, folder, count


def _vid_save_index(idx: dict, folder: int, count: int) -> None:
    try:
        with open(_VID_INDEX_PATH, "w", encoding="utf-8") as f:
            json.dump(idx, f)
        with open(_VID_STATE_PATH, "w", encoding="utf-8") as f:
            json.dump({"folder": folder, "count": count}, f)
    except Exception:
        pass




def _shell_thumbnail(path: str, size: int) -> QImage | None:
    try:
        import ctypes
        import comtypes
        from comtypes import GUID

        IID_IShellItem             = GUID("{43826D1E-E718-42EE-BC55-A1E261C37BFE}")
        IID_IShellItemImageFactory = GUID("{BCC18B79-BA16-442F-80C4-8A59C30C463B}")
        SIIGBF_BIGGERSIZEOK = 0x1

        class SIZE(ctypes.Structure):
            _fields_ = [("cx", ctypes.c_long), ("cy", ctypes.c_long)]

        shell32 = ctypes.windll.shell32
        shell32.SHCreateItemFromParsingName.restype = ctypes.HRESULT
        shell32.SHCreateItemFromParsingName.argtypes = [
            ctypes.c_wchar_p, ctypes.c_void_p,
            ctypes.POINTER(GUID), ctypes.POINTER(ctypes.c_void_p),
        ]

        psi = ctypes.c_void_p()
        hr = shell32.SHCreateItemFromParsingName(
            path, None, ctypes.byref(IID_IShellItem), ctypes.byref(psi)
        )
        if hr != 0 or not psi:
            return None

        punk = comtypes.cast(psi, comtypes.POINTER(comtypes.IUnknown))

        class IShellItemImageFactory(comtypes.IUnknown):
            _iid_ = IID_IShellItemImageFactory
            _methods_ = [
                comtypes.STDMETHOD(ctypes.HRESULT, "GetImage",
                    [SIZE, ctypes.c_uint, ctypes.POINTER(ctypes.c_void_p)]),
            ]

        try:
            factory = punk.QueryInterface(IShellItemImageFactory)
        except comtypes.COMError:
            return None

        hbmp = ctypes.c_void_p()
        hr = factory.GetImage(SIZE(size, size), SIIGBF_BIGGERSIZEOK, ctypes.byref(hbmp))
        if hr != 0 or not hbmp:
            return None

        import win32ui
        bmp      = win32ui.CreateBitmapFromHandle(hbmp.value)
        bmp_info = bmp.GetInfo()
        bmp_data = bmp.GetBitmapBits(True)
        w, h     = bmp_info["bmWidth"], bmp_info["bmHeight"]
        img = QImage(bmp_data, w, h, QImage.Format.Format_ARGB32_Premultiplied)
        img = img.convertToFormat(QImage.Format.Format_RGB888)
        ctypes.windll.gdi32.DeleteObject(hbmp)
        return img.copy()
    except Exception:
        return None


def _cv2_thumbnail(path: str, size: int) -> QImage | None:
    try:
        import cv2
        cap = cv2.VideoCapture(path)
        if not cap.isOpened():
            return None
        ok, frame = cap.read()
        cap.release()
        if not ok or frame is None:
            return None
        frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        h, w = frame_rgb.shape[:2]
        scale = size / max(w, h)
        nw, nh = max(1, int(w * scale)), max(1, int(h * scale))
        resized = cv2.resize(frame_rgb, (nw, nh), interpolation=cv2.INTER_AREA)
        img = QImage(resized.data, nw, nh, nw * 3, QImage.Format.Format_RGB888)
        return img.copy()
    except Exception:
        return None


class _VideoThumbnailWorker(QRunnable):
    def __init__(self, path: str, key: str, signals: _ThumbnailSignals, cache: "VideoThumbnailCache") -> None:
        super().__init__()
        self.path = path
        self.key = key
        self.signals = signals
        self._cache = cache
        self.setAutoDelete(True)

    def run(self) -> None:
        import ctypes
        ctypes.windll.ole32.CoInitializeEx(None, 0x2)
        try:
            img = _shell_thumbnail(self.path, _THUMB_SIZE) or _cv2_thumbnail(self.path, _THUMB_SIZE)
            if img is None or img.isNull():
                self.signals.failed.emit(self.path)
                return

            with self._cache._lock:
                folder_idx = self._cache._current_folder
                if self._cache._current_count >= _FOLDER_CAP:
                    folder_idx += 1
                    self._cache._current_folder = folder_idx
                    self._cache._current_count = 0

                dest_dir = _VID_CACHE_DIR / f"{folder_idx:03d}"
                dest_dir.mkdir(parents=True, exist_ok=True)
                dest = dest_dir / f"{self.key}.jpg"

                if not img.save(str(dest), format="JPEG", quality=92):
                    self.signals.failed.emit(self.path)
                    return

                self._cache._index[self.key] = {"folder": folder_idx, "file": f"{self.key}.jpg"}
                self._cache._current_count += 1
                _vid_save_index(self._cache._index, self._cache._current_folder, self._cache._current_count)
                self._cache._cache_size[0] += dest.stat().st_size
                if self._cache._cache_size[0] > _MAX_CACHE_BYTES:
                    freed = _evict_lru_global(_MAX_CACHE_BYTES)
                    self._cache._cache_size[0] = max(0, self._cache._cache_size[0] - freed)

            self.signals.ready.emit(self.path, QUrl.fromLocalFile(str(dest)).toString())
        except Exception:
            self.signals.failed.emit(self.path)
        finally:
            ctypes.windll.ole32.CoUninitialize()


class VideoThumbnailCache(QObject):
    thumbnailReady = Signal(str, str)

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        _VID_CACHE_DIR.mkdir(parents=True, exist_ok=True)
        self._pool = QThreadPool()
        self._pool.setMaxThreadCount(2)
        self._pending: set[str] = set()
        self._sig = _ThumbnailSignals()
        self._sig.ready.connect(self._on_ready)
        self._sig.failed.connect(self._on_failed)
        self._lock = threading.Lock()
        self._index, self._current_folder, self._current_count = _vid_load_index()
        self._cache_size: list[int] = [0]
        
        def load_size():
            sz = _walk_root_size()
            with self._lock:
                self._cache_size[0] = sz
        threading.Thread(target=load_size, daemon=True).start()

    def _on_ready(self, path: str, url: str) -> None:
        self._pending.discard(path)
        self.thumbnailReady.emit(path, url)

    def _on_failed(self, path: str) -> None:
        self._pending.discard(path)

    def _dest_from_index(self, key: str) -> Path | None:
        entry = self._index.get(key)
        if entry is None:
            return None
        return _VID_CACHE_DIR / f"{entry['folder']:03d}" / entry["file"]

    @Slot(str, result=bool)
    def isCached(self, path: str) -> bool:
        if not path:
            return False
        key = _file_key(path)
        with self._lock:
            return key in self._index

    @Slot(str, result=str)
    def get(self, path: str) -> str:
        if not path:
            return ""
        key = _file_key(path)
        with self._lock:
            dest = self._dest_from_index(key)
            if dest:
                return QUrl.fromLocalFile(str(dest)).toString()
        if path not in self._pending:
            self._pending.add(path)
            self._pool.start(_VideoThumbnailWorker(path, key, self._sig, self))
        return ""

    @Slot(result=str)
    def cacheSizeText(self) -> str:
        with self._lock:
            sz = self._cache_size[0]
        if sz >= 1024 ** 3:
            return f"{sz / 1024 ** 3:.2f} GB"
        if sz >= 1024 ** 2:
            return f"{sz / 1024 ** 2:.1f} MB"
        if sz >= 1024:
            return f"{sz / 1024:.1f} KB"
        return f"{sz} B"

    @Slot()
    def clearCache(self) -> None:
        with self._lock:
            self._index.clear()
            self._current_folder = 0
            self._current_count = 0
            self._cache_size[0] = 0
            _vid_save_index(self._index, 0, 0)
