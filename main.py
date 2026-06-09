from __future__ import annotations

import ctypes
import os
import sys
from pathlib import Path

import mpv_setup

from PySide6.QtCore import QUrl
from PySide6.QtGui import QIcon
from PySide6.QtWidgets import QApplication
from PySide6.QtQml import QQmlApplicationEngine, qmlRegisterType
from PySide6.QtQuick import QQuickWindow, QSGRendererInterface
from PySide6.QtQuickControls2 import QQuickStyle

from backend import Backend
from mpv_video import MpvVideo, cleanup_all_videos
from thumbnail_cache import ThumbnailCache, VideoThumbnailCache


def main() -> int:
    ctypes.windll.winmm.timeBeginPeriod(1)

    os.environ.setdefault("QT_LOGGING_RULES", "*.debug=false;qt.rhi.*=false;qt.scenegraph.*=false")

    os.environ.setdefault("QSG_RENDER_LOOP", "threaded")
    QQuickWindow.setGraphicsApi(QSGRendererInterface.GraphicsApi.Direct3D11)

    app = QApplication(sys.argv)
    app.setOrganizationName("RootlineAtlas")
    app.setApplicationName("Rootline Atlas")
    QQuickStyle.setStyle("Fusion")

    if getattr(sys, 'frozen', False):
        icon_path = Path(sys._MEIPASS) / "app_icon.ico"
    else:
        icon_path = Path(__file__).parent / "app_icon.ico"
    if icon_path.exists():
        app.setWindowIcon(QIcon(str(icon_path)))

    engine = QQmlApplicationEngine()

    qmlRegisterType(MpvVideo, "MpvVideo", 1, 0, "MpvVideo")

    backend = Backend()
    engine.rootContext().setContextProperty("backend", backend)

    thumbnail_cache = ThumbnailCache()
    engine.rootContext().setContextProperty("thumbnailCache", thumbnail_cache)

    video_thumbnail_cache = VideoThumbnailCache()
    engine.rootContext().setContextProperty("videoThumbnailCache", video_thumbnail_cache)

    qml_path = Path(__file__).parent / "qml" / "Main.qml"
    engine.load(QUrl.fromLocalFile(str(qml_path)))
    if not engine.rootObjects():
        return 11
    
    def on_about_to_quit():
        cleanup_all_videos()
        backend.cleanupDeleteThread()
    
    app.aboutToQuit.connect(on_about_to_quit)
    
    def on_closing():
        cleanup_all_videos()
        backend.cleanupDeleteThread()
        os._exit(0)

    root = engine.rootObjects()[0]
    if hasattr(root, 'closing'):
        root.closing.connect(on_closing)
    
    result = app.exec()
    backend.cleanupDeleteThread()
    os._exit(result)


if __name__ == "__main__":
    sys.exit(main())
