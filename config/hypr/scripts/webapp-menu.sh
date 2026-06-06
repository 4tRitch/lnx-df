#!/usr/bin/env bash
set -euo pipefail

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
app_dir="${data_home}/applications"
managed_root="${data_home}/lnx-df-webapps"
meta_dir="${managed_root}/entries"
icon_dir="${managed_root}/icons"
launcher_script="${config_home}/hypr/scripts/webapp-launch.sh"
runtime_dir="${XDG_RUNTIME_DIR:-/tmp}"
cancel_stamp_file="${runtime_dir}/lnx-df-webapps-cancel.stamp"
cancel_close_threshold_ms=350

notify() {
  local title="$1" message="$2"
  command -v notify-send >/dev/null 2>&1 && notify-send "$title" "$message" || true
}

require_tools() {
  command -v python3 >/dev/null 2>&1 || {
    notify "WebApps" "python3 no está instalado"
    exit 1
  }

  command -v rofi >/dev/null 2>&1 || {
    notify "WebApps" "rofi no está instalado"
    exit 1
  }
}

ensure_dirs() {
  mkdir -p "$app_dir" "$meta_dir" "$icon_dir"
}

now_ms() {
  date +%s%3N
}

clear_cancel_state() {
  rm -f "$cancel_stamp_file"
}

cancel_requests_close() {
  local now prev delta

  now="$(now_ms)"
  prev=
  [[ -f "$cancel_stamp_file" ]] && prev="$(<"$cancel_stamp_file")"
  printf '%s\n' "$now" > "$cancel_stamp_file"

  if [[ -n "$prev" ]]; then
    delta=$((now - prev))
    if (( delta >= 0 && delta <= cancel_close_threshold_ms )); then
      clear_cancel_state
      return 0
    fi
  fi

  return 1
}

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s\n' "$value"
}

slugify() {
  python3 - "$1" <<'PY'
import re
import sys
value = sys.argv[1].strip().lower()
value = re.sub(r"[^a-z0-9]+", "-", value).strip("-")
print(value or "webapp")
PY
}

normalize_url() {
  python3 - "$1" <<'PY'
from urllib.parse import urlparse, urlunparse
import sys

raw = sys.argv[1].strip()
if not raw:
    raise SystemExit(1)

if "://" not in raw:
    raw = "https://" + raw

parts = urlparse(raw)
if parts.scheme not in {"http", "https"} or not parts.netloc:
    raise SystemExit(1)

path = parts.path or "/"
print(urlunparse((parts.scheme, parts.netloc, path, parts.params, parts.query, parts.fragment)))
PY
}

derive_name() {
  python3 - "$1" <<'PY'
from html import unescape
from urllib.parse import urlparse
from urllib.request import Request, urlopen
import re
import sys

url = sys.argv[1]
request = Request(url, headers={"User-Agent": "Mozilla/5.0"})
html = ""

try:
    with urlopen(request, timeout=8) as response:
        content_type = response.headers.get("Content-Type", "")
        if "text/html" in content_type:
            html = response.read(262144).decode("utf-8", "ignore")
except Exception:
    html = ""

patterns = [
    r'<meta[^>]+property=["\\\']og:site_name["\\\'][^>]+content=["\\\']([^"\\\']+)["\\\']',
    r'<meta[^>]+name=["\\\']application-name["\\\'][^>]+content=["\\\']([^"\\\']+)["\\\']',
    r"<title[^>]*>(.*?)</title>",
]

for pattern in patterns:
    match = re.search(pattern, html, re.IGNORECASE | re.DOTALL)
    if match:
        value = re.sub(r"\s+", " ", unescape(match.group(1))).strip()
        if value:
            print(value[:80])
            raise SystemExit(0)

host = urlparse(url).hostname or "webapp"
host = re.sub(r"^www\.", "", host, flags=re.IGNORECASE)
parts = [segment for segment in re.split(r"[^A-Za-z0-9]+", host) if segment]
if not parts:
    print("WebApp")
else:
    print(" ".join(segment.capitalize() for segment in parts))
PY
}

pick_unique_id() {
  local base_id="$1" app_id="$1" counter=2

  while [[ -e "${meta_dir}/${app_id}.conf" || -e "${app_dir}/lnx-df-webapp-${app_id}.desktop" ]]; do
    app_id="${base_id}-${counter}"
    counter=$((counter + 1))
  done

  printf '%s\n' "$app_id"
}

fetch_icon() {
  local app_id="$1" url="$2"

  python3 - "$app_id" "$url" "$icon_dir" <<'PY'
from html import unescape
from pathlib import Path
from urllib.parse import urljoin, urlparse
from urllib.request import Request, urlopen
import mimetypes
import re
import sys

app_id, url, icon_dir = sys.argv[1:]

def read_url(target, timeout=8):
    request = Request(target, headers={"User-Agent": "Mozilla/5.0"})
    with urlopen(request, timeout=timeout) as response:
        return response.read(512000), response.headers.get("Content-Type", "")

def extension_for(content_type, fallback_url):
    content_type = (content_type or "").split(";", 1)[0].strip().lower()
    mapping = {
        "image/png": ".png",
        "image/x-icon": ".ico",
        "image/vnd.microsoft.icon": ".ico",
        "image/svg+xml": ".svg",
        "image/jpeg": ".jpg",
        "image/webp": ".webp",
        "image/gif": ".gif",
    }
    if content_type in mapping:
        return mapping[content_type]
    guessed = mimetypes.guess_extension(content_type) if content_type else None
    if guessed:
        return guessed
    suffix = Path(urlparse(fallback_url).path).suffix
    return suffix if suffix else ".ico"

def icon_targets(page_url):
    parsed = urlparse(page_url)
    origin = f"{parsed.scheme}://{parsed.netloc}"
    host = parsed.netloc
    targets = []

    try:
        html, content_type = read_url(page_url)
        if "text/html" in content_type:
            text = html.decode("utf-8", "ignore")
            pattern = re.compile(
                r'<link[^>]+rel=["\\\']([^"\\\']*icon[^"\\\']*)["\\\'][^>]+href=["\\\']([^"\\\']+)["\\\']',
                re.IGNORECASE,
            )
            for _, href in pattern.findall(text):
                href = unescape(href.strip())
                if href:
                    targets.append(urljoin(page_url, href))
    except Exception:
        pass

    targets.extend((
        f"{origin}/favicon.ico",
        f"{origin}/favicon.png",
        f"https://www.google.com/s2/favicons?domain={host}&sz=256",
        f"https://icons.duckduckgo.com/ip3/{host}.ico",
    ))

    seen = set()
    for target in targets:
        if target not in seen:
            seen.add(target)
            yield target

for target in icon_targets(url):
    try:
        data, content_type = read_url(target, timeout=6)
        if not data:
            continue
        path = Path(icon_dir) / f"{app_id}{extension_for(content_type, target)}"
        path.write_bytes(data)
        print(path)
        raise SystemExit(0)
    except Exception:
        continue

raise SystemExit(1)
PY
}

write_meta() {
  local app_id="$1" name="$2" url="$3" class_name="$4" icon_path="$5"

  {
    printf 'APP_ID=%q\n' "$app_id"
    printf 'NAME=%q\n' "$name"
    printf 'URL=%q\n' "$url"
    printf 'CLASS=%q\n' "$class_name"
    printf 'ICON=%q\n' "$icon_path"
  } > "${meta_dir}/${app_id}.conf"
}

write_desktop_entry() {
  local app_id="$1" name="$2" url="$3" class_name="$4" icon_path="$5" desktop_path
  desktop_path="${app_dir}/lnx-df-webapp-${app_id}.desktop"

  {
    printf '[Desktop Entry]\n'
    printf 'Version=1.0\n'
    printf 'Type=Application\n'
    printf 'Name=%s\n' "$name"
    printf 'Comment=WebApp para %s\n' "$url"
    printf 'Exec=%s --id %s\n' "$launcher_script" "$app_id"
    printf 'Terminal=false\n'
    printf 'Categories=Network;WebBrowser;\n'
    printf 'StartupWMClass=%s\n' "$class_name"
    printf 'X-LnxDf-WebApp=true\n'
    if [[ -n "$icon_path" ]]; then
      printf 'Icon=%s\n' "$icon_path"
    else
      printf 'Icon=web-browser\n'
    fi
  } > "$desktop_path"
}

desktop_database_refresh() {
  command -v update-desktop-database >/dev/null 2>&1 || return 0
  update-desktop-database "$app_dir" >/dev/null 2>&1 || true
}

create_webapp() {
  local raw_url="$1" requested_name="${2:-}" normalized_url name base_id app_id class_name icon_path=

  normalized_url="$(normalize_url "$raw_url")" || {
    notify "WebApps" "URL inválida: ${raw_url}"
    return 1
  }

  if [[ -n "$requested_name" ]]; then
    name="$(trim "$requested_name")"
  else
    name="$(derive_name "$normalized_url")"
  fi

  [[ -n "$name" ]] || name="WebApp"
  base_id="$(slugify "$name")"
  app_id="$(pick_unique_id "$base_id")"
  class_name="lnx-df-webapp-${app_id}"

  if icon_path="$(fetch_icon "$app_id" "$normalized_url" 2>/dev/null)"; then
    :
  else
    icon_path=""
  fi

  write_meta "$app_id" "$name" "$normalized_url" "$class_name" "$icon_path"
  write_desktop_entry "$app_id" "$name" "$normalized_url" "$class_name" "$icon_path"
  desktop_database_refresh
  notify "WebApps" "Agregada ${name}"
}

list_entries() {
  python3 - "$meta_dir" "$app_dir" "$icon_dir" <<'PY'
from configparser import ConfigParser
from glob import glob
from pathlib import Path
import json
import re
import shlex
import sys
from urllib.parse import urlparse

meta_dir = Path(sys.argv[1])
app_dir = Path(sys.argv[2])
icon_dir = Path(sys.argv[3])
home = Path.home()
brave_root = home / ".config/BraveSoftware/Brave-Browser"

def parse_desktop(path: Path):
    parser = ConfigParser(interpolation=None)
    try:
        content = path.read_text(encoding="utf-8")
    except OSError:
        return None
    if "[Desktop Entry]" not in content:
        return None
    try:
        parser.read_string(content)
    except Exception:
        return None
    if not parser.has_section("Desktop Entry"):
        return None
    return parser["Desktop Entry"]

def parse_shell_kv(path: Path):
    result = {}
    try:
        for raw_line in path.read_text(encoding="utf-8").splitlines():
            line = raw_line.strip()
            if not line or "=" not in line:
                continue
            key, value = line.split("=", 1)
            try:
                parts = shlex.split(value, posix=True)
            except ValueError:
                parts = [value]
            result[key] = parts[0] if parts else ""
    except OSError:
        return {}
    return result

def best_browser_icon(profile_dir: str, app_id: str, desktop_icon: str):
    manifest_root = brave_root / profile_dir / "Web Applications" / "Manifest Resources" / app_id
    candidates = []
    for subdir in ("Icons", "Trusted Icons/Icons", "Icons Maskable", "Trusted Icons/Icons Maskable"):
        base = manifest_root / subdir
        if base.exists():
            for file in base.glob("*.*"):
                try:
                    size = int(file.stem)
                except ValueError:
                    size = 0
                candidates.append((size, str(file)))
    if candidates:
        return sorted(candidates)[-1][1]

    if desktop_icon:
        for pattern in (
            str(home / ".local/share/icons/hicolor/*/apps" / f"{desktop_icon}.*"),
            str(home / ".icons/*/apps" / f"{desktop_icon}.*"),
            f"/usr/share/icons/hicolor/*/apps/{desktop_icon}.*",
        ):
            matches = glob(pattern)
            if matches:
                return str(sorted(matches)[-1])

        if desktop_icon.startswith("/"):
            return desktop_icon

    return ""

def normalize_host_tokens(value: str):
    value = value.lower()
    return [token for token in re.split(r"[^a-z0-9]+", value) if token]

def infer_browser_url(profile_dir: str, name: str, app_id: str):
    stop_tokens = {"web", "app", "pwa", "site"}
    name_tokens = [token for token in normalize_host_tokens(name) if token not in stop_tokens]
    candidates = []

    def collect_from_pref(pref_path: Path, profile_bonus: int):
        if not pref_path.exists():
            return

        try:
            data = json.loads(pref_path.read_text())
        except Exception:
            return

        daily_metrics = data.get("web_apps", {}).get("daily_metrics", {})
        local_metric = data.get("web_app_install_metrics", {}).get(app_id, {})

        for url, meta in daily_metrics.items():
            host = urlparse(url).hostname or ""
            host_tokens = normalize_host_tokens(host)
            path_tokens = normalize_host_tokens(urlparse(url).path)
            url_tokens = set(host_tokens + path_tokens)
            score = profile_bonus
            name_match = bool(name_tokens and any(token in url_tokens for token in name_tokens))

            if meta.get("installed"):
                score += 50
            if name_match:
                score += 30
            elif name_tokens:
                score -= 40
            if app_id and app_id in url:
                score += 20
            if name.lower() in url.lower():
                score += 15

            launch_time = meta.get("lastShortcutLaunchTime", 0)
            if launch_time:
                score += 10

            install_source = meta.get("install_source")
            if install_source == local_metric.get("install_source") and local_metric.get("install_timestamp"):
                score += 5
            if install_source == app_metric.get("install_source") and app_timestamp:
                score += 5

            if score > 0:
                candidates.append((score, float(meta.get("foreground_duration_sec", 0)), float(meta.get("background_duration_sec", 0)), url))

    pref_path = brave_root / profile_dir / "Preferences"
    app_metric = {}
    if pref_path.exists():
        try:
            app_metric = json.loads(pref_path.read_text()).get("web_app_install_metrics", {}).get(app_id, {})
        except Exception:
            app_metric = {}
    app_timestamp = app_metric.get("install_timestamp")

    collect_from_pref(pref_path, 25)
    for other_pref in sorted(brave_root.glob("*/Preferences")):
        if other_pref == pref_path:
            continue
        collect_from_pref(other_pref, 0)

    if not candidates:
        return ""

    candidates.sort(reverse=True)
    return candidates[0][3]

def emit(source, app_id, name, url, desktop_path, icon_path, meta_path):
    print("\t".join((source, app_id, name, url, desktop_path, icon_path, meta_path)))

for meta_file in sorted(meta_dir.glob("*.conf")):
    namespace = parse_shell_kv(meta_file)
    app_id = namespace.get("APP_ID", meta_file.stem)
    emit(
        "managed",
        app_id,
        namespace.get("NAME", app_id),
        namespace.get("URL", ""),
        str(app_dir / f"lnx-df-webapp-{app_id}.desktop"),
        namespace.get("ICON", ""),
        str(meta_file),
    )

patterns = (
    "brave-*.desktop",
    "google-chrome-*.desktop",
    "chromium-*.desktop",
    "microsoft-edge-*.desktop",
    "vivaldi-*.desktop",
)

seen = set()

for pattern in patterns:
    for desktop_path in sorted(app_dir.glob(pattern)):
        section = parse_desktop(desktop_path)
        if not section:
            continue

        exec_value = section.get("Exec", "")
        if not exec_value or ("--app-id=" not in exec_value and "--app=" not in exec_value):
            continue

        app_id = desktop_path.stem
        if app_id in seen:
            continue
        seen.add(app_id)

        name = section.get("Name", app_id)
        desktop_icon = section.get("Icon", "")
        try:
            tokens = shlex.split(exec_value)
        except ValueError:
            tokens = exec_value.split()

        profile_dir = "Default"
        url = ""
        browser_appid = ""

        idx = 0
        while idx < len(tokens):
            token = tokens[idx]
            if token == "--profile-directory" and idx + 1 < len(tokens):
                profile_dir = tokens[idx + 1]
                idx += 2
                continue
            if token.startswith("--profile-directory="):
                profile_dir = token.split("=", 1)[1]
            elif token == "--app" and idx + 1 < len(tokens):
                url = tokens[idx + 1]
                idx += 2
                continue
            elif token.startswith("--app="):
                url = token.split("=", 1)[1]
            elif token == "--app-id" and idx + 1 < len(tokens):
                browser_appid = tokens[idx + 1]
                idx += 2
                continue
            elif token.startswith("--app-id="):
                browser_appid = token.split("=", 1)[1]
            idx += 1

        if not url and browser_appid:
            url = infer_browser_url(profile_dir, name, browser_appid)

        icon_path = best_browser_icon(profile_dir, browser_appid, desktop_icon)
        emit("browser", app_id, name, url, str(desktop_path), icon_path, profile_dir)
PY
}

delete_webapp_ids() {
  local spec source app_id desktop_file icon_ref meta_file found=0

  for spec in "$@"; do
    IFS=':' read -r source app_id <<< "$spec"

    case "$source" in
      managed)
        meta_file="${meta_dir}/${app_id}.conf"
        desktop_file="${app_dir}/lnx-df-webapp-${app_id}.desktop"

        if [[ -f "$meta_file" ]]; then
          ICON=
          # shellcheck disable=SC1090
          source "$meta_file"
          rm -f "$meta_file"
          if [[ -n ${ICON:-} ]]; then
            rm -f "$ICON"
          else
            rm -f "${icon_dir}/${app_id}".* 2>/dev/null || true
          fi
          found=1
        fi

        rm -f "$desktop_file"
        ;;
      browser)
        desktop_file="${app_dir}/${app_id}.desktop"
        if [[ -f "$desktop_file" ]]; then
          icon_ref="$(
            python3 - "$desktop_file" <<'PY'
from configparser import ConfigParser
import sys
parser = ConfigParser(interpolation=None)
with open(sys.argv[1], encoding="utf-8") as handle:
    parser.read_string(handle.read())
print(parser["Desktop Entry"].get("Icon", ""))
PY
          )"
          rm -f "$desktop_file"
          if [[ -n "$icon_ref" ]]; then
            rm -f "${data_home}/icons/hicolor/"*/apps/"${icon_ref}".* 2>/dev/null || true
          fi
          found=1
        fi
        ;;
    esac
  done

  desktop_database_refresh

  if (( found )); then
    notify "WebApps" "WebApps eliminadas"
  fi
}

rename_webapp() {
  local source="$1" app_id="$2" new_name="$3"
  local desktop_file meta_file tmp_file

  new_name="$(trim "$new_name")"
  [[ -n "$new_name" ]] || return 1

  case "$source" in
    managed)
      meta_file="${meta_dir}/${app_id}.conf"
      desktop_file="${app_dir}/lnx-df-webapp-${app_id}.desktop"
      [[ -f "$meta_file" && -f "$desktop_file" ]] || return 1

      APP_ID= NAME= URL= CLASS= ICON=
      # shellcheck disable=SC1090
      source "$meta_file"
      write_meta "$APP_ID" "$new_name" "$URL" "$CLASS" "${ICON:-}"
      python3 - "$desktop_file" "$new_name" <<'PY'
from configparser import ConfigParser
from pathlib import Path
import sys
path = Path(sys.argv[1])
name = sys.argv[2]
parser = ConfigParser(interpolation=None)
parser.optionxform = str
parser.read_string(path.read_text(encoding="utf-8"))
parser["Desktop Entry"]["Name"] = name
with path.open("w", encoding="utf-8") as handle:
    parser.write(handle, space_around_delimiters=False)
PY
      ;;
    browser)
      desktop_file="${app_dir}/${app_id}.desktop"
      [[ -f "$desktop_file" ]] || return 1
      python3 - "$desktop_file" "$new_name" <<'PY'
from configparser import ConfigParser
from pathlib import Path
import sys
path = Path(sys.argv[1])
name = sys.argv[2]
parser = ConfigParser(interpolation=None)
parser.optionxform = str
parser.read_string(path.read_text(encoding="utf-8"))
parser["Desktop Entry"]["Name"] = name
with path.open("w", encoding="utf-8") as handle:
    parser.write(handle, space_around_delimiters=False)
PY
      ;;
    *)
      return 1
      ;;
  esac

  desktop_database_refresh
  notify "WebApps" "Renombrada ${new_name}"
}

prompt_url() {
  rofi -dmenu -i -p 'webapp url'
}

prompt_name() {
  rofi -dmenu -i -p 'webapp name (optional)'
}

build_rofi_rows() {
  local mode="$1"
  local rows=()
  local source app_id name url desktop_file icon_path meta_path label row

  while IFS=$'\t' read -r source app_id name url desktop_file icon_path meta_path; do
    [[ -n "$source" ]] || continue

    case "$mode" in
      delete)
        if [[ -n "$url" ]]; then
          label="${name}  ·  ${url}"
        else
          label="${name}"
        fi
        ;;
      rename)
        if [[ -n "$url" ]]; then
          label="${name}  ·  ${url}"
        else
          label="${name}"
        fi
        ;;
      *)
        continue
        ;;
    esac

    if [[ -n "$icon_path" && -f "$icon_path" ]]; then
      printf -v row '%s\t%s\t%s' "${source}:${app_id}" "$label" "$icon_path"
    else
      printf -v row '%s\t%s\t%s' "${source}:${app_id}" "$label" ""
    fi
    rows+=("$row")
  done < <(list_entries)

  printf '%s\n' "${rows[@]}"
}

menu_create() {
  local url requested_name

  while true; do
    if ! url="$(prompt_url)"; then
      if cancel_requests_close; then
        return 2
      fi
      return 1
    fi

    clear_cancel_state
    [[ -n "$url" ]] || continue

    while true; do
      if ! requested_name="$(prompt_name)"; then
        if cancel_requests_close; then
          return 2
        fi
        break
      fi

      clear_cancel_state
      create_webapp "$url" "$requested_name"
      return 0
    done
  done
}

menu_delete() {
  local rows selection index selected_specs=()
  mapfile -t rows < <(build_rofi_rows delete)

  (( ${#rows[@]} > 0 )) || {
    notify "WebApps" "No hay webapps disponibles"
    return 1
  }

  if ! selection="$(
    {
      for row in "${rows[@]}"; do
        IFS=$'\t' read -r spec label icon_path <<< "$row"
        if [[ -n "$icon_path" ]]; then
          printf '%s\0icon\x1f%s\n' "$label" "$icon_path"
        else
          printf '%s\n' "$label"
        fi
      done
    } | rofi -dmenu -i -multi-select -show-icons -format i -p 'remove webapps' \
         -ballot-selected-str '' \
         -ballot-unselected-str '' \
         -theme-str 'window { width: 980px; }' \
         -theme-str 'listview { lines: 10; }' \
         -theme-str 'element-icon { size: 28px; }'
  )"; then
    if cancel_requests_close; then
      return 2
    fi
    return 1
  fi

  clear_cancel_state
  [[ -n "$selection" ]] || return 1

  while IFS= read -r index; do
    [[ -n "$index" ]] || continue
    IFS=$'\t' read -r spec _ <<< "${rows[$index]}"
    selected_specs+=("$spec")
  done <<< "$selection"

  (( ${#selected_specs[@]} > 0 )) || return 1
  delete_webapp_ids "${selected_specs[@]}"
  return 0
}

menu_rename() {
  local rows selection new_name spec source app_id

  while true; do
    mapfile -t rows < <(build_rofi_rows rename)

    (( ${#rows[@]} > 0 )) || {
      notify "WebApps" "No hay webapps disponibles"
      return 1
    }

    if ! selection="$(
      {
        for row in "${rows[@]}"; do
          IFS=$'\t' read -r spec label icon_path <<< "$row"
          if [[ -n "$icon_path" ]]; then
            printf '%s\0icon\x1f%s\n' "$label" "$icon_path"
          else
            printf '%s\n' "$label"
          fi
        done
      } | rofi -dmenu -i -show-icons -format i -p 'rename webapp' \
           -theme-str 'window { width: 980px; }' \
           -theme-str 'listview { lines: 10; }' \
           -theme-str 'element-icon { size: 28px; }'
    )"; then
      if cancel_requests_close; then
        return 2
      fi
      return 1
    fi

    clear_cancel_state
    [[ -n "$selection" ]] || return 1
    IFS=$'\t' read -r spec _ <<< "${rows[$selection]}"

    while true; do
      if ! new_name="$(prompt_name)"; then
        if cancel_requests_close; then
          return 2
        fi
        break
      fi

      clear_cancel_state
      [[ -n "$(trim "$new_name")" ]] || continue
      IFS=':' read -r source app_id <<< "$spec"
      rename_webapp "$source" "$app_id" "$new_name"
      return 0
    done
  done
}

menu() {
  require_tools
  ensure_dirs
  clear_cancel_state

  local action sub_status

  while true; do
    if ! action="$(
      printf '󰀻  create webapp\n󰑕  rename webapp\n󰆴  remove webapps\n' | rofi -dmenu -i -p 'webapps'
    )"; then
      clear_cancel_state
      return 0
    fi

    clear_cancel_state
    sub_status=0

    case "$action" in
      '󰀻  create webapp')
        menu_create || sub_status=$?
        ;;
      '󰑕  rename webapp')
        menu_rename || sub_status=$?
        ;;
      '󰆴  remove webapps')
        menu_delete || sub_status=$?
        ;;
      *)
        clear_cancel_state
        return 0
        ;;
    esac

    case "${sub_status:-0}" in
      0|1)
        sub_status=0
        continue
        ;;
      2)
        clear_cancel_state
        return 0
        ;;
      *)
        sub_status=0
        continue
        ;;
    esac
  done
}

usage() {
  cat <<'EOF'
Uso:
  webapp-menu.sh --menu
  webapp-menu.sh --create --url URL [--name NOMBRE]
  webapp-menu.sh --rename SOURCE:APP_ID --name NOMBRE
  webapp-menu.sh --delete SOURCE:APP_ID [SOURCE:APP_ID ...]
  webapp-menu.sh --list
EOF
}

main() {
  ensure_dirs

  local mode=menu url= name= rename_spec= delete_ids=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --menu)
        mode=menu
        shift
        ;;
      --create)
        mode=create
        shift
        ;;
      --rename)
        mode=rename
        [[ $# -ge 2 ]] || { echo "--rename requiere un valor" >&2; exit 1; }
        rename_spec="$2"
        shift 2
        ;;
      --url)
        [[ $# -ge 2 ]] || { echo "--url requiere un valor" >&2; exit 1; }
        url="$2"
        shift 2
        ;;
      --name)
        [[ $# -ge 2 ]] || { echo "--name requiere un valor" >&2; exit 1; }
        name="$2"
        shift 2
        ;;
      --delete)
        mode=delete
        shift
        while [[ $# -gt 0 ]]; do
          delete_ids+=("$1")
          shift
        done
        ;;
      --list)
        mode=list
        shift
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        echo "Argumento no reconocido: $1" >&2
        usage >&2
        exit 1
        ;;
    esac
  done

  case "$mode" in
    menu)
      menu
      ;;
    create)
      [[ -n "$url" ]] || { echo "Falta --url" >&2; exit 1; }
      create_webapp "$url" "$name"
      ;;
    rename)
      [[ -n "$rename_spec" && -n "$name" ]] || { echo "Falta --rename o --name" >&2; exit 1; }
      IFS=':' read -r source app_id <<< "$rename_spec"
      rename_webapp "$source" "$app_id" "$name"
      ;;
    delete)
      (( ${#delete_ids[@]} > 0 )) || { echo "Falta al menos un APP_ID para --delete" >&2; exit 1; }
      delete_webapp_ids "${delete_ids[@]}"
      ;;
    list)
      list_entries
      ;;
  esac
}

main "$@"
