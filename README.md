# Rootline Atlas

A desktop file manager and directory analyzer with browser-style navigation, multi-tab browsing, video playback via mpv, bulk rename, analytics charts, and full file operations (copy, cut, paste, delete). Built with Python, PySide6, and QML.

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Language | Python 3.14 |
| UI Framework | PySide6 (Qt 6) + QML |
| Rendering | Direct3D 11 (hardware-accelerated) |
| Video | mpv (libmpv-2.dll) via python-mpv bindings |
| Shell Operations | Windows Shell API (COM) via shell_bridge |
| Thumbnails | Windows Shell + OpenCV fallback |
| Packaging | PyInstaller / Nuitka |

## Features

### Navigation
- **Browser-style controls** — back, forward, up, reload
- **Address bar** — type or paste any path, press Enter to navigate
- **Breadcrumb trail** — click any segment to jump there
- **Native folder picker** — browse with the system dialog
- **Drive selector** — dropdown of all available drives, auto-refreshes
- **Multi-tab browsing** — open multiple directories in tabs, drag to reorder, pin, color-code, set home locations

### Views
- **List** — flat table with sortable columns (name, size, type, date)
- **Tree** — hierarchical expandable tree with folder sizes
- **Grid** — thumbnail grid with file icons and previews
- **Analytics** — charts and statistics (extension distribution, size buckets, largest files/folders)

### Filters & Search
- Filter by **type** (all / files only / folders only)
- Filter by **size range** (e.g. `500MB` to `2GB`)
- Include / exclude by **file extensions**
- Include / exclude by **keywords** in filename
- Filter by **date range**
- **Sort** by size, date, or name (ascending/descending)
- **Subfolder recursion** toggle — scan all nested directories
- **Real-time search** — filter results as you type

### File Operations
- **Copy / Cut / Paste** — with progress bars, speed display, and conflict resolution
- **Delete** — to recycle bin or permanent delete
- **Rename** — inline rename (F2 or double-click) with conflict handling
- **Bulk Rename** — find & replace, prefix/suffix, sequential numbering, decimal numbering, append numbering
- **New Folder** — create folders via context menu
- **Undo** — undo delete operations
- **Bookmarks** — toggle bookmarks on any folder, navigate from bookmarks panel

### Video Playback
- **Embedded mpv player** — play videos directly in the preview pane
- **Fullscreen mode** — launches mpv in a separate fullscreen window with playlist support
- **Playlist navigation** — previous/next file, delete from playlist, undo delete
- **Volume control** — per-app volume with mute toggle, persisted between sessions
- **Quality presets** — automatically adjusts scaling and debanding based on video resolution (low-res vs high-res)
- **Resume playback** — remembers position when returning from fullscreen
- **Keyboard shortcuts** — Space (play/pause), Left/Right (seek), F11 (fullscreen), Delete (delete current)

### Preview Pane
- **Image preview** — view images with dimensions
- **Video preview** — embedded mpv player
- **Text preview** — read text files (first 50KB)
- **File properties** — size, dates, hashes (MD5, SHA-256), EXE version info, image dimensions
- **Keyboard navigation** — arrow keys to move between files

### Analytics
- **Extension distribution** — bar chart of file types by count and size
- **Size buckets** — pie chart of files grouped by size ranges
- **Largest files** — top 20 largest files
- **Largest folders** — top 20 largest folders

### Other
- **File system watcher** — auto-refreshes when files change externally
- **Export results** — save current view to a text file
- **View exported files** — open previously exported reports
- **Archive extraction** — extract archives (7z, WinRAR, WinZip) with progress
- **Scan caching** — caches scan results for instant reload of previously visited directories
- **Pause/Resume scan** — pause long-running scans

## Requirements

```
PySide6>=6.6
humanize>=4.0
python-mpv>=1.0.0
pywin32>=306
```

Install with:

```powershell
pip install -r requirements.txt
```

## External Dependencies

### mpv (`.dll` folder)

Video playback requires **mpv**, a free open-source media player (GPLv2 licensed). The application looks for mpv binaries in a `.dll` folder next to the executable:

```
.dll/
├── libmpv-2.dll    (required — the mpv library, ~120 MB)
├── mpv.exe         (required — standalone player for fullscreen mode, ~117 MB)
├── MpvVideo.dll    (required — QML video integration plugin)
├── libmpv.dll.a    (import library)
├── libMpvVideo.a   (import library)
├── qmldir          (QML module definition)
└── include/        (C headers)
```

**How to obtain mpv:**

1. Download the latest Windows build from [mpv.io/installation](https://mpv.io/installation/) or [sourceforge.net/projects/mpv-player-windows](https://sourceforge.net/projects/mpv-player-windows/files/)
2. Extract `libmpv-2.dll` and `mpv.exe` into the `.dll` folder
3. `MpvVideo.dll` is a custom QML plugin — build it from the QML video integration source, or obtain it from a release package

The `.dll` folder is **not included** in this repository (gitignored). You must provide these binaries yourself.

### LockHunter

LockHunter is a free tool for unlocking and deleting files that are locked by other processes. It integrates with the right-click context menu.

**How to install:**

1. Download from [lockhunter.com](https://lockhunter.com/)
2. Place the `LockHunter` folder next to the application executable
3. The folder should contain `LockHunter.exe` and its dependencies

The `LockHunter` folder is **not included** in this repository (gitignored).

## Run

```powershell
pip install -r requirements.txt
python main.py
```

## Build

### PyInstaller

```powershell
python build_app.py
```

Uses `DirectoryScanner.spec` — outputs to `dist/Rootline Atlas/`.

### Nuitka

```powershell
python build_app_nuitka.py
```

Outputs a standalone folder to `dist/Rootline Atlas/`. Nuitka builds produce smaller, faster executables but take longer to compile (5–15 minutes).

## Project Structure

```
├── main.py              Entry point — initializes Qt, QML engine, Backend, caches
├── backend.py           Core logic — Backend QObject, ResultsModel, ScanWorker,
│                        PasteWorker, DeleteWorker, ExpandWorker, filters, analytics
├── mpv_video.py         MpvVideo QQuickItem — embedded and fullscreen video playback
├── mpv_setup.py         Bootstrap — adds .dll folder to PATH before importing mpv
├── thumbnail_cache.py   ThumbnailCache + VideoThumbnailCache — async thumbnail generation
├── shell_bridge.py      Windows Shell API bindings — COM file operations via IShellItem
├── build_app.py         PyInstaller build script
├── build_app_nuitka.py  Nuitka build script
├── make_icon.py         Generates app_icon.ico programmatically
├── convert_icon.py      Converts PNG to multi-resolution ICO
├── requirements.txt     Python dependencies
├── app_icon.ico         Application icon
├── qml/
│   ├── Main.qml              Main window — chrome, tab bar, body, status bar
│   ├── ResultsView.qml       List, tree, and grid views with context menus
│   ├── FiltersPanel.qml      Collapsible filter sidebar
│   ├── AnalyticsView.qml     Charts and statistics view
│   ├── BulkRenameDialog.qml  Bulk rename dialog with live preview
│   ├── Theme.qml             Dark theme colors and typography
│   ├── GlyphIcon.qml         Icon component
│   ├── IconButton.qml        Toolbar button component
│   ├── ModernCheck.qml       Styled checkbox
│   ├── ModernCombo.qml       Styled combobox
│   ├── ModernField.qml       Styled text field
│   ├── SectionLabel.qml      Section header label
│   ├── SegmentedControl.qml  Segmented button control
│   └── qmldir                QML module definition
├── .dll/                mpv binaries (gitignored — must be provided)
└── LockHunter/          LockHunter tool (gitignored — must be provided)
```

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `Backspace` | Go to parent directory |
| `F5` | Refresh current directory |
| `F2` | Rename selected item |
| `Delete` | Delete selected items |
| `Ctrl+C` | Copy selected items |
| `Ctrl+X` | Cut selected items |
| `Ctrl+V` | Paste items |
| `Ctrl+Z` | Undo last delete |
| `Escape` | Cancel edit / clear selection / close preview |
| `Space` | Toggle play/pause (video) |
| `F11` | Open fullscreen video |
| `Left/Right` | Navigate files in preview / seek video |
| `Up/Down` | Navigate files in preview |

## License

This project is provided as-is. mpv is licensed under GPLv2 — see [mpv.io](https://mpv.io/) for details. LockHunter is freeware — see [lockhunter.com](https://lockhunter.com/) for its license terms.
