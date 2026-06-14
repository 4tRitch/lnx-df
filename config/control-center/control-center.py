#!/usr/bin/env python3
from control_center.bootstrap import ensure_layer_shell_preload

ensure_layer_shell_preload()

from control_center.main import main  # noqa: E402


if __name__ == "__main__":
    main()
