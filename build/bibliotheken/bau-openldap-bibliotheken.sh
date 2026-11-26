#!/bin/bash
# bau-openldap-bibliotheken.sh - Version 1.2 (2026-11-26)
# 1.2: ein vorhandenes Ergebnis gilt nur für genau diese Fassung (Datei QUELLE, in SHA256SUMS), sonst
#      Exit 3 statt eines stillen Erfolgs (Drittprüfung F-010)
# 1.1: Bauordner erkennen (ohne dh-Sequenz konfiguriert Debians Regel im Quellordner), make depend
# Baut libldap-2.5.so.0 und liblber-2.5.so.0 aus dem Debian-12-Quellpaket openldap 2.5.13+dfsg-5
# (derselbe Stand wie auf PROD) in der Debian-13-Chroot. Der vollständige dpkg-buildpackage scheitert
# unter Debian 13 erst am slapd-Zusatzmodul contrib/slapd-modules/smbk5pwd (Heimdal 7.8 in Debian 13
# kennt kadm5_s_init_with_password_ctx nicht mehr); die Bibliotheken berührt das nicht. Deshalb:
#   1. Quellen mit apt-get source (Debian-12-Patches angewandt), Bauabhängigkeiten mit build-dep
#   2. configure genau wie Debians debian/rules (Ziel override_dh_auto_configure, mit dpkg-buildflags)
#   3. nur include/ und libraries/ bauen und installieren, danach strip wie dh_strip
# Compiler-Semantik wie GCC 12 für die Fehlerklassen, die GCC 14 neu als Fehler behandelt (E-0040).
# Läuft IN der Chroot als root, über scripts/lab/khli-im-chroot.sh:
#   bash /khli/baum/build/bibliotheken/bau-openldap-bibliotheken.sh
# Ergebnis: /khli/aus/ergebnis/openldap/stage/usr/lib/x86_64-linux-gnu/lib{ldap,lber}-2.5.so.0*
set -euo pipefail
exec </dev/null
export DEBIAN_FRONTEND=noninteractive LC_ALL=C.UTF-8
export DEB_BUILD_OPTIONS="nocheck nodoc noautodbgsym parallel=$(nproc)"
export DEB_CFLAGS_APPEND="-Wno-error=implicit-int -Wno-error=int-conversion -Wno-error=incompatible-pointer-types -Wno-error=return-mismatch"
quelle=openldap
version=2.5.13+dfsg-5
ergebnis=/khli/aus/ergebnis/openldap
kennung="$quelle $version"
if [ -f "$ergebnis/SHA256SUMS" ]; then
  if [ "$(cat "$ergebnis/QUELLE" 2>/dev/null)" = "$kennung" ]; then echo "bau-openldap-bibliotheken: $ergebnis vorhanden ($kennung)"; exit 0; fi
  echo "bau-openldap-bibliotheken: $ergebnis gehört zu $(cat "$ergebnis/QUELLE" 2>/dev/null || echo 'einer unbekannten Quelle'), verlangt ist $kennung; den Ordner entfernen, dann neu bauen" >&2
  exit 3
fi
bau=/khli/aus/bau/openldap
rm -rf "$bau" "$ergebnis"
mkdir -p "$bau" "$ergebnis"
cd "$bau"
apt-get update -q
apt-get install -y -q dpkg-dev devscripts fakeroot
apt-get source -q --only-source "$quelle=$version" > quelle.log 2>&1
sha256sum ./*.dsc ./*.tar.* > quellen.sha256
apt-get build-dep -y -q --arch-only --only-source "$quelle=$version" > builddep.log 2>&1 || { tail -30 builddep.log >&2; exit 1; }
verz=$(find . -mindepth 1 -maxdepth 1 -type d -name 'openldap-*' | head -1)
cd "$verz"
start=$(date +%s)
debian/rules override_dh_auto_configure > ../configure.log 2>&1 || { tail -30 ../configure.log >&2; exit 1; }
bd=debian/build
[ -f "$bd/config.status" ] || bd=.
grep -E '^ac_cs_config=' "$bd/config.status" > ../configure-aufruf.txt || true
make -C "$bd" depend > ../make.log 2>&1 || { tail -30 ../make.log >&2; exit 1; }
make -C "$bd/include" -j"$(nproc)" >> ../make.log 2>&1 || { tail -30 ../make.log >&2; exit 1; }
make -C "$bd/libraries" -j"$(nproc)" >> ../make.log 2>&1 || { tail -30 ../make.log >&2; exit 1; }
make -C "$bd/libraries" install DESTDIR="$ergebnis/stage" > ../install.log 2>&1 || { tail -30 ../install.log >&2; exit 1; }
echo "bau-openldap-bibliotheken: gebaut in $(( $(date +%s) - start )) s"
find "$ergebnis/stage" -name '*.so.*' -type f -exec strip --remove-section=.comment --remove-section=.note --strip-unneeded {} +
find "$ergebnis/stage" -name '*.la' -delete
cd "$bau"
cp quellen.sha256 configure-aufruf.txt "$ergebnis/"
cp "$verz/debian/copyright" "$ergebnis/copyright"
cp "$verz/debian/changelog" "$ergebnis/changelog"
printf '%s\n' "$kennung" > "$ergebnis/QUELLE"
(cd "$ergebnis" && find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
ls -la "$ergebnis/stage/usr/lib/x86_64-linux-gnu/"
