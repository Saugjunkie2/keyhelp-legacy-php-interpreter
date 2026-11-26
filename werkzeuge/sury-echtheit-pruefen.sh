#!/bin/bash
# sury-echtheit-pruefen.sh - Version 1.0.0
# Prüft die Echtheit des Quellpakets uw-imap unter fremdquellen/sury/uw-imap/ über Surys Signaturkette:
#   Surys Schlüssel (fremdquellen/sury/echtheit/apt.gpg, Fingerabdruck 15058500A0235D97F5D10063B188E2B695BD4743)
#   -> signierte InRelease -> Sources.xz -> die drei Dateien des Quellpakets
# Die Nachweise stammen von Surys Paketquelle für Debian 13 (trixie) vom 18.11.2026
# (fremdquellen/sury/uw-imap/HERKUNFT.md). Braucht gpg, gpgv und xz; ändert nichts.
# Aufruf im Repository, unter Linux oder in Git Bash: bash werkzeuge/sury-echtheit-pruefen.sh
# Exit: 0 jede Stufe stimmt, 1 Abweichung, 4 Voraussetzung fehlt
set -uo pipefail
export LC_ALL=C
hier=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
wurzel=$(cd "$hier/.." && pwd)
E=$wurzel/fremdquellen/sury/echtheit
U=$wurzel/fremdquellen/sury/uw-imap
FPR_SOLL=15058500A0235D97F5D10063B188E2B695BD4743
for w in gpg gpgv xz sha256sum awk stat; do
  command -v "$w" > /dev/null || { echo "sury-echtheit-pruefen: $w fehlt" >&2; exit 4; }
done
for f in "$E/apt.gpg" "$E/InRelease" "$E/Sources.xz"; do
  [ -f "$f" ] || { echo "sury-echtheit-pruefen: $f fehlt" >&2; exit 4; }
done
T=$(mktemp -d "${TMPDIR:-/tmp}/khli-sury.XXXXXX")
trap 'rm -rf -- "$T"' EXIT
# gpg aus Git Bash liest C:/... als relativen Pfad; dort den Pfad in die Schreibweise von Git Bash bringen
if command -v cygpath > /dev/null; then T=$(cygpath -u "$T"); fi
export GNUPGHOME=$T/gnupg
# mkdir -m scheitert unter Windows an den Rechten von NTFS; gpg arbeitet dort auch ohne Modus 700
mkdir "$GNUPGHOME" && { chmod 700 "$GNUPGHOME" 2> /dev/null || true; }
fehler=0

echo "== 1 Schlüssel"
fpr=$(gpg --batch --quiet --show-keys --with-colons "$E/apt.gpg" 2> /dev/null | awk -F: '/^fpr/ {print $10; exit}')
if [ "$fpr" = "$FPR_SOLL" ]; then echo "Fingerabdruck $fpr: OK"; else echo "Fingerabdruck ${fpr:-unbekannt}: ABWEICHUNG (soll $FPR_SOLL)"; fehler=1; fi

echo "== 2 Signatur der InRelease"
if gpgv --keyring "$E/apt.gpg" --output "$T/InRelease.txt" "$E/InRelease" 2> "$T/gpgv.log"; then
  grep -E 'Signature made|Good signature|Signatur vom|Korrekte Signatur' "$T/gpgv.log" || true
  echo "Signatur: OK"
else
  cat "$T/gpgv.log"; echo "Signatur: ABWEICHUNG"; fehler=1
fi

echo "== 3 Sources.xz gegen die signierte InRelease"
soll=$(awk '/^SHA256:/ {x = 1; next} /^[^ ]/ {x = 0} x && $3 == "main/source/Sources.xz" {print $1 " " $2}' "$T/InRelease.txt" 2> /dev/null)
ist="$(sha256sum < "$E/Sources.xz" | cut -c1-64) $(stat -c %s "$E/Sources.xz")"
if [ -n "$soll" ] && [ "$soll" = "$ist" ]; then echo "main/source/Sources.xz: OK"; else echo "main/source/Sources.xz: ABWEICHUNG"; fehler=1; fi

echo "== 4 Dateien von uw-imap gegen Sources"
xz -dc "$E/Sources.xz" > "$T/Sources" || { echo "Sources.xz lässt sich nicht entpacken"; fehler=1; }
awk 'BEGIN { RS = ""; FS = "\n" }
  {
    paket = ""; im = 0
    for (i = 1; i <= NF; i++) {
      if ($i ~ /^Package: /) paket = substr($i, 10)
      if ($i ~ /^Checksums-Sha256:/) { im = 1; continue }
      if (im && $i ~ /^ /) { if (paket == "uw-imap") { split($i, t, " "); print t[3], t[1], t[2] }; continue }
      im = 0
    }
  }' "$T/Sources" > "$T/erwartet"
anzahl=0
for f in "$U"/uw-imap_*; do
  [ -f "$f" ] || continue
  anzahl=$((anzahl + 1))
  n=$(basename -- "$f")
  zeile=$(awk -v n="$n" '$1 == n {print $2 " " $3; exit}' "$T/erwartet")
  ist="$(sha256sum < "$f" | cut -c1-64) $(stat -c %s "$f")"
  if [ -z "$zeile" ]; then echo "$n: nicht im signierten Index"; fehler=1
  elif [ "$zeile" = "$ist" ]; then echo "$n: OK"
  else echo "$n: ABWEICHUNG"; fehler=1; fi
done
[ "$anzahl" -eq 3 ] || { echo "erwartet drei Dateien uw-imap_*, gefunden $anzahl"; fehler=1; }
echo "== Ergebnis: $([ "$fehler" -eq 0 ] && echo 'alle Stufen OK' || echo 'ABWEICHUNG, siehe oben')"
exit "$fehler"
