
import os
import shutil
import subprocess
import sys
from pathlib import Path

if sys.stdout.encoding and sys.stdout.encoding.lower() != "utf-8":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")


def main():
    project_dir = Path(__file__).parent.resolve()
    main_py     = project_dir / "main.py"
    qml_dir     = project_dir / "qml"
    dll_dir     = project_dir / ".dll"
    icon_file   = project_dir / "app_icon.ico"
    lockhunter  = project_dir / "LockHunter"

    missing = []
    if not main_py.exists():
        missing.append(f"main.py: {main_py}")
    if not qml_dir.exists():
        missing.append(f"qml directory: {qml_dir}")
    if not dll_dir.exists():
        missing.append(f".dll directory: {dll_dir}")
    if not icon_file.exists():
        missing.append(f"app_icon.ico: {icon_file}")
    if not lockhunter.exists():
        missing.append(f"LockHunter directory: {lockhunter}")
    if missing:
        for m in missing:
            print(f"  ✗ {m}")
        sys.exit(1)

    print("═" * 60)
    print("  Building Rootline Atlas with Nuitka")
    print("═" * 60)
    print(f"  Main file   : {main_py}")
    print(f"  QML dir     : {qml_dir}")
    print(f"  DLL dir     : {dll_dir}")
    print(f"  Icon        : {icon_file}")
    print(f"  LockHunter  : {lockhunter}")
    print()

    cmd = [
        sys.executable, "-m", "nuitka",
        str(main_py),

        "--standalone",
        "--output-dir=dist_nuitka",
        "--output-filename=Rootline Atlas.exe",

        f"--windows-icon-from-ico={icon_file}",
        "--windows-console-mode=disable",

        "--enable-plugin=pyside6",
        "--include-qt-plugins=qml",

        f"--include-data-dir={qml_dir}=qml",
        f"--include-data-dir={dll_dir / 'include'}=.dll/include",
        f"--include-data-dir={lockhunter}=LockHunter",

        f"--include-data-files={dll_dir / 'qmldir'}=.dll/qmldir",
        f"--include-data-files={icon_file}=app_icon.ico",

        f"--include-data-files={dll_dir / 'libmpv-2.dll'}=libmpv-2.dll",
        f"--include-data-files={dll_dir / 'MpvVideo.dll'}=MpvVideo.dll",
        f"--include-data-files={dll_dir / 'mpv.exe'}=mpv.exe",

        "--include-module=PySide6.QtQuick",
        "--include-module=PySide6.QtQml",
        "--include-module=PySide6.QtWidgets",
        "--include-module=PySide6.QtMultimedia",
        "--include-module=PySide6.QtQuickControls2",
        "--include-module=PySide6.QtGui",
        "--include-module=PySide6.QtCore",
        "--include-module=shiboken6",
        "--include-module=humanize",
        "--include-module=send2trash",
        "--include-module=mpv",
        "--include-module=comtypes",
        "--include-module=win32ui",
        "--include-module=cv2",
        "--include-module=numpy",
        "--include-module=mpv_setup",
        "--include-module=backend",
        "--include-module=mpv_video",
        "--include-module=thumbnail_cache",

        "--follow-imports",
        "--nofollow-import-to=*.tests",
        "--nofollow-import-to=*.test",
        "--nofollow-import-to=test",

        "--nofollow-import-to=tkinter",
        "--nofollow-import-to=_tkinter",
        "--nofollow-import-to=turtle",
        "--nofollow-import-to=turtledemo",
        "--nofollow-import-to=unittest",
        "--nofollow-import-to=pydoc",
        "--nofollow-import-to=doctest",
        "--nofollow-import-to=xmlrpc",
        "--nofollow-import-to=email",
        "--nofollow-import-to=html",
        "--nofollow-import-to=http",
        "--nofollow-import-to=urllib",
        "--nofollow-import-to=xml",
        "--nofollow-import-to=ftplib",
        "--nofollow-import-to=imaplib",
        "--nofollow-import-to=poplib",
        "--nofollow-import-to=smtplib",
        "--nofollow-import-to=sqlite3",
        "--nofollow-import-to=curses",
        "--nofollow-import-to=idlelib",
        "--nofollow-import-to=lib2to3",
        "--nofollow-import-to=distutils",
        "--nofollow-import-to=setuptools",
        "--nofollow-import-to=pkg_resources",
        "--nofollow-import-to=pip",
        "--nofollow-import-to=PySide6.QtWebEngine",
        "--nofollow-import-to=PySide6.QtWebEngineCore",
        "--nofollow-import-to=PySide6.QtWebEngineWidgets",
        "--nofollow-import-to=PySide6.QtWebChannel",
        "--nofollow-import-to=PySide6.Qt3DCore",
        "--nofollow-import-to=PySide6.Qt3DRender",
        "--nofollow-import-to=PySide6.Qt3DInput",
        "--nofollow-import-to=PySide6.QtBluetooth",
        "--nofollow-import-to=PySide6.QtNfc",
        "--nofollow-import-to=PySide6.QtSensors",
        "--nofollow-import-to=PySide6.QtSerialPort",
        "--nofollow-import-to=PySide6.QtPositioning",
        "--nofollow-import-to=PySide6.QtRemoteObjects",
        "--nofollow-import-to=PySide6.QtSql",
        "--nofollow-import-to=PySide6.QtCharts",
        "--nofollow-import-to=PySide6.QtDataVisualization",
        "--nofollow-import-to=PySide6.QtTest",

        "--noinclude-dlls=opengl32sw.dll",
        "--noinclude-dlls=qtwebengine*.dll",
        "--noinclude-dlls=qt6webengine*.dll",
        "--noinclude-dlls=qt6pdf*.dll",
        "--noinclude-dlls=qt6designer*.dll",

        "--python-flag=no_docstrings",
        "--python-flag=no_asserts",

        "--lto=no",
        "--jobs=12",

        "--show-progress",
        "--show-memory",
    ]

    print("Running Nuitka command:")
    print()
    for arg in cmd:
        print(f"  {arg}")
    print()
    print("This may take 5-15 minutes...")
    print()

    build_env = os.environ.copy()
    build_env["PYTHONUTF8"] = "1"
    build_env["PYTHONIOENCODING"] = "utf-8"

    try:
        result = subprocess.run(
            cmd,
            cwd=str(project_dir),
            capture_output=False,
            text=True,
            check=True,
            env=build_env,
        )

        staging   = project_dir / "dist_nuitka" / "main.dist"
        final_dir = project_dir / "dist" / "Rootline Atlas"

        if final_dir.exists():
            shutil.rmtree(final_dir)
        final_dir.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(staging), str(final_dir))

        print()
        print("═" * 60)
        print("  ✅ Build complete!")
        print(f"  Output folder: {final_dir}")
        print(f"  Executable   : {final_dir / 'Rootline Atlas.exe'}")
        print("═" * 60)
    except subprocess.CalledProcessError as e:
        print(f"\n❌ Build failed with exit code {e.returncode}")
        sys.exit(1)
    except FileNotFoundError:
        print("\n❌ Error: Nuitka not found. Install with: pip install nuitka ordered-set")
        sys.exit(1)


if __name__ == "__main__":
    main()
