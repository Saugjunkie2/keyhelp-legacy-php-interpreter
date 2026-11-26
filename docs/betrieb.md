# Betrieb: PHP 5.6 für KeyHelp unter Debian 13

Gilt für Release 0.4.15: Installer `khli-php56.sh` 0.4.15, Ergänzungssatz 1.1.0, `install.sh` 1.0.0. [English version](en/operation.md)

## Kurzfassung

```bash
bash install.sh            # installieren oder aktualisieren, als root (README)
khli-php56 check           # prüfen, jederzeit
khli-php56 status          # Version, Zustand und Dienst
khli-php56 uninstall       # vollständiger Rückbau, nur wenn nichts 5.6 nutzt
```

Danach erscheint 5.6 in KeyHelp wie die offiziellen Interpreter; zugewiesen wird es im Panel je Domain.

## Installation

### Was install.sh tut

1. prüft root, Debian 13, amd64, `openssl` und `curl` oder `wget`
2. lädt `SHA256SUMS` und `SHA256SUMS.sig` des Releases und prüft die Ed25519-Signatur mit seinem eingetragenen Schlüssel; ohne gültige Signatur endet es mit Exit 3 und ändert nichts
3. lädt jede Datei des Releases und prüft sie gegen `SHA256SUMS`; prüft `RELEASE` (Produkt, System, Version gleich der des Installers)
4. fragt den zweiten Kanal nach Widerrufen ([signatur.md](signatur.md#zweiter-kanal)); ein widerrufenes Release lehnt es ab (Exit 5)
5. prüft den freien Platz und startet den Installer: `install`, wenn PHP 5.6 dieses Projekts noch nicht eingerichtet ist, sonst `update`; Optionen nach `--` gehen an den Installer
6. schreibt eine Zeile nach `/var/log/khli-php56/install-sh.log` (Release, SHA-256 von `SHA256SUMS`, Schlüssel, Exit-Code)

Optionen: `--version <v>` für ein bestimmtes Release, `--quelle <ordner|https-adresse>` statt GitHub, `--nur-pruefen`, `--nur-laden <ordner>`, `--ohne-zweiten-kanal`, `--aelter-erlauben`, `--hilfe`.

### Was der Installer tut

`khli-php56.sh install`

- lädt KeyHelps Paket `php_5.6.40_20261103164601.tar.gz` von `repo.keyhelp.de` und prüft den fest eingetragenen SHA-256 (`4ee240d31be9f1cc5cba853728b3bc6fe4aceaa18a1a0a3dafd0d282dbf5b6c6`); mit `--original <datei>` nimmt er eine vorhandene Datei
- prüft den Ergänzungssatz gegen seinen fest eingetragenen SHA-256 und beide Archive auf Pfade und Verknüpfungen außerhalb ihres Ordners; scheitert eine Prüfung, ändert er nichts (Exit 3 oder 4)
- installiert fehlende Laufzeitpakete aus Debian 13 (auf einem KeyHelp-Server meist nur `libmcrypt4` und `xz-utils`) und hält fest, welche Pakete neu dazukommen
- legt KeyHelps Paket unverändert nach `/opt/keyhelp/php/5.6` und den Ergänzungssatz nach `lib/khli`, setzt den RUNPATH in gd, imagick, imap, ldap, tidy, ssh2 und in der gebündelten ICU; `ssh2.so` lädt das private libssh2 1.10 aus Debian 12 unter dem Namen `libssh2-khli.so.1`, libcurl nutzt weiter das libssh2 von Debian 13
- schaltet in `keyhelp-setup/config.ini` KeyHelps automatisches Update für 5.6 aus (`is_autoupdate_enabled = false`); nur diese Zeile ändert sich
- führt KeyHelps eigenes `keyhelp-setup/install.sh` aus (Startskript, Befehl `keyhelp-php56`, Zeitzone)
- richtet das Prüfwerkzeug `/usr/local/sbin/khli-php56` und die tägliche Prüfung `/etc/cron.d/khli-php56` ein
- prüft das Ergebnis mit `check`; Zustand unter `/var/lib/khli-php56/`, Protokolle unter `/var/log/khli-php56/`; endet KeyHelps `install.sh` mit Fehler oder meldet `check` Befunde, endet der Installer mit Exit 1

KeyHelps Master-Cronjob beendet ein `apt-get`, das ihm zu lange läuft. Am besten nicht in KeyHelps nächtlichen Wartungsfenstern (2 bis 7 Uhr) installieren. Bricht die Installation trotzdem ab, setzt `khli-php56 uninstall` alles zurück, auch die schon installierten Pakete; danach erneut installieren. Zwei Läufe gleichzeitig verhindert eine Sperre (`/run/khli-php56.lock`, bleibt bis zum nächsten Neustart liegen). Hält gerade ein anderes Programm die Paketverwaltung, wartet apt bis zu zehn Minuten.

### Originalpaket aufbewahren

KeyHelp könnte das 5.6-Paket für Debian 12 eines Tages von `repo.keyhelp.de` entfernen. Dann scheitert der Download, und eine aufbewahrte Kopie hilft:

```bash
curl -fsSLO https://repo.keyhelp.de/live/amd64/debian_12/php/5.6/php_5.6.40_20261103164601.tar.gz
sha256sum php_5.6.40_20261103164601.tar.gz
# 4ee240d31be9f1cc5cba853728b3bc6fe4aceaa18a1a0a3dafd0d282dbf5b6c6
bash install.sh -- --original /root/php_5.6.40_20261103164601.tar.gz
```

Die Kopie ist nur für den eigenen Server; dieses Projekt verteilt KeyHelps Paket nicht.

## Nutzung

- Im Panel bei der Domain die PHP-Version 5.6 wählen. KeyHelp schreibt dann selbst den Pool `/opt/keyhelp/php/5.6/etc/php-fpm.d/<BENUTZER>_php56.conf`, stellt den VHost auf den Socket `/run/php/keyhelp_<BENUTZER>_php56.socket` um und startet `keyhelp-php56-fpm`.
- Kommandozeile: `keyhelp-php56` (Verknüpfung auf `/opt/keyhelp/php/5.6/bin/php`).
- Nach einem Neustart startet KeyHelp den Dienst selbst, sobald eine Domain ihn braucht (auf dem Testserver nach rund 40 Sekunden).
- Umzug einer Website von einem Debian-12-Server: die PHP-Einstellungen der Domain im Panel mitnehmen. Grenzen wie `memory_limit` oder `upload_max_filesize`, gesperrte Funktionen, `short_open_tag` und die Schalter der Sitzungs-Cookies gehören in KeyHelp zur Domain und stehen in ihrem Pool, nicht im Interpreter. Mit KeyHelps Vorgaben statt der bisherigen Einstellungen kann eine alte Anwendung anders laufen.
- Gettext: Die Sprache über die Umgebungsvariable `LANGUAGE` zu wählen, wirkt unter Debian 13 im Gebietsschema C.UTF-8 nicht (glibc 2.41); Anwendungen sollten ein Sprachgebietsschema wie `de_DE.UTF-8` setzen. Das gilt für jede PHP-Fassung unter Debian 13.

## Prüfen

`khli-php56 check` meldet:

- ob der Zustand vollständig ist, der Ergänzungssatz unverändert und die sieben geänderten Dateien den installierten Stand haben
- ob alle Programme, Erweiterungen und privaten Bibliotheken ihre Bibliotheken finden
- ob `php -m` ohne Startfehler lädt und die FPM-Konfiguration gültig ist (ohne Domain gibt es keinen Pool, das ist wie unter Debian 12)
- ob Startskript und Befehl vorhanden sind und der Dienst läuft, wenn KeyHelp Pools angelegt hat
- als Hinweis, nicht als Befund: ob KeyHelps automatisches Update für 5.6 wieder eingeschaltet ist (etwa im Panel) oder `config.ini` fehlt; `update` schaltet es wieder aus

Die tägliche Prüfung läuft um 7:40 Uhr, nach KeyHelps Wartungsjob `php-update`, als `khli-php56 check --cron`: ohne Befund keine Ausgabe, mit Befund eine Mail an root (über cron) und ein Eintrag im Systemprotokoll (`journalctl -t khli-php56`). Hinweise allein lösen keine Mail aus. Exit 1 bedeutet Befunde.

Endet der FPM-Dienst von außen, startete KeyHelp ihn auf dem Testserver nicht von selbst wieder. Die Prüfung meldet dann „Dienst keyhelp-php56-fpm läuft nicht, obwohl KeyHelp Pools angelegt hat"; Abhilfe: `systemctl restart keyhelp-php56-fpm` (nicht `start`, systemd hält den Dienst noch für aktiv).

## Aktualisieren

`bash install.sh` mit demselben Befehl wie bei der Installation; es startet `khli-php56.sh update` mit dem Ergänzungssatz des Releases.

- Leichter Zweig: Sind Originalpaket und Ergänzungssatz gleich geblieben und ist `check` in Ordnung, erneuert `update` nur Prüfwerkzeug und Zustand und schaltet KeyHelps automatisches Update aus, falls es wieder an ist (vorher Sicherung von `etc/`, `config.ini` und Protokollen). Interpreter und Dienst bleiben unberührt. `bash install.sh -- --neu-aufbauen` baut trotzdem neu auf.
- Voller Zweig: `update` baut den neuen Ordner neben dem alten, sichert `etc/`, `config.ini` und Protokolle nach `/var/log/khli-php56/sicherung-<zeit>-update.tar.gz`, hält den Dienst an, übernimmt Pools, Zeitzone, `config.ini` und Protokolle, tauscht die Ordner, startet den Dienst neu und führt KeyHelps `install.sh` aus, wie KeyHelps `php-update`.
- Rücknahme: Meldet `check` danach Befunde oder startet der Dienst nicht, kommt der alte Ordner zurück und der Dienst läuft wieder (Exit 1). Ebenso, wenn der Lauf während des Tauschs durch ein Signal abbricht, auch durch HUP an die ganze Prozessgruppe, wie beim Abriss einer SSH-Sitzung mit Terminal (Exit 129, 130, 141 oder 143). Reißt eine Sitzung ohne Terminal ab, kommt kein Signal: der Lauf geht zu Ende und schreibt weiter ins Protokoll. Nach SIGKILL oder Stromausfall holt der nächste `update` den bisherigen Ordner zurück, wenn das Ziel fehlt; sonst bleibt er mit einer Warnung liegen, bis `uninstall` ihn entfernt. `install.sh` wartet, bis der Installer fertig ist, und reicht seinen Exit-Code weiter.
- Die Domains bleiben auf 5.6; ihre Websites sind einige Sekunden nicht erreichbar (auf dem Testserver gemessen: unter einer Sekunde, etwa 3 von 599 Abrufen mit HTTP 503).
- Änderungen von Hand an `etc/php.ini` oder `etc/conf.d` übernimmt `update` nicht, wie KeyHelps eigenes Update; sie stehen in der Sicherung, und `update` nennt die betroffenen Dateien.

KeyHelp bietet 5.6 für Debian 13 nicht an und aktualisiert es deshalb nicht; zudem steht sein Schalter für das automatische Update von 5.6 auf aus, und das Panel zeigt ihn so. Ob KeyHelps `php-update` den Schalter beachtet, ist nicht beobachtet; das würde nur zählen, wenn KeyHelp für Debian 13 je ein 5.6-Paket anböte.

## Rückbau

`khli-php56 uninstall`

- prüft vorher in KeyHelps Datenbank, ob Domains, geplante Aufgaben oder der Standard-Interpreter 5.6 nutzen, ob KeyHelp Pools für 5.6 angelegt hat und ob Crontabs `keyhelp-php56` aufrufen; dann verweigert er mit Exit 5. Scheitert die Prüfung selbst, etwa ohne Zugriff auf die Datenbank, verweigert er ebenfalls. `--trotz-domains` übergeht die Prüfung; betroffene Websites haben danach kein PHP mehr.
- verweigert auch, wenn `/opt/keyhelp/php/5.6` den Ergänzungssatz nicht enthält, also nicht von diesem Installer stammt (`--trotz-fremdem-ordner` entfernt ihn trotzdem)
- sichert `etc/`, `config.ini` und Protokolle nach `/var/log/khli-php56/sicherung-<zeit>-uninstall.tar.gz`
- holt zuerst einen bisherigen Ordner aus dem Rest eines abgebrochenen Updates zurück, wenn das Ziel fehlt
- vermerkt den begonnenen Rückbau im Zustand: Bricht er ab, setzt der nächste `uninstall` ihn fort, und `update` verweigert bis dahin
- führt KeyHelps `uninstall.sh` aus und räumt Startskript, Befehl, Ordner, Prüfwerkzeug, tägliche Prüfung und Reste abgebrochener Läufe nach
- entfernt die bei der Installation hinzugekommenen Pakete mit `dpkg --purge`, das kein Paket entfernt, von dem ein anderes abhängt. Es bleiben Pakete, die inzwischen von Hand installiert wurden, gehaltene Pakete und alles, was sie brauchen, Pakete, die andere brauchen, und solche, deren Bibliotheken KeyHelps übrige Interpreter laden. Bleiben Pakete stehen, die entfernt werden sollten, stehen sie in `/var/log/khli-php56/pakete-nicht-entfernt-<zeit>.txt`, und `uninstall` endet mit Exit 1. `--pakete-behalten` lässt alle Pakete stehen.

Nicht umkehrbar ist nur, wenn apt beim Installieren ein vorhandenes Paket auf eine neuere Fassung gehoben hat (beobachtet bei einem Sicherheitsupdate von `liblzma5`; kein Eingriff nötig). Protokolle und Sicherungen unter `/var/log/khli-php56/` bleiben nach dem Rückbau; sie gehören root (Modus 750 und 600).

## Was sich am System ändert

| Änderung | Ort | Rückbau |
|---|---|---|
| KeyHelps Interpreterpaket, unverändert entpackt | `/opt/keyhelp/php/5.6/` | `uninstall` über KeyHelps `uninstall.sh` |
| Ergänzungssatz mit privaten Bibliotheken | `/opt/keyhelp/php/5.6/lib/khli/` | mit dem Ordner |
| RUNPATH in sieben ELF-Dateien, in `ssh2.so` dazu `NEEDED libssh2-khli.so.1`; alte und neue SHA-256 im Zustand | im Interpreterordner, `/var/lib/khli-php56/elf-aenderungen.tsv` | mit dem Ordner |
| Laufzeitpakete aus Debian 13, nur wenn sie fehlen | Paketverwaltung | `uninstall`, mit den Ausnahmen oben |
| Prüfwerkzeug (Kopie des Installers) | `/usr/local/sbin/khli-php56` | `uninstall` |
| tägliche Prüfung | `/etc/cron.d/khli-php56` (7:40 Uhr, nur lesend) | `uninstall` |
| KeyHelps Schalter für das automatische Update von 5.6 aus | `/opt/keyhelp/php/5.6/keyhelp-setup/config.ini` | mit dem Ordner; die bisherige Datei steht in der Sicherung |
| Startskript, Befehl `keyhelp-php56`, Zeitzone | durch KeyHelps eigenes `install.sh` | KeyHelps `uninstall.sh`, danach Nachlese des Installers |
| Sicherungen vor `update` und `uninstall` | `/var/log/khli-php56/sicherung-*.tar.gz` (0600) | bleiben bewusst |
| Zustand, Protokolle, Protokoll von `install.sh` | `/var/lib/khli-php56/` (0700), `/var/log/khli-php56/` (0750) | Zustand mit `uninstall`, Protokolle bleiben |
| Sperrdatei | `/run/khli-php56.lock` | bis zum nächsten Neustart |

Nicht geändert werden Systembibliotheken, die Standard-PHP-Version, `/etc/ld.so.conf.d` sowie die Konfiguration von Apache und KeyHelp (die schreibt KeyHelp selbst).

## Exit-Codes

| Code | Bedeutung |
|---|---|
| 0 | Erfolg |
| 1 | Fehler: etwa ein Download, ein anderer Lauf aktiv, Prüfung nach Installation oder Update mit Befunden, Rückbau mit Paketen, die stehen blieben |
| 2 | falscher Aufruf; ausnahmsweise auch der Status eines Befehls, der im Installer unter `set -e` abbrach (`tar`, `sort`, `dpkg-query`, etwa bei voller Platte); dann steht seine Fehlermeldung im Protokoll |
| 3 | Signatur, Prüfsumme oder Aufbau eines Archivs falsch |
| 4 | Voraussetzung fehlt (nicht root, nicht Debian 13, kein KeyHelp, kein Schlüssel, Datei nicht gefunden, zu wenig Platz) |
| 5 | zum Schutz abgelehnt: 5.6 in Gebrauch, fremder Ordner, Nutzung nicht prüfbar; bei `install.sh` auch ein widerrufenes oder älteres Release |
| andere Werte unter 128 | Status eines Befehls, der im Installer unter `set -e` abbrach, etwa 100 von `apt-get` bei einer fehlerhaften Paketquelle; seine Fehlermeldung steht im Protokoll |
| 129, 130, 141, 143 | abgebrochen durch HUP, INT (Strg+C), PIPE oder TERM; kam das Signal während des Tauschs eines `update`, ist der bisherige Stand zurückgeholt; bei `uninstall` diesen wiederholen |

## Fehlersuche

| Meldung | Ursache | Abhilfe |
|---|---|---|
| `install.sh: FEHLER: die Signatur von SHA256SUMS ist ungültig` | Release verändert oder nicht von Retrowork | nichts installieren; Herkunft prüfen ([signatur.md](signatur.md)) |
| `install.sh: FEHLER: dieses install.sh enthält keinen öffentlichen Schlüssel` | `install.sh` aus dem Repository statt aus einem Release | das `install.sh` aus einem Release nehmen |
| `install.sh: FEHLER: Download gescheitert: …/SHA256SUMS (gibt es das Release?)` | kein Netz, GitHub nicht erreichbar oder das Release gibt es nicht | Netz prüfen, `--version` prüfen, sonst `--quelle` |
| `install.sh: WARNUNG: zweiter Kanal … nicht erreichbar` | Domain des zweiten Kanals nicht erreichbar | Hinweis; Widerrufe von Hand auf dem zweiten Kanal ansehen |
| `install.sh: FEHLER: Release … ist widerrufen` | Retrowork hat das Release zurückgezogen | ein anderes Release wählen |
| `SHA-256 von … ist …, erwartet …` | falsche oder beschädigte Datei | Datei neu laden; die Prüfung nie umgehen |
| `… existiert und stammt nicht von khli-php56` | 5.6 von anderer Stelle installiert | vorhandenen Stand selbst entfernen oder behalten |
| `es gibt schon einen Zustand …` | vorhandene oder abgebrochene Installation | `update` oder `uninstall` |
| `ein anderer Lauf von khli-php56 ist aktiv` | zweiter Lauf gleichzeitig | den ersten abwarten |
| `KeyHelp nutzt PHP 5.6: …` | Domains, Aufgaben oder Standard-Interpreter auf 5.6 | im Panel umstellen, dann erneut `uninstall` |
| `check: lib/khli fehlt (Interpreter von KeyHelp ersetzt?)` | der Ordner wurde von außen ersetzt | `bash install.sh -- --trotz-fremdem-ordner` stellt den Stand dieses Projekts wieder her |
| `check: … findet nicht: …` | Bibliothek fehlt | `bash install.sh -- --neu-aufbauen`; Laufzeitpakete prüfen |
| `check: Dienst … läuft nicht, obwohl KeyHelp Pools angelegt hat` | FPM-Hauptprozess beendet | `systemctl restart keyhelp-php56-fpm`, `/opt/keyhelp/php/5.6/var/log/php-fpm.log` |
| Domain zeigt Fehler 503 | Dienst nicht gestartet | wie in der Zeile davor |
| `ein früherer uninstall wurde abgebrochen (RUECKBAU=begonnen)` | ein `uninstall` brach nach dem ersten Eingriff ab | `uninstall` wiederholen |
| `deinstalliert bis auf Pakete, die stehen blieben (Liste: …)` | apt konnte ein Paket nicht ohne fremde Pakete entfernen, oder die Paketverwaltung war gesperrt | Liste und Protokoll prüfen, Pakete von Hand mit `apt-get purge` entfernen, soweit nichts anderes sie braucht |
| `ssh2_auth_pubkey_file(): Authentication failed …` mit RSA-Schlüssel | der Server lehnt `ssh-rsa` (SHA-1) ab, wie bei PHP 5.6 unter Debian 12 | ECDSA- oder Ed25519-Schlüssel nutzen |

## Bekannte Grenzen

Aus dem Original unter Debian 12 übernommen, also dort genauso:

- PHP 5.6 erhält keine Sicherheitskorrekturen mehr ([SECURITY.md](../SECURITY.md)).
- `openssl_encrypt()` mit Verfahren, die OpenSSL 3 ohne Legacy-Provider nicht anbietet (bf, cast5, rc4, des, seed), lässt den Prozess abstürzen; FPM startet ein neues Kind.
- imagick kann WebP weder schreiben noch lesen, solange gd geladen ist (gd überdeckt Funktionen von libwebp); das Schreiben im Format MAT scheitert an einem Fehler im ImageMagick-6-Quelltext von Debian.
- imap: Lokale Postfächer außer INBOX sind gesperrt (Debians c-client), und c-client findet kein `mlock`; unter KeyHelp liegen Postfächer als Maildir bei Dovecot, nicht im Spool.
- `tls://` heißt in PHP 5.6 TLS 1.0 und scheitert gegen aktuelle Server; `ssl://` nutzen.
- ssh2 meldet sich mit RSA-Schlüsseln nur über `ssh-rsa` (SHA-1) an, das OpenSSH ab 8.8 ablehnt; ECDSA- und Ed25519-Schlüssel funktionieren.

Neu durch dieses Projekt:

- Die privaten Bibliotheken im Ergänzungssatz erhalten keine automatischen Updates. Debian pflegt Debian 12 als LTS bis Mitte 2028; neue Sicherheitsstände dieser Quellpakete kommen als neuer Ergänzungssatz in einem neuen Release ([bau.md](bau.md)).
- Die Systembibliotheken (OpenSSL 3.5, libxml2, libcurl, glibc und andere) kommen aus Debian 13 und erhalten dessen Sicherheitsupdates; TLS und Zertifikatsprüfung sind damit auf dem Stand von Debian 13.
