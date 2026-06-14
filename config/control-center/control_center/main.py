import argparse
import signal

from control_center.app import ControlCenter
from control_center.infra.process import existing_control_center_pid, signal_existing


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--toggle", action="store_true")
    parser.add_argument("--daemon", action="store_true")
    args = parser.parse_args()
    if args.toggle and signal_existing(signal.SIGUSR1):
        return
    if args.daemon and existing_control_center_pid() is not None:
        return
    app = ControlCenter(start_hidden=args.daemon)
    raise SystemExit(app.run([]))
