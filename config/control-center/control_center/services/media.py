import hashlib
import urllib.parse
import urllib.request
from pathlib import Path

from control_center.config import ALLOWED_PLAYER_HINTS, ART_CACHE, DENIED_PLAYER_HINTS
from control_center.infra.commands import command_output


def allowed_player(player: str) -> bool:
    name = player.lower()
    if any(hint in name for hint in DENIED_PLAYER_HINTS):
        return False
    return any(hint in name for hint in ALLOWED_PLAYER_HINTS)


def selected_player() -> str:
    players = [p.strip() for p in command_output(["playerctl", "-l"], timeout=0.5).splitlines() if p.strip()]
    allowed = [p for p in players if allowed_player(p)]
    if not allowed:
        return ""
    for player in allowed:
        if command_output(["playerctl", "-p", player, "status"], timeout=0.2) == "Playing":
            return player
    return allowed[0]


def playerctl_args(player: str, *args: str) -> list[str]:
    return ["playerctl", "-p", player, *args]


def player_status() -> tuple[str, str, str, int, int, bool, str, str]:
    player = selected_player()
    if not player:
        return "No media", "", "", 0, 0, False, "", ""
    title = command_output(playerctl_args(player, "metadata", "title"))
    artist = command_output(playerctl_args(player, "metadata", "artist"))
    state = command_output(playerctl_args(player, "status"))
    length_raw = command_output(playerctl_args(player, "metadata", "mpris:length"))
    position_raw = command_output(playerctl_args(player, "position"))
    art_url = command_output(playerctl_args(player, "metadata", "mpris:artUrl"))
    try:
        length = int(int(length_raw) / 1_000_000) if length_raw else 0
    except Exception:
        length = 0
    try:
        position = int(float(position_raw)) if position_raw else 0
    except Exception:
        position = 0
    if not title:
        return "No media", "", "", 0, 0, False, "", player
    playing = state == "Playing"
    return title, artist or state, ("" if playing else ""), position, length, playing, art_url, player


def cached_art_path(art_url: str) -> str:
    if not art_url:
        return ""
    parsed = urllib.parse.urlparse(art_url)
    if parsed.scheme == "file":
        return urllib.parse.unquote(parsed.path)
    if parsed.scheme not in {"http", "https"}:
        return ""
    ART_CACHE.mkdir(parents=True, exist_ok=True)
    suffix = Path(parsed.path).suffix or ".jpg"
    target = ART_CACHE / f"{hashlib.sha256(art_url.encode()).hexdigest()}{suffix}"
    if target.exists() and target.stat().st_size > 0:
        return str(target)
    try:
        req = urllib.request.Request(art_url, headers={"User-Agent": "lnx-df-control-center"})
        with urllib.request.urlopen(req, timeout=1.5) as response:
            target.write_bytes(response.read())
        return str(target)
    except Exception:
        return ""
