import re
import shlex

from control_center.config import AUDIO_PREF_FILE, STEP
from control_center.infra.commands import command_output, command_run, run_detached, shell_output
from control_center.utils import clamp


def read_audio_preferences() -> dict[str, str]:
    preferences = {}
    try:
        lines = AUDIO_PREF_FILE.read_text().splitlines()
    except Exception:
        return preferences

    for line in lines:
        try:
            tokens = shlex.split(line, posix=True)
        except ValueError:
            continue
        if not tokens or "=" not in tokens[0]:
            continue
        key, value = tokens[0].split("=", 1)
        preferences[key] = value
    return preferences


def write_audio_preferences(preferences: dict[str, str]) -> None:
    AUDIO_PREF_FILE.parent.mkdir(parents=True, exist_ok=True)
    keys = ("PREFERRED_SINK", "PREFERRED_SOURCE", "PREFERRED_SOURCE_VOLUME")
    content = "".join(
        f"{key}={shlex.quote(preferences.get(key, ''))}\n"
        for key in keys
        if key in preferences
    )
    AUDIO_PREF_FILE.write_text(content)


def save_audio_preference(key: str, value: str) -> None:
    preferences = read_audio_preferences()
    preferences[key] = value
    write_audio_preferences(preferences)


def preferred_input_volume() -> int | None:
    raw = read_audio_preferences().get("PREFERRED_SOURCE_VOLUME", "").strip().rstrip("%")
    try:
        return clamp(int(float(raw)))
    except Exception:
        return None


def current_output_volume() -> int:
    value = shell_output("pactl get-sink-volume @DEFAULT_SINK@ | awk 'match($0, /[0-9]+%/) {v=substr($0, RSTART, RLENGTH); sub(/%/, \"\", v); print v; exit}'")
    try:
        return clamp(int(value))
    except Exception:
        return 0


def current_input_volume() -> int:
    value = shell_output("pactl get-source-volume @DEFAULT_SOURCE@ | awk 'match($0, /[0-9]+%/) {v=substr($0, RSTART, RLENGTH); sub(/%/, \"\", v); print v; exit}'")
    try:
        return clamp(int(value))
    except Exception:
        return 0


def set_output_volume(value: int) -> None:
    run_detached(["wpctl", "set-volume", "-l", "1", "@DEFAULT_AUDIO_SINK@", f"{clamp(value)}%"])


def toggle_output_mute() -> None:
    run_detached(["pactl", "set-sink-mute", "@DEFAULT_SINK@", "toggle"])


def set_output_muted(muted: bool) -> None:
    run_detached(["pactl", "set-sink-mute", "@DEFAULT_SINK@", "1" if muted else "0"])


def set_input_volume(value: int) -> None:
    volume = clamp(value)
    command_run(["pactl", "set-source-volume", "@DEFAULT_SOURCE@", f"{volume}%"], timeout=1.0)
    save_audio_preference("PREFERRED_SOURCE_VOLUME", f"{volume}%")


def toggle_input_mute() -> None:
    run_detached(["pactl", "set-source-mute", "@DEFAULT_SOURCE@", "toggle"])


def set_input_muted(muted: bool) -> None:
    run_detached(["pactl", "set-source-mute", "@DEFAULT_SOURCE@", "1" if muted else "0"])


def audio_status() -> tuple[str, str]:
    muted = shell_output("pactl get-sink-mute @DEFAULT_SINK@ | awk '{print $2}'")
    volume = current_output_volume()
    return (f"Muted · {volume}%" if muted == "yes" else f"{volume}%"), ("off" if muted == "yes" else "on")


def mic_status() -> tuple[str, str]:
    muted = shell_output("pactl get-source-mute @DEFAULT_SOURCE@ | awk '{print $2}'")
    return ("Muted" if muted == "yes" else "On"), ("off" if muted == "yes" else "on")


def audio_outputs() -> list[tuple[str, list[str]]]:
    default = command_output(["pactl", "get-default-sink"])
    rows = []
    current = ""
    for line in command_output(["pactl", "list", "sinks"], timeout=0.8).splitlines():
        stripped = line.strip()
        if stripped.startswith("Name:"):
            current = stripped.split("Name:", 1)[1].strip()
        elif stripped.startswith("Description:") and current:
            desc = stripped.split("Description:", 1)[1].strip()
            mark = "* " if current == default else "  "
            rows.append((f"  {mark}{desc[:34]}", ["audio-output", current]))
            current = ""
    return rows[:5]


def audio_inputs() -> list[tuple[str, list[str]]]:
    default = command_output(["pactl", "get-default-source"])
    rows = []
    current = ""
    for line in command_output(["pactl", "list", "sources"], timeout=0.8).splitlines():
        stripped = line.strip()
        if stripped.startswith("Name:"):
            current = stripped.split("Name:", 1)[1].strip()
        elif stripped.startswith("Description:") and current and not current.endswith(".monitor"):
            desc = stripped.split("Description:", 1)[1].strip()
            mark = "* " if current == default else "  "
            rows.append((f"  {mark}{desc[:34]}", ["audio-input", current]))
            current = ""
    return rows[:5]


def move_sink_inputs(sink: str) -> None:
    for line in command_output(["pactl", "list", "short", "sink-inputs"], timeout=1.0).splitlines():
        input_id = line.split("\t", 1)[0].strip()
        if input_id:
            command_run(["pactl", "move-sink-input", input_id, sink], timeout=1.0)


def move_source_outputs(source: str) -> None:
    for line in command_output(["pactl", "list", "short", "source-outputs"], timeout=1.0).splitlines():
        output_id = line.split("\t", 1)[0].strip()
        if output_id:
            command_run(["pactl", "move-source-output", output_id, source], timeout=1.0)


def set_default_output_device(sink: str) -> tuple[bool, str]:
    ok, output = command_run(["pactl", "set-default-sink", sink], timeout=2.0)
    if not ok:
        return False, output
    move_sink_inputs(sink)
    save_audio_preference("PREFERRED_SINK", sink)
    current = command_output(["pactl", "get-default-sink"], timeout=1.0)
    return current == sink, output


def set_default_input_device(source: str) -> tuple[bool, str]:
    ok, output = command_run(["pactl", "set-default-source", source], timeout=2.0)
    if not ok:
        return False, output
    volume = preferred_input_volume()
    if volume is not None:
        command_run(["pactl", "set-source-volume", source, f"{volume}%"], timeout=1.0)
    move_source_outputs(source)
    save_audio_preference("PREFERRED_SOURCE", source)
    current = command_output(["pactl", "get-default-source"], timeout=1.0)
    return current == source, output


def enforce_preferred_input_volume() -> None:
    preferences = read_audio_preferences()
    preferred_source = preferences.get("PREFERRED_SOURCE", "")
    preferred_volume = preferred_input_volume()
    current_source = command_output(["pactl", "get-default-source"], timeout=1.0)

    if not preferred_source or preferred_volume is None or current_source != preferred_source:
        return

    if current_input_volume() != preferred_volume:
        command_run(["pactl", "set-source-volume", preferred_source, f"{preferred_volume}%"], timeout=1.0)


def app_audio_outputs() -> list[dict[str, str | int | bool]]:
    entries = []
    current: dict[str, str | int | bool] | None = None
    for line in command_output(["pactl", "list", "sink-inputs"], timeout=1.2).splitlines():
        if line.startswith("Sink Input #"):
            if current:
                entries.append(current)
            current = {"id": int(line.rsplit("#", 1)[1]), "name": "Unknown", "media": "", "volume": 0, "muted": False}
            continue
        if current is None:
            continue
        stripped = line.strip()
        if stripped.startswith("Mute:"):
            current["muted"] = stripped.endswith("yes")
        elif stripped.startswith("Volume:"):
            match = re.search(r"/\s*(\d+)%", stripped)
            if match:
                current["volume"] = clamp(int(match.group(1)))
        elif stripped.startswith("application.name ="):
            current["name"] = stripped.split("=", 1)[1].strip().strip('"')
        elif stripped.startswith("media.name ="):
            current["media"] = stripped.split("=", 1)[1].strip().strip('"')
    if current:
        entries.append(current)
    return entries
