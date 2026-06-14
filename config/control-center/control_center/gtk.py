import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Gdk", "4.0")
try:
    gi.require_version("Gtk4LayerShell", "1.0")
    from gi.repository import Gtk4LayerShell  # noqa: F401
except (ImportError, ValueError):
    Gtk4LayerShell = None
from gi.repository import Gdk, GLib, Gtk  # noqa: F401,E402
