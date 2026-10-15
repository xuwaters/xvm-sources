# alpine/openjdk25

The Alpine Linux aport that built `openjdk25-jdk`, `openjdk25-jmods` and `openjdk25-jre-headless` (`25.0.4_p7-r0`), the JDK the guest's
jlinked runtime is made from: the `APKBUILD` and every patch it applies, byte for byte as they are
at the aports commit below. Every file here is listed in `../../index.json` (component `openjdk`,
`files`) with its URL and sha256, taken from xvm's `guest/licenses/sources.lock`.

| | |
|---|---|
| aports commit | `5a749f43582ad0818c27b83b720fba169f72ae58` (from the packages' `.PKGINFO`) |
| directory | <https://gitlab.alpinelinux.org/alpine/aports/-/tree/5a749f43582ad0818c27b83b720fba169f72ae58/community/openjdk25> |
| raw file URL | `https://gitlab.alpinelinux.org/alpine/aports/-/raw/5a749f43582ad0818c27b83b720fba169f72ae58/community/openjdk25/<file>` |
| upstream source | `jdk-25.0.4-ga.tar.gz` = tag `jdk-25.0.4-ga` of `openjdk/jdk25u`, the submodule `../../openjdk/jdk25u` |
| licence of these files | the aports tree's own terms; the patches modify GPL-2.0-only WITH Classpath-exception-2.0 code |

`APKBUILD` also names a prebuilt documentation archive and googletest; neither reaches any binary
in the guest image, so they are not part of the corresponding source (xvm RFC 005 §17.4 item 2).
How xvm turns the package into the guest's runtime (jlink, CDS archives) is in the xvm repository,
`guest/jdk/` (`build.sh`, `jlink.args`), and in each published version's
`licenses/guest/<v>/openjdk/recipe/`.
