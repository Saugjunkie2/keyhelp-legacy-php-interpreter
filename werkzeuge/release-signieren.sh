#!/bin/bash
# release-signieren.sh - Version 1.0.0
# Signiert SHA256SUMS eines mit release-bauen.sh gebauten Releases mit dem privaten Ed25519-Schlüssel
# und prüft die Signatur sofort gegen den öffentlichen Schlüssel, der im install.sh des Releases steht.
# Nur der Betreiber hat den privaten Schlüssel. Das Skript liest die Passphrase von der Tastatur
# (ohne Terminal eine Zeile von stdin) und reicht sie über eine Pipe an openssl; es speichert und
# zeigt sie nicht und kopiert den privaten Schlüssel nirgendwohin.
#
# Aufruf, unter Linux oder in Git Bash unter Windows:
#   bash werkzeuge/release-signieren.sh <release-ordner> <privater-schluessel>
# Ergebnis: <release-ordner>/SHA256SUMS.sig (64 Bytes)
# Exit: 0 signiert und geprüft, 2 falscher Aufruf, 3 Signatur passt nicht zum Schlüssel des Releases,
#       4 Voraussetzung fehlt
set -euo pipefail
export LC_ALL=C.UTF-8
WERKZEUG=release-signieren
hier=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=werkzeuge/gemeinsam.sh
. "$hier/gemeinsam.sh"

[ $# -eq 2 ] || fehler "Aufruf: release-signieren.sh <release-ordner> <privater-schluessel>" 2
dir=$1 key=$2
[ -f "$dir/SHA256SUMS" ] && [ -f "$dir/install.sh" ] || fehler "$dir ist kein mit release-bauen.sh gebautes Release" 4
[ ! -e "$dir/SHA256SUMS.sig" ] || fehler "$dir/SHA256SUMS.sig gibt es schon" 2
[ -f "$key" ] || fehler "privater Schlüssel nicht gefunden: $key" 4
command -v openssl > /dev/null || fehler "openssl fehlt" 4

tmp=$(mktemp -d "${TMPDIR:-/tmp}/khli-signieren.XXXXXX")
trap 'rm -rf -- "$tmp"' EXIT
schluessel_auslesen "$dir/install.sh" > "$tmp/pub.pem"
fingerabdruck=$(schluessel_fingerabdruck "$tmp/pub.pem") || fehler "install.sh im Release enthält keinen Ed25519-Schlüssel" 3
meldung "Release $(sed -n 's/^VERSION=//p' "$dir/RELEASE" 2> /dev/null), Schlüssel im Release SHA256:$fingerabdruck"

passphrase_lesen "Passphrase für $key"
rc=0
printf '%s\n' "$PASSPHRASE" | openssl pkeyutl -sign -inkey "$key" -passin stdin -rawin \
  -in "$dir/SHA256SUMS" -out "$tmp/SHA256SUMS.sig" || rc=$?
PASSPHRASE=""
[ "$rc" -eq 0 ] || fehler "openssl konnte nicht signieren (Passphrase falsch?)" 3
[ "$(stat -c %s -- "$tmp/SHA256SUMS.sig")" -eq 64 ] || fehler "die Signatur hat nicht 64 Bytes; ist der Schlüssel ein Ed25519-Schlüssel?" 3
openssl pkeyutl -verify -pubin -inkey "$tmp/pub.pem" -rawin -in "$dir/SHA256SUMS" \
  -sigfile "$tmp/SHA256SUMS.sig" > /dev/null 2>&1 \
  || fehler "die Signatur passt nicht zum Schlüssel im install.sh des Releases (falscher privater Schlüssel?); nichts geschrieben" 3
cp -- "$tmp/SHA256SUMS.sig" "$dir/SHA256SUMS.sig"
meldung "signiert und geprüft: $dir/SHA256SUMS.sig"
meldung "weiter: bash werkzeuge/release-pruefen.sh $dir"
