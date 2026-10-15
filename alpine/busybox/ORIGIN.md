# alpine/busybox

The Alpine Linux aport that built the guest's BusyBox (`busybox-static-1.37.0-r31`, riscv64):
the `APKBUILD`, every patch it applies to the BusyBox source, the configuration (`busyboxconfig`)
and the support files, byte for byte as they are at the aports commit below. Every file here is
listed in `../../index.json` (component `busybox`, `files`) with its URL and sha256, taken from
xvm's `guest/licenses/sources.lock`.

| | |
|---|---|
| aports commit | `c3ef5d10e6ef6528852c51f0564963e2f8c1be19` (from the package's `.PKGINFO`) |
| directory | <https://gitlab.alpinelinux.org/alpine/aports/-/tree/c3ef5d10e6ef6528852c51f0564963e2f8c1be19/main/busybox> |
| raw file URL | `https://gitlab.alpinelinux.org/alpine/aports/-/raw/c3ef5d10e6ef6528852c51f0564963e2f8c1be19/main/busybox/<file>` |
| upstream source | `busybox-1.37.0.tar.bz2` = tag `1_37_0` of BusyBox, the submodule `../../busybox` (see `../../README.md`) |
| licence of these files | the aports tree's own terms; the patches modify GPL-2.0-only code |

To rebuild: unpack the tag (or the archive), apply the patches in the order of `source=` in
`APKBUILD`, configure with `busyboxconfig`, and build as `APKBUILD`'s `build()` does (Alpine's
`abuild`).
