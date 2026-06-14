import subprocess


def command_output(command: list[str], timeout: float = 0.35) -> str:
    try:
        return subprocess.check_output(command, text=True, stderr=subprocess.DEVNULL, timeout=timeout).strip()
    except Exception:
        return ""


def shell_output(command: str, timeout: float = 0.35) -> str:
    try:
        return subprocess.check_output(command, text=True, shell=True, stderr=subprocess.DEVNULL, timeout=timeout).strip()
    except Exception:
        return ""


def run_detached(command: list[str]) -> None:
    subprocess.Popen(command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)


def command_succeeds(command: list[str], timeout: float = 12.0) -> bool:
    try:
        return subprocess.run(command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=timeout).returncode == 0
    except Exception:
        return False


def command_run(command: list[str], timeout: float = 12.0) -> tuple[bool, str]:
    try:
        result = subprocess.run(command, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=timeout)
        return result.returncode == 0, result.stdout.strip()
    except Exception as error:
        return False, str(error)
