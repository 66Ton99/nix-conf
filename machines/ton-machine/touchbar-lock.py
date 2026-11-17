"""Mirror logind's local graphical session lock for tiny-dfr."""
from pathlib import Path

import dbus
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

DBusGMainLoop(set_as_default=True)
bus = dbus.SystemBus()
manager = dbus.Interface(
    bus.get_object("org.freedesktop.login1", "/org/freedesktop/login1"),
    "org.freedesktop.login1.Manager",
)
marker = Path("/run/touchbar-lock/locked")


def refresh(*args, **kwargs):
    locked = False
    for session_id, uid, user, seat, path in manager.ListSessions():
        if user != "ton" or seat != "seat0":
            continue
        try:
            props = dbus.Interface(
                bus.get_object("org.freedesktop.login1", path),
                "org.freedesktop.DBus.Properties",
            ).GetAll("org.freedesktop.login1.Session")
        except dbus.DBusException:
            continue  # A session may disappear between listing and reading it.
        if props.get("Active") and props.get("LockedHint"):
            locked = True
    if locked:
        marker.touch(exist_ok=True)
    else:
        marker.unlink(missing_ok=True)


bus.add_signal_receiver(
    refresh,
    signal_name="PropertiesChanged",
    dbus_interface="org.freedesktop.DBus.Properties",
    bus_name="org.freedesktop.login1",
)
for signal in ("SessionNew", "SessionRemoved"):
    bus.add_signal_receiver(
        refresh,
        signal_name=signal,
        dbus_interface="org.freedesktop.login1.Manager",
        bus_name="org.freedesktop.login1",
    )
refresh()
GLib.MainLoop().run()
