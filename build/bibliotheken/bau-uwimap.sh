#!/bin/bash
# bau-uwimap.sh - Version 1.1 (2026-11-26)
# 1.1: ein vorhandenes Ergebnis gilt nur für genau dieses Quellpaket (Datei QUELLE, in SHA256SUMS), sonst
#      Exit 3 statt eines stillen Erfolgs (Drittprüfung F-010); Verweis auf die öffentliche Echtheitsprüfung
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
kennung="uw-imap $(basename "$dsc" .dsc)"
if [ -f "$ergebnis/SHA256SUMS" ]; then
  if [ "$(cat "$ergebnis/QUELLE" 2>/dev/null)" = "$kennung" ]; then echo "bau-uwimap: $ergebnis vorhanden ($kennung)"; exit 0; fi
  echo "bau-uwimap: $ergebnis gehört zu $(cat "$ergebnis/QUELLE" 2>/dev/null || echo 'einer unbekannten Quelle'), verlangt ist $kennung; den Ordner entfernen, dann neu bauen" >&2
  exit 3
fi
bau=/khli/aus/bau/uw-imap
rm -rf "$bau"
mkdir -p "$bau" "$ergebnis"
cd "$bau"
apt-get update -q
apt-get install -y -q dpkg-dev devscripts fakeroot
# dpkg-source prüft die Prüfsummen der Dateien gegen die .dsc; die Signatur der .dsc ist über
# Surys InRelease und Sources-Index belegt: werkzeuge/sury-echtheit-pruefen.sh im öffentlichen Repository,
# mit den Nachweisen unter fremdquellen/sury/echtheit/ (bis 1.0 stand hier ein falscher Skriptname).
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
printf '%s\n' "$kennung" > "$ergebnis/QUELLE"
(cd "$ergebnis" && sha256sum ./*.deb ./*.buildinfo ./*.changes quellen.sha256 copyright changelog QUELLE > SHA256SUMS)
ls -la "$ergebnis"
