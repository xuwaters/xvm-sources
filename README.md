# xvm-sources

The complete corresponding source of the **GPL components** of every published
[xvm](https://github.com/xuwaters/xvm) guest image: the Linux kernel, BusyBox and OpenJDK. Nothing
else lives here. The guest is the riscv64 Linux system that xvm runs inside a browser tab; its
images are served by the xvm site under `img/<version>/` and `chunks/`.

This repository is how xvm meets the source obligation of GPL-2.0 §3 for those binaries (xvm
RFC 005 §7, decisions D14 and D114). It replaces the source archives the site used to serve under
`licenses/src/`. The rest of the licence material stays on the site, per version, under
`licenses/guest/<version>/`: `index.json`, `README.html` with the written offer, `SHA256SUMS`, the
licence texts and notices of every component (musl, zlib and GCC's runtime libraries included; they
are under permissive licences or the GCC Runtime Library Exception and are listed there, not here),
and the small build-recipe files (kernel configuration and patches, scripts, image digests).

## Layout

| path | what | upstream it was taken from |
|---|---|---|
| `linux/` | submodule: Linux, tag `v6.18.56`, commit `17ad2612c11a748b50d32eefc681344b26fea946` | <https://github.com/gregkh/linux> (Greg Kroah-Hartman's GitHub copy of kernel.org's `stable/linux.git`, which has the same tag and commit) |
| `busybox/` | submodule: BusyBox, tag `1_37_0`, commit `be7d1b7b1701d225379bc1665487ed0871b592a5` | <https://github.com/sailfishos-mirror/busybox> (a mirror of the official `git.busybox.net/busybox`, same tag and commit; `github.com/mirror/busybox` stops at 1_36_1) |
| `openjdk/jdk25u/` | submodule: OpenJDK 25 updates, tag `jdk-25.0.4-ga`, commit `0b8bc780f976dab23ec798018fef0b674e885b0c` | <https://github.com/openjdk/jdk25u> |
| `alpine/busybox/` | the Alpine aport (APKBUILD, 44 patches, configs, support files) that built `busybox-static` | aports `c3ef5d10e6ef`, see its `ORIGIN.md` |
| `alpine/openjdk25/` | the Alpine aport (APKBUILD, 4 patches) that built `openjdk25-jdk`/`-jmods`/`-jre-headless` | aports `5a749f43582a`, see its `ORIGIN.md` |
| `index.json` | format `xvm-sources/1`: per component the tag, commit, the archive the build consumed (url, size, sha256), every committed file with its sha256, and how the tag was checked against the archive | |
| `scripts/verify.sh` | re-checks gitlinks and file hashes against `index.json`; `--remote` asks the forks, `--locks <xvm>` checks the xvm lock files | |

Each submodule points at a **fork under `github.com/xuwaters/`** (`linux`, `busybox`, `jdk25u`),
not at the upstream, so the source stays reachable from us whatever happens upstream. A fork has
the same commits, so the shas above are the same in the fork and in the upstream they came from.

## Which version of xvm uses which commit

The xvm repository pins a commit of this repository as its submodule `sources/` (the gitlink). When
xvm publishes a guest version, `licenses/guest/<version>/index.json` on the site records the
`xvm-sources` commit, and the offer links `https://github.com/xuwaters/xvm-sources/tree/<commit>`.
xvm's `scripts/build-guest.sh check` fails when an archive that its lock files
(`guest/licenses/sources.lock`, `guest/kernel/linux.lock`) mark as hosted has no entry with the
same sha256 in this `index.json`. A guest version that changes a component's version needs a new
commit here first.

## Cloning: do not recurse blindly

The submodules are whole source trees (Linux alone is several GB with history). They are declared
`shallow = true` and `update = none` in `.gitmodules`, so `git clone --recurse-submodules` and
`git submodule update --init` (also from xvm, recursively) **skip** them. Fetch the one you want on
purpose; `--checkout` overrides `update = none`, and the clone is depth 1:

```sh
git clone https://github.com/xuwaters/xvm-sources.git && cd xvm-sources
git submodule update --init --checkout busybox          # a few MB
git submodule update --init --checkout openjdk/jdk25u   # hundreds of MB
git submodule update --init --checkout linux            # hundreds of MB to fetch, ~1.5 GB on disk
scripts/verify.sh                                       # gitlinks and file hashes vs index.json
```

## How a tag corresponds to the archive the build consumed

xvm's build never clones these repositories: it downloads each archive by the URL in its lock file
and checks its sha256 (the archive table below; `scripts/verify.sh` prints it). Each archive is a
`git archive` of the tag pinned here. What was checked, on 2026-10-14 (also in `index.json`,
field `verified`):

| component | archive (url, size, sha256) | check | result |
|---|---|---|---|
| Linux 6.18.56 | `https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.18.56.tar.xz`, 154,807,564 B, `4633bbda2ab95eaf2a7af4041236451d6759c72e6946265531af4b3aacefbf89` (`guest/kernel/linux.lock`) | kernel.org makes the stable tarballs from the tag with `git archive`, which writes the commit id into the tar's pax global header. The first 128 KiB of the archive were fetched and decompressed; the tag's `Makefile` was read from GitHub | header `comment=17ad2612c11a748b50d32eefc681344b26fea946` = peeled tag `v6.18.56` in gregkh/linux and in git.kernel.org `stable/linux.git`; `Makefile`: `VERSION = 6`, `PATCHLEVEL = 18`, `SUBLEVEL = 56`. The whole archive was not downloaded or hashed here (the xvm build checks its sha256 every time it fetches it) |
| BusyBox 1.37.0 | `https://busybox.net/downloads/busybox-1.37.0.tar.bz2`, 2,565,764 B, `3311dff32e746499f4df0d5df04d7eb396382d7e108bb9250e7b519b837043a4` (`guest/licenses/sources.lock`) | downloaded (sha256 matched the lock), unpacked, compared with `git archive` of `git clone --depth 1 --branch 1_37_0` (`diff -r`, plus file lists, executable bits, directories) | identical content in all 2,880 files of the tarball, same executable bits, same 167 directories, no symlinks. The only difference: the tarball leaves out the 9 `.gitignore` files of the tag (top level, `applets/`, `docs/`, `include/`, `scripts/basic/`, `scripts/kconfig/`, `scripts/kconfig/lxdialog/`, `shell/ash_test/`, `shell/hush_test/`) |
| OpenJDK 25.0.4 | `https://github.com/openjdk/jdk25u/archive/jdk-25.0.4-ga.tar.gz`, 119,669,964 B, `85934f45ebfde0024a76e3dce86218236c3712687689bf00f24c559ac1ed0e6a` (`guest/licenses/sources.lock`) | the URL is GitHub's archive of the tag itself (generated by `git archive`); downloaded again | byte-identical to the lock (same size, same sha256); its pax header names commit `0b8bc780f976dab23ec798018fef0b674e885b0c` = peeled tag `jdk-25.0.4-ga` |

To check one yourself: fetch the archive by its URL, compare its sha256 with `index.json`, and either
read the commit id from its pax header
(`xz -dc linux-6.18.56.tar.xz | head -c 1024 | strings | grep comment=`) or compare its unpacked tree
with `git -C <submodule> archive --prefix=<dir>/ HEAD | tar -x`.

The Alpine aport files under `alpine/` were downloaded from their lock URLs (the aports commit is in
each URL) and match the lock's sha256; `scripts/verify.sh` re-hashes them against `index.json`.

## Building from this source

The binaries in the guest image are built as follows; the scripts are in the xvm repository at the
commit that pins this one, and copies of the small recipe files are published per version under
`licenses/guest/<version>/` on the site.

* **Linux:** the tag plus libkrunfw's patches 0001/0002 (authorship kept) and the configuration
  (libkrunfw's riscv64 config + `xvm.config`, `olddefconfig`), built by `guest/kernel/kbuild.sh` in
  the container of `guest/kernel/Dockerfile` (`guest/images.lock` pins it).
* **BusyBox:** Alpine's `busybox-static` package, built from the tag (= the archive) with the patches
  and `busyboxconfig` in `alpine/busybox/`; xvm installs the package unchanged.
* **OpenJDK:** Alpine's `openjdk25` packages, built from the tag (= the archive) with the patches in
  `alpine/openjdk25/`; xvm then runs `jlink` over the modules in `guest/jdk/jlink.args` and dumps the
  CDS archives (`guest/jdk/build.sh`). Neither step changes the source.

## Licence

Each component keeps its own licence (Linux: GPL-2.0-only WITH Linux-syscall-note; BusyBox:
GPL-2.0-only; OpenJDK: GPL-2.0-only WITH Classpath-exception-2.0; the aport files: the Alpine aports
tree's terms). Our own files here (`README.md`, `index.json`, `alpine/*/ORIGIN.md`, `scripts/`,
`.gitmodules`) are MIT; see [LICENSE](LICENSE).
