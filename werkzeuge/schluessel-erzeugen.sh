#!/bin/bash
# schluessel-erzeugen.sh - Version 1.0.0
# Erzeugt einmalig das Ed25519-Schlüsselpaar für die Signaturen der Releases.
#   privater Schlüssel: mit Passphrase verschlüsselt (AES-256) in einen Ordner außerhalb des
#                       Repositorys, am besten auf einen Datenträger, der sonst offline bleibt
#   öffentlicher Schlüssel: schluessel/release-ed25519.pub in diesem Repository (wird committet)
# Das Skript liest die Passphrase zweimal von der Tastatur (ohne Terminal: zwei Zeilen von stdin)
# und reicht sie über eine Pipe an openssl; es speichert und zeigt sie nicht.
#
# Aufruf, unter Linux oder in Git Bash unter Windows:
#   bash werkzeuge/schluessel-erzeugen.sh [--ersetzen] <ordner-fuer-den-privaten-schluessel>
#   --ersetzen  einen vorhandenen öffentlichen Schlüssel ersetzen (Schlüsselwechsel, siehe docs/signatur.md)
# Exit: 0 erzeugt, 2 falscher Aufruf, 4 Voraussetzung fehlt
set -euo pipefail
export LC_ALL=C.UTF-8
umask 077
WERKZEUG=schluessel-erzeugen
hier=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
wurzel=$(cd "$hier/.." && pwd)
# shellcheck source=werkzeuge/gemeinsam.sh
. "$hier/gemeinsam.sh"

ersetzen=0
if [ "${1:-}" = --ersetzen ]; then ersetzen=1; shift; fi
[ $# -eq 1 ] || fehler "Aufruf: schluessel-erzeugen.sh [--ersetzen] <ordner-fuer-den-privaten-schluessel>" 2
command -v openssl > /dev/null || fehler "openssl fehlt" 4
[ -d "$1" ] || fehler "Ordner nicht gefunden: $1" 4
ordner=$(cd -- "$1" && pwd -P)
repo=$(cd -- "$wurzel" && pwd -P)
case "$ordner/" in
  "$repo"/*) fehler "der private Schlüssel gehört nicht in das Repository; bitte einen Ordner außerhalb wählen" 2 ;;
esac
key=$ordner/khli-release-ed25519.key
pub=$wurzel/schluessel/release-ed25519.pub
[ ! -e "$key" ] || fehler "$key gibt es schon; ein vorhandener Schlüssel wird nie überschrieben" 2
if [ -f "$pub" ] && schluessel_fingerabdruck "$pub" > /dev/null && [ "$ersetzen" = 0 ]; then
  fehler "schluessel/release-ed25519.pub enthält schon einen Schlüssel; ein Wechsel nur mit --ersetzen (docs/signatur.md)" 2
fi

passphrase_lesen "neue Passphrase (mindestens 12 Zeichen)"
pw1=$PASSPHRASE
passphrase_lesen "Passphrase wiederholen"
pw2=$PASSPHRASE
PASSPHRASE=""
[ "$pw1" = "$pw2" ] || fehler "die beiden Eingaben stimmen nicht überein" 2
[ "${#pw1}" -ge 12 ] || fehler "die Passphrase ist kürzer als 12 Zeichen" 2
pw2=""

tmp=$(mktemp -d "${TMPDIR:-/tmp}/khli-schluessel.XXXXXX")
trap 'rm -rf -- "$tmp"' EXIT
printf '%s\n' "$pw1" | openssl genpkey -algorithm ed25519 -aes-256-cbc -pass stdin -out "$key" \
  || fehler "openssl konnte den Schlüssel nicht erzeugen" 4
printf '%s\n' "$pw1" | openssl pkey -in "$key" -passin stdin -pubout -out "$tmp/pub.pem" \
  || fehler "openssl konnte den öffentlichen Schlüssel nicht ableiten" 4
pw1=""
fingerabdruck=$(schluessel_fingerabdruck "$tmp/pub.pem") || fehler "der erzeugte Schlüssel ist kein Ed25519-Schlüssel" 4
tr -d '\r' < "$tmp/pub.pem" > "$pub"
meldung "privater Schlüssel: $key (mit Passphrase verschlüsselt)"
meldung "öffentlicher Schlüssel: $pub"
meldung "Fingerabdruck: SHA256:$fingerabdruck"
meldung "jetzt: den privaten Schlüssel auf einem zweiten Datenträger sichern, die Passphrase getrennt davon aufbewahren, schluessel/release-ed25519.pub committen und den Fingerabdruck auf dem zweiten Kanal veröffentlichen (docs/signatur.md)"
