# Control Center UI organization

This package follows an atomic-design split for the GTK control center:

- `ui/atoms`: single GTK primitives such as labels, buttons, icons and spinners.
- `ui/molecules`: reusable rows/cards composed from atoms.
- `ui/organisms`: larger panel/page composition helpers.

The `ControlCenter` application coordinates state, services, and callbacks.
