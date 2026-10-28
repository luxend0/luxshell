#!/usr/bin/env python3
"""Fake MPRIS player for the sandbox (own D-Bus, tools/sandbox.sh run ... LUXSB_DBUS=1).

NEVER run this on the real session bus: it is only meant for the private bus of a sandbox,
so luxshell can be steered against something that is not the user's Spotify. The bus name is
org.mpris.MediaPlayer2.luxshelltest[.<suffix>]; services/Media.qml lets only this name through
while LUXSHELL_DRYRUN=1 (every other player just logs).

  DBUS_SESSION_BUS_ADDRESS=$(cat $XDG_RUNTIME_DIR/luxsandbox/<name>.dbus) \\
      mpris-test-player.py [--suffix two | --bus-name org.mpris.MediaPlayer2.x] [--identity Spotify] [--paused] [--no-volume] \\
                           [--track 'Title|Artist|Album|seconds|file:///cover.png' ...]

Every method call / property write is printed to stdout (one line each), so a test can check
that a click or key in the shell reached the player.
"""
import argparse, os, sys, time
from gi.repository import Gio, GLib

XML = """
<node>
  <interface name="org.mpris.MediaPlayer2">
    <method name="Raise"/>
    <method name="Quit"/>
    <property name="CanQuit" type="b" access="read"/>
    <property name="CanRaise" type="b" access="read"/>
    <property name="HasTrackList" type="b" access="read"/>
    <property name="Identity" type="s" access="read"/>
    <property name="DesktopEntry" type="s" access="read"/>
    <property name="SupportedUriSchemes" type="as" access="read"/>
    <property name="SupportedMimeTypes" type="as" access="read"/>
  </interface>
  <interface name="org.mpris.MediaPlayer2.Player">
    <method name="Next"/>
    <method name="Previous"/>
    <method name="Pause"/>
    <method name="PlayPause"/>
    <method name="Stop"/>
    <method name="Play"/>
    <method name="Seek"><arg direction="in" name="Offset" type="x"/></method>
    <method name="SetPosition"><arg direction="in" name="TrackId" type="o"/><arg direction="in" name="Position" type="x"/></method>
    <method name="OpenUri"><arg direction="in" name="Uri" type="s"/></method>
    <signal name="Seeked"><arg name="Position" type="x"/></signal>
    <property name="PlaybackStatus" type="s" access="read"/>
    <property name="LoopStatus" type="s" access="readwrite"/>
    <property name="Rate" type="d" access="readwrite"/>
    <property name="Shuffle" type="b" access="readwrite"/>
    <property name="Metadata" type="a{sv}" access="read"/>
    <property name="Volume" type="d" access="readwrite"/>
    <property name="Position" type="x" access="read"/>
    <property name="MinimumRate" type="d" access="read"/>
    <property name="MaximumRate" type="d" access="read"/>
    <property name="CanGoNext" type="b" access="read"/>
    <property name="CanGoPrevious" type="b" access="read"/>
    <property name="CanPlay" type="b" access="read"/>
    <property name="CanPause" type="b" access="read"/>
    <property name="CanSeek" type="b" access="read"/>
    <property name="CanControl" type="b" access="read"/>
  </interface>
</node>
"""
ROOT = "org.mpris.MediaPlayer2"
PLAYER = "org.mpris.MediaPlayer2.Player"
PATH = "/org/mpris/MediaPlayer2"


def log(msg):
    print(f"{time.strftime('%H:%M:%S')} {msg}", flush=True)


class Player:
    def __init__(self, a):
        self.identity = a.identity
        self.tracks = []
        for t in a.track or []:
            f = (t.split("|") + [""] * 5)[:5]
            self.tracks.append({"title": f[0], "artist": f[1], "album": f[2], "length": float(f[3] or 200), "art": f[4]})
        if not self.tracks:
            self.tracks = [{"title": "Test Track", "artist": "luxshell", "album": "Sandbox", "length": 200.0, "art": ""}]
        self.index = 0
        self.playing = not a.paused
        self.volume = 0.8
        self.volume_ok = not a.no_volume
        self.offset = 0.0           # position (s) at self.since
        self.since = time.monotonic()
        self.conn = None

    # ---- state -------------------------------------------------------------
    def position(self):
        p = self.offset + (time.monotonic() - self.since if self.playing else 0)
        return min(p, self.track()["length"])

    def set_position(self, p):
        self.offset = max(0.0, min(p, self.track()["length"]))
        self.since = time.monotonic()

    def track(self):
        return self.tracks[self.index]

    def metadata(self):
        t = self.track()
        md = {
            "mpris:trackid": GLib.Variant("o", f"/luxshell/test/track/{self.index}"),
            "mpris:length": GLib.Variant("x", int(t["length"] * 1e6)),
            "xesam:title": GLib.Variant("s", t["title"]),
            "xesam:artist": GLib.Variant("as", [t["artist"]]),
            "xesam:album": GLib.Variant("s", t["album"]),
        }
        if t["art"]:
            md["mpris:artUrl"] = GLib.Variant("s", t["art"])
        return md

    def status(self):
        return "Playing" if self.playing else "Paused"

    def prop(self, iface, name):
        if iface == ROOT:
            return {
                "CanQuit": GLib.Variant("b", False), "CanRaise": GLib.Variant("b", True),
                "HasTrackList": GLib.Variant("b", False), "Identity": GLib.Variant("s", self.identity),
                "DesktopEntry": GLib.Variant("s", self.identity.lower()),
                "SupportedUriSchemes": GLib.Variant("as", []), "SupportedMimeTypes": GLib.Variant("as", []),
            }.get(name)
        v = {
            "PlaybackStatus": GLib.Variant("s", self.status()), "LoopStatus": GLib.Variant("s", "None"),
            "Rate": GLib.Variant("d", 1.0), "Shuffle": GLib.Variant("b", False),
            "Metadata": GLib.Variant("a{sv}", self.metadata()),
            "Position": GLib.Variant("x", int(self.position() * 1e6)),
            "MinimumRate": GLib.Variant("d", 1.0), "MaximumRate": GLib.Variant("d", 1.0),
            "CanGoNext": GLib.Variant("b", True), "CanGoPrevious": GLib.Variant("b", True),
            "CanPlay": GLib.Variant("b", True), "CanPause": GLib.Variant("b", True),
            "CanSeek": GLib.Variant("b", True), "CanControl": GLib.Variant("b", True),
        }
        if self.volume_ok:
            v["Volume"] = GLib.Variant("d", self.volume)
        return v.get(name)

    def changed(self, *names):
        props = {n: self.prop(PLAYER, n) for n in names if self.prop(PLAYER, n) is not None}
        self.conn.emit_signal(None, PATH, "org.freedesktop.DBus.Properties", "PropertiesChanged",
                              GLib.Variant("(sa{sv}as)", (PLAYER, props, [])))

    def seeked(self):
        self.conn.emit_signal(None, PATH, PLAYER, "Seeked", GLib.Variant("(x)", (int(self.position() * 1e6),)))

    def go(self, d):
        self.index = (self.index + d) % len(self.tracks)
        self.set_position(0)
        self.changed("Metadata", "PlaybackStatus")
        self.seeked()

    # ---- D-Bus callbacks -----------------------------------------------------
    def call(self, conn, sender, path, iface, method, params, inv):
        args = params.unpack()
        log(f"call {method}{'' if not args else ' ' + repr(args)}")
        if method in ("PlayPause", "Play", "Pause", "Stop"):
            pos = self.position()
            self.playing = {"PlayPause": not self.playing, "Play": True}.get(method, False)
            self.set_position(0 if method == "Stop" else pos)
            self.changed("PlaybackStatus")
        elif method == "Next":
            self.go(1)
        elif method == "Previous":
            if self.position() > 3:
                self.set_position(0)
                self.seeked()
            else:
                self.go(-1)
        elif method == "Seek":
            self.set_position(self.position() + args[0] / 1e6)
            self.seeked()
        elif method == "SetPosition":
            if args[0] == f"/luxshell/test/track/{self.index}":
                self.set_position(args[1] / 1e6)
                self.seeked()
        inv.return_value(None)

    def get(self, conn, sender, path, iface, name):
        return self.prop(iface, name)

    def set(self, conn, sender, path, iface, name, value):
        log(f"set {name} = {value.unpack()!r}")
        if name == "Volume" and self.volume_ok:
            self.volume = max(0.0, min(1.0, value.unpack()))
            self.changed("Volume")
        return True

    def tick(self):
        if self.playing and self.position() >= self.track()["length"] - 0.05:
            self.go(1)
        return True


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--suffix", default="")
    ap.add_argument("--bus-name", default="", help="full bus name instead of luxshelltest (tests the dry-run gate)")
    ap.add_argument("--identity", default="Spotify")
    ap.add_argument("--paused", action="store_true")
    ap.add_argument("--no-volume", action="store_true")
    ap.add_argument("--track", action="append")
    a = ap.parse_args()
    addr = os.environ.get("DBUS_SESSION_BUS_ADDRESS", "")
    real = "path=" + os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}") + "/bus"
    if not addr or any(part.split(":")[-1] == real for part in addr.split(",")) or addr.endswith(real):
        sys.exit("refusing to run without a sandbox bus (DBUS_SESSION_BUS_ADDRESS from luxsandbox/<name>.dbus)")

    player = Player(a)
    conn = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    player.conn = conn
    node = Gio.DBusNodeInfo.new_for_xml(XML)
    for iface in node.interfaces:
        conn.register_object(PATH, iface, player.call, player.get, player.set)
    name = a.bus_name or "org.mpris.MediaPlayer2.luxshelltest" + (f".{a.suffix}" if a.suffix else "")
    Gio.bus_own_name_on_connection(conn, name, Gio.BusNameOwnerFlags.NONE,
                                   lambda *_: log(f"owned {name}"), lambda *_: sys.exit(f"lost {name}"))
    GLib.timeout_add(500, player.tick)
    GLib.MainLoop().run()


if __name__ == "__main__":
    main()
