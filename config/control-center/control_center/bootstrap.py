import os
import sys
from pathlib import Path


def ensure_layer_shell_preload() -> None:
    if os.environ.get("LNX_DF_LAYER_SHELL_PRELOAD_CHECKED") == "1":
        return
    current_preload = os.environ.get("LD_PRELOAD", "")
    if "libgtk4-layer-shell" in current_preload:
        return
    for candidate in ("/usr/lib/libgtk4-layer-shell.so", "/usr/lib64/libgtk4-layer-shell.so"):
        if Path(candidate).exists():
            env = os.environ.copy()
            env["LNX_DF_LAYER_SHELL_PRELOAD_CHECKED"] = "1"
            env["LD_PRELOAD"] = f"{candidate}:{current_preload}" if current_preload else candidate
            os.execvpe(sys.executable, [sys.executable, *sys.argv], env)
