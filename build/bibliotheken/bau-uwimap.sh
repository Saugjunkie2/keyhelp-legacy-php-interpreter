#!/bin/bash
# bau-uwimap.sh - Version 1.0 ENTWURF (Lauf P2, 2026-11-19)
# Baut c-client (libc-client.so.2007e) aus Surys Quellpaket uw-imap 2007f~dfsg-7.1 für Debian 13
# (fremdquellen/sury/uw-imap/, Echtheit über Surys Signaturkette belegt, docs/35). Gegenüber
# Debians 2007f~dfsg-7, dessen Bibliothek auf PROD läuft (-7+b2), enthält -7.1 nur Baukorrekturen
# (GCC 14, Bauabbruch bei Fehlern, chown-Syntax; Changelog im Quellpaket).
# Läuft IN der Debian-13-Chroot als root, über scripts/lab/khli-im-chroot.sh mit dem Baum, der
# fremdquellen/sury/uw-imap enthält:
#   bash /khli/baum/build/bibliotheken/bau-uwimap.sh
# Ergebnis wie bei bau-debianquelle.sh unter /khli/aus/ergebnis/uw-imap/.
set -euo pipefail
exec </dev/null
export DEBIAN_FRONTEND=noninteractive LC_ALL=C.UTF-8
export DEB_BUILD_OPTIONS="nocheck nodoc noautodbgsym parallel=$(nproc)"
dsc=$(ls /khli/baum/fremdquellen/sury/uw-imap/uw-imap_*.dsc)
ergebnis=/khli/aus/ergebnis/uw-imap
if [ -f "$ergebnis/SHA256SUMS" ]; then echo "bau-uwimap: $ergebnis vorhanden"; exit 0; fi
bau=/khli/aus/bau/uw-imap
rm -rf "$bau"
mkdir -p "$bau" "$ergebnis"
cd "$bau"
apt-get update -q
apt-get install -y -q dpkg-dev devscripts fakeroot
# dpkg-source prüft die Prüfsummen der Dateien gegen die .dsc; die Signatur der .dsc ist über
# Surys InRelease und Sources-Index belegt (scripts/analyse/khli-sury-echtheit-pruefen.sh).
dpkg-source -x "$dsc" uw-imap > quelle.log 2>&1
sha256sum /khli/baum/fremdquellen/sury/uw-imap/uw-imap_* > quellen.sha256
apt-get build-dep -y -q --arch-only ./uw-imap > builddep.log 2>&1 || { tail -30 builddep.log >&2; exit 1; }
cd uw-imap
start=$(date +%s)
if ! dpkg-buildpackage -B -uc -us > ../bau.log 2>&1; then
  echo "bau-uwimap: dpkg-buildpackage scheiterte" >&2; tail -40 ../bau.log >&2; exit 1
fi
echo "bau-uwimap: gebaut in $(( $(date +%s) - start )) s"
cd "$bau"
cp ./*.deb ./*.buildinfo ./*.changes quellen.sha256 "$ergebnis/"
cp uw-imap/debian/copyright "$ergebnis/copyright"
cp uw-imap/debian/changelog "$ergebnis/changelog"
(cd "$ergebnis" && sha256sum ./*.deb ./*.buildinfo ./*.changes quellen.sha256 copyright changelog > SHA256SUMS)
ls -la "$ergebnis"
