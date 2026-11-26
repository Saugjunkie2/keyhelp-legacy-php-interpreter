# Licenses and redistribution

[Deutsche Fassung](../lizenzen.md). Not legal advice; the classification follows the license texts in the source packages.

## Principle

This project does not redistribute any KeyHelp files. On the user's server, the installer downloads KeyHelp's package `php_5.6.40_20261103164601.tar.gz` from KeyHelp's official source `repo.keyhelp.de` and verifies its SHA-256. Only the project's own scripts and documents, the uw-imap source package for the build and the supplement with freely licensed libraries are redistributed.

## Components

| Component | Origin | License | redistributed |
|---|---|---|---|
| scripts, tests and documents of this project | Retrowork | Apache License 2.0 ([LICENSE](../../LICENSE)) | yes, in the repository and the releases |
| KeyHelp's PHP 5.6 package (PHP, PEAR, Composer, bundled ICU, extensions) | repo.keyhelp.de | PHP License 3.01, Unicode license and others | no, downloaded on the user's server |
| ionCube and SourceGuardian loaders | placed on the server by KeyHelp | proprietary | no, untouched |
| libvpx 1.12.0 | Debian source package | BSD-3-Clause with a patent license by Google | yes, in the supplement |
| tidy-html5 5.6.0 | Debian source package | HTML Tidy license (W3C-like, free) | yes, in the supplement |
| OpenLDAP 2.5.13 (libldap, liblber) | Debian source package | OpenLDAP Public License 2.8 | yes, in the supplement |
| ImageMagick 6.9.11-60 | Debian source package, configuration from `imagemagick-6-common` | ImageMagick License (modelled on Apache 2.0) | yes, in the supplement |
| UW IMAP c-client 2007f | Sury's source package for Debian 13 | Apache-2.0; Debian packaging GPL-2+ | yes, in the supplement; the source package in `fremdquellen/` |
| libssh2 1.10.0 (as `libssh2-khli.so.1`) | Debian source package 1.10.0-3+deb12u1 | BSD-3-Clause | yes, in the supplement |
| Debian's patches and packaging of these sources | Debian, Sury | as in the respective `copyright` files | as part of the built libraries |
| Sury's key, signed `InRelease` and `Sources.xz` | deb.sury.org | public repository metadata without a license statement of their own | yes, unchanged in `fremdquellen/sury/echtheit/` as evidence of authenticity |

The supplement contains `copyright` and `changelog.gz` per source under `lib/khli/share/doc/<source>/`, ImageMagick's `LICENSE` and `HERKUNFT.tsv` with the SHA-256 of all source files. The build recipes in `build/` and [building.md](building.md) show how it is produced.

Source code: of the built sources, only Debian's packaging of uw-imap is under a copyleft license (GPL-2+, according to `copyright` in the supplement; the others use ImageMagick, BSD, OpenLDAP and Tidy licenses). Its complete source package is therefore kept in this repository in [`fremdquellen/sury/uw-imap/`](../../fremdquellen/sury/uw-imap/HERKUNFT.md), at the same place as the releases. `HERKUNFT.tsv` lists the other source packages with version and SHA-256; they are available from the Debian archive (`snapshot.debian.org`).

## Names

The Apache License 2.0 grants no rights to names and trademarks (section 6). Modified versions must not present themselves as a Retrowork release; only what is signed with Retrowork's key is official ([signing.md](signing.md)). KeyHelp is a trademark of Keyweb AG, PHP a trademark of The PHP Group; this project is published by neither of them.
