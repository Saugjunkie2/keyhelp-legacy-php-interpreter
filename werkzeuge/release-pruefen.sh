#!/bin/bash
# release-pruefen.sh - Version 1.0.0
# Prüft ein signiertes Release unabhängig von seinem install.sh und vergleicht es mit diesem
# Repository. Jeder kann es ausführen; einen privaten Schlüssel braucht es nicht.
#   1. Signatur von SHA256SUMS mit dem angegebenen öffentlichen Schlüssel (openssl direkt)
#   2. jede Datei gegen SHA256SUMS, keine Datei zu viel oder zu wenig
#   3. install.sh im Release ist install.sh aus diesem Repository mit eingesetztem Schlüssel
#   4. khli-php56.sh im Release ist installer/khli-php56.sh aus diesem Repository
#   5. RELEASE passt zum Installer, der Ergänzungssatz hat den SHA-256, den der Installer erwartet
#   6. das install.sh des Releases selbst prüft es ebenso (--nur-pruefen)
#
# Aufruf: bash werkzeuge/release-pruefen.sh <release-ordner> [<oeffentlicher-schluessel>]
#   Vorgabe für den Schlüssel: schluessel/release-ed25519.pub
# Exit: 0 in Ordnung, 2 falscher Aufruf, 3 Abweichung, 4 Voraussetzung fehlt
set -euo pipefail
export LC_ALL=C.UTF-8
WERKZEUG=release-pruefen
hier=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
wurzel=$(cd "$hier/.." && pwd)
# shellcheck source=werkzeuge/gemeinsam.sh
. "$hier/gemeinsam.sh"

[ $# -ge 1 ] && [ $# -le 2 ] || fehler "Aufruf: release-pruefen.sh <release-ordner> [<oeffentlicher-schluessel>]" 2
dir=$(cd -- "$1" && pwd) || fehler "Ordner nicht gefunden: $1" 4
pub=${2:-$wurzel/schluessel/release-ed25519.pub}
for w in openssl sha256sum awk sed cmp; do command -v "$w" > /dev/null || fehler "$w fehlt" 4; done
fingerabdruck=$(schluessel_fingerabdruck "$pub") || fehler "$pub enthält keinen Ed25519-Schlüssel" 4

for f in SHA256SUMS SHA256SUMS.sig RELEASE install.sh khli-php56.sh; do
  [ -f "$dir/$f" ] || fehler "im Release fehlt $f" 3
done
openssl pkeyutl -verify -pubin -inkey "$pub" -rawin -in "$dir/SHA256SUMS" -sigfile "$dir/SHA256SUMS.sig" > /dev/null 2>&1 \
  || fehler "die Signatur von SHA256SUMS passt nicht zu SHA256:$fingerabdruck" 3
meldung "Signatur gültig, Schlüssel SHA256:$fingerabdruck"

muster='^[0-9a-f]{64}  ([A-Za-z0-9][A-Za-z0-9._+-]{0,127})$'
gelistet=""
n=0
while IFS= read -r zeile || [ -n "$zeile" ]; do
  n=$((n + 1))
  [[ $zeile =~ $muster ]] || fehler "SHA256SUMS: Zeile $n hat nicht die Form <sha256>  <datei>" 3
  name=${BASH_REMATCH[1]}
  [ -f "$dir/$name" ] || fehler "SHA256SUMS nennt $name, die Datei fehlt" 3
  [ "$(sha256 "$dir/$name")" = "${zeile:0:64}" ] || fehler "SHA-256 von $name weicht von SHA256SUMS ab" 3
  gelistet="$gelistet $name"
done < "$dir/SHA256SUMS"
for f in "$dir"/*; do
  name=$(basename -- "$f")
  case "$name" in SHA256SUMS|SHA256SUMS.sig) continue ;; esac
  case " $gelistet " in *" $name "*) ;; *) fehler "$name liegt im Release, steht aber nicht in SHA256SUMS" 3 ;; esac
done
meldung "$n Dateien stimmen mit SHA256SUMS überein"

tmp=$(mktemp -d "${TMPDIR:-/tmp}/khli-pruefen.XXXXXX")
trap 'rm -rf -- "$tmp"' EXIT
schluessel_einsetzen "$wurzel/install.sh" "$pub" > "$tmp/install.sh" || fehler "install.sh in diesem Repository hat keinen leeren Platzhalter" 3
cmp -s "$tmp/install.sh" "$dir/install.sh" || fehler "install.sh im Release ist nicht install.sh aus diesem Repository mit diesem Schlüssel" 3
cmp -s "$wurzel/installer/khli-php56.sh" "$dir/khli-php56.sh" || fehler "khli-php56.sh im Release ist nicht installer/khli-php56.sh aus diesem Repository" 3
meldung "install.sh und khli-php56.sh entsprechen diesem Repository"

rel() { sed -n "s/^$1=//p" "$dir/RELEASE"; }
version=$(sed -n 's/^KHLI_VERSION=\([0-9.]*\)$/\1/p' "$dir/khli-php56.sh")
erg_version=$(sed -n 's/^ERGAENZUNG_VERSION=\([0-9.]*\)$/\1/p' "$dir/khli-php56.sh")
erg_soll=$(sed -n 's/^ERGAENZUNG_SHA256=\([0-9a-f]*\)$/\1/p' "$dir/khli-php56.sh")
[ "$(rel PRODUKT)" = keyhelp-legacy-php-interpreter ] || fehler "RELEASE: PRODUKT falsch" 3
[ "$(rel SYSTEM)" = debian13-amd64 ] || fehler "RELEASE: SYSTEM falsch" 3
[ "$(rel VERSION)" = "$version" ] || fehler "RELEASE nennt Version $(rel VERSION), der Installer hat $version" 3
[ "$(rel INSTALLER)" = khli-php56.sh ] || fehler "RELEASE: INSTALLER falsch" 3
erg=$(rel ERGAENZUNG)
[ "$erg" = "khli-php56-ergaenzung-$erg_version-debian13-amd64.tar.xz" ] || fehler "RELEASE nennt den Ergänzungssatz $erg, der Installer erwartet Version $erg_version" 3
[ -f "$dir/$erg" ] || fehler "der Ergänzungssatz $erg fehlt" 3
[ "$(sha256 "$dir/$erg")" = "$erg_soll" ] || fehler "der Ergänzungssatz hat nicht den SHA-256, den der Installer erwartet" 3
meldung "RELEASE passt zum Installer $version und zum Ergänzungssatz $erg_version"

bash "$dir/install.sh" --quelle "$dir" --nur-pruefen --ohne-zweiten-kanal > "$tmp/install.txt" 2>&1 \
  || { cat "$tmp/install.txt" >&2; fehler "install.sh des Releases lehnt das Release ab" 3; }
meldung "install.sh des Releases bestätigt die Prüfung"
meldung "Release $version in Ordnung; SHA-256 von SHA256SUMS: $(sha256 "$dir/SHA256SUMS")"
