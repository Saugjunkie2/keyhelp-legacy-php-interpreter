#!/bin/bash
# ergaenzung-bauen.sh - Version 1.2 (2026-11-26)
# 1.2: der Zeitpunkt in BAU folgt SOURCE_DATE_EPOCH, wenn gesetzt, damit zwei Bauten mit denselben
#      Eingaben vergleichbar sind; ein vorhandenes Ergebnis ohne Datei QUELLE (aus den Bauanleitungen vor
#      1.2) wird genannt (Drittprüfung F-010, F-018)
# 1.1: libssh2 1.10.0-3+deb12u1 aus Debian 12 (build/bibliotheken/bau-debianquelle.sh) unter dem
#      eigenen soname libssh2-khli.so.1: mit libssh2 1.11 aus Debian 13 bricht ssh2_auth_pubkey_file()
#      bei ECDSA-Schlüsseln mit "free(): invalid pointer" ab; libcurl lädt im selben PHP-Prozess das
#      libssh2 von Debian 13 unter dem soname libssh2.so.1, deshalb ein eigener Name (E-0049)
# Setzt den Ergänzungssatz für PHP 5.6 unter Debian 13 zusammen: die privat gebauten Bibliotheken,
# die Debian 13 nicht mehr liefert (docs/45, H1), für den Ordner <interpreter>/lib/khli.
# Enthält keine KeyHelp-Dateien; die kommen beim Installieren aus KeyHelps Originalquelle (E-0017).
# Läuft IN der Debian-13-Chroot als root, über scripts/lab/khli-im-chroot.sh, nach den Bauten aus
# build/bibliotheken/ (Ergebnisse unter /khli/aus/ergebnis/) und nach dem Holen von
# imagemagick-6-common aus Debian 12 (/khli/aus/ergebnis/imagemagick-6-common/*.deb):
#   bash /khli/baum/build/zusammenbau/ergaenzung-bauen.sh <version>
# Ergebnis: /khli/aus/ergaenzung/khli-php56-ergaenzung-<version>-debian13-amd64.tar.xz und .sha256
# Inhalt des Archivs (Pfade relativ zum Interpreterordner):
#   lib/khli/lib/               libvpx.so.7, libtidy.so.5deb1, libc-client.so.2007e, libldap-2.5.so.0,
#                               liblber-2.5.so.0, libMagickCore-6.Q16.so.6, libMagickWand-6.Q16.so.6,
#                               libssh2-khli.so.1 (ab 1.1.0)
#   lib/khli/lib/ImageMagick-6.9.11/   Module (coders, filters) und configure.xml
#   lib/khli/etc/ImageMagick-6/        Konfiguration aus Debian 12 (imagemagick-6-common, gleicher Stand)
#   lib/khli/share/ImageMagick-6/      Meldungstexte aus Debian 12
#   lib/khli/share/doc/<quelle>/       copyright und changelog jeder Quelle
#   lib/khli/khli/                     MANIFEST.sha256, HERKUNFT.tsv, laufzeit-pakete.txt, needed.tsv
set -euo pipefail
exec </dev/null
export LC_ALL=C.UTF-8 DEBIAN_FRONTEND=noninteractive
version=${1:?Version, zum Beispiel 1.0.0}
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Version a.b.c" >&2; exit 2; }
E=/khli/aus/ergebnis
for q in libvpx tidy-html5 uw-imap openldap imagemagick6 imagemagick-6-common libssh2; do
  [ -d "$E/$q" ] || { echo "fehlt: $E/$q" >&2; exit 2; }
done
(cd "$E/imagemagick6" && sha256sum -c --quiet SHA256SUMS) || { echo "imagemagick6 weicht ab" >&2; exit 3; }
for q in libvpx tidy-html5 uw-imap openldap libssh2; do (cd "$E/$q" && sha256sum -c --quiet SHA256SUMS) || { echo "$q weicht ab" >&2; exit 3; }; done
for q in libvpx tidy-html5 uw-imap openldap imagemagick6 libssh2; do
  if [ -f "$E/$q/QUELLE" ]; then echo "ergaenzung-bauen: $q aus $(cat "$E/$q/QUELLE")"; else echo "ergaenzung-bauen: Hinweis: $E/$q ohne QUELLE (Bauanleitung vor 1.2); die Fassung steht nur in HERKUNFT.tsv"; fi
done
apt-get install -y -q patchelf binutils > /dev/null
arbeit=/khli/aus/ergaenzung/arbeit
rm -rf "$arbeit"
mkdir -p "$arbeit/deb"
S=$arbeit/stage/lib/khli
mkdir -p "$S/lib" "$S/etc" "$S/share/doc" "$S/khli"
auspacken() { mkdir -p "$arbeit/deb/$1"; dpkg-deb -x "$2" "$arbeit/deb/$1"; }
auspacken libvpx "$(ls "$E"/libvpx/libvpx7_*.deb)"
auspacken tidy "$(ls "$E"/tidy-html5/libtidy5deb1_*.deb)"
auspacken cclient "$(ls "$E"/uw-imap/libc-client2007e_*.deb)"
auspacken imcommon "$(ls "$E"/imagemagick-6-common/imagemagick-6-common_*.deb)"
cp -a "$arbeit"/deb/libvpx/usr/lib/x86_64-linux-gnu/libvpx.so.7* "$S/lib/"
cp -a "$arbeit"/deb/tidy/usr/lib/x86_64-linux-gnu/libtidy.so.5deb1* "$S/lib/"
cp -a "$arbeit"/deb/cclient/usr/lib/libc-client.so.2007e* "$S/lib/"
# libssh2 aus Debian 12 unter eigenem soname; nur ssh2.so nutzt es (der Installer ändert dort NEEDED)
auspacken libssh2 "$(ls "$E"/libssh2/libssh2-1_*.deb)"
cp "$(readlink -f "$arbeit"/deb/libssh2/usr/lib/x86_64-linux-gnu/libssh2.so.1)" "$S/lib/libssh2-khli.so.1"
patchelf --set-soname libssh2-khli.so.1 "$S/lib/libssh2-khli.so.1"
# OpenLDAP: nur die Bibliotheken gebaut (build/bibliotheken/bau-openldap-bibliotheken.sh), kein .deb
cp -a "$E"/openldap/stage/usr/lib/x86_64-linux-gnu/libldap-2.5.so.0* "$E"/openldap/stage/usr/lib/x86_64-linux-gnu/liblber-2.5.so.0* "$S/lib/"
IM=$E/imagemagick6/stage/opt/keyhelp/php/5.6/lib/khli
cp -a "$IM"/lib/libMagickCore-6.Q16.so.6* "$IM"/lib/libMagickWand-6.Q16.so.6* "$S/lib/"
cp -a "$IM/lib/ImageMagick-6.9.11" "$S/lib/"
# Konfiguration und Meldungstexte wie unter Debian 12 (gleicher Paketstand wie auf PROD)
cp -a "$arbeit/deb/imcommon/etc/ImageMagick-6" "$S/etc/"
mkdir -p "$S/share"
cp -a "$arbeit/deb/imcommon/usr/share/ImageMagick-6" "$S/share/"
# Was der eigene Bau zusätzlich als Konfiguration installiert hätte, nur zum Vergleich ablegen
diff -r "$IM/etc/ImageMagick-6" "$S/etc/ImageMagick-6" > "$S/khli/imagemagick-konfiguration-gegen-eigenbau.diff" || true
for q in libvpx tidy-html5 uw-imap openldap imagemagick6 libssh2; do
  mkdir -p "$S/share/doc/$q"
  cp "$E/$q/copyright" "$S/share/doc/$q/copyright"
  gzip -9n < "$E/$q/changelog" > "$S/share/doc/$q/changelog.gz"
done
cp "$E/imagemagick6/LICENSE" "$S/share/doc/imagemagick6/LICENSE"
# RUNPATH: jede private Bibliothek sucht ihre privaten Nachbarn im eigenen Ordner
for f in "$S"/lib/*.so.*; do
  [ -L "$f" ] && continue
  rp=$(readelf -dW "$f" | sed -n 's/.*(RUNPATH).*\[\(.*\)\]/\1/p')
  case "$rp" in
    '') patchelf --set-rpath '$ORIGIN' "$f" ;;
    /opt/keyhelp/php/5.6/lib/khli/lib) patchelf --set-rpath '$ORIGIN' "$f" ;;
  esac
done
# Module von ImageMagick: libtool hat den absoluten Pfad gesetzt; auf $ORIGIN umstellen
find "$S/lib/ImageMagick-6.9.11" -name '*.so' -type f | while read -r f; do
  patchelf --set-rpath '$ORIGIN/../../..' "$f"
done
# Abhängigkeiten außerhalb des Satzes: soname -> Debian-13-Paket
: > "$S/khli/needed.tsv"
find "$S/lib" -type f -name '*.so*' | sort | while read -r f; do
  for n in $(readelf -dW "$f" | sed -n 's/.*(NEEDED).*\[\(.*\)\]/\1/p'); do
    printf '%s\t%s\n' "${f#"$S"/}" "$n" >> "$S/khli/needed.tsv"
  done
done
privat=$(cd "$S/lib" && ls)
cut -f2 "$S/khli/needed.tsv" | sort -u | while read -r n; do
  if printf '%s\n' "$privat" | grep -qx "$n"; then continue; fi
  p=$(dpkg -S "*/$n" 2>/dev/null | grep -v -- '-dev' | head -1 | cut -d: -f1)
  printf '%s\t%s\n' "$n" "${p:-UNBEKANNT}"
done | sort -u > "$S/khli/soname-pakete.tsv"
cut -f2 "$S/khli/soname-pakete.tsv" | sort -u > "$S/khli/laufzeit-pakete.txt"
if grep -q UNBEKANNT "$S/khli/soname-pakete.tsv"; then echo "nicht zuordenbar:" >&2; grep UNBEKANNT "$S/khli/soname-pakete.tsv" >&2; exit 1; fi
# Herkunft
{
  printf 'quelle\tversion\tdatei\tsha256\n'
  for q in libvpx tidy-html5 uw-imap openldap imagemagick6 libssh2; do
    v=$(dpkg-parsechangelog -l "$E/$q/changelog" -S Version)
    while read -r h d; do printf '%s\t%s\t%s\t%s\n' "$q" "$v" "$(basename "$d")" "$h"; done < "$E/$q/quellen.sha256"
  done
  d=$(ls "$E"/imagemagick-6-common/imagemagick-6-common_*.deb)
  printf 'imagemagick-6-common\t%s\t%s\t%s\n' "$(dpkg-deb -f "$d" Version)" "$(basename "$d")" "$(sha256sum "$d" | cut -c1-64)"
} > "$S/khli/HERKUNFT.tsv"
{
  echo "ergaenzung=$version"
  echo "gebaut=$(date -u -d "@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y-%m-%dT%H:%M:%SZ)"
  echo "system=Debian $(cat /etc/debian_version)"
  echo "compiler=$(gcc --version | head -1)"
} > "$S/khli/BAU"
(cd "$arbeit/stage" && find lib -type f ! -name MANIFEST.sha256 -print0 | sort -z | xargs -0 sha256sum > lib/khli/khli/MANIFEST.sha256)
name=khli-php56-ergaenzung-$version-debian13-amd64
mkdir -p /khli/aus/ergaenzung
tar --sort=name --owner=0 --group=0 --numeric-owner --mtime='2026-11-19 00:00:00Z' -C "$arbeit/stage" -cJf "/khli/aus/ergaenzung/$name.tar.xz" lib
(cd /khli/aus/ergaenzung && sha256sum "$name.tar.xz" > "$name.tar.xz.sha256")
cat "/khli/aus/ergaenzung/$name.tar.xz.sha256"
du -sh "$S"
echo "Laufzeitpakete: $(tr '\n' ' ' < "$S/khli/laufzeit-pakete.txt")"
