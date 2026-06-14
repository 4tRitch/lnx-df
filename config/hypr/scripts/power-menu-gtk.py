#!/usr/bin/env python3
from __future__ import annotations

import shutil
import subprocess
from dataclasses import dataclass
from pathlib import Path

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("GtkLayerShell", "0.1")

from gi.repository import Gdk, Gtk, GtkLayerShell  # noqa: E402


HOME = Path.home()
SCRIPT_DIR = HOME / ".config" / "hypr" / "scripts"
ICON_DIR = HOME / ".config" / "wlogout" / "icons"


@dataclass(frozen=True)
class PowerAction:
    label: str
    icon: Path
    selected_icon: Path
    command: tuple[str, ...]


ACTIONS = (
    PowerAction(
        "Lock",
        ICON_DIR / "lock.svg",
        ICON_DIR / "lock-dark.svg",
        ("hyprlock",),
    ),
    PowerAction(
        "Logout",
        ICON_DIR / "logout.svg",
        ICON_DIR / "logout-dark.svg",
        (str(SCRIPT_DIR / "shutdown-menu.sh"), "logout"),
    ),
    PowerAction(
        "Reboot",
        ICON_DIR / "reboot.svg",
        ICON_DIR / "reboot-dark.svg",
        (str(SCRIPT_DIR / "shutdown-menu.sh"), "reboot"),
    ),
    PowerAction(
        "Shutdown",
        ICON_DIR / "shutdown.svg",
        ICON_DIR / "shutdown-dark.svg",
        (str(SCRIPT_DIR / "shutdown-menu.sh"), "shutdown"),
    ),
)


CSS = """
window {
  background-color: transparent;
}

.background-hit-area {
  background-color: rgba(8, 10, 12, 0.28);
}

.power-menu {
  background-color: transparent;
}

.power-card {
  min-width: 166px;
  min-height: 148px;
  padding: 24px 14px 18px 14px;
  border-radius: 26px;
  border: 1px solid rgba(255, 255, 255, 0.10);
  background-image: none;
  background-color: rgba(19, 21, 24, 0.40);
  box-shadow: none;
  color: #f5f6f7;
  text-shadow: none;
}

.power-card.selected {
  border-color: rgba(255, 255, 255, 0.28);
  background-color: rgba(228, 232, 236, 0.86);
  color: #0d1013;
}

.power-card label {
  color: inherit;
  font-family: "Inter", sans-serif;
  font-size: 17px;
  font-weight: 600;
}
"""


class PowerMenu(Gtk.Application):
    def __init__(self) -> None:
        super().__init__(application_id="dev.ritch.PowerMenu")
        self.window: Gtk.ApplicationWindow | None = None
        self.buttons: list[Gtk.Button] = []
        self.icons: list[Gtk.Image] = []
        self.selected = 0

    def do_activate(self) -> None:
        self.install_css()

        self.window = Gtk.ApplicationWindow(application=self)
        self.window.set_title("power-menu")
        self.window.set_decorated(False)
        self.window.set_resizable(False)
        self.window.set_app_paintable(True)

        screen = self.window.get_screen()
        visual = screen.get_rgba_visual()
        if visual is not None:
            self.window.set_visual(visual)

        GtkLayerShell.init_for_window(self.window)
        GtkLayerShell.set_namespace(self.window, "logout_dialog")
        GtkLayerShell.set_layer(self.window, GtkLayerShell.Layer.OVERLAY)
        GtkLayerShell.set_keyboard_mode(
            self.window,
            GtkLayerShell.KeyboardMode.EXCLUSIVE,
        )
        GtkLayerShell.set_exclusive_zone(self.window, -1)

        for edge in (
            GtkLayerShell.Edge.TOP,
            GtkLayerShell.Edge.RIGHT,
            GtkLayerShell.Edge.BOTTOM,
            GtkLayerShell.Edge.LEFT,
        ):
            GtkLayerShell.set_anchor(self.window, edge, True)

        root = Gtk.Overlay()
        root.set_hexpand(True)
        root.set_vexpand(True)

        hit_area = Gtk.EventBox()
        hit_area.set_visible_window(True)
        hit_area.get_style_context().add_class("background-hit-area")
        hit_area.set_hexpand(True)
        hit_area.set_vexpand(True)
        hit_area.connect("button-press-event", self.on_background_clicked)
        root.add(hit_area)

        menu = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=18)
        menu.get_style_context().add_class("power-menu")
        menu.set_halign(Gtk.Align.CENTER)
        menu.set_valign(Gtk.Align.CENTER)

        for index, action in enumerate(ACTIONS):
            button, icon = self.build_button(index, action)
            self.buttons.append(button)
            self.icons.append(icon)
            menu.pack_start(button, False, False, 0)

        root.add_overlay(menu)
        self.window.add(root)

        self.window.connect("key-press-event", self.on_key_pressed)

        self.set_selected(0)
        self.window.show_all()
        self.buttons[0].grab_focus()

    def install_css(self) -> None:
        provider = Gtk.CssProvider()
        provider.load_from_data(CSS.encode("utf-8"))
        screen = Gdk.Screen.get_default()
        if screen is None:
            return
        Gtk.StyleContext.add_provider_for_screen(
            screen,
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
        )

    def build_button(self, index: int, action: PowerAction) -> tuple[Gtk.Button, Gtk.Image]:
        icon = Gtk.Image.new_from_file(str(action.icon))
        icon.set_pixel_size(46)

        label = Gtk.Label(label=action.label)

        content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14)
        content.set_halign(Gtk.Align.CENTER)
        content.set_valign(Gtk.Align.CENTER)
        content.pack_start(icon, False, False, 0)
        content.pack_start(label, False, False, 0)

        button = Gtk.Button()
        button.get_style_context().add_class("power-card")
        button.add(content)
        button.set_can_focus(True)
        button.add_events(
            Gdk.EventMask.ENTER_NOTIFY_MASK
            | Gdk.EventMask.POINTER_MOTION_MASK,
        )
        button.connect("clicked", lambda _button: self.activate(index))
        button.connect("enter-notify-event", self.on_button_entered, index)
        button.connect("motion-notify-event", self.on_button_moved, index)
        button.connect("focus-in-event", self.on_button_focused, index)
        button.connect("state-flags-changed", self.on_button_state_changed, index)

        return button, icon

    def on_button_entered(self, _button: Gtk.Button, _event: Gdk.Event, index: int) -> bool:
        self.set_selected(index)
        return False

    def on_button_moved(self, _button: Gtk.Button, _event: Gdk.Event, index: int) -> bool:
        self.set_selected(index)
        return False

    def on_button_focused(self, _button: Gtk.Button, _event: Gdk.Event, index: int) -> bool:
        self.set_selected(index)
        return False

    def on_button_state_changed(
        self,
        button: Gtk.Button,
        _previous_flags: Gtk.StateFlags,
        index: int,
    ) -> None:
        if button.get_state_flags() & Gtk.StateFlags.PRELIGHT:
            self.set_selected(index)

    def set_selected(self, index: int) -> None:
        self.selected = index % len(ACTIONS)

        for current, (button, icon, action) in enumerate(
            zip(self.buttons, self.icons, ACTIONS, strict=True),
        ):
            is_selected = current == self.selected
            style = button.get_style_context()
            if is_selected:
                style.add_class("selected")
                icon.set_from_file(str(action.selected_icon))
            else:
                style.remove_class("selected")
                icon.set_from_file(str(action.icon))

    def activate(self, index: int) -> None:
        action = ACTIONS[index]
        if action.label == "Lock" and shutil.which("hyprlock") is None:
            self.quit()
            return

        subprocess.Popen(
            action.command,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
        self.quit()

    def on_background_clicked(self, *_args: object) -> bool:
        self.quit()
        return True

    def on_key_pressed(
        self,
        _window: Gtk.ApplicationWindow,
        event: Gdk.EventKey,
    ) -> bool:
        key = Gdk.keyval_name(event.keyval)
        if key in {"Escape", "q", "Q"}:
            self.quit()
            return True

        if key in {"Left", "h", "H", "Up", "k", "K"}:
            self.set_selected(self.selected - 1)
            self.buttons[self.selected].grab_focus()
            return True

        if key in {"Right", "l", "L", "Down", "j", "J"}:
            self.set_selected(self.selected + 1)
            self.buttons[self.selected].grab_focus()
            return True

        if key in {"Return", "KP_Enter", "space"}:
            self.activate(self.selected)
            return True

        return False


if __name__ == "__main__":
    raise SystemExit(PowerMenu().run())
