from __future__ import annotations

import os
import sys
import json
from pathlib import Path
import ctypes
from ctypes import wintypes

HWND_TOPMOST = -1
HWND_NOTOPMOST = -2
HWND_TOP = 0
SWP_NOMOVE = 0x0002
SWP_NOSIZE = 0x0001
SWP_SHOWWINDOW = 0x0040
SWP_HIDEWINDOW = 0x0080
SWP_NOACTIVATE = 0x0010

_SETTINGS_FILE = Path(__file__).parent / ".settings.json"

def _load_volume() -> float:
    try:
        data = json.loads(_SETTINGS_FILE.read_text(encoding="utf-8"))
        return float(data.get("video_volume", 100.0))
    except Exception:
        return 100.0

def _save_volume(volume: float):
    try:
        data = {}
        if _SETTINGS_FILE.exists():
            data = json.loads(_SETTINGS_FILE.read_text(encoding="utf-8"))
        data["video_volume"] = round(volume, 1)
        _SETTINGS_FILE.write_text(json.dumps(data, indent=2), encoding="utf-8")
    except Exception:
        pass

user32 = ctypes.windll.user32
kernel32 = ctypes.windll.kernel32

GetWindowLongPtr = user32.GetWindowLongPtrW
GetWindowLongPtr.argtypes = [wintypes.HWND, wintypes.INT]
GetWindowLongPtr.restype = ctypes.c_ssize_t

SetWindowLongPtr = user32.SetWindowLongPtrW
SetWindowLongPtr.argtypes = [wintypes.HWND, wintypes.INT, ctypes.c_ssize_t]
SetWindowLongPtr.restype = ctypes.c_ssize_t

SetParent = user32.SetParent
SetParent.argtypes = [wintypes.HWND, wintypes.HWND]
SetParent.restype = wintypes.HWND

GWL_STYLE = -16
GWL_EXSTYLE = -20
WS_CHILD = 0x40000000
WS_POPUP = 0x80000000
WS_EX_LAYERED = 0x00080000
WS_EX_TRANSPARENT = 0x00000020
WS_EX_NOACTIVATE = 0x08000000

SetWindowPos = user32.SetWindowPos
SetWindowPos.argtypes = [wintypes.HWND, wintypes.HWND, wintypes.INT, wintypes.INT, wintypes.INT, wintypes.INT, wintypes.UINT]
SetWindowPos.restype = wintypes.BOOL

DestroyWindow = user32.DestroyWindow
DestroyWindow.argtypes = [wintypes.HWND]
DestroyWindow.restype = wintypes.BOOL

FindWindow = user32.FindWindowW
FindWindow.argtypes = [wintypes.LPCWSTR, wintypes.LPCWSTR]
FindWindow.restype = wintypes.HWND

PostMessage = user32.PostMessageW
PostMessage.argtypes = [wintypes.HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM]
PostMessage.restype = wintypes.BOOL

ShowWindow = user32.ShowWindow
ShowWindow.argtypes = [wintypes.HWND, wintypes.INT]
ShowWindow.restype = wintypes.BOOL

MoveWindow = user32.MoveWindow
MoveWindow.argtypes = [wintypes.HWND, wintypes.INT, wintypes.INT, wintypes.INT, wintypes.INT, wintypes.BOOL]
MoveWindow.restype = wintypes.BOOL

WM_CLOSE = 0x0010
SW_HIDE = 0

dll_dir = Path(__file__).parent / ".dll"
if str(dll_dir) not in os.environ["PATH"]:
    os.environ["PATH"] = str(dll_dir) + os.pathsep + os.environ["PATH"]

from PySide6.QtCore import (
    QObject,
    Signal,
    Slot,
    Property,
    QTimer,
    Qt,
)
from PySide6.QtQuick import QQuickItem
from PySide6.QtGui import QWindow
from PySide6.QtWidgets import QWidget

import mpv
try:
    from shiboken6 import isdeleted
except ImportError:
    def isdeleted(obj):
        return False

_active_videos = set()
_fs_proc_global = None


class MpvVideo(QQuickItem):

    durationChanged = Signal(float)
    positionChanged = Signal(float)
    playbackStateChanged = Signal(int)
    fileLoaded = Signal(str)
    fullscreenDelete = Signal(str)
    fullscreenPrev = Signal()
    fullscreenNext = Signal()
    fullscreenUndo = Signal()
    playlistPositionChanged = Signal(str, int)
    _fsClosedSignal = Signal(str, float, int)
    volumeChanged = Signal(float)
    mutedChanged = Signal(bool)
    eofReached = Signal()

    def __init__(self, parent=None):
        super().__init__(parent)

        self._mpv = None
        self._container = None
        self._hwnd = None
        self._above_hwnd = None
        self._fs_proc = None
        self._current_file = ""
        self._duration = 0.0
        self._position = 0.0
        self._playback_state = 0
        self._volume = _load_volume()
        self._muted = False

        self._timer = QTimer(self)
        self._timer.setTimerType(Qt.PreciseTimer)
        self._timer.timeout.connect(self._update)
        self._timer.start(6)

        self._zTimer = QTimer(self)
        self._zTimer.timeout.connect(self._updateZOrder)
        self._zTimer.start(500)

        self._fsClosedSignal.connect(self._on_fullscreen_closed)
        self.windowChanged.connect(self._on_window_changed)
        self.destroyed.connect(self._cleanup)
        self.xChanged.connect(self._update_geometry)
        self.yChanged.connect(self._update_geometry)
        self.widthChanged.connect(self._update_geometry)
        self.heightChanged.connect(self._update_geometry)

        _active_videos.add(self)

    def _cleanup(self):
        if self in _active_videos:
            _active_videos.discard(self)

        if self._fs_proc is not None:
            try:
                self._fs_proc.kill()
            except Exception:
                pass
            self._fs_proc = None
        if self._timer:
            self._timer.stop()
            self._timer = None
        if self._zTimer:
            self._zTimer.stop()
            self._zTimer = None
        if self._container:
            try:
                hwnd = int(self._container.winId())
                ShowWindow(hwnd, SW_HIDE)
                PostMessage(hwnd, WM_CLOSE, 0, 0)
                import time
                time.sleep(0.1)
                DestroyWindow(hwnd)
            except Exception as e:
                pass
            try:
                self._container.hide()
            except:
                pass
            try:
                self._container.close()
            except:
                pass
            try:
                self._container.destroy()
            except:
                pass
            self._container = None
            self._hwnd = None
        if self._mpv:
            try:
                self._mpv.command("quit", 0)
            except:
                pass
            import time
            time.sleep(0.2)
            try:
                self._mpv.unobserve_property("duration")
                self._mpv.unobserve_property("time-pos")
                self._mpv.unobserve_property("pause")
                self._mpv.unobserve_property("core-idle")
            except:
                pass
            try:
                self._mpv.terminate()
            except:
                pass
            try:
                self._mpv.close()
            except:
                pass
            self._mpv = None

    def _on_window_changed(self, window):
        if window:
            window.xChanged.connect(self._update_geometry)
            window.yChanged.connect(self._update_geometry)
        if window and not self._mpv:
            self._init_mpv()

    def _init_mpv(self):
        if self._mpv:
            return

        try:
            self._container = QWidget()
            self._container.setWindowFlags(
                Qt.FramelessWindowHint | Qt.WindowDoesNotAcceptFocus
            )
            self._container.setAttribute(Qt.WA_ShowWithoutActivating, True)
            self._container.setAttribute(Qt.WA_TransparentForMouseEvents, False)
            self._container.setStyleSheet("background-color: black;")
            self._container.setAutoFillBackground(True)
            pal = self._container.palette()
            pal.setColor(self._container.backgroundRole(), "black")
            self._container.setPalette(pal)

            win_id = int(self._container.winId())
            self._hwnd = win_id

            ex_style = GetWindowLongPtr(win_id, GWL_EXSTYLE)
            SetWindowLongPtr(win_id, GWL_EXSTYLE, ex_style | WS_EX_NOACTIVATE)

            self._mpv = mpv.MPV(
                wid=str(win_id),
                vo="gpu",
                gpu_api="d3d11",
                fbo_format="rgba16f",
                hwdec="auto-safe",
                profile="high-quality",
                icc_profile_auto=True,
                target_colorspace_hint="no",
                tone_mapping="mobius",
                scale="spline36",
                cscale="spline36",
                dscale="mitchell",
                sigmoid_upscaling=True,
                correct_downscaling=True,
                dither="fruit",
                dither_depth="auto",
                temporal_dither=True,
                deband=True,
                deband_iterations=2,
                deband_threshold=32,
                deband_range=16,
                deband_grain=4,
                cache=True,
                cache_secs=60,
                volume=_load_volume(),
                volume_max=150,
                border=False,
                input_default_bindings=True,
                input_vo_keyboard=True,
                osc=True,
            )

            self._mpv.observe_property("duration", self._on_duration)
            self._mpv.observe_property("time-pos", self._on_position)
            self._mpv.observe_property("pause", self._on_pause)
            self._mpv.observe_property("core-idle", self._on_idle)
            self._mpv.observe_property("volume", self._on_volume)
            self._mpv.observe_property("mute", self._on_mute)
            self._mpv.observe_property("eof-reached", self._on_eof)
            self._mpv.observe_property("video-params", self._on_video_params)

            self._update_geometry()

        except Exception as e:
            pass
            self._mpv = None

    def _on_duration(self, name, value):
        if value is not None and self._is_valid():
            self._duration = float(value)
            self.durationChanged.emit(self._duration)

    def _on_position(self, name, value):
        if value is not None and self._is_valid():
            self._position = float(value)
            self.positionChanged.emit(self._position)

    def _on_pause(self, name, value):
        if value is not None and self._is_valid():
            state = 2 if value else 1
            self._playback_state = state
            self.playbackStateChanged.emit(state)

    def _on_eof(self, name, value):
        if value and self._is_valid():
            self.eofReached.emit()

    def _on_video_params(self, name, value):
        if value is not None and self._is_valid():
            w = int(value.get("w", 0))
            h = int(value.get("h", 0))
            self._apply_quality_preset(w, h)

    def _apply_quality_preset(self, width: int, height: int):
        if not self._mpv:
            return
        try:
            min_dim = min(width, height)
            preset_name = "low-res (360-720p)" if min_dim <= 720 else "high-res (1080p/2K+)"
            if min_dim <= 720:
                self._mpv.scale = "ewa_lanczos"
                self._mpv.scale_antiring = 0.7
                self._mpv.cscale = "spline36"
                self._mpv.cscale_antiring = 0.7
                self._mpv.deband_iterations = 3
                self._mpv.deband_threshold = 48
                self._mpv.deband_range = 20
                self._mpv.deband_grain = 8
            else:
                self._mpv.scale = "spline36"
                self._mpv.scale_antiring = 0.0
                self._mpv.cscale = "spline36"
                self._mpv.cscale_antiring = 0.0
                self._mpv.deband_iterations = 2
                self._mpv.deband_threshold = 32
                self._mpv.deband_range = 16
                self._mpv.deband_grain = 4
        except Exception as e:
            pass

    def _on_volume(self, name, value):
        if value is not None and self._is_valid():
            self._volume = float(value)
            self.volumeChanged.emit(self._volume)
            _save_volume(self._volume)

    def _on_mute(self, name, value):
        if value is not None and self._is_valid():
            self._muted = bool(value)
            self.mutedChanged.emit(self._muted)

    def _on_idle(self, name, value):
        if value is not None and self._is_valid():
            if value:
                self._playback_state = 0
            else:
                self._playback_state = 2 if self._mpv.pause else 1
            self.playbackStateChanged.emit(self._playback_state)

    def _is_valid(self):
        try:
            return not isdeleted(self)
        except:
            return True

    def _update(self):
        if self._container:
            self._update_geometry()

    def _updateZOrder(self):
        if not self._hwnd or not self._container or not self._container.isVisible():
            return
        SetWindowPos(self._hwnd, HWND_TOP, 0, 0, 0, 0,
                   SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE)

    def _update_geometry(self):
        if not self._hwnd:
            return
        if self._above_hwnd:
            win = self.window()
            if win:
                screen = win.screen()
                if screen:
                    geom = screen.geometry()
                    MoveWindow(self._hwnd, geom.x(), geom.y(), geom.width(), geom.height(), False)
                    return
        item_pos = QQuickItem.position(self)
        pos = self.mapToGlobal(item_pos)
        x, y = int(pos.x()), int(pos.y())
        w, h = int(self.width()), int(self.height())
        if w > 0 and h > 0:
            MoveWindow(self._hwnd, x, y, w, h, False)

    def itemChange(self, change, value):
        if change == QQuickItem.ItemVisibleHasChanged:
            if self._container:
                if self.isVisible():
                    self._container.show()
                else:
                    self._container.hide()
        return super().itemChange(change, value)

    def geometryChanged(self, new_geom, old_geom):
        super().geometryChanged(new_geom, old_geom)
        self._update_geometry()

    @Slot(str)
    def loadFile(self, path):
        self._init_mpv()
        if not self._mpv:
            return
        self._current_file = path
        if path.startswith("file://"):
            path = path[7:]
        path = path.replace("/", "\\")
        try:
            self._mpv.play(path)
            self._container.show()
            SetWindowPos(self._hwnd, HWND_TOP, 0, 0, 0, 0,
                       SWP_NOMOVE | SWP_NOSIZE | SWP_SHOWWINDOW | SWP_NOACTIVATE)
            self.fileLoaded.emit(self._current_file)
        except Exception as e:
            pass

    @Slot()
    def play(self):
        if self._mpv:
            self._mpv.pause = False

    @Slot()
    def pause(self):
        if self._mpv:
            self._mpv.pause = True

    @Slot()
    def togglePause(self):
        if self._mpv:
            self._mpv.cycle("pause")

    @Slot()
    def toggleMute(self):
        if self._mpv:
            self._mpv.cycle("mute")

    @Slot()
    def stop(self):
        if self._mpv:
            self._mpv.command("stop")
            self._playback_state = 0
            self.playbackStateChanged.emit(0)
        if self._container:
            self._container.hide()
            hwnd = int(self._container.winId())
            SetWindowPos(hwnd, HWND_NOTOPMOST, 0, 0, 0, 0,
                       SWP_NOMOVE | SWP_NOSIZE | SWP_HIDEWINDOW | SWP_NOACTIVATE)

    @Slot(bool)
    def setTopmost(self, topmost):
        if topmost:
            self._above_hwnd = None
        if self._hwnd:
            if topmost:
                SetWindowPos(self._hwnd, HWND_NOTOPMOST, 0, 0, 0, 0,
                           SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE)
        if topmost:
            self._zTimer.start(500)
        else:
            self._zTimer.stop()

    @Slot(int)
    def placeBelow(self, aboveWinId):
        if not self._hwnd or not aboveWinId:
            return
        self._above_hwnd = wintypes.HWND(aboveWinId)
        SetWindowPos(self._above_hwnd, HWND_TOPMOST, 0, 0, 0, 0,
                   SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE)
        SetWindowPos(self._hwnd, self._above_hwnd, 0, 0, 0, 0,
                   SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE)

    @Slot(result=float)
    def getPosition(self):
        return self._position

    FS_EXIT_NORMAL   = 0
    FS_EXIT_PREV     = 10
    FS_EXIT_NEXT     = 11
    FS_EXIT_DELETE   = 20
    FS_EXIT_UNDO     = 30
    FS_EXIT_EOF      = 40

    def _get_video_resolution(self, path: str) -> tuple[int, int]:
        import shutil
        if shutil.which("ffprobe"):
            try:
                import subprocess
                result = subprocess.run(
                    ["ffprobe", "-v", "error", "-select_streams", "v:0",
                     "-show_entries", "stream=width,height", "-of", "csv=p=0", path],
                    capture_output=True, text=True, timeout=5
                )
                if result.returncode == 0 and result.stdout.strip():
                    parts = result.stdout.strip().split(',')
                    if len(parts) == 2:
                        return (int(parts[0]), int(parts[1]))
            except Exception:
                pass
        if self._mpv and self._current_file == path:
            try:
                params = self._mpv.get_property_native("video-params")
                if params:
                    w = int(params.get("w", 0))
                    h = int(params.get("h", 0))
                    if w > 0 and h > 0:
                        return (w, h)
            except Exception:
                pass
        return (1920, 1080)

    @Slot(str, float, "QVariantList", int)
    def launchFullscreen(self, path, start_pos=0.0, sibling_files=None, current_index=0):
        import subprocess
        import threading
        mpv_exe = str(dll_dir / "mpv.exe")
        if not Path(mpv_exe).exists():
            pass
            return
        if path.startswith("file:///"):
            path = path[8:]
        elif path.startswith("file://"):
            path = path[7:]
        path = path.replace("/", "\\")
        
        playlist = []
        playlist_index = current_index
        if sibling_files and len(sibling_files) > 0:
            dir_sep = "\\"
            last_sep = path.rfind(dir_sep)
            if last_sep == -1:
                dir_sep = "/"
                last_sep = path.rfind(dir_sep)
            parent_dir = path[:last_sep+1] if last_sep > 0 else ""
            
            for name in sibling_files:
                full_path = parent_dir + name.replace("/", "\\")
                playlist.append(full_path)
            try:
                playlist_index = playlist.index(path)
            except ValueError:
                playlist_index = current_index
        else:
            playlist = [path]
            playlist_index = 0

        mpv_cache_dir = Path(__file__).with_name("cache") / "mpv"
        mpv_cache_dir.mkdir(parents=True, exist_ok=True)

        watch_later_dir = str(mpv_cache_dir / "watch_later")
        Path(watch_later_dir).mkdir(exist_ok=True)
        
        import uuid
        ipc_pipe_name = r"\\.\pipe\mpv_fs_" + uuid.uuid4().hex[:8]
        
        playlist_file = mpv_cache_dir / "playlist.m3u"
        playlist_content = "#EXTM3U\n"
        for p in playlist:
            playlist_content += p + "\n"
        playlist_file.write_text(playlist_content, encoding="utf-8")

        lua_script = mpv_cache_dir / "playlist.lua"
        lua_script.write_text(
            "-- Helper: write to stdout so Python can read it\n"
            "local function out(s)\n"
            "  io.write(s .. '\\n')\n"
            "  io.flush()\n"
            "end\n"
            "-- Output playlist position changes\n"
            "mp.observe_property('playlist-pos', 'number', function(_, pos)\n"
            "  if pos then out('MPVPOS:' .. pos) end\n"
            "end)\n"
            "mp.observe_property('path', 'string', function(_, p)\n"
            "  if p then out('MPVPATH:' .. p) end\n"
            "end)\n"
            "-- App actions: signal Python instead of quitting\n"
            "mp.register_script_message('app-delete', function()\n"
            "  local p = mp.get_property('path', '')\n"
            "  if p ~= '' then out('ACTION:delete:' .. p) end\n"
            "end)\n"
            "mp.register_script_message('app-undo', function()\n"
            "  out('ACTION:undo')\n"
            "end)\n"
            "mp.register_event('end-file', function(e)\n"
            "  if e.reason == 'eof' then\n"
            "    local count = mp.get_property_native('playlist-count', 0)\n"
            "    local pos = mp.get_property_native('playlist-pos', -1)\n"
            "    if pos >= count - 1 then\n"
            "      mp.command('quit 40')\n"
            "    end\n"
            "  end\n"
            "end)\n",
            encoding="utf-8"
        )

        input_conf = mpv_cache_dir / "input.conf"
        input_conf.write_text(
            "# Playback\n"
            "SPACE cycle pause\n"
            "p     cycle pause\n"
            "m     cycle mute\n"
            "f     cycle fullscreen\n"
            "q     quit\n"
            "ESC   quit\n"
            "# Seeking\n"
            "UP          seek 5\n"
            "DOWN        seek -5\n"
            "Shift+UP    seek 1 exact\n"
            "Shift+DOWN  seek -1 exact\n"
            "Ctrl+UP     seek 60\n"
            "Ctrl+DOWN   seek -60\n"
            "# Navigation (mpv handles playlist internally)\n"
            "RIGHT      playlist-next\n"
            "LEFT       playlist-prev\n"
            "NEXT       playlist-next\n"
            "PREV       playlist-prev\n"
            "MBTN_LEFT  cycle pause\n"
            "# App actions (signal host app via script-message, no quit)\n"
            "DEL        script-message app-delete\n"
            "Ctrl+z     script-message app-undo\n",
            encoding="utf-8"
        )

        width, height = self._get_video_resolution(path)
        min_dim = min(width, height)
        is_low_res = min_dim <= 720
        preset_name = "low-res (360-720p)" if is_low_res else "high-res (1080p/2K+)"

        args = [
            mpv_exe,
            f"--playlist={playlist_file}",
            f"--playlist-start={playlist_index}",
            "--fullscreen",
            "--force-window=yes",
            "--save-position-on-quit=yes",
            "--no-input-default-bindings",
            f"--watch-later-dir={watch_later_dir}",
            f"--input-conf={input_conf}",
            f"--script={lua_script}",
            f"--input-ipc-server={ipc_pipe_name}",
            f"--volume={int(_load_volume())}",
            "--no-terminal",
            "--vo=gpu",
            "--gpu-api=d3d11",
            "--fbo-format=rgba16f",
            "--hwdec=auto-safe",
            "--profile=high-quality",
            "--icc-profile-auto=yes",
            "--target-colorspace-hint=no",
            "--tone-mapping=mobius",
            "--dscale=mitchell",
            "--sigmoid-upscaling=yes",
            "--correct-downscaling=yes",
            "--dither=fruit",
            "--dither-depth=auto",
            "--temporal-dither=yes",
            "--video-sync=display-resample",
        ]

        if is_low_res:
            args.extend([
                "--scale=ewa_lanczos",
                "--scale-antiring=0.7",
                "--cscale=spline36",
                "--cscale-antiring=0.7",
                "--deband=yes",
                "--deband-iterations=3",
                "--deband-threshold=48",
                "--deband-range=20",
                "--deband-grain=8",
            ])
        else:
            args.extend([
                "--scale=spline36",
                "--cscale=spline36",
                "--deband=yes",
                "--deband-iterations=2",
                "--deband-threshold=32",
                "--deband-range=16",
                "--deband-grain=4",
            ])

        if start_pos > 0:
            args.append(f"--start={start_pos:.3f}")

        def _send_ipc(command_json: str):
            try:
                with open(ipc_pipe_name, "w", encoding="utf-8") as f:
                    f.write(command_json + "\n")
                    f.flush()
            except Exception as e:
                pass

        live_playlist = list(playlist)

        self._fs_ipc_send = _send_ipc
        self._fs_live_playlist = live_playlist
        self._fs_orig_playlist = list(playlist)

        def _run():
            global _fs_proc_global
            current_playlist_path = path
            current_playlist_index = playlist_index
            
            proc = subprocess.Popen(
                args,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT
            )
            self._fs_proc = proc
            _fs_proc_global = proc
            
            for raw_line in proc.stdout:
                try:
                    line = raw_line.decode('utf-8', errors='ignore').strip()
                except Exception:
                    continue
                if line.startswith("MPVPOS:"):
                    try:
                        new_index = int(line.split(":", 1)[1])
                        current_playlist_index = new_index
                        if 0 <= new_index < len(playlist):
                            current_playlist_path = playlist[new_index]
                            self.playlistPositionChanged.emit(current_playlist_path, new_index)
                    except (ValueError, IndexError):
                        pass
                elif line.startswith("MPVPATH:"):
                    new_path = line.split(":", 1)[1].strip()
                    if new_path:
                        current_playlist_path = new_path
                elif line.startswith("ACTION:delete:"):
                    del_path = line.split(":", 2)[2].strip()
                    self.fullscreenDelete.emit(del_path)
                    try:
                        live_playlist.remove(del_path)
                    except ValueError:
                        pass
                    if len(live_playlist) > 0:
                        _send_ipc('{"command":["playlist-remove","current"]}')
                    else:
                        _send_ipc('{"command":["quit"]}')
                elif line.startswith("ACTION:undo"):
                    self.fullscreenUndo.emit()
            
            proc.wait()
            exit_code = proc.returncode
            self._fs_proc = None
            _fs_proc_global = None
            
            exit_pos = self._read_watch_later_pos(current_playlist_path, watch_later_dir)
            exit_vol = self._read_watch_later_volume(current_playlist_path, watch_later_dir)
            if exit_vol is not None:
                _save_volume(exit_vol)
                if self._mpv and self._is_valid():
                    self._mpv.volume = exit_vol
            
            self._fsClosedSignal.emit(current_playlist_path, exit_pos, exit_code)

        threading.Thread(target=_run, daemon=True).start()

    @Slot(str)
    def fullscreenLoadFile(self, path: str):
        if not getattr(self, "_fs_ipc_send", None) or not self._fs_proc:
            return
        if path.startswith("file:///"):
            path = path[8:]
        elif path.startswith("file://"):
            path = path[7:]
        path = path.replace("/", "\\")
        import json as _json
        live = getattr(self, "_fs_live_playlist", None)

        orig_index = 0
        orig_playlist = getattr(self, "_fs_orig_playlist", None)
        if orig_playlist and path in orig_playlist:
            orig_index = orig_playlist.index(path)

        if live is not None:
            if path in live:
                live.remove(path)
            inserted = False
            if orig_playlist:
                for i, p in enumerate(orig_playlist):
                    if p == path:
                        insert_pos = 0
                        for j, lp in enumerate(live):
                            if orig_playlist.index(lp) < orig_index:
                                insert_pos = j + 1
                        live.insert(insert_pos, path)
                        inserted = True
                        break
            if not inserted:
                live.append(path)

        restore_idx = live.index(path) if live and path in live else 0
        new_playlist_file = Path(__file__).with_name("cache") / "mpv" / "playlist_undo.m3u"
        content = "#EXTM3U\n" + "\n".join(live or [path]) + "\n"
        new_playlist_file.write_text(content, encoding="utf-8")

        self._fs_ipc_send(_json.dumps({"command": ["loadlist", str(new_playlist_file), "replace"]}))

        import threading as _threading
        def _jump(idx=restore_idx, send=self._fs_ipc_send):
            import time
            time.sleep(0.3)
            send(_json.dumps({"command": ["playlist-play-index", idx]}))
        _threading.Thread(target=_jump, daemon=True).start()

        orig = getattr(self, "_fs_orig_playlist", None)
        if orig is not None and path not in orig:
            orig.append(path)


    @Slot()
    def quitFullscreen(self):
        if getattr(self, "_fs_ipc_send", None) and self._fs_proc:
            import json as _json
            self._fs_ipc_send(_json.dumps({"command": ["quit"]}))

    @Slot(result=bool)
    def fullscreenIsActive(self) -> bool:
        active = self._fs_proc is not None and self._fs_proc.poll() is None
        return active

    def _on_fullscreen_closed(self, path, exit_pos, exit_code):
        if exit_code == MpvVideo.FS_EXIT_DELETE:
            self.fullscreenDelete.emit(path)
        elif exit_code == MpvVideo.FS_EXIT_UNDO:
            self.fullscreenUndo.emit()
        else:
            self._resume_after_fullscreen(path, exit_pos)

    def _read_watch_later_file(self, file_path, watch_later_dir):
        import hashlib
        h = hashlib.md5(file_path.encode("utf-8")).hexdigest().upper()
        wl_file = Path(watch_later_dir) / h
        if wl_file.exists():
            try:
                return wl_file.read_text(encoding="utf-8").splitlines()
            except Exception:
                pass
        for f in Path(watch_later_dir).iterdir():
            try:
                return f.read_text(encoding="utf-8").splitlines()
            except Exception:
                pass
        return []

    def _read_watch_later_pos(self, file_path, watch_later_dir):
        for line in self._read_watch_later_file(file_path, watch_later_dir):
            if line.startswith("start="):
                try: return float(line.split("=", 1)[1])
                except Exception: pass
        return 0.0

    def _read_watch_later_volume(self, file_path, watch_later_dir):
        for line in self._read_watch_later_file(file_path, watch_later_dir):
            if line.startswith("volume="):
                try: return float(line.split("=", 1)[1])
                except Exception: pass
        return None

    def _resume_after_fullscreen(self, path, position):
        if not self._mpv or not self._is_valid():
            return
        try:
            if self._container and not self._container.isVisible():
                self._container.show()
                if self._hwnd:
                    SetWindowPos(self._hwnd, HWND_TOP, 0, 0, 0, 0,
                               SWP_NOMOVE | SWP_NOSIZE | SWP_SHOWWINDOW | SWP_NOACTIVATE)
            if position > 0:
                self._mpv.command("seek", position, "absolute")
            self._mpv.pause = True
        except Exception as e:
            pass

    @Slot(float)
    def seek(self, position):
        if self._mpv:
            self._mpv.command("seek", position, "absolute")

    @Slot(float)
    def setVolume(self, volume):
        if self._mpv:
            self._mpv.volume = max(0.0, min(150.0, volume))

    @Slot(bool)
    def setMuted(self, muted):
        if self._mpv:
            self._mpv.mute = muted

    def get_duration(self):
        return self._duration

    def get_position(self):
        return self._position

    def get_playback_state(self):
        return self._playback_state

    def get_volume(self):
        return self._volume

    def get_muted(self):
        return self._muted

    duration = Property(float, get_duration, notify=durationChanged)
    position = Property(float, get_position, notify=positionChanged)
    playbackState = Property(int, get_playback_state, notify=playbackStateChanged)
    volume = Property(float, get_volume, notify=volumeChanged)
    muted = Property(bool, get_muted, notify=mutedChanged)


def cleanup_all_videos():
    global _fs_proc_global
    if _fs_proc_global is not None:
        try:
            _fs_proc_global.kill()
        except Exception:
            pass
        _fs_proc_global = None

    for video in list(_active_videos):
        try:
            video._cleanup()
        except:
            pass
    _active_videos.clear()
    
    try:
        hwnd = FindWindow(None, None)
        while hwnd:
            class_name = ctypes.create_unicode_buffer(256)
            user32.GetClassNameW(hwnd, class_name, 256)
            if "QWidget" in class_name.value or "mpv" in class_name.value.lower():
                ShowWindow(hwnd, SW_HIDE)
                PostMessage(hwnd, WM_CLOSE, 0, 0)
                DestroyWindow(hwnd)
            hwnd = user32.GetWindow(hwnd, 2)
    except:
        pass


def create_mpv_video(qmlEngine, jsEngine):
    return MpvVideo()


import atexit
atexit.register(cleanup_all_videos)
