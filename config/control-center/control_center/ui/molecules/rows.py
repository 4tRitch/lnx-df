from control_center.gtk import Gtk
from control_center.ui.atoms.widgets import label


def detail_button_row(text: str, command: list[str]) -> Gtk.Button:
    button = Gtk.Button()
    row_label = label(text, xalign=0.5, max_chars=38)
    row_label.set_hexpand(True)
    button.set_child(row_label)
    button.add_css_class("embedded-row")
    button.set_halign(Gtk.Align.FILL)
    marker_source = text.replace("  ", " ")
    if "* " in marker_source:
        button.add_css_class("connected-row")
    return button


def section_label(text: str) -> Gtk.Label:
    return label(text, xalign=0, css="detail-section")


def plain_detail_row(text: str) -> Gtk.Label:
    widget = label(text, xalign=0.5)
    widget.add_css_class("embedded-row")
    return widget
