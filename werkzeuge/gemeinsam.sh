# gemeinsam.sh - Version 1.0.0
# Gemeinsame Funktionen der Werkzeuge unter werkzeuge/ und der Tests; wird mit "source" geladen.
# Läuft unter Linux und in Git Bash unter Windows (OpenSSL ab 3.0 mit Ed25519).

meldung() { printf '%s: %s\n' "${WERKZEUG:-werkzeug}" "$*"; }
fehler() { printf '%s: FEHLER: %s\n' "${WERKZEUG:-werkzeug}" "$1" >&2; exit "${2:-1}"; }

sha256() { sha256sum < "$1" | cut -c1-64; }

schluessel_fingerabdruck() {
  # $1 Datei mit öffentlichem Schlüssel (PEM); gibt den SHA-256 des Schlüssels in DER aus,
  # scheitert, wenn es kein Ed25519-Schlüssel ist
  local text
  text=$(openssl pkey -pubin -in "$1" -noout -text 2> /dev/null) || return 1
  [[ "$text" == "ED25519 Public-Key:"* ]] || return 1
  openssl pkey -pubin -in "$1" -outform DER 2> /dev/null | sha256sum | cut -c1-64
}

schluessel_einsetzen() {
  # $1 install.sh mit leerem Platzhalter, $2 öffentlicher Schlüssel (PEM); Ausgabe auf stdout.
  # Exit 3, wenn der Block zwischen den Markierungen nicht genau der Platzhalter ist.
  awk -v pemdatei="$2" -v q="'" '
    BEGIN {
      while ((getline z < pemdatei) > 0) { sub(/\r$/, "", z); if (z != "") pem = pem (pem == "" ? "" : "\n") z }
    }
    /^# BEGINN SCHLUESSEL$/ { print; drin = 1; gesehen++; next }
    drin && /^# ENDE SCHLUESSEL$/ {
      if (zeilen != 1 || !platzhalter) kaputt = 1
      print "SCHLUESSEL_PEM=" q pem q
      print
      drin = 0
      next
    }
    drin { zeilen++; if ($0 == "SCHLUESSEL_PEM=" q q) platzhalter = 1; next }
    { print }
    END { if (gesehen != 1 || drin || kaputt || pem == "") exit 3 }
  ' "$1"
}

schluessel_auslesen() {
  # $1 install.sh; gibt den eingesetzten öffentlichen Schlüssel (PEM) aus
  awk '/^# BEGINN SCHLUESSEL$/ {drin = 1; next} /^# ENDE SCHLUESSEL$/ {drin = 0} drin' "$1" \
    | sed -e "s/^SCHLUESSEL_PEM='//" -e "s/'\$//"
}

passphrase_lesen() {
  # $1 Aufforderung; liest von der Tastatur ohne Echo oder, ohne Terminal, eine Zeile von stdin
  local pw=""
  if [ -t 0 ]; then
    IFS= read -rsp "$1: " pw || true
    printf '\n' >&2
  else
    IFS= read -r pw || true
  fi
  PASSPHRASE=$pw
}

ohne_cr() {
  # $@ Dateien; scheitert, wenn eine davon ein Wagenrücklaufzeichen enthält (Windows-Zeilenenden)
  local f
  for f in "$@"; do
    if grep -q $'\r' "$f"; then fehler "$f hat Windows-Zeilenenden; .gitattributes sollte LF erzwingen" 4; fi
  done
}
