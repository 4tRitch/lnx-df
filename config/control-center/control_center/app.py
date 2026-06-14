import re
import signal
import threading
import time
from pathlib import Path

from control_center.config import (
    APP_ID, BASE, LAYER_NAMESPACE, MEDIA_HEIGHT, PANEL_ANIMATION_MS, PANEL_FALLBACK_X,
    PANEL_HEIGHT, PANEL_HORIZONTAL_DECORATION, PANEL_RIGHT_MARGIN, PANEL_TOP_MARGIN,
    PANEL_WIDTH, STEP,
)
from control_center.gtk import Gdk, GLib, Gtk, Gtk4LayerShell
from control_center.infra.commands import run_detached
from control_center.infra.process import cleanup_pid, write_pid
from control_center.services.actions import row_action_kind
from control_center.services.audio import (
    app_audio_outputs, audio_inputs, audio_outputs, audio_status, current_input_volume,
    current_output_volume, enforce_preferred_input_volume, mic_status, set_default_input_device,
    set_default_output_device, set_input_muted, set_input_volume, set_output_muted,
    set_output_volume, toggle_input_mute,
)
from control_center.services.bluetooth import (
    bluetooth_rows, bluetooth_status, connect_bluetooth, set_bluetooth_enabled,
)
from control_center.services.hyprland import focus_app_window, hypr_monitor_width
from control_center.services.media import cached_art_path, player_status
from control_center.services.notifications import (
    clear_notification_history, close_notifications, notification_groups, notification_status,
    relative_notification_time, remove_notifications_from_history,
)
from control_center.services.wifi import connect_wifi, set_wifi_enabled, wifi_rows, wifi_status
from control_center.ui.atoms.widgets import icon as atom_icon, spinner_row as atom_spinner_row
from control_center.ui.molecules.notifications import hover_reveal_action_row
from control_center.ui.molecules.rows import detail_button_row, plain_detail_row, section_label
from control_center.utils import format_time, snap_volume

class ControlCenter(Gtk.Application):
    def __init__(self, start_hidden: bool = False):
        super().__init__(application_id=APP_ID)
        self.connect("activate", self.on_activate)
        self.start_hidden = start_hidden
        self.window = None
        self.tiles = {}
        self.tile_icons = {}
        self.volume_scale = None
        self.volume_label = None
        self.mic_scale = None
        self.mic_label = None
        self.mic_switch = None
        self.mic_switch_status = None
        self.cached_output_volume = 0
        self.cached_mic_volume = 0
        self.feature_switches = {}
        self.feature_switch_icons = {}
        self.feature_switch_statuses = {}
        self.updating_feature_switches = set()
        self.media_title = None
        self.media_subtitle = None
        self.media_play = None
        self.media_progress = None
        self.media_time = None
        self.media_player = ""
        self.notifications_list = None
        self.notifications_dnd = None
        self.expanded_notification_groups = set()
        self.art_provider = Gtk.CssProvider()
        self.media_position = 0
        self.media_length = 0
        self.media_playing = False
        self.media_last_tick = time.monotonic()
        self.updating_volume = False
        self.updating_mic = False
        self.updating_mic_switch = False
        self.updating_media_progress = False
        self.back_button = None
        self.header_title = None
        self.stack = None
        self.stage = None
        self.panel = None
        self.animation_source = None
        self.animation_start_time = 0.0
        self.panel_offset = 0
        self.animation_start_offset = 0
        self.animation_target_offset = 0
        self.animation_opening = True
        self.detail_title = None
        self.detail_icon = None
        self.detail_subtitle = None
        self.detail_rows = None
        self.layer_shell_enabled = False
        self.closing = False
        self.visible = False
        self.monitor_width = 0
        self.refresh_generation = 0

    def on_activate(self, app):
        if self.window:
            self.toggle_panel()
            return

        write_pid()
        self.connect("shutdown", lambda *_: cleanup_pid())
        signal.signal(signal.SIGUSR1, self.on_toggle_signal)
        signal.signal(signal.SIGTERM, self.on_exit_signal)
        signal.signal(signal.SIGINT, self.on_exit_signal)
        self.load_css()
        Gtk.StyleContext.add_provider_for_display(Gdk.Display.get_default(), self.art_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION + 1)

        self.window = Gtk.ApplicationWindow(application=app)
        self.window.set_title("Control Center")
        self.layer_shell_enabled = self.configure_layer_shell()
        self.monitor_width = self.current_monitor_width()
        if not self.layer_shell_enabled:
            self.window.set_default_size(PANEL_WIDTH, PANEL_HEIGHT)
        self.window.add_css_class("control-overlay-window")
        self.window.connect("close-request", self.on_close)
        key_controller = Gtk.EventControllerKey.new()
        key_controller.connect("key-pressed", self.on_key_pressed)
        self.window.add_controller(key_controller)
        self.window.set_decorated(False)
        if not self.layer_shell_enabled:
            self.window.set_resizable(False)
        self.window.set_child(self.build_ui())
        GLib.timeout_add(1000, self.tick_media_progress)
        GLib.timeout_add_seconds(5, self.periodic_refresh)
        self.refresh_async()
        if not self.start_hidden:
            self.show_panel()

    def configure_layer_shell(self) -> bool:
        if Gtk4LayerShell is None or not Gtk4LayerShell.is_supported():
            return False
        Gtk4LayerShell.init_for_window(self.window)
        Gtk4LayerShell.set_namespace(self.window, LAYER_NAMESPACE)
        Gtk4LayerShell.set_layer(self.window, Gtk4LayerShell.Layer.OVERLAY)
        Gtk4LayerShell.set_keyboard_mode(self.window, Gtk4LayerShell.KeyboardMode.EXCLUSIVE)
        Gtk4LayerShell.set_exclusive_zone(self.window, 0)
        for edge in (Gtk4LayerShell.Edge.TOP, Gtk4LayerShell.Edge.RIGHT, Gtk4LayerShell.Edge.BOTTOM, Gtk4LayerShell.Edge.LEFT):
            Gtk4LayerShell.set_anchor(self.window, edge, True)
        return True

    def on_toggle_signal(self, *_args):
        GLib.idle_add(self.toggle_panel)

    def on_exit_signal(self, *_args):
        GLib.idle_add(self.exit_panel)

    def toggle_panel(self):
        if self.visible:
            self.close_panel()
        else:
            self.show_panel()
        return False

    def show_panel(self):
        if not self.window:
            return False
        self.closing = False
        self.visible = True
        self.monitor_width = hypr_monitor_width() or self.current_monitor_width()
        self.show_main_page()
        self.window.present()
        GLib.idle_add(self.reveal_panel)
        GLib.timeout_add(80, self.ensure_panel_position)
        GLib.timeout_add(PANEL_ANIMATION_MS + 60, self.ensure_panel_position)
        if not self.layer_shell_enabled:
            GLib.timeout_add(120, self.place_window)
        self.refresh_async()
        return False

    def reveal_panel(self):
        self.animate_panel(opening=True)
        return False

    def close_panel(self):
        if self.closing:
            return False
        self.closing = True
        self.animate_panel(opening=False)
        return False

    def exit_panel(self):
        cleanup_pid()
        if self.window:
            self.window.set_visible(False)
        self.quit()
        return False

    def panel_width(self) -> int:
        if self.panel and self.panel.get_width() > 0:
            return self.panel.get_width()
        return PANEL_WIDTH

    def panel_outer_width(self) -> int:
        return self.panel_width() + PANEL_HORIZONTAL_DECORATION

    def current_monitor_width(self) -> int:
        hypr_width = hypr_monitor_width()
        if hypr_width > 0:
            return hypr_width
        display = Gdk.Display.get_default()
        if not display:
            return PANEL_WIDTH + PANEL_RIGHT_MARGIN
        monitors = display.get_monitors()
        if monitors.get_n_items() == 0:
            return PANEL_WIDTH + PANEL_RIGHT_MARGIN
        monitor = monitors.get_item(0)
        return monitor.get_geometry().width

    def visible_panel_x(self) -> int:
        if not self.layer_shell_enabled:
            return 0
        width = self.monitor_width or (self.stage.get_width() if self.stage else 0)
        return max(0, width - PANEL_RIGHT_MARGIN - self.panel_outer_width())

    def hidden_panel_offset(self) -> int:
        if not self.layer_shell_enabled:
            return 0
        return PANEL_RIGHT_MARGIN

    def set_panel_offset(self, offset: int) -> None:
        self.panel_offset = offset
        if self.layer_shell_enabled and self.stage and self.panel:
            self.stage.move(self.panel, self.visible_panel_x() + offset, PANEL_TOP_MARGIN)

    def ensure_panel_position(self):
        if self.visible and self.layer_shell_enabled:
            self.set_panel_offset(self.panel_offset)
        return False

    def animate_panel(self, opening: bool) -> None:
        if not self.panel:
            if not opening:
                self.finish_close()
            return

        if self.layer_shell_enabled and (not self.stage or self.stage.get_width() <= 1):
            GLib.timeout_add(16, lambda: (self.animate_panel(opening), False)[1])
            return

        if self.animation_source:
            GLib.source_remove(self.animation_source)
            self.animation_source = None

        self.animation_opening = opening
        self.animation_start_time = time.monotonic()
        if opening and self.panel.get_opacity() == 0.0:
            self.set_panel_offset(self.hidden_panel_offset())
        self.animation_start_offset = self.panel_offset
        self.animation_target_offset = 0 if opening else self.hidden_panel_offset()
        self.animation_source = GLib.timeout_add(16, self.animate_panel_step)

    def animate_panel_step(self):
        if not self.panel:
            return False

        elapsed = (time.monotonic() - self.animation_start_time) * 1000
        progress = min(1.0, elapsed / PANEL_ANIMATION_MS)
        eased = 1 - pow(1 - progress, 3)
        offset = round(self.animation_start_offset + (self.animation_target_offset - self.animation_start_offset) * eased)
        self.set_panel_offset(offset)
        self.panel.set_opacity(eased if self.animation_opening else 1 - eased)

        if progress < 1.0:
            return True

        self.set_panel_offset(self.animation_target_offset)
        self.panel.set_opacity(1.0 if self.animation_opening else 0.0)
        self.animation_source = None
        if not self.animation_opening:
            self.finish_close()
        return False

    def finish_close(self):
        self.closing = False
        self.visible = False
        if self.window:
            self.window.set_visible(False)
        return False

    def on_close(self, *_):
        if self.closing:
            return True
        self.close_panel()
        return True

    def on_key_pressed(self, _controller, keyval, _keycode, _state):
        if keyval == Gdk.KEY_Escape:
            self.close_panel()
            return True
        return False

    def place_window(self):
        run_detached(["hyprctl", "dispatch", "focuswindow", "class:dev.ritch.ControlCenter"])
        run_detached(["hyprctl", "dispatch", "resizeactive", "exact", str(PANEL_WIDTH), str(PANEL_HEIGHT)])
        run_detached(["hyprctl", "dispatch", "movewindowpixel", "exact", str(PANEL_FALLBACK_X), str(PANEL_TOP_MARGIN)])
        return False

    def load_css(self):
        provider = Gtk.CssProvider()
        provider.load_from_path(str(BASE / "control-center" / "style.css"))
        Gtk.StyleContext.add_provider_for_display(Gdk.Display.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

    def build_ui(self):
        panel = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        panel.add_css_class("control-panel")
        panel.set_size_request(PANEL_WIDTH, PANEL_HEIGHT)
        panel.set_overflow(Gtk.Overflow.HIDDEN)
        panel.set_opacity(0.0)
        self.panel = panel
        header = Gtk.CenterBox()
        self.back_button = Gtk.Button(label="‹")
        self.back_button.add_css_class("round-button")
        self.back_button.connect("clicked", self.show_main_page)
        self.back_button.set_visible(False)
        self.header_title = Gtk.Label(label="", xalign=0.5)
        self.header_title.add_css_class("title")
        header.set_start_widget(self.back_button)
        header.set_center_widget(self.header_title)
        panel.append(header)

        self.stack = Gtk.Stack()
        self.stack.set_transition_type(Gtk.StackTransitionType.SLIDE_LEFT_RIGHT)
        self.stack.set_transition_duration(180)
        self.stack.set_vexpand(True)
        self.stack.add_named(self.main_page(), "main")
        self.stack.add_named(self.detail_page(), "detail")
        self.stack.set_visible_child_name("main")
        panel.append(self.stack)

        if not self.layer_shell_enabled:
            panel.set_margin_end(0)
            return panel

        stage = Gtk.Fixed()
        stage.add_css_class("control-backdrop")
        if self.monitor_width > 0:
            stage.set_size_request(self.monitor_width, -1)
        stage.set_hexpand(True)
        stage.set_vexpand(True)
        stage.set_can_target(True)
        click_controller = Gtk.GestureClick.new()
        click_controller.set_propagation_phase(Gtk.PropagationPhase.CAPTURE)
        click_controller.connect("released", self.on_stage_clicked)
        stage.add_controller(click_controller)
        stage.put(panel, 0, PANEL_TOP_MARGIN)
        self.stage = stage
        return stage

    def on_stage_clicked(self, gesture, _n_press, x, y):
        panel_x = self.visible_panel_x() + self.panel_offset
        if self.panel and panel_x <= x <= panel_x + self.panel_outer_width() and PANEL_TOP_MARGIN <= y <= PANEL_TOP_MARGIN + self.panel.get_height():
            return
        gesture.set_state(Gtk.EventSequenceState.CLAIMED)
        self.close_panel()

    def main_page(self):
        page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        grid = Gtk.Grid(column_spacing=8, row_spacing=8)
        grid.attach(self.split_tile("wifi", "󰤨", "Wi‑Fi", "Loading", "off", self.on_wifi_tile_toggle, self.show_wifi_detail_page, "Turn Wi‑Fi on / off", "Open Wi‑Fi settings"), 0, 0, 1, 1)
        grid.attach(self.split_tile("audio", "", "Audio", "Loading", "off", self.on_audio_tile_toggle, self.show_audio_detail_page, "Mute / unmute audio", "Open audio settings"), 1, 0, 1, 1)
        grid.attach(self.split_tile("bluetooth", "󰂯", "Bluetooth", "Loading", "off", self.on_bluetooth_tile_toggle, self.show_bluetooth_detail_page, "Turn Bluetooth on / off", "Open Bluetooth settings"), 0, 1, 1, 1)
        grid.attach(self.split_tile("mic", "", "Mic", "Loading", "off", self.on_mic_tile_toggle, self.show_mic_detail_page, "Mute / unmute microphone", "Open microphone settings"), 1, 1, 1, 1)
        page.append(grid)
        page.append(self.slider_row("", "output"))
        page.append(self.media_card())
        page.append(self.notifications_card())
        return page

    def tile(self, key, icon, title, subtitle, state, callback):
        button = Gtk.Button()
        button.add_css_class("tile")
        button.add_css_class(state)
        button.connect("clicked", lambda *_: callback())
        box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        glyph = Gtk.Label(label=icon)
        glyph.add_css_class("tile-icon")
        text = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=1)
        label = Gtk.Label(label=title, xalign=0)
        label.add_css_class("tile-title")
        sub = Gtk.Label(label=subtitle, xalign=0)
        sub.add_css_class("tile-subtitle")
        sub.set_ellipsize(3)
        text.append(label)
        text.append(sub)
        box.append(glyph)
        box.append(text)
        button.set_child(box)
        self.tiles[key] = (button, sub)
        return button

    def split_tile(self, key, icon, title, subtitle, state, toggle_callback, detail_callback, toggle_tooltip, detail_tooltip):
        tile = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
        tile.add_css_class("tile")
        tile.add_css_class("split-tile")
        tile.add_css_class(state)
        tile.set_overflow(Gtk.Overflow.HIDDEN)

        toggle = Gtk.Button()
        toggle.add_css_class("split-tile-primary")
        toggle.set_tooltip_text(toggle_tooltip)
        toggle.connect("clicked", toggle_callback)

        content = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        glyph = Gtk.Label(label=self.feature_icon(key, state))
        glyph.add_css_class("tile-icon")
        text = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=1)
        label = Gtk.Label(label=title, xalign=0)
        label.add_css_class("tile-title")
        sub = Gtk.Label(label=subtitle, xalign=0)
        sub.add_css_class("tile-subtitle")
        sub.set_ellipsize(3)
        text.append(label)
        text.append(sub)
        content.append(glyph)
        content.append(text)
        toggle.set_child(content)
        toggle.set_hexpand(True)

        divider = Gtk.Box()
        divider.add_css_class("split-tile-divider")
        divider.set_size_request(1, -1)

        detail = Gtk.Button(label="›")
        detail.add_css_class("split-tile-detail")
        detail.set_tooltip_text(detail_tooltip)
        detail.connect("clicked", detail_callback)

        tile.append(toggle)
        tile.append(divider)
        tile.append(detail)
        self.tiles[key] = (tile, sub)
        self.tile_icons[key] = glyph
        return tile

    def on_wifi_tile_toggle(self, *_args):
        next_state = "off" if self.tile_state("wifi") == "on" else "on"
        self.apply_feature_visual_state("wifi", "Off" if next_state == "off" else "On", next_state)
        set_wifi_enabled(next_state == "on")
        GLib.timeout_add(350, self.refresh_wifi_status_async)
        if self.detail_title and self.detail_title.get_label() == "Wi‑Fi":
            GLib.timeout_add(550, self.refresh_current_detail)

    def on_audio_tile_toggle(self, *_args):
        next_state = "off" if self.tile_state("audio") == "on" else "on"
        volume = self.volume_label.get_label() if self.volume_label else f"{current_output_volume()}%"
        subtitle = f"Muted · {volume}" if next_state == "off" else volume
        self.apply_feature_visual_state("audio", subtitle, next_state)
        set_output_muted(next_state == "off")
        GLib.timeout_add(110, self.refresh_audio_status_async)

    def on_bluetooth_tile_toggle(self, *_args):
        next_state = "off" if self.tile_state("bluetooth") == "on" else "on"
        self.apply_feature_visual_state("bluetooth", "Off" if next_state == "off" else "On", next_state)
        set_bluetooth_enabled(next_state == "on")
        GLib.timeout_add(650, self.refresh_bluetooth_status_async)
        if self.detail_title and self.detail_title.get_label() == "Bluetooth":
            GLib.timeout_add(650, self.refresh_current_detail)

    def on_mic_tile_toggle(self, *_args):
        next_state = "off" if self.tile_state("mic") == "on" else "on"
        self.apply_mic_visual_state("Muted" if next_state == "off" else "On", next_state)
        toggle_input_mute()
        GLib.timeout_add(110, self.refresh_mic_status_async)

    def update_tile(self, key, subtitle, state):
        button, sub = self.tiles[key]
        sub.set_label(subtitle)
        glyph = self.tile_icons.get(key)
        if glyph:
            glyph.set_label(self.feature_icon(key, state))
        button.remove_css_class("on")
        button.remove_css_class("off")
        button.add_css_class(state)

    def refresh_wifi_status_async(self):
        def worker():
            wifi = wifi_status()
            GLib.idle_add(self.apply_feature_visual_state, "wifi", wifi[0], wifi[1])

        threading.Thread(target=worker, daemon=True).start()
        return False

    def refresh_audio_status_async(self):
        def worker():
            audio = audio_status()
            volume = current_output_volume()
            GLib.idle_add(self.apply_audio_status, audio, volume)

        threading.Thread(target=worker, daemon=True).start()
        return False

    def refresh_bluetooth_status_async(self):
        def worker():
            bluetooth = bluetooth_status()
            GLib.idle_add(self.apply_feature_visual_state, "bluetooth", bluetooth[0], bluetooth[1])

        threading.Thread(target=worker, daemon=True).start()
        return False

    def refresh_mic_status_async(self):
        def worker():
            mic = mic_status()
            mic_volume = current_input_volume()
            GLib.idle_add(self.apply_mic_status, mic, mic_volume)

        threading.Thread(target=worker, daemon=True).start()
        return False

    def apply_mic_status(self, mic, mic_volume):
        self.apply_mic_visual_state(*mic)
        self.set_mic_value(mic_volume, apply=False)
        return False

    def apply_audio_status(self, audio, volume):
        self.apply_feature_visual_state("audio", audio[0], audio[1])
        self.set_volume_value(volume, apply=False)
        return False

    def apply_mic_visual_state(self, subtitle: str, state: str):
        return self.apply_feature_visual_state("mic", subtitle, state)

    def apply_feature_visual_state(self, key: str, subtitle: str, state: str):
        self.update_tile(key, subtitle, state)
        self.set_feature_switch_state(key, state == "on")
        icon = self.feature_switch_icons.get(key)
        if icon:
            icon.set_label(self.feature_icon(key, state))
        status = self.feature_switch_statuses.get(key)
        if status:
            status.set_label(subtitle)
        if self.detail_title and self.detail_title.get_label() == self.feature_title(key):
            self.detail_subtitle.set_label(subtitle)
        return False

    def set_mic_switch_state(self, active: bool):
        self.set_feature_switch_state("mic", active)

    def set_feature_switch_state(self, key: str, active: bool):
        switch = self.feature_switches.get(key)
        if not switch:
            return
        self.updating_feature_switches.add(key)
        switch.set_active(active)
        self.updating_feature_switches.discard(key)

    def feature_title(self, key: str) -> str:
        return {
            "wifi": "Wi‑Fi",
            "audio": "Audio",
            "bluetooth": "Bluetooth",
            "mic": "Mic",
        }.get(key, key)

    def feature_icon(self, key: str, state: str) -> str:
        icons = {
            "wifi": {"on": "󰤨", "off": "󰤭"},
            "audio": {"on": "", "off": "󰝟"},
            "bluetooth": {"on": "󰂯", "off": "󰂲"},
            "mic": {"on": "", "off": "󰍭"},
        }
        return icons.get(key, {}).get(state, icons.get(key, {}).get("on", ""))

    def tile_state(self, key):
        button, _sub = self.tiles[key]
        if button.has_css_class("on"):
            return "on"
        return "off"

    def cached_feature_status(self, key: str) -> tuple[str, str]:
        state = self.tile_state(key)
        subtitle = self.tiles.get(key, (None, None))[1]
        label = subtitle.get_label() if subtitle else ""
        if label and label != "Loading":
            return label, state
        if key == "audio":
            return (f"{self.cached_output_volume}%" if state == "on" else f"Muted · {self.cached_output_volume}%"), state
        if key == "mic":
            return ("On" if state == "on" else "Muted"), state
        return ("On" if state == "on" else "Off"), state

    def detail_page(self):
        page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        self.detail_title = Gtk.Label(label="", xalign=0)
        self.detail_subtitle = Gtk.Label(label="", xalign=0)
        self.detail_rows = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        self.detail_rows.add_css_class("embedded-list")
        scroller = Gtk.ScrolledWindow()
        scroller.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroller.set_vexpand(True)
        scroller.set_child(self.detail_rows)
        page.append(scroller)
        return page

    def show_main_page(self, *_args):
        self.back_button.set_visible(False)
        self.header_title.set_label("")
        self.stack.set_visible_child_name("main")

    def show_detail_loading(self, title: str, message: str):
        self.back_button.set_visible(True)
        self.header_title.set_label("")
        self.detail_title.set_label(title)
        self.clear_detail_rows()
        self.append_loading_row(message)
        self.stack.set_visible_child_name("detail")

    def append_loading_row(self, message: str):
        self.detail_rows.append(atom_spinner_row(message))

    def show_wifi_detail_page(self, *_args):
        cached_status = self.cached_feature_status("wifi")
        self.render_wifi_detail_rows([], "Scanning networks…" if cached_status[1] == "on" else None, cached_status)

        def worker():
            status = wifi_status()
            cached_rows = wifi_rows(refresh=False) if status[1] == "on" else []
            if cached_rows:
                GLib.idle_add(self.render_wifi_detail_rows_if_current, cached_rows, "Updating networks…", status)
            rows = wifi_rows(refresh=True) if status[1] == "on" else []
            GLib.idle_add(self.render_wifi_detail_rows_if_current, rows, None, wifi_status())

        threading.Thread(target=worker, daemon=True).start()

    def show_bluetooth_detail_page(self, *_args):
        cached_status = self.cached_feature_status("bluetooth")
        self.render_bluetooth_detail_rows([], "Scanning devices…" if cached_status[1] == "on" else None, cached_status)

        def worker():
            status = bluetooth_status()
            cached_rows = bluetooth_rows(refresh=False) if status[1] == "on" else []
            if cached_rows:
                GLib.idle_add(self.render_bluetooth_detail_rows_if_current, cached_rows, "Scanning for devices…", status)
            rows = bluetooth_rows(refresh=True) if status[1] == "on" else []
            GLib.idle_add(self.render_bluetooth_detail_rows_if_current, rows, None, bluetooth_status())

        threading.Thread(target=worker, daemon=True).start()

    def show_audio_detail_page(self, *_args):
        self.render_audio_detail_rows(self.cached_feature_status("audio"), None, None)

        def worker():
            GLib.idle_add(
                self.render_audio_detail_rows_if_current,
                audio_status(),
                audio_outputs(),
                app_audio_outputs(),
            )

        threading.Thread(target=worker, daemon=True).start()

    def render_wifi_detail_rows_if_current(self, rows: list[tuple[str, list[str]]], loading_message: str | None, status: tuple[str, str] | None = None):
        if self.detail_title.get_label() == "Wi‑Fi":
            self.render_wifi_detail_rows(rows, loading_message, status)
        return False

    def render_wifi_detail_rows(self, rows: list[tuple[str, list[str]]], loading_message: str | None = None, status: tuple[str, str] | None = None):
        self.back_button.set_visible(True)
        self.header_title.set_label("")
        self.detail_title.set_label("Wi‑Fi")
        self.detail_subtitle.set_label(self.tiles["wifi"][1].get_label())
        self.clear_detail_rows()
        self.append_section_label("Wi‑Fi")
        subtitle, state = status or self.cached_feature_status("wifi")
        self.detail_rows.append(self.feature_switch_row("wifi", "󰤨", "Wi‑Fi", subtitle, state))
        self.append_section_label("Networks")
        if rows:
            self.append_detail_rows(rows)
        elif not loading_message:
            self.append_plain_detail_row("Wi‑Fi is off" if state == "off" else "No networks")
        if loading_message:
            self.append_loading_row(loading_message)
        self.stack.set_visible_child_name("detail")
        return False

    def render_bluetooth_detail_rows_if_current(self, rows: list[tuple[str, list[str]]], loading_message: str | None, status: tuple[str, str] | None = None):
        if self.detail_title.get_label() == "Bluetooth":
            self.render_bluetooth_detail_rows(rows, loading_message, status)
        return False

    def render_bluetooth_detail_rows(self, rows: list[tuple[str, list[str]]], loading_message: str | None = None, status: tuple[str, str] | None = None):
        self.back_button.set_visible(True)
        self.header_title.set_label("")
        self.detail_title.set_label("Bluetooth")
        self.detail_subtitle.set_label(self.tiles["bluetooth"][1].get_label())
        self.clear_detail_rows()
        self.append_section_label("Bluetooth")
        subtitle, state = status or self.cached_feature_status("bluetooth")
        self.detail_rows.append(self.feature_switch_row("bluetooth", "󰂯", "Bluetooth", subtitle, state))
        self.append_section_label("Devices")
        if rows:
            self.append_detail_rows(rows)
        elif not loading_message:
            self.append_plain_detail_row("Bluetooth is off" if state == "off" else "No devices")
        if loading_message:
            self.append_loading_row(loading_message)
        self.stack.set_visible_child_name("detail")
        return False

    def show_mic_detail_page(self, *_args):
        self.render_mic_detail_rows(self.cached_feature_status("mic"), self.cached_mic_volume, None)

        def worker():
            GLib.idle_add(
                self.render_mic_detail_rows_if_current,
                mic_status(),
                current_input_volume(),
                audio_inputs(),
            )

        threading.Thread(target=worker, daemon=True).start()

    def render_audio_detail_rows_if_current(self, status: tuple[str, str], outputs: list[tuple[str, list[str]]], apps: list[dict[str, str | int | bool]]):
        if self.detail_title.get_label() == "Audio":
            self.render_audio_detail_rows(status, outputs, apps)
        return False

    def render_audio_detail_rows(self, status: tuple[str, str], outputs: list[tuple[str, list[str]]] | None, apps: list[dict[str, str | int | bool]] | None):
        subtitle, state = status
        self.back_button.set_visible(True)
        self.header_title.set_label("")
        self.detail_title.set_label("Audio")
        self.detail_subtitle.set_label(subtitle)
        self.clear_detail_rows()
        self.append_section_label("Audio")
        self.detail_rows.append(self.feature_switch_row("audio", "", "Audio", subtitle, state))
        self.append_section_label("Output devices")
        if outputs is None:
            self.append_loading_row("Loading output devices…")
        else:
            self.append_detail_rows(outputs)
        self.append_section_label("App audio")
        if apps is None:
            self.append_loading_row("Loading app audio…")
        elif not apps:
            self.append_plain_detail_row("No active app audio")
        else:
            for app in apps:
                self.append_app_audio_row(app)
        self.stack.set_visible_child_name("detail")
        return False

    def render_mic_detail_rows_if_current(self, status: tuple[str, str], volume: int, inputs: list[tuple[str, list[str]]]):
        if self.detail_title.get_label() == "Mic":
            self.render_mic_detail_rows(status, volume, inputs)
        return False

    def render_mic_detail_rows(self, status: tuple[str, str], volume: int, inputs: list[tuple[str, list[str]]] | None):
        subtitle, state = status
        self.back_button.set_visible(True)
        self.header_title.set_label("")
        self.detail_title.set_label("Mic")
        self.detail_subtitle.set_label(subtitle)
        self.clear_detail_rows()
        self.append_section_label("Microphone")
        self.detail_rows.append(self.feature_switch_row("mic", "", "Microphone", subtitle, state))
        self.append_section_label("Input volume")
        self.detail_rows.append(self.slider_row("", "input"))
        self.set_mic_value(volume, apply=False)
        self.append_section_label("Input devices")
        if inputs is None:
            self.append_loading_row("Loading input devices…")
        else:
            self.append_detail_rows(inputs)
        self.stack.set_visible_child_name("detail")
        return False

    def mic_switch_row(self):
        subtitle, state = self.cached_feature_status("mic")
        return self.feature_switch_row("mic", "", "Microphone", subtitle, state)

    def feature_switch_row(self, key: str, icon_text: str, title_text: str, subtitle: str, state: str):
        row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        row.add_css_class("embedded-row")
        row.add_css_class("feature-switch-row")

        icon = Gtk.Label(label=self.feature_icon(key, state) or icon_text)
        icon.add_css_class("tile-icon")

        text = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=1)
        text.set_hexpand(True)
        title = Gtk.Label(label=title_text, xalign=0)
        title.add_css_class("tile-title")
        status = Gtk.Label(label=subtitle, xalign=0)
        status.add_css_class("tile-subtitle")
        text.append(title)
        text.append(status)

        switch = Gtk.Switch()
        switch.set_valign(Gtk.Align.CENTER)
        self.feature_switches[key] = switch
        self.feature_switch_icons[key] = icon
        self.feature_switch_statuses[key] = status
        self.set_feature_switch_state(key, state == "on")
        switch.connect("notify::active", self.on_feature_switch_changed, key)

        row.append(icon)
        row.append(text)
        row.append(switch)
        return row

    def on_feature_switch_changed(self, switch, _param, key: str):
        if key in self.updating_feature_switches:
            return
        active = switch.get_active()
        if key == "audio":
            volume = self.volume_label.get_label() if self.volume_label else f"{current_output_volume()}%"
            subtitle = volume if active else f"Muted · {volume}"
        else:
            subtitle = "On" if active else ("Muted" if key == "mic" else "Off")
        state = "on" if active else "off"
        self.apply_feature_visual_state(key, subtitle, state)
        if key == "wifi":
            set_wifi_enabled(active)
            GLib.timeout_add(350, self.refresh_wifi_status_async)
            GLib.timeout_add(550, self.refresh_current_detail)
        elif key == "audio":
            set_output_muted(not active)
            GLib.timeout_add(110, self.refresh_audio_status_async)
        elif key == "bluetooth":
            set_bluetooth_enabled(active)
            GLib.timeout_add(650, self.refresh_bluetooth_status_async)
            GLib.timeout_add(650, self.refresh_current_detail)
        elif key == "mic":
            set_input_muted(not active)
            GLib.timeout_add(110, self.refresh_mic_status_async)

    def show_detail_page(self, icon: str, title: str, subtitle: str, state: str, rows: list[tuple[str, list[str]]]):
        self.back_button.set_visible(True)
        self.header_title.set_label("")
        self.detail_title.set_label(title)
        self.detail_subtitle.set_label(subtitle)
        self.set_detail_rows(rows)
        self.stack.set_visible_child_name("detail")

    def update_detail_rows_if_current(self, title: str, rows: list[tuple[str, list[str]]]):
        if self.detail_title.get_label() == title:
            self.set_detail_rows(rows)
        return False

    def update_detail_rows_with_loading_if_current(self, title: str, rows: list[tuple[str, list[str]]], message: str):
        if self.detail_title.get_label() == title:
            self.set_detail_rows(rows)
            self.append_loading_row(message)
        return False

    def clear_detail_rows(self):
        child = self.detail_rows.get_first_child()
        while child:
            next_child = child.get_next_sibling()
            self.detail_rows.remove(child)
            child = next_child
        self.mic_switch = None
        self.mic_switch_status = None
        self.feature_switches.clear()
        self.feature_switch_icons.clear()
        self.feature_switch_statuses.clear()
        self.updating_feature_switches.clear()

    def append_section_label(self, text: str):
        self.detail_rows.append(section_label(text))

    def append_plain_detail_row(self, text: str):
        self.detail_rows.append(plain_detail_row(text))

    def set_detail_rows(self, rows: list[tuple[str, list[str]]]):
        self.clear_detail_rows()
        if not rows:
            rows = [("No items", [])]
        self.append_detail_rows(rows)

    def append_detail_rows(self, rows: list[tuple[str, list[str]]]):
        for label, command in rows[:7]:
            button = detail_button_row(label, command)
            if command:
                button.connect("clicked", self.on_detail_action, command, label)
            self.detail_rows.append(button)

    def append_app_audio_row(self, app: dict[str, str | int | bool]):
        row = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        row.add_css_class("embedded-row")
        header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        name = str(app.get("name") or "Unknown")
        media = str(app.get("media") or "")
        title = Gtk.Label(label=f"  {name[:26]}", xalign=0)
        title.set_hexpand(True)
        subtitle = Gtk.Label(label=media[:16], xalign=1)
        subtitle.add_css_class("tile-subtitle")
        header.append(title)
        header.append(subtitle)
        controls = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        scale = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0, 100, STEP)
        scale.set_value(int(app.get("volume") or 0))
        scale.set_draw_value(False)
        scale.set_hexpand(True)
        value = Gtk.Label(label=f"{int(app.get('volume') or 0)}%")
        value.add_css_class("slider-value")
        app_id = int(app.get("id") or 0)
        scale.connect("value-changed", self.on_app_volume_changed, app_id, value)
        mute = Gtk.Button(label="󰝟" if bool(app.get("muted")) else "")
        mute.add_css_class("media-button")
        mute.connect("clicked", self.on_app_mute_clicked, app_id)
        controls.append(mute)
        controls.append(scale)
        controls.append(value)
        row.append(header)
        row.append(controls)
        self.detail_rows.append(row)

    def on_detail_action(self, button, command: list[str], label: str):
        kind = row_action_kind(command)
        if kind == "wifi-scan":
            self.show_wifi_detail_page()
            return
        if kind == "bluetooth-scan":
            self.show_bluetooth_detail_page()
            return
        if kind == "wifi":
            button.remove_css_class("connected-row")
            button.add_css_class("connecting-row")
            child = button.get_child()
            if isinstance(child, Gtk.Label):
                child.set_label(f"󰔟  Connecting… {label.split('  ', 1)[-1]}")
            def worker():
                ssid = command[1]
                security = command[2] if len(command) > 2 else ""
                ok, output = connect_wifi(ssid)
                if ok:
                    GLib.idle_add(self.finish_detail_action, button, command, True, "✓ Connected")
                elif security and security != "--":
                    GLib.idle_add(self.prompt_wifi_password, button, ssid, output)
                else:
                    GLib.idle_add(self.finish_detail_action, button, command, False, output or "Connection failed")
            threading.Thread(target=worker, daemon=True).start()
        elif kind == "bluetooth":
            button.remove_css_class("connected-row")
            button.add_css_class("connecting-row")
            child = button.get_child()
            if isinstance(child, Gtk.Label):
                child.set_label(f"󰔟  Pairing… {label.split('  ', 1)[-1]}")
            def worker():
                ok, output = connect_bluetooth(command[1])
                GLib.idle_add(self.finish_detail_action, button, command, ok, "✓ Paired + trusted" if ok else (output or "Connection failed"))
            threading.Thread(target=worker, daemon=True).start()
        elif kind in {"audio-output", "audio-input"}:
            button.remove_css_class("connected-row")
            button.add_css_class("connecting-row")
            child = button.get_child()
            if isinstance(child, Gtk.Label):
                child.set_label(f"󰔟  Switching… {label.split('  ', 1)[-1]}")

            def worker():
                if kind == "audio-output":
                    ok, output = set_default_output_device(command[1])
                else:
                    ok, output = set_default_input_device(command[1])
                GLib.idle_add(self.finish_detail_action, button, command, ok, "✓ Selected" if ok else (output or "Switch failed"))

            threading.Thread(target=worker, daemon=True).start()
        else:
            run_detached(command)
            button.add_css_class("connected-row")
            GLib.timeout_add(600, lambda: (self.refresh_async(), False)[1])

    def prompt_wifi_password(self, button, ssid: str, error: str):
        button.remove_css_class("connecting-row")
        self.remove_wifi_password_prompts()

        form = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        form.add_css_class("wifi-password-card")
        form.set_size_request(PANEL_WIDTH - 64, -1)
        title = Gtk.Label(label=f"Password for {ssid}", xalign=0)
        title.add_css_class("wifi-password-title")
        title.set_ellipsize(3)
        title.set_max_width_chars(36)
        hint = Gtk.Label(label=self.short_error(error) or "Enter the network password.", xalign=0)
        hint.add_css_class("wifi-password-hint")
        hint.set_ellipsize(3)
        hint.set_max_width_chars(42)
        entry = Gtk.Entry()
        entry.set_visibility(False)
        entry.set_placeholder_text("Password")
        entry.set_hexpand(True)
        entry.set_max_width_chars(32)

        controls = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        cancel = Gtk.Button(label="Cancel")
        cancel.add_css_class("mini-button")
        connect = Gtk.Button(label="Connect")
        connect.add_css_class("mini-button")
        connect.add_css_class("active")
        controls.append(cancel)
        controls.append(connect)

        form.append(title)
        form.append(hint)
        form.append(entry)
        form.append(controls)

        def remove_form(*_args):
            parent = form.get_parent()
            if parent:
                parent.remove(form)
            GLib.idle_add(self.ensure_panel_position)

        def submit(*_args):
            password = entry.get_text()
            if not password:
                hint.set_label("Password required.")
                return
            entry.set_sensitive(False)
            connect.set_sensitive(False)
            cancel.set_sensitive(False)
            hint.set_label("Connecting…")
            button.remove_css_class("failed-row")
            button.add_css_class("connecting-row")
            child = button.get_child()
            if isinstance(child, Gtk.Label):
                child.set_label(f"󰔟  Connecting… {ssid}")

            def worker():
                ok, output = connect_wifi(ssid, password)
                GLib.idle_add(self.finish_wifi_password_attempt, form, button, ssid, ok, output)

            threading.Thread(target=worker, daemon=True).start()

        cancel.connect("clicked", remove_form)
        connect.connect("clicked", submit)
        entry.connect("activate", submit)
        self.detail_rows.insert_child_after(form, button)
        GLib.idle_add(self.ensure_panel_position)
        entry.grab_focus()
        return False

    def remove_wifi_password_prompts(self):
        child = self.detail_rows.get_first_child()
        while child:
            next_child = child.get_next_sibling()
            if child.has_css_class("wifi-password-card"):
                self.detail_rows.remove(child)
            child = next_child

    def finish_wifi_password_attempt(self, form, button, ssid: str, ok: bool, output: str):
        if ok:
            parent = form.get_parent()
            if parent:
                parent.remove(form)
            self.finish_detail_action(button, ["wifi-connect", ssid], True, "✓ Connected")
            GLib.idle_add(self.ensure_panel_position)
            return False

        button.remove_css_class("connecting-row")
        button.add_css_class("failed-row")
        child = button.get_child()
        if isinstance(child, Gtk.Label):
            child.set_label("Connection failed")

        hint = form.get_first_child()
        if hint:
            hint = hint.get_next_sibling()
        if isinstance(hint, Gtk.Label):
            hint.set_label(self.short_error(output) or "Connection failed. Check the password.")
            hint.set_ellipsize(3)
        entry = hint.get_next_sibling() if hint else None
        controls = entry.get_next_sibling() if entry else None
        if entry:
            entry.set_sensitive(True)
            entry.grab_focus()
        if controls:
            child = controls.get_first_child()
            while child:
                child.set_sensitive(True)
                child = child.get_next_sibling()
        GLib.idle_add(self.ensure_panel_position)
        return False

    def short_error(self, text: str) -> str:
        compact = " ".join((text or "").split())
        if not compact:
            return ""
        compact = re.sub(r"^Error:\\s*", "", compact)
        return compact[:110]

    def finish_detail_action(self, button, command: list[str], ok: bool, message: str | None = None):
        button.remove_css_class("connecting-row")
        if ok:
            button.add_css_class("connected-row")
            child = button.get_child()
            if isinstance(child, Gtk.Label):
                child.set_label(message or "✓ Connected")
        else:
            button.add_css_class("failed-row")
            child = button.get_child()
            if isinstance(child, Gtk.Label):
                child.set_label(message or "Connection failed")
        self.refresh_async()
        GLib.timeout_add(900, self.refresh_current_detail)
        return False

    def refresh_current_detail(self):
        title = self.detail_title.get_label()
        if title == "Wi‑Fi":
            self.show_wifi_detail_page()
        elif title == "Bluetooth":
            self.show_bluetooth_detail_page()
        elif title == "Audio":
            self.show_audio_detail_page()
        elif title == "Mic":
            self.show_mic_detail_page()
        return False

    def on_app_volume_changed(self, scale, app_id: int, value_label):
        value = snap_volume(scale.get_value())
        value_label.set_label(f"{value}%")
        run_detached(["pactl", "set-sink-input-volume", str(app_id), f"{value}%"])

    def on_app_mute_clicked(self, _button, app_id: int):
        run_detached(["pactl", "set-sink-input-mute", str(app_id), "toggle"])
        GLib.timeout_add(350, self.refresh_current_detail)

    def slider_row(self, icon_text, kind):
        row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        row.add_css_class("slider-card")
        icon = Gtk.Label(label=icon_text)
        scale = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0, 100, STEP)
        scale.set_increments(STEP, STEP)
        scale.set_digits(0)
        scale.set_hexpand(True)
        scale.set_value(0)
        scroll = Gtk.EventControllerScroll.new(Gtk.EventControllerScrollFlags.VERTICAL)
        scale.add_controller(scroll)
        label = Gtk.Label(label="0%")
        label.add_css_class("slider-value")
        row.append(icon)
        row.append(scale)
        row.append(label)
        if kind == "output":
            self.volume_scale = scale
            self.volume_label = label
            scale.connect("value-changed", self.on_volume_changed)
            scroll.connect("scroll", self.on_volume_scroll)
        else:
            self.mic_scale = scale
            self.mic_label = label
            scale.connect("value-changed", self.on_mic_changed)
            scroll.connect("scroll", self.on_mic_scroll)
        return row

    def on_volume_scroll(self, _controller, _dx, dy):
        self.set_volume_value(snap_volume(self.volume_scale.get_value()) + (STEP if dy < 0 else -STEP), apply=True)
        return True

    def on_mic_scroll(self, _controller, _dx, dy):
        self.set_mic_value(snap_volume(self.mic_scale.get_value()) + (STEP if dy < 0 else -STEP), apply=True)
        return True

    def on_volume_changed(self, scale):
        if not self.updating_volume:
            self.set_volume_value(scale.get_value(), apply=True)

    def on_mic_changed(self, scale):
        if not self.updating_mic:
            self.set_mic_value(scale.get_value(), apply=True)

    def set_volume_value(self, value, apply=False):
        snapped = snap_volume(value)
        self.cached_output_volume = snapped
        self.updating_volume = True
        self.volume_scale.set_value(snapped)
        self.updating_volume = False
        self.volume_label.set_label(f"{snapped}%")
        if apply:
            set_output_volume(snapped)

    def set_mic_value(self, value, apply=False):
        snapped = snap_volume(value)
        self.cached_mic_volume = snapped
        if not self.mic_scale or not self.mic_label:
            return
        self.updating_mic = True
        self.mic_scale.set_value(snapped)
        self.updating_mic = False
        self.mic_label.set_label(f"{snapped}%")
        if apply:
            set_input_volume(snapped)

    def media_card(self):
        overlay = Gtk.Overlay()
        overlay.add_css_class("media-card")
        overlay.set_size_request(-1, MEDIA_HEIGHT)
        overlay.set_vexpand(False)
        content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=7)
        content.add_css_class("media-content")
        content.set_size_request(-1, MEDIA_HEIGHT)
        content.set_vexpand(False)
        overlay.set_child(content)
        self.media_title = Gtk.Label(label="Loading media", xalign=0)
        self.media_title.add_css_class("media-title")
        self.media_title.set_ellipsize(3)
        self.media_subtitle = Gtk.Label(label="", xalign=0)
        self.media_subtitle.add_css_class("media-subtitle")
        self.media_subtitle.set_ellipsize(3)
        time_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        self.media_time = Gtk.Label(label="0:00 / 0:00", xalign=1)
        self.media_time.add_css_class("media-time")
        self.media_time.set_hexpand(True)
        time_row.append(self.media_time)
        self.media_progress = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0, 100, 1)
        self.media_progress.set_draw_value(False)
        self.media_progress.set_sensitive(True)
        self.media_progress.set_hexpand(True)
        self.media_progress.connect("value-changed", self.on_media_seek)
        controls = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        controls.add_css_class("media-controls")
        controls.set_halign(Gtk.Align.CENTER)
        for label, action in [("", "prev"), ("", "play-pause"), ("", "next")]:
            btn = Gtk.Button(label=label)
            btn.add_css_class("media-button")
            btn.connect("clicked", self.on_media_action, action)
            controls.append(btn)
            if action == "play-pause":
                self.media_play = btn
        content.append(self.media_title)
        content.append(self.media_subtitle)
        spacer = Gtk.Box()
        spacer.set_vexpand(True)
        content.append(spacer)
        content.append(time_row)
        content.append(self.media_progress)
        content.append(controls)
        return overlay

    def on_media_action(self, _button, action):
        if self.media_player:
            run_detached(["swayosd-client", "--player", self.media_player, "--playerctl", action])
        else:
            run_detached(["swayosd-client", "--playerctl", action])
        GLib.timeout_add(350, lambda: (self.refresh_async(), False)[1])

    def on_media_seek(self, scale):
        if self.updating_media_progress or not self.media_player or self.media_length <= 0:
            return
        target = int(scale.get_value() / 100 * self.media_length)
        self.media_position = target
        self.media_last_tick = time.monotonic()
        self.media_time.set_label(f"{format_time(target)} / {format_time(self.media_length)}")
        run_detached(["playerctl", "-p", self.media_player, "position", str(target)])

    def notifications_card(self):
        card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        card.add_css_class("notifications-card")

        header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        title = Gtk.Label(label="󰂚  Notifications", xalign=0)
        title.set_hexpand(True)
        title.add_css_class("notifications-title")
        self.notifications_dnd = Gtk.Button(label="󰂚")
        self.notifications_dnd.add_css_class("mini-button")
        self.notifications_dnd.add_css_class("icon-button")
        self.notifications_dnd.connect("clicked", self.on_toggle_dnd)
        clear = Gtk.Button(label="Clear")
        clear.add_css_class("mini-button")
        clear.connect("clicked", self.on_clear_notifications)
        header.append(title)
        header.append(self.notifications_dnd)
        header.append(clear)

        self.notifications_list = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        card.append(header)
        card.append(self.notifications_list)
        return card

    def on_toggle_dnd(self, *_args):
        next_dnd = not self.notifications_dnd.has_css_class("active")
        self.set_notifications_dnd_state(next_dnd)
        run_detached(["swaync-client", "-d", "-sw"])
        GLib.timeout_add(110, self.refresh_notifications_async)

    def on_clear_notifications(self, *_args):
        run_detached(["swaync-client", "-C", "-sw"])
        clear_notification_history()
        GLib.timeout_add(250, lambda: (self.refresh_async(), False)[1])

    def update_notifications_center(self, status: dict[str, bool | int | list[dict[str, str | int]]]):
        if not self.notifications_list or not self.notifications_dnd:
            return
        count = int(status.get("count") or 0)
        dnd = bool(status.get("dnd"))
        items = status.get("items") or []
        self.set_notifications_dnd_state(dnd)

        child = self.notifications_list.get_first_child()
        while child:
            next_child = child.get_next_sibling()
            self.notifications_list.remove(child)
            child = next_child

        groups = notification_groups(items if isinstance(items, list) else [], count)
        if groups:
            for group in groups[:4]:
                self.notifications_list.append(self.notification_group_widget(group))
        else:
            self.notifications_list.append(self.notification_empty_row("No notifications"))

    def set_notifications_dnd_state(self, dnd: bool):
        if not self.notifications_dnd:
            return
        self.notifications_dnd.set_label("󰂛" if dnd else "󰂚")
        if dnd:
            self.notifications_dnd.add_css_class("active")
        else:
            self.notifications_dnd.remove_css_class("active")
        return False

    def refresh_notifications_async(self):
        def worker():
            status = notification_status()
            GLib.idle_add(self.update_notifications_center, status)

        threading.Thread(target=worker, daemon=True).start()
        return False

    def notification_group_widget(self, group: dict[str, object]):
        items = group.get("items") or []
        if not isinstance(items, list):
            items = []
        key = str(group.get("key") or "")
        expanded = key in self.expanded_notification_groups and len(items) > 1
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5)
        box.add_css_class("notification-row")
        header = hover_reveal_action_row(
            self.notification_group_content(group, expanded),
            lambda group=group: self.on_notification_group_clicked(None, group),
            lambda items=items: self.delete_notification_group(items),
            "notification-group-button",
            delete_tooltip="Delete notification group",
        )
        box.append(header)
        if expanded:
            for item in items[:5]:
                detail = hover_reveal_action_row(
                    self.notification_item_content(item, compact=True),
                    lambda item=item: self.on_notification_item_clicked(None, item),
                    lambda item=item: self.delete_notification_item(item),
                    "notification-detail-button",
                    "notification-detail-row",
                    delete_tooltip="Delete notification",
                )
                box.append(detail)
        return box

    def notification_group_content(self, group: dict[str, object], expanded: bool):
        items = group.get("items") or []
        if not isinstance(items, list) or not items:
            items = [{}]
        latest = items[0]
        app = str(group.get("app") or latest.get("app") or "Notification")
        icon_name = str(group.get("icon") or "dialog-information")
        count = len(items)

        row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=9)
        row.set_hexpand(True)
        icon = self.notification_icon(icon_name)
        row.append(icon)

        text = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        text.set_hexpand(True)
        top = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        app_label = Gtk.Label(label=app[:18], xalign=0)
        app_label.add_css_class("notification-app")
        app_label.set_ellipsize(3)
        app_label.set_hexpand(True)
        time_label = Gtk.Label(label=relative_notification_time(latest.get("time", "")), xalign=1)
        time_label.add_css_class("notification-time")
        top.append(app_label)
        top.append(time_label)

        summary = Gtk.Label(label=str(latest.get("summary") or "")[:42], xalign=0)
        summary.add_css_class("notification-row-title")
        summary.set_ellipsize(3)
        summary.set_max_width_chars(38)
        text.append(top)
        text.append(summary)
        row.append(text)

        if count > 1:
            badge = Gtk.Label(label=f"{'⌃' if expanded else '⌄'} {count}")
            badge.add_css_class("notification-stack-badge")
            row.append(badge)
        return row

    def notification_item_content(self, item: dict[str, str | int], compact: bool = False):
        row = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        summary = Gtk.Label(label=str(item.get("summary") or "Notification")[:46], xalign=0)
        summary.add_css_class("notification-row-title")
        summary.set_ellipsize(3)
        summary.set_max_width_chars(40)
        row.append(summary)
        body = str(item.get("body") or "").strip()
        if body and not compact:
            subtitle = Gtk.Label(label=body[:72], xalign=0)
            subtitle.add_css_class("notification-row-body")
            subtitle.set_ellipsize(3)
            subtitle.set_max_width_chars(40)
            row.append(subtitle)
        return row

    def notification_icon(self, icon_name: str):
        return atom_icon(icon_name, size=28, css="notification-icon")

    def on_notification_group_clicked(self, _button, group: dict[str, object]):
        items = group.get("items") or []
        key = str(group.get("key") or "")
        if isinstance(items, list) and len(items) > 1:
            if key in self.expanded_notification_groups:
                self.expanded_notification_groups.remove(key)
            else:
                self.expanded_notification_groups.add(key)
            self.update_notifications_center(notification_status())
            return
        if isinstance(items, list) and items:
            self.on_notification_item_clicked(_button, items[0])

    def on_notification_item_clicked(self, _button, item: dict[str, str | int]):
        app = str(item.get("app") or "")
        desktop_entry = str(item.get("desktop_entry") or "")
        self.close_panel()

        def worker():
            time.sleep(0.25)
            focus_app_window(app, desktop_entry)

        threading.Thread(target=worker, daemon=True).start()

    def delete_notification_items(self, items: list[dict[str, str | int]]):
        ids = {str(item.get("id", "")).strip() for item in items if isinstance(item, dict) and str(item.get("id", "")).strip()}
        if not ids:
            return

        def worker():
            close_notifications(items)
            remove_notifications_from_history(ids)
            time.sleep(0.15)
            status = notification_status()
            GLib.idle_add(self.update_notifications_center, status)
            GLib.idle_add(self.refresh_async)

        threading.Thread(target=worker, daemon=True).start()

    def delete_notification_group(self, items: list[dict[str, str | int]]):
        self.delete_notification_items(items)

    def delete_notification_item(self, item: dict[str, str | int]):
        self.delete_notification_items([item])

    def notification_empty_row(self, text: str):
        label = Gtk.Label(label=text, xalign=0.5)
        label.add_css_class("notification-empty")
        return label

    def refresh_async(self):
        self.refresh_generation += 1
        generation = self.refresh_generation

        def worker():
            enforce_preferred_input_volume()
            wifi = wifi_status()
            bluetooth = bluetooth_status()
            audio = audio_status()
            mic = mic_status()
            media = player_status()
            volume = current_output_volume()
            mic_volume = current_input_volume()
            art_path = cached_art_path(media[6])
            notifications = notification_status()
            GLib.idle_add(self.apply_status, generation, wifi, bluetooth, audio, mic, media, volume, mic_volume, art_path, notifications)
        threading.Thread(target=worker, daemon=True).start()

    def periodic_refresh(self):
        self.refresh_async()
        return True

    def tick_media_progress(self):
        if self.media_playing and self.media_length > 0:
            now = time.monotonic()
            elapsed = max(0, int(now - self.media_last_tick))
            if elapsed:
                self.media_position = min(self.media_length, self.media_position + elapsed)
                self.media_last_tick = now
                self.update_media_progress()
        return True

    def update_media_progress(self):
        self.updating_media_progress = True
        if self.media_length > 0:
            self.media_progress.set_value(min(100, self.media_position / self.media_length * 100))
            self.media_time.set_label(f"{format_time(self.media_position)} / {format_time(self.media_length)}")
        else:
            self.media_progress.set_value(0)
            self.media_time.set_label("0:00 / 0:00")
        self.updating_media_progress = False

    def apply_status(self, generation, wifi, bluetooth, audio, mic, media, volume, mic_volume, art_path, notifications):
        if generation != self.refresh_generation:
            return False
        self.apply_feature_visual_state("wifi", *wifi)
        self.apply_feature_visual_state("bluetooth", *bluetooth)
        self.apply_feature_visual_state("audio", *audio)
        self.apply_feature_visual_state("mic", *mic)
        title, subtitle, icon, position, length, playing, _art_url, player = media
        self.media_title.set_label(title)
        self.media_subtitle.set_label(subtitle)
        self.media_play.set_label(icon)
        self.media_player = player
        self.media_position = position
        self.media_length = length
        self.media_playing = playing
        self.media_last_tick = time.monotonic()
        self.set_media_art(art_path)
        self.update_media_progress()
        self.update_notifications_center(notifications)
        self.set_volume_value(volume, apply=False)
        self.set_mic_value(mic_volume, apply=False)
        return False

    def set_media_art(self, art_path: str):
        if art_path:
            uri = Path(art_path).resolve().as_uri()
            css = f'''
.media-card {{
  background-image: linear-gradient(90deg, rgba(0,0, 0, 0.42), rgba(4, 11, 10, 0.50)), url("{uri}");
  background-size: cover;
  background-position: center;
  border: 1px solid #ffffff;
}}
'''
        else:
            css = '''
.media-card {
  border: 1px solid rgba(255, 255, 255, 0.10);
  background-image: linear-gradient(90deg, rgba(4, 11, 10, 0.92), rgba(4, 11, 10, 0.72));
}
'''
        self.art_provider.load_from_string(css)

    def open_menu(self, relative_script: str, *args: str):
        self.open_command([str(BASE / relative_script), *args])

    def open_command(self, command: list[str]):
        run_detached(command)
        self.close_panel()
