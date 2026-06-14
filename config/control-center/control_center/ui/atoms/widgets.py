from pathlib import Path

from control_center.gtk import Gtk
from control_center.services.icons import resolved_icon_path


def label(text: str = "", xalign: float = 0, css: str | None = None, max_chars: int | None = None) -> Gtk.Label:
    widget = Gtk.Label(label=text, xalign=xalign)
    if css:
        widget.add_css_class(css)
    if max_chars:
        widget.set_ellipsize(3)
        widget.set_max_width_chars(max_chars)
        widget.set_width_chars(1)
    return widget


def button(text: str = "", css: str | None = None) -> Gtk.Button:
    widget = Gtk.Button(label=text) if text else Gtk.Button()
    if css:
        widget.add_css_class(css)
    return widget


def icon(icon_name: str, size: int = 28, css: str | None = None) -> Gtk.Image:
    icon_path = resolved_icon_path(icon_name)
    if icon_path and Path(icon_path).exists():
        image = Gtk.Image.new_from_file(icon_path)
    else:
        image = Gtk.Image.new_from_icon_name(icon_name or "dialog-information")
    image.set_pixel_size(size)
    if css:
        image.add_css_class(css)
    return image


def spinner_row(message: str) -> Gtk.Box:
    row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
    row.add_css_class("embedded-row")
    spinner = Gtk.Spinner()
    spinner.start()
    text = label(message, xalign=0)
    text.set_hexpand(True)
    row.append(spinner)
    row.append(text)
    return row
