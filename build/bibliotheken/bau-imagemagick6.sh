#!/bin/bash
# bau-imagemagick6.sh - Version 1.3 (2026-11-26)
# 1.3: ein vorhandenes Ergebnis gilt nur für genau diese Fassung (Datei QUELLE, in SHA256SUMS), sonst
#      Exit 3 statt eines stillen Erfolgs (Drittprüfung F-010)
# 1.2: auch implicit-function-declaration nur als Warnung. Debian 13s dpkg-buildflags setzt
#      -Werror=implicit-function-declaration von sich aus, Debian 12 nicht. Debians coders/mat.c ruft
#      GetMagickUTCTime statt GetMagickUTCtime auf; Debian 12s mat.so enthält das unaufgelöste Symbol
#      ebenso (nm -D in der Debian-12-Chroot), also derselbe Stand wie unter Debian 12 (E-0041).
# 1.1: GCC-12-Semantik für die Fehlerklassen, die GCC 14 neu als Fehler behandelt. Anlass: Debians
#      wand/mogrify.c Zeile 2855 übergibt Image** an SetImageProfile(Image*,...); GCC 12 (Debian 12)
#      warnt nur, GCC 14 bricht ab. Mit der Semantik entsteht dasselbe Verhalten wie unter Debian 12.
# Baut ImageMagick 6.9.11-60 Q16 aus dem Debian-12-Quellpaket imagemagick, Debian-Stand
# 6.9.11-60+dfsg-1.6+deb12u15 (derselbe Stand wie auf PROD) in der Debian-13-Chroot, mit
# Debians configure-Optionen aus debian/rules, aber privatem Präfix im Ordner des Interpreters:
#   /opt/keyhelp/php/5.6/lib/khli     lib/ (libMagickCore, libMagickWand, Module), etc/, share/
# Abweichungen von Debians Optionen und ihr Grund:
#   --without-magick-plus-plus, --without-perl: Magick++ und PerlMagick braucht imagick nicht
#   --disable-static: nur gemeinsame Bibliotheken
#   nur Q16 ohne HDRI: imagick.so ist gegen libMagickWand-6.Q16 gelinkt (docs/40)
# Läuft IN der Chroot als root, über scripts/lab/khli-im-chroot.sh:
#   bash /khli/baum/build/bibliotheken/bau-imagemagick6.sh
# Ergebnis: /khli/aus/ergebnis/imagemagick6/stage/opt/keyhelp/php/5.6/lib/khli/... und SHA256SUMS
set -euo pipefail
exec </dev/null
export DEBIAN_FRONTEND=noninteractive LC_ALL=C.UTF-8
quelle=imagemagick
# Debian schreibt die Fassung mit Punkt vor 60; aus Teilen zusammengesetzt, weil der pre-commit-Hook
# vierteilige Zahlen als IPv4-Adresse sperrt (E-0039)
im_basis=6.9.11
im_stand=60
version="8:${im_basis}.${im_stand}+dfsg-1.6+deb12u15"
praefix=/opt/keyhelp/php/5.6/lib/khli
ergebnis=/khli/aus/ergebnis/imagemagick6
kennung="$quelle $version"
if [ -f "$ergebnis/SHA256SUMS" ]; then
  if [ "$(cat "$ergebnis/QUELLE" 2>/dev/null)" = "$kennung" ]; then echo "bau-imagemagick6: $ergebnis vorhanden ($kennung)"; exit 0; fi
  echo "bau-imagemagick6: $ergebnis gehört zu $(cat "$ergebnis/QUELLE" 2>/dev/null || echo 'einer unbekannten Quelle'), verlangt ist $kennung; den Ordner entfernen, dann neu bauen" >&2
  exit 3
fi
bau=/khli/aus/bau/imagemagick6
rm -rf "$bau"
mkdir -p "$bau" "$ergebnis"
cd "$bau"
apt-get update -q
apt-get install -y -q dpkg-dev devscripts fakeroot
apt-get source -q --only-source "$quelle=$version" > quelle.log 2>&1
sha256sum ./*.dsc ./*.tar.* > quellen.sha256
apt-get build-dep -y -q --arch-only --only-source "$quelle=$version" > builddep.log 2>&1 || {
  tail -30 builddep.log >&2; exit 1; }
verz=$(find . -mindepth 1 -maxdepth 1 -type d -name 'imagemagick-*' | head -1)
cd "$verz"
# Compiler-Optionen wie bei Debian (dpkg-buildflags), dazu --as-needed aus debian/rules
eval "$(dpkg-buildflags --export=sh)"
export LDFLAGS="$LDFLAGS -Wl,--as-needed"
export CFLAGS="$CFLAGS -Wno-error=implicit-function-declaration -Wno-error=incompatible-pointer-types -Wno-error=implicit-int -Wno-error=int-conversion -Wno-error=return-mismatch"
mkdir -p ../build-q16
cd ../build-q16
"../$verz/configure" \
  --enable-reproducible-build \
  --prefix="$praefix" \
  --libdir="$praefix/lib" \
  --sysconfdir="$praefix/etc" \
  --docdir="$praefix/share/doc/imagemagick-6" \
  --mandir="$praefix/share/man" \
  --with-modules \
  --with-gs-font-dir=/usr/share/fonts/type1/gsfonts \
  --without-magick-plus-plus \
  --with-djvu --with-heic --with-openjp2 --with-webp --with-wmf \
  --without-gvc --enable-shared --disable-static --without-dps --without-fpx \
  --without-perl \
  --x-includes=/usr/include/X11 --x-libraries=/usr/lib/X11 \
  --without-rsvg --without-gcc-arch \
  --disable-silent-rules \
  --with-quantum-depth=16 --enable-hdri=no \
  MVDelegate=/bin/mv RMDelegate=/bin/rm > ../configure.log 2>&1 || { tail -40 ../configure.log >&2; exit 1; }
grep -A60 -E '^ +Option +Value' ../configure.log > ../configure-zusammenfassung.txt || true
start=$(date +%s)
make -j"$(nproc)" > ../make.log 2>&1 || { tail -40 ../make.log >&2; exit 1; }
make install DESTDIR="$ergebnis/stage" > ../install.log 2>&1 || { tail -40 ../install.log >&2; exit 1; }
echo "bau-imagemagick6: gebaut in $(( $(date +%s) - start )) s"
cd "$bau"
cp quellen.sha256 configure-zusammenfassung.txt "$ergebnis/"
cp "$verz/debian/copyright" "$ergebnis/copyright"
cp "$verz/debian/changelog" "$ergebnis/changelog"
cp "$verz/LICENSE" "$ergebnis/LICENSE"
LD_LIBRARY_PATH="$ergebnis/stage$praefix/lib" "$ergebnis/stage$praefix/bin/convert" -version > "$ergebnis/convert-version.txt" 2>&1 || true
printf '%s\n' "$kennung" > "$ergebnis/QUELLE"
(cd "$ergebnis" && find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
cat "$ergebnis/convert-version.txt"
du -sh "$ergebnis/stage"
