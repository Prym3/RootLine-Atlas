from __future__ import annotations

import hashlib
import os
import re
import json
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime
from pathlib import Path

import shell_bridge
from typing import Any

import humanize

from PySide6.QtCore import (
    QObject, Property, Signal, Slot, QAbstractListModel, QModelIndex, Qt,
    QThread, QByteArray, QFileSystemWatcher, QTimer, QUrl
)
from PySide6.QtGui import QGuiApplication


def log_debug(msg: str) -> None:
    pass
SIZE_RE = re.compile(r"^(\d+(?:\.\d+)?)\s*(B|KB|MB|GB|TB|PB)$", re.IGNORECASE)
SIZE_MULT = {
    "B": 1,
    "KB": 1024,
    "MB": 1024 ** 2,
    "GB": 1024 ** 3,
    "TB": 1024 ** 4,
    "PB": 1024 ** 5,
}


def parse_size(text: str) -> int | None:
    if not text:
        return None
    m = SIZE_RE.match(text.strip())
    if not m:
        return None
    return int(float(m.group(1)) * SIZE_MULT[m.group(2).upper()])


def format_size(size: int) -> str:
    return humanize.naturalsize(size or 0, binary=True)


def format_time(ts: float) -> str:
    return datetime.fromtimestamp(ts).strftime("%Y-%m-%d %H:%M:%S")


def _fast_walk_size(root: Path) -> tuple[int, int, int]:
    size = folders = files = 0
    stack = [root]
    import time
    while stack:
        path = stack.pop()
        if folders > 0 and folders % 150 == 0:
            time.sleep(0.001)
        try:
            with os.scandir(path) as it:
                for entry in it:
                    try:
                        if entry.is_dir(follow_symlinks=False):
                            try:
                                if entry.is_symlink():
                                    continue
                                if os.name == "nt" and entry.stat(follow_symlinks=False).st_file_attributes & 0x400:
                                    continue
                            except OSError:
                                pass
                            folders += 1
                            stack.append(entry.path)
                        else:
                            files += 1
                            try:
                                size += entry.stat(follow_symlinks=False).st_size
                            except OSError:
                                pass
                    except OSError:
                        pass
        except OSError:
            pass
    return size, folders, files


_EXT_COLOURS: dict[str, str] = {
    ".py": "#7C9EFF", ".pyw": "#7C9EFF", ".pyi": "#7C9EFF", ".pyc": "#5570BB",
    ".pyd": "#5570BB", ".pyo": "#5570BB", ".pyx": "#7C9EFF", ".pxd": "#7C9EFF",
    ".js": "#F7DF1E", ".mjs": "#F7DF1E", ".cjs": "#F7DF1E", ".jsx": "#61DAFB",
    ".ts": "#3178C6", ".tsx": "#3178C6", ".d.ts": "#3178C6",
    ".vue": "#42B883", ".svelte": "#FF3E00", ".astro": "#FF5D01",
    ".html": "#E34F26", ".htm": "#E34F26", ".xhtml": "#E34F26",
    ".css": "#1572B6", ".scss": "#CC6699", ".sass": "#CC6699",
    ".less": "#1D365D", ".styl": "#FF6347", ".stylus": "#FF6347",
    ".c": "#A8B9CC", ".h": "#A8B9CC",
    ".cpp": "#9C33CC", ".cxx": "#9C33CC", ".cc": "#9C33CC",
    ".hpp": "#9C33CC", ".hxx": "#9C33CC", ".hh": "#9C33CC",
    ".inl": "#9C33CC", ".tcc": "#9C33CC",
    ".cs": "#239120", ".csx": "#239120", ".razor": "#512BD4",
    ".java": "#B07219", ".class": "#B07219", ".jar": "#B07219",
    ".kt": "#F18E33", ".kts": "#F18E33", ".groovy": "#4298B8",
    ".gradle": "#4298B8", ".scala": "#DC322F", ".clj": "#63B132",
    ".cljs": "#63B132", ".cljc": "#63B132",
    ".go": "#00ADD8", ".mod": "#00ADD8", ".sum": "#00ADD8",
    ".rs": "#DEA584", ".toml": "#9C4121",
    ".rb": "#CC342D", ".rake": "#CC342D", ".gemspec": "#CC342D",
    ".erb": "#CC342D", ".haml": "#CC342D", ".slim": "#CC342D",
    ".php": "#777BB4", ".phtml": "#777BB4", ".php3": "#777BB4",
    ".php4": "#777BB4", ".php5": "#777BB4", ".php7": "#777BB4",
    ".swift": "#F05138", ".m": "#438EFF", ".mm": "#438EFF",
    ".lua": "#6B9EFF",
    ".sh": "#4EAA25", ".bash": "#4EAA25", ".zsh": "#4EAA25",
    ".fish": "#4EAA25", ".ksh": "#4EAA25", ".csh": "#4EAA25",
    ".tcsh": "#4EAA25", ".dash": "#4EAA25",
    ".ps1": "#5391FE", ".psm1": "#5391FE", ".psd1": "#5391FE",
    ".bat": "#C1F12E", ".cmd": "#C1F12E",
    ".r": "#276DC3", ".rmd": "#276DC3", ".rnw": "#276DC3",
    ".jl": "#9558B2",
    ".ml": "#E66E00", ".mli": "#E66E00",
    ".fs": "#378BBA", ".fsi": "#378BBA", ".fsx": "#378BBA",
    ".hs": "#5D4F85", ".lhs": "#5D4F85",
    ".elm": "#60B5CC",
    ".dart": "#00B4AB",
    ".ex": "#6E4A7E", ".exs": "#6E4A7E", ".eex": "#6E4A7E",
    ".erl": "#B83998", ".hrl": "#B83998",
    ".pl": "#0298C3", ".pm": "#0298C3",
    ".awk": "#C0C0C0", ".sed": "#C0C0C0",
    ".tcl": "#E4CC98",
    ".nim": "#FFE953",
    ".v": "#5D87BF", ".vh": "#5D87BF", ".sv": "#5D87BF",
    ".vhd": "#ADB2C3", ".vhdl": "#ADB2C3",
    ".zig": "#F7A41D",
    ".d": "#BA595E",
    ".pas": "#0055AA", ".pp": "#0055AA",
    ".ada": "#02F88C", ".adb": "#02F88C", ".ads": "#02F88C",
    ".f": "#734F96", ".f90": "#734F96", ".f95": "#734F96", ".for": "#734F96",
    ".cob": "#005CA5", ".cbl": "#005CA5",
    ".lisp": "#3FB68B", ".lsp": "#3FB68B",
    ".scm": "#1E4AEC", ".ss": "#1E4AEC",
    ".coffee": "#244776",
    ".cr": "#000100",
    ".raku": "#0000FB", ".p6": "#0000FB",
    ".json": "#FFCB47", ".jsonc": "#FFCB47", ".json5": "#FFCB47",
    ".xml": "#F07040", ".xsd": "#F07040", ".xsl": "#F07040", ".xslt": "#F07040",
    ".dtd": "#F07040", ".wsdl": "#F07040",
    ".yaml": "#CB171E", ".yml": "#CB171E",
    ".ini": "#6D8086", ".cfg": "#6D8086", ".conf": "#6D8086",
    ".config": "#6D8086", ".properties": "#6D8086", ".prefs": "#6D8086",
    ".env": "#ECD53F", ".env.local": "#ECD53F",
    ".csv": "#23A566", ".tsv": "#23A566", ".dsv": "#23A566",
    ".sql": "#E38C00", ".mysql": "#E38C00", ".psql": "#E38C00",
    ".sqlite": "#E38C00", ".db": "#E38C00", ".dbf": "#E38C00",
    ".graphql": "#E535AB", ".gql": "#E535AB",
    ".proto": "#4285F4",
    ".thrift": "#D12127",
    ".avro": "#D62728",
    ".parquet": "#50ABF1",
    ".ndjson": "#FFCB47", ".jsonl": "#FFCB47",
    ".hcl": "#5C4EE5", ".tf": "#5C4EE5", ".tfvars": "#5C4EE5",
    ".editorconfig": "#FAFAFA",
    ".gitignore": "#F05032", ".gitattributes": "#F05032",
    ".dockerignore": "#2496ED", ".dockerfile": "#2496ED",
    ".npmrc": "#CB3837", ".nvmrc": "#339933",
    ".babelrc": "#F5DA55", ".eslintrc": "#4B32C3",
    ".prettierrc": "#F7B93E", ".stylelintrc": "#263238",
    ".md": "#083FA1", ".mdx": "#083FA1", ".markdown": "#083FA1",
    ".rst": "#3776AB", ".adoc": "#E40046", ".asciidoc": "#E40046",
    ".txt": "#BBBBBB", ".text": "#BBBBBB", ".log": "#AAAAAA",
    ".nfo": "#AAAAAA", ".readme": "#BBBBBB",
    ".pdf": "#FF0000",
    ".doc": "#2B5797", ".docx": "#2B5797", ".docm": "#2B5797",
    ".xls": "#1D6F42", ".xlsx": "#1D6F42", ".xlsm": "#1D6F42", ".xlsb": "#1D6F42",
    ".ppt": "#D04423", ".pptx": "#D04423", ".pptm": "#D04423",
    ".odt": "#2980BA", ".ods": "#2980BA", ".odp": "#2980BA", ".odg": "#2980BA",
    ".rtf": "#888888", ".wpd": "#888888",
    ".tex": "#008080", ".latex": "#008080", ".bib": "#008080",
    ".epub": "#E67E22", ".mobi": "#E67E22", ".azw": "#E67E22",
    ".pages": "#FF9500", ".numbers": "#1D6F42", ".key": "#D04423",
    ".png": "#A259FF", ".jpg": "#A259FF", ".jpeg": "#A259FF", ".jpe": "#A259FF",
    ".gif": "#FF9500", ".webp": "#FF9500", ".avif": "#FF9500",
    ".svg": "#FFB13B", ".svgz": "#FFB13B",
    ".ico": "#888888", ".bmp": "#888888", ".dib": "#888888",
    ".tiff": "#7B68EE", ".tif": "#7B68EE",
    ".psd": "#31A8FF", ".psb": "#31A8FF",
    ".ai": "#FF7C00", ".eps": "#FF7C00",
    ".xcf": "#1A6496", ".kra": "#1A6496",
    ".raw": "#C0C0C0", ".cr2": "#C0C0C0", ".cr3": "#C0C0C0",
    ".nef": "#C0C0C0", ".arw": "#C0C0C0", ".dng": "#C0C0C0",
    ".heic": "#A259FF", ".heif": "#A259FF",
    ".exr": "#8B4513", ".hdr": "#8B4513",
    ".sketch": "#F7B500", ".fig": "#A259FF",
    ".mp4": "#FF453A", ".m4v": "#FF453A", ".mov": "#FF453A", ".qt": "#FF453A",
    ".avi": "#FF453A", ".wmv": "#FF453A", ".flv": "#FF453A", ".f4v": "#FF453A",
    ".mkv": "#BF5AF2", ".webm": "#BF5AF2",
    ".ogv": "#BF5AF2", ".ogg": "#30D158",
    ".3gp": "#FF9F43", ".3g2": "#FF9F43",
    ".ts": "#3178C6", ".mts": "#3178C6", ".m2ts": "#3178C6",
    ".vob": "#FF6B6B", ".dvd": "#FF6B6B",
    ".rmvb": "#E91E63", ".rm": "#E91E63",
    ".asf": "#FF453A",
    ".mp3": "#30D158", ".mp2": "#30D158",
    ".flac": "#30D158", ".wav": "#30D158", ".wave": "#30D158",
    ".aac": "#30D158", ".m4a": "#30D158", ".m4b": "#30D158",
    ".ogg": "#30D158", ".oga": "#30D158",
    ".wma": "#30D158", ".aiff": "#30D158", ".aif": "#30D158",
    ".opus": "#30D158", ".ape": "#30D158", ".wv": "#30D158",
    ".mid": "#30D158", ".midi": "#30D158",
    ".amr": "#30D158", ".au": "#30D158",
    ".mka": "#30D158",
    ".zip": "#FFD60A", ".zipx": "#FFD60A",
    ".tar": "#FFD60A", ".tgz": "#FFD60A", ".tar.gz": "#FFD60A",
    ".tar.bz2": "#FFD60A", ".tar.xz": "#FFD60A", ".tar.zst": "#FFD60A",
    ".gz": "#FFD60A", ".bz2": "#FFD60A", ".xz": "#FFD60A",
    ".zst": "#FFD60A", ".lz": "#FFD60A", ".lzma": "#FFD60A",
    ".7z": "#FFD60A", ".rar": "#FFD60A", ".r00": "#FFD60A",
    ".cab": "#FFD60A", ".iso": "#FFD60A", ".img": "#FFD60A",
    ".dmg": "#FFD60A", ".pkg": "#FFD60A",
    ".deb": "#D70751", ".rpm": "#D70751",
    ".apk": "#3DDC84", ".aab": "#3DDC84",
    ".ipa": "#999999", ".xcarchive": "#999999",
    ".snap": "#E95420", ".flatpak": "#4A90D9",
    ".war": "#B07219", ".ear": "#B07219",
    ".nupkg": "#512BD4", ".vsix": "#5C2D91",
    ".gem": "#CC342D",
    ".whl": "#7C9EFF", ".egg": "#7C9EFF",
    ".exe": "#FF6B6B", ".msi": "#FF6B6B", ".msix": "#FF6B6B",
    ".dll": "#FF9F43", ".lib": "#FF9F43", ".a": "#FF9F43",
    ".so": "#FF9F43", ".dylib": "#FF9F43", ".o": "#FF9F43",
    ".elf": "#FF6B6B", ".bin": "#FF6B6B", ".run": "#FF6B6B",
    ".com": "#FF6B6B", ".scr": "#FF6B6B",
    ".out": "#CC99CD",
    ".ttf": "#FFAA33", ".otf": "#FFAA33",
    ".woff": "#FFAA33", ".woff2": "#FFAA33",
    ".eot": "#FFAA33", ".pfb": "#FFAA33", ".pfm": "#FFAA33",
    ".obj": "#00BCD4", ".fbx": "#00BCD4", ".dae": "#00BCD4",
    ".gltf": "#00BCD4", ".glb": "#00BCD4", ".stl": "#00BCD4",
    ".blend": "#EA7600", ".max": "#00A1E4", ".ma": "#00A1E4", ".mb": "#00A1E4",
    ".c4d": "#011A6A", ".dwg": "#E20714", ".dxf": "#E20714",
    ".step": "#00BCD4", ".iges": "#00BCD4", ".stp": "#00BCD4",
    ".pem": "#2ECC71", ".crt": "#2ECC71", ".cer": "#2ECC71",
    ".key": "#2ECC71", ".p12": "#2ECC71", ".pfx": "#2ECC71",
    ".csr": "#2ECC71", ".ca-bundle": "#2ECC71",
    ".gpg": "#2ECC71", ".asc": "#2ECC71", ".sig": "#2ECC71",
    ".vmdk": "#607D8B", ".vdi": "#607D8B", ".vhd": "#607D8B", ".vhdx": "#607D8B",
    ".qcow2": "#607D8B", ".ova": "#607D8B", ".ovf": "#607D8B",
    ".sys": "#9E9E9E", ".drv": "#9E9E9E", ".inf": "#9E9E9E",
    ".reg": "#0078D4", ".lnk": "#0078D4", ".url": "#0078D4",
    ".tmp": "#777777", ".bak": "#777777", ".old": "#777777",
    ".swp": "#777777", ".lock": "#777777",
    ".pid": "#777777", ".sock": "#777777",
    ".unity": "#000000", ".unitypackage": "#000000",
    ".uasset": "#1B8AC4", ".umap": "#1B8AC4",
    ".godot": "#478CBF", ".tscn": "#478CBF", ".gd": "#478CBF",
    ".pak": "#9E9E9E", ".wad": "#9E9E9E", ".bsp": "#9E9E9E",
    ".srt": "#AAAAAA", ".vtt": "#AAAAAA", ".ass": "#AAAAAA", ".ssa": "#AAAAAA",
    ".sub": "#AAAAAA",
    ".torrent": "#1DA462",
    ".var": "#FFFFFF",
}
_EXT_COLOUR_DEFAULT = "#666888"


def ext_colour(name: str) -> str:
    ext = Path(name).suffix.lower()
    return _EXT_COLOURS.get(ext, _EXT_COLOUR_DEFAULT)


_EXT_ICONS: dict[str, str] = {
    "code": {
        "py","pyw","pyi","pyx","pxd","js","mjs","cjs","jsx","ts","tsx","vue",
        "svelte","astro","html","htm","xhtml","css","scss","sass","less","styl",
        "stylus","cpp","cxx","cc","c","h","hpp","hxx","hh","inl","tcc","cs","csx",
        "razor","java","kt","kts","groovy","gradle","scala","clj","cljs","cljc",
        "go","rs","rb","rake","gemspec","erb","haml","slim","php","phtml","swift",
        "m","mm","lua","sh","bash","zsh","fish","ksh","csh","tcsh","dash","ps1",
        "psm1","psd1","bat","cmd","r","rmd","jl","ml","mli","fs","fsi","fsx","hs",
        "lhs","elm","dart","ex","exs","eex","erl","hrl","pl","pm","awk","sed","tcl",
        "nim","v","vh","sv","zig","d","pas","pp","ada","adb","ads","f","f90","f95",
        "for","cob","cbl","lisp","lsp","scm","ss","coffee","cr","raku","p6","gd",
        "vhd","vhdl","class",
    },
    "data": {
        "json","jsonc","json5","ndjson","jsonl","xml","xsd","xsl","xslt","dtd",
        "wsdl","yaml","yml","toml","ini","cfg","conf","config","properties","prefs",
        "env","csv","tsv","dsv","sql","mysql","psql","sqlite","db","dbf","graphql",
        "gql","proto","thrift","avro","parquet","hcl","tf","tfvars","mod","sum",
    },
    "doc": {
        "md","mdx","markdown","rst","adoc","asciidoc","txt","text","log","nfo",
        "readme","pdf","doc","docx","docm","xls","xlsx","xlsm","xlsb","ppt","pptx",
        "pptm","odt","ods","odp","odg","rtf","wpd","tex","latex","bib","epub",
        "mobi","azw","pages","numbers","key",
    },
    "image": {
        "png","jpg","jpeg","jpe","gif","webp","avif","svg","svgz","ico","bmp","dib",
        "tiff","tif","psd","psb","ai","eps","xcf","kra","raw","cr2","cr3","nef",
        "arw","dng","heic","heif","exr","hdr","sketch","fig",
    },
    "video": {
        "mp4","m4v","mov","qt","avi","wmv","flv","f4v","mkv","webm","ogv","3gp",
        "3g2","mts","m2ts","vob","dvd","rmvb","rm","asf",
    },
    "audio": {
        "mp3","mp2","flac","wav","wave","aac","m4a","m4b","ogg","oga","wma","aiff",
        "aif","opus","ape","wv","mid","midi","amr","au","mka",
    },
    "archive": {
        "zip","zipx","tar","tgz","gz","bz2","xz","zst","lz","lzma","7z","rar","r00",
        "cab","iso","img","dmg","pkg","deb","rpm","apk","aab","ipa","xcarchive",
        "snap","flatpak","war","ear","nupkg","vsix","gem","whl","egg","var",
    },
    "exe": {
        "exe","msi","msix","dll","lib","a","so","dylib","o","elf","bin","run",
        "com","scr","out","pyc","pyd","pyo",
    },
    "font": {"ttf","otf","woff","woff2","eot","pfb","pfm"},
}
_EXT_ICON_MAP: dict[str, str] = {}
for _glyph, _exts in _EXT_ICONS.items():
    for _e in _exts:
        _EXT_ICON_MAP[f".{_e}"] = f"fileType{_glyph.capitalize()}"
_EXT_ICON_DEFAULT = "file"


def ext_icon(name: str) -> str:
    ext = Path(name).suffix.lower()
    return _EXT_ICON_MAP.get(ext, _EXT_ICON_DEFAULT)


_SYSTEM_HIDDEN: frozenset[str] = frozenset({
    "$recycle.bin", "system volume information", "$winreagent",
    "$windows.~bt", "$windows.~ws", "recovery", "config.msi",
    "msocache", "pagefile.sys", "swapfile.sys", "hiberfil.sys",
    "bootmgr", "bootnxt", "boot", "efi",
})

def _is_system_hidden(p: Path, attrs: int | None = None) -> bool:
    name_lower = p.name.lower()
    if name_lower in _SYSTEM_HIDDEN:
        return True
    if name_lower.startswith("$"):
        return True
    try:
        import stat as _stat
        if attrs is None:
            attrs = p.stat().st_file_attributes
        if attrs & 0x2 and attrs & 0x4:
            return True
    except (AttributeError, OSError):
        pass
    return False


def _is_hidden(p: Path, attrs: int | None = None) -> bool:
    if p.name.startswith("."):
        return True
    try:
        if attrs is None:
            attrs = p.stat().st_file_attributes
        if attrs & 0x2:
            return True
    except (AttributeError, OSError):
        pass
    return False


def folder_size(path: Path) -> int:
    size, _, _ = _fast_walk_size(path)
    return size


def folder_stats(path: Path) -> tuple[int, int, int]:
    return _fast_walk_size(path)


class ResultsModel(QAbstractListModel):
    NameRole = Qt.UserRole + 1
    SizeRole = Qt.UserRole + 2
    SizeBytesRole = Qt.UserRole + 3
    TypeRole = Qt.UserRole + 4
    PathRole = Qt.UserRole + 5
    CreatedRole = Qt.UserRole + 6
    IndentRole = Qt.UserRole + 7
    ConnectorRole = Qt.UserRole + 8
    LevelRole = Qt.UserRole + 9
    IsDirRole = Qt.UserRole + 10
    FullPathRole = Qt.UserRole + 11
    HiddenRole = Qt.UserRole + 12

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._rows: list[dict[str, Any]] = []
        self._all_rows: list[dict[str, Any]] = []
        self._search_text: str = ""

    def roleNames(self) -> dict[int, QByteArray]:
        return {
            self.NameRole: b"name",
            self.SizeRole: b"sizeText",
            self.SizeBytesRole: b"sizeBytes",
            self.TypeRole: b"entryType",
            self.PathRole: b"relPath",
            self.CreatedRole: b"created",
            self.IndentRole: b"indent",
            self.ConnectorRole: b"connector",
            self.LevelRole: b"level",
            self.IsDirRole: b"isDir",
            self.FullPathRole: b"fullPath",
            self.HiddenRole: b"isHidden",
        }

    def rowCount(self, parent: QModelIndex = QModelIndex()) -> int:
        if parent.isValid():
            return 0
        return len(self._rows)

    def data(self, index: QModelIndex, role: int = Qt.DisplayRole):
        if not index.isValid() or index.row() >= len(self._rows):
            return None
        row = self._rows[index.row()]
        mapping = {
            self.NameRole: "name",
            self.SizeRole: "size_text",
            self.SizeBytesRole: "size",
            self.TypeRole: "type",
            self.PathRole: "rel_path",
            self.CreatedRole: "created",
            self.IndentRole: "indent",
            self.ConnectorRole: "connector",
            self.LevelRole: "level",
            self.IsDirRole: "is_dir",
            self.FullPathRole: "full_path",
            self.HiddenRole: "is_hidden",
        }
        key = mapping.get(role)
        if key == "is_hidden":
            val = row.get("is_hidden")
            if val is None:
                full_path = row.get("full_path")
                if full_path:
                    val = _is_hidden(Path(full_path))
                    row["is_hidden"] = val
                else:
                    val = False
            return val
        return row.get(key) if key else None

    def reset_rows(self, rows: list[dict[str, Any]]) -> None:
        self.beginResetModel()
        self._all_rows = rows
        self._rows = self._compute_filtered()
        self.endResetModel()

    def rows(self) -> list[dict[str, Any]]:
        return self._rows

    def all_rows(self) -> list[dict[str, Any]]:
        return self._all_rows

    def row_for_full_path(self, full_path: str) -> dict[str, Any] | None:
        if not full_path:
            return None
        for r in self._all_rows:
            if r.get("full_path") == full_path:
                return r
        return None

    def remove_by_full_paths(self, paths: list[str]) -> list[dict[str, Any]]:
        if not paths:
            return []
        target = set(p for p in paths if p)
        if not target:
            return []
        n = len(self._all_rows)
        to_remove: set[int] = set()
        for i, r in enumerate(self._all_rows):
            if i in to_remove:
                continue
            if r.get("full_path") in target:
                to_remove.add(i)
                level = r.get("level", 0) or 0
                j = i + 1
                while j < n:
                    lvl = self._all_rows[j].get("level", 0) or 0
                    if lvl > level:
                        to_remove.add(j)
                        j += 1
                    else:
                        break
        if not to_remove:
            return []
        removed_rows = [self._all_rows[i] for i in sorted(to_remove)]
        self.beginResetModel()
        self._all_rows = [r for i, r in enumerate(self._all_rows) if i not in to_remove]
        self._rows = self._compute_filtered()
        self.endResetModel()
        return removed_rows

    def rename_by_full_path(self, old_path: str, new_path: str) -> bool:
        if not old_path or not new_path or old_path == new_path:
            return False
        new_name = os.path.basename(new_path) or new_path
        sep_variants = (old_path + os.sep, old_path + "/")
        changed = False
        for r in self._all_rows:
            fp = r.get("full_path") or ""
            if fp == old_path:
                r["full_path"] = new_path
                r["name"] = new_name
                changed = True
            elif fp.startswith(sep_variants[0]) or fp.startswith(sep_variants[1]):
                r["full_path"] = new_path + fp[len(old_path):]
                rel = r.get("rel_path") or ""
                if rel == old_path:
                    r["rel_path"] = new_path
                elif rel.startswith(sep_variants[0]) or rel.startswith(sep_variants[1]):
                    r["rel_path"] = new_path + rel[len(old_path):]
                changed = True
        if changed:
            self.beginResetModel()
            self._rows = self._compute_filtered()
            self.endResetModel()
        return changed

    def expand_after(self, full_path: str, new_rows: list[dict[str, Any]]) -> int:
        if not full_path or not new_rows:
            return 0
        if self._search_text:
            return 0
        parent_idx = -1
        for i, r in enumerate(self._rows):
            if r.get("full_path") == full_path:
                parent_idx = i
                break
        if parent_idx < 0:
            return 0
        insert_at = parent_idx + 1
        self.beginInsertRows(QModelIndex(), insert_at, insert_at + len(new_rows) - 1)
        self._rows[insert_at:insert_at] = new_rows
        all_idx = -1
        for i, r in enumerate(self._all_rows):
            if r.get("full_path") == full_path:
                all_idx = i
                break
        if all_idx >= 0:
            self._all_rows[all_idx + 1:all_idx + 1] = new_rows
        self.endInsertRows()
        return len(new_rows)

    def collapse_descendants(self, full_path: str) -> int:
        if not full_path or self._search_text:
            return 0
        parent_idx = -1
        for i, r in enumerate(self._rows):
            if r.get("full_path") == full_path:
                parent_idx = i
                break
        if parent_idx < 0:
            return 0
        parent_level = self._rows[parent_idx].get("level", 0) or 0
        end = parent_idx + 1
        n = len(self._rows)
        while end < n:
            lvl = self._rows[end].get("level", 0) or 0
            if lvl > parent_level:
                end += 1
            else:
                break
        count = end - (parent_idx + 1)
        if count <= 0:
            return 0
        first = parent_idx + 1
        last = end - 1
        self.beginRemoveRows(QModelIndex(), first, last)
        del self._rows[first:end]
        all_idx = -1
        for i, r in enumerate(self._all_rows):
            if r.get("full_path") == full_path:
                all_idx = i
                break
        if all_idx >= 0:
            a_end = all_idx + 1
            an = len(self._all_rows)
            while a_end < an:
                lvl = self._all_rows[a_end].get("level", 0) or 0
                if lvl > parent_level:
                    a_end += 1
                else:
                    break
            del self._all_rows[all_idx + 1:a_end]
        self.endRemoveRows()
        return count

    def set_search_text(self, text: str) -> None:
        text = (text or "").strip().lower()
        if text == self._search_text:
            return
        self._search_text = text
        self.beginResetModel()
        self._rows = self._compute_filtered()
        self.endResetModel()

    def _compute_filtered(self) -> list[dict[str, Any]]:
        if not self._search_text:
            return list(self._all_rows)
        q = self._search_text
        included: set[int] = set()
        is_tree_mode = any(r.get("level", 0) > 0 for r in self._all_rows)
        for i, row in enumerate(self._all_rows):
            name = (row.get("name") or "").lower()
            if q in name:
                included.add(i)
                if is_tree_mode:
                    lvl = row.get("level", 0) or 0
                    j = i - 1
                    while j >= 0 and lvl > 0:
                        anc_lvl = self._all_rows[j].get("level", 0) or 0
                        if anc_lvl < lvl:
                            included.add(j)
                            lvl = anc_lvl
                        j -= 1
        return [self._all_rows[i] for i in sorted(included)]

    def update_row_size(self, full_path: str, size: int, size_text: str) -> bool:
        changed = False
        for r in self._all_rows:
            if r.get("full_path") == full_path:
                r["size"] = size
                r["size_text"] = size_text
                changed = True
                break
        
        for idx, r in enumerate(self._rows):
            if r.get("full_path") == full_path:
                r["size"] = size
                r["size_text"] = size_text
                qidx = self.index(idx, 0)
                self.dataChanged.emit(qidx, qidx, [])
                log_debug(f"[DEBUG] update_row_size updated model row at index={idx} path={full_path} to {size_text}")
                changed = True
                break
        if not changed:
            log_debug(f"[DEBUG] update_row_size path={full_path} not found in model rows")
        return changed


class DeleteWorker(QObject):
    finished = Signal("QVariantList")
    error = Signal(str, str)

    def __init__(self, paths: list[str]) -> None:
        super().__init__()
        self.paths = paths
        self._cancelled = False
        self.deleted_names: list[str] = []
        self.deleted_paths: list[str] = []

    def cancel(self) -> None:
        self._cancelled = True

    def run(self) -> None:
        from pathlib import Path
        valid = []
        for p in self.paths:
            if self._cancelled:
                break
            if p and Path(p).exists():
                valid.append(p)
                self.deleted_names.append(Path(p).name)
                self.deleted_paths.append(p)
        if valid and not self._cancelled:
            try:
                shell_bridge.delete_files(valid, to_recycle_bin=True)
            except Exception as e:
                self.error.emit(valid[0], str(e))
        self.finished.emit(self.deleted_names)


class PasteWorker(QObject):
    finished = Signal("QVariantList", bool)
    error = Signal(str)
    progress = Signal(int, int, float, float, float, float, str)

    def __init__(self, paths: list[str], dest_dir: str, is_cut: bool,
                 resolutions: dict[str, str],
                 target_paths: dict[str, str] | None = None) -> None:
        super().__init__()
        self.paths = paths
        self.dest_dir = dest_dir
        self.is_cut = is_cut
        self.resolutions = resolutions
        self.target_paths = target_paths or {}
        self.moved_pairs: list[tuple[str, str]] = []
        self.copied_dests: list[str] = []
        self._cancelled = False

    def cancel(self) -> None:
        self._cancelled = True

    @Slot()
    def run(self) -> None:
        from pathlib import Path
        try:
            pasted_names: list[str] = []
            valid_sources = []
            for path_str in self.paths:
                if self._cancelled:
                    break
                src = Path(path_str)
                if not src.exists():
                    continue
                if path_str in self.resolutions and self.resolutions[path_str] == "skip":
                    continue
                valid_sources.append(path_str)

            if not valid_sources or self._cancelled:
                self.finished.emit([], self.is_cut)
                return

            total = len(valid_sources)
            self.progress.emit(0, total, 0.0, 1.0, 0.0, float(total), "")

            if self.is_cut:
                shell_bridge.move_files(valid_sources, self.dest_dir)
                for path_str in valid_sources:
                    src = Path(path_str)
                    dest_path = Path(self.dest_dir) / src.name
                    self.moved_pairs.append((path_str, str(dest_path)))
                    pasted_names.append(src.name)
            else:
                shell_bridge.copy_files(valid_sources, self.dest_dir)
                for path_str in valid_sources:
                    src = Path(path_str)
                    dest_path = Path(self.dest_dir) / src.name
                    self.copied_dests.append(str(dest_path))
                    pasted_names.append(src.name)

            self.progress.emit(total, total, 1.0, 1.0, float(total), float(total), "")

            self.finished.emit(pasted_names, self.is_cut)
        except Exception as e:
            self.error.emit(str(e))
            self.finished.emit([], self.is_cut)

class ExpandWorker(QObject):
    finished = Signal(str, list)

    def __init__(self, full_path: str, parent_level: int, filters: dict) -> None:
        super().__init__()
        self._full_path = full_path
        self._parent_level = parent_level
        self._filters = filters

    @Slot()
    def run(self) -> None:
        p = Path(self._full_path)
        helper = ScanWorker(str(p), self._filters, "tree")
        f = self._filters
        try:
            entries = [e for e in p.iterdir() if not _is_system_hidden(e)]
        except (PermissionError, OSError):
            self.finished.emit(self._full_path, [])
            return
        entries = helper._sort(entries)

        subdirs = [e for e in entries if e.is_dir()]
        size_map: dict[Path, int] = {}
        if subdirs:
            workers = min(os.cpu_count() or 1, max(1, len(subdirs)))
            with ThreadPoolExecutor(max_workers=workers) as pool:
                futs = {pool.submit(folder_size, d): d for d in subdirs}
                for fut in as_completed(futs):
                    d = futs[fut]
                    try:
                        size_map[d] = fut.result()
                    except Exception:
                        size_map[d] = 0

        rows: list[dict] = []
        for e in entries:
            try:
                is_dir = e.is_dir()
                size = size_map.get(e, 0) if is_dir else helper._safe_size(e)
                st = e.stat()
            except (PermissionError, OSError):
                continue
            if is_dir:
                if f["filter_type"] == "files":
                    continue
            else:
                if not helper._passes(e.name, size, False, st.st_ctime):
                    continue
            try:
                created = format_time(st.st_ctime)
            except OSError:
                created = ""
            rows.append({
                "name": e.name,
                "size": size,
                "size_text": format_size(size),
                "type": "Folder" if is_dir else "File",
                "rel_path": str(e.parent),
                "created": created,
                "indent": "",
                "connector": "",
                "level": self._parent_level + 1,
                "is_dir": is_dir,
                "full_path": str(e),
                "is_hidden": _is_hidden(e),
            })
        self.finished.emit(self._full_path, rows)


class ScanWorker(QObject):
    finished = Signal(list, int, int, "qint64", str, str)
    error = Signal(str)
    progress = Signal(int, int, str)

    def __init__(self, root: str, filters: dict, mode: str, force_recursive: bool = False, pool=None) -> None:
        super().__init__()
        self.root = root
        self.filters = filters
        self.mode = mode
        self.force_recursive = force_recursive
        self._cancelled = False
        self._paused = False
        self._pool = pool

    def cancel(self) -> None:
        self._cancelled = True

    def pause(self) -> None:
        self._paused = True

    def resume(self) -> None:
        self._paused = False

    def toggle_pause(self) -> None:
        self._paused = not self._paused

    def _wait_if_paused(self) -> None:
        while self._paused and not self._cancelled:
            import time
            time.sleep(0.1)

    def _passes(self, name: str, size: int, is_dir: bool, ctime: float = 0.0) -> bool:
        f = self.filters
        if f["filter_type"] == "files" and is_dir:
            return False
        if f["filter_type"] == "folders" and not is_dir:
            return False
        if f["min_size"] and size < f["min_size"]:
            return False
        if f["max_size"] and size > f["max_size"]:
            return False
        min_d = f.get("min_date", "")
        max_d = f.get("max_date", "")
        if (min_d or max_d) and ctime:
            try:
                entry_date = datetime.fromtimestamp(ctime).date()
                if min_d:
                    if entry_date < datetime.strptime(min_d, "%Y-%m-%d").date():
                        return False
                if max_d:
                    if entry_date > datetime.strptime(max_d, "%Y-%m-%d").date():
                        return False
            except ValueError:
                pass
        lname = name.lower()
        if not is_dir:
            if f["extensions"] and not any(lname.endswith(e) for e in f["extensions"]):
                return False
            if f["exclude_extensions"] and any(lname.endswith(e) for e in f["exclude_extensions"]):
                return False
            if f["keywords"] and not any(k.lower() in lname for k in f["keywords"]):
                return False
            if f["exclude_keywords"] and any(k.lower() in lname for k in f["exclude_keywords"]):
                return False
        return True

    @staticmethod
    def _natkey(s: str):
        return [int(t) if t.isdigit() else t.lower()
                for t in re.split(r"(\d+)", s)]

    def _sort(self, entries: list[Path]) -> list[Path]:
        sb  = self.filters.get("sort_by")  or "none"
        rev = (self.filters.get("sort_dir") or "asc") == "desc"
        nk  = self._natkey
        def _fd(e: Path) -> int:
            return 0 if e.is_dir() else 1
        if sb in ("alph", "name"):
            return sorted(entries, key=lambda e: (_fd(e), nk(e.name)), reverse=rev)
        if sb == "size":
            dirs  = sorted([e for e in entries if e.is_dir()],
                           key=lambda e: (folder_size(e), nk(e.name)), reverse=rev)
            files = sorted([e for e in entries if not e.is_dir()],
                           key=lambda e: (self._safe_size(e), nk(e.name)), reverse=rev)
            return dirs + files
        if sb == "date":
            dirs  = sorted([e for e in entries if e.is_dir()],
                           key=lambda e: (self._safe_mtime(e), nk(e.name)), reverse=rev)
            files = sorted([e for e in entries if not e.is_dir()],
                           key=lambda e: (self._safe_mtime(e), nk(e.name)), reverse=rev)
            return dirs + files
        if sb == "path":
            return sorted(entries, key=lambda e: (_fd(e), nk(str(e))), reverse=rev)
        if sb == "type":
            return sorted(entries, key=lambda e: (_fd(e), e.suffix.lower(), nk(e.name)), reverse=rev)
        return sorted(entries, key=lambda e: (_fd(e), nk(e.name)))

    @staticmethod
    def _safe_size(p: Path) -> int:
        try:
            return p.stat().st_size
        except OSError:
            return 0

    @staticmethod
    def _safe_mtime(p: Path) -> float:
        try:
            return p.stat().st_mtime
        except OSError:
            return 0.0

    def _emit_progress(self, folders: int, files: int, name: str) -> None:
        import time as _t
        now = _t.monotonic()
        last = getattr(self, "_last_progress_ts", 0.0)
        if now - last >= 0.08 or (folders == 0 and files == 0):
            self._last_progress_ts = now
            self.progress.emit(folders, files, name)

    def run(self) -> None:
        try:
            log_debug(f"[DEBUG] ScanWorker.run starting for root={self.root}, mode={self.mode}")
            root = Path(self.root)
            if not root.exists() or not root.is_dir():
                self.error.emit(f"Directory not found: {self.root}")
                return
            self._emit_progress(0, 0, "")
            import time as _time
            _time.sleep(0.05)
            if self.mode == "tree":
                log_debug("[DEBUG] ScanWorker.run calling _build_tree")
                rows, folders, files, size = self._build_tree(root, pool=self._pool)
            else:
                log_debug("[DEBUG] ScanWorker.run calling _build_list")
                rows, folders, files, size = self._build_list(root, pool=self._pool)
            log_debug(f"[DEBUG] ScanWorker.run scan complete: {len(rows)} rows, emitting finished")
            self.finished.emit(rows, folders, files, int(size), format_size(size), self.mode)
        except Exception as exc:
            log_debug(f"[DEBUG] ScanWorker.run Exception: {exc}")
            import traceback
            traceback.print_exc()
            self.error.emit(str(exc))

    def _build_list(self, root: Path, pool=None) -> tuple[list[dict], int, int, int]:
        f = self.filters
        rows: list[dict] = []
        total_folders = total_files = total_size = 0
        _p_folders = _p_files = 0

        collected_infos = []
        if self.force_recursive:
            stack = [root]
            while stack:
                self._wait_if_paused()
                if self._cancelled:
                    return [], 0, 0, 0
                current = stack.pop()
                try:
                    with os.scandir(current) as it:
                        for entry in it:
                            try:
                                p = Path(entry.path)
                                is_dir = entry.is_dir(follow_symlinks=False)
                                st = entry.stat(follow_symlinks=False)
                                attrs = getattr(st, "st_file_attributes", 0)
                                if _is_system_hidden(p, attrs):
                                    continue
                                collected_infos.append({
                                    "name": entry.name,
                                    "is_dir": is_dir,
                                    "size": 0 if is_dir else st.st_size,
                                    "mtime": st.st_mtime,
                                    "ctime": st.st_ctime,
                                    "full_path": entry.path,
                                    "suffix": p.suffix.lower(),
                                    "attrs": attrs,
                                })
                                if is_dir:
                                    _p_folders += 1
                                    stack.append(entry.path)
                                else:
                                    _p_files += 1
                                if (_p_folders + _p_files) % 50 == 0:
                                    self._emit_progress(_p_folders, _p_files, entry.name)
                            except (PermissionError, OSError):
                                continue
                except OSError:
                    continue
        else:
            try:
                with os.scandir(root) as it:
                    for entry in it:
                        try:
                            p = Path(entry.path)
                            is_dir = entry.is_dir(follow_symlinks=False)
                            st = entry.stat(follow_symlinks=False)
                            attrs = getattr(st, "st_file_attributes", 0)
                            if _is_system_hidden(p, attrs):
                                continue
                            collected_infos.append({
                                "name": entry.name,
                                "is_dir": is_dir,
                                "size": 0 if is_dir else st.st_size,
                                "mtime": st.st_mtime,
                                "ctime": st.st_ctime,
                                "full_path": entry.path,
                                "suffix": p.suffix.lower(),
                                "attrs": attrs,
                            })
                        except (PermissionError, OSError):
                            continue
            except OSError:
                return [], 0, 0, 0

        sb = f.get("sort_by") or "none"
        rev = (f.get("sort_dir") or "asc") == "desc"
        nk = self._natkey

        def _fd(item) -> int:
            return 0 if item["is_dir"] else 1

        if sb in ("alph", "name"):
            collected_infos.sort(key=lambda x: (_fd(x), nk(x["name"])), reverse=rev)
        elif sb == "size":
            dirs = [x for x in collected_infos if x["is_dir"]]
            files = [x for x in collected_infos if not x["is_dir"]]
            dirs.sort(key=lambda x: (x["size"], nk(x["name"])), reverse=rev)
            files.sort(key=lambda x: (x["size"], nk(x["name"])), reverse=rev)
            collected_infos = dirs + files
        elif sb == "date":
            dirs = [x for x in collected_infos if x["is_dir"]]
            files = [x for x in collected_infos if not x["is_dir"]]
            dirs.sort(key=lambda x: (x["mtime"], nk(x["name"])), reverse=rev)
            files.sort(key=lambda x: (x["mtime"], nk(x["name"])), reverse=rev)
            collected_infos = dirs + files
        elif sb == "path":
            collected_infos.sort(key=lambda x: (_fd(x), nk(x["full_path"])), reverse=rev)
        elif sb == "type":
            collected_infos.sort(key=lambda x: (_fd(x), x["suffix"], nk(x["name"])), reverse=rev)
        else:
            collected_infos.sort(key=lambda x: (_fd(x), nk(x["name"])))

        for item in collected_infos:
            self._wait_if_paused()
            if self._cancelled:
                return [], 0, 0, 0
            
            is_dir = item["is_dir"]
            size = item["size"]
            name = item["name"]
            
            if is_dir:
                size_text = "Calculating..."
                _p_folders += 1
            else:
                size_text = format_size(size)
                _p_files += 1
                
            self._emit_progress(_p_folders, _p_files, name)
            
            if not self._passes(name, size, is_dir, item["ctime"]):
                continue
                
            created = format_time(item["ctime"])
            try:
                rel = str(Path(item["full_path"]).parent.relative_to(root))
                if rel == ".":
                    rel = str(root)
            except ValueError:
                rel = str(Path(item["full_path"]).parent)
                
            rows.append({
                "name": name,
                "size": size,
                "size_text": size_text,
                "type": "Folder" if is_dir else "File",
                "rel_path": rel,
                "created": created,
                "indent": "",
                "connector": "",
                "level": 0,
                "is_dir": is_dir,
                "full_path": item["full_path"],
                "is_hidden": _is_hidden(Path(item["full_path"]), item["attrs"]),
            })
            
            if is_dir:
                total_folders += 1
            else:
                total_files += 1
                total_size += size

        return rows, total_folders, total_files, total_size

    def _build_tree(self, root: Path, pool=None) -> tuple[list[dict], int, int, int]:
        f = self.filters
        rows: list[dict] = []
        totals = {"folders": 0, "files": 0, "size": 0}

        _pw = {"folders": 0, "files": 0}

        is_root_drive = Backend._is_drive_root(root) and not self.force_recursive

        def walk(path: Path, level: int, ancestors_last: list[bool]) -> None:
            self._wait_if_paused()
            if self._cancelled:
                return
            try:
                entries = [e for e in path.iterdir() if not _is_system_hidden(e)]
            except (PermissionError, OSError):
                return
            entries = self._sort(entries)

            subdirs = [e for e in entries if e.is_dir()]
            workers = min(os.cpu_count() or 1, max(1, len(subdirs)))
            level_size_map: dict[Path, int] = {}
            if subdirs and not (is_root_drive and level == 0):
                _p = pool or ThreadPoolExecutor(max_workers=workers)
                future_to_path = {_p.submit(folder_size, d): d for d in subdirs}
                for future in as_completed(future_to_path):
                    p = future_to_path[future]
                    try:
                        level_size_map[p] = future.result()
                    except Exception:
                        level_size_map[p] = 0

            visible: list[tuple[Path, bool, int]] = []
            for e in entries:
                if (_pw["folders"] + _pw["files"]) and (_pw["folders"] + _pw["files"]) % 500 == 0:
                    QThread.msleep(1)
                try:
                    is_dir = e.is_dir()
                    size = level_size_map.get(e, 0) if is_dir else self._safe_size(e)
                except (PermissionError, OSError):
                    continue
                if is_dir:
                    _pw["folders"] += 1
                    if (_pw["folders"] + _pw["files"]) % 50 == 0:
                        self._emit_progress(_pw["folders"], _pw["files"], e.name)
                    if f["filter_type"] != "files":
                        visible.append((e, True, size))
                    else:
                        is_reparse = False
                        try:
                            if e.is_symlink():
                                is_reparse = True
                            elif os.name == "nt" and e.stat(follow_symlinks=False).st_file_attributes & 0x400:
                                is_reparse = True
                        except OSError:
                            pass
                        if not is_reparse and not (is_root_drive and level == 0):
                            walk(e, level, ancestors_last)
                else:
                    _pw["files"] += 1
                    if (_pw["folders"] + _pw["files"]) % 50 == 0:
                        self._emit_progress(_pw["folders"], _pw["files"], e.name)
                    try:
                        ctime = e.stat().st_ctime
                    except OSError:
                        ctime = 0.0
                    if self._passes(e.name, size, False, ctime):
                        visible.append((e, False, size))

            for idx, (entry, is_dir, size) in enumerate(visible):
                is_last = idx == len(visible) - 1
                indent_parts = []
                for last in ancestors_last:
                    indent_parts.append("    " if last else "│   ")
                indent = "".join(indent_parts)
                connector = "└── " if is_last else "├── "
                try:
                    created = format_time(entry.stat().st_ctime)
                except OSError:
                    created = ""
                rows.append({
                    "name": entry.name,
                    "size": size,
                    "size_text": format_size(size),
                    "type": "Folder" if is_dir else "File",
                    "rel_path": str(entry.parent),
                    "created": created,
                    "indent": indent,
                    "connector": connector,
                    "level": level,
                    "is_dir": is_dir,
                    "full_path": str(entry),
                    "is_hidden": _is_hidden(entry),
                })
                if is_dir:
                    totals["folders"] += 1
                    is_reparse = False
                    try:
                        if entry.is_symlink():
                            is_reparse = True
                        elif os.name == "nt" and entry.stat(follow_symlinks=False).st_file_attributes & 0x400:
                            is_reparse = True
                    except OSError:
                        pass
                    if not is_reparse and not (is_root_drive and level == 0):
                        walk(entry, level + 1, ancestors_last + [is_last])
                else:
                    totals["files"] += 1
                    totals["size"] += size

        walk(root, 0, [])
        return rows, totals["folders"], totals["files"], totals["size"]


_BOOKMARKS_FILE = Path(__file__).parent / ".bookmarks.json"
_SCAN_CACHE_DIR  = Path(__file__).with_name("cache") / "scans"
_SCAN_INDEX_FILE = _SCAN_CACHE_DIR / ".index.json"
_SCAN_CACHE_MAX  = 250
_TABS_CACHE_FILE = Path(__file__).with_name("cache") / "tabs.json"


class _ExtractWatcherThread(QThread):
    extractDone = Signal(str, str, int)

    def __init__(self, proc, stem: str, archive_path: str = "", dest_dir: str = "", batch_id: int = 0, parent=None):
        super().__init__(parent)
        self._proc = proc
        self._stem = stem
        self._archive_path = archive_path
        self._dest_dir = dest_dir
        self._batch_id = batch_id

    def run(self) -> None:
        try:
            self._proc.wait()
        except Exception as e:
            pass
        
        if self._archive_path and self._dest_dir:
            out_folder = Path(self._dest_dir) / self._stem
            for _ in range(300):
                if out_folder.exists():
                    break
                time.sleep(0.1)
            if out_folder.exists():
                last_size = -1
                stable_count = 0
                for _ in range(600):
                    current_size = sum(f.stat().st_size for f in out_folder.rglob("*") if f.is_file())
                    if current_size == last_size:
                        stable_count += 1
                        if stable_count >= 10:
                            break
                    else:
                        stable_count = 0
                        last_size = current_size
                    time.sleep(0.1)
        
        self.extractDone.emit(self._stem, self._archive_path, self._batch_id)


class Backend(QObject):
    pathChanged = Signal()
    historyChanged = Signal()
    busyChanged = Signal()
    statusChanged = Signal()
    totalsChanged = Signal()
    filtersChanged = Signal()
    viewModeChanged = Signal()
    bookmarksChanged = Signal()
    messagePosted = Signal(str, str)
    scanProgressChanged = Signal()
    canUndoChanged = Signal()
    clipboardChanged = Signal()
    fileSelected = Signal(str)
    undoDone = Signal(str)
    cancelingChanged = Signal()
    forceRecursiveChanged = Signal()
    pasteConflictsDetected = Signal("QVariantList")
    pasteProgressChanged = Signal()
    pasteStarted = Signal()
    pasteFinished = Signal()
    pasteError = Signal(str)
    pasteBusyChanged = Signal()
    expandFinished = Signal(str, int)
    expandBusyChanged = Signal()
    availableDrivesChanged = Signal()
    searchTextChanged = Signal()
    renameConflictDetected = Signal(str, str, str)
    folderSizeUpdated = Signal(str, "qint64", str)
    folderSizesFinalized = Signal(list, dict, str, float)

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._model = ResultsModel(self)
        self._path = ""
        self._history: list[str] = []
        self._history_index = -1
        self._force_recursive = False
        self._busy = False
        self._status = "Ready"
        self._canceling = False
        self._view_mode = "list"
        self._totals = {"folders": 0, "files": 0, "size": 0, "size_text": "0 B"}
        self._total_size_bytes: int = 0
        self._memory_path_cache: dict = {}
        self._self_modified_paths: dict[str, float] = {}
        self._filters = self._default_filters()
        self._thread: QThread | None = None
        self._dying_threads: list[QThread] = []
        self._worker: ScanWorker | None = None
        self._scan_progress = (0, 0, "")
        self._analytics_cache: tuple | None = None
        self._scan_index: dict[str, float] = self._load_scan_index()
        self._bookmarks: list[str] = self._load_bookmarks()
        self._search_text: str = ""
        self._preserve_search_on_scan: bool = False
        self._pending_search_restore: str = ""
        self._trash: list[tuple[str, str]] = []
        self._rename_history: list[tuple[str, str]] = []
        self._move_history: list[list[tuple[str, str]]] = []
        self._copy_history: list[list[str]] = []
        self._archive_app = self._load_settings().get("archive_app", "7z")
        self._extracting = False
        self._extract_threads: list[QThread] = []
        self._bulk_extract_batch_id = 0
        self._bulk_extract_pending: dict[int, int] = {}
        self._bulk_extract_delete_paths: dict[int, list[str]] = {}
        self._winrar_extract_queue: list[str] = []
        self._winrar_extract_delete_after: bool = False
        self._winrar_extract_current: int = 0
        self._winrar_extract_total: int = 0
        self._clipboard_paths: list[str] = []
        self._clipboard_path: str = ""
        self._clipboard_cut: bool = False

        self._pending_paste_paths: list[str] = []
        self._pending_paste_conflicts: list[dict] = []
        self._pending_paste_resolutions: dict[str, str] = {}
        self._pending_paste_dest: Path | None = None
        self._pending_paste_cut: bool = False
        self._folder_size_generation: int = 0

        self._paste_thread: QThread | None = None
        self._paste_worker: PasteWorker | None = None
        self._paste_busy = False
        self._paste_progress = (0, 0, 0.0, 1.0, 0.0, 1.0, "", 0.0)

        self._delete_threads: list[QThread] = []
        self._delete_thread: QThread | None = None
        self._delete_worker: DeleteWorker | None = None
        self._delete_busy = False

        self._expand_thread: QThread | None = None
        self._expand_worker: "ExpandWorker | None" = None
        self._expand_busy = False

        cpu_count = max(2, (os.cpu_count() or 4) - 1)
        self._scan_pool = ThreadPoolExecutor(max_workers=cpu_count)
        QTimer.singleShot(0, lambda: [self._scan_pool.submit(lambda: None) for _ in range(cpu_count)])
        from PySide6.QtCore import QThreadPool
        QThreadPool.globalInstance().setMaxThreadCount(max(8, (os.cpu_count() or 4) * 2))

        self._watcher = QFileSystemWatcher(self)
        self._watcher.fileChanged.connect(self._on_watcher_event)
        self._watcher.directoryChanged.connect(self._on_watcher_event)
        self._watcher_debounce = QTimer(self)
        self._watcher_debounce.setSingleShot(True)
        self._watcher_debounce.timeout.connect(self._do_watched_refresh)
        self._watcher_pending = False

        self._watcher_update_timer = QTimer(self)
        self._watcher_update_timer.setSingleShot(True)
        self._watcher_update_timer.setInterval(500)
        self._watcher_update_timer.timeout.connect(self._apply_watcher_path)

        self._available_drives = self._enumerate_drives()
        self._drive_poll_timer = QTimer(self)
        self._drive_poll_timer.setInterval(2000)
        self._drive_poll_timer.timeout.connect(self._poll_drives)
        self._drive_poll_timer.start()

        self._refresh_timer = QTimer(self)
        self._refresh_timer.setSingleShot(True)
        self._refresh_timer.setInterval(500)
        self._refresh_timer.timeout.connect(self._refresh_current_directory)

        self.folderSizeUpdated.connect(self._model.update_row_size)
        self.folderSizesFinalized.connect(self._on_folder_sizes_finalized)

    def _is_same_folder(self, path1: str, path2: str) -> bool:
        if not path1 or not path2:
            return False
        try:
            return Path(path1).resolve() == Path(path2).resolve()
        except Exception:
            try:
                return os.path.normpath(path1).lower() == os.path.normpath(path2).lower()
            except Exception:
                return str(path1).strip().lower() == str(path2).strip().lower()

    def _refresh_current_directory(self) -> None:
        if not self._path:
            return
        if self._extracting:
            return
        if any(pending > 0 for pending in self._bulk_extract_pending.values()):
            return

        current_search = self._search_text
        current_filters = dict(self._filters)
        
        self._pending_search_restore = current_search
        
        filters = dict(self._filters)
        key = self._cache_key(self._path, self._view_mode, filters)
        self._scan_index.pop(key, None)
        self._save_scan_index()
        
        self.scan()

    def _schedule_scan(self) -> None:
        if not self._path:
            return
        if self._extracting:
            return
        if any(pending > 0 for pending in self._bulk_extract_pending.values()):
            return
        self._refresh_timer.start()

    def _patch_current_cache(self) -> None:
        key = getattr(self, "_pending_cache_key", None)
        if not key:
            return
        try:
            rows = self._model.all_rows()
            folders = int(self._totals.get("folders", 0))
            files = int(self._totals.get("files", 0))
            size_text = self._totals.get("size_text", "")
            size_bytes = int(self._total_size_bytes)
            self._save_scan_shard(key, rows, folders, files, size_text, size_bytes)
            self._scan_index[key] = self._dir_mtime(self._path)
            self._save_scan_index()
        except Exception:
            pass

    def _apply_local_rename(self, old_path: str, new_path: str) -> None:
        if not old_path or not new_path or old_path == new_path:
            return
        self._mark_self_modified([old_path, new_path])
        changed = self._model.rename_by_full_path(old_path, new_path)
        if changed:
            self._analytics_cache = None
            self._patch_current_cache()

    def _apply_local_delete(self, paths: list[str]) -> None:
        if not paths or not self._path:
            return
        paths = [p for p in paths if p]
        if not paths:
            return
        self._mark_self_modified(paths)

        is_tree = (self._view_mode == "tree")
        folders_delta = 0
        files_delta = 0
        size_delta = 0

        if is_tree:
            removed = self._model.remove_by_full_paths(paths)
            for r in removed:
                if r.get("is_dir"):
                    folders_delta += 1
                else:
                    files_delta += 1
                    size_delta += int(r.get("size") or 0)
        else:
            for p in paths:
                row = self._model.row_for_full_path(p)
                if not row:
                    continue
                size_delta += int(row.get("size") or 0)
                if row.get("is_dir"):
                    folders_delta += 1
                else:
                    files_delta += 1
            self._model.remove_by_full_paths(paths)

        if not (folders_delta or files_delta or size_delta):
            return

        new_size = max(0, int(self._total_size_bytes) - int(size_delta))
        self._total_size_bytes = new_size
        self._totals = {
            "folders": max(0, int(self._totals.get("folders", 0)) - folders_delta),
            "files":   max(0, int(self._totals.get("files",   0)) - files_delta),
            "size":    0,
            "size_text": format_size(new_size),
        }
        self.totalsChanged.emit()
        self._analytics_cache = None
        self._patch_current_cache()

    def _create_row_dict_for_path(self, full_path: str) -> dict[str, Any]:
        p = Path(full_path)
        is_dir = p.is_dir()
        try:
            stat = p.stat()
            size = 0 if is_dir else stat.st_size
            created = stat.st_ctime
        except OSError:
            size = 0
            created = 0.0
            
        size_text = ""
        if not is_dir:
            try:
                size_text = humanize.naturalsize(size, binary=True)
            except Exception:
                size_text = f"{size} B"

        return {
            "name": p.name,
            "size": size,
            "size_text": size_text,
            "type": "Folder" if is_dir else p.suffix.upper().replace(".", "") or "File",
            "rel_path": p.name,
            "created": created,
            "indent": 0,
            "connector": "",
            "level": 0,
            "is_dir": is_dir,
            "full_path": str(p),
            "is_hidden": p.name.startswith("."),
        }

    def _apply_local_restore(self, restored_rows: list[dict[str, Any]]) -> None:
        if not restored_rows or not self._path:
            return
        
        paths = [r["full_path"] for r in restored_rows if r and r.get("full_path")]
        self._mark_self_modified(paths)
        
        self._model.beginResetModel()
        for r in restored_rows:
            if r and not any(existing.get("full_path") == r.get("full_path") for existing in self._model._all_rows):
                self._model._all_rows.append(r)
        self._model._rows = self._model._compute_filtered()
        self._model.endResetModel()
        
        folders_delta = sum(1 for r in restored_rows if r and r.get("is_dir"))
        files_delta = sum(1 for r in restored_rows if r and not r.get("is_dir"))
        size_delta = sum(int(r.get("size") or 0) for r in restored_rows if r)
        
        new_size = int(self._total_size_bytes) + size_delta
        self._total_size_bytes = new_size
        self._totals = {
            "folders": int(self._totals.get("folders", 0)) + folders_delta,
            "files":   int(self._totals.get("files",   0)) + files_delta,
            "size":    0,
            "size_text": humanize.naturalsize(new_size, binary=True) if hasattr(humanize, 'naturalsize') else f"{new_size} B",
        }
        self.totalsChanged.emit()
        self._analytics_cache = None
        
        self._resort_current_rows()
        if self._search_text:
            self._set_search_text(self._search_text)
            
        self._patch_current_cache()

    def _mark_self_modified(self, paths: list[str]) -> None:
        import time as _time
        now = _time.time()
        for p in paths:
            if not p:
                continue
            self._self_modified_paths[p] = now
            parent = os.path.dirname(p)
            if parent:
                self._self_modified_paths[parent] = now

    def _is_self_modified(self, path: str) -> bool:
        import time as _time
        now = _time.time()
        self._self_modified_paths = {
            k: v for k, v in self._self_modified_paths.items() if now - v < 2.0
        }
        if not path:
            return False
        for marked in self._self_modified_paths:
            if path == marked:
                return True
            if path.startswith(marked + os.sep) or path.startswith(marked + "/"):
                return True
            if marked.startswith(path + os.sep) or marked.startswith(path + "/"):
                return True
        return False

    def _on_watcher_event(self, path: str) -> None:
        if self._is_self_modified(path):
            return
        if self._extracting:
            return
        if self._delete_busy:
            return
        if self._paste_busy:
            return
        if not self._watcher_pending and not self._busy:
            self._watcher_pending = True
            self._watcher_debounce.start(500)

    def _do_watched_refresh(self) -> None:
        self._watcher_pending = False
        if self._path and not self._busy:
            self.messagePosted.emit("Directory changed, refreshing…", "info")
            self._refresh_current_directory()

    def _update_watcher_path(self, new_path: str) -> None:
        files = self._watcher.files()
        dirs = self._watcher.directories()
        if files:
            self._watcher.removePaths(files)
        if dirs:
            self._watcher.removePaths(dirs)
        if new_path:
            p = Path(new_path)
            if p.is_dir():
                self._watcher.addPath(str(p))

    def _apply_watcher_path(self) -> None:
        if self._path:
            self._update_watcher_path(self._path)

    @Property("QVariantMap", notify=scanProgressChanged)
    def scanProgress(self) -> dict:
        return getattr(self, "_scan_progress_dict", {"folders": 0, "files": 0, "current": "", "total": 0, "elapsed": 0.0, "rate": 0})

    @Property(QObject, constant=True)
    def model(self) -> QObject:
        return self._model

    @Property(str, notify=pathChanged)
    def path(self) -> str:
        return self._path

    @path.setter
    def path(self, value: str) -> None:
        if value == self._path:
            return
        self._path = value
        self.forceRecursive = False
        self._watcher_update_timer.start()
        self.pathChanged.emit()

    @Property(bool, notify=forceRecursiveChanged)
    def forceRecursive(self) -> bool:
        return self._force_recursive

    @forceRecursive.setter
    def forceRecursive(self, value: bool) -> None:
        if self._force_recursive != value:
            self._force_recursive = value
            self.forceRecursiveChanged.emit()

    @Property(bool, notify=historyChanged)
    def canGoBack(self) -> bool:
        return self._history_index > 0

    @Property(bool, notify=historyChanged)
    def canGoForward(self) -> bool:
        return 0 <= self._history_index < len(self._history) - 1

    @Property(bool, notify=busyChanged)
    def busy(self) -> bool:
        return self._busy

    @Property(bool, notify=pasteBusyChanged)
    def pasteBusy(self) -> bool:
        return self._paste_busy

    @Property("QVariantMap", notify=pasteProgressChanged)
    def pasteProgress(self) -> dict:
        idx, total, f_done, f_total, o_done, o_total, name, speed = self._paste_progress
        pct_file = round((f_done / f_total) * 100) if f_total > 0 else 0
        pct_overall = round((o_done / o_total) * 100) if o_total > 0 else 0
        return {
            "currentFileIndex": idx,
            "totalFiles": total,
            "fileBytesDone": f_done,
            "fileBytesTotal": f_total,
            "overallBytesDone": o_done,
            "overallBytesTotal": o_total,
            "currentFileName": name,
            "filePercent": pct_file,
            "overallPercent": pct_overall,
            "fileBytesDoneText": format_size(int(f_done)),
            "fileBytesTotalText": format_size(int(f_total)),
            "overallBytesDoneText": format_size(int(o_done)),
            "overallBytesTotalText": format_size(int(o_total)),
            "speedBytesPerSec": speed,
            "speedText": (f"{speed/1024/1024:.2f} MB/s" if speed > 0 else "")
        }

    @Property(bool, notify=cancelingChanged)
    def canceling(self) -> bool:
        return self._canceling

    @Property(str, notify=statusChanged)
    def status(self) -> str:
        return self._status

    @Property("QVariantMap", notify=totalsChanged)
    def totals(self) -> dict:
        return self._totals

    @Property("QVariantMap", notify=pathChanged)
    def directCounts(self) -> dict:
        if not self._path:
            return {"folders": 0, "files": 0}
        try:
            folders = files = 0
            with os.scandir(self._path) as it:
                for entry in it:
                    try:
                        if entry.is_dir():
                            folders += 1
                        else:
                            files += 1
                    except OSError:
                        pass
            return {"folders": folders, "files": files}
        except OSError:
            return {"folders": 0, "files": 0}

    @Property("QVariantMap", notify=filtersChanged)
    def filters(self) -> dict:
        return self._filters_for_qml()

    @Property("QVariantList", notify=bookmarksChanged)
    def bookmarks(self) -> list:
        return list(self._bookmarks)

    @staticmethod
    def _enumerate_drives() -> list[str]:
        drives: list[str] = []
        if os.name == "nt":
            import string
            for letter in string.ascii_uppercase:
                drive = f"{letter}:\\"
                if os.path.exists(drive):
                    drives.append(drive)
        else:
            drives.append("/")
        return drives

    @Property("QVariantList", notify=availableDrivesChanged)
    def availableDrives(self) -> list[str]:
        return list(self._available_drives)

    def _poll_drives(self) -> None:
        current = self._enumerate_drives()
        if current != self._available_drives:
            self._available_drives = current
            self.availableDrivesChanged.emit()

    def _get_search_text(self) -> str:
        return self._search_text

    def _set_search_text(self, value: str) -> None:
        text = value or ""
        if text == self._search_text:
            return
        if getattr(self, "_preserve_search_on_scan", False) and text == "" and self._search_text != "":
            return
        was_searching = bool(self._search_text)
        self._search_text = text
        self._model.set_search_text(text)
        self.searchTextChanged.emit()
        is_searching = bool(text)
        if is_searching != was_searching and self._path:
            if is_searching:
                self._search_restore_recursive = self._force_recursive
                self._force_recursive = True
                self.forceRecursiveChanged.emit()
                self.scan()
            else:
                if hasattr(self, "_search_restore_recursive"):
                    self._force_recursive = self._search_restore_recursive
                    del self._search_restore_recursive
                else:
                    self._force_recursive = False
                self.forceRecursiveChanged.emit()
                self.scan()

    searchText = Property(str, _get_search_text, _set_search_text, notify=searchTextChanged)

    @Slot()
    def clearSearch(self) -> None:
        self._set_search_text("")

    @Slot()
    def clearResults(self) -> None:
        self._cancel_background_folder_sizes()
        self._path = ""
        self._model.reset_rows([])
        self.pathChanged.emit()
        self._totals = {"folders": 0, "files": 0, "size": 0, "size_text": ""}
        self.totalsChanged.emit()
        self._set_status("")

    @Property(str, constant=True)
    def archiveApp(self) -> str:
        return self._archive_app

    @Slot(str)
    def setArchiveApp(self, app: str) -> None:
        if app in ["7z", "winrar", "winzip"]:
            self._archive_app = app
            self._save_settings()
            self.messagePosted.emit(f"Archive app set to {app}", "success")

    @Property(str, notify=viewModeChanged)
    def viewMode(self) -> str:
        return self._view_mode

    @viewMode.setter
    def viewMode(self, value: str) -> None:
        if value not in ("list", "tree", "grid", "analytics") or value == self._view_mode:
            return
        self._view_mode = value
        self.viewModeChanged.emit()

    @staticmethod
    def _default_filters() -> dict:
        return {
            "filter_type": "all",
            "min_size": 0,
            "max_size": 0,
            "extensions": [],
            "exclude_extensions": [],
            "keywords": [],
            "exclude_keywords": [],
            "sort_by": "none",
            "sort_dir": "asc",
            "min_date": "",
            "max_date": "",
        }

    def _filters_for_qml(self) -> dict:
        f = dict(self._filters)
        f["min_size_text"] = format_size(f["min_size"]) if f["min_size"] else ""
        f["max_size_text"] = format_size(f["max_size"]) if f["max_size"] else ""
        return f

    @staticmethod
    def _load_settings() -> dict:
        settings_file = Path(__file__).parent / ".settings.json"
        try:
            if settings_file.exists():
                return json.loads(settings_file.read_text(encoding="utf-8"))
        except Exception:
            pass
        return {}

    def _save_settings(self) -> None:
        settings_file = Path(__file__).parent / ".settings.json"
        try:
            settings = {"archive_app": self._archive_app}
            settings_file.write_text(json.dumps(settings, indent=2), encoding="utf-8")
        except Exception as e:
            self.messagePosted.emit(f"Cannot save settings: {e}", "error")

    @staticmethod
    def _load_bookmarks() -> list[str]:
        try:
            if _BOOKMARKS_FILE.exists():
                return json.loads(_BOOKMARKS_FILE.read_text(encoding="utf-8"))
        except Exception:
            pass
        return []

    def _save_bookmarks(self) -> None:
        try:
            _BOOKMARKS_FILE.write_text(json.dumps(self._bookmarks, indent=2), encoding="utf-8")
        except Exception:
            pass

    def _save_memory_cache(self, path: str, rows: list, folders: int, files: int, size_text: str, size_bytes: int) -> None:
        if not path:
            return
        try:
            path_key = os.path.normpath(path).lower()
            self._memory_path_cache[path_key] = {
                "rows": list(rows),
                "folders": folders,
                "files": files,
                "size_text": size_text,
                "size_bytes": size_bytes,
                "view_mode": self._view_mode,
            }
            if len(self._memory_path_cache) > 50:
                oldest_key = next(iter(self._memory_path_cache))
                self._memory_path_cache.pop(oldest_key, None)
        except Exception as e:
            pass

    def _get_memory_cache(self, path: str) -> dict | None:
        if not path:
            return None
        try:
            path_key = os.path.normpath(path).lower()
            item = self._memory_path_cache.get(path_key)
            if item:
                if item.get("view_mode") == self._view_mode:
                    return item
                else:
                    pass
            else:
                pass
        except Exception as e:
            pass
        return None

    @staticmethod
    def _load_scan_index() -> dict[str, float]:
        try:
            if _SCAN_INDEX_FILE.exists():
                data = json.loads(_SCAN_INDEX_FILE.read_text(encoding="utf-8"))
                if isinstance(data, dict):
                    return {k: float(v) for k, v in data.items()}
        except Exception:
            pass
        return {}

    def _save_scan_index(self) -> None:
        try:
            _SCAN_CACHE_DIR.mkdir(parents=True, exist_ok=True)
            _SCAN_INDEX_FILE.write_text(json.dumps(self._scan_index, indent=2), encoding="utf-8")
        except Exception:
            pass

    def _load_scan_shard(self, key: str) -> tuple[list, int, int, str, int] | None:
        try:
            shard = _SCAN_CACHE_DIR / f"{key}.json"
            if shard.exists():
                data = json.loads(shard.read_text(encoding="utf-8"))
                rows       = data["rows"]
                folders    = data["folders"]
                files      = data["files"]
                size_text  = data["size_text"]
                size_bytes = int(data.get("size_bytes", 0))
                return rows, folders, files, size_text, size_bytes
        except Exception:
            pass
        return None

    def _save_scan_shard(self, key: str, rows: list, folders: int, files: int, size_text: str, size_bytes: int = 0) -> None:
        try:
            _SCAN_CACHE_DIR.mkdir(parents=True, exist_ok=True)
            shard = _SCAN_CACHE_DIR / f"{key}.json"
            shard.write_text(json.dumps({"rows": rows, "folders": folders, "files": files, "size_text": size_text, "size_bytes": int(size_bytes)}, indent=2), encoding="utf-8")
        except Exception:
            pass

    def _evict_scan_lru(self) -> None:
        if len(self._scan_index) <= _SCAN_CACHE_MAX:
            return
        oldest = sorted(self._scan_index.items(), key=lambda x: x[1])
        to_remove = oldest[:len(self._scan_index) - _SCAN_CACHE_MAX]
        for key, _ in to_remove:
            try:
                shard = _SCAN_CACHE_DIR / f"{key}.json"
                if shard.exists():
                    shard.unlink()
            except Exception:
                pass
            del self._scan_index[key]

    def _cache_key(self, path: str, mode: str, filters: dict) -> str:
        f = dict(filters)
        f.pop("sort_by", None)
        f.pop("sort_dir", None)
        fhash = hashlib.md5(json.dumps(f, sort_keys=True).encode()).hexdigest()[:12]
        recursive = "1" if self._force_recursive else "0"
        payload = f"{path}|{mode}|{fhash}|r{recursive}"
        return hashlib.md5(payload.encode()).hexdigest()[:16]

    def _dir_mtime(self, path: str) -> float:
        try:
            return Path(path).stat().st_mtime
        except OSError:
            return 0.0

    def _find_ancestor_recursive_cache(self, path: str) -> str | None:
        norm = os.path.normpath(path).lower()
        best = None
        best_len = 0
        for cache_key in self._scan_index:
            if "|r1" not in cache_key:
                continue
            parts = cache_key.split("|")
            if len(parts) < 2:
                continue
            cached_path = parts[0]
            cached_norm = os.path.normpath(cached_path).lower()
            if norm.startswith(cached_norm) and len(cached_norm) > best_len:
                best = cache_key
                best_len = len(cached_norm)
        return best


    @Slot(str)
    def toggleBookmark(self, path: str) -> None:
        self.toggleBookmarks([path])

    @Slot("QVariantList")
    def toggleBookmarks(self, paths: list) -> None:
        if not paths:
            return
        changed = False
        for path in paths:
            if not path:
                continue
            if path in self._bookmarks:
                self._bookmarks.remove(path)
                changed = True
            else:
                self._bookmarks.append(path)
                changed = True
        if changed:
            self._save_bookmarks()
            self.bookmarksChanged.emit()

    @Slot(str, result=bool)
    def isBookmarked(self, path: str) -> bool:
        if not path:
            return False
        return path in self._bookmarks

    @Slot(str)
    def navigateBookmark(self, path: str) -> None:
        if not path:
            return
        try:
            p = Path(path)
            if p.is_file():
                path = str(p.parent)
        except Exception:
            pass
        self.navigate(path)

    @Slot(str, result=str)
    def extColour(self, name: str) -> str:
        return ext_colour(name)

    @Slot(str, result=str)
    def extIcon(self, name: str) -> str:
        return ext_icon(name)

    def _set_status(self, message: str) -> None:
        self._status = message
        self.statusChanged.emit()

    def _set_busy(self, busy: bool) -> None:
        if busy != self._busy:
            self._busy = busy
            self.busyChanged.emit()
            if not busy:
                self._scan_paused = False
                self.scanPausedChanged.emit()

    scanPausedChanged = Signal()

    @Property(bool, notify=scanPausedChanged)
    def scanPaused(self) -> bool:
        return self._scan_paused if hasattr(self, "_scan_paused") else False

    @Slot()
    def cancelScan(self) -> None:
        if self._worker is not None:
            self._canceling = True
            self.cancelingChanged.emit()
            self._worker.cancel()
            self._set_status("canceling...")
            self.messagePosted.emit("canceling...", "info")

    @Slot()
    def cancelPaste(self) -> None:
        if self._paste_worker is not None:
            self._paste_worker.cancel()
            self._set_status("Canceling paste...")
            self.messagePosted.emit("Canceling paste...", "info")

    @Slot()
    def pauseScan(self) -> None:
        if self._worker is not None and self._busy:
            self._worker.pause()
            self._scan_paused = True
            self.scanPausedChanged.emit()
            self._set_status("Scan paused")

    @Slot()
    def resumeScan(self) -> None:
        if self._worker is not None:
            self._worker.resume()
            self._scan_paused = False
            self.scanPausedChanged.emit()
            self._set_status(f"Scanning {self._path} ({self._view_mode})…")

    @Slot()
    def togglePauseScan(self) -> None:
        if self._scan_paused:
            self.resumeScan()
        else:
            self.pauseScan()

    def _push_history(self, value: str) -> None:
        if not value:
            return
        if self._history_index >= 0 and self._history[self._history_index] == value:
            return
        self._history = self._history[: self._history_index + 1]
        self._history.append(value)
        self._history_index = len(self._history) - 1
        self.historyChanged.emit()

    @staticmethod
    def _is_drive_root(p: Path) -> bool:
        parts = p.parts
        if len(parts) == 1:
            return True
        if len(parts) == 2 and parts[1] == "\\":
            return True
        resolved = str(p)
        if len(resolved) <= 3 and resolved[1:3] in (":\\", ":/"):
            return True
        return False

    @Slot(str, result=bool)
    def isDriveRoot(self, path: str) -> bool:
        if not path:
            return False
        try:
            return self._is_drive_root(Path(path))
        except Exception:
            return False

    @Slot(str, result=bool)
    def newFolder(self, name: str) -> bool:
        if not self._path:
            self.messagePosted.emit("No directory selected.", "warn")
            return False
        try:
            target_name = name.strip()
            target = Path(self._path) / target_name
            if target.exists():
                self.messagePosted.emit(f"Folder already exists: {name}", "error")
                return False
            shell_bridge.new_folder(self._path, target_name)
            self.messagePosted.emit(f"Created folder: {target_name}", "success")
            self._refresh_current_directory()
            return True
        except Exception as exc:
            self.messagePosted.emit(f"Could not create folder: {exc}", "error")
        return False

    @staticmethod
    def _suggest_rename(dst: "Path") -> "Path":
        stem, suffix, parent = dst.stem, dst.suffix, dst.parent
        counter = 1
        while True:
            candidate = parent / f"{stem} ({counter}){suffix}"
            if not candidate.exists():
                return candidate
            counter += 1

    @Slot(str, str, result=bool)
    def renameItem(self, old_name: str, new_name: str) -> bool:
        if not self._path:
            return False
        try:
            src = Path(self._path) / old_name.strip()
            dst = Path(self._path) / new_name.strip()
            if not src.exists():
                self.messagePosted.emit(f"Item not found: {old_name}", "error")
                return False
            if dst.exists():
                suggested = self._suggest_rename(dst)
                self.renameConflictDetected.emit(old_name, new_name, suggested.name)
                return False
            shell_bridge.rename_file(str(src), new_name.strip())
            self.messagePosted.emit(f"Renamed to {dst.name}", "success")
            self._apply_local_rename(str(src), str(dst))
            return True
        except Exception as exc:
            self.messagePosted.emit(f"Rename failed: {exc}", "error")
            return False

    @Slot(str, str, str)
    def resolveRenameConflict(self, old_name: str, new_name: str, action: str) -> None:
        if action == "skip" or not self._path:
            return
        try:
            src = Path(self._path) / old_name.strip()
            target = Path(self._path) / new_name.strip()
            if not src.exists():
                self.messagePosted.emit(f"Item not found: {old_name}", "error")
                return
            if action == "keepboth":
                dst = target if not target.exists() else self._suggest_rename(target)
                src.rename(dst)
                self.messagePosted.emit(f"Renamed to {dst.name}", "success")
                self._apply_local_rename(str(src), str(dst))
            elif action.startswith("renameold:"):
                new_existing_name = action[len("renameold:"):].strip()
                if not new_existing_name:
                    return
                existing_dst = Path(self._path) / new_existing_name
                if existing_dst.exists() and existing_dst != target:
                    self.messagePosted.emit(f"Name already taken: {new_existing_name}", "error")
                    return
                target.rename(existing_dst)
                self._apply_local_rename(str(target), str(existing_dst))
                src.rename(target)
                self._apply_local_rename(str(src), str(target))
                self.messagePosted.emit(f"Renamed '{target.name}' → '{existing_dst.name}', then '{src.name}' → '{target.name}'", "success")
        except Exception as exc:
            self.messagePosted.emit(f"Rename failed: {exc}", "error")

    @Slot(str, str, result=int)
    def nextBulkRenameStart(self, mode: str, dec_first: str) -> int:
        if not self._path:
            return 1
        import re as _re
        folder = Path(self._path)
        max_n = 0
        if mode == "normal":
            pat = _re.compile(r'^(\d+)(\.[^.]+)?$', _re.IGNORECASE)
            for p in folder.iterdir():
                m = pat.match(p.name)
                if m:
                    max_n = max(max_n, int(m.group(1)))
        elif mode == "decimal":
            first = dec_first.strip() or "1"
            pat = _re.compile(r'^' + _re.escape(first) + r'\.(\d+)(\.[^.]+)?$', _re.IGNORECASE)
            for p in folder.iterdir():
                m = pat.match(p.name)
                if m:
                    max_n = max(max_n, int(m.group(1)))
        return max_n + 1

    @Slot("QVariantList")
    def bulkRename(self, pairs: list) -> None:
        if not self._path or not pairs:
            return
        ok = 0
        skipped = 0
        for pair in pairs:
            old_name = (pair.get("from") or "").strip()
            new_name = (pair.get("to") or "").strip()
            if not old_name or not new_name or old_name == new_name:
                continue
            try:
                src = Path(self._path) / old_name
                if not src.exists():
                    skipped += 1
                    continue
                dst = Path(self._path) / new_name
                if dst.exists():
                    dst = self._suggest_rename(dst)
                src.rename(dst)
                self._apply_local_rename(str(src), str(dst))
                ok += 1
            except Exception as exc:
                self.messagePosted.emit(f"Could not rename '{old_name}': {exc}", "error")
                skipped += 1
        if ok:
            msg = f"Renamed {ok} item{'s' if ok != 1 else ''}"
            if skipped:
                msg += f", {skipped} skipped"
            self.messagePosted.emit(msg, "success")

    @Slot(str, result=str)
    def readTextFile(self, path: str) -> str:
        try:
            p = Path(path)
            if not p.is_file():
                return ""
            ext = p.suffix.lower()
            binary_exts = {".exe", ".dll", ".bin", ".dat", ".db", ".sqlite", ".zip", ".rar", ".7z", ".tar", ".gz"}
            if ext in binary_exts:
                return "[Binary file - preview not available]"
            try:
                with open(p, "r", encoding="utf-8", errors="replace") as f:
                    return f.read(51200)
            except UnicodeDecodeError:
                with open(p, "rb") as f:
                    raw = f.read(51200)
                    if b"\x00" in raw[:1024]:
                        return "[Binary file - preview not available]"
                    return raw.decode("utf-8", errors="replace")
        except Exception as exc:
            return f"[Error reading file: {exc}]"

    @Slot(str, result="QVariantMap")
    def itemProperties(self, name: str) -> dict:
        if not self._path:
            return {}
        p = Path(self._path) / name
        if not p.exists():
            return {}
        try:
            st = p.stat()
            is_dir = p.is_dir()
            res: dict = {
                "name": p.name,
                "path": str(p),
                "size": st.st_size if not is_dir else folder_size(p),
                "size_text": format_size(st.st_size if not is_dir else folder_size(p)),
                "created": format_time(st.st_ctime),
                "modified": format_time(st.st_mtime),
                "is_dir": is_dir,
            }
            ext = p.suffix.lower()
            if ext in {".jpg", ".jpeg", ".png", ".bmp", ".gif", ".webp", ".tiff", ".tif"}:
                try:
                    from PIL import Image
                    with Image.open(p) as img:
                        res["image_width"], res["image_height"] = img.size
                        res["image_dims"] = f"{img.size[0]}×{img.size[1]}"
                except Exception:
                    pass
            if ext in {".exe", ".dll"}:
                try:
                    import win32api
                    info = win32api.GetFileVersionInfo(str(p), "\\")
                    ms = info["FileVersionMS"]
                    ls = info["FileVersionLS"]
                    version = f"{win32api.HIWORD(ms)}.{win32api.LOWORD(ms)}.{win32api.HIWORD(ls)}.{win32api.LOWORD(ls)}"
                    res["exe_version"] = version
                except Exception:
                    pass
            if not is_dir and st.st_size < 100_000_000:
                try:
                    import hashlib
                    h_md5 = hashlib.md5()
                    h_sha = hashlib.sha256()
                    with open(p, "rb") as f:
                        while chunk := f.read(65536):
                            h_md5.update(chunk)
                            h_sha.update(chunk)
                    res["md5"] = h_md5.hexdigest()
                    res["sha256"] = h_sha.hexdigest()
                except Exception:
                    pass
            return res
        except Exception:
            return {}

    @staticmethod
    def _resolve_shortcut(name: str) -> str | None:
        key = name.strip().lower().lstrip("$").lstrip(":")
        if not key:
            return None
        home = Path.home()
        home_aliases: dict[str, str] = {
            "home": "", "~": "", "user": "", "userprofile": "",
            "desktop": "Desktop",
            "documents": "Documents", "docs": "Documents", "doc": "Documents",
            "downloads": "Downloads", "download": "Downloads", "dl": "Downloads",
            "pictures": "Pictures", "pics": "Pictures", "images": "Pictures",
            "music": "Music",
            "videos": "Videos", "movies": "Videos",
            "onedrive": "OneDrive",
            "favorites": "Favorites",
        }
        if key in home_aliases:
            sub = home_aliases[key]
            return str(home / sub) if sub else str(home)
        env_aliases: dict[str, list[str]] = {
            "appdata": ["APPDATA"],
            "localappdata": ["LOCALAPPDATA"],
            "programfiles": ["ProgramFiles"],
            "programfilesx86": ["ProgramFiles(x86)"],
            "programdata": ["ProgramData"],
            "temp": ["TEMP", "TMP"],
            "tmp": ["TMP", "TEMP"],
            "windir": ["WINDIR", "SystemRoot"],
            "windows": ["WINDIR", "SystemRoot"],
            "system32": ["SystemRoot"],
            "public": ["PUBLIC"],
        }
        if key in env_aliases:
            for var in env_aliases[key]:
                v = os.environ.get(var)
                if v:
                    p = Path(v)
                    if key == "system32" and p.name.lower() != "system32":
                        p = p / "System32"
                    return str(p)
        if len(key) <= 2 and key.endswith(":"):
            letter = key[0]
            if letter.isalpha():
                return f"{letter.upper()}:\\"
        if len(key) == 1 and key.isalpha() and os.name == "nt":
            return f"{key.upper()}:\\"
        return None

    def _navigate_to_path(self, path: str) -> None:
        import time
        start_time = time.monotonic()
        cached = self._get_memory_cache(path)
        if cached is not None:
            self._cancel_background_folder_sizes()
            if self._busy:
                self._abort_scan()
            self.path = path
            
            def apply_cached_rows():
                if self.path == path:
                    self._model.reset_rows(cached["rows"])
                    self._total_size_bytes = cached["size_bytes"]
                    self._totals = {
                        "folders": cached["folders"],
                        "files": cached["files"],
                        "size": 0,
                        "size_text": cached["size_text"],
                    }
                    self.totalsChanged.emit()
                    self._set_status(f"{cached['folders']} folders · {cached['files']} files · {cached['size_text']} (cached)")
                    self._resort_current_rows()
                    search_to_apply = getattr(self, '_pending_search_restore', '') or self._search_text
                    if search_to_apply:
                        self._set_search_text(search_to_apply)
                        self._pending_search_restore = ''
                    self._start_background_folder_sizes(path, cached["rows"], self._view_mode, "", 0.0, cached["folders"], cached["files"], cached["size_bytes"])

            QTimer.singleShot(50, apply_cached_rows)
            return

        self.path = path
        self._set_status(f"Loaded {self.path}")
        self.scan()

    @Slot(str)
    def navigate(self, raw_path: str) -> None:
        path = (raw_path or "").strip().strip('"')
        if not path:
            self.messagePosted.emit("Please enter a path.", "warn")
            return
        if "\\" not in path and "/" not in path and ":" not in path[1:]:
            shortcut = self._resolve_shortcut(path)
            if shortcut:
                path = shortcut
        p = Path(path).expanduser()
        if not p.exists():
            self.messagePosted.emit(f"Path does not exist: {p}", "error")
            return
        if not p.is_dir():
            self.messagePosted.emit(f"Not a directory: {p}", "error")
            return
        dest_path = str(p)
        self._push_history(dest_path)
        self._navigate_to_path(dest_path)

    @Slot()
    def goBack(self) -> None:
        if self.canGoBack:
            self._history_index -= 1
            dest_path = self._history[self._history_index]
            self.historyChanged.emit()
            self._navigate_to_path(dest_path)

    @Slot()
    def goForward(self) -> None:
        if self.canGoForward:
            self._history_index += 1
            dest_path = self._history[self._history_index]
            self.historyChanged.emit()
            self._navigate_to_path(dest_path)

    @Slot()
    def goUp(self) -> None:
        if not self._path:
            return
        parent = Path(self._path).parent
        if str(parent) and parent.exists() and str(parent) != self._path:
            self.navigate(str(parent))

    @Slot()
    def reload(self) -> None:
        if self._path:
            try:
                path_key = os.path.normpath(self._path).lower()
                self._memory_path_cache.pop(path_key, None)
            except Exception:
                pass
            
            try:
                filters = dict(self._filters)
                key = self._cache_key(self._path, self._view_mode, filters)
                self._scan_index.pop(key, None)
                self._save_scan_index()
            except Exception:
                pass
                
            self._pending_search_restore = self._search_text
            self.scan()

    @Property(bool, notify=expandBusyChanged)
    def expandBusy(self) -> bool:
        return self._expand_busy

    def _set_expand_busy(self, busy: bool) -> None:
        if busy != self._expand_busy:
            self._expand_busy = busy
            self.expandBusyChanged.emit()

    @Slot(str)
    def expandFolder(self, full_path: str) -> None:
        if not full_path or self._expand_busy:
            return
        p = Path(full_path)
        if not p.is_dir():
            return
        parent_row = self._model.row_for_full_path(full_path)
        if not parent_row:
            return
        parent_level = parent_row.get("level", 0) or 0

        self._set_expand_busy(True)
        self._set_status(f"Expanding {p.name}…")

        thread = QThread(self)
        worker = ExpandWorker(full_path, parent_level, dict(self._filters))
        worker.moveToThread(thread)
        thread.started.connect(worker.run)
        worker.finished.connect(self._on_expand_finished)
        worker.finished.connect(thread.quit)
        thread.finished.connect(worker.deleteLater)
        thread.finished.connect(thread.deleteLater)
        self._expand_thread = thread
        self._expand_worker = worker
        thread.start()

    def _on_expand_finished(self, full_path: str, rows: list) -> None:
        self._expand_thread = None
        self._expand_worker = None
        if rows:
            self._model.expand_after(full_path, rows)
        self._set_expand_busy(False)
        self._set_status("Ready")
        self.expandFinished.emit(full_path, len(rows))

    @Slot(str, result=int)
    def collapseFolder(self, full_path: str) -> int:
        if not full_path:
            return 0
        return self._model.collapse_descendants(full_path)

    @Slot(str)
    def openItem(self, full_path: str) -> None:
        if not full_path:
            return
        p = Path(full_path)
        if p.is_dir():
            self.navigate(str(p))
        elif p.is_file():
            try:
                os.startfile(str(p))
            except Exception as e:
                self.messagePosted.emit(
                    "Blocked by Windows SmartScreen/permissions. Open manually via Explorer (Right-click -> Reveal).",
                    "error"
                )

    @Slot(str, "QVariantList")
    def launchExternalApp(self, exe_path: str, paths: list) -> None:
        if not exe_path:
            return
        import subprocess
        exe = Path(exe_path)
        if not exe.exists():
            self.messagePosted.emit(f"App not found: {exe.name}", "error")
            return
        try:
            args = [str(exe)] + [str(p) for p in paths if p]
            subprocess.Popen(args, cwd=str(exe.parent))
            self.messagePosted.emit(f"Opening {len(paths)} folder(s) in {exe.stem}...", "success")
        except Exception as e:
            self.messagePosted.emit(f"Could not launch {exe.name}: {e}", "error")

    @Slot(str, str, result=str)
    def siblingAppPath(self, app_folder: str, exe_name: str) -> str:
        if getattr(sys, 'frozen', False):
            app_dir = Path(sys.executable).parent
        else:
            app_dir = Path(__file__).parent
        sibling_exe = app_dir.parent / app_folder / exe_name
        return str(sibling_exe)

    @Slot(str, result=str)
    def adjacentAppPath(self, exe_name: str) -> str:
        if getattr(sys, 'frozen', False):
            app_dir = Path(sys.executable).parent
        else:
            app_dir = Path(__file__).parent
        return str(app_dir / exe_name)

    @Slot(str)
    def revealInExplorer(self, full_path: str) -> None:
        if not full_path:
            return
        import subprocess
        p = Path(full_path)
        try:
            if p.is_dir():
                subprocess.Popen(["explorer", str(p)])
            else:
                subprocess.Popen(["explorer", "/select,", str(p)])
        except Exception as e:
            self.messagePosted.emit(f"Cannot open Explorer: {e}", "error")

    @Slot(str)
    def openTerminal(self, full_path: str) -> None:
        if not full_path:
            return
        import subprocess
        p = Path(full_path)
        if not p.exists():
            self.messagePosted.emit(f"Path does not exist: {full_path}", "error")
            return
        try:
            target_dir = str(p) if p.is_dir() else str(p.parent)
            wt_path = Path(os.environ.get("LOCALAPPDATA", "")) / "Microsoft" / "WindowsApps" / "wt.exe"
            if wt_path.exists():
                subprocess.Popen([str(wt_path), "-d", target_dir])
            else:
                subprocess.Popen(["cmd.exe", "/c", "start", "cmd.exe"], cwd=target_dir, shell=True)
            self.messagePosted.emit(f"Terminal opened at: {target_dir}", "success")
        except Exception as e:
            self.messagePosted.emit(f"Cannot open terminal: {e}", "error")

    @Slot(str)
    def copyToClipboard(self, text: str) -> None:
        if not text:
            return
        app = QGuiApplication.instance()
        if app:
            app.clipboard().setText(text)
            self.messagePosted.emit("Path copied to clipboard", "info")

    @Slot(str, result="QVariantList")
    def getSiblings(self, full_path: str) -> list:
        if not full_path:
            return []
        try:
            p = Path(full_path)
            parent_str = str(p.parent)
            siblings: list[str] = []
            for r in self._model.rows():
                fp = r.get("full_path") or ""
                if not fp:
                    continue
                if r.get("is_dir"):
                    continue
                if str(Path(fp).parent) == parent_str:
                    siblings.append(r.get("name") or Path(fp).name)
            if siblings:
                if p.name not in siblings:
                    def nk(s: str):
                        return [int(t) if t.isdigit() else t.lower() for t in re.split(r"(\d+)", s)]
                    
                    is_descending = False
                    if len(siblings) >= 2:
                        is_descending = nk(siblings[0]) > nk(siblings[-1])
                    
                    inserted = False
                    for idx, name in enumerate(siblings):
                        comp = nk(p.name) < nk(name)
                        if is_descending:
                            comp = nk(p.name) > nk(name)
                        if comp:
                            siblings.insert(idx, p.name)
                            inserted = True
                            break
                    if not inserted:
                        siblings.append(p.name)
                return siblings
            if not p.parent.exists():
                return []
            disk = [f.name for f in p.parent.iterdir() if f.is_file()]
            def nk(s: str):
                return [int(t) if t.isdigit() else t.lower() for t in re.split(r"(\d+)", s)]
            return sorted(disk, key=nk)
        except Exception:
            return []

    def _get_can_undo(self) -> bool:
        return (len(self._trash) > 0
                or len(self._rename_history) > 0
                or len(self._move_history) > 0
                or len(self._copy_history) > 0)
    canUndo = Property(bool, _get_can_undo, notify=canUndoChanged)

    def _get_can_paste(self) -> bool:
        return bool(self._clipboard_path) or bool(self._clipboard_paths)
    canPaste = Property(bool, _get_can_paste, notify=clipboardChanged)

    def _get_clipboard_cut_paths(self) -> list:
        return self._clipboard_paths if self._clipboard_cut else []
    clipboardCutPaths = Property("QVariantList", _get_clipboard_cut_paths, notify=clipboardChanged)

    @Slot(result=str)
    def undoDelete(self) -> str:
        if not self._trash:
            return ""
        try:
            original_path, trash_data = self._trash.pop()
            orig = Path(original_path)
            
            row_dict = None
            if isinstance(trash_data, dict):
                row_dict = trash_data
            elif isinstance(trash_data, str) and trash_data != "":
                temp = Path(trash_data)
                if temp.exists():
                    orig.parent.mkdir(parents=True, exist_ok=True)
                    import shutil
                    shutil.move(str(temp), str(orig))
                    self.messagePosted.emit(f"Restored: {orig.name}", "info")
                    self.canUndoChanged.emit()
                    if self._is_same_folder(str(orig.parent), self._path):
                        row = self._create_row_dict_for_path(str(orig))
                        self._apply_local_restore([row])
                    return str(orig)

            import subprocess
            subprocess.run([
                "powershell", "-Command",
                f"$shell = New-Object -ComObject Shell.Application; $item = $shell.Namespace(0xA).Items() | Where-Object {{ $_.Name -eq '{orig.name}' }}; if ($item) {{ $shell.Namespace('{orig.parent}').MoveHere($item) }}"
            ], shell=True)
            self.messagePosted.emit(f"Restored from recycle bin: {orig.name}", "success")
            self.canUndoChanged.emit()
            if self._is_same_folder(str(orig.parent), self._path):
                row = row_dict if row_dict else self._create_row_dict_for_path(str(orig))
                self._apply_local_restore([row])
            return str(orig)
        except Exception as e:
            self.messagePosted.emit(f"Cannot undo: {e}", "error")
            self.canUndoChanged.emit()
            return ""

    @Slot(result=str)
    def undoRename(self) -> str:
        if not self._rename_history:
            return ""
        try:
            old_path, new_path = self._rename_history.pop()
            old = Path(old_path)
            new = Path(new_path)
            if new.exists():
                new.rename(old)
                self.messagePosted.emit(f"Undo rename: {old.name}", "info")
                self.canUndoChanged.emit()
                if self._is_same_folder(str(old.parent), self._path):
                    self._model.rename_by_full_path(new_path, old_path)
                    self._resort_current_rows()
                    if self._search_text:
                        self._set_search_text(self._search_text)
                    self._patch_current_cache()
                return str(old)
            else:
                self.messagePosted.emit("Cannot undo rename: file not found", "error")
                self.canUndoChanged.emit()
                return ""
        except Exception as e:
            self.messagePosted.emit(f"Cannot undo rename: {e}", "error")
            self.canUndoChanged.emit()
            return ""

    @Slot(result=str)
    def undoMove(self) -> str:
        if not self._move_history:
            return ""
        batch = self._move_history.pop()
        import shutil
        restored = 0
        first_orig = ""
        for orig_src, final_dest in reversed(batch):
            try:
                src_p = Path(final_dest)
                dst_p = Path(orig_src)
                if not src_p.exists():
                    continue
                dst_p.parent.mkdir(parents=True, exist_ok=True)
                if dst_p.exists():
                    continue
                try:
                    src_p.rename(dst_p)
                except OSError:
                    shutil.move(str(src_p), str(dst_p))
                if not first_orig:
                    first_orig = orig_src
                restored += 1
            except Exception as e:
                self.messagePosted.emit(f"Cannot undo move for {Path(final_dest).name}: {e}", "error")
        if restored:
            self.messagePosted.emit(
                f"Undo move: restored {restored} item{'s' if restored != 1 else ''}", "info")
        self.canUndoChanged.emit()
        if self._path:
            removed_paths = []
            added_rows = []
            for orig_src, final_dest in batch:
                if self._is_same_folder(str(Path(final_dest).parent), self._path):
                    removed_paths.append(final_dest)
                if self._is_same_folder(str(Path(orig_src).parent), self._path):
                    added_rows.append(self._create_row_dict_for_path(orig_src))
            
            if removed_paths:
                self._apply_local_delete(removed_paths)
            if added_rows:
                self._apply_local_restore(added_rows)
        return first_orig

    @Slot(result=str)
    def undoCopy(self) -> str:
        if not self._copy_history:
            return ""
        batch = self._copy_history.pop()
        removed = 0
        first_parent = ""
        for dest in reversed(batch):
            try:
                p = Path(dest)
                if not p.exists():
                    continue
                try:
                    from send2trash import send2trash
                    send2trash(str(p))
                except ImportError:
                    import shutil
                    if p.is_file():
                        p.unlink()
                    else:
                        shutil.rmtree(p)
                if not first_parent:
                    first_parent = str(p.parent)
                removed += 1
            except Exception as e:
                self.messagePosted.emit(f"Cannot undo copy for {Path(dest).name}: {e}", "error")
        if removed:
            self.messagePosted.emit(
                f"Undo copy: removed {removed} item{'s' if removed != 1 else ''}", "info")
        self.canUndoChanged.emit()
        if self._path:
            removed_paths = []
            for dest in batch:
                if self._is_same_folder(str(Path(dest).parent), self._path):
                    removed_paths.append(dest)
            if removed_paths:
                self._apply_local_delete(removed_paths)
        return first_parent

    @Slot(result=str)
    def undo(self) -> str:
        if self._rename_history:
            return self.undoRename()
        if self._move_history:
            return self.undoMove()
        if self._copy_history:
            return self.undoCopy()
        return self.undoDelete()

    @Slot()
    def undoAndNotify(self) -> None:
        path = self.undo()
        self.undoDone.emit(path)

    @Slot(str)
    def deleteFile(self, full_path: str) -> None:
        self.deleteFiles([full_path])

    @Slot("QVariantList")
    def deleteFiles(self, paths: list) -> None:
        if not paths:
            return
        if self._delete_busy:
            self.messagePosted.emit("Another delete operation is in progress.", "warn")
            return

        self._delete_threads = [t for t in self._delete_threads if t.isRunning()]

        valid_paths = [p for p in paths if p and Path(p).exists()]
        if not valid_paths:
            return

        for full_path in valid_paths:
            row_dict = self._model.row_for_full_path(full_path)
            self._trash.append((full_path, row_dict))

        self._delete_busy = True
        self.messagePosted.emit(f"Moving {len(valid_paths)} items to recycle bin...", "info")

        thread = QThread()
        worker = DeleteWorker(valid_paths)
        worker.moveToThread(thread)

        thread.started.connect(worker.run)
        worker.error.connect(
            lambda path, err: self.messagePosted.emit(
                f"'{Path(path).name}' is locked by another process — please use IObit Unlocker to release it first."
                if "-2144927711" in err or "0x80270021" in err or "2147540525" in err
                else f"Cannot delete {path}: {err}", "error"
            )
        )
        worker.finished.connect(self._on_delete_thread_done, Qt.ConnectionType.QueuedConnection)
        thread.finished.connect(thread.deleteLater)

        self._delete_threads.append(thread)
        self._delete_thread = thread
        self._delete_worker = worker
        thread.start()

    def _on_delete_thread_done(self, deleted_names: list) -> None:
        self._delete_busy = False
        if deleted_names:
            self.canUndoChanged.emit()
            if len(deleted_names) == 1:
                self.messagePosted.emit(f"Moved to recycle bin: {deleted_names[0]}", "success")
            else:
                self.messagePosted.emit(f"Moved {len(deleted_names)} items to recycle bin", "success")
            valid_paths = self._delete_worker.deleted_paths if self._delete_worker else []
            if valid_paths:
                self._apply_local_delete(valid_paths)
                self._resort_current_rows()
                if self._search_text:
                    self._set_search_text(self._search_text)

    def _on_delete_thread_finished(self) -> None:
        self._delete_thread = None
        self._delete_worker = None

    def cleanupDeleteThread(self) -> None:
        self._delete_threads = [t for t in self._delete_threads if t.isRunning()]
        for thread in self._delete_threads:
            if thread.isRunning():
                thread.terminate()
                thread.wait(500)
        self._delete_threads = []
        self._delete_thread = None
        self._delete_worker = None

    @Slot(str, result=str)
    def localPathFromUrl(self, url_str: str) -> str:
        return QUrl(url_str).toLocalFile()

    @Slot(str)
    def copyFile(self, full_path: str) -> None:
        self.copyFiles([full_path])

    @Slot("QVariantList")
    def copyFiles(self, paths: list) -> None:
        if not paths:
            return
        try:
            valid_paths = []
            for path in paths:
                if path and Path(path).exists():
                    valid_paths.append(str(Path(path).resolve()))
            if not valid_paths:
                return
            self._clipboard_paths = valid_paths
            self._clipboard_path = valid_paths[0]
            self._clipboard_cut = False
            self.clipboardChanged.emit()
            app = QGuiApplication.instance()
            if app:
                clipboard = app.clipboard()
                clipboard.setText("\n".join(valid_paths))
            if len(valid_paths) == 1:
                self.messagePosted.emit(f"Copied: {Path(valid_paths[0]).name}", "success")
            else:
                self.messagePosted.emit(f"Copied {len(valid_paths)} items", "success")
        except Exception as e:
            self.messagePosted.emit(f"Cannot copy: {e}", "error")

    @Slot(str)
    def cutFile(self, full_path: str) -> None:
        self.cutFiles([full_path])

    @Slot("QVariantList")
    def cutFiles(self, paths: list) -> None:
        if not paths:
            return
        try:
            valid_paths = []
            for path in paths:
                if path and Path(path).exists():
                    valid_paths.append(str(Path(path).resolve()))
            if not valid_paths:
                return
            self._clipboard_paths = valid_paths
            self._clipboard_path = valid_paths[0]
            self._clipboard_cut = True
            self.clipboardChanged.emit()
            app = QGuiApplication.instance()
            if app:
                clipboard = app.clipboard()
                clipboard.setText("\n".join(valid_paths))
            if len(valid_paths) == 1:
                self.messagePosted.emit(f"Cut: {Path(valid_paths[0]).name}", "success")
            else:
                self.messagePosted.emit(f"Cut {len(valid_paths)} items", "success")
        except Exception as e:
            self.messagePosted.emit(f"Cannot cut: {e}", "error")

    @Slot(str)
    def copyAndPaste(self, full_path: str) -> None:
        self.copyAndPasteMultiple([full_path])

    @Slot("QVariantList")
    def copyAndPasteMultiple(self, paths: list) -> None:
        if not paths:
            return
        if self._paste_busy:
            self.messagePosted.emit("Another paste operation is already in progress.", "warn")
            return

        target_paths: dict[str, str] = {}
        valid_paths: list[str] = []
        for full_path in paths:
            if not full_path:
                continue
            try:
                p = Path(full_path)
                if not p.exists():
                    continue
                stem, suffix = p.stem, p.suffix
                new_path = p.parent / f"{stem} - Copy{suffix}"
                counter = 1
                chosen = set(target_paths.values())
                while new_path.exists() or str(new_path) in chosen:
                    new_path = p.parent / f"{stem} - Copy ({counter}){suffix}"
                    counter += 1
                target_paths[str(p)] = str(new_path)
                valid_paths.append(str(p))
            except Exception as e:
                self.messagePosted.emit(f"Cannot duplicate {Path(full_path).name}: {e}", "error")

        if not valid_paths:
            return

        first_parent = Path(valid_paths[0]).parent

        self._paste_busy = True
        self.pasteBusyChanged.emit()
        self.pasteStarted.emit()
        self._paste_progress = (0, len(valid_paths), 0.0, 1.0, 0.0, 1.0, "", 0.0)
        self._paste_last_ts = time.time()
        self._paste_last_bytes = 0.0
        self.pasteProgressChanged.emit()
        self._set_status("Duplicating files...")

        thread = QThread()
        worker = PasteWorker(valid_paths, str(first_parent), False, {}, target_paths=target_paths)
        worker.moveToThread(thread)

        thread.started.connect(worker.run)
        worker.progress.connect(self._on_paste_progress)
        worker.finished.connect(self._on_paste_finished)
        worker.error.connect(self._on_paste_error)
        worker.finished.connect(thread.quit)
        worker.error.connect(thread.quit)
        thread.finished.connect(worker.deleteLater)
        thread.finished.connect(thread.deleteLater)
        thread.finished.connect(self._on_paste_thread_done)

        self._paste_thread = thread
        self._paste_worker = worker
        thread.start()

    def _get_file_info(self, path: Path) -> dict:
        if not path.exists():
            return {"size": "", "modified": "", "isDir": False}
        try:
            is_dir = path.is_dir()
            if is_dir:
                size_str = "Folder"
            else:
                size = path.stat().st_size
                size_str = humanize.naturalsize(size)
            mtime = path.stat().st_mtime
            modified_str = datetime.fromtimestamp(mtime).strftime("%Y-%m-%d %H:%M:%S")
            return {"size": size_str, "modified": modified_str, "isDir": is_dir}
        except Exception:
            return {"size": "Unknown", "modified": "Unknown", "isDir": path.is_dir()}

    @Slot()
    def pasteFile(self) -> None:
        if not self._clipboard_paths and self._clipboard_path:
            self._clipboard_paths = [self._clipboard_path]

        if not self._clipboard_paths:
            return
        if not self._path:
            self.messagePosted.emit("No directory selected", "error")
            return

        try:
            dest_dir = Path(self._path)
            is_cut = self._clipboard_cut

            self._pending_paste_paths = list(self._clipboard_paths)
            self._pending_paste_dest = dest_dir
            self._pending_paste_cut = is_cut
            self._pending_paste_conflicts = []
            self._pending_paste_resolutions = {}

            conflicts = []
            for path_str in self._clipboard_paths:
                src = Path(path_str)
                if not src.exists():
                    continue
                dest = dest_dir / src.name
                if dest.exists():
                    src_info = self._get_file_info(src)
                    dest_info = self._get_file_info(dest)
                    conflicts.append({
                        "name": src.name,
                        "src": str(src),
                        "dest": str(dest),
                        "srcSize": src_info["size"],
                        "srcModified": src_info["modified"],
                        "destSize": dest_info["size"],
                        "destModified": dest_info["modified"],
                        "isDir": src_info["isDir"]
                    })

            if conflicts:
                self._pending_paste_conflicts = conflicts
                self.pasteConflictsDetected.emit(conflicts)
            else:
                self._execute_paste_list(self._pending_paste_paths, {})
                self.clearPendingPaste()
        except Exception as e:
            self.messagePosted.emit(f"Cannot scan destination: {e}", "error")

    @Slot(str, str)
    def resolveConflict(self, src_path: str, action: str) -> None:
        self._pending_paste_resolutions[src_path] = action

    @Slot(str)
    def resolveAllConflicts(self, action: str) -> None:
        for c in self._pending_paste_conflicts:
            src = c["src"]
            self._pending_paste_resolutions[src] = action
        self.executePendingPaste()

    @Slot()
    def executePendingPaste(self) -> None:
        self._execute_paste_list(self._pending_paste_paths, self._pending_paste_resolutions)
        self.clearPendingPaste()

    @Slot()
    def clearPendingPaste(self) -> None:
        self._pending_paste_paths = []
        self._pending_paste_conflicts = []
        self._pending_paste_resolutions = {}
        self._pending_paste_dest = None
        self._pending_paste_cut = False

    @Slot("QVariantList", str, int)
    def handleDrop(self, urls: list, target_dir: str, action: int) -> None:
        if not target_dir:
            return
            
        is_cut = (action == 2)
        
        paths = []
        for url in urls:
            u = QUrl(url)
            if u.isLocalFile():
                p = u.toLocalFile()
                if Path(p).exists():
                    paths.append(p)
                    
        if not paths:
            return

        self._clipboard_paths = paths
        self._clipboard_cut = is_cut
        
        try:
            dest_dir = Path(target_dir)

            self._pending_paste_paths = list(self._clipboard_paths)
            self._pending_paste_dest = dest_dir
            self._pending_paste_cut = is_cut
            self._pending_paste_conflicts = []
            self._pending_paste_resolutions = {}

            conflicts = []
            for path_str in self._clipboard_paths:
                src = Path(path_str)
                if not src.exists():
                    continue
                try:
                    if dest_dir.is_relative_to(src):
                        self.messagePosted.emit(f"Cannot drop '{src.name}' into its own subfolder.", "warn")
                        continue
                except ValueError:
                    pass

                dest = dest_dir / src.name
                if dest.exists():
                    src_info = self._get_file_info(src)
                    dest_info = self._get_file_info(dest)
                    conflicts.append({
                        "name": src.name,
                        "src": str(src),
                        "dest": str(dest),
                        "srcSize": src_info["size"],
                        "srcModified": src_info["modified"],
                        "destSize": dest_info["size"],
                        "destModified": dest_info["modified"],
                        "isDir": src_info["isDir"]
                    })

            if conflicts:
                self._pending_paste_conflicts = conflicts
                self.pasteConflictsDetected.emit(conflicts)
            else:
                self._execute_paste_list(self._pending_paste_paths, {})
                self.clearPendingPaste()
        except Exception as e:
            self.messagePosted.emit(f"Drop error: {e}", "error")

    def _execute_paste_list(self, paths: list[str], resolutions: dict[str, str]) -> None:
        if self._paste_busy:
            self.messagePosted.emit("Another paste operation is already in progress.", "warn")
            return

        dest_dir = self._pending_paste_dest
        is_cut = self._pending_paste_cut

        if not dest_dir or not paths:
            return

        self._paste_busy = True
        self.pasteBusyChanged.emit()
        self.pasteStarted.emit()
        self._paste_progress = (0, len(paths), 0.0, 1.0, 0.0, 1.0, "", 0.0)
        self._paste_last_ts = time.time()
        self._paste_last_bytes = 0.0
        self.pasteProgressChanged.emit()

        self._set_status("Pasting files...")

        thread = QThread()
        worker = PasteWorker(paths, str(dest_dir), is_cut, resolutions)
        worker.moveToThread(thread)
        
        thread.started.connect(worker.run)
        worker.progress.connect(self._on_paste_progress)
        worker.finished.connect(self._on_paste_finished)
        worker.error.connect(self._on_paste_error)

        worker.finished.connect(thread.quit)
        worker.error.connect(thread.quit)

        thread.finished.connect(worker.deleteLater)
        thread.finished.connect(thread.deleteLater)
        thread.finished.connect(self._on_paste_thread_done)

        self._paste_thread = thread
        self._paste_worker = worker
        thread.start()

    def _on_paste_progress(self, idx: int, total: int, f_done: float, f_total: float, o_done: float, o_total: float, name: str) -> None:
        now = time.time()
        try:
            last_bytes = self._paste_last_bytes
            last_ts    = self._paste_last_ts
        except AttributeError:
            last_bytes = 0.0
            last_ts    = now
        speed = getattr(self, "_paste_last_speed", 0.0)
        dt = now - last_ts
        if dt > 0.3:
            calc = (o_done - last_bytes) / dt if o_done > last_bytes else 0.0
            if calc > 0:
                speed = calc
                self._paste_last_speed = speed
            self._paste_last_ts = now
            self._paste_last_bytes = o_done
        self._paste_progress = (idx, total, f_done, f_total, o_done, o_total, name, speed)
        self.pasteProgressChanged.emit()

    def _record_paste_move_history(self) -> None:
        worker = self._paste_worker
        if worker is None:
            return
        pairs = list(getattr(worker, "moved_pairs", []) or [])
        if pairs:
            self._move_history.append(pairs)
            self.canUndoChanged.emit()

    def _record_paste_copy_history(self) -> None:
        worker = self._paste_worker
        if worker is None:
            return
        dests = list(getattr(worker, "copied_dests", []) or [])
        if dests:
            self._copy_history.append(dests)
            self.canUndoChanged.emit()

    def _on_paste_finished(self, pasted_names, is_cut: bool) -> None:
        self._paste_busy = False
        names = list(pasted_names) if pasted_names else []

        if is_cut:
            self._record_paste_move_history()
        else:
            self._record_paste_copy_history()

        if names:
            verb = "Moved" if is_cut else "Pasted"
            if len(names) == 1:
                self.messagePosted.emit(f"{verb}: {names[0]}", "success")
            else:
                self.messagePosted.emit(f"{verb} {len(names)} items", "success")
            if is_cut:
                self._clipboard_paths = []
                self._clipboard_path = ""
                self._clipboard_cut = False
                self.clipboardChanged.emit()
            QTimer.singleShot(300, self.scan)
        else:
            self._set_status("Paste operation finished (nothing copied/moved)")

        self.pasteFinished.emit()
        self.pasteBusyChanged.emit()

    def _on_paste_error(self, message: str) -> None:
        self._paste_busy = False
        self._set_status("Paste error")
        self.pasteError.emit(message)
        self.pasteFinished.emit()
        self.pasteBusyChanged.emit()
        self.messagePosted.emit(f"Paste failed: {message}", "error")

    @Slot()
    def _on_paste_thread_done(self) -> None:
        self._paste_thread = None
        self._paste_worker = None

    @Slot(str)
    def selectFile(self, full_path: str) -> None:
        if not full_path:
            return
        self.fileSelected.emit(full_path)

    @Slot(str)
    def addToArchive(self, full_path: str) -> None:
        if not full_path:
            return
        try:
            p = Path(full_path)
            if not p.exists():
                self.messagePosted.emit("File not found", "error")
                return

            import os

            if self._archive_app == "winrar":
                for path in [r"C:\Program Files\WinRAR\WinRAR.exe", r"C:\Program Files (x86)\WinRAR\WinRAR.exe"]:
                    if Path(path).exists():
                        os.startfile(path)
                        self.messagePosted.emit(f"Opened WinRAR - select file and press Add to archive", "info")
                        return
                self.messagePosted.emit("WinRAR not found. Please install or select another app.", "error")
            elif self._archive_app == "7z":
                for path in [r"C:\Program Files\7-Zip\7zFM.exe", r"C:\Program Files (x86)\7-Zip\7zFM.exe"]:
                    if Path(path).exists():
                        os.startfile(path)
                        self.messagePosted.emit(f"Opened 7-Zip - select file and press Add to archive", "info")
                        return
                self.messagePosted.emit("7-Zip not found. Please install or select another app.", "error")
            elif self._archive_app == "winzip":
                for path in [r"C:\Program Files\WinZip\winzip64.exe", r"C:\Program Files\WinZip\winzip32.exe"]:
                    if Path(path).exists():
                        os.startfile(path)
                        self.messagePosted.emit(f"Opened WinZip - select file and press Add to archive", "info")
                        return
                self.messagePosted.emit("WinZip not found. Please install or select another app.", "error")
            else:
                self.messagePosted.emit(f"Unknown archive app: {self._archive_app}", "error")

        except Exception as e:
            self.messagePosted.emit(f"Cannot open archive app: {e}", "error")

    @Slot(str)
    def openWithLockHunter(self, path: str) -> None:
        import shutil, subprocess, threading
        name = Path(path).name

        lockhunter = shutil.which("LockHunter") or shutil.which("lockhunter")
        if not lockhunter:
            app_root = Path(__file__).parent
            for candidate in [
                app_root / "LockHunter" / "lockhunter.exe",
                app_root / "LockHunter" / "LockHunter.exe",
                app_root / "LockHunter" / "LockHunter64.exe",
                app_root / "LockHunter.exe",
                app_root / "LockHunter64.exe",
                r"C:\Program Files\LockHunter\LockHunter.exe",
                r"C:\Program Files (x86)\LockHunter\LockHunter.exe",
                r"C:\Program Files\LockHunter\LockHunter64.exe",
                r"C:\Program Files (x86)\LockHunter\LockHunter64.exe",
            ]:
                if Path(candidate).exists():
                    lockhunter = str(candidate)
                    break
        if not lockhunter:
            self.messagePosted.emit("LockHunter not found. Please install it from lockhunter.com.", "error")
            return

        def _run():
            try:
                import ctypes
                ctypes.windll.shell32.ShellExecuteW(None, "runas", lockhunter, f'"{path}"', None, 1)
            except Exception as e:
                self.messagePosted.emit(f"Cannot launch LockHunter: {e}", "error")

        threading.Thread(target=_run, daemon=True).start()

    @Slot(str)
    def openWithIObitUnlocker(self, path: str) -> None:
        import shutil, ctypes
        unlocker = shutil.which("IObitUnlocker") or shutil.which("iobitunlocker")
        if not unlocker:
            for candidate in [
                r"C:\Program Files (x86)\IObit\IObit Unlocker\IObitUnlocker.exe",
                r"C:\Program Files\IObit\IObit Unlocker\IObitUnlocker.exe",
            ]:
                if Path(candidate).exists():
                    unlocker = candidate
                    break
        if not unlocker:
            self.messagePosted.emit("IObit Unlocker not found. Please install it from iobit.com.", "error")
            return
        try:
            ctypes.windll.shell32.ShellExecuteW(None, "runas", unlocker, None, None, 1)
        except Exception as e:
            self.messagePosted.emit(f"Cannot launch IObit Unlocker: {e}", "error")

    @Slot(str)
    def openElevated(self, path: str) -> None:
        import ctypes
        try:
            ctypes.windll.shell32.ShellExecuteW(None, "runas", path, None, None, 1)
        except Exception as e:
            self.messagePosted.emit(f"Cannot run elevated: {e}", "error")

    @Slot(str, result=bool)
    def canRunElevated(self, path: str) -> bool:
        if not path:
            return False
        p = Path(path)
        if p.is_dir():
            return False
        ext = p.suffix.lower()
        elevated_extensions = {
            '.exe', '.bat', '.cmd', '.ps1', '.vbs', '.js', '.jar',
            '.msi', '.msc', '.reg', '.lnk'
        }
        return ext in elevated_extensions

    @Slot("QVariantList", str)
    def openWithArchiver(self, paths: list[str], app: str) -> None:
        if not paths or len(paths) == 0:
            self.messagePosted.emit("No files selected", "warn")
            return
        import subprocess
        single_file = (len(paths) == 1
                       and Path(paths[0]).exists()
                       and not Path(paths[0]).is_dir())
        try:
            if app == "7z":
                if single_file:
                    for exe_path in [r"C:\Program Files\7-Zip\7zFM.exe", r"C:\Program Files (x86)\7-Zip\7zFM.exe"]:
                        if Path(exe_path).exists():
                            parent = str(Path(paths[0]).parent)
                            subprocess.Popen([exe_path, parent])
                            self.messagePosted.emit("Opened 7-Zip - select the file and click Add", "info")
                            return
                    self.messagePosted.emit("7-Zip not found. Please install it.", "error")
                else:
                    for exe_path in [r"C:\Program Files\7-Zip\7zG.exe", r"C:\Program Files (x86)\7-Zip\7zG.exe"]:
                        if Path(exe_path).exists():
                            subprocess.Popen([exe_path, "a"] + paths)
                            self.messagePosted.emit(f"Opened 7-Zip add dialog with {len(paths)} item(s)", "info")
                            return
                    self.messagePosted.emit("7-Zip not found. Please install it.", "error")
            elif app == "winrar":
                for exe_path in [r"C:\Program Files\WinRAR\WinRAR.exe", r"C:\Program Files (x86)\WinRAR\WinRAR.exe"]:
                    if Path(exe_path).exists():
                        if single_file:
                            parent = str(Path(paths[0]).parent)
                            subprocess.Popen([exe_path, parent])
                            self.messagePosted.emit("Opened WinRAR - select the file and click Add", "info")
                        else:
                            subprocess.Popen([exe_path] + paths)
                            self.messagePosted.emit(f"Opened WinRAR with {len(paths)} item(s)", "info")
                        return
                self.messagePosted.emit("WinRAR not found. Please install it.", "error")
            else:
                self.messagePosted.emit(f"Unknown archiver: {app}", "error")
        except Exception as e:
            self.messagePosted.emit(f"Cannot open archiver: {e}", "error")

    def _start_extract_watcher(self, proc, stem: str, archive_path: str = "", dest_dir: str = "", batch_id: int = 0) -> None:
        thread = _ExtractWatcherThread(proc, stem, archive_path, dest_dir, batch_id, self)
        thread.finished.connect(thread.deleteLater)
        self._extract_threads.append(thread)
        thread.extractDone.connect(self._on_extract_done, Qt.ConnectionType.QueuedConnection)
        thread.start()

    @Slot(str, str, int)
    def _on_extract_done(self, stem: str, archive_path: str, batch_id: int) -> None:
        
        if batch_id > 0 and batch_id in self._bulk_extract_pending:
            self._bulk_extract_pending[batch_id] -= 1
            pending = self._bulk_extract_pending[batch_id]
            
            if pending <= 0:
                pass
                self._extracting = False
                
                delete_paths = self._bulk_extract_delete_paths.pop(batch_id, [])
                if delete_paths:
                    deleted_count = 0
                    for path in delete_paths:
                        if Path(path).exists():
                            try:
                                self.deleteFiles([path])
                                deleted_count += 1
                            except Exception as e:
                                pass
                    if deleted_count > 0:
                        self.messagePosted.emit(f"Bulk extraction complete: {len(delete_paths)} archives extracted and deleted", "success")
                    else:
                        self.messagePosted.emit(f"Bulk extraction complete: {len(delete_paths)} archives extracted", "success")
                else:
                    self.messagePosted.emit(f"Bulk extraction complete: {stem}\\", "success")
                
                self._bulk_extract_pending.pop(batch_id, None)
                self._refresh_current_directory()
        else:
            self._extracting = False
            if archive_path and Path(archive_path).exists():
                try:
                    self.deleteFiles([archive_path])
                    self.messagePosted.emit(f"Extraction complete: {stem}\\ (archive deleted — undo to restore)", "success")
                except Exception as e:
                    self.messagePosted.emit(f"Extraction complete: {stem}\\ (archive delete failed: {e})", "success")
            else:
                self.messagePosted.emit(f"Extraction complete: {stem}\\", "success")
            self._refresh_current_directory()
        
        self._extract_threads = [t for t in self._extract_threads if t.isRunning()]

    @Slot(str, str, bool)
    def extractArchive(self, path: str, app: str, delete_after: bool = False) -> None:
        self.extractArchives([path], app, delete_after)

    @Slot("QVariantList", str, bool)
    def extractArchives(self, paths: list, app: str, delete_after: bool) -> None:
        if not paths:
            self.messagePosted.emit("No archives selected", "warn")
            return
        
        import subprocess
        
        valid_paths = [p for p in paths if p and Path(p).exists()]
        if not valid_paths:
            self.messagePosted.emit("No valid archives found", "error")
            return
        
        self._bulk_extract_batch_id += 1
        batch_id = self._bulk_extract_batch_id
        self._bulk_extract_pending[batch_id] = len(valid_paths)
        
        if delete_after:
            self._bulk_extract_delete_paths[batch_id] = valid_paths.copy()
        
        self._extracting = True
        action = "Extracting" if not delete_after else "Extracting and deleting"
        self.messagePosted.emit(f"{action} {len(valid_paths)} archives...", "info")
        
        for path in valid_paths:
            try:
                proc = None
                dest_dir = str(Path(path).parent)
                stem = Path(path).stem
                
                if app == "7z":
                    for exe_path in [r"C:\Program Files\7-Zip\7zG.exe", r"C:\Program Files (x86)\7-Zip\7zG.exe"]:
                        if Path(exe_path).exists():
                            out_dir = str(Path(dest_dir) / stem)
                            proc = subprocess.Popen([exe_path, "x", path, f"-o{out_dir}"])
                            break
                    if proc is None:
                        self.messagePosted.emit("7-Zip not found. Please install it.", "error")
                        self._bulk_extract_pending[batch_id] -= 1
                        continue
                        
                elif app == "winrar":
                    if len(valid_paths) > 1 and path == valid_paths[0]:
                        if self._extractWinRARViaShell(valid_paths):
                            self.messagePosted.emit(f"WinRAR shell extraction started for {len(valid_paths)} archives", "info")
                            for p in valid_paths[1:]:
                                self._bulk_extract_pending[batch_id] -= 1
                            proc = None
                            break
                    
                    for exe_path in [r"C:\Program Files\WinRAR\WinRAR.exe", r"C:\Program Files (x86)\WinRAR\WinRAR.exe"]:
                        if Path(exe_path).exists():
                            proc = subprocess.Popen([exe_path, "x", "-ad", path, dest_dir + "\\"])
                            break
                    if proc is None:
                        self.messagePosted.emit("WinRAR not found. Please install it.", "error")
                        self._bulk_extract_pending[batch_id] -= 1
                        continue
                else:
                    self.messagePosted.emit(f"Unknown archiver: {app}", "error")
                    self._bulk_extract_pending[batch_id] -= 1
                    continue
                
                delete_path = path if delete_after else ""
                self._start_extract_watcher(proc, stem, delete_path, dest_dir, batch_id)
                
            except Exception as e:
                self.messagePosted.emit(f"Cannot extract {Path(path).name}: {e}", "error")
                self._bulk_extract_pending[batch_id] -= 1
        
        if self._bulk_extract_pending.get(batch_id, 0) <= 0:
            self._extracting = False
            self._bulk_extract_pending.pop(batch_id, None)
            self._bulk_extract_delete_paths.pop(batch_id, None)

    @Slot("QVariantList", bool)
    def extractWinRARShell(self, paths: list, delete_after: bool) -> None:
        if not paths:
            self.messagePosted.emit("No archives selected", "warn")
            return
        
        valid_paths = [p for p in paths if p and Path(p).exists()]
        if not valid_paths:
            self.messagePosted.emit("No valid archives found", "error")
            return
        
        self._winrar_extract_queue = valid_paths.copy()
        self._winrar_extract_delete_after = delete_after
        self._winrar_extract_total = len(valid_paths)
        self._winrar_extract_current = 0
        
        self._extracting = True
        action = "Extracting" if not delete_after else "Extracting and deleting"
        self.messagePosted.emit(f"{action} {len(valid_paths)} archive(s) with WinRAR...", "info")
        
        self._extractNextWinRAR()

    def _extractNextWinRAR(self) -> None:
        if not self._winrar_extract_queue:
            self._extracting = False
            self.messagePosted.emit(f"All {self._winrar_extract_total} archive(s) processed. Press F5 to refresh if files don't appear.", "success")
            QTimer.singleShot(500, self._schedule_scan)
            return
        
        path = self._winrar_extract_queue.pop(0)
        self._winrar_extract_current += 1
        current = self._winrar_extract_current
        total = self._winrar_extract_total
        
        try:
            import subprocess
            dest_dir = str(Path(path).parent)
            stem = Path(path).stem
            
            winrar_exe = None
            for exe_path in [r"C:\Program Files\WinRAR\WinRAR.exe", r"C:\Program Files (x86)\WinRAR\WinRAR.exe"]:
                if Path(exe_path).exists():
                    winrar_exe = exe_path
                    break
            
            if not winrar_exe:
                self.messagePosted.emit("WinRAR not found", "error")
                self._extracting = False
                return
            
            self.messagePosted.emit(f"[{current}/{total}] Extracting: {stem}...", "info")
            
            proc = subprocess.Popen([winrar_exe, "x", "-ad", path, dest_dir + "\\"])
            
            self._start_sequential_watcher(proc, stem, path)
            
        except Exception as e:
            self.messagePosted.emit(f"[{current}/{total}] Failed to extract {stem}: {e}", "error")
            QTimer.singleShot(100, self._extractNextWinRAR)

    def _start_sequential_watcher(self, proc, stem: str, archive_path: str) -> None:
        thread = _ExtractWatcherThread(proc, stem, archive_path, str(Path(archive_path).parent), parent=self)
        thread.finished.connect(thread.deleteLater)
        self._extract_threads.append(thread)
        
        def on_single_extract_done(stem_done: str, archive_path_done: str):
            self._extract_threads = [t for t in self._extract_threads if t.isRunning()]
            QTimer.singleShot(500, self._extractNextWinRAR)
            
            if self._winrar_extract_delete_after and Path(archive_path_done).exists():
                try:
                    self.deleteFiles([archive_path_done])
                except Exception as e:
                    pass
        
        thread.extractDone.connect(on_single_extract_done, Qt.ConnectionType.QueuedConnection)
        thread.start()

    def _deleteArchivesAfterExtract(self, paths: list) -> None:
        deleted = 0
        for path in paths:
            if Path(path).exists():
                try:
                    self.deleteFiles([path])
                    deleted += 1
                except Exception as e:
                    pass
        self.messagePosted.emit(f"Extraction complete, deleted {deleted} archive(s)", "success")
        self._refresh_current_directory()

    def _extractWinRARViaShell(self, paths: list[str]) -> bool:
        try:
            import winreg
            import pythoncom
            from win32com.shell import shell, shellcon
            import win32gui
            import win32con
            import ctypes
            from ctypes import wintypes
            
            WINRAR_CLSID = "{B41DB860-64E4-11D2-9906-E49FADC173CA}"
            
            try:
                key = winreg.OpenKey(winreg.HKEY_CLASSES_ROOT, f"CLSID\\{WINRAR_CLSID}\\InProcServer32")
                dll_path, _ = winreg.QueryValueEx(key, None)
                winreg.CloseKey(key)
            except FileNotFoundError:
                raise Exception("WinRAR shell extension not found in registry")
            except Exception as e:
                raise Exception(f"Failed to locate WinRAR shell extension: {e}")
            
            clsid = pythoncom.MakeIID(WINRAR_CLSID)
            context_menu = pythoncom.CoCreateInstance(
                clsid,
                None,
                pythoncom.CLSCTX_INPROC_SERVER,
                shell.IID_IContextMenu
            )
            
            shell_ext_init = context_menu.QueryInterface(shell.IID_IShellExtInit)
            
            file_list = []
            for path in paths:
                if Path(path).exists():
                    file_list.append(str(Path(path).resolve()))
            
            if not file_list:
                raise Exception("No valid files to extract")
            
            
            files_bytes = b'\x00'.join(f.encode('utf-16-le') for f in file_list) + b'\x00\x00'
            
            class DROPFILES(ctypes.Structure):
                _fields_ = [
                    ("pFiles", wintypes.DWORD),
                    ("pt", wintypes.POINT),
                    ("fNC", wintypes.BOOL),
                    ("fWide", wintypes.BOOL),
                ]
            
            header_size = ctypes.sizeof(DROPFILES)
            total_size = header_size + len(files_bytes)
            
            hglobal = ctypes.windll.kernel32.GlobalAlloc(win32con.GMEM_MOVEABLE, total_size)
            if not hglobal:
                raise Exception("Failed to allocate global memory")
            
            try:
                ptr = ctypes.windll.kernel32.GlobalLock(hglobal)
                if not ptr:
                    raise Exception("Failed to lock global memory")
                
                try:
                    dropfiles = DROPFILES()
                    dropfiles.pFiles = header_size
                    dropfiles.pt.x = 0
                    dropfiles.pt.y = 0
                    dropfiles.fNC = False
                    dropfiles.fWide = True
                    ctypes.memmove(ptr, ctypes.byref(dropfiles), header_size)
                    
                    ctypes.memmove(ptr + header_size, files_bytes, len(files_bytes))
                finally:
                    ctypes.windll.kernel32.GlobalUnlock(hglobal)
                
                class STGMEDIUM(ctypes.Structure):
                    _fields_ = [
                        ("tymed", wintypes.DWORD),
                        ("union", ctypes.c_void_p),
                        ("pUnkForRelease", ctypes.c_void_p),
                    ]
                
                medium = STGMEDIUM()
                medium.tymed = pythoncom.TYMED_HGLOBAL
                medium.union = hglobal
                medium.pUnkForRelease = 0
                
                class FORMATETC(ctypes.Structure):
                    _fields_ = [
                        ("cfFormat", wintypes.WORD),
                        ("ptd", ctypes.c_void_p),
                        ("dwAspect", wintypes.DWORD),
                        ("lindex", wintypes.LONG),
                        ("tymed", wintypes.DWORD),
                    ]
                
                formatetc = FORMATETC()
                formatetc.cfFormat = win32con.CF_HDROP
                formatetc.ptd = 0
                formatetc.dwAspect = 1
                formatetc.lindex = -1
                formatetc.tymed = pythoncom.TYMED_HGLOBAL
                
                try:
                    data_object = shell.SHCreateDataObject(None, 0, None)
                    data_object.SetData(formatetc, medium, False)
                except AttributeError:
                    from win32com.shell import shellcon
                    data_object = pythoncom.CoCreateInstance(
                        pythoncom.MakeIID("{00000312-0000-0000-C000-000000000046}"),
                        None,
                        pythoncom.CLSCTX_INPROC_SERVER,
                        pythoncom.IID_IDataObject
                    )
                    data_object.SetData(formatetc, medium, False)
                
                shell_ext_init.Initialize(None, data_object, 0)
                
                hmenu = win32gui.CreatePopupMenu()
                try:
                    id_cmd_first = 0
                    context_menu.QueryContextMenu(hmenu, 0, id_cmd_first, 0x7FFF, shellcon.CMF_NORMAL)
                    
                    num_items = win32gui.GetMenuItemCount(hmenu)
                    extract_cmd = None
                    
                    for i in range(num_items):
                        item_info = win32gui.GetMenuItemInfo(hmenu, i, True)
                        cmd_id = item_info.wID
                        
                        if cmd_id >= id_cmd_first:
                            try:
                                cmd_str = context_menu.GetCommandString(cmd_id - id_cmd_first, shellcon.GCS_VERBW)
                                
                                if cmd_str and 'extract' in cmd_str.lower():
                                    if 'here' in cmd_str.lower() or cmd_str.lower() in ('extract', 'extracthere'):
                                        extract_cmd = cmd_id - id_cmd_first
                                        break
                            except:
                                pass
                    
                    if extract_cmd is None:
                        extract_cmd = 0
                    
                    class CMINVOKECOMMANDINFO(ctypes.Structure):
                        _fields_ = [
                            ("cbSize", wintypes.DWORD),
                            ("fMask", wintypes.DWORD),
                            ("hwnd", wintypes.HWND),
                            ("lpVerb", wintypes.LPCSTR),
                            ("lpParameters", wintypes.LPCSTR),
                            ("lpDirectory", wintypes.LPCSTR),
                            ("nShow", wintypes.INT),
                            ("dwHotKey", wintypes.DWORD),
                            ("hIcon", wintypes.HANDLE),
                        ]
                    
                    verb = ctypes.c_char_p(b"extracthere")
                    invoke_info = CMINVOKECOMMANDINFO()
                    invoke_info.cbSize = ctypes.sizeof(CMINVOKECOMMANDINFO)
                    invoke_info.fMask = 0
                    invoke_info.hwnd = 0
                    invoke_info.lpVerb = verb
                    invoke_info.lpParameters = None
                    invoke_info.lpDirectory = None
                    invoke_info.nShow = win32con.SW_SHOWNORMAL
                    invoke_info.dwHotKey = 0
                    invoke_info.hIcon = 0
                    
                    
                    try:
                        context_menu.InvokeCommand(ctypes.byref(invoke_info))
                    except Exception as e:
                        pass
                        verb_idx = ctypes.c_char_p(extract_cmd)
                        invoke_info.lpVerb = verb_idx
                        context_menu.InvokeCommand(ctypes.byref(invoke_info))
                    
                    return True
                    
                finally:
                    win32gui.DestroyMenu(hmenu)
                    
            finally:
                ctypes.windll.kernel32.GlobalFree(hglobal)
                
        except Exception as e:
            pass
            import traceback
            traceback.print_exc()
            return False

    @Slot(str, str, result=bool)
    def renameFile(self, full_path: str, new_name: str) -> bool:
        if not full_path or not new_name:
            return False
        try:
            p = Path(full_path)
            if not p.exists():
                self.messagePosted.emit("Cannot rename: file not found", "error")
                return False
            new_path = p.parent / new_name
            if new_path.exists():
                self.messagePosted.emit("Cannot rename: file already exists", "error")
                return False
            old_path = str(p)
            p.rename(new_path)
            self._rename_history.append((old_path, str(new_path)))
            self.canUndoChanged.emit()
            self.messagePosted.emit(f"Renamed to: {new_name}", "info")
            self._apply_local_rename(old_path, str(new_path))
            return True
        except Exception as e:
            self.messagePosted.emit(f"Cannot rename: {e}", "error")
            return False

    @Slot(result="QVariantMap")
    def analyticsStats(self) -> dict:
        rows = self._model.rows()
        row_sig = (len(rows), rows[0].get("name", "") if rows else "")
        if self._analytics_cache and self._analytics_cache[0] == row_sig:
            return self._analytics_cache[1]
        if not rows:
            return {
                "totalFiles": 0,
                "totalSize": 0,
                "totalSizeText": "0 B",
                "byExt": [],
                "bySizeBucket": [],
                "largestFiles": [],
                "largestFolders": []
            }

        total_size = 0
        ext_stats: dict[str, dict] = {}
        files = []
        folders = []

        size_buckets = [
            (0, 1024, "< 1 KB"),
            (1024, 1024*1024, "1 KB - 1 MB"),
            (1024*1024, 10*1024*1024, "1 - 10 MB"),
            (10*1024*1024, 100*1024*1024, "10 - 100 MB"),
            (100*1024*1024, 1024*1024*1024, "100 MB - 1 GB"),
            (1024*1024*1024, 10*1024*1024*1024, "1 - 10 GB"),
            (10*1024*1024*1024, 100*1024*1024*1024, "10 - 100 GB"),
            (100*1024*1024*1024, float('inf'), "> 100 GB")
        ]
        bucket_counts = [0] * len(size_buckets)

        for row in rows:
            size = row.get("size", 0) or 0
            is_dir = row.get("type", "") == "Folder"
            name = row.get("name", "")

            total_size += size

            if is_dir:
                folders.append({"name": name, "size": size, "sizeText": row.get("size_text", "")})
            else:
                files.append({"name": name, "size": size, "sizeText": row.get("size_text", "")})
                ext = Path(name).suffix.lower() or "(no ext)"
                if ext not in ext_stats:
                    ext_stats[ext] = {"count": 0, "size": 0}
                ext_stats[ext]["count"] += 1
                ext_stats[ext]["size"] += size

                for i, (lo, hi, _) in enumerate(size_buckets):
                    if lo <= size < hi:
                        bucket_counts[i] += 1
                        break

        ext_list = [
            {
                "ext": ext,
                "count": d["count"],
                "size": d["size"],
                "sizeText": format_size(d["size"]),
                "color": _EXT_COLOURS.get(ext.lower(), "#888888")
            }
            for ext, d in sorted(ext_stats.items(), key=lambda x: -x[1]["size"])
        ]

        bucket_list = [
            {"label": label, "count": count}
            for (_, _, label), count in zip(size_buckets, bucket_counts)
        ]

        largest_files = sorted(files, key=lambda x: -x["size"])[:10]
        largest_folders = sorted(folders, key=lambda x: -x["size"])[:10]

        result = {
            "totalFiles": len(files),
            "totalSize": total_size,
            "totalSizeText": format_size(total_size),
            "byExt": ext_list,
            "bySizeBucket": bucket_list,
            "largestFiles": [{"name": f["name"], "sizeText": f["sizeText"]} for f in largest_files],
            "largestFolders": [{"name": f["name"], "sizeText": f["sizeText"]} for f in largest_folders]
        }
        self._analytics_cache = (row_sig, result)
        return result

    @Slot(str, str, str, str, str, str, str, str, str)
    def applyFilters(self, min_size: str, max_size: str,
                     extensions: str, exclude_extensions: str,
                     keywords: str, exclude_keywords: str,
                     filter_type: str,
                     min_date: str = "", max_date: str = "") -> None:
        if filter_type in ("all", "files", "folders"):
            self._filters["filter_type"] = filter_type

        if not min_size:
            self._filters["min_size"] = 0
        else:
            v = parse_size(min_size)
            if v is not None:
                self._filters["min_size"] = v

        if not max_size:
            self._filters["max_size"] = 0
        else:
            v = parse_size(max_size)
            if v is not None:
                self._filters["max_size"] = v

        self._filters["extensions"]         = self._norm_ext(self._split_csv(extensions))
        self._filters["exclude_extensions"] = self._norm_ext(self._split_csv(exclude_extensions))
        self._filters["keywords"]           = self._split_csv(keywords)
        self._filters["exclude_keywords"]   = self._split_csv(exclude_keywords)
        self._filters["min_date"]           = min_date.strip()
        self._filters["max_date"]           = max_date.strip()

        self.filtersChanged.emit()

    @Slot(str)
    def setFilterType(self, value: str) -> None:
        if value in ("all", "files", "folders"):
            self._filters["filter_type"] = value
            self.filtersChanged.emit()

    @Slot(str)
    def setMinSize(self, text: str) -> None:
        if not text:
            self._filters["min_size"] = 0
        else:
            v = parse_size(text)
            if v is None:
                self.messagePosted.emit(f"Invalid size: {text}", "error")
                return
            self._filters["min_size"] = v
        self.filtersChanged.emit()

    @Slot(str)
    def setMaxSize(self, text: str) -> None:
        if not text:
            self._filters["max_size"] = 0
        else:
            v = parse_size(text)
            if v is None:
                self.messagePosted.emit(f"Invalid size: {text}", "error")
                return
            self._filters["max_size"] = v
        self.filtersChanged.emit()

    @staticmethod
    def _split_csv(text: str) -> list[str]:
        return [p.strip() for p in (text or "").split(",") if p.strip()]

    @staticmethod
    def _norm_ext(items: list[str]) -> list[str]:
        return [e if e.startswith(".") else f".{e}" for e in items]

    @Slot(str)
    def setExtensions(self, text: str) -> None:
        self._filters["extensions"] = self._norm_ext(self._split_csv(text))
        self.filtersChanged.emit()

    @Slot(str)
    def setExcludeExtensions(self, text: str) -> None:
        self._filters["exclude_extensions"] = self._norm_ext(self._split_csv(text))
        self.filtersChanged.emit()

    @Slot(str)
    def setKeywords(self, text: str) -> None:
        self._filters["keywords"] = self._split_csv(text)
        self.filtersChanged.emit()

    @Slot(str)
    def setExcludeKeywords(self, text: str) -> None:
        self._filters["exclude_keywords"] = self._split_csv(text)
        self.filtersChanged.emit()

    @Slot(str)
    def setSortBy(self, value: str) -> None:
        if value in ("none", "size", "date", "alph", "name", "path", "type"):
            self._filters["sort_by"] = value
            self._resort_current_rows()
            self.filtersChanged.emit()

    @Slot(str)
    def setSortDir(self, value: str) -> None:
        if value in ("asc", "desc"):
            self._filters["sort_dir"] = value
            self._resort_current_rows()
            self.filtersChanged.emit()

    @Slot()
    def resetFilters(self) -> None:
        self._filters = self._default_filters()
        self.filtersChanged.emit()
        self.messagePosted.emit("Filters reset.", "info")

    def _resort_current_rows(self) -> None:
        self._cancel_background_folder_sizes()
        
        sb = self._filters.get("sort_by") or "none"
        rev = (self._filters.get("sort_dir") or "asc") == "desc"
        
        def _natkey(s: str):
            return [int(t) if t.isdigit() else t.lower()
                    for t in re.split(r"(\d+)", s)]

        def _fd(item) -> int:
            return 0 if item.get("is_dir") else 1

        all_rows = self._model.all_rows()
        
        if sb in ("alph", "name"):
            all_rows.sort(key=lambda x: (_fd(x), _natkey(x["name"])), reverse=rev)
        elif sb == "size":
            dirs = [x for x in all_rows if x.get("is_dir")]
            files = [x for x in all_rows if not x.get("is_dir")]
            dirs.sort(key=lambda x: (x["size"], _natkey(x["name"])), reverse=rev)
            files.sort(key=lambda x: (x["size"], _natkey(x["name"])), reverse=rev)
            all_rows = dirs + files
        elif sb == "date":
            dirs = [x for x in all_rows if x.get("is_dir")]
            files = [x for x in all_rows if not x.get("is_dir")]
            dirs.sort(key=lambda x: (x.get("mtime", 0), _natkey(x["name"])), reverse=rev)
            files.sort(key=lambda x: (x.get("mtime", 0), _natkey(x["name"])), reverse=rev)
            all_rows = dirs + files
        elif sb == "path":
            all_rows.sort(key=lambda x: (_fd(x), _natkey(x["full_path"])), reverse=rev)
        elif sb == "type":
            all_rows.sort(key=lambda x: (_fd(x), x.get("suffix", ""), _natkey(x["name"])), reverse=rev)
        else:
            all_rows.sort(key=lambda x: (_fd(x), _natkey(x["name"])))
        
        self._model.reset_rows(all_rows)

    def _abort_scan(self) -> None:
        self._cancel_background_folder_sizes()
        if self._worker is not None:
            self._worker.cancel()
            try:
                self._worker.finished.disconnect()
            except RuntimeError:
                pass
            try:
                self._worker.error.disconnect()
            except RuntimeError:
                pass
            try:
                self._worker.progress.disconnect()
            except RuntimeError:
                pass
            if self._thread is not None:
                try:
                    self._worker.finished.connect(self._thread.quit)
                except RuntimeError:
                    pass
                try:
                    self._worker.error.connect(self._thread.quit)
                except RuntimeError:
                    pass
            self._worker = None
        if self._thread is not None:
            try:
                self._thread.finished.disconnect()
            except RuntimeError:
                pass
            dying = self._thread
            self._dying_threads.append(dying)
            def _remove_dying(t=dying):
                try:
                    self._dying_threads.remove(t)
                except ValueError:
                    pass
            dying.finished.connect(dying.deleteLater)
            dying.finished.connect(_remove_dying)
            self._thread = None
        self._busy = False
        if getattr(self, "_canceling", False):
            self._canceling = False
            self.cancelingChanged.emit()

    @Slot()
    def scan(self) -> None:
        if not self._path:
            self.messagePosted.emit("Select a directory first.", "warn")
            return
        self._cancel_background_folder_sizes()
        if self._busy:
            self._abort_scan()

        filters = dict(self._filters)
        key = self._cache_key(self._path, self._view_mode, filters)
        mtime = self._dir_mtime(self._path)

        if self._force_recursive and key not in self._scan_index:
            ancestor = self._find_ancestor_recursive_cache(self._path)
            if ancestor:
                def _load_ancestor(anc=ancestor, p=self._path, k=key):
                    try:
                        shard = self._load_scan_shard(anc)
                        if shard is None:
                            return
                        rows, folders, files, size_text, size_bytes = shard
                        norm = os.path.normpath(p).lower()
                        filtered = [r for r in rows if os.path.normpath(r.get("full_path", "")).lower().startswith(norm)]
                        if not filtered:
                            return
                        f_folders = sum(1 for r in filtered if r.get("is_dir"))
                        f_files = sum(1 for r in filtered if not r.get("is_dir"))
                        f_size = sum(int(r.get("size") or 0) for r in filtered if not r.get("is_dir"))
                        f_size_text = format_size(f_size)
                        def _apply():
                            active_filters = dict(self._filters)
                            current_key = self._cache_key(self._path, self._view_mode, active_filters)
                            if k == current_key:
                                self._model.reset_rows(filtered)
                                self._total_size_bytes = f_size
                                self._totals = {"folders": f_folders, "files": f_files, "size": 0, "size_text": f_size_text}
                                self._save_memory_cache(p, filtered, f_folders, f_files, f_size_text, f_size)
                                self._save_scan_shard(k, filtered, f_folders, f_files, f_size_text, f_size)
                                self._scan_index[k] = mtime
                                self._save_scan_index()
                                self.totalsChanged.emit()
                                self._set_status(f"{f_folders} folders · {f_files} files · {f_size_text} (from parent cache)")
                                self._resort_current_rows()
                                if self._search_text:
                                    self._model.set_search_text(self._search_text)
                        QTimer.singleShot(0, self, _apply)
                    except Exception:
                        pass
                import threading
                threading.Thread(target=_load_ancestor, daemon=True).start()
                return

        if key in self._scan_index and self._scan_index[key] == mtime:
            def async_load_cache(k=key, mt=mtime, p=self._path, vm=self._view_mode):
                try:
                    shard = self._load_scan_shard(k)
                    if shard is not None:
                        rows, folders, files, size_text, size_bytes = shard
                        
                        def _apply_async():
                            active_filters = dict(self._filters)
                            current_active_key = self._cache_key(self._path, self._view_mode, active_filters)
                            if k == current_active_key:
                                self._model.reset_rows(rows)
                                self._total_size_bytes = size_bytes
                                self._totals = {"folders": folders, "files": files,
                                                "size": 0, "size_text": size_text}
                                self._save_memory_cache(p, rows, folders, files, size_text, size_bytes)
                                self.totalsChanged.emit()
                                self._set_status(f"{folders} folders · {files} files · {size_text} (cached)")
                                self._resort_current_rows()
                                search_to_apply = getattr(self, '_pending_search_restore', '') or self._search_text
                                if search_to_apply:
                                    self._set_search_text(search_to_apply)
                                    self._pending_search_restore = ''
                                self._start_background_folder_sizes(p, rows, vm, k, mt, folders, files, size_bytes)
                        
                        QTimer.singleShot(0, self, _apply_async)
                    else:
                        log_debug(f"[DEBUG] async_load_cache: shard is None for key={k}, falling back to fresh scan")
                        def _invalidate_and_rescan():
                            self._scan_index.pop(k, None)
                            self._save_scan_index()
                            active_filters = dict(self._filters)
                            current_active_key = self._cache_key(self._path, self._view_mode, active_filters)
                            if k == current_active_key:
                                self.scan()
                        QTimer.singleShot(0, self, _invalidate_and_rescan)
                except Exception as e:
                    log_debug(f"[DEBUG] async_load_cache exception: {e}, falling back to fresh scan")
                    def _invalidate_on_error():
                        self._scan_index.pop(k, None)
                        self._save_scan_index()
                        active_filters = dict(self._filters)
                        current_active_key = self._cache_key(self._path, self._view_mode, active_filters)
                        if k == current_active_key:
                            self.scan()
                    QTimer.singleShot(0, self, _invalidate_on_error)

            import threading
            threading.Thread(target=async_load_cache, daemon=True).start()
            return

        self._scan_progress = (0, 0, "")
        self._scan_start_time = time.monotonic()
        self._set_busy(True)
        self._set_status(f"Scanning {self._path} ({self._view_mode})…")

        thread = QThread()
        worker = ScanWorker(self._path, filters, self._view_mode, self._force_recursive, pool=self._scan_pool)
        worker.moveToThread(thread)
        thread.started.connect(worker.run)
        worker.finished.connect(self._on_scan_finished)
        worker.error.connect(self._on_scan_error)
        worker.progress.connect(self._on_scan_progress)
        worker.finished.connect(thread.quit)
        worker.error.connect(thread.quit)
        thread.finished.connect(worker.deleteLater)
        thread.finished.connect(thread.deleteLater)
        thread.finished.connect(self._on_scan_thread_done)
        self._thread = thread
        self._worker = worker
        self._pending_cache_key = key
        self._pending_mtime = mtime
        thread.start()

    @Slot()
    def _on_scan_thread_done(self) -> None:
        self._thread = None
        self._worker = None

    def _on_scan_progress(self, folders: int, files: int, name: str) -> None:
        self._scan_progress = (folders, files, name)
        elapsed = time.monotonic() - getattr(self, "_scan_start_time", time.monotonic())
        rate = round((folders + files) / elapsed) if elapsed > 0.5 else 0
        self._scan_progress_dict = {"folders": folders, "files": files, "current": name, "total": folders + files,
                                     "elapsed": round(elapsed, 1), "rate": rate}
        self.scanProgressChanged.emit()

    def _on_scan_finished(self, rows, folders, files, size_bytes, size_text, mode) -> None:
        try:
            log_debug(f"[DEBUG] _on_scan_finished start: folders={folders}, files={files}, size_text={size_text}, mode={mode}")
            if getattr(self, "_canceling", False):
                self._canceling = False
                self.cancelingChanged.emit()
                self._set_busy(False)
                if self.canGoBack:
                    self.goBack()
                else:
                    self._model.reset_rows(rows)
                    self._total_size_bytes = int(size_bytes)
                    self._totals = {
                        "folders": folders,
                        "files": files,
                        "size": 0,
                        "size_text": size_text,
                    }
                    self.totalsChanged.emit()
                    self._set_status("Scan cancelled")
                return

            self._model.reset_rows(rows)
            self._total_size_bytes = int(size_bytes)
            self._totals = {
                "folders": folders,
                "files": files,
                "size": 0,
                "size_text": size_text,
            }
            self._save_memory_cache(self._path, rows, folders, files, size_text, size_bytes)
            key  = getattr(self, "_pending_cache_key", None)
            mtime = getattr(self, "_pending_mtime", 0.0)
            if key:
                self._save_scan_shard(key, rows, folders, files, size_text, size_bytes)
                self._scan_index[key] = mtime
                self._evict_scan_lru()
                self._save_scan_index()
            self._analytics_cache = None
            self._resort_current_rows()
            search_to_apply = getattr(self, '_pending_search_restore', '') or self._search_text
            if search_to_apply:
                self._set_search_text(search_to_apply)
                self._pending_search_restore = ''
            self.totalsChanged.emit()
            self._set_status(
                f"{folders} folders · {files} files · {size_text} · mode: {mode}"
            )
            self._set_busy(False)
            log_debug("[DEBUG] _on_scan_finished busy set to False, calling _start_background_folder_sizes")
            self._start_background_folder_sizes(self._path, rows, mode, key, mtime, folders, files, size_bytes)
        except Exception as e:
            log_debug(f"[DEBUG] _on_scan_finished Exception: {e}")
            import traceback
            traceback.print_exc()

    def _cancel_background_folder_sizes(self) -> None:
        self._folder_size_generation += 1

    def _start_background_folder_sizes(self, root_path: str, rows: list[dict], mode: str, key: str, mtime: float, initial_folders: int, initial_files: int, initial_size: int) -> None:
        log_debug(f"[DEBUG] _start_background_folder_sizes root_path={root_path}, mode={mode}, subfolders={len([r for r in rows if r.get('is_dir')])}")
        self._folder_size_generation += 1
        my_gen = self._folder_size_generation

        if mode not in ("list", "grid"):
            log_debug(f"[DEBUG] _start_background_folder_sizes mode is not list or grid (mode={mode}), returning")
            return

        folders_to_calculate = [r for r in rows if r.get("is_dir")]
        if not folders_to_calculate:
            log_debug("[DEBUG] _start_background_folder_sizes no subfolders to calculate")
            return

        def calculate_worker():
            try:
                import threading
                log_debug(f"[DEBUG] calculate_worker starting for {len(folders_to_calculate)} subfolders (gen={my_gen})")
                total_added_size = 0
                total_subfolders = 0
                total_subfiles = 0

                for idx, r in enumerate(folders_to_calculate):
                    if self._folder_size_generation != my_gen:
                        log_debug(f"[DEBUG] calculate_worker cancelled early (gen {my_gen} vs {self._folder_size_generation})")
                        return

                    import time
                    time.sleep(0.001)

                    fp = r.get("full_path")
                    if not fp:
                        continue

                    try:
                        s, sf, ff = folder_stats(Path(fp))
                    except Exception as err:
                        log_debug(f"[DEBUG] calculate_worker stats exception for {fp}: {err}")
                        s, sf, ff = 0, 0, 0

                    if self._folder_size_generation != my_gen:
                        log_debug(f"[DEBUG] calculate_worker cancelled during calculation (gen {my_gen} vs {self._folder_size_generation})")
                        return

                    r["size"] = s
                    r["size_text"] = format_size(s)
                    log_debug(f"[DEBUG] calculate_worker computed folder={r.get('name')} size={format_size(s)}")

                    self.folderSizeUpdated.emit(fp, s, format_size(s))

                    total_added_size += s
                    total_subfolders += sf
                    total_subfiles += ff

                if self._folder_size_generation != my_gen:
                    return

                totals = {
                    "root_path": root_path,
                    "added_size": total_added_size,
                    "folders_added": total_subfolders,
                    "files_added": total_subfiles,
                    "complete_size": initial_size + total_added_size,
                    "complete_folders": initial_folders + total_subfolders,
                    "complete_files": initial_files + total_subfiles,
                }
                self.folderSizesFinalized.emit(rows, totals, key, mtime)

            except Exception as e_calc:
                log_debug(f"[DEBUG] calculate_worker Exception: {e_calc}")
                import traceback
                traceback.print_exc()

        import threading
        threading.Thread(target=calculate_worker, daemon=True).start()

    @Slot(list, dict, str, float)
    def _on_folder_sizes_finalized(self, rows: list, totals: dict, key: str, mtime: float) -> None:
        try:
            if not key:
                return
            log_debug(f"[DEBUG] _on_folder_sizes_finalized running: key={key}")

            if key:
                self._save_scan_shard(
                    key, 
                    rows, 
                    totals["complete_folders"], 
                    totals["complete_files"], 
                    format_size(totals["complete_size"]), 
                    totals["complete_size"]
                )
                self._scan_index[key] = mtime
                self._evict_scan_lru()
                self._save_scan_index()
                log_debug("[DEBUG] _on_folder_sizes_finalized stored updated rows in cache")

            self._save_memory_cache(
                totals["root_path"], 
                rows, 
                totals["complete_folders"], 
                totals["complete_files"], 
                format_size(totals["complete_size"]), 
                totals["complete_size"]
            )

            active_filters = dict(self._filters)
            current_active_key = self._cache_key(self._path, self._view_mode, active_filters)
            if key == current_active_key:
                self._total_size_bytes += totals["added_size"]
                self._totals["folders"] += totals["folders_added"]
                self._totals["files"] += totals["files_added"]
                self._totals["size_text"] = format_size(self._total_size_bytes)
                self.totalsChanged.emit()
                self._set_status(
                    f"{self._totals['folders']} folders · {self._totals['files']} files · {self._totals['size_text']} · mode: {self._view_mode}"
                )
        except Exception as e:
            log_debug(f"[DEBUG] _on_folder_sizes_finalized Exception: {e}")

    def _on_scan_error(self, message: str) -> None:
        self._set_busy(False)
        if getattr(self, "_canceling", False):
            self._canceling = False
            self.cancelingChanged.emit()
            self._set_status("Scan cancelled")
            if self.canGoBack:
                self.goBack()
            return
        self._set_status("Error")
        self.messagePosted.emit(message, "error")

    @Slot()
    def clearScanCache(self) -> None:
        self._scan_index.clear()
        try:
            if _SCAN_CACHE_DIR.exists():
                import shutil
                shutil.rmtree(_SCAN_CACHE_DIR)
        except Exception:
            pass

    @Slot(result=int)
    def totalCacheSize(self) -> int:
        total = 0
        cache_dir = Path(__file__).with_name("cache")
        try:
            if cache_dir.exists():
                for f in cache_dir.rglob("*"):
                    if f.is_file():
                        total += f.stat().st_size
        except Exception:
            pass
        return total

    @Slot(result=str)
    def totalCacheSizeText(self) -> str:
        sz = self.totalCacheSize()
        if sz >= 1024 ** 3:
            return f"{sz / 1024 ** 3:.2f} GB"
        if sz >= 1024 ** 2:
            return f"{sz / 1024 ** 2:.1f} MB"
        if sz >= 1024:
            return f"{sz / 1024:.1f} KB"
        return f"{sz} B"

    @Slot("QVariantList")
    def saveTabs(self, tabs: list[dict]) -> None:
        try:
            _TABS_CACHE_FILE.parent.mkdir(parents=True, exist_ok=True)
            data = [{"path": t.get("path", ""), "pinned": t.get("pinned", False), "color": t.get("tabColor", ""), "homePath": t.get("homePath", "")} for t in tabs]
            _TABS_CACHE_FILE.write_text(json.dumps(data, indent=2), encoding="utf-8")
        except Exception:
            pass

    @Slot(result="QVariantList")
    def loadTabs(self) -> list[dict]:
        try:
            if _TABS_CACHE_FILE.exists():
                data = json.loads(_TABS_CACHE_FILE.read_text(encoding="utf-8"))
                if isinstance(data, list):
                    result = []
                    for t in data:
                        if t.get("path"):
                            tab = {"path": t.get("path", ""), "pinned": t.get("pinned", False), "color": t.get("color", "")}
                            if t.get("pinned") and t.get("homePath"):
                                tab["path"] = t.get("homePath")
                                tab["homePath"] = t.get("homePath")
                            result.append(tab)
                    return result
        except Exception:
            pass
        return []

    @Slot(str, result=bool)
    def exportCurrent(self, file_url: str) -> bool:
        path = self._url_to_path(file_url)
        if not path:
            self.messagePosted.emit("Invalid export path.", "error")
            return False
        rows = self._model.rows()
        if not rows:
            self.messagePosted.emit("Nothing to export. Run a scan first.", "warn")
            return False
        try:
            with open(path, "w", encoding="utf-8") as fh:
                fh.write(self._format_export(rows))
            self.messagePosted.emit(f"Exported to {path}", "success")
            return True
        except Exception as exc:
            self.messagePosted.emit(f"Export failed: {exc}", "error")
            return False

    @staticmethod
    def _url_to_path(url: str) -> str:
        if not url:
            return ""
        from urllib.parse import unquote
        if url.startswith("file:///"):
            path = url[8:] if os.name == "nt" else "/" + url[8:]
        elif url.startswith("file://"):
            path = url[7:]
        else:
            path = url
        return unquote(path).replace("/", os.sep)

    def _format_export(self, rows: list[dict]) -> str:
        lines: list[str] = []
        lines.append("=" * 80)
        lines.append("Rootline Atlas Export")
        lines.append(f"Root: {self._path}")
        lines.append(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        lines.append(f"View mode: {self._view_mode}")
        lines.append("=" * 80)
        lines.append("")
        lines.append("Active Filters:")
        for k, v in self._filters.items():
            if isinstance(v, list):
                v = ", ".join(v) if v else "None"
            elif k in ("min_size", "max_size"):
                v = format_size(v) if v else "Unlimited"
            lines.append(f"  - {k}: {v}")
        lines.append("")

        if self._view_mode == "tree":
            lines.append("Directory Tree:")
            lines.append("-" * 80)
            for r in rows:
                lines.append(
                    f"{r['indent']}{r['connector']}{r['name']}  -  {r['size_text']}"
                    f"    | {r['type']:6} | Created: {r['created']}"
                )
        else:
            lines.append("Results:")
            lines.append("-" * 80)
            header = f"{'Name':<40} {'Size':>12}  {'Type':<7}  {'Created':<19}  Path"
            lines.append(header)
            lines.append("-" * len(header))
            for r in rows:
                name = r["name"]
                if len(name) > 39:
                    name = name[:36] + "..."
                lines.append(
                    f"{name:<40} {r['size_text']:>12}  {r['type']:<7}  {r['created']:<19}  {r['rel_path']}"
                )

        lines.append("")
        lines.append("Summary:")
        lines.append(f"  Total Folders: {self._totals['folders']}")
        lines.append(f"  Total Files:   {self._totals['files']}")
        lines.append(f"  Total Size:    {self._totals['size_text']}")
        return "\n".join(lines) + "\n"

    @Slot(result=str)
    def getTreeText(self) -> str:
        rows = self._model.rows()
        if not rows:
            return ""
        lines: list[str] = []
        lines.append(f"  {self._path}")
        lines.append("")
        COL = 68
        for r in rows:
            prefix = r["indent"] + r["connector"]
            name_part = f"{prefix}{r['name']}"
            size_part = f"  {r['size_text']}"
            date_part = f"  {r['created']}"
            pad = max(1, COL - len(name_part) - len(size_part))
            lines.append(f"{name_part}{size_part}{' ' * pad}{date_part}")
        lines.append("")
        lines.append(
            f"  {self._totals['folders']} folders   "
            f"{self._totals['files']} files   "
            f"{self._totals['size_text']}"
        )
        return "\n".join(lines)

    _SETTINGS_FILE = Path(__file__).parent / ".settings.json"

    def _load_settings(self) -> dict:
        try:
            return json.loads(self._SETTINGS_FILE.read_text(encoding="utf-8"))
        except Exception:
            return {}

    def _save_settings(self, data: dict):
        try:
            self._SETTINGS_FILE.write_text(json.dumps(data, indent=2), encoding="utf-8")
        except Exception:
            pass

    @Slot(str, result="QVariant")
    def getSetting(self, key: str):
        return self._load_settings().get(key)

    @Slot(str, "QVariant")
    def setSetting(self, key: str, value):
        data = self._load_settings()
        data[key] = value
        self._save_settings(data)

    @Slot(str, result=str)
    def readExportedFile(self, file_url: str) -> str:
        path = self._url_to_path(file_url)
        try:
            with open(path, "r", encoding="utf-8") as fh:
                return fh.read()
        except OSError as exc:
            self.messagePosted.emit(f"Cannot read file: {exc}", "error")
            return ""
