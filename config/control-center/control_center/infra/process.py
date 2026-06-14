import os
import signal
from pathlib import Path

from control_center.config import PID_FILE


def pid_is_control_center(pid: int) -> bool:
    try:
        cmdline = Path(f"/proc/{pid}/cmdline").read_text(errors="ignore")
    except Exception:
        return False
    return "control-center.py" in cmdline or "control_center" in cmdline


def existing_control_center_pid() -> int | None:
    if not PID_FILE.exists():
        return None
    try:
        pid = int(PID_FILE.read_text().strip())
        if not pid_is_control_center(pid):
            PID_FILE.unlink(missing_ok=True)
            return None
        return pid
    except ProcessLookupError:
        PID_FILE.unlink(missing_ok=True)
        return None
    except Exception:
        return None


def signal_existing(sig: signal.Signals = signal.SIGUSR1) -> bool:
    pid = existing_control_center_pid()
    if pid is None:
        return False
    try:
        os.kill(pid, sig)
        return True
    except ProcessLookupError:
        PID_FILE.unlink(missing_ok=True)
        return False
    except Exception:
        return False


def write_pid() -> None:
    PID_FILE.write_text(str(os.getpid()))


def cleanup_pid() -> None:
    try:
        if PID_FILE.exists() and PID_FILE.read_text().strip() == str(os.getpid()):
            PID_FILE.unlink()
    except Exception:
        pass
