#!/bin/bash
# ende-zu-ende.sh - Version 1.0.1
# 1.0.1: fehlt install-sh.log noch, keine Meldung der Shell mehr (Reihenfolge der Umleitungen)
# Prüft den ganzen Weg auf einem TESTSERVER mit Debian 13, KeyHelp und schon installiertem PHP 5.6
# dieses Projekts: Wegwerf-Schlüssel erzeugen, ein Release mit dem echten Installer und dem echten
# Ergänzungssatz bauen, signieren und prüfen, es mit dem install.sh aus diesem Release einspielen
# (update im leichten Zweig, mit --voll auch im vollen Zweig) und danach khli-php56 check.
# Dazu zwei Abfragen ohne Installation: der echte zweite Kanal und das neueste Release auf GitHub.
# Verändert den Server wie ein update von Hand. Nur auf Testservern.
#
# Aufruf als root: bash tests/ende-zu-ende.sh --testserver <ergaenzungssatz.tar.xz> [--voll]
#   --voll  zusätzlich update mit --neu-aufbauen: Ordnertausch, die 5.6-Websites sind Sekunden weg
# Exit: 0 alle Schritte wie erwartet, 1 Abweichung, 2 falscher Aufruf, 4 Voraussetzung fehlt
set -uo pipefail
export LC_ALL=C.UTF-8
umask 077
hier=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
wurzel=$(cd "$hier/.." && pwd)
WERKZEUG=ende-zu-ende
# shellcheck source=werkzeuge/gemeinsam.sh
. "$wurzel/werkzeuge/gemeinsam.sh"

[ "${1:-}" = --testserver ] || fehler "nur auf Testservern; Aufruf: ende-zu-ende.sh --testserver <ergaenzungssatz.tar.xz> [--voll]" 2
[ $# -ge 2 ] && [ $# -le 3 ] || fehler "Aufruf: ende-zu-ende.sh --testserver <ergaenzungssatz.tar.xz> [--voll]" 2
erg=$2 voll=0
if [ $# -eq 3 ]; then [ "$3" = --voll ] || fehler "drittes Argument: --voll" 2; voll=1; fi
[ "$(id -u)" -eq 0 ] || fehler "nur als root" 4
[ "$(cut -d. -f1 /etc/debian_version 2> /dev/null)" = 13 ] || fehler "nur Debian 13" 4
[ -e /usr/bin/keyhelp ] || fehler "KeyHelp fehlt" 4
[ -f /var/lib/khli-php56/zustand.env ] || fehler "PHP 5.6 dieses Projekts ist nicht installiert (zuerst install)" 4
[ -f "$erg" ] || fehler "Ergänzungssatz nicht gefunden: $erg" 4

t=$(mktemp -d /var/tmp/khli-e2e.XXXXXX)
trap 'rm -rf -- "$t"' EXIT
PW=wegwerf-passphrase-ende-zu-ende
ok=0 fehl=0
schritt() {
  # $1 Name, $2 erwarteter Exit-Code, danach der Befehl; Ausgabe in $t/<name>.txt und gekürzt hier
  local name=$1 soll=$2 ist=0
  shift 2
  "$@" > "$t/$name.txt" 2>&1 < /dev/null || ist=$?
  if [ "$ist" = "$soll" ]; then ok=$((ok + 1)); printf 'ok   %-4s Exit %s: %s\n' "$name" "$ist" "$*"
  else fehl=$((fehl + 1)); printf 'FEHL %-4s Exit %s, erwartet %s: %s\n' "$name" "$ist" "$soll" "$*"; fi
  sed 's/^/     | /' "$t/$name.txt" | tail -n "${ZEILEN:-8}"
}
bedingung() {
  local name=$1
  shift
  if "$@" > /dev/null 2>&1; then ok=$((ok + 1)); printf 'ok   %-4s %s\n' "$name" "$*"
  else fehl=$((fehl + 1)); printf 'FEHL %-4s nicht erfüllt: %s\n' "$name" "$*"; fi
}

printf 'ende-zu-ende 1.0.1, %s, Debian %s, KeyHelp-Server, installiert: %s\n' "$(openssl version | cut -d' ' -f1-2)" \
  "$(cat /etc/debian_version)" "$(sed -n 's/^KHLI_VERSION=//p' /var/lib/khli-php56/zustand.env | tail -n 1)"
printf 'Ergänzungssatz %s, SHA-256 %s\n' "$(basename -- "$erg")" "$(sha256 "$erg")"
openssl genpkey -algorithm ed25519 -aes-256-cbc -pass "pass:$PW" -out "$t/test.key" 2> /dev/null || fehler "kein Wegwerf-Schlüssel" 4
openssl pkey -in "$t/test.key" -passin "pass:$PW" -pubout -out "$t/test.pub" || fehler "kein öffentlicher Schlüssel" 4
printf 'Wegwerf-Schlüssel SHA256:%s (wird am Ende gelöscht)\n' "$(schluessel_fingerabdruck "$t/test.pub")"
log_vorher=$( { wc -l < /var/log/khli-php56/install-sh.log; } 2> /dev/null || echo 0)

schritt E01 0 bash "$wurzel/werkzeuge/release-bauen.sh" --ohne-git --schluessel "$t/test.pub" "$erg" "$t/release"
printf '%s\n' "$PW" > "$t/pw"
schritt E02 0 bash -c 'bash "$1" "$2" "$3" < "$4"' _ "$wurzel/werkzeuge/release-signieren.sh" "$t/release" "$t/test.key" "$t/pw"
rm -f "$t/pw"
schritt E03 0 bash "$wurzel/werkzeuge/release-pruefen.sh" "$t/release" "$t/test.pub"
ZEILEN=14 schritt E04 0 bash "$t/release/install.sh" --quelle "$t/release" --ohne-zweiten-kanal
bedingung E04a grep -q 'starte khli-php56.sh update' "$t/E04.txt"
bedingung E04b grep -q 'fertig: Release' "$t/E04.txt"
schritt E05 0 /usr/local/sbin/khli-php56 check
if [ "$voll" = 1 ]; then
  ZEILEN=14 schritt E06 0 bash "$t/release/install.sh" --quelle "$t/release" --ohne-zweiten-kanal -- --neu-aufbauen
  schritt E07 0 /usr/local/sbin/khli-php56 check
fi
schritt E08 0 /usr/local/sbin/khli-php56 status
log_nachher=$( { wc -l < /var/log/khli-php56/install-sh.log; } 2> /dev/null || echo 0)
bedingung E09 test "$log_nachher" -gt "$log_vorher"
tail -n 2 /var/log/khli-php56/install-sh.log | sed 's/^/     | /'
# ohne Installation: echter zweiter Kanal (Exit 0 auch ohne Liste, dann mit Warnung) und das neueste
# Release auf GitHub (vor dem ersten Release Exit 1: SHA256SUMS fehlt)
schritt E10 0 bash "$t/release/install.sh" --quelle "$t/release" --nur-pruefen
ist=0
bash "$t/release/install.sh" --nur-pruefen --ohne-zweiten-kanal > "$t/E11.txt" 2>&1 < /dev/null || ist=$?
printf 'info E11  Exit %s: neuestes Release auf GitHub, nur prüfen\n' "$ist"
sed 's/^/     | /' "$t/E11.txt" | tail -n 4
printf 'Schritte: %d wie erwartet, %d anders\n' "$ok" "$fehl"
[ "$fehl" -eq 0 ]
