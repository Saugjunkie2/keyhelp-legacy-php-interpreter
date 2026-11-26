#!/bin/bash
# werkzeuge-test.sh - Version 1.0.1
# 1.0.1: Teil B entfernt auch install-sh.log, wenn der Test es angelegt hat und der Ordner
#        /var/log/khli-php56 schon vorher bestand (1.0.0 ließ die Datei dann liegen)
# Prüft install.sh und die Werkzeuge unter werkzeuge/ mit Wegwerf-Schlüsseln und Attrappen; es
# installiert nichts und braucht kein Netz.
#   Teil A, überall (Linux, Git Bash unter Windows), ohne root: Schlüssel erzeugen, Release bauen,
#     signieren und prüfen, Freigabeliste führen; install.sh mit --nur-pruefen und --nur-laden gegen
#     gültige und veränderte Releases; der zweite Kanal als lokaler Ordner
#   Teil B, nur als root unter Debian 13 (amd64) ohne Zustand und ohne /opt/keyhelp/php/5.6, etwa
#     in einer Chroot: install.sh startet die Attrappe des Installers mit install oder update, lehnt
#     ältere und widerrufene Releases ab, reicht Optionen und Exit-Code durch, schreibt sein Protokoll
# Die Wegwerf-Schlüssel entstehen in einem temporären Ordner und werden am Ende gelöscht.
# Aufruf: bash tests/werkzeuge-test.sh
# Exit: 0 alle Fälle wie erwartet, 1 mindestens ein Fall anders, 4 Voraussetzung fehlt
set -uo pipefail
export LC_ALL=C.UTF-8
hier=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
wurzel=$(cd "$hier/.." && pwd)
WERKZEUG=werkzeuge-test
# shellcheck source=werkzeuge/gemeinsam.sh
. "$wurzel/werkzeuge/gemeinsam.sh"
for w in openssl sha256sum awk sed cmp; do command -v "$w" > /dev/null || fehler "$w fehlt" 4; done

t=$(mktemp -d "${TMPDIR:-/tmp}/khli-test.XXXXXX")
B_ZUSTAND=0 B_PROTOKOLL=0 B_LOGDATEI=0
aufraeumen() {
  rm -rf -- "$t"
  if [ "$B_ZUSTAND" = 1 ]; then rm -rf /var/lib/khli-php56; fi
  if [ "$B_PROTOKOLL" = 1 ]; then rm -rf /var/log/khli-php56; fi
  if [ "$B_LOGDATEI" = 1 ]; then rm -f /var/log/khli-php56/install-sh.log; fi
  rm -rf /tmp/khli-test-nobody
}
trap aufraeumen EXIT
ok=0 fehl=0
PW=wegwerf-passphrase-nur-fuer-den-test

fall() {
  # $1 Name, $2 erwarteter Exit-Code, danach der Befehl; Ausgabe in $t/aus.txt
  local name=$1 soll=$2 ist=0
  shift 2
  "$@" > "$t/aus.txt" 2>&1 < /dev/null || ist=$?
  bewerten "$name" "$ist" "$soll"
}
fall_mit_eingabe() {
  # wie fall, $3 ist die Eingabe auf stdin (Passphrasen)
  local name=$1 soll=$2 eingabe=$3 ist=0
  shift 3
  printf '%s' "$eingabe" | "$@" > "$t/aus.txt" 2>&1 || ist=$?
  bewerten "$name" "$ist" "$soll"
}
bewerten() {
  if [ "$2" = "$3" ]; then
    ok=$((ok + 1)); printf 'ok   %-5s Exit %s\n' "$1" "$2"
  else
    fehl=$((fehl + 1)); printf 'FEHL %-5s Exit %s, erwartet %s\n' "$1" "$2" "$3"
    sed 's/^/     | /' "$t/aus.txt" | tail -n 6
  fi
}
pruefe() {
  # $1 Name, danach eine Bedingung als Befehl
  local name=$1
  shift
  if "$@" > /dev/null 2>&1; then
    ok=$((ok + 1)); printf 'ok   %-5s %s\n' "$name" "bestätigt"
  else
    fehl=$((fehl + 1)); printf 'FEHL %-5s Bedingung nicht erfüllt: %s\n' "$name" "$*"
  fi
}
ausgabe_hat() { grep -qF -- "$1" "$t/aus.txt"; }

summen_neu() {
  # $1 Release-Ordner: SHA256SUMS aus den Dateien neu berechnen und mit dem Testschlüssel signieren
  local f
  (
    cd -- "$1" || exit 1
    for f in $(LC_ALL=C ls -1); do
      case "$f" in SHA256SUMS|SHA256SUMS.sig) continue ;; esac
      printf '%s  %s\n' "$(sha256 "$f")" "$f"
    done > SHA256SUMS
  )
  signieren "$1/SHA256SUMS" "$t/privat/khli-release-ed25519.key"
}
signieren() {
  # $1 Datei, $2 privater Schlüssel (Passphrase des Tests); Signatur nach $1.sig bzw. SHA256SUMS.sig
  local ziel=$1.sig
  [ "$(basename -- "$1")" = SHA256SUMS ] && ziel=$(dirname -- "$1")/SHA256SUMS.sig
  rm -f -- "$ziel"
  openssl pkeyutl -sign -inkey "$2" -passin "pass:$PW" -rawin -in "$1" -out "$ziel"
}
kopie() { rm -rf -- "$t/$2"; cp -r -- "$t/$1" "$t/$2"; }

printf 'werkzeuge-test 1.0.1, %s, %s\n' "$(openssl version)" "$(uname -s)"

# Testbaum: install.sh und werkzeuge/ aus diesem Repository, Attrappen von Installer und Ergänzungssatz
r=$t/repo
mkdir -p "$r/werkzeuge" "$r/installer" "$r/schluessel" "$t/privat" "$t/privat2" "$t/falsch"
cp -- "$wurzel/install.sh" "$r/"
cp -- "$wurzel"/werkzeuge/*.sh "$r/werkzeuge/"
erg=$t/khli-php56-ergaenzung-1.1.0-debian13-amd64.tar.xz
printf 'Attrappe des Ergänzungssatzes\n' > "$erg"
printf 'anderer Inhalt\n' > "$t/falsch/khli-php56-ergaenzung-1.1.0-debian13-amd64.tar.xz"
printf 'Attrappe\n' > "$t/anders.tar.xz"
cat > "$r/installer/khli-php56.sh" <<EOF
#!/bin/bash
# Attrappe des Installers für tests/werkzeuge-test.sh: schreibt ihre Argumente und endet
KHLI_VERSION=0.4.15
ORIGINAL_BUILD=20261103164601
ORIGINAL_NAME=php_5.6.40_\$ORIGINAL_BUILD.tar.gz
ORIGINAL_SHA256=4ee240d31be9f1cc5cba853728b3bc6fe4aceaa18a1a0a3dafd0d282dbf5b6c6
ERGAENZUNG_VERSION=1.1.0
ERGAENZUNG_SHA256=$(sha256 "$erg")
printf '%s\n' "\$@" > "\${KHLI_TEST_AUFRUF:-/dev/null}"
exit "\${KHLI_TEST_EXIT:-0}"
EOF

echo "== Teil A: Schlüssel"
fall_mit_eingabe A01 2 "$PW"$'\n'"$PW"$'\n' bash "$r/werkzeuge/schluessel-erzeugen.sh" "$r/schluessel"
fall_mit_eingabe A02 2 "aaaaaaaaaaaa1"$'\n'"aaaaaaaaaaaa2"$'\n' bash "$r/werkzeuge/schluessel-erzeugen.sh" "$t/privat"
fall_mit_eingabe A03 2 $'kurz\nkurz\n' bash "$r/werkzeuge/schluessel-erzeugen.sh" "$t/privat"
fall_mit_eingabe A04 0 "$PW"$'\n'"$PW"$'\n' bash "$r/werkzeuge/schluessel-erzeugen.sh" "$t/privat"
pruefe A04a test -f "$t/privat/khli-release-ed25519.key"
pruefe A04b schluessel_fingerabdruck "$r/schluessel/release-ed25519.pub"
pruefe A04c grep -q 'ENCRYPTED PRIVATE KEY' "$t/privat/khli-release-ed25519.key"
fall_mit_eingabe A05 2 "$PW"$'\n'"$PW"$'\n' bash "$r/werkzeuge/schluessel-erzeugen.sh" "$t/privat2"
openssl genpkey -algorithm ed25519 -aes-256-cbc -pass "pass:$PW" -out "$t/fremd.key" 2> /dev/null
openssl pkey -in "$t/fremd.key" -passin "pass:$PW" -pubout -out "$t/fremd.pub"
: > "$t/leer.pub"

echo "== Teil A: Release bauen"
fall W01 4 bash "$r/werkzeuge/release-bauen.sh" "$erg" "$t/ohne-git"
fall W02 3 bash "$r/werkzeuge/release-bauen.sh" --ohne-git "$t/falsch/khli-php56-ergaenzung-1.1.0-debian13-amd64.tar.xz" "$t/x2"
fall W03 3 bash "$r/werkzeuge/release-bauen.sh" --ohne-git "$t/anders.tar.xz" "$t/x3"
fall W04 3 bash "$r/werkzeuge/release-bauen.sh" --ohne-git --schluessel "$t/leer.pub" "$erg" "$t/x4"
fall W05 0 bash "$r/werkzeuge/release-bauen.sh" --ohne-git "$erg" "$t/r1"
pruefe W05a test "$(awk '{print $2}' "$t/r1/SHA256SUMS" | tr '\n' ' ')" = "RELEASE install.sh khli-php56-ergaenzung-1.1.0-debian13-amd64.tar.xz khli-php56.sh "
pruefe W05b grep -qx 'VERSION=0.4.15' "$t/r1/RELEASE"
pruefe W05c cmp -s "$(schluessel_auslesen "$t/r1/install.sh" > "$t/eingesetzt.pem"; echo "$t/eingesetzt.pem")" "$r/schluessel/release-ed25519.pub"
fall W06 2 bash "$r/werkzeuge/release-bauen.sh" --ohne-git "$erg" "$t/r1"
pruefe W07 test ! -e "$t/x2" -a ! -e "$t/x3" -a ! -e "$t/x4"

echo "== Teil A: signieren"
fall_mit_eingabe S01 3 "$PW"$'\n' bash "$r/werkzeuge/release-signieren.sh" "$t/r1" "$t/fremd.key"
pruefe S01a test ! -e "$t/r1/SHA256SUMS.sig"
fall_mit_eingabe S02 3 $'falsche-passphrase\n' bash "$r/werkzeuge/release-signieren.sh" "$t/r1" "$t/privat/khli-release-ed25519.key"
pruefe S02a test ! -e "$t/r1/SHA256SUMS.sig"
fall_mit_eingabe S03 0 "$PW"$'\n' bash "$r/werkzeuge/release-signieren.sh" "$t/r1" "$t/privat/khli-release-ed25519.key"
pruefe S03a test "$(stat -c %s -- "$t/r1/SHA256SUMS.sig")" = 64
fall_mit_eingabe S04 2 "$PW"$'\n' bash "$r/werkzeuge/release-signieren.sh" "$t/r1" "$t/privat/khli-release-ed25519.key"

echo "== Teil A: Release prüfen"
fall P01 0 bash "$r/werkzeuge/release-pruefen.sh" "$t/r1"
fall P02 3 bash "$r/werkzeuge/release-pruefen.sh" "$t/r1" "$t/fremd.pub"
kopie r1 p3
printf '# angehängt\n' >> "$t/p3/install.sh"
summen_neu "$t/p3"
fall P03 3 bash "$r/werkzeuge/release-pruefen.sh" "$t/p3"
pruefe P03a ausgabe_hat "install.sh im Release ist nicht install.sh aus diesem Repository"
kopie r1 p4
printf 'x\n' > "$t/p4/zusatz.txt"
fall P04 3 bash "$r/werkzeuge/release-pruefen.sh" "$t/p4"

echo "== Teil A: install.sh prüft Releases"
inst=$t/r1/install.sh
fall I01 0 bash "$inst" --quelle "$t/r1" --nur-pruefen --ohne-zweiten-kanal
pruefe I01a ausgabe_hat "Release 0.4.15 geprüft: Signatur gültig"
kopie r1 i2
sed -i '1s/^./0/' "$t/i2/SHA256SUMS"
[ "$(head -c 1 "$t/r1/SHA256SUMS")" != 0 ] || sed -i '1s/^./1/' "$t/i2/SHA256SUMS"
fall I02 3 bash "$inst" --quelle "$t/i2" --nur-pruefen --ohne-zweiten-kanal
pruefe I02a ausgabe_hat "Signatur von SHA256SUMS ist ungültig"
kopie r1 i3
rm "$t/i3/SHA256SUMS.sig"
fall I03 3 bash "$inst" --quelle "$t/i3" --nur-pruefen --ohne-zweiten-kanal
kopie r1 i4
rm "$t/i4/SHA256SUMS.sig"
signieren "$t/i4/SHA256SUMS" "$t/fremd.key"
fall I04 3 bash "$inst" --quelle "$t/i4" --nur-pruefen --ohne-zweiten-kanal
kopie r1 i5
printf '# verändert\n' >> "$t/i5/khli-php56.sh"
fall I05 3 bash "$inst" --quelle "$t/i5" --nur-pruefen --ohne-zweiten-kanal
pruefe I05a ausgabe_hat "SHA-256 von khli-php56.sh"
kopie r1 i6
printf 'x' >> "$t/i6/khli-php56-ergaenzung-1.1.0-debian13-amd64.tar.xz"
fall I06 3 bash "$inst" --quelle "$t/i6" --nur-pruefen --ohne-zweiten-kanal
kopie r1 i7
printf '%s  ../boese\n' "$(sha256 "$t/i7/RELEASE")" >> "$t/i7/SHA256SUMS"
signieren "$t/i7/SHA256SUMS" "$t/privat/khli-release-ed25519.key"
fall I07 3 bash "$inst" --quelle "$t/i7" --nur-pruefen --ohne-zweiten-kanal
kopie r1 i8
sed -i 's/^PRODUKT=.*/PRODUKT=anderes-produkt/' "$t/i8/RELEASE"
summen_neu "$t/i8"
fall I08 3 bash "$inst" --quelle "$t/i8" --nur-pruefen --ohne-zweiten-kanal
kopie r1 i9
sed -i 's/^VERSION=.*/VERSION=0.4.16/' "$t/i9/RELEASE"
summen_neu "$t/i9"
fall I09 3 bash "$inst" --quelle "$t/i9" --nur-pruefen --ohne-zweiten-kanal
pruefe I09a ausgabe_hat "der Installer im Release hat die Version 0.4.15, das Release nennt 0.4.16"
fall I10 3 bash "$inst" --quelle "$t/r1" --version 9.9.9 --nur-pruefen --ohne-zweiten-kanal
fall I11 4 bash "$wurzel/install.sh" --quelle "$t/r1" --nur-pruefen --ohne-zweiten-kanal
kopie r1 i12
sed -i 's/$/\r/' "$t/i12/SHA256SUMS"
signieren "$t/i12/SHA256SUMS" "$t/privat/khli-release-ed25519.key"
fall I12 3 bash "$inst" --quelle "$t/i12" --nur-pruefen --ohne-zweiten-kanal
kopie r1 i13
head -n 1 "$t/i13/SHA256SUMS" >> "$t/i13/SHA256SUMS"
signieren "$t/i13/SHA256SUMS" "$t/privat/khli-release-ed25519.key"
fall I13 3 bash "$inst" --quelle "$t/i13" --nur-pruefen --ohne-zweiten-kanal
fall I14 0 bash "$inst" --quelle "$t/r1" --nur-laden "$t/geladen" --ohne-zweiten-kanal
pruefe I14a test -f "$t/geladen/SHA256SUMS.sig" -a -f "$t/geladen/khli-php56-ergaenzung-1.1.0-debian13-amd64.tar.xz"
fall I14b 0 bash "$t/geladen/install.sh" --quelle "$t/geladen" --nur-pruefen --ohne-zweiten-kanal
fall I15 2 bash "$inst" --quelle "$t/r1" --nur-laden "$t/geladen" --ohne-zweiten-kanal
fall I16 2 bash "$inst" --unbekannt
fall I17 2 bash "$inst" --quelle http://example.org/release --nur-pruefen
kopie r1 i18
printf 'INSTALL_SH_MIN=9.0.0\n' > "$t/i18/RELEASE.neu"
grep -v '^INSTALL_SH_MIN=' "$t/i18/RELEASE" >> "$t/i18/RELEASE.neu"
mv "$t/i18/RELEASE.neu" "$t/i18/RELEASE"
summen_neu "$t/i18"
fall I18 4 bash "$inst" --quelle "$t/i18" --nur-pruefen --ohne-zweiten-kanal
kopie r1 i19
grep -v '  RELEASE$' "$t/i19/SHA256SUMS" > "$t/i19/S" && mv "$t/i19/S" "$t/i19/SHA256SUMS"
signieren "$t/i19/SHA256SUMS" "$t/privat/khli-release-ed25519.key"
fall I19 3 bash "$inst" --quelle "$t/i19" --nur-pruefen --ohne-zweiten-kanal
fall I20 2 bash "$inst" --version 1.2

echo "== Teil A: zweiter Kanal"
mkdir -p "$t/kanal" "$t/kanal2" "$t/kanal3"
for k in kanal kanal2 kanal3; do
  sed "s|^ZWEITER_KANAL=.*|ZWEITER_KANAL=$t/$k|" "$inst" > "$t/install-$k.sh"
done
fall K01 0 bash "$t/install-kanal.sh" --quelle "$t/r1" --nur-pruefen
pruefe K01a ausgabe_hat "nicht erreichbar"
fall_mit_eingabe K02 0 "$PW"$'\n' bash "$r/werkzeuge/freigabe-eintragen.sh" "$t/kanal/freigaben.txt" "$t/r1" "$t/privat/khli-release-ed25519.key"
fall K03 0 bash "$t/install-kanal.sh" --quelle "$t/r1" --nur-pruefen
pruefe K03a ausgabe_hat "als gültig geführt"
fall_mit_eingabe K04 2 "$PW"$'\n' bash "$r/werkzeuge/freigabe-eintragen.sh" "$t/kanal/freigaben.txt" "$t/r1" "$t/privat/khli-release-ed25519.key"
cp "$t/kanal/freigaben.txt" "$t/kanal2/freigaben.txt"
signieren "$t/kanal2/freigaben.txt" "$t/fremd.key"
fall K05 0 bash "$t/install-kanal2.sh" --quelle "$t/r1" --nur-pruefen
pruefe K05a ausgabe_hat "keine gültige Signatur"
printf '0.4.14 %s gueltig 2026-11-01\n' "$(printf 'x' | sha256sum | cut -c1-64)" > "$t/kanal3/freigaben.txt"
signieren "$t/kanal3/freigaben.txt" "$t/privat/khli-release-ed25519.key"
fall K06 0 bash "$t/install-kanal3.sh" --quelle "$t/r1" --nur-pruefen
pruefe K06a ausgabe_hat "steht nicht in der Freigabeliste"
fall_mit_eingabe K07 3 "$PW"$'\n' bash "$r/werkzeuge/freigabe-eintragen.sh" "$t/kanal/freigaben.txt" "$t/r1" "$t/fremd.key" widerrufen "Test"
fall_mit_eingabe K08 2 "$PW"$'\n' bash "$r/werkzeuge/freigabe-eintragen.sh" "$t/kanal/freigaben.txt" "$t/r1" "$t/privat/khli-release-ed25519.key" widerrufen 'mit "Anführungszeichen"'
fall_mit_eingabe K09 0 "$PW"$'\n' bash "$r/werkzeuge/freigabe-eintragen.sh" "$t/kanal/freigaben.txt" "$t/r1" "$t/privat/khli-release-ed25519.key" widerrufen "Test eines Widerrufs"
fall K10 5 bash "$t/install-kanal.sh" --quelle "$t/r1" --nur-pruefen
pruefe K10a ausgabe_hat "ist widerrufen: Test eines Widerrufs"
fall K11 0 bash "$t/install-kanal.sh" --quelle "$t/r1" --nur-pruefen --ohne-zweiten-kanal

if [ "$(id -u)" = 0 ] && [ "$(cut -d. -f1 /etc/debian_version 2> /dev/null)" = 13 ] \
   && [ "$(dpkg --print-architecture 2> /dev/null)" = amd64 ] && [ ! -e /var/lib/khli-php56 ] && [ ! -e /opt/keyhelp/php/5.6 ]; then
  echo "== Teil B: install.sh startet den Installer (Attrappe)"
  [ -e /var/log/khli-php56 ] || B_PROTOKOLL=1
  [ -e /var/log/khli-php56/install-sh.log ] || B_LOGDATEI=1
  B_ZUSTAND=1
  export KHLI_TEST_AUFRUF=$t/aufruf.txt
  rm -f "$KHLI_TEST_AUFRUF"
  fall B01 0 bash "$inst" --quelle "$t/r1" --ohne-zweiten-kanal
  pruefe B01a test "$(head -n 2 "$KHLI_TEST_AUFRUF" | tr '\n' ' ')" = "install --ergaenzung "
  pruefe B01b grep -q '/khli-php56-ergaenzung-1.1.0-debian13-amd64.tar.xz$' "$KHLI_TEST_AUFRUF"
  mkdir -p /var/lib/khli-php56
  printf 'KHLI_VERSION=0.4.14\nSTATUS=installiert\n' > /var/lib/khli-php56/zustand.env
  rm -f "$KHLI_TEST_AUFRUF"
  fall B02 0 bash "$inst" --quelle "$t/r1" --ohne-zweiten-kanal
  pruefe B02a test "$(head -n 1 "$KHLI_TEST_AUFRUF")" = update
  printf 'KHLI_VERSION=0.5.0\nSTATUS=installiert\n' > /var/lib/khli-php56/zustand.env
  rm -f "$KHLI_TEST_AUFRUF"
  fall B03 5 bash "$inst" --quelle "$t/r1" --ohne-zweiten-kanal
  pruefe B03a test ! -e "$KHLI_TEST_AUFRUF"
  fall B04 0 bash "$inst" --quelle "$t/r1" --ohne-zweiten-kanal --aelter-erlauben
  pruefe B04a test "$(head -n 1 "$KHLI_TEST_AUFRUF")" = update
  printf 'KHLI_VERSION=0.4.15\nSTATUS=installiert\n' > /var/lib/khli-php56/zustand.env
  fall B05 0 bash "$inst" --quelle "$t/r1" --ohne-zweiten-kanal -- --neu-aufbauen
  pruefe B05a test "$(tail -n 1 "$KHLI_TEST_AUFRUF")" = --neu-aufbauen
  fall B06 7 env KHLI_TEST_EXIT=7 bash "$inst" --quelle "$t/r1" --ohne-zweiten-kanal
  rm -f "$KHLI_TEST_AUFRUF"
  fall B07 5 bash "$t/install-kanal.sh" --quelle "$t/r1"
  pruefe B07a test ! -e "$KHLI_TEST_AUFRUF"
  pruefe B08 grep -q 'Release 0.4.15, SHA256SUMS' /var/log/khli-php56/install-sh.log
  pruefe B08a test "$(stat -c %a /var/log/khli-php56)" = 750
  mkdir -p /tmp/khli-test-nobody
  cp -r "$t/r1" /tmp/khli-test-nobody/r1
  chmod -R a+rX /tmp/khli-test-nobody
  if command -v setpriv > /dev/null; then
    fall B09 4 setpriv --reuid=65534 --regid=65534 --clear-groups bash /tmp/khli-test-nobody/r1/install.sh --quelle /tmp/khli-test-nobody/r1 --ohne-zweiten-kanal
    fall B10 0 setpriv --reuid=65534 --regid=65534 --clear-groups env TMPDIR=/tmp bash /tmp/khli-test-nobody/r1/install.sh --quelle /tmp/khli-test-nobody/r1 --nur-pruefen --ohne-zweiten-kanal
  fi
  unset KHLI_TEST_AUFRUF
else
  echo "== Teil B übersprungen (nur als root unter Debian 13 amd64 ohne PHP 5.6 dieses Projekts)"
fi

printf 'Fälle: %d wie erwartet, %d anders\n' "$ok" "$fehl"
[ "$fehl" -eq 0 ]
