#!/bin/bash
# khli-php56.sh - Version 0.4.17 (2026-11-26)
# Projekt keyhelp-legacy-php-interpreter: PHP 5.6 für KeyHelp unter Debian 13 (amd64).
#
# Installiert KeyHelps eigenen PHP-5.6-Interpreter für Debian 12 aus dem unveränderten Originalarchiv
# unter /opt/keyhelp/php/5.6 und ändert oder ergänzt nur, was Debian 13 verlangt (F-023):
#   - privat gebaute Bibliotheken unter /opt/keyhelp/php/5.6/lib/khli (Ergänzungssatz)
#   - RUNPATH in sechs Erweiterungen (gd, imagick, imap, ldap, tidy, ssh2) auf lib/khli/lib und in
#     der gebündelten libicuuc.so.69 auf den eigenen Ordner (statt einer Kopie im Systemordner);
#     ssh2.so lädt dazu libssh2 aus Debian 12 unter dem eigenen soname libssh2-khli.so.1
#   - fehlende Laufzeitpakete aus Debian 13 (apt), etwa libmcrypt4
# Danach läuft KeyHelps eigenes keyhelp-setup/install.sh wie beim Wartungsjob php-update.
# Keine Systembibliothek wird ersetzt, die Standard-PHP-Version bleibt unverändert.
#
# Aufruf als root:
#   khli-php56.sh install   [--original <datei>] [--ergaenzung <datei>] [--ergaenzung-sha256 <wert>]
#   khli-php56.sh update    [--original <datei>] [--ergaenzung <datei>] [--ergaenzung-sha256 <wert>]
#                           [--neu-aufbauen] [--trotz-fremdem-ordner] [--aelter-erlauben]
#   khli-php56.sh check     [--cron | --module-merken]
#   khli-php56.sh status
#   khli-php56.sh uninstall [--pakete-behalten] [--trotz-domains] [--trotz-fremdem-ordner]
#
#   install    prüft zuerst beide Archive und ändert bei einem Fehler nichts
#   update     ersetzt den Interpreter an Ort und Stelle wie KeyHelps Wartungsjob php-update; Pools,
#              Zeitzone, Panel-Einstellungen und Protokolle bleiben, nur KeyHelps automatisches Update für
#              5.6 schaltet update aus (vorher gesichert, ab 0.4.15); die 5.6-Websites sind dabei einige
#              Sekunden nicht erreichbar; misslingt die Prüfung oder bricht der Lauf durch einen Fehler
#              oder ein Signal ab (auch HUP an die ganze Prozessgruppe, wie beim Abbruch einer SSH-Sitzung
#              mit Terminal), kommt der bisherige Ordner zurück und der Dienst wird wieder gestartet; reißt
#              eine Sitzung ohne Terminal ab, kommt kein Signal: der Lauf geht zu Ende und schreibt weiter
#              ins Protokoll; nach SIGKILL oder Stromausfall holt der nächste update den bisherigen Ordner
#              zurück, wenn das Ziel fehlt, sonst bleibt er mit Warnung liegen, bis uninstall ihn entfernt;
#              ab 0.4.16 nur, wenn der Dienst wirklich angehalten ist, und eine ältere Fassung über eine
#              neuere nur mit --aelter-erlauben
#   check      Dateien, Bibliotheken, Module, FPM-Konfiguration und Dienst; mit --cron nur Befunde
#              (tägliche Prüfung über /etc/cron.d/khli-php56, cron schickt die Ausgabe an root); mit
#              --module-merken gelten Module, die gegenüber dem letzten Aufbau jetzt fehlen, als gewollt
#              abgeschaltet
#   uninstall  nur, wenn die geprüften Nutzungen fehlen (KeyHelps Domains, geplante Aufgaben und
#              Standard-Interpreter, Pools, Crontabs, systemd-Units); andere Aufrufe von PHP 5.6, etwa aus
#              eigenen Skripten, erkennt er nicht; sichert vorher etc/, config.ini und Protokolle
#   --ohne-keyhelp (install, update) nur für Tests in einer Chroot ohne KeyHelp
#
# Ohne --original lädt der Installer das Paket von KeyHelps Originalquelle und prüft den SHA-256.
# Ohne --ergaenzung sucht er den Ergänzungssatz neben diesem Skript und im Unterordner ergaenzung/.
# Zustand: /var/lib/khli-php56/; Protokolle und Sicherungen: /var/log/khli-php56/;
# Prüfwerkzeug: /usr/local/sbin/khli-php56 (Kopie dieses Skripts)
# Exit: 0 Erfolg, 1 Fehler, 2 falscher Aufruf, 3 Prüfsumme oder Archiv falsch, 4 Voraussetzung fehlt,
#       5 zum Schutz abgelehnt (5.6 in Gebrauch, fremder Ordner, Nutzung nicht prüfbar),
#       129, 130, 141, 143 ein Signal (HUP, INT, PIPE, TERM) hat den Lauf beendet; kam es während des
#       Tauschs eines update, ist der bisherige Stand zurückgeholt; fehlte der Ordner schon vor dem
#       update, bleibt der neue mit STATUS=fehlerhaft; scheitert die Rücknahme, endet der Lauf mit 1;
#       ein Signal erst beim Aufräumen ändert den Exit-Code nicht und bricht das Aufräumen nicht ab;
#       bricht ein Befehl unter set -e ab, endet der Lauf mit dessen Status, etwa 100 (apt-get) oder
#       2 (tar, sort, dpkg-query; dann kein falscher Aufruf); seine Fehlermeldung steht im Protokoll
#
# 0.4.17: Befunde der unabhängigen Gegenprüfung vom 26.11.2026 (docs/reviews/2026-11-26_gegenpruefung-
#        drittpruefung.md): die Modulliste entsteht nur noch bei einem Aufbau aus dem Originalarchiv
#        (install, voller Zweig von update), check --module-merken hält nur Module als gewollt
#        abgeschaltet fest, die jetzt fehlen (module-ohne.txt); Module aus eigenen ini-Dateien, die update
#        nicht übernimmt, halten so kein update mehr auf (G-01); uninstall entfernt nur Pakete, die die
#        Installation geplant hat (G-06); fehlt das Startskript, gilt ein laufender Dienst als nicht
#        angehalten (G-07); wirkt service stop in der Rücknahme nicht, beendet sie den Hauptprozess aus der
#        PID-Datei, sonst bleibt der Arbeitsordner zur Untersuchung (G-08); die Rücknahme legt auch
#        Prüfwerkzeug und Cron-Datei zurück (F-014); Testschalter KHLI_TEST_STOPP=ruecknahme, Testabbruch
#        nach_werkzeug, KHLI_TEST_EINGABE=tauschen auch für den Ergänzungssatz. 0.4.16 wurde nicht
#        veröffentlicht
# 0.4.16: Befunde der Drittprüfung vom 26.11.2026: check wertet den Exit-Code von php -m und ldd aus,
#        verlangt die Grundmodule und meldet Module, die gegenüber der letzten erfolgreichen Prüfung
#        fehlen (Liste im Zustand, check --module-merken übernimmt den jetzigen Stand; F-006); die
#        Rücknahme gilt nur als gelungen, wenn auch Zustand, ELF-Tabelle und Dienst zurück sind (F-007);
#        update tauscht nur, wenn der Dienst wirklich angehalten ist (F-008); apt entfernt nie Pakete
#        (Plan mit Entfernungen abgelehnt, --no-remove), angehobene Pakete werden genannt (F-009);
#        update spielt eine ältere Fassung nur mit --aelter-erlauben ein, geprüft unter der Sperre (F-004);
#        Originalpaket und Ergänzungssatz werden vor der Prüfung in den eigenen Arbeitsordner kopiert und
#        nur von dort benutzt (F-013); Werkzeug, Fassung und Modulliste stehen vor der Bestätigung des
#        Tauschs (F-014); Pakete aus dem Lauf von KeyHelps install.sh gelten nicht mehr als eigene (F-015);
#        uninstall erkennt auch systemd-Units, die PHP 5.6 aufrufen (F-016)
# 0.4.15: Befunde der Gegenprüfung P5 (docs/reviews/2026-11-25_gegenpruefung-p5.md): der leichte Zweig von
#        update sichert etc/, config.ini und Protokolle, bevor er den Schalter ändert (I-52); check versteht
#        null und einen Kommentar hinter dem Wert wie PHPs INI-Leser und nennt eine fehlende config.ini;
#        Hinweise gehen nicht als Warnung ins Systemprotokoll (I-54)
# 0.4.14: install und update schalten KeyHelps automatisches Update für 5.6 aus (is_autoupdate_enabled
#        = false in keyhelp-setup/config.ini, Wunsch des Betreibers vom 25.11.2026): KeyHelp hat für
#        Debian 13 kein 5.6-Paket, Aktualisierungen kommen nur über diesen Installer; check nennt einen
#        wieder eingeschalteten Schalter als Hinweis
# 0.4.13: Befunde der Gegenprüfung P4, siebte Runde (docs/reviews/2026-11-25_gegenpruefung-p4-7.md): der
#        Hinweis zum Dienst entfällt, sobald uninstall das Ziel gelöscht hat (I-48); update merkt sich
#        das Zurückholen eines Ordners aus einem Rest wie uninstall und sagt es bei der Ablehnung eines
#        fremden Ordners (I-49); die Signalfallen und fehler schalten vor dem exit auf Vermerken um,
#        ein zweites Signal bricht das Aufräumen deshalb nicht mehr ab; offen bleibt nur das sehr kurze
#        Fenster zu Beginn des Aufräumens nach einem exit ohne fehler oder einem Abbruch unter set -e
#        (I-50); Testschalter KHLI_TEST_ZWEITES_SIGNAL; Exit-Codes unter set -e im Kopf (I-51)
# 0.4.12:Befunde der Gegenprüfung P4, sechste Runde (docs/reviews/2026-11-24_gegenpruefung-p4-6.md): Exit 1
#        nach jeder gescheiterten Rücknahme mit bisherigem Ordner, auch nach einem Signal; nur ein
#        Signal, das während der Rücknahme kam, bestimmt den Exit-Code, eines beim Aufräumen nie; Kopf
#        zum Fall ohne bisherigen Ordner (I-44); Testschalter KHLI_TEST_RUECKNAHME; keine leere Menge
#        mehr an dpkg --verify und dpkg --purge (I-45); nach dem Zurückholen eines Ordners in uninstall
#        sagen Ablehnungen das und nennen den Weg zum Dienst (I-46); Sicherungen, Listen und Protokolle
#        mit eindeutigem Namen, nie überschrieben (I-47)
# 0.4.11: uninstall entfernt einen Rest gleich nach dem Zurückholen des bisherigen Ordners (N29c: ein Rest
#        ohne Kennung blieb sonst leer stehen)
# 0.4.10: Befunde der Gegenprüfung P4, fünfte Runde (docs/reviews/2026-11-20_gegenpruefung-p4-5.md):
#        uninstall holt bei fehlendem Ziel einen bisherigen Ordner aus einem Rest vor der Sicherung
#        zurück (I-40); der Exit-Code eines späten Signals gilt nur nach gelungener Rücknahme, nach
#        gescheiterter Rücknahme Exit 1 (I-41); ist die Simulation aller Pakete nicht möglich, baut der
#        Rückbau die entfernbare Teilmenge Paket für Paket auf, ohne Runden ohne Fortschritt (I-42);
#        uninstall setzt vor dem Eingriff RUECKBAU=begonnen und baut beim nächsten Lauf einen halb
#        gelöschten Ordner weiter zurück, update verweigert dann; Testabbruch an der Stelle rueckbau
#        (I-43); Testschalter wirken auch mit OHNE_KEYHELP=1 im Zustand
# 0.4.9: uninstall löscht das Ziel taub für Signale (ein Abbruch mitten im Löschen konnte einen halben Ordner
#        zurücklassen, den der nächste uninstall als fremd abgelehnt hätte; abgeleitet, Rest zu I-37;
#        Berichtigung in 0.4.10: KeyHelps uninstall.sh löscht das Ziel vorher selbst, siehe I-43)
# 0.4.8: scheitert eine Simulation von apt, nennt die Meldung den Grund aus der Ausgabe von apt (I-34);
#        Meldung zu einem Rest mit bisherigem Ordner bei vorhandenem Ziel berichtigt (ihn entfernt
#        uninstall, ein update holt ihn nur bei fehlendem Ziel zurück; I-39)
# 0.4.7: Befunde der Gegenprüfung P4, vierte Runde (docs/reviews/2026-11-19_gegenpruefung-p4-4.md): die
#        Hülle bilden alle gehaltenen Pakete, nicht nur die der Installation, und scheitert die Simulation
#        der ganzen Menge, wird jedes Paket einzeln geprüft (I-34); scheitert apt-cache, bleiben alle mit
#        Liste (I-35); zustand_setzen taub für Signale, Wartezeit des Dienststarts nach der Uhr (I-36);
#        Reste abgebrochener Läufe geschützt und erst nach dem Umbenennen des bisherigen Ordners gelöscht,
#        uninstall holt nie zurück, install räumt erst nach der Prüfung des Ziels auf (I-37); ein in der
#        Rücknahme vermerktes Signal bestimmt den Exit-Code auch nach einem Fehler (I-38); Hinweis zu
#        OHNE_KEYHELP im Protokoll, service nur in der Rücknahme taub für Signale (I-39)
# 0.4.6: was gehaltene Pakete brauchen (apt-cache depends --recurse --installed), bleibt vorab stehen;
#        die Simulation berührt dann kein gehaltenes Paket mehr (0.4.5 versuchte es mit
#        --allow-change-held-packages in der Simulation; das regelt bei apt nur die Rückfrage, die
#        Simulation scheiterte weiter, und alle Pakete blieben stehen, N31)
# 0.4.5: Versuch mit --allow-change-held-packages in der Simulation (ohne Wirkung, siehe 0.4.6)
# 0.4.4: ein vom Verwalter gehaltenes Paket der Installation bleibt beim Rückbau stehen wie ein von Hand
#        installiertes (dpkg --purge übergeht einen Halt bei ausdrücklicher Anfrage; Negativtest N31);
#        Testschalter KHLI_TEST_VOR_PURGE; das Aufräumen der Arbeitsordner läuft taub für Signale
# 0.4.3: ein gehaltenes Paket (dpkg-Status hold ok installed) gilt als installiert; bis 0.4.2 übersprang
#        der Rückbau es stillschweigend, und es stand in keiner Liste (Negativtest N31); Testschalter
#        HUP-GRUPPE-WIEDERHOLT statt HUP-GRUPPE-VERZOEGERT
# 0.4.2: Befunde der Gegenprüfung P4, dritte Runde (docs/reviews/2026-11-19_gegenpruefung-p4-3.md):
#        uninstall entfernt auch Reste eines abgebrochenen Updates mit bisherigem Ordner, install legt
#        nie einen Rest zurück (I-30); ein OHNE_KEYHELP=1 im Zustand blockiert update auf einem Server
#        mit KeyHelp nicht mehr (I-31); bleiben beim Rückbau Pakete stehen, die entfernt werden sollten,
#        stehen sie in einer Liste unter /var/log/khli-php56 und uninstall endet mit Exit 1, die Sperre
#        wird an der festen Meldung von dpkg erkannt (I-32); service, mv und cp der Rücknahme laufen
#        taub für HUP, INT und TERM, eine gescheiterte Rücknahme setzt den Zustand fehlerhaft und
#        versucht den Dienst zu starten, ein während der Rücknahme vermerktes Signal bestimmt den
#        Exit-Code (I-33)
# 0.4.1: Befunde der Gegenprüfung P4, zweite Runde (docs/reviews/2026-11-19_gegenpruefung-p4-2.md):
#        Protokoll über ein tee, das HUP, INT und TERM ignoriert und bei verlorener Ausgabe weiter ins
#        Protokoll schreibt, SIGPIPE beendet über die EXIT-Falle (I-23); während der Rücknahme werden
#        Signale nur vermerkt, die Phase bleibt bis zum Ende gesetzt, und ein bisheriger Ordner wird nie
#        gelöscht, solange der Tausch nicht bestätigt ist (I-24); Markierungen der ausdrücklich
#        angeforderten Pakete vor dem apt-Lauf festgehalten (I-25); eigene Pakete laut apt-Protokoll des
#        eigenen Laufs (I-26); Rückbau nur nach gelungener Simulation und mit dpkg --purge, das kein
#        Paket entfernt, von dem ein anderes abhängt (I-27); update ohne bisherigen Ordner endet bei
#        einem Abbruch mit Zustand fehlerhaft (I-28); --ohne-keyhelp und Testabbrüche nur ohne KeyHelp
#        (I-29)
# 0.4.0: Ergänzungssatz 1.1.0 mit libssh2 1.10.0-3+deb12u1 aus Debian 12 als libssh2-khli.so.1;
#        ssh2.so lädt es statt des libssh2 1.11 von Debian 13, mit dem ssh2_auth_pubkey_file() bei
#        ECDSA-Schlüsseln abbricht (E-0049); libcurl nutzt weiter das libssh2 von Debian 13.
# 0.3.1: Befunde der Gegenprüfung P4 (docs/reviews/2026-11-19_gegenpruefung-p4.md): update nimmt
#        auch nach einem Abbruch oder Signal den Tausch zurück und startet den Dienst wieder (I-11);
#        Nutzungsprüfung immer, wenn der Zustand eine Installation mit KeyHelp ausweist, Standard-
#        Interpreter über Muster, Pools als weiteres Merkmal (I-12); nur eigene Arbeitsordner werden
#        entfernt (I-13); als eigene Pakete zählen nur geplante Pakete eines eigenen apt-Laufs, ihre
#        Markierungen werden sofort festgehalten (I-14, I-16, I-21); Pakete, die KeyHelps übrige
#        Interpreter laden, bleiben (I-15); keine Pipe mit grep -q mehr (I-17); fremder Ordner bei
#        install mit Exit 5 (I-18); Sperrdatei bleibt, Kindprozesse erben die Sperre nicht, die tägliche
#        Prüfung schweigt während eines Laufs (I-19); Reste vor der Prüfung des Ziels, mv -T (I-20);
#        status nur als root (I-22); KeyHelps Pakete aus install.sh vorab über die eigene Erfassung.
# 0.3.0: Befunde der Gegenprüfung P2/P3: fail-closed Rückbau, Herkunft und Sicherung, Paketerfassung,
#        update, tägliche Prüfung, Sperre, strengere Archivprüfung (E-0046).
set -euo pipefail
umask 022
export LC_ALL=C.UTF-8 DEBIAN_FRONTEND=noninteractive
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

KHLI_VERSION=0.4.17
PHP_KURZ=56
PHP_VER=5.6
ZIEL=/opt/keyhelp/php/$PHP_VER
ZUSTAND=/var/lib/khli-php56
PROTOKOLL_DIR=/var/log/khli-php56
WERKZEUG=/usr/local/sbin/khli-php56
CRON=/etc/cron.d/khli-php56
SPERRE=/run/khli-php56.lock
DIENST=keyhelp-php$PHP_KURZ-fpm
PIDDATEI=/var/run/$DIENST.pid
KENNUNG=.khli-php56-arbeitsordner
# KeyHelps Paket für debian_12 (Paketindex https://repo.keyhelp.de/get_php_packages.php?os=debian_12)
ORIGINAL_BUILD=20261103164601
ORIGINAL_NAME=php_5.6.40_$ORIGINAL_BUILD.tar.gz
ORIGINAL_URL=https://repo.keyhelp.de/live/amd64/debian_12/php/5.6/$ORIGINAL_NAME
ORIGINAL_SHA256=4ee240d31be9f1cc5cba853728b3bc6fe4aceaa18a1a0a3dafd0d282dbf5b6c6
ERGAENZUNG_VERSION=1.1.0
ERGAENZUNG_NAME=khli-php56-ergaenzung-$ERGAENZUNG_VERSION-debian13-amd64.tar.xz
ERGAENZUNG_SHA256=530f1a948e5b3e6f1472d91ee24b69d4240bcc57bf9abef09ffd3f589f656502
EXT=lib/php/extensions/no-debug-non-zts-20131226
# Erweiterungen mit privaten Bibliotheken und der RUNPATH, den sie bekommen (relativ zur Datei)
PATCH_EXT="gd imagick imap ldap tidy ssh2"
RUNPATH_EXT='$ORIGIN/../../../khli/lib'
# Pakete, die der Interpreter braucht und die KeyHelps install.sh unter Debian 13 nicht installiert,
# dazu die drei, die KeyHelps install.sh unter Debian 13 selbst nachinstalliert (libtidy58,
# libssh2-1t64, libpq5): so laufen sie über die eigene Erfassung (geplant, gezählt, markiert)
PAKETE_BASIS="libmcrypt4 libmemcached11t64 libcurl4t64 libgmp10 libjpeg62-turbo libpng16-16t64 libfreetype6 libsasl2-2 libxslt1.1 libxml2 libreadline8t64 libbz2-1.0 zlib1g libssl3t64 libsodium23 libonig5 libgssapi-krb5-2 libpam0g patchelf xz-utils ca-certificates libtidy58 libssh2-1t64 libpq5"
# Wie unter Debian 12, wo libheif1 die Encoder enthielt und Ghostscript die URW-Schriften mitbrachte,
# auf die ImageMagicks type-urw-base35.xml verweist (Funktionstest imagick, docs/50)
PAKETE_WIE_DEBIAN12="fonts-urw-base35 libheif-plugin-x265 libheif-plugin-aomenc"
# apt wartet bis zu zehn Minuten auf die Paketsperre, etwa während KeyHelps eigener Wartung
APT=(apt-get -q -o DPkg::Lock::Timeout=600)

SKRIPT=$(readlink -f "${BASH_SOURCE[0]}")
hier=$(dirname "$SKRIPT")
befehl=${1:-}
[ $# -gt 0 ] && shift
OHNE_KEYHELP=0
ARBEIT=""
ARBEIT2=""
PROTOKOLL=""
ORIGINAL_DATEI=""
ERGAENZUNG_DATEI=""
ERGAENZUNG_SHA_IST=""
ERG_ARCHIV_GEPRUEFT=0
# Phase des Tauschs in update: leer, angehalten (Dienst gestoppt, Ordner noch alt), getauscht
TAUSCH_PHASE=""
LIEF=0
# update: Ordner fehlte schon vorher (I-28); Tausch bestätigt, der bisherige Ordner darf weg (I-24)
VORHER_FEHLTE=0
TAUSCH_OK=0
SPAETES_SIGNAL=0
RUECKBAU_UNVOLLSTAENDIG=""
IN_RUECKNAHME=0
# eine Rücknahme hat begonnen, eine Rücknahme hat den bisherigen Stand wiederhergestellt (I-41)
RUECKNAHME_LIEF=0
RUECKNAHME_OK=0
# Signal, das während der Rücknahme kam (I-44); bisheriger Ordner aus einem Rest zurückgelegt (I-46)
RUECKNAHME_SIGNAL=0
ZURUECKGEHOLT=0
HINWEIS_OHNE_KEYHELP=0
# Rücknahme ohne Zustand oder ELF-Tabelle: der Arbeitsordner mit ihren Sicherungen bleibt (0.4.16, F-007);
# ebenso, wenn der neue Dienst sich in der Rücknahme nicht beenden ließ (0.4.17, G-08)
ARBEIT2_BEHALTEN=0

meldung() { printf 'khli-php56: %s\n' "$*" 2>/dev/null || true; }
fehler() {
  # ab hier beenden Signale nichts mehr, sie werden vermerkt: das Aufräumen in der EXIT-Falle läuft auch
  # bei einem weiteren Signal zu Ende (0.4.13, I-50)
  signale_vermerken
  printf 'khli-php56: FEHLER: %s\n' "$1" >&2 2>/dev/null || true
  # nach dem Zurückholen eines bisherigen Ordners in update oder uninstall (I-46, I-49): der Ordner ist
  # wieder da, der Dienst aber nicht unbedingt; nur solange das Ziel noch da ist (I-48)
  if [ "$ZURUECKGEHOLT" = 1 ] && [ -e "$ZIEL" ]; then printf 'khli-php56: Hinweis: der bisherige Ordner kam vorher aus dem Rest eines abgebrochenen Updates nach %s zurück; ob der Dienst läuft, zeigt "khli-php56 status"; "systemctl restart %s" startet ihn mit diesem Ordner wieder\n' "$ZIEL" "$DIENST" >&2 2>/dev/null || true; fi
  exit "${2:-1}"
}
datum() { date -u +%Y-%m-%dT%H:%M:%SZ; }
hilfe() { awk 'NR == 1 {next} /^# 0\.[0-9]+\.[0-9]+:/ {exit} /^#/ {sub(/^# ?/, ""); print; next} {exit}' "$SKRIPT"; }

fpm_laeuft() {
  local pid
  pid=$(cat "$PIDDATEI" 2>/dev/null) || return 1
  [[ "$pid" =~ ^[0-9]+$ ]] || return 1
  [ "$(readlink "/proc/$pid/exe" 2>/dev/null || true)" = "$ZIEL/sbin/$DIENST" ]
}

pools_da() { compgen -G "$ZIEL/etc/php-fpm.d/*.conf" > /dev/null; }

ohne_signale() {
  # führt einen Befehl aus, den HUP, INT und TERM nicht beenden (SIG_IGN erbt er); für die Schritte, die
  # nicht halb ausgeführt stehen bleiben dürfen (I-33)
  ( trap '' HUP INT TERM; exec "$@" )
}

dienst_befehl() {
  # service stop oder restart; während der Rücknahme taub für HUP, INT und TERM, sonst nicht, damit
  # Strg+C einen hängenden Dienststart abbrechen kann (I-39)
  if [ "$IN_RUECKNAHME" = 1 ]; then ohne_signale service "$DIENST" "$1"; else service "$DIENST" "$1"; fi
}

dienst_anhalten() {
  # KeyHelps Startskript erkennt den Prozess an seinem Programmpfad; deshalb vor jedem Tausch. Ab 0.4.16
  # Rückgabe 1, wenn der Dienst nach dem Anhalten noch läuft: gewartet wird bis zu zehn Sekunden nach der
  # Uhr (F-008); ab 0.4.17 auch, wenn das Startskript fehlt und der Dienst trotzdem läuft (G-07)
  if [ ! -x "/etc/init.d/$DIENST" ]; then
    fpm_laeuft || return 0
    meldung "Warnung: /etc/init.d/$DIENST fehlt, der Dienst läuft aber; über das Startskript lässt er sich nicht anhalten"
    return 1
  fi
  if ! test_stopp_scheitert; then dienst_befehl stop > /dev/null 2>&1 9>&- || true; fi
  local ende=$((SECONDS + 10))
  while fpm_laeuft; do
    [ "$SECONDS" -lt "$ende" ] || return 1
    sleep 1 || true
  done
  return 0
}

dienst_neu_starten() {
  # restart statt start: systemd führt den LSB-Dienst auch nach einem Absturz als "active (exited)",
  # ein start bliebe dann wirkungslos (E-0044); gewartet wird bis zu zehn Sekunden nach der Uhr, damit
  # ein Signal, das ein sleep beendet, die Wartezeit nicht verkürzt (I-36). Ohne Startskript ab 0.4.17
  # Rückgabe 1 statt 0: der Dienst läuft dann nicht (G-07)
  [ -x "/etc/init.d/$DIENST" ] || { meldung "Warnung: /etc/init.d/$DIENST fehlt; der Dienst lässt sich nicht starten"; return 1; }
  dienst_befehl restart > /dev/null 2>&1 9>&- || meldung "Warnung: service $DIENST restart endete mit einem Fehler"
  local ende=$((SECONDS + 10))
  while [ "$SECONDS" -lt "$ende" ]; do
    if fpm_laeuft; then return 0; fi
    sleep 1 || true
  done
  fpm_laeuft
}

fpm_beenden() {
  # beendet den Hauptprozess des Dienstes aus der PID-Datei, nur wenn er aus $ZIEL läuft (fpm_laeuft prüft
  # den Programmpfad); für die Rücknahme, wenn service stop nicht wirkte (0.4.17, G-08). Rückgabe 1, wenn
  # er nach zehn Sekunden noch läuft
  local pid
  fpm_laeuft || return 0
  pid=$(cat "$PIDDATEI" 2>/dev/null) || return 1
  meldung "beende den Hauptprozess $pid von $DIENST (aus $ZIEL)"
  kill -TERM "$pid" 2>/dev/null || true
  local ende=$((SECONDS + 10))
  while fpm_laeuft; do
    [ "$SECONDS" -lt "$ende" ] || return 1
    sleep 1 || true
  done
  return 0
}

signale_vermerken() {
  # während der Rücknahme beenden Signale nichts mehr, sie werden nur vermerkt (I-24); Kindprozesse
  # erben einen solchen Handler nicht
  trap 'SPAETES_SIGNAL=129' HUP
  trap 'SPAETES_SIGNAL=130' INT
  trap 'SPAETES_SIGNAL=141' PIPE
  trap 'SPAETES_SIGNAL=143' TERM
}

zuruecknehmen() {
  # hält fest, welches Signal während der Rücknahme kam; nur dieses darf den Exit-Code bestimmen, ein
  # Signal erst beim späteren Aufräumen nicht (0.4.12, I-44)
  local r=0
  zuruecknehmen_ablauf || r=$?
  if [ "$RUECKNAHME_LIEF" = 1 ]; then RUECKNAHME_SIGNAL=$SPAETES_SIGNAL; fi
  return "$r"
}

test_ruecknahme_scheitert() {
  # nur im Testmodus ohne KeyHelp: das Zurücklegen des bisherigen Ordners gilt als gescheitert (N40)
  { [ "$OHNE_KEYHELP" = 1 ] || [ "$(zustand_wert OHNE_KEYHELP)" = 1 ]; } && ! keyhelp_da && [ "${KHLI_TEST_RUECKNAHME:-}" = scheitern ]
}

test_ruecknahme_dienst_scheitert() {
  # nur im Testmodus ohne KeyHelp: der Dienst startet in der Rücknahme nicht wieder (0.4.16, F-007)
  { [ "$OHNE_KEYHELP" = 1 ] || [ "$(zustand_wert OHNE_KEYHELP)" = 1 ]; } && ! keyhelp_da && [ "${KHLI_TEST_RUECKNAHME:-}" = dienst ]
}

test_stopp_scheitert() {
  # nur im Testmodus ohne KeyHelp: service stop hält den Dienst nicht an (0.4.16, F-008); mit ruecknahme nur
  # in der Rücknahme (0.4.17, G-08)
  { [ "$OHNE_KEYHELP" = 1 ] || [ "$(zustand_wert OHNE_KEYHELP)" = 1 ]; } && ! keyhelp_da || return 1
  case "${KHLI_TEST_STOPP:-}" in
    scheitern) return 0 ;;
    ruecknahme) [ "$IN_RUECKNAHME" = 1 ] ;;
    *) return 1 ;;
  esac
}

test_apt_entfernt() {
  # nur im Testmodus ohne KeyHelp: der Plan von apt enthält eine Entfernung (0.4.16, F-009)
  { [ "$OHNE_KEYHELP" = 1 ] || [ "$(zustand_wert OHNE_KEYHELP)" = 1 ]; } && ! keyhelp_da && [ "${KHLI_TEST_APT:-}" = entfernen ]
}

test_eingabe_tauschen() {
  # nur im Testmodus ohne KeyHelp: nach der Prüfung werden die angegebenen Dateien (Originalpaket, ab 0.4.17
  # auch Ergänzungssatz) überschrieben; der Lauf muss mit seinen Kopien weitergehen (0.4.16, F-013)
  { [ "$OHNE_KEYHELP" = 1 ] || [ "$(zustand_wert OHNE_KEYHELP)" = 1 ]; } && ! keyhelp_da && [ "${KHLI_TEST_EINGABE:-}" = tauschen ] || return 0
  local f
  for f in "$OPT_ORIGINAL" "$OPT_ERGAENZUNG"; do
    [ -n "$f" ] || continue
    meldung "Testtausch: $f wird nach der Prüfung überschrieben"
    printf 'ausgetauscht\n' > "$f"
  done
  return 0
}

test_zweites_signal() {
  # nur im Testmodus ohne KeyHelp und nur im Tausch: schickt zu Beginn des Aufräumens ein weiteres Signal
  # an diesen Prozess, genau in das Fenster, in dem es bis 0.4.12 das Aufräumen abbrach (N44, I-50)
  [ -n "${KHLI_TEST_ZWEITES_SIGNAL:-}" ] && [ -n "$TAUSCH_PHASE" ] || return 0
  { [ "$OHNE_KEYHELP" = 1 ] || [ "$(zustand_wert OHNE_KEYHELP)" = 1 ]; } && ! keyhelp_da || return 0
  meldung "Testsignal $KHLI_TEST_ZWEITES_SIGNAL zu Beginn des Aufräumens"
  kill -s "$KHLI_TEST_ZWEITES_SIGNAL" $$ 2>/dev/null || true
}

zuruecknehmen_ablauf() {
  # Stand vor dem Tausch wiederherstellen (Ordner, Zustand, ELF-Tabelle) und den Dienst starten, wenn
  # er lief oder KeyHelp Pools angelegt hat; aus dem Fehlerzweig von update und aus der EXIT-Falle
  # (Abbruch durch Fehler unter set -e oder Signal). Die Phase bleibt gesetzt, bis alles zurück ist.
  # Rückgabe 1, wenn ein Ordner nicht zurückgelegt werden konnte; ARBEIT2 bleibt dann stehen.
  [ -n "$TAUSCH_PHASE" ] || return 0
  signale_vermerken
  IN_RUECKNAHME=1
  RUECKNAHME_LIEF=1
  if [ "$VORHER_FEHLTE" = 1 ]; then
    # es gab keinen bisherigen Ordner (I-28): der neu aufgebaute bleibt, der Zustand sagt fehlerhaft
    zustand_setzen STATUS=fehlerhaft || true
    meldung "kein bisheriger Ordner (er fehlte schon vor dem update); der neu aufgebaute bleibt, Zustand fehlerhaft; 'update --neu-aufbauen' oder 'uninstall'"
    TAUSCH_PHASE=""
    return 0
  fi
  local unvollstaendig=""
  if [ -n "$ARBEIT2" ] && [ -d "$ARBEIT2/alt" ]; then
    if [ -e "$ZIEL" ]; then
      # ab 0.4.17: wirkt service stop nicht, wird der Hauptprozess aus der PID-Datei beendet, solange er
      # noch aus $ZIEL läuft (nach dem Beiseitelegen erkennt ihn fpm_laeuft nicht mehr); läuft er dann
      # immer noch, bleibt der Arbeitsordner samt neuem Ordner zur Untersuchung (G-08)
      if ! dienst_anhalten && ! fpm_beenden; then
        meldung "Warnung: $DIENST läuft nach dem Anhalten noch (aus dem neuen Ordner)"
        unvollstaendig="$unvollstaendig Anhalten"
        ARBEIT2_BEHALTEN=1
      fi
      testabbruch ruecknahme
      if ! ohne_signale mv -T "$ZIEL" "$ARBEIT2/neu-fehlerhaft"; then
        meldung "Warnung: neuer Ordner lässt sich nicht beiseitelegen; bisheriger Ordner liegt in $ARBEIT2/alt"
        ruecknahme_gescheitert; return 1
      fi
    fi
    if test_ruecknahme_scheitert || ! ohne_signale mv -T "$ARBEIT2/alt" "$ZIEL"; then
      meldung "Warnung: bisheriger Ordner lässt sich nicht zurücklegen; er liegt in $ARBEIT2/alt"
      ruecknahme_gescheitert; return 1
    fi
  fi
  # ab 0.4.16 zählt jeder dieser Schritte: nur wenn alle gelingen, ist der bisherige Stand wiederhergestellt
  # (F-007); scheitert Zustand oder ELF-Tabelle, bleibt der Arbeitsordner mit ihren Sicherungen stehen
  if [ -n "$ARBEIT2" ] && [ -f "$ARBEIT2/zustand-alt.env" ]; then
    ohne_signale cp "$ARBEIT2/zustand-alt.env" "$ZUSTAND/zustand.env" || { unvollstaendig="$unvollstaendig Zustand"; ARBEIT2_BEHALTEN=1; }
  fi
  if [ -n "$ARBEIT2" ] && [ -f "$ARBEIT2/elf-alt.tsv" ]; then
    ohne_signale cp "$ARBEIT2/elf-alt.tsv" "$ZUSTAND/elf-aenderungen.tsv" || { unvollstaendig="$unvollstaendig ELF-Tabelle"; ARBEIT2_BEHALTEN=1; }
  fi
  # ab 0.4.17 auch Prüfwerkzeug und Cron-Datei, wenn werkzeug_einrichten sie in diesem Lauf schon ersetzt
  # hatte (F-014); was es neu angelegt hatte, wird entfernt
  if [ -n "$ARBEIT2" ] && [ -f "$ARBEIT2/werkzeug-alt" ]; then
    ohne_signale cp -a "$ARBEIT2/werkzeug-alt" "$WERKZEUG" || { unvollstaendig="$unvollstaendig Prüfwerkzeug"; ARBEIT2_BEHALTEN=1; }
  elif [ -n "$ARBEIT2" ] && [ -e "$ARBEIT2/werkzeug-neu" ]; then
    ohne_signale rm -f "$WERKZEUG" || unvollstaendig="$unvollstaendig Prüfwerkzeug"
  fi
  if [ -n "$ARBEIT2" ] && [ -f "$ARBEIT2/cron-alt" ]; then
    ohne_signale cp -a "$ARBEIT2/cron-alt" "$CRON" || { unvollstaendig="$unvollstaendig Cron-Datei"; ARBEIT2_BEHALTEN=1; }
  elif [ -n "$ARBEIT2" ] && [ -e "$ARBEIT2/cron-neu" ]; then
    ohne_signale rm -f "$CRON" || unvollstaendig="$unvollstaendig Cron-Datei"
  fi
  if [ "$LIEF" = 1 ] || pools_da; then
    if test_ruecknahme_dienst_scheitert || ! dienst_neu_starten; then
      meldung "Warnung: $DIENST startet auch mit dem bisherigen Ordner nicht; Abhilfe: systemctl restart $DIENST"
      unvollstaendig="$unvollstaendig Dienst"
    fi
  fi
  TAUSCH_PHASE=""
  if [ -n "$unvollstaendig" ]; then
    zustand_setzen STATUS=fehlerhaft || true
    meldung "bisheriger Ordner zurückgelegt, aber nicht vollständig wiederhergestellt:$unvollstaendig; Zustand fehlerhaft; 'khli-php56 check' zeigt den Stand, 'update --neu-aufbauen' baut neu auf"
    return 1
  fi
  meldung "bisheriger Stand wiederhergestellt"
  RUECKNAHME_OK=1
  return 0
}

ruecknahme_gescheitert() {
  # ein Ordner ließ sich nicht zurücklegen: ARBEIT2 bleibt stehen, der Zustand sagt fehlerhaft, und mit
  # dem Ordner, der jetzt am Ziel liegt, wird der Dienst wenigstens versucht (I-33)
  ARBEIT2=""
  TAUSCH_PHASE=""
  zustand_setzen STATUS=fehlerhaft || true
  if [ -e "$ZIEL" ] && { [ "$LIEF" = 1 ] || pools_da; }; then
    if dienst_neu_starten; then meldung "Dienst $DIENST läuft mit dem Ordner, der jetzt unter $ZIEL liegt"; else meldung "Warnung: Dienst $DIENST läuft nicht"; fi
  fi
  meldung "Zustand fehlerhaft; bitte prüfen ('khli-php56 check') und 'update --neu-aufbauen' ausführen"
}

aufraeumen() {
  local rc=$?
  test_zweites_signal
  signale_vermerken
  if [ -n "$TAUSCH_PHASE" ]; then
    meldung "Abbruch während des Tauschs (Exit $rc); der bisherige Stand kommt zurück"
    zuruecknehmen || true
  fi
  if [ -n "$ARBEIT" ]; then ohne_signale rm -rf "$ARBEIT"; fi
  if [ -n "$ARBEIT2" ] && [ -d "$ARBEIT2/alt" ] && [ "$TAUSCH_OK" != 1 ]; then
    # Sicherheitsnetz: ein bisheriger Ordner wird nur nach bestätigtem Tausch gelöscht (I-24)
    meldung "Warnung: der bisherige Ordner bleibt in $ARBEIT2/alt (Tausch nicht bestätigt)"
  elif [ -n "$ARBEIT2" ] && [ "$ARBEIT2_BEHALTEN" = 1 ]; then
    meldung "Warnung: der Arbeitsordner $ARBEIT2 bleibt zur Untersuchung (Sicherungen aus der Rücknahme, neuer Ordner unter neu-fehlerhaft)"
  elif [ -n "$ARBEIT2" ]; then
    ohne_signale rm -rf "$ARBEIT2"
  fi
  # Exit-Code (0.4.12, I-38, I-41, I-44): scheiterte eine Rücknahme mit bisherigem Ordner, immer 1, auch
  # wenn ein Signal den Lauf beendet hatte (129ff. heißt "bisheriger Stand zurück"); ein während einer
  # gelungenen Rücknahme vermerktes Signal bestimmt den Exit-Code, wenn der Lauf an einem Fehler
  # endete; ein Signal erst beim Aufräumen ändert ihn nie
  if [ "$RUECKNAHME_LIEF" = 1 ] && [ "$RUECKNAHME_OK" != 1 ] && [ "$VORHER_FEHLTE" != 1 ] && [ "$rc" != 1 ]; then
    meldung "die Rücknahme ist unvollständig (der Lauf endete mit Exit $rc); deshalb Exit 1"
    exit 1
  fi
  if [ "$RUECKNAHME_SIGNAL" != 0 ] && [ "$rc" -lt 128 ] && [ "$RUECKNAHME_OK" = 1 ] && [ "$rc" != "$RUECKNAHME_SIGNAL" ]; then exit "$RUECKNAHME_SIGNAL"; fi
  if [ "$SPAETES_SIGNAL" != 0 ] && [ "$SPAETES_SIGNAL" != "$RUECKNAHME_SIGNAL" ]; then meldung "Hinweis: ein Signal kam erst beim Aufräumen; der Exit-Code bleibt $rc"; fi
  return 0
}
trap aufraeumen EXIT
# Signale beenden das Skript über exit, damit die EXIT-Falle läuft; SIGPIPE ebenso, falls das tee des
# Protokolls doch endet: ohne Falle beendete es bash ohne Rücknahme (I-23). Vor dem exit schalten sie auf
# Vermerken um: ein zweites Signal kurz danach brach sonst die EXIT-Falle samt Rücknahme ab (0.4.13, I-50)
trap 'signale_vermerken; exit 129' HUP
trap 'signale_vermerken; exit 130' INT
trap 'signale_vermerken; exit 141' PIPE
trap 'signale_vermerken; exit 143' TERM

testabbruch() {
  # nur im Testmodus ohne KeyHelp: gezielter Abbruch an einer Stelle (khli-installer-negativ.sh).
  # KHLI_TEST_SIGNAL: TERM (Standard, nur an diesen Prozess), HUP-GRUPPE (nach einer Sekunde an die
  # ganze Prozessgruppe, wie beim Abbruch einer SSH-Sitzung mit Terminal; der Leser der Ausgabe kann
  # vorher enden) oder HUP-GRUPPE-WIEDERHOLT (zwei Sekunden lang alle 0,1 Sekunden im Hintergrund,
  # während der Lauf weitergeht, so dass auch Kindprozesse der Rücknahme getroffen werden)
  if { [ "$OHNE_KEYHELP" = 1 ] || [ "$(zustand_wert OHNE_KEYHELP)" = 1 ]; } && ! keyhelp_da && [ "${KHLI_TEST_ABBRUCH:-}" = "$1" ]; then
    meldung "Testabbruch an der Stelle $1"
    case "${KHLI_TEST_SIGNAL:-TERM}" in
      HUP-GRUPPE) sleep 1; kill -HUP 0; sleep 5 ;;
      HUP-GRUPPE-WIEDERHOLT) ( trap '' HUP; exec 9>&-; i=0; while [ $i -lt 20 ]; do sleep 0.1; kill -HUP 0 2>/dev/null; i=$((i + 1)); done ) & ;;
      *) kill -TERM $$; sleep 5 ;;
    esac
  fi
  return 0
}

test_pruefung_scheitert() {
  # nur im Testmodus ohne KeyHelp: update behandelt die Prüfung nach dem Tausch als gescheitert
  [ "$OHNE_KEYHELP" = 1 ] && ! keyhelp_da && [ "${KHLI_TEST_PRUEFUNG:-}" = scheitern ]
}

eindeutig() {
  # $1 Anfang, $2 Endung: ein Name, den es noch nicht gibt (Stempel nur auf die Sekunde; zwei Läufe in
  # derselben Sekunde überschrieben sonst die Sicherung des ersten, 0.4.12, I-47)
  local d="$1$2" n=1
  while [ -e "$d" ]; do n=$((n + 1)); d="$1-$n$2"; done
  printf '%s' "$d"
}

protokoll_start() {
  mkdir -p "$PROTOKOLL_DIR"
  chmod 750 "$PROTOKOLL_DIR"
  PROTOKOLL=$(eindeutig "$PROTOKOLL_DIR/$(date -u +%Y%m%dT%H%M%SZ)-$1" .log)
  # tee ohne die Sperre (fd 9), taub für HUP, INT und TERM und mit --output-error=warn: bricht die
  # Sitzung ab, schreibt es weiter ins Protokoll, statt das Skript über SIGPIPE mitzureißen (I-23)
  exec > >(exec 9>&-; trap '' HUP INT TERM; exec tee --output-error=warn -a "$PROTOKOLL") 2>&1
  meldung "Version $KHLI_VERSION, $1, Protokoll $PROTOKOLL"
}

sperren() {
  # exklusive Sperre; die Datei bleibt bestehen (in /run, also flüchtig), damit kein zweiter Lauf eine
  # neue Datei mit eigener Sperre anlegt
  exec 9>> "$SPERRE" || fehler "Sperrdatei $SPERRE lässt sich nicht anlegen" 1
  flock -n 9 || fehler "ein anderer Lauf von khli-php56 ist aktiv (Sperre $SPERRE)" 1
}

keyhelp_da() { [ -e /usr/bin/keyhelp ] || [ -d /home/keyhelp/www/keyhelp ]; }

voraussetzungen() {
  [ "$(id -u)" -eq 0 ] || fehler "nur als root" 4
  [ "$(uname -s)" = Linux ] || fehler "nur Linux" 4
  [ "$(dpkg --print-architecture)" = amd64 ] || fehler "nur amd64; der Ergänzungssatz ist für amd64 gebaut" 4
  local v
  v=$(cut -d. -f1 /etc/debian_version 2>/dev/null || true)
  [ "$v" = 13 ] || fehler "nur Debian 13 (gefunden: $(cat /etc/debian_version 2>/dev/null || echo unbekannt)); unter Debian 12 bietet KeyHelp PHP 5.6 selbst an" 4
  if keyhelp_da && [ "$OHNE_KEYHELP" = 1 ]; then fehler "--ohne-keyhelp nur für Tests ohne KeyHelp; hier ist KeyHelp installiert" 2; fi
  if ! keyhelp_da; then
    [ "$OHNE_KEYHELP" = 1 ] || fehler "KeyHelp nicht gefunden (/usr/bin/keyhelp); nur für KeyHelp-Server" 4
    meldung "Hinweis: ohne KeyHelp (--ohne-keyhelp), nur für Tests"
  fi
  if [ ! -d /opt/keyhelp/php ] && [ "$OHNE_KEYHELP" != 1 ]; then fehler "/opt/keyhelp/php fehlt; ist KeyHelp vollständig installiert?" 4; fi
  command -v apt-get > /dev/null || fehler "apt-get fehlt" 4
  command -v flock > /dev/null || fehler "flock fehlt (Paket util-linux)" 4
}

zustand_setzen() {
  # zustand_setzen SCHLUESSEL=wert ...: ersetzt oder ergänzt Zeilen in zustand.env
  local paar k
  touch "$ZUSTAND/zustand.env"
  for paar in "$@"; do
    k=${paar%%=*}
    # grep und mv taub für Signale: ein vorzeitig beendetes grep ließe sonst einen Zustand mit nur
    # einer Zeile zurück (I-36); Status 1 heißt nur „keine andere Zeile", ab 2 ist es ein Fehler
    local rc=0
    ohne_signale grep -v "^$k=" "$ZUSTAND/zustand.env" > "$ZUSTAND/.zustand.neu" || rc=$?
    if [ "$rc" -gt 1 ]; then meldung "Warnung: Zustand nicht geschrieben ($k)"; rm -f "$ZUSTAND/.zustand.neu"; return 1; fi
    printf '%s\n' "$paar" >> "$ZUSTAND/.zustand.neu"
    ohne_signale mv "$ZUSTAND/.zustand.neu" "$ZUSTAND/zustand.env"
  done
}
zustand_wert() { sed -n "s/^$1=//p" "$ZUSTAND/zustand.env" 2>/dev/null | tail -n 1; }

sha_pruefen() {
  local datei=$1 soll=$2 ist
  ist=$(sha256sum "$datei" | cut -c1-64)
  [ "$ist" = "$soll" ] || fehler "SHA-256 von $datei ist $ist, erwartet $soll" 3
}

re_maskieren() { printf '%s' "$1" | sed 's/[.[\*^$]/\\&/g'; }

archiv_pruefen() {
  # Nur Einträge unter dem erwarteten Ordner und seinen Elternordnern, keine absoluten Pfade, kein ..,
  # Verknüpfungen nur innerhalb des Ordners. Die Listen stehen in Variablen: grep -q am Ende einer
  # Pipe beendet sie früh, tar bekommt SIGPIPE, und unter pipefail gälte der Treffer als nicht gefunden.
  local datei=$1 wurzel=$2 komp=$3 erlaubt teil liste lang aussen art name ziel basis
  erlaubt="^$(re_maskieren "$wurzel")(/|\$)"
  teil=$wurzel
  while [[ "$teil" == */* ]]; do teil=${teil%/*}; erlaubt="$erlaubt|^$(re_maskieren "$teil")/?\$"; done
  liste=$(tar -t"$komp"f "$datei") || fehler "$datei ist kein lesbares Archiv" 3
  [ -n "$liste" ] || fehler "$datei ist leer" 3
  aussen=$(grep -vE "$erlaubt" <<< "$liste" || true)
  [ -z "$aussen" ] || fehler "$datei enthält Pfade außerhalb von $wurzel/, etwa $(head -n 1 <<< "$aussen")" 3
  if grep -qE '(^|/)\.\.(/|$)' <<< "$liste"; then fehler "$datei enthält Pfade mit .." 3; fi
  lang=$(tar -tv"$komp"f "$datei") || fehler "$datei ist kein lesbares Archiv" 3
  while IFS=$'\t' read -r art name ziel; do
    [ -n "$art" ] || continue
    case "$ziel" in /*) fehler "$datei: Verknüpfung $name zeigt auf den absoluten Pfad $ziel" 3 ;; esac
    # symbolische Verknüpfungen gelten relativ zu ihrem Ordner, harte relativ zur Archivwurzel
    if [ "$art" = l ]; then basis=/khli-pruefung/$(dirname "$name"); else basis=/khli-pruefung; fi
    case "$(realpath -m -s "$basis/$ziel")/" in
      "/khli-pruefung/$wurzel/"*) ;;
      *) fehler "$datei: Verknüpfung $name zeigt aus $wurzel/ hinaus ($ziel)" 3 ;;
    esac
  done < <(awk '/^[lh]/ { t = (substr($0, 1, 1) == "l") ? " -> " : " link to "; i = index($0, t); if (i == 0) next; n = split(substr($0, 1, i - 1), f, " "); print substr($0, 1, 1) "\t" f[n] "\t" substr($0, i + length(t)) }' <<< "$lang")
}

# installiert heißt: Zustand installed, gleich ob gewünscht (install) oder gehalten (hold)
paket_da() { [ "$(dpkg-query -W -f='${db:Status-Status}' "$1" 2>/dev/null || true)" = installed ]; }
installiert_liste() { dpkg-query -W -f='${db:Status-Status} ${Package}\n' | awk '$1 == "installed" {print $2}' | sort -u; }
manuell_liste() { apt-mark showmanual | sort -u; }
elf_runpath() { patchelf --print-rpath "$1"; }

lauf_pakete() {
  # Pakete, die der apt-Lauf mit der Kennung $1 laut /var/log/apt/history.log installiert hat, je Zeile
  # Name und "manuell" oder "auto" (apt markiert die ausdrücklich angeforderten als manuell)
  [ -r /var/log/apt/history.log ] || return 0
  awk -v k="Khli::Lauf=$1" '
    /^Start-Date:/ { eigen = 0 }
    /^Commandline:/ && index($0, k) { eigen = 1 }
    eigen && /^Install: / {
      s = substr($0, 10)
      n = split(s, t, /\), /)
      for (i = 1; i <= n; i++) {
        split(t[i], q, ":")
        print q[1], (index(t[i], "automatic") ? "auto" : "manuell")
      }
    }' /var/log/apt/history.log
}

pakete_installieren() {
  # Installiert fehlende Pakete. Die geplanten neuen Pakete und die Markierungen der ausdrücklich
  # angeforderten werden vor dem Lauf erfasst: bricht apt ab (KeyHelps Cron beendet ein lange
  # laufendes apt-get mit SIGTERM), kennt der Rückbau sie trotzdem (I-25). Als eigene zählen danach die
  # Pakete, die laut apt-Protokoll dieser Lauf installiert hat; was ein anderer Lauf (etwa KeyHelps
  # php-update) in der Wartezeit auf die Paketsperre installiert, bleibt fremd (I-26).
  local liste=$1 fehlt="" p plan geplant angefordert lauf eigen
  for p in $liste; do paket_da "$p" || fehlt="$fehlt $p"; done
  if [ -z "$fehlt" ]; then meldung "alle Laufzeitpakete vorhanden"; return 0; fi
  meldung "installiere aus Debian 13:$fehlt"
  "${APT[@]}" update 9>&-
  # shellcheck disable=SC2086
  plan=$("${APT[@]}" -s install --no-install-recommends $fehlt 9>&-) || fehler "apt kann$fehlt nicht installieren" 1
  # ab 0.4.16 entfernt die Installation nie ein Paket: ein Plan mit Entfernungen wird abgelehnt, bevor apt
  # etwas ändert, und der echte Lauf hat --no-remove; Pakete, die apt dabei anhebt, werden genannt (F-009)
  local entfernt angehoben
  entfernt=$(awk '/^Remv / {print $2}' <<< "$plan" | sort -u | tr '\n' ' ')
  if test_apt_entfernt; then entfernt="${entfernt}khli-testpaket "; fi
  [ -z "$entfernt" ] || fehler "apt würde für$fehlt diese Pakete entfernen: ${entfernt% }; nichts installiert, der Installer entfernt nie fremde Pakete" 1
  angehoben=$(awk '/^Inst / && $3 ~ /^\[/ {print $2}' <<< "$plan" | sort -u | tr '\n' ' ')
  [ -z "$angehoben" ] || meldung "Hinweis: apt hebt dabei vorhandene Pakete auf eine neuere Fassung: $angehoben"
  geplant=$(awk '/^Inst / && $3 !~ /^\[/ {print $2}' <<< "$plan" | sort -u)
  if [ -n "$geplant" ]; then printf '%s\n' "$geplant" >> "$ZUSTAND/pakete-geplant.txt"; fi
  sort -u -o "$ZUSTAND/pakete-geplant.txt" "$ZUSTAND/pakete-geplant.txt"
  # shellcheck disable=SC2086
  angefordert=$(printf '%s\n' $fehlt | sort -u | comm -12 - <(printf '%s\n' "$geplant"))
  if [ -n "$angefordert" ]; then printf '%s\n' "$angefordert" >> "$ZUSTAND/manuell-nachher.txt"; fi
  sort -u -o "$ZUSTAND/manuell-nachher.txt" "$ZUSTAND/manuell-nachher.txt"
  installiert_liste > "$ZUSTAND/.vorher"
  manuell_liste > "$ZUSTAND/.manuell-vorher-lauf"
  lauf="$(date -u +%Y%m%dT%H%M%SZ)-$$"
  # shellcheck disable=SC2086
  "${APT[@]}" -o "Khli::Lauf=$lauf" install -y --no-remove --no-install-recommends $fehlt 9>&-
  testabbruch nach_apt
  eigen=$(lauf_pakete "$lauf")
  if [ -n "$eigen" ]; then
    awk '{print $1}' <<< "$eigen" | sort -u > "$ZUSTAND/.eigen"
    installiert_liste | comm -13 "$ZUSTAND/.vorher" - | comm -12 - "$ZUSTAND/.eigen" >> "$ZUSTAND/pakete-neu.txt"
    printf '%s\n' "$geplant" | comm -23 - "$ZUSTAND/.eigen" | grep -v '^$' > "$ZUSTAND/.fremd-geplant" || true
    if [ -s "$ZUSTAND/.fremd-geplant" ]; then
      comm -23 "$ZUSTAND/pakete-geplant.txt" "$ZUSTAND/.fremd-geplant" > "$ZUSTAND/.liste"; mv "$ZUSTAND/.liste" "$ZUSTAND/pakete-geplant.txt"
      comm -23 "$ZUSTAND/manuell-nachher.txt" "$ZUSTAND/.fremd-geplant" > "$ZUSTAND/.liste"; mv "$ZUSTAND/.liste" "$ZUSTAND/manuell-nachher.txt"
      meldung "geplant, aber von einem anderen Lauf installiert, deshalb nicht als eigene geführt: $(tr '\n' ' ' < "$ZUSTAND/.fremd-geplant")"
    fi
    awk '$2 == "manuell" {print $1}' <<< "$eigen" >> "$ZUSTAND/manuell-nachher.txt"
  else
    # kein Eintrag im apt-Protokoll: wie bis 0.4.0 über den Vergleich vorher und nachher
    meldung "Hinweis: kein Eintrag dieses Laufs im apt-Protokoll; eigene Pakete über den Vergleich vorher und nachher"
    installiert_liste | comm -13 "$ZUSTAND/.vorher" - | comm -12 - <(printf '%s\n' "$geplant") >> "$ZUSTAND/pakete-neu.txt"
    manuell_liste | comm -13 "$ZUSTAND/.manuell-vorher-lauf" - | comm -12 - <(printf '%s\n' "$geplant") >> "$ZUSTAND/manuell-nachher.txt"
  fi
  sort -u -o "$ZUSTAND/pakete-neu.txt" "$ZUSTAND/pakete-neu.txt"
  sort -u -o "$ZUSTAND/manuell-nachher.txt" "$ZUSTAND/manuell-nachher.txt"
  rm -f "$ZUSTAND/.vorher" "$ZUSTAND/.manuell-vorher-lauf" "$ZUSTAND/.eigen" "$ZUSTAND/.fremd-geplant"
}

arbeitsordner_anlegen() {
  ARBEIT=$(mktemp -d /var/tmp/khli-php56.XXXXXX) || fehler "kein temporärer Ordner unter /var/tmp" 1
  : > "$ARBEIT/$KENNUNG"
}

arbeitsordner2_anlegen() {
  # auf demselben Dateisystem wie das Ziel, damit mv atomar ist
  ARBEIT2=$(mktemp -d /opt/keyhelp/php/.khli-arbeit.XXXXXX) || fehler "kein Arbeitsordner unter /opt/keyhelp/php" 1
  : > "$ARBEIT2/$KENNUNG"
}

eigener_arbeitsordner() {
  # nur Ordner mit genau dem Muster von mktemp, Besitzer root, keine Verknüpfung, und mit Kennung (ab
  # 0.3.1) oder, unter /opt/keyhelp/php, mit dem Aufbau eines Arbeitsordners von 0.3.0
  local d=$1
  [ -d "$d" ] && [ ! -L "$d" ] || return 1
  [ "$(stat -c %u "$d")" = 0 ] || return 1
  case "$d" in
    /var/tmp/khli-php56.??????) [ -f "$d/$KENNUNG" ] ;;
    /opt/keyhelp/php/.khli-arbeit.??????) [ -f "$d/$KENNUNG" ] || [ -d "$d/baum" ] || [ -d "$d/alt" ] ;;
    *) return 1 ;;
  esac
}

alte_arbeitsordner_entfernen() {
  # Reste abgebrochener Läufe; dieser Lauf hält die Sperre, also arbeitet kein anderer darin.
  # $1: zurueckholen (update): ein bisheriger Ordner kommt zurück, wenn das Ziel fehlt, und bleibt
  #     sonst stehen; vor_rueckbau (uninstall vor der Sicherung): ein bisheriger Ordner kommt zurück,
  #     wenn das Ziel fehlt, damit die Sicherung ihn erfasst, sonst bleibt alles für den Modus alles
  #     (0.4.10, I-40); ohne_zustand (install): ohne Zustand gehört ein Rest zu
  #     keiner Installation mehr und wird entfernt, nie zurückgelegt; alles (uninstall nach dem
  #     Entfernen des Ziels): auch bisherige Ordner werden entfernt (I-30)
  local modus=${1:-zurueckholen} d
  for d in /opt/keyhelp/php/.khli-arbeit.?????? /var/tmp/khli-php56.??????; do
    [ -e "$d" ] || continue
    [ "$d" = "$ARBEIT" ] && continue
    [ "$d" = "$ARBEIT2" ] && continue
    if ! eigener_arbeitsordner "$d"; then
      [ "$modus" = vor_rueckbau ] || meldung "Hinweis: $d sieht nicht wie ein eigener Arbeitsordner aus; nicht entfernt"
      continue
    fi
    if [ "$modus" = vor_rueckbau ]; then
      # seit dem Umbenennen zu alt.weg (0.4.7) ist ein Ordner alt nie halb gelöscht; zurück kommt höchstens
      # einer, weil danach das Ziel da ist
      if [ -d "$d/alt/keyhelp-setup" ] && [ ! -e "$ZIEL" ]; then
        meldung "Rest eines abgebrochenen Updates: $d/alt kommt für den Rückbau zurück nach $ZIEL, damit die Sicherung ihn erfasst"
        ohne_signale mv -T "$d/alt" "$ZIEL"
        ZURUECKGEHOLT=1
        # der Rest ohne den bisherigen Ordner: sofort entfernen wie bei zurueckholen; ohne Kennung (Reste
        # älterer Fassungen) erkennte ihn der Modus alles sonst nicht mehr (0.4.11)
        ohne_signale rm -rf "$d"
        meldung "Rest eines abgebrochenen Laufs entfernt: $d"
      fi
      continue
    fi
    if [ -d "$d/alt/keyhelp-setup" ] && [ "$modus" = zurueckholen ]; then
      if [ ! -e "$ZIEL" ]; then
        meldung "Rest eines abgebrochenen Updates: $d/alt kommt zurück nach $ZIEL"
        ohne_signale mv -T "$d/alt" "$ZIEL"
        # wie im Modus vor_rueckbau: eine spätere Ablehnung sagt das Zurücklegen (0.4.13, I-49)
        ZURUECKGEHOLT=1
      else
        meldung "Warnung: Rest eines abgebrochenen Updates mit bisherigem Ordner $d/alt; bleibt stehen, bis 'uninstall' ihn entfernt (ein 'update' holt ihn nur bei fehlendem Ziel zurück)"
        continue
      fi
    elif [ -d "$d/alt/keyhelp-setup" ]; then
      meldung "Rest eines abgebrochenen Updates mit bisherigem Ordner $d/alt wird entfernt ($([ "$modus" = alles ] && echo 'Rückbau' || echo 'kein Zustand mehr'))"
      # erst umbenennen: bricht das Löschen ab, gilt der Rest nicht mehr als bisheriger Ordner, den ein
      # späterer Lauf zurückholen könnte (I-37)
      ohne_signale mv -T "$d/alt" "$d/alt.weg"
    fi
    ohne_signale rm -rf "$d"
    meldung "Rest eines abgebrochenen Laufs entfernt: $d"
  done
}

eingaben_pruefen() {
  # $1 Originalpaket (leer: Download), $2 Ergänzungssatz (leer: neben dem Skript), $3 SHA-256 eines
  # anderen Ergänzungssatzes (leer: der fest eingetragene). Ändert nichts außer dem Arbeitsordner.
  local original=$1 ergaenzung=$2 erg_sha=$3 soll
  if [ -n "$original" ]; then
    [ -f "$original" ] || fehler "Originalpaket nicht gefunden: $original" 4
    # ab 0.4.16 zuerst in den eigenen Arbeitsordner (nur root) kopieren und nur die Kopie prüfen und
    # benutzen: liegt die Datei in einem Ordner, den andere beschreiben dürfen, könnte sie sonst zwischen
    # Prüfung und Entpacken getauscht werden (F-013)
    cp -- "$original" "$ARBEIT/$ORIGINAL_NAME" || fehler "Originalpaket lässt sich nicht nach $ARBEIT kopieren" 1
    original=$ARBEIT/$ORIGINAL_NAME
  else
    original=$ARBEIT/$ORIGINAL_NAME
    meldung "lade $ORIGINAL_URL"
    if command -v curl > /dev/null; then
      curl -fsS --proto =https --max-time 600 -o "$original" "$ORIGINAL_URL" || fehler "Download gescheitert: $ORIGINAL_URL" 1
    elif command -v wget > /dev/null; then
      wget -q --https-only -O "$original" "$ORIGINAL_URL" || fehler "Download gescheitert: $ORIGINAL_URL" 1
    else
      fehler "weder curl noch wget vorhanden; das Originalpaket mit --original angeben" 4
    fi
  fi
  sha_pruefen "$original" "$ORIGINAL_SHA256"
  archiv_pruefen "$original" "$PHP_VER" z
  meldung "Originalpaket geprüft: $ORIGINAL_NAME, SHA-256 $ORIGINAL_SHA256"
  if [ -z "$ergaenzung" ]; then
    ergaenzung=$hier/$ERGAENZUNG_NAME
    [ -f "$ergaenzung" ] || ergaenzung=$hier/ergaenzung/$ERGAENZUNG_NAME
  fi
  [ -f "$ergaenzung" ] || fehler "Ergänzungssatz nicht gefunden: $ergaenzung" 4
  # ebenso der Ergänzungssatz (0.4.16, F-013); der Name bleibt, ihn hält der Zustand fest
  cp -- "$ergaenzung" "$ARBEIT/$(basename -- "$ergaenzung")" || fehler "Ergänzungssatz lässt sich nicht nach $ARBEIT kopieren" 1
  ergaenzung=$ARBEIT/$(basename -- "$ergaenzung")
  # Der fest eingetragene SHA-256 gilt für den mitgelieferten Satz; ein anderer Satz nur mit
  # ausdrücklich angegebener Prüfsumme (Entwicklung, neue Bauten)
  soll=${erg_sha:-$ERGAENZUNG_SHA256}
  ERGAENZUNG_SHA_IST=$(sha256sum "$ergaenzung" | cut -c1-64)
  [ "$ERGAENZUNG_SHA_IST" = "$soll" ] || fehler "SHA-256 von $ergaenzung ist $ERGAENZUNG_SHA_IST, erwartet $soll" 3
  if command -v xz > /dev/null; then
    archiv_pruefen "$ergaenzung" lib/khli J
    ERG_ARCHIV_GEPRUEFT=1
  else
    meldung "xz fehlt noch; den Aufbau des Ergänzungssatzes prüft der Installer nach der Installation von xz-utils"
  fi
  meldung "Ergänzungssatz geprüft: $(basename "$ergaenzung"), SHA-256 $ERGAENZUNG_SHA_IST"
  ORIGINAL_DATEI=$original
  ERGAENZUNG_DATEI=$ergaenzung
}

ergaenzung_nachpruefen() {
  if [ "$ERG_ARCHIV_GEPRUEFT" = 0 ]; then archiv_pruefen "$ERGAENZUNG_DATEI" lib/khli J; ERG_ARCHIV_GEPRUEFT=1; fi
}

laufzeitpakete_installieren() {
  pakete_installieren "$PAKETE_BASIS"
  ergaenzung_nachpruefen
  local laufzeit
  laufzeit=$(tar -xJOf "$ERGAENZUNG_DATEI" lib/khli/khli/laufzeit-pakete.txt | tr '\n' ' ')
  [ -n "$laufzeit" ] || fehler "Ergänzungssatz ohne Paketliste lib/khli/khli/laufzeit-pakete.txt" 3
  pakete_installieren "$laufzeit $PAKETE_WIE_DEBIAN12"
}

baum_bauen() {
  # $1 Ordner, in dem $PHP_VER/ entsteht; $2 Tabelle der ELF-Änderungen
  local neu=$1 tsv=$2 e f vorher alt rp notiz
  mkdir -p "$neu"
  tar -xzf "$ORIGINAL_DATEI" -C "$neu"
  tar -xJf "$ERGAENZUNG_DATEI" -C "$neu/$PHP_VER"
  (cd "$neu/$PHP_VER" && sha256sum -c --quiet lib/khli/khli/MANIFEST.sha256) || fehler "Ergänzungssatz nach dem Entpacken beschädigt" 3
  : > "$tsv"
  for e in $PATCH_EXT; do
    f=$neu/$PHP_VER/$EXT/$e.so
    [ -f "$f" ] || fehler "$EXT/$e.so fehlt im Originalpaket" 1
    vorher=$(sha256sum "$f" | cut -c1-64)
    alt=$(elf_runpath "$f")
    rp=$RUNPATH_EXT${alt:+:$alt}
    notiz=$rp
    if [ "$e" = ssh2 ]; then
      # libssh2 aus Debian 12 unter eigenem soname; das libssh2.so.1 von Debian 13 lädt libcurl
      patchelf --replace-needed libssh2.so.1 libssh2-khli.so.1 "$f"
      notiz="$rp; NEEDED libssh2.so.1 -> libssh2-khli.so.1"
    fi
    patchelf --set-rpath "$rp" "$f"
    printf '%s\t%s\t%s\t%s\t%s\n' "$EXT/$e.so" "$vorher" "$(sha256sum "$f" | cut -c1-64)" "${alt:--}" "$notiz" >> "$tsv"
  done
  f=$neu/$PHP_VER/lib/icu/lib/libicuuc.so.69.1
  vorher=$(sha256sum "$f" | cut -c1-64)
  patchelf --set-rpath '$ORIGIN' "$f"
  printf '%s\t%s\t%s\t%s\t%s\n' lib/icu/lib/libicuuc.so.69.1 "$vorher" "$(sha256sum "$f" | cut -c1-64)" - '$ORIGIN' >> "$tsv"
}

keyhelp_install_sh() {
  # KeyHelps install.sh wie beim Wartungsjob php-update. Seine Pakete (libtidy58, libssh2-1t64,
  # libpq5) sind schon über die eigene Erfassung installiert; was in seinem kurzen Lauf neu dazukommt,
  # zählt ab 0.4.16 nicht mehr zur Installation (F-015).
  local rc=0 dazu
  installiert_liste > "$ZUSTAND/.vorher"
  meldung "führe KeyHelps $ZIEL/keyhelp-setup/install.sh aus"
  bash "$ZIEL/keyhelp-setup/install.sh" 9>&- || rc=$?
  # ab 0.4.16 gelten Pakete, die in diesem Fenster dazukommen, nicht mehr als eigene: es kann auch ein
  # anderer Lauf gewesen sein; uninstall lässt sie stehen, sie stehen nur in einer Liste (F-015)
  dazu=$(installiert_liste | comm -13 "$ZUSTAND/.vorher" - || true)
  if [ -n "$dazu" ]; then
    printf '%s\n' "$dazu" >> "$ZUSTAND/pakete-waehrend-install-sh.txt"
    meldung "Hinweis: während KeyHelps install.sh kamen Pakete dazu: $(tr '\n' ' ' <<< "$dazu"); sie gelten nicht als eigene, uninstall lässt sie stehen"
  fi
  rm -f "$ZUSTAND/.vorher"
  zustand_setzen "INSTALL_SH_EXIT=$rc"
  [ "$rc" -eq 0 ] || meldung "Warnung: KeyHelps install.sh endete mit $rc"
  return 0
}

herkunft() {
  # fehlt, eigen (mit Ergänzungssatz von khli-php56) oder fremd
  if [ ! -e "$ZIEL" ]; then echo fehlt
  elif [ -f "$ZIEL/lib/khli/khli/MANIFEST.sha256" ]; then echo eigen
  else echo fremd
  fi
}

sicherung_anlegen() {
  # etc/, config.ini und Protokolle des Interpreters als Archiv im Protokollordner (Modus 600)
  local anlass=$1 datei t teile=()
  [ -d "$ZIEL" ] || { meldung "keine Sicherung: $ZIEL fehlt"; return 0; }
  for t in etc keyhelp-setup/config.ini var/log; do [ -e "$ZIEL/$t" ] && teile+=("$t"); done
  [ ${#teile[@]} -gt 0 ] || return 0
  mkdir -p "$PROTOKOLL_DIR"
  chmod 750 "$PROTOKOLL_DIR"
  datei=$(eindeutig "$PROTOKOLL_DIR/sicherung-$(date -u +%Y%m%dT%H%M%SZ)-$anlass" .tar.gz)
  (umask 077 && tar -czf "$datei" -C "$ZIEL" "${teile[@]}") || fehler "Sicherung nach $datei gescheitert; nichts entfernt" 1
  meldung "Sicherung von ${teile[*]}: $datei"
}

uebernehmen() {
  # Was KeyHelp und das Panel im Ordner pflegen, kommt in den neuen Ordner: Pools, Zeitzone aus
  # install.sh, config.ini (Schalter des Panels) und die Protokolle
  local alt=$1 neu=$2
  mkdir -p "$neu/etc/php-fpm.d"
  if [ -d "$alt/etc/php-fpm.d" ]; then cp -a "$alt/etc/php-fpm.d/." "$neu/etc/php-fpm.d/"; fi
  if [ -f "$alt/etc/conf.d/30-timezone.ini" ]; then cp -a "$alt/etc/conf.d/30-timezone.ini" "$neu/etc/conf.d/"; fi
  if [ -f "$alt/keyhelp-setup/config.ini" ]; then cp -a "$alt/keyhelp-setup/config.ini" "$neu/keyhelp-setup/config.ini"; fi
  if [ -d "$alt/var/log" ]; then mkdir -p "$neu/var/log"; cp -a "$alt/var/log/." "$neu/var/log/"; fi
}

autoupdate_soll() {
  # der Inhalt, den die Datei $1 mit ausgeschaltetem Schalter haben soll, auf stdout (0.4.15)
  local f=$1
  if grep -Eq '^[[:space:]]*is_autoupdate_enabled[[:space:]]*=' "$f"; then
    sed -E 's/^([[:space:]]*is_autoupdate_enabled[[:space:]]*=[[:space:]]*).*/\1false/' "$f"
  else
    cat "$f"
    [ -z "$(tail -c 1 "$f")" ] || printf '\n'
    printf 'is_autoupdate_enabled = false\n'
  fi
}

autoupdate_noetig() {
  # 0, wenn autoupdate_aus an keyhelp-setup/config.ini im Ordner $1 etwas ändern würde; der leichte Zweig
  # von update sichert dann vorher (0.4.15, I-52)
  local f=$1/keyhelp-setup/config.ini
  [ -f "$f" ] || return 1
  ! autoupdate_soll "$f" | cmp -s - "$f"
}

autoupdate_aus() {
  # KeyHelps eigener Schalter in keyhelp-setup/config.ini (die Datei gibt KeyHelps install.sh dem Panel,
  # chown keyhelp): KeyHelp soll 5.6 nie selbst aktualisieren; für Debian 13 hat KeyHelp kein 5.6-Paket,
  # Aktualisierungen kommen über diesen Installer (0.4.14). Geändert wird nur diese eine Zeile; fehlt
  # sie, kommt sie ans Ende (auch in eine leere Datei), die übrigen Schalter bleiben, wie sie sind.
  # GNU sed -i übernimmt als root Besitzer und Rechte der bisherigen Datei.
  local f=$1/keyhelp-setup/config.ini
  autoupdate_noetig "$1" || return 0
  if grep -Eq '^[[:space:]]*is_autoupdate_enabled[[:space:]]*=' "$f"; then
    sed -i -E 's/^([[:space:]]*is_autoupdate_enabled[[:space:]]*=[[:space:]]*).*/\1false/' "$f"
  else
    [ -z "$(tail -c 1 "$f")" ] || printf '\n' >> "$f"
    printf 'is_autoupdate_enabled = false\n' >> "$f"
  fi
  meldung "KeyHelps automatisches Update für $PHP_VER ausgeschaltet (keyhelp-setup/config.ini: is_autoupdate_enabled = false)"
}

unterschiede_melden() {
  local d
  d=$(diff -rq "$1/etc" "$2/etc" 2>/dev/null | grep -v -e '/php-fpm.d' -e '30-timezone.ini' || true)
  [ -z "$d" ] || meldung "aus dem bisherigen etc/ nicht übernommen (steht in der Sicherung): $(tr '\n' ';' <<< "$d")"
}

zustand_migrieren() {
  # Zustand von 0.2.x und älter: geplante Pakete und Markierungen fehlen
  [ -f "$ZUSTAND/pakete-geplant.txt" ] || : > "$ZUSTAND/pakete-geplant.txt"
  [ -f "$ZUSTAND/pakete-neu.txt" ] || : > "$ZUSTAND/pakete-neu.txt"
  # ohne Stand von vorher gilt alles Installierte als vorher vorhanden: der Rückbau entfernt dann nichts
  [ -f "$ZUSTAND/pakete-vorher.txt" ] || installiert_liste > "$ZUSTAND/pakete-vorher.txt"
  if [ ! -f "$ZUSTAND/manuell-vorher.txt" ]; then
    # Annahme: die heute von Hand markierten unter den damals neuen Paketen hat die Installation markiert
    manuell_liste > "$ZUSTAND/manuell-nachher.txt"
    sort -u "$ZUSTAND/pakete-neu.txt" | comm -23 "$ZUSTAND/manuell-nachher.txt" - > "$ZUSTAND/manuell-vorher.txt"
    zustand_setzen "MIGRIERT_VON=$(zustand_wert KHLI_VERSION)" "MIGRIERT=$(datum)"
    meldung "Zustand von khli-php56 $(zustand_wert MIGRIERT_VON) übernommen; Annahme: die von Hand markierten unter den damals neuen Paketen hat die Installation markiert"
  fi
  [ -f "$ZUSTAND/manuell-nachher.txt" ] || cp "$ZUSTAND/manuell-vorher.txt" "$ZUSTAND/manuell-nachher.txt"
}

werkzeug_einrichten() {
  # Prüfwerkzeug für den Verwalter und tägliche Prüfung; beides entfernt der Rückbau. Während des Tauschs
  # eines update hält es ab 0.4.17 vorher fest, was es ersetzt, damit die Rücknahme es zurücklegt (F-014)
  local merken=0
  if [ -n "$TAUSCH_PHASE" ] && [ -n "$ARBEIT2" ] && [ -d "$ARBEIT2" ]; then merken=1; fi
  if [ -e "$WERKZEUG" ] && ! grep -q '^# khli-php56.sh - Version' "$WERKZEUG"; then
    meldung "Warnung: $WERKZEUG stammt nicht von khli-php56; nicht ersetzt, keine tägliche Prüfung"
    return 0
  fi
  if [ ! "$SKRIPT" -ef "$WERKZEUG" ]; then
    if [ "$merken" = 1 ]; then
      if [ -f "$WERKZEUG" ]; then cp -a "$WERKZEUG" "$ARBEIT2/werkzeug-alt"; else : > "$ARBEIT2/werkzeug-neu"; fi
    fi
    install -m 0755 "$SKRIPT" "$WERKZEUG.khli-neu"
    mv "$WERKZEUG.khli-neu" "$WERKZEUG"
  fi
  meldung "Prüfwerkzeug: $WERKZEUG (check, status, uninstall)"
  if [ ! -d /etc/cron.d ]; then
    meldung "Hinweis: /etc/cron.d fehlt (cron nicht installiert); keine tägliche Prüfung"
    return 0
  fi
  if [ -e "$CRON" ] && ! grep -q '^# khli-php56' "$CRON"; then
    meldung "Warnung: $CRON stammt nicht von khli-php56; nicht ersetzt"
    return 0
  fi
  if [ "$merken" = 1 ]; then
    if [ -f "$CRON" ]; then cp -a "$CRON" "$ARBEIT2/cron-alt"; else : > "$ARBEIT2/cron-neu"; fi
  fi
  printf '%s\n' "# khli-php56 $KHLI_VERSION: tägliche Prüfung von PHP $PHP_VER nach KeyHelps Wartungsjob php-update (6 bis 7 Uhr)." \
    "# Ausgabe nur bei Befunden; cron schickt sie an root. Entfernt mit 'khli-php56 uninstall'." \
    "MAILTO=root" "40 7 * * * root $WERKZEUG check --cron" > "$CRON.khli-neu"
  chmod 0644 "$CRON.khli-neu"
  mv "$CRON.khli-neu" "$CRON"
  meldung "tägliche Prüfung: $CRON (7:40 Uhr)"
}

werkzeug_entfernen() {
  if [ -f "$CRON" ] && grep -q '^# khli-php56' "$CRON"; then rm -f "$CRON"; fi
  if [ -f "$WERKZEUG" ] && grep -q '^# khli-php56.sh - Version' "$WERKZEUG"; then rm -f "$WERKZEUG"; fi
  return 0
}

OPT_ORIGINAL=""
OPT_ERGAENZUNG=""
OPT_ERG_SHA=""
OPT_N=0
optionen_eingaben() {
  # gemeinsame Optionen von install und update; die Zahl verbrauchter Argumente steht danach in OPT_N
  case "$1" in
    --original) [ $# -ge 2 ] || fehler "--original braucht eine Datei" 2; OPT_ORIGINAL=$2; OPT_N=2 ;;
    --ergaenzung) [ $# -ge 2 ] || fehler "--ergaenzung braucht eine Datei" 2; OPT_ERGAENZUNG=$2; OPT_N=2 ;;
    --ergaenzung-sha256) [ $# -ge 2 ] || fehler "--ergaenzung-sha256 braucht einen Wert" 2; OPT_ERG_SHA=$2; OPT_N=2 ;;
    --ohne-keyhelp) OHNE_KEYHELP=1; OPT_N=1 ;;
    *) OPT_N=0 ;;
  esac
}

install_befehl() {
  while [ $# -gt 0 ]; do
    optionen_eingaben "$@"
    [ "$OPT_N" -gt 0 ] || fehler "unbekannte Option $1" 2
    shift "$OPT_N"
  done
  voraussetzungen
  sperren
  if [ -f "$ZUSTAND/zustand.env" ]; then
    fehler "es gibt schon einen Zustand unter $ZUSTAND ($(grep '^STATUS=' "$ZUSTAND/zustand.env" || echo STATUS=?)); zum Aktualisieren 'update', zum Entfernen 'uninstall'" 1
  fi
  protokoll_start install
  [ ! -e "$ZIEL" ] || fehler "$ZIEL existiert und stammt nicht von khli-php56; nichts verändert" 5
  alte_arbeitsordner_entfernen ohne_zustand
  # 1. Eingaben prüfen, bevor irgendetwas verändert wird
  arbeitsordner_anlegen
  eingaben_pruefen "$OPT_ORIGINAL" "$OPT_ERGAENZUNG" "$OPT_ERG_SHA"
  test_eingabe_tauschen
  # 2. Ab hier ändert der Installer das System; der Zustand entsteht zuerst, damit 'uninstall' auch
  #    nach einem Abbruch aufräumen kann
  mkdir -p "$ZUSTAND"
  chmod 700 "$ZUSTAND"
  : > "$ZUSTAND/pakete-neu.txt"
  : > "$ZUSTAND/pakete-geplant.txt"
  installiert_liste > "$ZUSTAND/pakete-vorher.txt"
  manuell_liste > "$ZUSTAND/manuell-vorher.txt"
  cp "$ZUSTAND/manuell-vorher.txt" "$ZUSTAND/manuell-nachher.txt"
  zustand_setzen "KHLI_VERSION=$KHLI_VERSION" STATUS=begonnen "BEGONNEN=$(datum)" "OHNE_KEYHELP=$OHNE_KEYHELP"
  if [ ! -d /opt/keyhelp/php ]; then
    # nur im Testmodus (voraussetzungen lässt es sonst nicht zu)
    local kh_neu=0
    [ -d /opt/keyhelp ] || kh_neu=1
    mkdir -p /opt/keyhelp/php
    echo /opt/keyhelp/php >> "$ZUSTAND/ordner-neu.txt"
    if [ "$kh_neu" = 1 ]; then echo /opt/keyhelp >> "$ZUSTAND/ordner-neu.txt"; fi
  fi
  arbeitsordner2_anlegen
  # 3. Laufzeitpakete, 4. Zusammenbau, 5. an den Zielort und KeyHelps install.sh
  laufzeitpakete_installieren
  baum_bauen "$ARBEIT2/baum" "$ZUSTAND/elf-aenderungen.tsv"
  autoupdate_aus "$ARBEIT2/baum/$PHP_VER"
  mv -T "$ARBEIT2/baum/$PHP_VER" "$ZIEL"
  zustand_setzen STATUS=entpackt "ORIGINAL_NAME=$ORIGINAL_NAME" "ORIGINAL_SHA256=$ORIGINAL_SHA256" \
    "ERGAENZUNG=$(basename "$ERGAENZUNG_DATEI")" "ERGAENZUNG_SHA256=$ERGAENZUNG_SHA_IST"
  keyhelp_install_sh
  werkzeug_einrichten
  zustand_setzen STATUS=installiert "INSTALLIERT=$(datum)"
  # 6. Prüfung
  if check_befehl --still && [ "$(zustand_wert INSTALL_SH_EXIT)" = 0 ]; then
    module_merken frisch
    meldung "Installation abgeschlossen: PHP $("$ZIEL/bin/php" -r 'echo PHP_VERSION;' 2>/dev/null)"
    return 0
  fi
  zustand_setzen STATUS=fehlerhaft
  fehler "Installation abgeschlossen, aber nicht fehlerfrei (siehe oben); 'khli-php56.sh uninstall' stellt den vorherigen Zustand her" 1
}

update_befehl() {
  local neu_aufbauen=0 trotz_fremd=0 aelter=0
  while [ $# -gt 0 ]; do
    optionen_eingaben "$@"
    if [ "$OPT_N" -gt 0 ]; then shift "$OPT_N"; continue; fi
    case "$1" in
      --neu-aufbauen) neu_aufbauen=1 ;;
      --trotz-fremdem-ordner) trotz_fremd=1 ;;
      --aelter-erlauben) aelter=1 ;;
      *) fehler "unbekannte Option $1" 2 ;;
    esac
    shift
  done
  if [ "$OHNE_KEYHELP" != 1 ] && [ "$(zustand_wert OHNE_KEYHELP)" = 1 ]; then
    # Zustand aus einem Test ohne KeyHelp: mit KeyHelp gilt er nicht mehr (I-31), ohne KeyHelp weiter
    if keyhelp_da; then HINWEIS_OHNE_KEYHELP=1; else OHNE_KEYHELP=1; fi
  fi
  voraussetzungen
  sperren
  [ -f "$ZUSTAND/zustand.env" ] || fehler "kein Zustand unter $ZUSTAND; zuerst 'khli-php56.sh install'" 1
  local status h
  status=$(zustand_wert STATUS)
  case "$status" in
    installiert|fehlerhaft) ;;
    *) fehler "Zustand '$status': ein früherer Lauf wurde nicht abgeschlossen; erst 'uninstall', dann 'install'" 1 ;;
  esac
  if [ "$(zustand_wert RUECKBAU)" = begonnen ]; then
    fehler "ein früherer uninstall wurde abgebrochen (RUECKBAU=begonnen); erst 'uninstall' wiederholen, dann 'install'" 1
  fi
  # ab 0.4.16 prüft update selbst und unter der Sperre, ob es eine ältere Fassung über eine neuere legt (F-004)
  local inst_version
  inst_version=$(zustand_wert KHLI_VERSION)
  if [ -n "$inst_version" ] && [ "$(printf '%s\n%s\n' "$inst_version" "$KHLI_VERSION" | sort -V | tail -n 1)" != "$KHLI_VERSION" ]; then
    [ "$aelter" = 1 ] || fehler "installiert ist khli-php56 $inst_version, diese Fassung $KHLI_VERSION ist älter; nichts verändert (--aelter-erlauben spielt sie trotzdem ein)" 5
  fi
  protokoll_start update
  if [ -n "$inst_version" ] && [ "$aelter" = 1 ] && [ "$inst_version" != "$KHLI_VERSION" ] && [ "$(printf '%s\n%s\n' "$inst_version" "$KHLI_VERSION" | sort -V | tail -n 1)" != "$KHLI_VERSION" ]; then
    meldung "Warnung: installiert ist $inst_version, eingespielt wird die ältere Fassung $KHLI_VERSION (--aelter-erlauben)"
  fi
  if [ "$HINWEIS_OHNE_KEYHELP" = 1 ]; then meldung "Hinweis: der Zustand stammt aus einem Test ohne KeyHelp; KeyHelp ist jetzt da, update läuft mit KeyHelp"; fi
  alte_arbeitsordner_entfernen zurueckholen
  h=$(herkunft)
  case "$h" in
    fremd) [ "$trotz_fremd" = 1 ] || fehler "$ZIEL enthält den Ergänzungssatz von khli-php56 nicht (von KeyHelp ersetzt?); $([ "$ZURUECKGEHOLT" = 1 ] && echo 'außer dem Zurücklegen aus dem Rest nichts verändert' || echo 'nichts verändert'). --trotz-fremdem-ordner ersetzt ihn (mit Sicherung)" 5 ;;
    fehlt) meldung "$ZIEL fehlt; update baut ihn neu auf"; VORHER_FEHLTE=1 ;;
  esac
  arbeitsordner_anlegen
  eingaben_pruefen "$OPT_ORIGINAL" "$OPT_ERGAENZUNG" "$OPT_ERG_SHA"
  test_eingabe_tauschen
  zustand_migrieren
  zustand_setzen "OHNE_KEYHELP=$OHNE_KEYHELP"
  if [ "$h" = eigen ] && [ "$neu_aufbauen" = 0 ] && [ "$status" = installiert ] \
     && [ "$(zustand_wert ORIGINAL_SHA256)" = "$ORIGINAL_SHA256" ] \
     && [ "$(zustand_wert ERGAENZUNG_SHA256)" = "$ERGAENZUNG_SHA_IST" ] && check_befehl --still; then
    # auch hier wird jede Änderung vorher gesichert (0.4.15, I-52)
    if autoupdate_noetig "$ZIEL"; then sicherung_anlegen update; fi
    autoupdate_aus "$ZIEL"
    werkzeug_einrichten
    zustand_setzen "KHLI_VERSION=$KHLI_VERSION" "AKTUALISIERT=$(datum)"
    # ab 0.4.17 keine Modulliste aus dem leichten Zweig: der Ordner kann Module aus eigenen ini-Dateien
    # laden, die ein späteres update nicht übernimmt (G-01)
    meldung "Interpreter unverändert (Originalpaket und Ergänzungssatz wie installiert, check in Ordnung); Werkzeug und Zustand erneuert; --neu-aufbauen baut ihn trotzdem neu auf"
    if [ ! -f "$ZUSTAND/module.txt" ]; then meldung "Hinweis: noch keine Modulliste für check; sie entsteht beim nächsten Aufbau aus dem Originalarchiv (update --neu-aufbauen)"; fi
    return 0
  fi
  arbeitsordner2_anlegen
  cp "$ZUSTAND/zustand.env" "$ARBEIT2/zustand-alt.env"
  if [ -f "$ZUSTAND/elf-aenderungen.tsv" ]; then cp "$ZUSTAND/elf-aenderungen.tsv" "$ARBEIT2/elf-alt.tsv"; fi
  laufzeitpakete_installieren
  baum_bauen "$ARBEIT2/baum" "$ARBEIT2/elf-aenderungen.tsv"
  local neu=$ARBEIT2/baum/$PHP_VER
  if fpm_laeuft; then LIEF=1; fi
  if [ "$h" != fehlt ]; then
    sicherung_anlegen update
    # ab hier nimmt die EXIT-Falle bei jedem Abbruch den Tausch zurück und startet den Dienst wieder
    TAUSCH_PHASE=angehalten
    if ! dienst_anhalten; then
      # ab 0.4.16 kein Tausch, solange der bisherige Dienst noch läuft: der Ordner ist unverändert am
      # Ziel, sein Dienst läuft weiter (F-008)
      TAUSCH_PHASE=""
      fehler "Dienst $DIENST ließ sich nicht anhalten; nichts getauscht, der bisherige Interpreter läuft weiter (Protokoll $PROTOKOLL)" 1
    fi
    testabbruch angehalten
    uebernehmen "$ZIEL" "$neu"
    mv -T "$ZIEL" "$ARBEIT2/alt"
  fi
  autoupdate_aus "$neu"
  TAUSCH_PHASE=getauscht
  mv -T "$neu" "$ZIEL"
  testabbruch getauscht
  cp "$ARBEIT2/elf-aenderungen.tsv" "$ZUSTAND/elf-aenderungen.tsv"
  zustand_setzen STATUS=installiert "ORIGINAL_NAME=$ORIGINAL_NAME" "ORIGINAL_SHA256=$ORIGINAL_SHA256" \
    "ERGAENZUNG=$(basename "$ERGAENZUNG_DATEI")" "ERGAENZUNG_SHA256=$ERGAENZUNG_SHA_IST"
  local dienst_ok=1
  if pools_da; then dienst_neu_starten || dienst_ok=0; fi
  keyhelp_install_sh
  testabbruch nach_install_sh
  if [ "$dienst_ok" = 1 ] && ! test_pruefung_scheitert && check_befehl --still && [ "$(zustand_wert INSTALL_SH_EXIT)" = 0 ]; then
    # ab 0.4.16 erst Werkzeug, Fassung und Modulliste, dann gilt der Tausch als bestätigt; bricht der Lauf
    # dabei ab, nimmt die EXIT-Falle den Tausch zurück, ab 0.4.17 samt Werkzeug und Cron-Datei (F-014).
    # Eine nicht geschriebene Modulliste oder ein fremdes Werkzeug sind nur Warnungen
    werkzeug_einrichten
    testabbruch nach_werkzeug
    zustand_setzen "KHLI_VERSION=$KHLI_VERSION" "AKTUALISIERT=$(datum)"
    module_merken frisch
    TAUSCH_OK=1
    TAUSCH_PHASE=""
    if [ -d "$ARBEIT2/alt" ]; then unterschiede_melden "$ARBEIT2/alt" "$ZIEL"; fi
    meldung "update abgeschlossen: PHP $("$ZIEL/bin/php" -r 'echo PHP_VERSION;' 2>/dev/null); Dienst $([ "$LIEF" = 1 ] && echo 'lief vorher' || echo 'lief vorher nicht')$(pools_da && fpm_laeuft && echo ', läuft jetzt')"
    return 0
  fi
  if [ -d "$ARBEIT2/alt" ]; then
    meldung "Prüfung nach dem Tausch gescheitert; der bisherige Ordner kommt zurück"
    if zuruecknehmen; then
      if [ "$RUECKNAHME_SIGNAL" != 0 ]; then meldung "während der Rücknahme kam ein Signal; es beendet den Lauf jetzt (Exit $RUECKNAHME_SIGNAL)"; fi
      fehler "update zurückgenommen; der bisherige Interpreter ist wieder aktiv (Protokoll $PROTOKOLL)" "$([ "$RUECKNAHME_SIGNAL" != 0 ] && echo "$RUECKNAHME_SIGNAL" || echo 1)"
    fi
    # nach gescheiterter Rücknahme immer Exit 1, auch wenn ein Signal kam: 129ff. heißt "bisheriger Stand
    # zurück" (0.4.10, I-41)
    if [ "$RUECKNAHME_SIGNAL" != 0 ]; then meldung "während der Rücknahme kam ein Signal (Exit $RUECKNAHME_SIGNAL); die Rücknahme ist unvollständig, deshalb Exit 1"; fi
    fehler "update gescheitert und Rücknahme unvollständig, siehe die Warnungen oben (Protokoll $PROTOKOLL)" 1
  fi
  TAUSCH_PHASE=""
  zustand_setzen STATUS=fehlerhaft
  fehler "update abgeschlossen, aber die Prüfung meldet Befunde (siehe oben)" 1
}

module_merken() {
  # frisch (install und voller Zweig von update, nach erfolgreicher Prüfung): module.txt hält fest, welche
  # Module php -m nach einem Aufbau aus dem Originalarchiv meldet, mit dem SHA-256 des Originalpakets in der
  # ersten Zeile; check vergleicht damit, solange das Originalpaket dasselbe ist (0.4.16, F-006). Eine
  # bisherige module-ohne.txt entfällt, weil der neue Ordner wieder die Einstellungen des Originals hat.
  # annehmen (check --module-merken): Module aus module.txt, die jetzt fehlen, gelten als gewollt
  # abgeschaltet (module-ohne.txt). Module aus eigenen ini-Dateien kommen so nie in die Liste; update
  # übernimmt solche Dateien nicht, und sie hielten sonst jedes update auf (0.4.17, G-01).
  # Scheitert es, bleibt die bisherige Liste, und es gibt nur eine Warnung
  local modus=$1 liste
  [ -d "$ZUSTAND" ] || return 0
  liste=$("$ZIEL/bin/php" -m 2>/dev/null) || { meldung "Warnung: php -m scheitert, Modulliste nicht festgehalten"; return 0; }
  liste=$(grep -vE '^\[|^$' <<< "$liste" | LC_ALL=C sort -u || true)
  if [ "$modus" = frisch ]; then
    if { printf '# original %s\n' "$(zustand_wert ORIGINAL_SHA256)"; printf '%s\n' "$liste"; } > "$ZUSTAND/module.txt.neu" 2> /dev/null \
       && mv "$ZUSTAND/module.txt.neu" "$ZUSTAND/module.txt"; then
      rm -f "$ZUSTAND/module-ohne.txt"
    else
      rm -f "$ZUSTAND/module.txt.neu"
      meldung "Warnung: Modulliste nicht geschrieben"
    fi
    return 0
  fi
  if [ ! -f "$ZUSTAND/module.txt" ] || [ "$(sed -n '1s/^# original //p' "$ZUSTAND/module.txt")" != "$(zustand_wert ORIGINAL_SHA256)" ]; then
    meldung "check: noch keine Modulliste zu diesem Originalpaket; sie entsteht beim nächsten Aufbau aus dem Originalarchiv (update --neu-aufbauen)"
    return 0
  fi
  if grep -v '^#' "$ZUSTAND/module.txt" | LC_ALL=C comm -23 - <(printf '%s\n' "$liste") > "$ZUSTAND/module-ohne.txt.neu" 2> /dev/null \
     && mv "$ZUSTAND/module-ohne.txt.neu" "$ZUSTAND/module-ohne.txt"; then
    meldung "check: Modulliste übernommen; als gewollt abgeschaltet gelten: $(if [ -s "$ZUSTAND/module-ohne.txt" ]; then tr '\n' ' ' < "$ZUSTAND/module-ohne.txt"; else echo keine; fi)"
  else
    rm -f "$ZUSTAND/module-ohne.txt.neu"
    meldung "Warnung: Liste der abgeschalteten Module nicht geschrieben"
  fi
  return 0
}

check_befehl() {
  local modus=normal
  case "${1:-}" in
    "") ;;
    --still) modus=still ;;
    --cron) modus=cron ;;
    --module-merken) modus=merken ;;
    *) fehler "unbekannte Option $1" 2 ;;
  esac
  [ "$(id -u)" -eq 0 ] || fehler "nur als root" 4
  if [ "$modus" = merken ]; then
    # Module, die gegenüber dem letzten Aufbau jetzt fehlen, gelten als gewollt abgeschaltet, etwa nach
    # einer bewussten Änderung an etc/conf.d (ab 0.4.17 kommt kein Modul mehr dazu, G-01)
    [ -f "$ZUSTAND/zustand.env" ] || fehler "kein Zustand unter $ZUSTAND" 1
    module_merken annehmen
  fi
  if [ "$modus" = cron ]; then
    # während eines Laufs von install, update oder uninstall nichts melden (keine Scheinbefunde)
    if [ -e "$SPERRE" ]; then
      exec 8< "$SPERRE"
      flock -s -n 8 || exit 0
    fi
    # nur Befunde ausgeben; cron schickt sie an root, dazu ein Eintrag im Systemprotokoll
    local aus rc=0
    aus=$(check_befehl --still 2>&1) || rc=$?
    [ "$rc" -ne 0 ] || return 0
    printf 'khli-php56 %s: die tägliche Prüfung von PHP %s meldet Befunde\n%s\n' "$KHLI_VERSION" "$PHP_VER" "$aus"
    # Hinweise sind keine Befunde: sie stehen in der Mail, aber nicht als Warnung im Systemprotokoll (0.4.15)
    grep 'check:' <<< "$aus" | grep -v 'check: Hinweis:' | logger -t khli-php56 -p daemon.warning 2>/dev/null || true
    exit 1
  fi
  local befunde=0
  if [ ! -x "$ZIEL/bin/php" ]; then
    meldung "check: $ZIEL/bin/php fehlt (Interpreter entfernt?)"
    [ "$modus" = still ] && return 1
    exit 1
  fi
  if [ ! -f "$ZUSTAND/zustand.env" ]; then
    meldung "check: kein Zustand unter $ZUSTAND (nicht mit khli-php56 installiert?)"; befunde=$((befunde + 1))
  elif [ "$(zustand_wert STATUS)" != installiert ]; then
    meldung "check: Zustand $(zustand_wert STATUS), ein Lauf wurde nicht fehlerfrei abgeschlossen"; befunde=$((befunde + 1))
  fi
  if [ -f "$ZIEL/lib/khli/khli/MANIFEST.sha256" ]; then
    if (cd "$ZIEL" && sha256sum -c --quiet lib/khli/khli/MANIFEST.sha256); then meldung "check: Ergänzungssatz unverändert"; else meldung "check: Ergänzungssatz verändert"; befunde=$((befunde + 1)); fi
  else
    meldung "check: lib/khli fehlt (Interpreter von KeyHelp ersetzt?)"; befunde=$((befunde + 1))
  fi
  if [ -f "$ZUSTAND/elf-aenderungen.tsv" ]; then
    local datei alt neu rest
    while IFS=$'\t' read -r datei alt neu rest; do
      [ "$(sha256sum "$ZIEL/$datei" 2>/dev/null | cut -c1-64 || true)" = "$neu" ] || { meldung "check: $datei weicht vom installierten Stand ab"; befunde=$((befunde + 1)); }
    done < "$ZUSTAND/elf-aenderungen.tsv"
  fi
  local f fehlt lout lrc
  # Die übrigen ICU-Bibliotheken finden einander nur über den RUNPATH von intl.so, schon im
  # Original unter Debian 12; geprüft wird deshalb intl.so selbst und die geänderte libicuuc.
  for f in "$ZIEL"/bin/php "$ZIEL"/bin/php-cgi "$ZIEL"/bin/phpdbg "$ZIEL/sbin/$DIENST" "$ZIEL"/$EXT/*.so "$ZIEL"/lib/icu/lib/libicuuc.so.69.1 "$ZIEL"/lib/khli/lib/*.so.*; do
    [ -L "$f" ] && continue
    [ -e "$f" ] || { meldung "check: ${f#"$ZIEL"/} fehlt"; befunde=$((befunde + 1)); continue; }
    # ldd endet auch bei fehlenden Bibliotheken mit 0 und nennt sie; ab 0.4.16 zählt zusätzlich sein
    # Exit-Code, etwa bei einer beschädigten Datei, die gar kein ELF mehr ist (F-006)
    lrc=0
    lout=$(ldd "$f" 2>&1) || lrc=$?
    fehlt=$(awk '/not found/ {print $1}' <<< "$lout" | tr '\n' ' ' || true)
    if [ -n "$fehlt" ]; then meldung "check: ${f#"$ZIEL"/} findet nicht: $fehlt"; befunde=$((befunde + 1))
    elif [ "$lrc" -ne 0 ]; then meldung "check: ldd scheitert an ${f#"$ZIEL"/} (Exit $lrc): $(head -n 1 <<< "$lout")"; befunde=$((befunde + 1)); fi
  done
  # php -m: ab 0.4.16 zählt der Exit-Code, die Grundmodule müssen da sein, und gegenüber dem letzten Aufbau
  # (module.txt im Zustand, gleiches Originalpaket) darf kein Modul fehlen, außer es ist als gewollt
  # abgeschaltet festgehalten (module-ohne.txt, ab 0.4.17) (F-006, G-01)
  local warn mrc=0 liste module kern="" fehlen="" m
  warn=$("$ZIEL/bin/php" -m 2>&1 >/dev/null) || mrc=$?
  liste=$("$ZIEL/bin/php" -m 2>/dev/null || true)
  module=$(grep -vE '^\[|^$' <<< "$liste" | LC_ALL=C sort -u || true)
  if [ "$mrc" -ne 0 ]; then
    meldung "check: php -m endet mit Exit $mrc$([ -n "$warn" ] && printf ': %s' "$(head -c 300 <<< "$warn" | tr '\n' ' ')")"; befunde=$((befunde + 1))
  elif grep -qiE 'warning|error|failed' <<< "$warn"; then
    meldung "check: php -m meldet: $(grep -iE 'warning|error|failed' <<< "$warn" | head -n 3 | tr '\n' ' ')"; befunde=$((befunde + 1))
  else
    for m in Core date pcre Reflection SPL standard; do grep -qxF "$m" <<< "$module" || kern="$kern $m"; done
    if [ -n "$kern" ]; then meldung "check: php -m nennt die Grundmodule nicht:$kern"; befunde=$((befunde + 1)); fi
    if [ -f "$ZUSTAND/module.txt" ] && [ "$(sed -n '1s/^# original //p' "$ZUSTAND/module.txt")" = "$(zustand_wert ORIGINAL_SHA256)" ]; then
      fehlen=$(grep -v '^#' "$ZUSTAND/module.txt" | LC_ALL=C comm -23 - <(LC_ALL=C sort -u "$ZUSTAND/module-ohne.txt" 2>/dev/null || true) | LC_ALL=C comm -23 - <(printf '%s\n' "$module") | tr '\n' ' ' || true)
      if [ -n "$fehlen" ]; then meldung "check: gegenüber dem letzten Aufbau fehlen Module: ${fehlen% }; ist das gewollt, hält 'khli-php56 check --module-merken' sie als abgeschaltet fest"; befunde=$((befunde + 1)); fi
    fi
    if [ -z "$kern" ] && [ -z "$fehlen" ]; then meldung "check: php -m ohne Startfehler, $(grep -c . <<< "$module" || true) Module"; fi
  fi
  local fpm andere
  fpm=$("$ZIEL/sbin/$DIENST" -t --fpm-config "$ZIEL/etc/php-fpm.conf" 2>&1 || true)
  andere=$(grep -v -e 'No pool defined' -e 'failed to post process' -e 'FPM initialization failed' -e 'Failed loading' <<< "$fpm" || true)
  if grep -q 'test is successful' <<< "$fpm"; then
    meldung "check: FPM-Konfiguration in Ordnung"
  elif grep -q 'No pool defined' <<< "$fpm" && ! grep -q 'ERROR' <<< "$andere"; then
    meldung "check: FPM-Konfiguration ohne Pools (wie unter Debian 12, solange keine Domain PHP $PHP_VER nutzt)"
  else
    meldung "check: FPM-Konfiguration: $fpm"; befunde=$((befunde + 1))
  fi
  # KeyHelps automatisches Update (ab 0.4.14): nur ein Hinweis, kein Befund; es gilt wie bei PHPs INI-Leser
  # die letzte Zeile mit dem Schlüssel, aus sind false, off, no, none, null, 0 und ein leerer Wert, ab
  # 0.4.15 auch mit einem Kommentar dahinter; fehlt die Datei, sagt check auch das (0.4.15, I-54)
  local cini=$ZIEL/keyhelp-setup/config.ini zeile
  if [ -f "$cini" ]; then
    zeile=$(grep -E '^[[:space:]]*is_autoupdate_enabled[[:space:]]*=' "$cini" | tail -n 1 || true)
    if ! grep -Eqi '^[[:space:]]*is_autoupdate_enabled[[:space:]]*=[[:space:]]*(false|off|no|none|null|0)?[[:space:]]*(;.*)?$' <<< "$zeile"; then
      meldung "check: Hinweis: KeyHelps automatisches Update für $PHP_VER ist nicht ausgeschaltet (keyhelp-setup/config.ini: ${zeile:-ohne is_autoupdate_enabled}); 'update' schaltet es aus"
    fi
  elif [ -d "$ZIEL/keyhelp-setup" ]; then
    meldung "check: Hinweis: keyhelp-setup/config.ini fehlt (KeyHelps Paket liefert sie mit); ob KeyHelp $PHP_VER selbst aktualisieren würde, ist offen; 'update' legt sie nicht an"
  fi
  [ -x "/etc/init.d/$DIENST" ] || { meldung "check: /etc/init.d/$DIENST fehlt"; befunde=$((befunde + 1)); }
  [ -L "/usr/bin/keyhelp-php$PHP_KURZ" ] || { meldung "check: /usr/bin/keyhelp-php$PHP_KURZ fehlt"; befunde=$((befunde + 1)); }
  if keyhelp_da && pools_da; then
    if fpm_laeuft; then
      meldung "check: Dienst $DIENST läuft ($(compgen -G "$ZIEL/etc/php-fpm.d/*.conf" | wc -l) Pool-Dateien von KeyHelp)"
    else
      meldung "check: Dienst $DIENST läuft nicht, obwohl KeyHelp Pools angelegt hat; Abhilfe: systemctl restart $DIENST"; befunde=$((befunde + 1))
    fi
  fi
  if [ "$befunde" -eq 0 ]; then meldung "check: in Ordnung"; return 0; fi
  meldung "check: $befunde Befunde"
  [ "$modus" = still ] && return 1
  exit 1
}

status_befehl() {
  [ "$(id -u)" -eq 0 ] || fehler "nur als root" 4
  [ -f "$ZUSTAND/zustand.env" ] || { meldung "nicht installiert"; exit 1; }
  cat "$ZUSTAND/zustand.env"
  if [ -f "$ZUSTAND/pakete-neu.txt" ]; then echo "neu installierte Pakete: $(tr '\n' ' ' < "$ZUSTAND/pakete-neu.txt")"; fi
  if [ -x "$ZIEL/bin/php" ]; then "$ZIEL/bin/php" -v 2>&1 | head -n 1; fi
  if fpm_laeuft; then echo "Dienst $DIENST: läuft"; else echo "Dienst $DIENST: läuft nicht"; fi
  if [ -f "$CRON" ]; then echo "tägliche Prüfung: $CRON"; else echo "tägliche Prüfung: keine"; fi
}

sql() { mysql -N -B -e "$1" 2>&1; }

nutzung_pruefen() {
  # Rückbau nur, wenn feststeht, dass nichts PHP 5.6 nutzt; jede gescheiterte Abfrage bricht ab. Die
  # Datenbank wird immer geprüft, wenn KeyHelp da ist oder der Zustand eine Installation mit KeyHelp
  # ausweist (OHNE_KEYHELP ungleich 1), auch wenn die Kennzeichen von KeyHelp fehlen.
  local d t s c hinweis="Erst selbst prüfen, dann mit --trotz-domains"
  if keyhelp_da || [ "$(zustand_wert OHNE_KEYHELP)" != 1 ]; then
    command -v mysql > /dev/null || fehler "mysql fehlt; ob KeyHelp PHP $PHP_VER nutzt, lässt sich nicht prüfen. $hinweis" 5
    d=$(sql "SELECT COUNT(*) FROM keyhelp.domains WHERE php_version = '$PHP_VER'") || fehler "Abfrage der Domains gescheitert: $d. $hinweis" 5
    t=$(sql "SELECT COUNT(*) FROM keyhelp.scheduled_tasks WHERE php_interpreter LIKE '%$PHP_VER%' OR php_interpreter LIKE '%php$PHP_KURZ%' OR command LIKE '%keyhelp-php$PHP_KURZ%' OR command LIKE '%/php/$PHP_VER/%'") || fehler "Abfrage der geplanten Aufgaben gescheitert: $t. $hinweis" 5
    s=$(sql "SELECT COUNT(*) FROM keyhelp.settings WHERE category = 'php_interpreter' AND name = 'default' AND (value LIKE '%$PHP_VER%' OR value LIKE '%php$PHP_KURZ%')") || fehler "Abfrage des Standard-Interpreters gescheitert: $s. $hinweis" 5
    [[ "$d" =~ ^[0-9]+$ && "$t" =~ ^[0-9]+$ && "$s" =~ ^[0-9]+$ ]] || fehler "unerwartete Antwort der Datenbank ($d; $t; $s). $hinweis" 5
    if [ "$d" != 0 ] || [ "$t" != 0 ] || [ "$s" != 0 ]; then
      fehler "KeyHelp nutzt PHP $PHP_VER: $d Domain(s), $t geplante Aufgabe(n), Standard-Interpreter: $([ "$s" = 0 ] && echo nein || echo ja). Erst im Panel umstellen, dann erneut 'uninstall'; --trotz-domains entfernt den Interpreter trotzdem, die Websites fallen dann aus" 5
    fi
    meldung "KeyHelp nutzt PHP $PHP_VER nicht (Domains, geplante Aufgaben, Standard-Interpreter geprüft)"
  else
    meldung "kein KeyHelp gefunden und Installation im Testmodus; die Prüfung in KeyHelps Datenbank entfällt"
  fi
  if pools_da; then fehler "KeyHelp hat noch Pools für PHP $PHP_VER angelegt ($ZIEL/etc/php-fpm.d); eine Domain nutzt es wohl noch. $hinweis" 5; fi
  c=$(grep -rlsF -e "keyhelp-php$PHP_KURZ" -e "/opt/keyhelp/php/$PHP_VER/" /var/spool/cron/crontabs /etc/crontab /etc/cron.d 2>/dev/null | grep -vxF "$CRON" | wc -l || true)
  [ "${c:-0}" = 0 ] || fehler "$c Crontab-Datei(en) rufen PHP $PHP_VER auf (keyhelp-php$PHP_KURZ). $hinweis" 5
  # ab 0.4.16 auch systemd-Units des Verwalters (Dienste, Timer); KeyHelps eigener FPM-Dienst zählt nicht (F-016)
  c=$(grep -rlsF -e "keyhelp-php$PHP_KURZ" -e "/opt/keyhelp/php/$PHP_VER/" /etc/systemd/system /usr/local/lib/systemd/system 2>/dev/null | grep -vE "/$DIENST(\.service)?(\.d/[^/]*)?$" | wc -l || true)
  [ "${c:-0}" = 0 ] || fehler "$c systemd-Unit-Datei(en) rufen PHP $PHP_VER auf. $hinweis" 5
}

entfernt_auch() {
  # Pakete, die apt beim Entfernen der Menge $1 zusätzlich entfernen würde; Rückgabe 1, wenn die
  # Simulation scheitert (der Aufrufer behält dann die Pakete, I-27); den Grund aus der Ausgabe von
  # apt schreibt sie dann nach $ZUSTAND/.apt-grund (0.4.8)
  local plan rc=0
  # shellcheck disable=SC2086
  plan=$(apt-get -s purge $1 2>"$ZUSTAND/.apt-fehler") || rc=$?
  if [ "$rc" -ne 0 ]; then
    { grep -E '^ ' <<< "$plan" || true; grep -v '^$' "$ZUSTAND/.apt-fehler" || true; } | head -n 4 | tr -s ' \n' ' ' | cut -c1-300 > "$ZUSTAND/.apt-grund" || true
    rm -f "$ZUSTAND/.apt-fehler"
    return 1
  fi
  rm -f "$ZUSTAND/.apt-fehler"
  # shellcheck disable=SC2086
  awk '/^Purg / {print $2}' <<< "$plan" | sort -u | comm -23 - <(printf '%s\n' $1 | sort -u)
}

apt_grund() {
  # Grund der letzten gescheiterten Simulation (aus entfernt_auch), sonst ein Platzhalter
  if [ -s "$ZUSTAND/.apt-grund" ]; then tr -d '\n' < "$ZUSTAND/.apt-grund"; else printf 'apt ohne Angabe'; fi
}

pakete_anderer_interpreter() {
  # Pakete, deren Bibliotheken KeyHelps übrige Interpreter laden; sie sind keine dpkg-Pakete und
  # erscheinen deshalb nicht in den Abhängigkeiten von apt
  local f
  for f in /opt/keyhelp/php/*/bin/php /opt/keyhelp/php/*/sbin/keyhelp-php*-fpm /opt/keyhelp/php/*/lib/php/extensions/*/*.so; do
    case "$f" in "$ZIEL"/*) continue ;; esac
    [ -f "$f" ] || continue
    ldd "$f" 2>/dev/null | awk '$2 == "=>" && $3 ~ /^\// {print $3}' || true
  done | sort -u | while read -r lib; do
    dpkg -S "$lib" 2>/dev/null || dpkg -S "$(readlink -f "$lib")" 2>/dev/null || true
  done | cut -d: -f1 | sort -u
}

test_vor_purge() {
  # nur im Testmodus ohne KeyHelp: führt KHLI_TEST_VOR_PURGE unmittelbar vor dpkg --purge aus, etwa um ein
  # Paket zu installieren, das von einem der zu entfernenden abhängt (Wettlauf nach der Simulation, I-27)
  if { [ "$OHNE_KEYHELP" = 1 ] || [ "$(zustand_wert OHNE_KEYHELP)" = 1 ]; } && ! keyhelp_da && [ -n "${KHLI_TEST_VOR_PURGE:-}" ]; then
    meldung "Testschritt vor dem Entfernen: $KHLI_TEST_VOR_PURGE"
    bash -c "$KHLI_TEST_VOR_PURGE" 9>&- || meldung "Testschritt endete mit einem Fehler"
  fi
  return 0
}

pakete_purgen() {
  # dpkg --purge wartet nicht auf die Paketsperre; deshalb bis zu zehn Minuten lang erneut versuchen
  local i rc aus
  for i in $(seq 1 60); do
    rc=0
    aus=$(dpkg --purge "$@" 2>&1 9>&-) || rc=$?
    printf '%s\n' "$aus"
    [ "$rc" -ne 0 ] || return 0
    case "$aus" in *"locked by another process"*) sleep 10 ;; *) return "$rc" ;; esac
  done
  return 1
}

pakete_entfernen() {
  # Kandidaten: von der Installation geplant oder neu installiert, vorher nicht vorhanden, heute
  # installiert. Es bleiben: inzwischen von Hand markierte Pakete, solche, die andere brauchen, und
  # solche, die KeyHelps übrige Interpreter laden. Was entfernt werden sollte und nicht entfernt
  # werden konnte (Simulation gescheitert, dpkg gescheitert), kommt in eine Liste unter dem
  # Protokollordner, und uninstall endet mit Exit 1 (I-32).
  local alle p kand="" hand="" abh="" kh="" gehalten="" gescheitert="" menge fremd neu i x andere ungeplant
  if [ -s "$ZUSTAND/pakete-geplant.txt" ]; then
    # ab 0.4.17 nur, was die Installation geplant hat (der Plan von apt enthält auch die Abhängigkeiten): in
    # Zuständen bis 0.4.15 kann pakete-neu.txt Pakete aus dem Lauf von KeyHelps install.sh enthalten, die
    # auch ein anderer Lauf installiert haben kann; sie bleiben (G-06)
    alle=$(sort -u "$ZUSTAND/pakete-geplant.txt" | comm -23 - "$ZUSTAND/pakete-vorher.txt" || true)
    ungeplant=$(sort -u "$ZUSTAND/pakete-neu.txt" 2>/dev/null | comm -23 - <(sort -u "$ZUSTAND/pakete-geplant.txt") | comm -23 - "$ZUSTAND/pakete-vorher.txt" | tr '\n' ' ' || true)
    [ -z "${ungeplant// /}" ] || meldung "Hinweis: nicht von der Installation geplant, deshalb nicht entfernt: ${ungeplant% }"
  else
    # Zustand ohne Plan (vor 0.3): wie bisher alles, was die Installation neu installiert hat
    alle=$(sort -u "$ZUSTAND/pakete-neu.txt" 2>/dev/null | comm -23 - "$ZUSTAND/pakete-vorher.txt" || true)
  fi
  if [ -z "$alle" ]; then meldung "keine Pakete zu entfernen"; return 0; fi
  manuell_liste > "$ZUSTAND/.manuell-jetzt"
  if [ -f "$ZUSTAND/manuell-nachher.txt" ]; then
    comm -23 "$ZUSTAND/manuell-nachher.txt" "$ZUSTAND/manuell-vorher.txt" > "$ZUSTAND/.manuell-eigen"
  else
    # Abbruch vor dem Ende der Installation einer alten Fassung: alle seither von Hand markierten
    # gelten als eigene
    comm -23 "$ZUSTAND/.manuell-jetzt" "$ZUSTAND/manuell-vorher.txt" > "$ZUSTAND/.manuell-eigen"
  fi
  andere=$(pakete_anderer_interpreter)
  for p in $alle; do
    paket_da "$p" || continue
    if grep -qxF "$p" <<< "$andere"; then
      kh="$kh $p"
    elif [ "$(dpkg-query -W -f='${db:Status-Want}' "$p" 2>/dev/null || true)" = hold ]; then
      # vom Verwalter gehalten (apt-mark hold): bleibt wie ein von Hand installiertes Paket; dpkg --purge
      # entfernte es sonst, weil eine ausdrückliche Anfrage einen Halt übergeht
      gehalten="$gehalten $p"
    elif grep -qxF "$p" "$ZUSTAND/.manuell-jetzt" && ! grep -qxF "$p" "$ZUSTAND/.manuell-eigen"; then
      hand="$hand $p"
    else
      kand="$kand $p"
    fi
  done
  # was gehaltene Pakete brauchen, bleibt, gleich ob sie zur Installation gehören oder nicht; die
  # Simulation von apt scheitert sonst, statt das gehaltene Paket als betroffen zu melden (0.4.6, I-34)
  local alle_gehalten braucht
  alle_gehalten=$(dpkg-query -W -f='${db:Status-Want} ${db:Status-Status} ${Package}\n' 2>/dev/null | awk '$1 == "hold" && $2 == "installed" {print $3}' | tr '\n' ' ')
  if [ -n "${alle_gehalten// /}" ] && [ -n "$kand" ]; then
    # shellcheck disable=SC2086
    if braucht=$(apt-cache depends --recurse --installed --no-recommends --no-suggests --no-conflicts --no-breaks --no-replaces --no-enhances $alle_gehalten 2>"$ZUSTAND/.apt-cache-fehler" | awk '!/^ / {print $1}' | sort -u); then
      neu=""
      for p in $kand; do if grep -qxF "$p" <<< "$braucht"; then abh="$abh $p"; else neu="$neu $p"; fi; done
      kand=$neu
    else
      # ohne die Hülle lässt sich nicht sicher entscheiden: alle bleiben, mit Liste (I-35)
      meldung "apt-cache depends gescheitert ($(head -c 300 "$ZUSTAND/.apt-cache-fehler" | tr '\n' ' ')); die Pakete der Installation bleiben"
      gescheitert="$gescheitert $kand"
      kand=""
    fi
    rm -f "$ZUSTAND/.apt-cache-fehler"
  fi
  menge=$kand
  if [ -n "${menge// /}" ]; then
    local ganz=1 s=""
    fremd=$(entfernt_auch "$menge") || ganz=0
    if [ "$ganz" = 0 ] || [ -n "$fremd" ]; then
      # nicht alle zusammen: die entfernbare Teilmenge Paket für Paket aufbauen. Ein Paket kommt dazu,
      # wenn apt es zusammen mit der bisherigen Teilmenge ohne fremde Pakete entfernen kann; was apt dabei
      # zusätzlich entfernte, gehört dann auch dazu. Sonst bleibt es: als gebraucht, wenn es allein
      # entfernbar wäre (etwa eine von zwei Alternativen, die ein anderes Paket braucht), sonst mit
      # Liste. Jedes Paket braucht so eine Simulation, und es gibt keine Runden ohne Fortschritt mehr
      # (0.4.10, I-34, I-42)
      if [ "$ganz" = 0 ]; then
        meldung "Simulation des Entfernens aller Pakete gescheitert ($(apt_grund)); prüfe Paket für Paket"
      else
        meldung "apt würde mit allen Paketen auch andere entfernen ($(tr '\n' ' ' <<< "$fremd")); prüfe Paket für Paket"
      fi
      for p in $menge; do
        case " $s " in *" $p "*) continue ;; esac
        if x=$(entfernt_auch "$s $p"); then
          # shellcheck disable=SC2086
          if [ -z "$(comm -23 <(printf '%s\n' $x | sort -u) <(printf '%s\n' $menge | sort -u) | grep -v '^$' || true)" ]; then
            s="$s $p $(tr '\n' ' ' <<< "$x")"
          else
            abh="$abh $p"
          fi
        elif entfernt_auch "$p" > /dev/null; then
          abh="$abh $p"
        else
          gescheitert="$gescheitert $p"
        fi
      done
      # shellcheck disable=SC2086
      menge=" $(printf '%s\n' $s | grep -v '^$' | sort -u | tr '\n' ' ' || true)"
      # keins entfernbar: leer, damit weder dpkg --verify noch dpkg --purge ohne Paketnamen laufen (I-45)
      [ -n "${menge// /}" ] || menge=""
    fi
  fi
  if [ -n "${menge// /}" ]; then
    if ! fremd=$(entfernt_auch "$menge"); then
      meldung "Simulation des Entfernens gescheitert ($(apt_grund)); die Pakete der Installation bleiben"
      gescheitert="$gescheitert $menge"
      menge=""
    elif [ -n "$fremd" ]; then
      meldung "behalte alle Pakete der Installation: apt würde sonst auch andere entfernen ($(tr '\n' ' ' <<< "$fremd"))"
      abh="$abh $menge"
      menge=""
    fi
  fi
  if [ -n "${menge// /}" ]; then
    local konf art f ts liste=()
    # shellcheck disable=SC2086
    konf=$(dpkg --verify $menge 2>/dev/null || true)
    while read -r _ art f; do
      if [ "$art" = c ] && [ -f "$f" ]; then liste+=("${f#/}"); fi
    done <<< "$konf"
    if [ ${#liste[@]} -gt 0 ]; then
      ts=$(date -u +%Y%m%dT%H%M%SZ)
      ts=$(eindeutig "$PROTOKOLL_DIR/sicherung-$ts-konfiguration" .tar.gz)
      (umask 077 && tar -czf "$ts" -C / "${liste[@]}")
      meldung "geänderte Konfigurationsdateien dieser Pakete gesichert: $ts (${liste[*]})"
    fi
    meldung "entferne die bei der Installation hinzugefügten Pakete:$menge"
    # dpkg statt apt-get: dpkg entfernt kein Paket, von dem ein anderes installiertes abhängt, auch
    # wenn ein anderer Lauf es seit der Simulation installiert hat (I-27)
    test_vor_purge
    # shellcheck disable=SC2086
    pakete_purgen $menge || meldung "Warnung: dpkg --purge endete mit einem Fehler (siehe oben)"
    for p in $menge; do if paket_da "$p"; then gescheitert="$gescheitert $p"; fi; done
  fi
  if [ -n "$gescheitert" ]; then
    local liste_datei
    liste_datei=$(eindeutig "$PROTOKOLL_DIR/pakete-nicht-entfernt-$(date -u +%Y%m%dT%H%M%SZ)" .txt)
    # shellcheck disable=SC2086
    printf '%s\n' $gescheitert | sort -u > "$liste_datei"
    meldung "nicht entfernt, obwohl vorgesehen:$gescheitert (Liste: $liste_datei)"
    RUECKBAU_UNVOLLSTAENDIG=$liste_datei
  fi
  [ -z "$kh" ] || meldung "behalten, weil KeyHelps übrige Interpreter sie laden:$kh"
  [ -z "$hand" ] || meldung "behalten, weil inzwischen von Hand installiert:$hand"
  [ -z "$gehalten" ] || meldung "behalten, weil gehalten (apt-mark hold):$gehalten"
  [ -z "$abh" ] || meldung "behalten, weil andere Pakete sie brauchen:$abh"
  rm -f "$ZUSTAND/.manuell-jetzt" "$ZUSTAND/.manuell-eigen" "$ZUSTAND/.apt-grund"
}

uninstall_befehl() {
  local behalten=0 trotz=0 trotz_fremd=0 h rc o
  while [ $# -gt 0 ]; do
    case "$1" in
      --pakete-behalten) behalten=1 ;;
      --trotz-domains) trotz=1 ;;
      --trotz-fremdem-ordner) trotz_fremd=1 ;;
      *) fehler "unbekannte Option $1" 2 ;;
    esac
    shift
  done
  [ "$(id -u)" -eq 0 ] || fehler "nur als root" 4
  command -v flock > /dev/null || fehler "flock fehlt (Paket util-linux)" 4
  sperren
  [ -f "$ZUSTAND/zustand.env" ] || fehler "kein Zustand unter $ZUSTAND; nicht mit khli-php56 installiert" 1
  protokoll_start uninstall
  # 0. Fehlt das Ziel und liegt der bisherige Ordner in einem Rest eines abgebrochenen Updates, kommt er
  #    zuerst zurück: die Prüfung der Nutzung sieht dann seine Pools, und die Sicherung erfasst ihn
  #    (I-40); übrige Reste entfernt der Rückbau nach dem Ziel
  alte_arbeitsordner_entfernen vor_rueckbau
  # 1. Nutzung: nur nach gelungener Prüfung weiter
  if [ "$trotz" = 1 ]; then meldung "Warnung: --trotz-domains, die Nutzung von PHP $PHP_VER wird nicht geprüft"; else nutzung_pruefen; fi
  # 2. Herkunft: nur den eigenen Ordner löschen. Ein Ordner ohne Ergänzungssatz gilt als Rest dieses
  #    Rückbaus, wenn ein früherer uninstall schon RUECKBAU=begonnen gesetzt hatte: KeyHelps uninstall.sh
  #    löscht das Ziel selbst, ein Abbruch darin hinterlässt einen halben Ordner (I-43)
  h=$(herkunft)
  if [ "$h" = fremd ] && [ "$(zustand_wert RUECKBAU)" = begonnen ]; then
    meldung "Hinweis: $ZIEL ist der Rest eines abgebrochenen Rückbaus (RUECKBAU=begonnen im Zustand); er wird weiter zurückgebaut"
    h=rest
  fi
  if [ "$h" = fremd ] && [ "$trotz_fremd" = 0 ]; then
    fehler "$ZIEL enthält den Ergänzungssatz von khli-php56 nicht (von KeyHelp ersetzt?); $([ "$ZURUECKGEHOLT" = 1 ] && echo 'außer dem Zurücklegen aus dem Rest nichts verändert' || echo 'nichts verändert'). --trotz-fremdem-ordner entfernt ihn trotzdem (mit Sicherung)" 5
  fi
  zustand_migrieren
  # 3. Sicherung
  sicherung_anlegen uninstall
  # ab hier verändert der Rückbau das Ziel; bricht er ab, erkennt der nächste uninstall den Rest daran
  zustand_setzen RUECKBAU=begonnen || fehler "Zustand nicht schreibbar; nichts entfernt" 1
  testabbruch rueckbau
  # 4. KeyHelps uninstall.sh: stoppt den Dienst, entfernt Startskript, Verknüpfung und Ordner
  if [ -f "$ZIEL/keyhelp-setup/uninstall.sh" ]; then
    meldung "führe KeyHelps uninstall.sh aus"
    rc=0
    bash "$ZIEL/keyhelp-setup/uninstall.sh" 9>&- || rc=$?
    [ "$rc" -eq 0 ] || meldung "Warnung: uninstall.sh endete mit $rc"
  fi
  # was uninstall.sh liegen lässt oder bei einem Abbruch übrig bliebe; läuft der Dienst danach noch, geht
  # der Rückbau trotzdem weiter wie bis 0.4.15 (0.4.16)
  dienst_anhalten || meldung "Warnung: $DIENST läuft nach dem Anhalten noch; der Rückbau geht weiter"
  rm -f "/etc/init.d/$DIENST" "/usr/bin/keyhelp-php$PHP_KURZ" "$PIDDATEI"
  # taub für Signale, damit dieses Löschen nicht halb endet (0.4.9); einen halben Ordner aus einem Abbruch
  # in KeyHelps uninstall.sh erkennt der nächste uninstall an RUECKBAU=begonnen (0.4.10, I-43)
  ohne_signale rm -rf "$ZIEL"
  # der zurückgeholte Ordner ist jetzt weg; der Hinweis zum Dienst gilt nicht mehr (0.4.13, I-48)
  ZURUECKGEHOLT=0
  alte_arbeitsordner_entfernen alles
  # nur im Testmodus angelegte Ordner, und nur wenn leer
  if [ -f "$ZUSTAND/ordner-neu.txt" ]; then
    while read -r o; do rmdir "$o" 2>/dev/null || true; done < "$ZUSTAND/ordner-neu.txt"
  fi
  werkzeug_entfernen
  systemctl daemon-reload 2>/dev/null 9>&- || true
  # 5. Pakete
  if [ "$behalten" = 0 ]; then pakete_entfernen; else meldung "Pakete bleiben (--pakete-behalten)"; fi
  rm -rf "$ZUSTAND"
  if [ -n "$RUECKBAU_UNVOLLSTAENDIG" ]; then
    fehler "deinstalliert bis auf Pakete, die stehen blieben (Liste: $RUECKBAU_UNVOLLSTAENDIG); sie bitte von Hand prüfen und entfernen" 1
  fi
  meldung "deinstalliert; Protokolle und Sicherungen bleiben unter $PROTOKOLL_DIR"
}

case "$befehl" in
  install) install_befehl "$@" ;;
  update) update_befehl "$@" ;;
  check) check_befehl "$@" ;;
  status) status_befehl ;;
  uninstall) uninstall_befehl "$@" ;;
  version|--version) echo "khli-php56 $KHLI_VERSION" ;;
  *) hilfe; exit 2 ;;
esac
