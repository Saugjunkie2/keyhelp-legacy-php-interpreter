#!/bin/bash
# freigabe-eintragen.sh - Version 1.2.0
# Führt die Freigabeliste für den zweiten Kanal: trägt ein signiertes Release als gültig ein, widerruft
# es oder erneuert nur das Ablaufdatum, und signiert die Liste neu. install.sh startet ab 1.1.0 nur mit
# einer gültigen, nicht abgelaufenen Liste, in der das Release als gueltig steht (docs/signatur.md).
# Format von freigaben.txt (ASCII):
#   # keyhelp-legacy-php-interpreter: Freigabeliste fuer install.sh (zweiter Kanal)
#   # Format: <version> <sha256 von SHA256SUMS> <gueltig|widerrufen> <datum> [grund]
#   # generation <n>                  steigt mit jeder neuen Fassung der Liste um 1
#   # gueltig-bis <JJJJ-MM-TT>        danach lehnt install.sh die Liste ab
#   <version> <sha256> <status> <datum> [grund]
#
# Aufruf, unter Linux oder in Git Bash unter Windows, im Repository:
#   bash werkzeuge/freigabe-eintragen.sh [--gueltig-tage <n>] <freigaben.txt> <release-ordner> <privater-schluessel> [widerrufen <grund>]
#   bash werkzeuge/freigabe-eintragen.sh [--gueltig-tage <n>] --erneuern <freigaben.txt> <privater-schluessel>
#   --gueltig-tage  Laufzeit der Liste ab heute, Vorgabe 365
#   --bisheriger-schluessel <pub>  nach einem Schlüsselwechsel: die vorhandene Liste ist noch mit dem
#                   bisherigen Schlüssel signiert; sie wird mit ihm geprüft und mit ihrer Generation
#                   fortgeführt, signiert wird die neue Liste mit dem neuen Schlüssel (docs/signatur.md)
# Ergebnis: freigaben.txt und freigaben.txt.sig im selben Ordner; beide kommen danach zusammen auf den
# zweiten Kanal (zwischen den beiden Uploads lehnt install.sh die Liste kurz ab).
# Exit: 0 eingetragen und geprüft, 2 falscher Aufruf, 3 Signatur oder Release falsch, 4 Voraussetzung fehlt
#
# 1.2.0: --bisheriger-schluessel für einen Schlüsselwechsel, die Generation läuft weiter (unabhängige
#        Gegenprüfung vom 26.11.2026, G-03)
# 1.1.0: Generation und Ablaufdatum in der Liste, Modus --erneuern, Kopf in ASCII, Prüfung gegen
#        schluessel/release-ed25519.pub, beide Dateien erst geschrieben, wenn alles stimmt (Drittprüfung
#        vom 26.11.2026, F-002, F-017)
set -euo pipefail
export LC_ALL=C.UTF-8
WERKZEUG=freigabe-eintragen
hier=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
wurzel=$(cd "$hier/.." && pwd)
# shellcheck source=werkzeuge/gemeinsam.sh
. "$hier/gemeinsam.sh"

tage=365 erneuern=0 bisher=""
while [ $# -gt 0 ]; do
  case "$1" in
    --gueltig-tage) [ $# -ge 2 ] && [[ "$2" =~ ^[0-9]{1,4}$ ]] && [ "$2" -ge 1 ] || fehler "--gueltig-tage braucht eine Zahl von 1 bis 9999" 2; tage=$2; shift 2 ;;
    --erneuern) erneuern=1; shift ;;
    --bisheriger-schluessel) [ $# -ge 2 ] || fehler "--bisheriger-schluessel braucht eine Datei" 2; bisher=$2; shift 2 ;;
    -*) fehler "unbekannte Option: $1" 2 ;;
    *) break ;;
  esac
done
modus=gueltig grund="" dir=""
if [ "$erneuern" = 1 ]; then
  [ $# -eq 2 ] || fehler "Aufruf: freigabe-eintragen.sh --erneuern <freigaben.txt> <privater-schluessel>" 2
  liste=$1 key=$2 modus=erneuern
  [ -f "$liste" ] || fehler "$liste gibt es nicht; erneuert wird nur eine vorhandene Liste" 4
else
  [ $# -eq 3 ] || [ $# -eq 5 ] || fehler "Aufruf: freigabe-eintragen.sh <freigaben.txt> <release-ordner> <privater-schluessel> [widerrufen <grund>]" 2
  liste=$1 dir=$2 key=$3
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
fi
[ -f "$key" ] || fehler "privater Schlüssel nicht gefunden: $key" 4
command -v openssl > /dev/null || fehler "openssl fehlt" 4
pub=$wurzel/schluessel/release-ed25519.pub
fingerabdruck=$(schluessel_fingerabdruck "$pub") || fehler "$pub enthält keinen Ed25519-Schlüssel" 4
# Schlüssel, mit dem die vorhandene Liste geprüft wird: der bisherige nach einem Wechsel, sonst der jetzige
pub_liste=$pub
if [ -n "$bisher" ]; then
  [ -f "$bisher" ] || fehler "bisheriger Schlüssel nicht gefunden: $bisher" 4
  fp_bisher=$(schluessel_fingerabdruck "$bisher") || fehler "$bisher enthält keinen Ed25519-Schlüssel" 4
  [ "$fp_bisher" != "$fingerabdruck" ] || fehler "--bisheriger-schluessel nennt denselben Schlüssel wie schluessel/release-ed25519.pub" 2
  pub_liste=$bisher
fi

tmp=$(mktemp -d "${TMPDIR:-/tmp}/khli-freigabe.XXXXXX")
trap 'rm -rf -- "$tmp"' EXIT
pruefen() { openssl pkeyutl -verify -pubin -inkey "${3:-$pub}" -rawin -in "$1" -sigfile "$2" > /dev/null 2>&1; }

if [ "$modus" != erneuern ]; then
  schluessel_auslesen "$dir/install.sh" > "$tmp/release.pem"
  [ "$(schluessel_fingerabdruck "$tmp/release.pem" || true)" = "$fingerabdruck" ] || fehler "install.sh im Release vertraut einem anderen Schlüssel als schluessel/release-ed25519.pub" 3
  pruefen "$dir/SHA256SUMS" "$dir/SHA256SUMS.sig" || fehler "das Release ist nicht mit dem Schlüssel des Repositorys signiert; eingetragen werden nur signierte Releases" 3
  version=$(sed -n 's/^VERSION=//p' "$dir/RELEASE")
  [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fehler "RELEASE nennt keine gültige Version" 3
  summe=$(sha256 "$dir/SHA256SUMS")
fi
datum=$(date -u +%Y-%m-%d)
bis=$(date -u -d "+$tage days" +%Y-%m-%d)

generation=0
: > "$tmp/eintraege.txt"
if [ -f "$liste" ]; then
  ohne_cr "$liste"
  if [ -f "$liste.sig" ]; then
    if [ -n "$bisher" ]; then
      pruefen "$liste" "$liste.sig" "$pub_liste" || fehler "die vorhandene Liste ist nicht mit dem bisherigen Schlüssel SHA256:$fp_bisher signiert; bitte prüfen, bevor sie ersetzt wird" 3
      meldung "vorhandene Liste mit dem bisherigen Schlüssel SHA256:$fp_bisher geprüft; die neue trägt den Schlüssel SHA256:$fingerabdruck"
    else
      pruefen "$liste" "$liste.sig" || fehler "die vorhandene Liste ist nicht mit dem Schlüssel des Repositorys signiert; nach einem Schlüsselwechsel: --bisheriger-schluessel <alter-öffentlicher-schlüssel>" 3
    fi
  else
    [ "$modus" = gueltig ] || fehler "zur vorhandenen Liste fehlt $liste.sig" 3
  fi
  generation=$(awk '/^# generation [0-9]+$/ {print $3; exit}' "$liste")
  generation=${generation:-0}
  grep -v '^#' "$liste" | grep -v '^[[:space:]]*$' > "$tmp/eintraege.txt" || true
fi
vorhanden=$(awk -v s="${summe:-}" '$2 == s' "$tmp/eintraege.txt" | wc -l)
case "$modus" in
  gueltig)
    [ "$vorhanden" -eq 0 ] || fehler "Release $version mit diesem SHA256SUMS steht schon in der Liste" 2
    printf '%s %s gueltig %s\n' "$version" "$summe" "$datum" >> "$tmp/eintraege.txt" ;;
  widerrufen)
    [ "$vorhanden" -eq 1 ] || fehler "Release $version mit diesem SHA256SUMS steht nicht in der Liste; widerrufen wird nur ein eingetragenes" 2
    awk -v s="$summe" -v d="$datum" -v g="$grund" '$2 == s {print $1, $2, "widerrufen", d, g; next} {print}' "$tmp/eintraege.txt" > "$tmp/e2.txt"
    mv "$tmp/e2.txt" "$tmp/eintraege.txt" ;;
  erneuern) ;;
esac
generation=$((generation + 1))
{
  printf '# keyhelp-legacy-php-interpreter: Freigabeliste fuer install.sh (zweiter Kanal)\n'
  printf '# Format: <version> <sha256 von SHA256SUMS> <gueltig|widerrufen> <datum> [grund]\n'
  printf '# generation %s\n' "$generation"
  printf '# gueltig-bis %s\n' "$bis"
  cat "$tmp/eintraege.txt"
} > "$tmp/neu.txt"
LC_ALL=C grep -q '[^ -~]' "$tmp/neu.txt" && fehler "die neue Liste enthält Zeichen außerhalb von ASCII" 3

passphrase_lesen "Passphrase für $key"
rc=0
printf '%s\n' "$PASSPHRASE" | openssl pkeyutl -sign -inkey "$key" -passin stdin -rawin \
  -in "$tmp/neu.txt" -out "$tmp/neu.txt.sig" || rc=$?
PASSPHRASE=""
[ "$rc" -eq 0 ] || fehler "openssl konnte nicht signieren (Passphrase falsch?)" 3
pruefen "$tmp/neu.txt" "$tmp/neu.txt.sig" || fehler "die Signatur passt nicht zu schluessel/release-ed25519.pub (falscher privater Schlüssel?); nichts geschrieben" 3
ordner=$(dirname -- "$liste")
cp -- "$tmp/neu.txt" "$ordner/.freigaben.neu"
cp -- "$tmp/neu.txt.sig" "$ordner/.freigaben.sig.neu"
mv -f -- "$ordner/.freigaben.neu" "$liste"
mv -f -- "$ordner/.freigaben.sig.neu" "$liste.sig"
case "$modus" in
  erneuern) meldung "Liste erneuert: Generation $generation, gültig bis $bis (Schlüssel SHA256:$fingerabdruck): $liste, $liste.sig" ;;
  *) meldung "Release $version als $modus eingetragen; Generation $generation, gültig bis $bis (Schlüssel SHA256:$fingerabdruck): $liste, $liste.sig" ;;
esac
meldung "weiter: freigaben.txt und freigaben.txt.sig zusammen auf den zweiten Kanal laden (docs/signatur.md); spätestens am $bis erneuern"
