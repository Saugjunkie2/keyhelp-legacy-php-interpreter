# Building the supplement

Applies to supplement 1.1.0 and the build recipes in `build/`. [Deutsche Fassung](../bau.md)

## What is built and why

KeyHelp's PHP 5.6 extensions for Debian 12 are linked against libraries that Debian 13 no longer ships, and intl lacks the search path to the bundled ICU data library. Only these libraries are built, from the same source versions as on the Debian 12 reference server:

| Library | Source | Version | Origin of the source |
|---|---|---|---|
| `libvpx.so.7` | Debian source package libvpx | 1.12.0-1+deb12u5 | deb.debian.org, bookworm-security, via apt (signed Release file) |
| `libtidy.so.5deb1` | tidy-html5 | 2:5.6.0-11 | deb.debian.org, bookworm |
| `libldap-2.5.so.0`, `liblber-2.5.so.0` | openldap | 2.5.13+dfsg-5 | deb.debian.org, bookworm |
| `libMagickCore-6.Q16.so.6`, `libMagickWand-6.Q16.so.6`, modules | imagemagick | 6.9.11-60+dfsg-1.6+deb12u15 | deb.debian.org, bookworm-security |
| ImageMagick configuration | imagemagick-6-common | same version | deb.debian.org, bookworm-security, binary package |
| `libc-client.so.2007e` | uw-imap | 2007f~dfsg-7.1 (Sury's build for Debian 13) | [`fremdquellen/sury/uw-imap/`](../../fremdquellen/sury/uw-imap/HERKUNFT.md) |
| `libssh2-khli.so.1` | libssh2 | 1.10.0-3+deb12u1 | deb.debian.org, bookworm-security |

libssh2 1.10 from Debian 12 gets its own soname `libssh2-khli.so.1` and serves only `ssh2.so`: with Debian 13's libssh2 1.11, `ssh2_auth_pubkey_file()` aborts with ECDSA keys, and libcurl keeps loading Debian 13's libssh2 in the same process.

## Environment

The build runs as root in a Debian 13 (trixie) chroot, so that it links against Debian 13's libraries:

- created with `debootstrap --variant=buildd --include=ca-certificates,gnupg trixie <dir> http://deb.debian.org/debian`; debootstrap verifies authenticity with `debian-archive-keyring`
- additional `deb-src` entries for trixie, bookworm, bookworm-updates and bookworm-security, so that `apt-get source` fetches the Debian 12 sources
- no recommended packages (`APT::Install-Recommends "false"`) and a `policy-rc.d` that starts no services (`exit 101`)
- this repository's tree read-only at `/khli/baum`, a writable directory `/khli/aus` for the results
- for step 3 a second chroot with Debian 12 (bookworm)

The recipes expect exactly these paths. For the official supplement they ran this way on a test server, with a separate mount and PID namespace per run (`unshare --mount --pid --fork`).

## Steps

1. In the Debian 13 chroot, one after another:
   - `bash /khli/baum/build/bibliotheken/bau-debianquelle.sh libvpx 1.12.0-1+deb12u5`
   - `bash /khli/baum/build/bibliotheken/bau-debianquelle.sh tidy-html5 2:5.6.0-11`
   - `bash /khli/baum/build/bibliotheken/bau-debianquelle.sh libssh2 1.10.0-3+deb12u1`
   - `bash /khli/baum/build/bibliotheken/bau-uwimap.sh`
   - `bash /khli/baum/build/bibliotheken/bau-openldap-bibliotheken.sh`
   - `bash /khli/baum/build/bibliotheken/bau-imagemagick6.sh`
2. The results are in `/khli/aus/ergebnis/<source>/` with `SHA256SUMS`, `copyright` and `changelog`.
3. Fetch `imagemagick-6-common` at the same version with `apt-get download` in the Debian 12 chroot and put it into `/khli/aus/ergebnis/imagemagick-6-common/` of the Debian 13 chroot.
4. Assembly: `bash /khli/baum/build/zusammenbau/ergaenzung-bauen.sh <version>` produces `/khli/aus/ergaenzung/khli-php56-ergaenzung-<version>-debian13-amd64.tar.xz` with `MANIFEST.sha256`, `HERKUNFT.tsv` (all source files with SHA-256), `BAU` (compiler, date), `needed.tsv` and `laufzeit-pakete.txt` (Debian 13 packages the libraries need).
5. Enter the SHA-256 of the new supplement in the installer (`ERGAENZUNG_SHA256`, `ERGAENZUNG_VERSION`), new version number, CHANGELOG.
6. Test: installation, update and removal in a minimal Debian 13 chroot and on a test server, functional comparison with KeyHelp's 5.6 on Debian 12, then `tests/ende-zu-ende.sh`. The functional and installer tests so far run in the internal project environment; they will be moved into this repository step by step.

Build times on a test server with 2 CPUs: libvpx, tidy and c-client a few minutes each, OpenLDAP under 5 minutes, ImageMagick about 5 minutes.

## Differences from the Debian 12 build

- GCC 14 instead of GCC 12. The error classes that GCC 14 and dpkg-buildflags newly treat as errors in Debian 13 (implicit-int, int-conversion, incompatible-pointer-types, return-mismatch) are downgraded to warnings where needed, so that the same source code results in the same program.
- Linked against Debian 13's libraries (for example libwebp 1.5, libtiff 4.7, OpenEXR 3.1, GnuTLS 3.8), not against Debian 12's. This is intended: no second, unmaintained copy of these libraries.
- ImageMagick with the private prefix `/opt/keyhelp/php/5.6/lib/khli` instead of `/usr`, without Magick++ and PerlMagick, Q16 only, without HDRI.
- OpenLDAP only `libraries/`; the full package build fails at a slapd module PHP does not use.

## When to rebuild

| Occasion | What to do |
|---|---|
| Debian publishes a new security level of one of the sources for Debian 12 (LTS until mid 2028) | build with the new version, new supplement, new installer version, new release |
| KeyHelp publishes a new 5.6 build for Debian 12 | adjust checksum and build in the installer, repeat the tests; the private libraries stay as long as the extensions need the same sonames |
| Debian 13 updates a system library | nothing; the private libraries use the system libraries via their sonames |
| Debian 14 | new comparison; the fallback is an own build of PHP 5.6 |

## Note on the build recipes

The files in `build/` are unchanged the versions with which supplement 1.1.0 was built. Their comments refer to the internal project documentation (abbreviations such as `E-0040` or `docs/45`), which is not published; "PROD" there stands for the Debian 12 reference server.
