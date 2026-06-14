from collections.abc import Callable

from control_center.gtk import GLib, Gtk


def hover_reveal_action_row(
    content: Gtk.Widget,
    on_activate: Callable[[], None],
    on_delete: Callable[[], None],
    button_css: str,
    row_css: str | None = None,
    hover_delay_ms: int = 1500,
    delete_tooltip: str = "Remove notification",
    always_show_delete: bool = True,
) -> Gtk.Box:
    row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
    row.add_css_class("notification-action-row")
    if row_css:
        row.add_css_class(row_css)

    content_button = Gtk.Button()
    content_button.add_css_class(button_css)
    content_button.set_hexpand(True)
    content_button.set_child(content)
    content_button.connect("clicked", lambda *_: on_activate())

    delete_button = Gtk.Button(label="×")
    delete_button.add_css_class("notification-delete-button")
    delete_button.set_tooltip_text(delete_tooltip)
    delete_button.set_valign(Gtk.Align.CENTER)
    delete_button.set_visible(always_show_delete)
    delete_button.connect("clicked", lambda *_: on_delete())

    hover_state = {"active": False, "source": 0}

    def cancel_pending_reveal() -> None:
        if hover_state["source"]:
            GLib.source_remove(hover_state["source"])
            hover_state["source"] = 0

    def reveal_delete_button() -> bool:
        hover_state["source"] = 0
        if hover_state["active"] and not always_show_delete:
            delete_button.set_visible(True)
        return False

    def on_enter(_controller, _x, _y):
        if always_show_delete:
            return
        hover_state["active"] = True
        cancel_pending_reveal()
        hover_state["source"] = GLib.timeout_add(hover_delay_ms, reveal_delete_button)

    def on_leave(_controller):
        if always_show_delete:
            return
        hover_state["active"] = False
        cancel_pending_reveal()
        delete_button.set_visible(False)

    motion = Gtk.EventControllerMotion.new()
    motion.connect("enter", on_enter)
    motion.connect("leave", on_leave)
    row.add_controller(motion)

    row.append(content_button)
    row.append(delete_button)
    return row
