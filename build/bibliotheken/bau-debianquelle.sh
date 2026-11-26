#!/bin/bash
# bau-debianquelle.sh - Version 1.1 ENTWURF (Lauf P2, 2026-11-19)
# 1.1: Schalter --gcc12-semantik. GCC 14 (Debian 13) behandelt implicit-int, int-conversion,
#      incompatible-pointer-types und return-mismatch als Fehler, GCC 12 (Debian 12) als Warnung.
#      Mit dem Schalter übersetzt der Bau den unveränderten Debian-12-Quelltext wie unter Debian 12
#      (DEB_CFLAGS_APPEND, von dpkg-buildflags ausgewertet). Anlass: OpenLDAP 2.5.13, configure-Test
#      "broken POSIX regex" scheitert an "return type defaults to int".
# Baut ein Debian-12-Quellpaket unverändert in der Debian-13-Chroot (E-0038) mit
# dpkg-buildpackage, für die Bibliotheken, die Debian 13 nicht mehr liefert (docs/45, H1).
# Läuft IN der Chroot als root, aufgerufen über scripts/lab/khli-im-chroot.sh:
#   bash /khli/baum/build/bibliotheken/bau-debianquelle.sh <quellpaket> <version> [--gcc12-semantik]
# Herkunft: apt-get source aus deb.debian.org (bookworm, bookworm-updates, bookworm-security);
# apt prüft die Signatur der Release-Datei und die Prüfsummen der Quelldateien.
# Ergebnis: /khli/aus/bau/<quellpaket>/ mit Quellen, Bauprotokoll und .deb-Dateien,
#           /khli/aus/ergebnis/<quellpaket>/ mit .deb, .buildinfo, .changes und SHA256SUMS.
# Exit 0 bei Erfolg; ein vorhandenes Ergebnis wird nicht neu gebaut (Exit 0 mit Hinweis).
set -euo pipefail
exec </dev/null
quelle=${1:?Quellpaket}
version=${2:?Version}
[[ "$quelle" =~ ^[a-z0-9][a-z0-9.+-]+$ ]] || { echo "Quellpaket ungültig" >&2; exit 2; }
[[ "$version" =~ ^[0-9A-Za-z.+:~-]+$ ]] || { echo "Version ungültig" >&2; exit 2; }
export DEBIAN_FRONTEND=noninteractive LC_ALL=C.UTF-8
export DEB_BUILD_OPTIONS="nocheck nodoc noautodbgsym parallel=$(nproc)"
if [ "${3:-}" = "--gcc12-semantik" ]; then
  export DEB_CFLAGS_APPEND="-Wno-error=implicit-int -Wno-error=int-conversion -Wno-error=incompatible-pointer-types -Wno-error=return-mismatch"
  echo "bau-debianquelle: GCC-12-Semantik, DEB_CFLAGS_APPEND=$DEB_CFLAGS_APPEND"
fi
ergebnis=/khli/aus/ergebnis/$quelle
if [ -f "$ergebnis/SHA256SUMS" ]; then
  echo "bau-debianquelle: $ergebnis vorhanden, nichts zu tun"; exit 0
fi
bau=/khli/aus/bau/$quelle
rm -rf "$bau"
mkdir -p "$bau" "$ergebnis"
cd "$bau"
apt-get update -q
apt-get install -y -q dpkg-dev devscripts fakeroot
apt-get source -q --only-source "$quelle=$version" > quelle.log 2>&1
sha256sum ./*.dsc ./*.tar.* > quellen.sha256
apt-get build-dep -y -q --arch-only --only-source "$quelle=$version" > builddep.log 2>&1 || {
  echo "bau-debianquelle: build-dep scheiterte" >&2; tail -30 builddep.log >&2; exit 1; }
verz=$(find . -mindepth 1 -maxdepth 1 -type d | head -1)
cd "$verz"
echo "bau-debianquelle: baue $quelle $version in $bau/$verz mit $(gcc --version | head -1)"
start=$(date +%s)
if ! dpkg-buildpackage -B -uc -us > ../bau.log 2>&1; then
  echo "bau-debianquelle: dpkg-buildpackage scheiterte" >&2; tail -40 ../bau.log >&2; exit 1
fi
echo "bau-debianquelle: gebaut in $(( $(date +%s) - start )) s"
cd "$bau"
cp ./*.deb ./*.buildinfo ./*.changes quellen.sha256 "$ergebnis/"
cp "$verz/debian/copyright" "$ergebnis/copyright"
cp "$verz/debian/changelog" "$ergebnis/changelog"
(cd "$ergebnis" && sha256sum ./*.deb ./*.buildinfo ./*.changes quellen.sha256 copyright changelog > SHA256SUMS)
ls -la "$ergebnis"
