#!/bin/bash
# release-bauen.sh - Version 1.0.0
# Stellt ein Release ohne Signatur zusammen: install.sh mit eingesetztem öffentlichem Schlüssel,
# installer/khli-php56.sh, den Ergänzungssatz, RELEASE und SHA256SUMS. Danach signiert der
# Betreiber mit werkzeuge/release-signieren.sh, geprüft wird mit werkzeuge/release-pruefen.sh.
#
# Aufruf im Repository, unter Linux oder in Git Bash unter Windows:
#   bash werkzeuge/release-bauen.sh [--schluessel <pub>] [--ohne-git] <ergaenzungssatz.tar.xz> [<zielordner>]
#   --schluessel <pub>  öffentlicher Schlüssel; Vorgabe schluessel/release-ed25519.pub, andere nur für Tests
#   --ohne-git          ohne sauberen Git-Stand bauen (Tests); RELEASE nennt dann COMMIT=unbekannt
#   <zielordner>        Vorgabe dist/v<version>; er darf noch nicht existieren
# Exit: 0 gebaut, 2 falscher Aufruf, 3 Prüfsumme oder Schlüssel falsch, 4 Voraussetzung fehlt
set -euo pipefail
export LC_ALL=C.UTF-8
WERKZEUG=release-bauen
hier=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
wurzel=$(cd "$hier/.." && pwd)
# shellcheck source=werkzeuge/gemeinsam.sh
. "$hier/gemeinsam.sh"
INSTALL_SH_MIN=1.0.0

schluessel=$wurzel/schluessel/release-ed25519.pub
ohne_git=0
while [ $# -gt 0 ]; do
  case "$1" in
    --schluessel) [ $# -ge 2 ] || fehler "--schluessel braucht eine Datei" 2; schluessel=$2; shift 2 ;;
    --ohne-git) ohne_git=1; shift ;;
    -*) fehler "unbekannte Option: $1" 2 ;;
    *) break ;;
  esac
done
[ $# -ge 1 ] && [ $# -le 2 ] || fehler "Aufruf: release-bauen.sh [--schluessel <pub>] [--ohne-git] <ergaenzungssatz.tar.xz> [<zielordner>]" 2
erg=$1
for w in openssl sha256sum awk sed; do command -v "$w" > /dev/null || fehler "$w fehlt" 4; done

installer=$wurzel/installer/khli-php56.sh
[ -f "$installer" ] || fehler "Installer fehlt: $installer" 4
[ -f "$wurzel/install.sh" ] || fehler "install.sh fehlt" 4
ohne_cr "$installer" "$wurzel/install.sh"
version=$(sed -n 's/^KHLI_VERSION=\([0-9.]*\)$/\1/p' "$installer")
erg_version=$(sed -n 's/^ERGAENZUNG_VERSION=\([0-9.]*\)$/\1/p' "$installer")
erg_soll=$(sed -n 's/^ERGAENZUNG_SHA256=\([0-9a-f]*\)$/\1/p' "$installer")
php_version=$(sed -n 's/^ORIGINAL_NAME=php_\([0-9.]*\)_\$ORIGINAL_BUILD\.tar\.gz$/\1/p' "$installer")
orig_build=$(sed -n 's/^ORIGINAL_BUILD=\([0-9]*\)$/\1/p' "$installer")
orig_sha=$(sed -n 's/^ORIGINAL_SHA256=\([0-9a-f]*\)$/\1/p' "$installer")
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fehler "KHLI_VERSION im Installer nicht gefunden" 4
[[ "$erg_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fehler "ERGAENZUNG_VERSION im Installer nicht gefunden" 4
[[ "$erg_soll" =~ ^[0-9a-f]{64}$ ]] || fehler "ERGAENZUNG_SHA256 im Installer nicht gefunden" 4
[[ "$php_version" =~ ^[0-9.]+$ && "$orig_build" =~ ^[0-9]+$ && "$orig_sha" =~ ^[0-9a-f]{64}$ ]] || fehler "Angaben zum Originalpaket im Installer nicht gefunden" 4
inst_sh_version=$(sed -n 's/^INSTALL_SH_VERSION=\([0-9.]*\)$/\1/p' "$wurzel/install.sh")
[[ "$inst_sh_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fehler "INSTALL_SH_VERSION in install.sh nicht gefunden" 4

erg_name=khli-php56-ergaenzung-$erg_version-debian13-amd64.tar.xz
[ -f "$erg" ] || fehler "Ergänzungssatz nicht gefunden: $erg" 4
[ "$(basename -- "$erg")" = "$erg_name" ] || fehler "der Installer erwartet $erg_name, angegeben ist $(basename -- "$erg")" 3
erg_ist=$(sha256 "$erg")
[ "$erg_ist" = "$erg_soll" ] || fehler "SHA-256 des Ergänzungssatzes ist $erg_ist, der Installer erwartet $erg_soll" 3

[ -f "$schluessel" ] || fehler "öffentlicher Schlüssel fehlt: $schluessel (siehe schluessel/LIESMICH.md)" 4
fingerabdruck=$(schluessel_fingerabdruck "$schluessel") || fehler "$schluessel enthält keinen Ed25519-Schlüssel (Platzhalter? siehe schluessel/LIESMICH.md)" 3

commit=unbekannt
if [ "$ohne_git" = 0 ]; then
  command -v git > /dev/null || fehler "git fehlt (für Tests: --ohne-git)" 4
  commit=$(git -C "$wurzel" rev-parse --verify HEAD 2> /dev/null) || fehler "kein Git-Stand (für Tests: --ohne-git)" 4
  [ -z "$(git -C "$wurzel" status --porcelain)" ] || fehler "der Arbeitsbaum hat Änderungen; ein Release entsteht nur aus einem Commit" 4
fi

ziel=${2:-$wurzel/dist/v$version}
[ ! -e "$ziel" ] || fehler "$ziel gibt es schon" 2
mkdir -p -- "$ziel"
schluessel_einsetzen "$wurzel/install.sh" "$schluessel" > "$ziel/install.sh" || { rm -rf -- "$ziel"; fehler "der Schlüsselblock in install.sh ist nicht der leere Platzhalter" 3; }
cp -- "$installer" "$ziel/khli-php56.sh"
cp -- "$erg" "$ziel/$erg_name"
{
  printf 'PRODUKT=keyhelp-legacy-php-interpreter\n'
  printf 'VERSION=%s\n' "$version"
  printf 'SYSTEM=debian13-amd64\n'
  printf 'INSTALLER=khli-php56.sh\n'
  printf 'ERGAENZUNG=%s\n' "$erg_name"
  printf 'ORIGINAL=php_%s_%s.tar.gz\n' "$php_version" "$orig_build"
  printf 'ORIGINAL_SHA256=%s\n' "$orig_sha"
  printf 'INSTALL_SH_MIN=%s\n' "$INSTALL_SH_MIN"
  printf 'INSTALL_SH_VERSION=%s\n' "$inst_sh_version"
  printf 'COMMIT=%s\n' "$commit"
  printf 'DATUM=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "$ziel/RELEASE"
(
  # erst die Namen, dann die Datei: eine Umleitung legte SHA256SUMS sonst vor dem ls an
  cd -- "$ziel"
  namen=$(LC_ALL=C ls -1)
  summen=""
  for f in $namen; do summen+="$(sha256 "$f")  $f"$'\n'; done
  printf '%s' "$summen" > SHA256SUMS
)
meldung "Release $version gebaut in $ziel"
meldung "Dateien: $(awk '{print $2}' "$ziel/SHA256SUMS" | tr '\n' ' ')"
meldung "SHA-256 von SHA256SUMS: $(sha256 "$ziel/SHA256SUMS")"
meldung "Schlüssel: SHA256:$fingerabdruck"
meldung "weiter: bash werkzeuge/release-signieren.sh $ziel <privater-schluessel>, danach bash werkzeuge/release-pruefen.sh $ziel; Tag auf GitHub: v$version"
