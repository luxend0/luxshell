// Sandbox-only click helper (wlr-virtual-pointer): left click or a short horizontal drag at
// the current cursor position on the display given as argv[1], i.e. the NESTED sandbox
// compositor. Refuses the real session display ($REAL_WAYLAND_DISPLAY). Built and used by
// tools/media-clicktest.sh; vp.xml is the minimal wlr-virtual-pointer-unstable-v1 subset.
//   vclick <wayland-display> click          press+release
//   vclick <wayland-display> drag DX        press, move DX px in steps, release
//   vclick <wayland-display> wiggle         only the 1 px motion: delivers enter/leave after a
//                                           hyprctl cursor warp (which sends no motion itself)
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <wayland-client.h>
#include "vp-client.h"
static struct zwlr_virtual_pointer_manager_v1 *mgr;
static struct wl_seat *seat;
static void reg(void *d, struct wl_registry *r, uint32_t name, const char *iface, uint32_t v) {
    if (!strcmp(iface, zwlr_virtual_pointer_manager_v1_interface.name)) mgr = wl_registry_bind(r, name, &zwlr_virtual_pointer_manager_v1_interface, 1);
    else if (!strcmp(iface, wl_seat_interface.name)) seat = wl_registry_bind(r, name, &wl_seat_interface, 1);
}
static void unreg(void *d, struct wl_registry *r, uint32_t n) {}
static const struct wl_registry_listener rl = { reg, unreg };
int main(int argc, char **argv) {
    if (argc < 3) { fprintf(stderr, "usage: vclick <display> click|drag DX|wiggle\n"); return 1; }
    const char *real = getenv("REAL_WAYLAND_DISPLAY");
    if (!real || !strcmp(real, argv[1])) { fprintf(stderr, "refusing: set REAL_WAYLAND_DISPLAY and use the sandbox display\n"); return 2; }
    struct wl_display *dpy = wl_display_connect(argv[1]);
    if (!dpy) { fprintf(stderr, "no display %s\n", argv[1]); return 1; }
    struct wl_registry *r = wl_display_get_registry(dpy);
    wl_registry_add_listener(r, &rl, NULL);
    wl_display_roundtrip(dpy);
    if (!mgr) { fprintf(stderr, "no virtual pointer manager\n"); return 1; }
    struct zwlr_virtual_pointer_v1 *p = zwlr_virtual_pointer_manager_v1_create_virtual_pointer(mgr, seat);
    uint32_t t = 1000;
    // tiny wiggle so the client has a fresh position, then back
    zwlr_virtual_pointer_v1_motion(p, t++, wl_fixed_from_int(1), 0); zwlr_virtual_pointer_v1_frame(p);
    zwlr_virtual_pointer_v1_motion(p, t++, wl_fixed_from_int(-1), 0); zwlr_virtual_pointer_v1_frame(p);
    wl_display_roundtrip(dpy); usleep(50000);
    if (!strcmp(argv[2], "wiggle")) { zwlr_virtual_pointer_v1_destroy(p); wl_display_roundtrip(dpy); wl_display_disconnect(dpy); return 0; }
    zwlr_virtual_pointer_v1_button(p, t++, 0x110, 1); zwlr_virtual_pointer_v1_frame(p);
    wl_display_roundtrip(dpy); usleep(60000);
    if (!strcmp(argv[2], "drag") && argc > 3) {
        int dx = atoi(argv[3]), steps = 10;
        for (int i = 0; i < steps; i++) {
            zwlr_virtual_pointer_v1_motion(p, t++, wl_fixed_from_double((double)dx / steps), 0); zwlr_virtual_pointer_v1_frame(p);
            wl_display_roundtrip(dpy); usleep(20000);
        }
    }
    zwlr_virtual_pointer_v1_button(p, t++, 0x110, 0); zwlr_virtual_pointer_v1_frame(p);
    wl_display_roundtrip(dpy); usleep(50000);
    zwlr_virtual_pointer_v1_destroy(p);
    wl_display_roundtrip(dpy);
    wl_display_disconnect(dpy);
    return 0;
}
