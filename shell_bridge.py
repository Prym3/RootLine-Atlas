
from __future__ import annotations

import ctypes
import os
from ctypes import wintypes
from pathlib import Path
from typing import Optional


_ole32 = ctypes.windll.ole32
_shell32 = ctypes.windll.shell32
_kernel32 = ctypes.windll.kernel32

COINIT_APARTMENTTHREADED = 0x2
COINIT_DISABLE_OLE1DDE = 0x4

_com_initialized = False


def _ensure_com() -> None:
    global _com_initialized
    if not _com_initialized:
        hr = _ole32.CoInitializeEx(None, COINIT_APARTMENTTHREADED | COINIT_DISABLE_OLE1DDE)
        if hr < 0 and hr != 0x00000001:
            raise OSError(f"CoInitializeEx failed: 0x{hr & 0xFFFFFFFF:08X}")
        _com_initialized = True



class GUID(ctypes.Structure):
    _fields_ = [
        ("Data1", wintypes.DWORD),
        ("Data2", wintypes.WORD),
        ("Data3", wintypes.WORD),
        ("Data4", wintypes.BYTE * 8),
    ]


def _make_guid(d1, d2, d3, b0, b1, b2, b3, b4, b5, b6, b7):
    return GUID(d1, d2, d3, (b0, b1, b2, b3, b4, b5, b6, b7))


class PROPERTYKEY(ctypes.Structure):
    _fields_ = [("fmtid", GUID), ("pid", wintypes.DWORD)]


def _make_pkey(d1, d2, d3, b0, b1, b2, b3, b4, b5, b6, b7, pid):
    return PROPERTYKEY(_make_guid(d1, d2, d3, b0, b1, b2, b3, b4, b5, b6, b7), pid)


PKEY_Size          = _make_pkey(0xB725F130, 0x47EF, 0x101A, 0xA5, 0xF1, 0x02, 0x60, 0x8C, 0x9E, 0xEB, 0xAC, 12)
PKEY_DateModified  = _make_pkey(0x14B81DA1, 0x0135, 0x4D31, 0x96, 0xD9, 0x6C, 0xBF, 0xC9, 0x67, 0x1A, 0x99, 2)
PKEY_DateCreated   = _make_pkey(0xB725F130, 0x47EF, 0x101A, 0xA5, 0xF1, 0x02, 0x60, 0x8C, 0x9E, 0xEB, 0xAC, 15)
PKEY_DateAccessed  = _make_pkey(0xB725F130, 0x47EF, 0x101A, 0xA5, 0xF1, 0x02, 0x60, 0x8C, 0x9E, 0xEB, 0xAC, 16)
PKEY_ItemTypeText  = _make_pkey(0xB725F130, 0x47EF, 0x101A, 0xA5, 0xF1, 0x02, 0x60, 0x8C, 0x9E, 0xEB, 0xAC, 4)
PKEY_FileAttributes = _make_pkey(0xB725F130, 0x47EF, 0x101A, 0xA5, 0xF1, 0x02, 0x60, 0x8C, 0x9E, 0xEB, 0xAC, 13)
PKEY_ParsingPath   = _make_pkey(0x28636AA6, 0x953D, 0x11D2, 0xB5, 0xD6, 0x00, 0xC0, 0x4F, 0xD9, 0x18, 0xD0, 30)

SFGAO_FOLDER     = 0x20000000
SFGAO_FILESYSTEM  = 0x40000000
SFGAO_HASSUBFOLDER = 0x80000000
SFGAO_STREAM     = 0x00400000
SFGAO_LINK       = 0x00010000
SFGAO_HIDDEN     = 0x00080000
SFGAO_READONLY   = 0x00040000
SFGAO_COMPRESSED = 0x04000000
SFGAO_ENCRYPTED  = 0x00002000
SFGAO_SYSTEM     = 0x00001000

SIGDN_NORMALDISPLAY           = 0
SIGDN_PARENTRELATIVE          = 0x80018001
SIGDN_DESKTOPABSOLUTEPARSING  = 0x80028000
SIGDN_FILESYSPATH             = 0x80058000

SHCONTF_FOLDERS             = 0x0020
SHCONTF_NONFOLDERS          = 0x0040
SHCONTF_INCLUDEHIDDEN       = 0x0080
SHCONTF_INCLUDESUPERHIDDEN  = 0x10000
SHCONTF_STORAGE             = 0x0200

FOF_ALLOW_UNDO        = 0x0040
FOF_NOCONFIRMMKDIR    = 0x0200
FOF_RENAMEONCOLLISION = 0x0008
FOF_WANTNUKEWARNING   = 0x4000
FOF_NO_UI             = 0x0614



def _call_vtbl(obj, index, restype, *argtypes_args):
    vtbl = ctypes.cast(obj.lpVtbl, ctypes.POINTER(ctypes.c_void_p))
    func_ptr = vtbl[index]
    argtypes_list = [ctypes.c_void_p] + [ctypes.c_void_p for _ in argtypes_args]
    func = ctypes.CFUNCTYPE(restype, *argtypes_list)(func_ptr)
    args = []
    for _, value in argtypes_args:
        if isinstance(value, ctypes.c_void_p):
            args.append(value)
        else:
            args.append(ctypes.cast(value, ctypes.c_void_p))
    return func(ctypes.byref(obj), *args)



IID_IShellItem = _make_guid(0x43826D1E, 0xE718, 0x42EE, 0xBC, 0x55, 0xA1, 0xE2, 0x61, 0xC3, 0x7B, 0xFE)


class IShellItem(ctypes.Structure):
    _fields_ = [("lpVtbl", ctypes.c_void_p)]

    def GetDisplayName(self, sigdn: int) -> str:
        _ensure_com()
        pstr = ctypes.c_wchar_p()
        hr = _call_vtbl(self, 5, ctypes.c_ulong,
                        (ctypes.c_ulong, sigdn),
                        (ctypes.POINTER(ctypes.c_wchar_p), ctypes.byref(pstr)))
        if hr < 0:
            raise OSError(f"IShellItem::GetDisplayName failed: 0x{hr & 0xFFFFFFFF:08X}")
        result = pstr.value or ""
        _ole32.CoTaskMemFree(pstr)
        return result

    def GetAttributes(self, sfgao_mask: int) -> int:
        _ensure_com()
        attr = ctypes.c_ulong(sfgao_mask)
        hr = _call_vtbl(self, 6, ctypes.c_ulong,
                        (ctypes.c_ulong, sfgao_mask),
                        (ctypes.POINTER(ctypes.c_ulong), ctypes.byref(attr)))
        if hr < 0:
            raise OSError(f"IShellItem::GetAttributes failed: 0x{hr & 0xFFFFFFFF:08X}")
        return attr.value

    def GetParent(self) -> Optional[IShellItem]:
        _ensure_com()
        parent = ctypes.POINTER(IShellItem)()
        hr = _call_vtbl(self, 4, ctypes.c_ulong,
                        (ctypes.POINTER(ctypes.POINTER(IShellItem)), ctypes.byref(parent)))
        if hr < 0:
            return None
        return parent

    def Release(self) -> int:
        return _call_vtbl(self, 2, ctypes.c_ulong)

    def AddRef(self) -> int:
        return _call_vtbl(self, 1, ctypes.c_ulong)


def create_shell_item(path: str) -> IShellItem:
    _ensure_com()
    item = ctypes.POINTER(IShellItem)()
    hr = _shell32.SHCreateItemFromParsingName(
        ctypes.c_wchar_p(path), None,
        ctypes.byref(IID_IShellItem), ctypes.byref(item))
    if hr < 0:
        raise OSError(f"SHCreateItemFromParsingName failed for '{path}': 0x{hr & 0xFFFFFFFF:08X}")
    return item



IID_IShellItem2 = _make_guid(0x7E9FB0D3, 0x919F, 0x4307, 0xAB, 0x2E, 0x9B, 0x18, 0x60, 0x31, 0x0C, 0x93)


class IShellItem2(ctypes.Structure):
    _fields_ = [("lpVtbl", ctypes.c_void_p)]

    def GetString(self, pkey: PROPERTYKEY) -> str:
        _ensure_com()
        pstr = ctypes.c_wchar_p()
        hr = _call_vtbl(self, 17, ctypes.c_ulong,
                        (ctypes.POINTER(PROPERTYKEY), ctypes.byref(pkey)),
                        (ctypes.POINTER(ctypes.c_wchar_p), ctypes.byref(pstr)))
        if hr < 0:
            return ""
        result = pstr.value or ""
        _ole32.CoTaskMemFree(pstr)
        return result

    def GetUInt64(self, pkey: PROPERTYKEY) -> int:
        _ensure_com()
        val = ctypes.c_ulonglong()
        hr = _call_vtbl(self, 19, ctypes.c_ulong,
                        (ctypes.POINTER(PROPERTYKEY), ctypes.byref(pkey)),
                        (ctypes.POINTER(ctypes.c_ulonglong), ctypes.byref(val)))
        if hr < 0:
            return 0
        return val.value

    def GetFileTime(self, pkey: PROPERTYKEY) -> Optional[int]:
        _ensure_com()
        ft = wintypes.FILETIME()
        hr = _call_vtbl(self, 15, ctypes.c_ulong,
                        (ctypes.POINTER(PROPERTYKEY), ctypes.byref(pkey)),
                        (ctypes.POINTER(wintypes.FILETIME), ctypes.byref(ft)))
        if hr < 0:
            return None
        return (ft.dwHighDateTime << 32) | ft.dwLowDateTime

    def Release(self) -> int:
        return _call_vtbl(self, 2, ctypes.c_ulong)


def _query_shell_item2(item) -> Optional[IShellItem2]:
    _ensure_com()
    si2 = ctypes.POINTER(IShellItem2)()
    hr = _call_vtbl(item.contents, 0, ctypes.c_ulong,
                    (ctypes.POINTER(GUID), ctypes.byref(IID_IShellItem2)),
                    (ctypes.POINTER(ctypes.POINTER(IShellItem2)), ctypes.byref(si2)))
    if hr < 0:
        return None
    return si2



class ShellEntry:
    __slots__ = ("name", "full_path", "is_dir", "size", "modified", "attributes")

    def __init__(self, name: str, full_path: str, is_dir: bool, size: int, modified: int, attributes: int):
        self.name = name
        self.full_path = full_path
        self.is_dir = is_dir
        self.size = size
        self.modified = modified
        self.attributes = attributes


def enum_folder(path: str) -> list[ShellEntry]:
    results = []
    try:
        with os.scandir(path) as it:
            for entry in it:
                try:
                    st = entry.stat()
                    is_dir = entry.is_dir()
                    attrs = 0
                    if is_dir:
                        attrs |= SFGAO_FOLDER
                    results.append(ShellEntry(
                        entry.name, entry.path, is_dir,
                        st.st_size if not is_dir else 0,
                        int(st.st_mtime),
                        attrs))
                except OSError:
                    pass
    except OSError:
        pass
    return results


FO_MOVE   = 0x0001
FO_COPY   = 0x0002
FO_DELETE = 0x0003
FO_RENAME = 0x0004

FOF_ALLOWUNDO          = 0x0040
FOF_NOCONFIRMMKDIR     = 0x0200
FOF_RENAMEONCOLLISION  = 0x0008
FOF_WANTNUKEWARNING    = 0x4000
FOF_NO_UI              = 0x0614
FOF_SILENT             = 0x0004
FOF_NOCONFIRMATION     = 0x0010

class SHFILEOPSTRUCTW(ctypes.Structure):
    _fields_ = [
        ("hwnd", wintypes.HWND),
        ("wFunc", wintypes.UINT),
        ("pFrom", wintypes.LPCWSTR),
        ("pTo", wintypes.LPCWSTR),
        ("fFlags", wintypes.WORD),
        ("fAnyOperationsAborted", wintypes.BOOL),
        ("hNameMappings", ctypes.c_void_p),
        ("lpszProgressTitle", wintypes.LPCWSTR),
    ]

_SHFILEOPSTRUCTW = SHFILEOPSTRUCTW

def _double_null(paths: list[str]) -> str:
    return "\0".join(paths) + "\0\0"

def copy_files(sources: list[str], dest_dir: str) -> None:
    if not sources:
        return
    op = _SHFILEOPSTRUCTW()
    op.wFunc = FO_COPY
    op.pFrom = _double_null(sources)
    op.pTo = dest_dir + "\0\0"
    op.fFlags = FOF_ALLOWUNDO | FOF_RENAMEONCOLLISION | FOF_NOCONFIRMMKDIR | FOF_NO_UI
    result = _shell32.SHFileOperationW(ctypes.byref(op))
    if result != 0:
        raise OSError(f"SHFileOperationW(COPY) failed: {result}")
    if op.fAnyOperationsAborted:
        raise OSError("SHFileOperationW(COPY) aborted by user")

def move_files(sources: list[str], dest_dir: str) -> None:
    if not sources:
        return
    op = _SHFILEOPSTRUCTW()
    op.wFunc = FO_MOVE
    op.pFrom = _double_null(sources)
    op.pTo = dest_dir + "\0\0"
    op.fFlags = FOF_ALLOWUNDO | FOF_RENAMEONCOLLISION | FOF_NOCONFIRMMKDIR | FOF_NO_UI
    result = _shell32.SHFileOperationW(ctypes.byref(op))
    if result != 0:
        raise OSError(f"SHFileOperationW(MOVE) failed: {result}")
    if op.fAnyOperationsAborted:
        raise OSError("SHFileOperationW(MOVE) aborted by user")

def delete_files(paths: list[str], to_recycle_bin: bool = True) -> None:
    if not paths:
        return
    op = _SHFILEOPSTRUCTW()
    op.wFunc = FO_DELETE
    op.pFrom = _double_null(paths)
    op.pTo = ""
    flags = FOF_ALLOWUNDO | FOF_NO_UI
    if not to_recycle_bin:
        flags |= FOF_WANTNUKEWARNING
    op.fFlags = flags
    result = _shell32.SHFileOperationW(ctypes.byref(op))
    if result != 0:
        raise OSError(f"SHFileOperationW(DELETE) failed: {result}")
    if op.fAnyOperationsAborted:
        raise OSError("SHFileOperationW(DELETE) aborted by user")

def rename_file(old_path: str, new_name: str) -> None:
    parent = os.path.dirname(old_path)
    new_path = os.path.join(parent, new_name) if parent else new_name
    op = _SHFILEOPSTRUCTW()
    op.wFunc = FO_RENAME
    op.pFrom = old_path + "\0\0"
    op.pTo = new_path + "\0\0"
    op.fFlags = FOF_ALLOWUNDO | FOF_RENAMEONCOLLISION | FOF_NO_UI
    result = _shell32.SHFileOperationW(ctypes.byref(op))
    if result != 0:
        raise OSError(f"SHFileOperationW(RENAME) failed: {result}")
    if op.fAnyOperationsAborted:
        raise OSError("SHFileOperationW(RENAME) aborted by user")

def new_folder(parent_dir: str, name: str) -> str:
    full_path = os.path.join(parent_dir, name)
    os.makedirs(full_path, exist_ok=True)
    return full_path


def open_item(path: str) -> None:
    _shell32.ShellExecuteW(None, None, ctypes.c_wchar_p(path), None, None, 1)


def get_item_properties(path: str) -> dict:
    _ensure_com()
    try:
        si = create_shell_item(path)
        try:
            si2 = _query_shell_item2(si)
            if not si2:
                return {}
            try:
                attrs = si.contents.GetAttributes(
                    SFGAO_FOLDER | SFGAO_FILESYSTEM | SFGAO_HIDDEN |
                    SFGAO_LINK | SFGAO_READONLY | SFGAO_COMPRESSED |
                    SFGAO_ENCRYPTED | SFGAO_SYSTEM | SFGAO_STREAM)
                return {
                    "size": si2.contents.GetUInt64(PKEY_Size),
                    "modified": si2.contents.GetFileTime(PKEY_DateModified) or 0,
                    "created": si2.contents.GetFileTime(PKEY_DateCreated) or 0,
                    "accessed": si2.contents.GetFileTime(PKEY_DateAccessed) or 0,
                    "type_text": si2.contents.GetString(PKEY_ItemTypeText),
                    "is_dir": bool(attrs & SFGAO_FOLDER),
                    "is_hidden": bool(attrs & SFGAO_HIDDEN),
                    "is_system": bool(attrs & SFGAO_SYSTEM),
                    "is_link": bool(attrs & SFGAO_LINK),
                    "is_readonly": bool(attrs & SFGAO_READONLY),
                    "is_compressed": bool(attrs & SFGAO_COMPRESSED),
                    "is_encrypted": bool(attrs & SFGAO_ENCRYPTED),
                }
            finally:
                si2.contents.Release()
        finally:
            si.contents.Release()
    except OSError:
        return {}
