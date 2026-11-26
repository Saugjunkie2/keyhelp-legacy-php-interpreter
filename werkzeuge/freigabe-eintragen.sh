#!/bin/bash
# freigabe-eintragen.sh - Version 1.0.0
# Führt die Freigabeliste für den zweiten Kanal: trägt ein signiertes Release als gültig ein oder
# widerruft es, und signiert die Liste neu. install.sh lädt die Liste vor jeder Installation und
# lehnt ein widerrufenes Release ab (docs/signatur.md).
# Format von freigaben.txt (ASCII, eine Zeile je Release, # für Kommentare):
#   <version> <sha256 von SHA256SUMS> <gueltig|widerrufen> <datum> [grund]
#
# Aufruf, unter Linux oder in Git Bash unter Windows:
#   bash werkzeuge/freigabe-eintragen.sh <freigaben.txt> <release-ordner> <privater-schluessel> [widerrufen <grund>]
# Ergebnis: freigaben.txt und freigaben.txt.sig im selben Ordner; beide kommen danach zusammen mit
# schluessel/release-ed25519.pub auf den zweiten Kanal.
# Exit: 0 eingetragen und geprüft, 2 falscher Aufruf, 3 Signatur oder Release falsch, 4 Voraussetzung fehlt
set -euo pipefail
export LC_ALL=C.UTF-8
WERKZEUG=freigabe-eintragen
hier=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=werkzeuge/gemeinsam.sh
. "$hier/gemeinsam.sh"

[ $# -eq 3 ] || [ $# -eq 5 ] || fehler "Aufruf: freigabe-eintragen.sh <freigaben.txt> <release-ordner> <privater-schluessel> [widerrufen <grund>]" 2
liste=$1 dir=$2 key=$3
modus=gueltig grund=""
if [ $# -eq 5 ]; then
  [ "$4" = widerrufen ] || fehler "viertes Argument: widerrufen" 2
  modus=widerrufen
  grund=$5
  muster='^[A-Za-z0-9 .,:;()/+_-]{1,200}$'
  [[ $grund =~ $muster ]] || fehler "Grund nur in ASCII ohne Anführungszeichen, höchstens 200 Zeichen" 2
fi
for f in SHA256SUMS SHA256SUMS.sig install.sh RELEASE; do
  [ -f "$dir/$f" ] || fehler "im Release fehlt $f" 4
done
[ -f "$key" ] || fehler "privater Schlüssel nicht gefunden: $key" 4
command -v openssl > /dev/null || fehler "openssl fehlt" 4

tmp=$(mktemp -d "${TMPDIR:-/tmp}/khli-freigabe.XXXXXX")
trap 'rm -rf -- "$tmp"' EXIT
schluessel_auslesen "$dir/install.sh" > "$tmp/pub.pem"
fingerabdruck=$(schluessel_fingerabdruck "$tmp/pub.pem") || fehler "install.sh im Release enthält keinen Ed25519-Schlüssel" 3
openssl pkeyutl -verify -pubin -inkey "$tmp/pub.pem" -rawin -in "$dir/SHA256SUMS" -sigfile "$dir/SHA256SUMS.sig" > /dev/null 2>&1 \
  || fehler "das Release ist nicht gültig signiert; eingetragen werden nur signierte Releases" 3
version=$(sed -n 's/^VERSION=//p' "$dir/RELEASE")
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fehler "RELEASE nennt keine gültige Version" 3
summe=$(sha256 "$dir/SHA256SUMS")
datum=$(date -u +%Y-%m-%d)

if [ -f "$liste" ]; then
  ohne_cr "$liste"
  cp -- "$liste" "$tmp/neu.txt"
  if [ -f "$liste.sig" ]; then
    openssl pkeyutl -verify -pubin -inkey "$tmp/pub.pem" -rawin -in "$liste" -sigfile "$liste.sig" > /dev/null 2>&1 \
      || fehler "die vorhandene Liste ist nicht mit diesem Schlüssel signiert; bitte prüfen, bevor sie ersetzt wird" 3
  fi
else
  printf '# keyhelp-legacy-php-interpreter: Freigabeliste für install.sh (zweiter Kanal)\n# <version> <sha256 von SHA256SUMS> <gueltig|widerrufen> <datum> [grund]\n' > "$tmp/neu.txt"
fi
vorhanden=$(awk -v s="$summe" '$0 !~ /^#/ && $2 == s' "$tmp/neu.txt" | wc -l)
if [ "$modus" = gueltig ]; then
  [ "$vorhanden" -eq 0 ] || fehler "Release $version mit diesem SHA256SUMS steht schon in der Liste" 2
  printf '%s %s gueltig %s\n' "$version" "$summe" "$datum" >> "$tmp/neu.txt"
else
  [ "$vorhanden" -eq 1 ] || fehler "Release $version mit diesem SHA256SUMS steht nicht in der Liste; widerrufen wird nur ein eingetragenes" 2
  awk -v s="$summe" -v d="$datum" -v g="$grund" \
    '$0 !~ /^#/ && $2 == s {print $1, $2, "widerrufen", d, g; next} {print}' "$tmp/neu.txt" > "$tmp/neu2.txt"
  mv "$tmp/neu2.txt" "$tmp/neu.txt"
fi

passphrase_lesen "Passphrase für $key"
rc=0
printf '%s\n' "$PASSPHRASE" | openssl pkeyutl -sign -inkey "$key" -passin stdin -rawin \
  -in "$tmp/neu.txt" -out "$tmp/neu.txt.sig" || rc=$?
PASSPHRASE=""
[ "$rc" -eq 0 ] || fehler "openssl konnte nicht signieren (Passphrase falsch?)" 3
openssl pkeyutl -verify -pubin -inkey "$tmp/pub.pem" -rawin -in "$tmp/neu.txt" -sigfile "$tmp/neu.txt.sig" > /dev/null 2>&1 \
  || fehler "die Signatur passt nicht zum Schlüssel des Releases (falscher privater Schlüssel?); nichts geschrieben" 3
cp -- "$tmp/neu.txt" "$liste"
cp -- "$tmp/neu.txt.sig" "$liste.sig"
meldung "Release $version als $modus eingetragen, Liste signiert (Schlüssel SHA256:$fingerabdruck): $liste, $liste.sig"
meldung "weiter: beide Dateien und schluessel/release-ed25519.pub auf den zweiten Kanal laden (docs/signatur.md)"
