#!/bin/bash
# install.sh - Version 1.0.0
# keyhelp-legacy-php-interpreter: PHP 5.6 für KeyHelp unter Debian 13 (amd64)
# https://github.com/Saugjunkie2/keyhelp-legacy-php-interpreter
# Copyright 2026 Retrowork. Lizenz: Apache License 2.0, siehe LICENSE und NOTICE.
#
# Installiert oder aktualisiert PHP 5.6 auf einem KeyHelp-Server mit Debian 13, als root:
#   curl -fsSL https://github.com/Saugjunkie2/keyhelp-legacy-php-interpreter/releases/latest/download/install.sh | bash
# Hilfe: bash install.sh --hilfe
#
# Ablauf: lädt die signierte Liste SHA256SUMS des Releases und prüft ihre Ed25519-Signatur mit dem
# unten eingetragenen öffentlichen Schlüssel, lädt jede Datei des Releases und prüft sie gegen die
# Liste, fragt den zweiten Kanal nach Widerrufen und startet erst dann den geprüften Installer
# khli-php56.sh. Der Installer prüft seinerseits KeyHelps Originalpaket und den Ergänzungssatz
# gegen seine fest eingetragenen SHA-256. Ohne gültige Signatur ändert dieses Skript nichts.
#
# Den Schlüssel setzt werkzeuge/release-bauen.sh beim Bau eines Releases aus
# schluessel/release-ed25519.pub ein. Im Repository steht hier ein leerer Platzhalter; installiert
# wird nur mit dem install.sh aus einem Release.
set -euo pipefail
umask 077
export LC_ALL=C.UTF-8
PATH=$PATH:/usr/local/sbin:/usr/sbin:/sbin

INSTALL_SH_VERSION=1.0.0
PRODUKT=keyhelp-legacy-php-interpreter
SYSTEM=debian13-amd64
RELEASES=https://github.com/Saugjunkie2/keyhelp-legacy-php-interpreter/releases
ZWEITER_KANAL=https://lizenz.retrowork.de/keyhelp-legacy-php-interpreter
ZUSTAND_DATEI=/var/lib/khli-php56/zustand.env
PROTOKOLL_ORDNER=/var/log/khli-php56
MAX_DATEIEN=20
MAX_BYTES=268435456
MAX_LISTE=1048576

# Öffentlicher Schlüssel für die Signaturen der Releases (Ed25519)
# BEGINN SCHLUESSEL
SCHLUESSEL_PEM=''
# ENDE SCHLUESSEL

meldung() { printf 'install.sh: %s\n' "$*"; }
warnung() { printf 'install.sh: WARNUNG: %s\n' "$*" >&2; }
fehler() { printf 'install.sh: FEHLER: %s\n' "$1" >&2; exit "${2:-1}"; }

hilfe() {
  cat <<'TEXT'
install.sh: PHP 5.6 für KeyHelp unter Debian 13 installieren oder aktualisieren

Aufruf als root:  bash install.sh [Optionen] [-- Optionen für den Installer]

  --version <v>          ein bestimmtes Release statt des neuesten, etwa 0.4.15
  --quelle <ort>         Release aus einem Ordner oder von einer https-Adresse statt von GitHub
  --nur-pruefen          nur laden und prüfen, nichts installieren (auch ohne root)
  --nur-laden <ordner>   laden, prüfen und in einen neuen Ordner legen, etwa für einen Server
                         ohne Internet (dort: bash <ordner>/install.sh --quelle <ordner>)
  --ohne-zweiten-kanal   die Widerrufsliste auf dem zweiten Kanal nicht abfragen
  --aelter-erlauben      ein älteres Release über ein neueres installieren
  --hilfe                diese Hilfe

Ohne Optionen: install, wenn PHP 5.6 von diesem Projekt noch nicht eingerichtet ist, sonst update.
Optionen nach -- gehen an den Installer, etwa -- --neu-aufbauen oder -- --original <datei>.
Danach: khli-php56 check, khli-php56 status, khli-php56 uninstall.

Exit: 0 Erfolg, 1 Fehler (etwa ein Download), 2 falscher Aufruf, 3 Signatur oder Prüfsumme falsch,
4 Voraussetzung fehlt, 5 zum Schutz abgelehnt (Release widerrufen oder älter als installiert);
nach dem Start des Installers dessen Exit-Code.
TEXT
}

holen() {
  # $1 Basis (Ordner oder https-Adresse), $2 Dateiname, $3 Ziel, $4 Höchstgröße in Bytes,
  # $5 "leise": Fehlermeldungen von curl und wget unterdrücken
  local basis=$1 name=$2 ziel=$3 max=$4 leise=${5:-}
  rm -f -- "$ziel"
  case "$basis" in
    https://*)
      if command -v curl > /dev/null; then
        if [ "$leise" = leise ]; then
          curl -fsL --proto '=https' --proto-redir '=https' --connect-timeout 20 --max-time 900 \
            --max-filesize "$max" -o "$ziel" "$basis/$name" 2> /dev/null || return 1
        else
          curl -fsSL --proto '=https' --proto-redir '=https' --connect-timeout 20 --max-time 900 \
            --max-filesize "$max" -o "$ziel" "$basis/$name" || return 1
        fi
      elif command -v wget > /dev/null; then
        if [ "$leise" = leise ]; then
          wget -q --https-only --timeout=60 -O "$ziel" "$basis/$name" 2> /dev/null || return 1
        else
          wget -q --https-only --timeout=60 -O "$ziel" "$basis/$name" || return 1
        fi
      else
        return 1
      fi ;;
    *)
      [ -f "$basis/$name" ] && [ ! -L "$basis/$name" ] || return 1
      cp -- "$basis/$name" "$ziel" || return 1 ;;
  esac
  [ -f "$ziel" ] && [ "$(stat -c %s -- "$ziel")" -le "$max" ]
}

schluessel_vorbereiten() {
  local text
  [ -n "$SCHLUESSEL_PEM" ] || fehler "dieses install.sh enthält keinen öffentlichen Schlüssel (Stand aus dem Repository); bitte das install.sh aus einem Release verwenden: $RELEASES" 4
  printf '%s\n' "$SCHLUESSEL_PEM" > "$tmp/schluessel.pem"
  text=$(openssl pkey -pubin -in "$tmp/schluessel.pem" -noout -text 2> /dev/null) || fehler "der eingetragene öffentliche Schlüssel ist nicht lesbar" 3
  [[ "$text" == "ED25519 Public-Key:"* ]] || fehler "der eingetragene öffentliche Schlüssel ist kein Ed25519-Schlüssel" 3
  FINGERABDRUCK=$(openssl pkey -pubin -in "$tmp/schluessel.pem" -outform DER 2> /dev/null | sha256sum | cut -c1-64)
}

signatur_gueltig() {
  # $1 Datei, $2 Signatur: 64 Bytes Ed25519 über die ganze Datei
  local aus
  [ -f "$2" ] && [ "$(stat -c %s -- "$2")" -eq 64 ] || return 1
  aus=$(openssl pkeyutl -verify -pubin -inkey "$tmp/schluessel.pem" -rawin -in "$1" -sigfile "$2" 2>&1) || return 1
  [[ "$aus" == *"Signature Verified Successfully"* ]]
}

summen_lesen() {
  local zeile n=0 muster='^[0-9a-f]{64}  ([A-Za-z0-9][A-Za-z0-9._+-]{0,127})$' name
  : > "$tmp/namen"
  while IFS= read -r zeile || [ -n "$zeile" ]; do
    n=$((n + 1))
    [[ $zeile =~ $muster ]] || fehler "SHA256SUMS: Zeile $n hat nicht die Form <sha256>  <datei>" 3
    name=${BASH_REMATCH[1]}
    case "$name" in SHA256SUMS|SHA256SUMS.sig) fehler "SHA256SUMS: $name darf nicht darin stehen" 3 ;; esac
    if grep -qxF -- "$name" "$tmp/namen"; then fehler "SHA256SUMS: $name steht doppelt darin" 3; fi
    printf '%s\n' "$name" >> "$tmp/namen"
  done < "$tmp/SHA256SUMS"
  [ "$n" -ge 1 ] && [ "$n" -le "$MAX_DATEIEN" ] || fehler "SHA256SUMS: $n Einträge, erlaubt sind 1 bis $MAX_DATEIEN" 3
}

summe_von() { awk -v n="$1" 'substr($0, 67) == n {print substr($0, 1, 64)}' "$tmp/SHA256SUMS"; }
gelistet() { grep -qxF -- "$1" "$tmp/namen"; }

datei_holen_und_pruefen() {
  # $1 Dateiname aus SHA256SUMS
  local soll ist
  soll=$(summe_von "$1")
  holen "$BASIS" "$1" "$tmp/dateien/$1" "$MAX_BYTES" || fehler "Download gescheitert: $BASIS/$1" 1
  ist=$(sha256sum < "$tmp/dateien/$1" | cut -c1-64)
  [ "$ist" = "$soll" ] || fehler "SHA-256 von $1 ist $ist, laut signierter Liste $soll" 3
}

rel_wert() { sed -n "s/^$1=//p" "$tmp/dateien/RELEASE"; }

release_lesen() {
  local zeile n=0 muster='^[A-Z][A-Z0-9_]{0,31}=[A-Za-z0-9._:+-]{0,128}$' k
  while IFS= read -r zeile || [ -n "$zeile" ]; do
    n=$((n + 1))
    [[ $zeile =~ $muster ]] || fehler "RELEASE: Zeile $n ist ungültig" 3
  done < "$tmp/dateien/RELEASE"
  for k in PRODUKT VERSION SYSTEM INSTALLER ERGAENZUNG; do
    [ "$(grep -c "^$k=" "$tmp/dateien/RELEASE")" = 1 ] || fehler "RELEASE: $k fehlt oder steht mehrfach darin" 3
  done
  R_PRODUKT=$(rel_wert PRODUKT)
  R_VERSION=$(rel_wert VERSION)
  R_SYSTEM=$(rel_wert SYSTEM)
  R_INSTALLER=$(rel_wert INSTALLER)
  R_ERGAENZUNG=$(rel_wert ERGAENZUNG)
  R_MIN=$(rel_wert INSTALL_SH_MIN)
  [ "$R_PRODUKT" = "$PRODUKT" ] || fehler "RELEASE: Produkt $R_PRODUKT, erwartet $PRODUKT" 3
  [ "$R_SYSTEM" = "$SYSTEM" ] || fehler "RELEASE: System $R_SYSTEM, erwartet $SYSTEM" 3
  [[ "$R_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fehler "RELEASE: Version $R_VERSION ist ungültig" 3
  [[ "$R_INSTALLER" =~ ^[A-Za-z0-9._+-]+\.sh$ ]] || fehler "RELEASE: Installer $R_INSTALLER ist ungültig" 3
  [[ "$R_ERGAENZUNG" =~ ^khli-php56-ergaenzung-[0-9]+\.[0-9]+\.[0-9]+-debian13-amd64\.tar\.xz$ ]] || fehler "RELEASE: Ergänzungssatz $R_ERGAENZUNG ist ungültig" 3
  if [ -n "$R_MIN" ] && [ "$(printf '%s\n%s\n' "$R_MIN" "$INSTALL_SH_VERSION" | sort -V | tail -n 1)" != "$INSTALL_SH_VERSION" ]; then
    fehler "das Release braucht install.sh ab $R_MIN, dieses ist $INSTALL_SH_VERSION; bitte das install.sh aus dem Release verwenden" 4
  fi
  if [ -n "$VERSION_WUNSCH" ] && [ "$R_VERSION" != "$VERSION_WUNSCH" ]; then
    fehler "angefordert war Release $VERSION_WUNSCH, die signierte Liste gehört zu $R_VERSION" 3
  fi
  gelistet "$R_INSTALLER" || fehler "SHA256SUMS: der Installer $R_INSTALLER fehlt" 3
  gelistet "$R_ERGAENZUNG" || fehler "SHA256SUMS: der Ergänzungssatz $R_ERGAENZUNG fehlt" 3
}

zweiter_kanal() {
  local d=$tmp/kanal zeile status grund
  if [ "$OHNE_KANAL" = 1 ]; then meldung "zweiter Kanal nicht abgefragt (--ohne-zweiten-kanal)"; return 0; fi
  mkdir -p "$d"
  if ! holen "$ZWEITER_KANAL" freigaben.txt "$d/freigaben.txt" "$MAX_LISTE" leise \
     || ! holen "$ZWEITER_KANAL" freigaben.txt.sig "$d/freigaben.txt.sig" 64 leise; then
    warnung "zweiter Kanal $ZWEITER_KANAL nicht erreichbar; ob das Release widerrufen ist, bleibt ungeprüft"
    return 0
  fi
  if ! signatur_gueltig "$d/freigaben.txt" "$d/freigaben.txt.sig"; then
    warnung "die Freigabeliste auf dem zweiten Kanal hat keine gültige Signatur; ob das Release widerrufen ist, bleibt ungeprüft"
    return 0
  fi
  zeile=$(awk -v s="$SUMMEN_SHA" '$0 !~ /^#/ && $2 == s {print; exit}' "$d/freigaben.txt")
  if [ -z "$zeile" ]; then
    warnung "Release $R_VERSION steht nicht in der Freigabeliste des zweiten Kanals"
    return 0
  fi
  status=$(awk '{print $3}' <<< "$zeile")
  case "$status" in
    gueltig) meldung "zweiter Kanal: Release $R_VERSION ist als gültig geführt" ;;
    widerrufen)
      grund=$(awk '{$1 = $2 = $3 = $4 = ""; sub(/^ +/, ""); print}' <<< "$zeile" | LC_ALL=C tr -cd ' -~')
      fehler "Release $R_VERSION ist widerrufen: ${grund:-ohne Angabe}; bitte ein anderes Release wählen" 5 ;;
    *) warnung "zweiter Kanal: unbekannter Status $status für Release $R_VERSION" ;;
  esac
}

platz_pruefen() {
  # $1 Ordner, $2 gebrauchte MB
  local frei
  [ -d "$1" ] || return 0
  frei=$(df -Pm -- "$1" | awk 'NR == 2 {print $4}')
  [[ "$frei" =~ ^[0-9]+$ ]] || return 0
  [ "$frei" -ge "$2" ] || fehler "unter $1 sind nur $frei MB frei, gebraucht werden etwa $2 MB" 4
}

protokollieren() {
  # eine Zeile je Lauf mit Installation, nur für root lesbar
  mkdir -p "$PROTOKOLL_ORDNER" 2> /dev/null && chmod 750 "$PROTOKOLL_ORDNER" 2> /dev/null || return 0
  printf '%s install.sh %s: Release %s, SHA256SUMS %s, Schlüssel SHA256:%s, Quelle %s, %s, Exit %s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$INSTALL_SH_VERSION" "$R_VERSION" "$SUMMEN_SHA" "$FINGERABDRUCK" \
    "$BASIS" "$1" "$2" >> "$PROTOKOLL_ORDNER/install-sh.log" 2> /dev/null || true
}

main() {
  VERSION_WUNSCH="" QUELLE="" NUR_PRUEFEN=0 NUR_LADEN="" OHNE_KANAL=0 AELTER=0
  DURCH=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --version) [ $# -ge 2 ] || fehler "--version braucht eine Versionsnummer" 2; VERSION_WUNSCH=$2; shift 2 ;;
      --quelle) [ $# -ge 2 ] || fehler "--quelle braucht einen Ordner oder eine https-Adresse" 2; QUELLE=$2; shift 2 ;;
      --nur-pruefen) NUR_PRUEFEN=1; shift ;;
      --nur-laden) [ $# -ge 2 ] || fehler "--nur-laden braucht einen Ordner" 2; NUR_LADEN=$2; shift 2 ;;
      --ohne-zweiten-kanal) OHNE_KANAL=1; shift ;;
      --aelter-erlauben) AELTER=1; shift ;;
      --hilfe|--help|-h) hilfe; exit 0 ;;
      --) shift; DURCH=("$@"); break ;;
      *) fehler "unbekannte Option: $1 (Hilfe: bash install.sh --hilfe)" 2 ;;
    esac
  done
  if [ -n "$VERSION_WUNSCH" ] && [[ ! "$VERSION_WUNSCH" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    fehler "--version erwartet eine Versionsnummer wie 0.4.15" 2
  fi
  if [ -n "$QUELLE" ]; then
    case "$QUELLE" in
      https://*) BASIS=${QUELLE%/} ;;
      *://*) fehler "--quelle nimmt einen Ordner oder eine https-Adresse" 2 ;;
      *) [ -d "$QUELLE" ] || fehler "Ordner nicht gefunden: $QUELLE" 4; BASIS=$(cd -- "$QUELLE" && pwd) ;;
    esac
  elif [ -n "$VERSION_WUNSCH" ]; then
    BASIS=$RELEASES/download/v$VERSION_WUNSCH
  else
    BASIS=$RELEASES/latest/download
  fi
  if [ -n "$NUR_LADEN" ] && [ -e "$NUR_LADEN" ]; then
    [ -d "$NUR_LADEN" ] && [ -z "$(ls -A -- "$NUR_LADEN")" ] || fehler "$NUR_LADEN gibt es schon und ist kein leerer Ordner" 2
  fi
  INSTALLIEREN=1
  if [ "$NUR_PRUEFEN" = 1 ] || [ -n "$NUR_LADEN" ]; then INSTALLIEREN=0; fi
  if [ "$INSTALLIEREN" = 1 ]; then
    [ "$(id -u)" -eq 0 ] || fehler "zum Installieren als root aufrufen (nur prüfen geht ohne root: --nur-pruefen)" 4
    [ "$(uname -s)" = Linux ] || fehler "nur Linux" 4
    [ "$(dpkg --print-architecture 2> /dev/null || true)" = amd64 ] || fehler "nur amd64" 4
    [ "$(cut -d. -f1 /etc/debian_version 2> /dev/null || true)" = 13 ] || fehler "nur Debian 13 (gefunden: $(cat /etc/debian_version 2> /dev/null || echo unbekannt))" 4
  fi
  local w
  for w in openssl sha256sum awk sed stat mktemp sort; do
    command -v "$w" > /dev/null || fehler "$w fehlt (unter Debian: apt-get install openssl coreutils)" 4
  done
  if [[ "$BASIS" == https://* ]] && ! command -v curl > /dev/null && ! command -v wget > /dev/null; then
    fehler "weder curl noch wget vorhanden" 4
  fi

  tmp=$(mktemp -d "${TMPDIR:-/tmp}/khli-install.XXXXXX") || fehler "kein temporärer Ordner" 1
  trap 'rm -rf -- "$tmp"' EXIT
  mkdir "$tmp/dateien"
  schluessel_vorbereiten
  meldung "Version $INSTALL_SH_VERSION, Quelle $BASIS"

  holen "$BASIS" SHA256SUMS "$tmp/SHA256SUMS" "$MAX_LISTE" || fehler "Download gescheitert: $BASIS/SHA256SUMS (gibt es das Release?)" 1
  holen "$BASIS" SHA256SUMS.sig "$tmp/SHA256SUMS.sig" 64 || fehler "SHA256SUMS.sig fehlt oder ist nicht ladbar ($BASIS); ohne gültige Signatur wird nichts installiert" 3
  signatur_gueltig "$tmp/SHA256SUMS" "$tmp/SHA256SUMS.sig" || fehler "die Signatur von SHA256SUMS ist ungültig (Schlüssel SHA256:$FINGERABDRUCK); nichts geändert" 3
  SUMMEN_SHA=$(sha256sum < "$tmp/SHA256SUMS" | cut -c1-64)
  summen_lesen
  gelistet RELEASE || fehler "SHA256SUMS: RELEASE fehlt" 3
  datei_holen_und_pruefen RELEASE
  release_lesen
  # das neueste Release kann zwischen zwei Downloads wechseln; ab hier gilt sein fester Name
  if [ -z "$QUELLE" ] && [ -z "$VERSION_WUNSCH" ]; then BASIS=$RELEASES/download/v$R_VERSION; fi
  local name
  while IFS= read -r name <&3; do
    [ "$name" = RELEASE ] || datei_holen_und_pruefen "$name"
  done 3< "$tmp/namen"
  local iv
  iv=$(awk -F= '/^KHLI_VERSION=[0-9.]+$/ {print $2; exit}' "$tmp/dateien/$R_INSTALLER")
  [ "$iv" = "$R_VERSION" ] || fehler "der Installer im Release hat die Version ${iv:-unbekannt}, das Release nennt $R_VERSION" 3
  meldung "Release $R_VERSION geprüft: Signatur gültig (Schlüssel SHA256:$FINGERABDRUCK), $(wc -l < "$tmp/namen") Dateien, SHA256SUMS $SUMMEN_SHA"
  zweiter_kanal

  if [ "$NUR_PRUEFEN" = 1 ] && [ -z "$NUR_LADEN" ]; then meldung "nur geprüft, nichts installiert"; return 0; fi
  if [ -n "$NUR_LADEN" ]; then
    mkdir -p -- "$NUR_LADEN"
    cp -- "$tmp/SHA256SUMS" "$tmp/SHA256SUMS.sig" "$NUR_LADEN/"
    while IFS= read -r name <&3; do cp -- "$tmp/dateien/$name" "$NUR_LADEN/"; done 3< "$tmp/namen"
    meldung "geprüftes Release $R_VERSION liegt in $NUR_LADEN; installieren dort mit: bash $NUR_LADEN/install.sh --quelle $NUR_LADEN"
    return 0
  fi

  local befehl=install installiert=""
  if [ -f "$ZUSTAND_DATEI" ]; then
    befehl=update
    installiert=$(sed -n 's/^KHLI_VERSION=//p' "$ZUSTAND_DATEI" | tail -n 1)
    if [ -n "$installiert" ] && [ "$(printf '%s\n%s\n' "$installiert" "$R_VERSION" | sort -V | tail -n 1)" != "$R_VERSION" ]; then
      [ "$AELTER" = 1 ] || fehler "installiert ist $installiert, das Release $R_VERSION ist älter; mit --aelter-erlauben trotzdem" 5
      warnung "installiert ist $installiert, eingespielt wird das ältere Release $R_VERSION (--aelter-erlauben)"
    fi
    platz_pruefen /opt/keyhelp/php 700
  else
    platz_pruefen /opt/keyhelp/php 400
  fi
  platz_pruefen /var/tmp 200
  meldung "installiert: ${installiert:-nichts von diesem Projekt}; starte $R_INSTALLER $befehl"

  # Signale während des Installers nur vermerken: er nimmt einen Abbruch selbst zurück, und dieses
  # Skript wartet, bis er fertig ist; die Kinder erben keine ignorierten Signale
  local signal="" rc
  trap 'signal=HUP' HUP
  trap 'signal=INT' INT
  trap 'signal=TERM' TERM
  set +e
  bash "$tmp/dateien/$R_INSTALLER" "$befehl" --ergaenzung "$tmp/dateien/$R_ERGAENZUNG" ${DURCH[@]+"${DURCH[@]}"} < /dev/null
  rc=$?
  set -e
  if [ -n "$signal" ]; then warnung "Signal $signal erhalten, der Installer hat seinen Lauf beendet"; fi
  protokollieren "$befehl" "$rc"
  if [ "$rc" -eq 0 ]; then meldung "fertig: Release $R_VERSION, $befehl ohne Fehler; Prüfung jederzeit mit: khli-php56 check"; fi
  return "$rc"
}

main "$@"
