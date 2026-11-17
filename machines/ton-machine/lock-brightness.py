"""Preserve the internal panel's actual brightness across screen locking."""
import json
import os
from pathlib import Path
import sys

import dbus
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

DBusGMainLoop(set_as_default=True)
bus = dbus.SessionBus()
state = Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")) / "lock-brightness.json"
panel = Path("/sys/class/backlight/gmux_backlight/brightness")


def display():
    obj = bus.get_object("org.gnome.Mutter.DisplayConfig", "/org/gnome/Mutter/DisplayConfig")
    serial, outputs = dbus.Interface(obj, "org.freedesktop.DBus.Properties").Get(
        "org.gnome.Mutter.DisplayConfig", "Backlight")
    return obj, serial, outputs


def capture():
    obj, serial, outputs = display()
    for output in outputs:
        if str(output.get("connector", "")).startswith("eDP-") and "value" in output:
            state.write_text(json.dumps({
                "connector": str(output["connector"]),
                "value": int(panel.read_text()),
            }))
            print(f"Saved brightness: {panel.read_text().strip()}", flush=True)
            return


def reapply_hardware(value):
    # Mutter may skip an unchanged cached value even after the panel has lost
    # its hardware state. logind writes through the backlight driver regardless
    # of Mutter's cached property; the active session owner needs no elevation.
    system_bus = dbus.SystemBus()
    manager = dbus.Interface(system_bus.get_object(
        "org.freedesktop.login1", "/org/freedesktop/login1"),
        "org.freedesktop.login1.Manager")
    for session_id, uid, user, seat, path in manager.ListSessions():
        if int(uid) != os.getuid() or seat != "seat0":
            continue
        obj = system_bus.get_object("org.freedesktop.login1", path)
        active = dbus.Interface(obj, "org.freedesktop.DBus.Properties").Get(
            "org.freedesktop.login1.Session", "Active")
        if active:
            dbus.Interface(obj, "org.freedesktop.login1.Session").SetBrightness(
                "backlight", "gmux_backlight", dbus.UInt32(value))
            print(f"Reapplied hardware brightness via logind: {value}", flush=True)
            return
    raise RuntimeError("No active local session for hardware brightness restore")


def restore():
    try:
        if not state.exists():
            return GLib.SOURCE_REMOVE
        saved = json.loads(state.read_text())
        obj, serial, outputs = display()
        for output in outputs:
            if output.get("connector") == saved["connector"] and "value" in output:
                value = max(int(output["min"]), min(int(output["max"]), saved["value"]))
                dbus.Interface(obj, "org.gnome.Mutter.DisplayConfig").SetBacklight(
                    serial, saved["connector"], dbus.Int32(value))
                reapply_hardware(value)
                print(f"Restored brightness: {value}; driver: {panel.read_text().strip()}", flush=True)
                state.unlink(missing_ok=True)
                break
    except (dbus.DBusException, OSError, ValueError, KeyError, RuntimeError) as error:
        print(f"Brightness restore failed: {error}", file=sys.stderr, flush=True)
    return GLib.SOURCE_REMOVE


if sys.argv[1:] == ["capture"]:
    capture()
else:
    print("Watching GNOME screen lock state", flush=True)
    pending = 0

    def changed(active):
        global pending
        if pending:
            GLib.source_remove(pending)
            pending = 0
        if active:
            if not state.exists():
                try:
                    capture()
                except (dbus.DBusException, OSError, ValueError) as error:
                    print(f"Brightness capture failed: {error}", file=sys.stderr, flush=True)
        else:
            def after_unlock():
                global pending
                pending = 0
                return restore()
            pending = GLib.timeout_add(300, after_unlock)

    bus.add_signal_receiver(changed, signal_name="ActiveChanged",
                            dbus_interface="org.gnome.ScreenSaver",
                            bus_name="org.gnome.ScreenSaver")
    GLib.MainLoop().run()
