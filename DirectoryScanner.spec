# -*- mode: python ; coding: utf-8 -*-
from PyInstaller.building.build_main import Analysis, PYZ, EXE, COLLECT
from pathlib import Path

project_dir = Path(SPECPATH)

a = Analysis(
    [str(project_dir / "main.py")],
    pathex=[str(project_dir)],
    binaries=[
        (str(project_dir / ".dll" / "libmpv-2.dll"), "."),
        (str(project_dir / ".dll" / "MpvVideo.dll"), "."),
        (str(project_dir / ".dll" / "mpv.exe"), "."),
    ],
    datas=[
        (str(project_dir / "qml"),    "qml"),
        (str(project_dir / ".dll" / "include"), ".dll/include"),
        (str(project_dir / ".dll" / "qmldir"),  ".dll"),
        (str(project_dir / "app_icon.ico"),  "."),
        (str(project_dir / "LockHunter"),  "LockHunter"),
    ],
    hiddenimports=[
        "PySide6.QtQuick",
        "PySide6.QtQml",
        "PySide6.QtWidgets",
        "PySide6.QtMultimedia",
        "PySide6.QtQuickControls2",
        "shiboken6",
        "humanize",
        "send2trash",
    ],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[
        "tkinter", "_tkinter", "turtle", "turtledemo",
        "unittest", "test", "pydoc", "doctest",
        "xmlrpc", "email", "html", "http", "urllib",
        "xml", "ftplib", "imaplib", "poplib", "smtplib",
        "sqlite3", "curses", "idlelib",
        "asyncio", "multiprocessing", "lib2to3",
        "distutils", "setuptools", "pkg_resources", "pip",
        "PySide6.QtWebEngine", "PySide6.QtWebEngineCore",
        "PySide6.QtWebEngineWidgets", "PySide6.QtWebChannel",
        "PySide6.Qt3DCore", "PySide6.Qt3DRender", "PySide6.Qt3DInput",
        "PySide6.QtBluetooth", "PySide6.QtNfc", "PySide6.QtSensors",
        "PySide6.QtSerialPort", "PySide6.QtPositioning",
        "PySide6.QtRemoteObjects", "PySide6.QtSql",
        "PySide6.QtCharts", "PySide6.QtDataVisualization",
        "PySide6.QtTest",
    ],
    noarchive=True,  # .pyc on filesystem — OS file cache serves imports faster
)

# Strip software OpenGL fallback — app uses D3D11 exclusively.
a.binaries = [b for b in a.binaries if not b[0].lower().endswith("opengl32sw.dll")]
# Strip unused Qt plugin DLLs.
_strip_prefixes = ("qtwebengine", "qt6webengine", "qt6pdf", "qt6designer")
a.binaries = [b for b in a.binaries
              if not any(b[0].lower().replace("\\", "/").split("/")[-1].startswith(p)
                         for p in _strip_prefixes)]

pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    [],
    name="Rootline Atlas",
    icon=str(project_dir / "app_icon.ico"),
    debug=False,
    optimize=2,          # strip docstrings + asserts for speed
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=False,       # no console window
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)

coll = COLLECT(
    exe,
    a.binaries,
    a.datas,
    strip=False,
    upx=False,
    upx_exclude=[],
    name="Rootline Atlas",
)
