from __future__ import annotations

import os
import sys
from pathlib import Path

_script_dir = Path(__file__).parent.resolve()
_local_dll_path = _script_dir / ".dll"

if _local_dll_path.exists():
    dll_path = str(_local_dll_path)
    current_path = os.environ.get("PATH", "")
    if dll_path not in current_path:
        os.environ["PATH"] = dll_path + os.pathsep + current_path
        if str(_script_dir) not in sys.path:
            sys.path.insert(0, str(_script_dir))

def _find_mpv_dll():
    path_env = os.environ.get("PATH", "")
    for path in path_env.split(os.pathsep):
        path = path.strip('"')
        if not path:
            continue
        p = Path(path)
        for dll_name in ["libmpv-2.dll", "mpv-2.dll", "mpv-1.dll"]:
            dll_path = p / dll_name
            if dll_path.exists():
                return str(dll_path)
    return None

_mpv_dll_path = _find_mpv_dll()
if _mpv_dll_path:
    pass
else:
    pass
