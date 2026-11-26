#!/bin/bash
# veroeffentlichung-pruefen.sh - Version 1.0.0
# Prüft das veröffentlichte Release auf GitHub so, wie es ein vorsichtiger Nutzer vor dem Start tun kann
# (Drittprüfung vom 26.11.2026, F-001, F-020): lädt SHA256SUMS, SHA256SUMS.sig und install.sh des
# Releases, prüft die Signatur mit schluessel/release-ed25519.pub aus diesem Repository (nicht mit dem
# Schlüssel im geladenen Skript), install.sh gegen SHA256SUMS und den darin eingesetzten Schlüssel gegen
# den des Repositorys; erst dann startet es dieses install.sh mit --nur-pruefen und dem echten zweiten
# Kanal. Erwartet: Exit 0, gültige Signatur, "als gültig geführt", und eine Freigabeliste, die noch
# mindestens 30 Tage gilt (sonst Exit 1 als Erinnerung zum Erneuern). Braucht Netz, kein root.
# Aufruf: bash tests/veroeffentlichung-pruefen.sh [--version <v>]
# Exit: 0 in Ordnung, 1 Abweichung, 2 falscher Aufruf, 4 Voraussetzung fehlt
set -uo pipefail
export LC_ALL=C.UTF-8
hier=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
wurzel=$(cd "$hier/.." && pwd)
WERKZEUG=veroeffentlichung-pruefen
# shellcheck source=werkzeuge/gemeinsam.sh
. "$wurzel/werkzeuge/gemeinsam.sh"
RELEASES=https://github.com/Saugjunkie2/keyhelp-legacy-php-interpreter/releases
KANAL=https://lizenz.retrowork.de/keyhelp-legacy-php-interpreter
version=""
if [ "${1:-}" = --version ]; then
  [ $# -eq 2 ] && [[ "$2" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fehler "Aufruf: veroeffentlichung-pruefen.sh [--version <v>]" 2
  version=$2
elif [ $# -ne 0 ]; then
  fehler "Aufruf: veroeffentlichung-pruefen.sh [--version <v>]" 2
fi
for w in curl openssl sha256sum awk; do command -v "$w" > /dev/null || fehler "$w fehlt" 4; done
pub=$wurzel/schluessel/release-ed25519.pub
fp=$(schluessel_fingerabdruck "$pub") || fehler "$pub enthält keinen Ed25519-Schlüssel" 4
basis=$RELEASES/latest/download
[ -z "$version" ] || basis=$RELEASES/download/v$version
t=$(mktemp -d "${TMPDIR:-/tmp}/khli-veroeff.XXXXXX")
trap 'rm -rf -- "$t"' EXIT
fehl=0
pruefe() {
  local name=$1
  shift
  if "$@" > /dev/null 2>&1; then printf 'ok   %s\n' "$name"; else printf 'FEHL %s\n' "$name"; fehl=$((fehl + 1)); fi
}
laden() { curl -fsSL --proto '=https' --proto-redir '=https' --max-time 120 -o "$t/$1" "$basis/$1"; }

printf 'veroeffentlichung-pruefen 1.0.0, Quelle %s, Schlüssel des Repositorys SHA256:%s\n' "$basis" "$fp"
for f in SHA256SUMS SHA256SUMS.sig install.sh RELEASE; do laden "$f" || fehler "Download gescheitert: $basis/$f" 1; done
pruefe "Signatur von SHA256SUMS mit dem Schlüssel des Repositorys" \
  openssl pkeyutl -verify -pubin -inkey "$pub" -rawin -in "$t/SHA256SUMS" -sigfile "$t/SHA256SUMS.sig"
pruefe "install.sh gegen SHA256SUMS" test "$(sha256 "$t/install.sh")" = "$(awk '$2 == "install.sh" {print $1}' "$t/SHA256SUMS")"
pruefe "RELEASE gegen SHA256SUMS" test "$(sha256 "$t/RELEASE")" = "$(awk '$2 == "RELEASE" {print $1}' "$t/SHA256SUMS")"
schluessel_auslesen "$t/install.sh" > "$t/eingesetzt.pem"
pruefe "Schlüssel in install.sh ist der des Repositorys" test "$(schluessel_fingerabdruck "$t/eingesetzt.pem" || true)" = "$fp"
r_version=$(sed -n 's/^VERSION=//p' "$t/RELEASE")
if [ -n "$version" ]; then pruefe "Version $version" test "$r_version" = "$version"; fi
printf 'Release %s, install.sh %s\n' "$r_version" "$(sed -n 's/^INSTALL_SH_VERSION=//p' "$t/install.sh")"
if [ "$fehl" -ne 0 ]; then
  printf 'nicht gestartet: das geladene install.sh ist nicht bestätigt (%d Abweichungen)\n' "$fehl"
  exit 1
fi
rc=0
if [ -n "$version" ]; then bash "$t/install.sh" --version "$version" --nur-pruefen > "$t/lauf.txt" 2>&1 < /dev/null || rc=$?
else bash "$t/install.sh" --nur-pruefen > "$t/lauf.txt" 2>&1 < /dev/null || rc=$?; fi
sed 's/^/     | /' "$t/lauf.txt"
pruefe "install.sh --nur-pruefen endet mit 0" test "$rc" = 0
pruefe "Signatur gültig" grep -q 'Signatur gültig' "$t/lauf.txt"
pruefe "zweiter Kanal: als gültig geführt" grep -q 'als gültig geführt' "$t/lauf.txt"
# Laufzeit der Freigabeliste: Erinnerung, wenn sie in weniger als 30 Tagen abläuft
if curl -fsSL --proto '=https' --max-time 60 -o "$t/freigaben.txt" "$KANAL/freigaben.txt"; then
  bis=$(awk '/^# gueltig-bis [0-9-]+$/ {print $3; exit}' "$t/freigaben.txt")
  if [ -n "$bis" ]; then
    grenze=$(date -u -d '+30 days' +%Y-%m-%d)
    printf 'Freigabeliste gültig bis %s\n' "$bis"
    pruefe "Freigabeliste gilt noch mindestens 30 Tage" test ! "$grenze" \> "$bis"
  else
    printf 'Freigabeliste ohne Ablaufdatum (Format vor install.sh 1.1.0)\n'
  fi
fi
printf 'Ergebnis: %s\n' "$([ "$fehl" -eq 0 ] && echo 'in Ordnung' || echo "$fehl Abweichungen")"
[ "$fehl" -eq 0 ]
