# Betrieb: PHP 5.6 für KeyHelp unter Debian 13

Gilt für Release 0.4.17: Installer `khli-php56.sh` 0.4.17, Ergänzungssatz 1.1.0, `install.sh` 1.1.1. [English version](en/operation.md)

## Kurzfassung

```bash
bash install.sh            # installieren oder aktualisieren, als root (README)
khli-php56 check           # prüfen, jederzeit
khli-php56 status          # Version, Zustand und Dienst
khli-php56 uninstall       # vollständiger Rückbau, solange KeyHelp und die geprüften Stellen 5.6 nicht nutzen
```

Danach erscheint 5.6 in KeyHelp wie die offiziellen Interpreter; zugewiesen wird es im Panel je Domain.

## Installation

### Was install.sh tut

1. prüft root, Debian 13, amd64, `openssl` und `curl` oder `wget`; nach `--` sind nur `--neu-aufbauen`, `--trotz-fremdem-ordner` und `--original <datei>` für den Installer erlaubt
2. lädt `SHA256SUMS` und `SHA256SUMS.sig` des Releases und prüft die Ed25519-Signatur mit seinem eingetragenen Schlüssel; ohne gültige Signatur endet es mit Exit 3 und ändert nichts
3. lädt jede Datei des Releases und prüft sie gegen `SHA256SUMS`; prüft `RELEASE` vollständig und gegen die Angaben des Installers (Version, Originalpaket, Ergänzungssatz)
4. fragt den zweiten Kanal nach der Freigabe ([signatur.md](signatur.md#zweiter-kanal)): ohne gültige, nicht abgelaufene Freigabeliste, in der das Release als `gueltig` steht, startet nichts (Exit 5 oder 3); `--ohne-zweiten-kanal` lässt das mit Warnung aus
5. prüft, dass der Server keinen anderen Release-Schlüssel festhält (sonst Exit 3, `--neuer-schluessel` nach einem angekündigten Wechsel), prüft den freien Platz und startet den Installer: `install`, wenn PHP 5.6 dieses Projekts noch nicht eingerichtet ist, sonst `update`
6. hält nach einem erfolgreichen Lauf Schlüssel und Generation der Freigabeliste im Zustand fest und schreibt eine Zeile nach `/var/log/khli-php56/install-sh.log` (Release, SHA-256 von `SHA256SUMS`, Schlüssel, Freigabeliste, Exit-Code)

Optionen: `--version <v>` für ein bestimmtes Release, `--quelle <ordner|https-adresse>` statt GitHub, `--nur-pruefen`, `--nur-laden <ordner>`, `--ohne-zweiten-kanal`, `--aelter-erlauben`, `--neuer-schluessel`, `--hilfe`.

### Was der Installer tut

`khli-php56.sh install`

- lädt KeyHelps Paket `php_5.6.40_20261103164601.tar.gz` von `repo.keyhelp.de` und prüft den fest eingetragenen SHA-256 (`4ee240d31be9f1cc5cba853728b3bc6fe4aceaa18a1a0a3dafd0d282dbf5b6c6`); mit `--original <datei>` nimmt er eine vorhandene Datei, kopiert sie zuerst in seinen eigenen Arbeitsordner (nur root) und prüft und benutzt nur diese Kopie
- prüft den Ergänzungssatz ebenso als Kopie gegen seinen fest eingetragenen SHA-256 und beide Archive auf Pfade und Verknüpfungen außerhalb ihres Ordners; scheitert eine Prüfung, ändert er nichts (Exit 3 oder 4)
- installiert fehlende Laufzeitpakete aus Debian 13 (auf einem KeyHelp-Server meist nur `libmcrypt4` und `xz-utils`) und hält fest, welche Pakete er selbst installiert; würde apt dafür ein Paket entfernen, lehnt er ab, bevor apt etwas ändert (Exit 1), und der echte Lauf hat `--no-remove`; hebt apt dabei vorhandene Pakete auf eine neuere Fassung, nennt er sie
- entpackt KeyHelps Paket aus dem unveränderten Archiv nach `/opt/keyhelp/php/5.6` und den Ergänzungssatz nach `lib/khli`; geändert wird nur der RUNPATH in gd, imagick, imap, ldap, tidy, ssh2 und in der gebündelten ICU, und `ssh2.so` lädt das private libssh2 1.10 aus Debian 12 unter dem Namen `libssh2-khli.so.1` (libcurl nutzt weiter das libssh2 von Debian 13)
- schaltet in `keyhelp-setup/config.ini` KeyHelps automatisches Update für 5.6 aus (`is_autoupdate_enabled = false`); nur diese Zeile ändert sich
- führt KeyHelps eigenes `keyhelp-setup/install.sh` aus (Startskript, Befehl `keyhelp-php56`, Zeitzone); Pakete, die in diesem Lauf dazukommen, gelten nicht als eigene (sie können auch von einem anderen Lauf stammen), stehen aber in `/var/lib/khli-php56/pakete-waehrend-install-sh.txt`
- richtet das Prüfwerkzeug `/usr/local/sbin/khli-php56` und die tägliche Prüfung `/etc/cron.d/khli-php56` ein
- prüft das Ergebnis mit `check` und hält die Liste der Module fest; Zustand unter `/var/lib/khli-php56/`, Protokolle unter `/var/log/khli-php56/`; endet KeyHelps `install.sh` mit Fehler oder meldet `check` Befunde, endet der Installer mit Exit 1

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

### Ohne Internet

`--nur-laden <ordner>` holt und prüft nur das Release selbst. Für einen Server ohne Internet braucht es außerdem:

- KeyHelps Paket als Datei (`-- --original <datei>`, siehe oben)
- die Laufzeitpakete aus Debian 13: entweder schon installiert oder über einen eigenen Debian-Spiegel erreichbar; `apt-get` braucht sonst Netz
- `--ohne-zweiten-kanal`, weil die Freigabeliste online liegt; Freigabe und Widerruf prüft man dann von Hand auf dem zweiten Kanal

Eine Vorabprüfung, die alles das vor dem ersten Eingriff meldet, fehlt noch. Fehlt das Originalpaket, bricht der Installer ab, bevor er etwas ändert; scheitert apt, bleibt ein begonnener Zustand, den `khli-php56 uninstall` aufräumt.

## Nutzung

- Im Panel bei der Domain die PHP-Version 5.6 wählen. KeyHelp schreibt dann selbst den Pool `/opt/keyhelp/php/5.6/etc/php-fpm.d/<BENUTZER>_php56.conf`, stellt den VHost auf den Socket `/run/php/keyhelp_<BENUTZER>_php56.socket` um und startet `keyhelp-php56-fpm`.
- Kommandozeile: `keyhelp-php56` (Verknüpfung auf `/opt/keyhelp/php/5.6/bin/php`).
- Nach einem Neustart startet KeyHelp den Dienst selbst, sobald eine Domain ihn braucht (auf dem Testserver nach rund 40 Sekunden).
- Umzug einer Website von einem Debian-12-Server: die PHP-Einstellungen der Domain im Panel mitnehmen. Grenzen wie `memory_limit` oder `upload_max_filesize`, gesperrte Funktionen, `short_open_tag` und die Schalter der Sitzungs-Cookies gehören in KeyHelp zur Domain und stehen in ihrem Pool, nicht im Interpreter. Mit KeyHelps Vorgaben statt der bisherigen Einstellungen kann eine alte Anwendung anders laufen.
- Gettext: Die Sprache über die Umgebungsvariable `LANGUAGE` zu wählen, wirkt unter Debian 13 im Gebietsschema C.UTF-8 nicht (glibc 2.41); Anwendungen sollten ein Sprachgebietsschema wie `de_DE.UTF-8` setzen. Das gilt für jede PHP-Fassung unter Debian 13.

## Prüfen

`khli-php56 check` meldet:

- ob der Zustand vollständig ist, der Ergänzungssatz unverändert und die sieben geänderten Dateien den installierten Stand haben
- ob alle Programme, Erweiterungen und privaten Bibliotheken ihre Bibliotheken finden; scheitert `ldd` an einer Datei selbst, etwa weil sie beschädigt ist, ist auch das ein Befund
- ob `php -m` mit Exit 0 und ohne Startfehler endet, die Grundmodule (Core, date, pcre, Reflection, SPL, standard) nennt und kein Modul fehlt, das bei der letzten erfolgreichen Prüfung da war (Liste `/var/lib/khli-php56/module.txt`, gilt für dasselbe Originalpaket); ein Modul mehr ist kein Befund
- ob die FPM-Konfiguration gültig ist (ohne Domain gibt es keinen Pool, das ist wie unter Debian 12)
- ob Startskript und Befehl vorhanden sind und der Dienst läuft, wenn KeyHelp Pools angelegt hat
- als Hinweis, nicht als Befund: ob KeyHelps automatisches Update für 5.6 wieder eingeschaltet ist (etwa im Panel) oder `config.ini` fehlt; `update` schaltet es wieder aus

Die Modulliste, mit der `check` vergleicht, entsteht bei jeder Installation und jedem vollen Aufbau durch `update` aus dem Originalarchiv. Wer bewusst ein Modul abschaltet (etwa eine Datei in `etc/conf.d` entfernt), hält das mit `khli-php56 check --module-merken` fest; das nimmt fehlende Module als gewollt abgeschaltet auf, aber nie ein zusätzliches. Module, die eine eigene ini-Datei zusätzlich lädt, kommen so nie in die Liste: `update` übernimmt solche Dateien nicht (sie stehen in der Sicherung und in seiner Meldung), und sie sollen ein `update` nicht aufhalten.

Die tägliche Prüfung läuft um 7:40 Uhr, nach KeyHelps Wartungsjob `php-update`, als `khli-php56 check --cron`: ohne Befund keine Ausgabe, mit Befund eine Mail an root (über cron) und ein Eintrag im Systemprotokoll (`journalctl -t khli-php56`). Hinweise allein lösen keine Mail aus. Exit 1 bedeutet Befunde.

Endet der FPM-Dienst von außen, startete KeyHelp ihn auf dem Testserver nicht von selbst wieder. Die Prüfung meldet dann „Dienst keyhelp-php56-fpm läuft nicht, obwohl KeyHelp Pools angelegt hat"; Abhilfe: `systemctl restart keyhelp-php56-fpm` (nicht `start`, systemd hält den Dienst noch für aktiv).

## Aktualisieren

`bash install.sh` mit demselben Befehl wie bei der Installation; es startet `khli-php56.sh update` mit dem Ergänzungssatz des Releases.

- Ältere Fassung: Ist eine neuere installiert, verweigert `update` (Exit 5), auch wenn der Installer direkt aufgerufen wird; geprüft wird unter der Sperre. `--aelter-erlauben` spielt sie trotzdem ein.
- Leichter Zweig: Sind Originalpaket und Ergänzungssatz gleich geblieben und ist `check` in Ordnung, erneuert `update` nur Prüfwerkzeug und Zustand und schaltet KeyHelps automatisches Update aus, falls es wieder an ist (vorher Sicherung von `etc/`, `config.ini` und Protokollen). Interpreter und Dienst bleiben unberührt. `bash install.sh -- --neu-aufbauen` baut trotzdem neu auf.
- Voller Zweig: `update` baut den neuen Ordner neben dem alten, sichert `etc/`, `config.ini` und Protokolle nach `/var/log/khli-php56/sicherung-<zeit>-update.tar.gz` und hält den Dienst an. Läuft er danach noch (bis zu zehn Sekunden gewartet), oder fehlt sein Startskript `/etc/init.d/keyhelp-php56-fpm`, während er läuft, tauscht `update` nicht und endet mit Exit 1; der bisherige Interpreter läuft dann weiter. Sonst übernimmt es Pools, Zeitzone, `config.ini` und Protokolle, tauscht die Ordner, startet den Dienst neu und führt KeyHelps `install.sh` aus, wie KeyHelps `php-update`. Als bestätigt gilt der Tausch erst, wenn `check` in Ordnung ist und danach Prüfwerkzeug, Fassung und Modulliste erneuert sind; ein fremdes Prüfwerkzeug oder eine nicht geschriebene Modulliste melden dabei nur eine Warnung. Bricht der Lauf vor der Bestätigung ab, legt die Rücknahme auch Prüfwerkzeug und tägliche Prüfung zurück.
- Rücknahme: Meldet `check` danach Befunde (auch ein fehlendes Modul) oder startet der Dienst nicht, kommt der alte Ordner zurück (Exit 1). Ebenso, wenn der Lauf während des Tauschs durch ein Signal abbricht, auch durch HUP an die ganze Prozessgruppe, wie beim Abriss einer SSH-Sitzung mit Terminal (Exit 129, 130, 141 oder 143). Hält `stop` den neuen Dienst in der Rücknahme nicht an, beendet der Installer dessen Hauptprozess aus der PID-Datei; läuft er dann noch, bleibt der Arbeitsordner mit dem neuen Ordner zur Untersuchung. Als „bisheriger Stand wiederhergestellt" meldet der Installer die Rücknahme nur, wenn auch Zustand und ELF-Tabelle zurückgeschrieben sind und der Dienst wieder läuft; sonst sagt er, was fehlt, setzt den Zustand auf fehlerhaft und endet mit Exit 1. Pakete, die das `update` installiert hat, und Dateien, die KeyHelps `install.sh` außerhalb des Ordners schreibt, nimmt die Rücknahme nicht zurück. Reißt eine Sitzung ohne Terminal ab, kommt kein Signal: der Lauf geht zu Ende und schreibt weiter ins Protokoll. Nach SIGKILL oder Stromausfall holt der nächste `update` den bisherigen Ordner zurück, wenn das Ziel fehlt; sonst bleibt er mit einer Warnung liegen, bis `uninstall` ihn entfernt. `install.sh` wartet, bis der Installer fertig ist, und reicht seinen Exit-Code weiter.
- Die Domains bleiben auf 5.6; ihre Websites sind einige Sekunden nicht erreichbar (auf dem Testserver gemessen: unter einer Sekunde, etwa 3 von 599 Abrufen mit HTTP 503).
- Änderungen von Hand an `etc/php.ini` oder `etc/conf.d` übernimmt `update` nicht, wie KeyHelps eigenes Update; sie stehen in der Sicherung, und `update` nennt die betroffenen Dateien.

KeyHelp bietet 5.6 für Debian 13 nicht an und aktualisiert es deshalb nicht; zudem steht sein Schalter für das automatische Update von 5.6 auf aus, und das Panel zeigt ihn so. Ob KeyHelps `php-update` den Schalter beachtet, ist nicht beobachtet; das würde nur zählen, wenn KeyHelp für Debian 13 je ein 5.6-Paket anböte.

## Rückbau

`khli-php56 uninstall`

- prüft vorher, ob 5.6 an diesen Stellen genutzt wird: in KeyHelps Datenbank (Domains, geplante Aufgaben, Standard-Interpreter), Pools von KeyHelp für 5.6, Crontabs, die `keyhelp-php56` oder `/opt/keyhelp/php/5.6/` aufrufen, und systemd-Units unter `/etc/systemd/system` und `/usr/local/lib/systemd/system`; dann verweigert er mit Exit 5. Scheitert die Prüfung selbst, etwa ohne Zugriff auf die Datenbank, verweigert er ebenfalls. Andere Aufrufe, etwa aus eigenen Skripten oder Programmen, erkennt er nicht. `--trotz-domains` übergeht die Prüfung; betroffene Websites haben danach kein PHP mehr.
- verweigert auch, wenn `/opt/keyhelp/php/5.6` den Ergänzungssatz nicht enthält, also nicht von diesem Installer stammt (`--trotz-fremdem-ordner` entfernt ihn trotzdem)
- sichert `etc/`, `config.ini` und Protokolle nach `/var/log/khli-php56/sicherung-<zeit>-uninstall.tar.gz`
- holt zuerst einen bisherigen Ordner aus dem Rest eines abgebrochenen Updates zurück, wenn das Ziel fehlt
- vermerkt den begonnenen Rückbau im Zustand: Bricht er ab, setzt der nächste `uninstall` ihn fort, und `update` verweigert bis dahin
- führt KeyHelps `uninstall.sh` aus und räumt Startskript, Befehl, Ordner, Prüfwerkzeug, tägliche Prüfung und Reste abgebrochener Läufe nach
- entfernt die Pakete, die der Installer selbst installiert hat, mit `dpkg --purge`, das kein Paket entfernt, von dem ein anderes abhängt. Es bleiben Pakete, die inzwischen von Hand installiert wurden, gehaltene Pakete und alles, was sie brauchen, Pakete, die andere brauchen, solche, deren Bibliotheken KeyHelps übrige Interpreter laden, und solche, die während KeyHelps `install.sh` dazukamen. Entfernt wird nur, was die Installation selbst geplant hat; ein Zustand aus einer Fassung bis 0.4.15 kann Pakete aus dem Lauf von KeyHelps `install.sh` als eigene führen, sie bleiben mit einem Hinweis stehen. Bleiben Pakete stehen, die entfernt werden sollten, stehen sie in `/var/log/khli-php56/pakete-nicht-entfernt-<zeit>.txt`, und `uninstall` endet mit Exit 1. `--pakete-behalten` lässt alle Pakete stehen.

Nicht umkehrbar ist nur, wenn apt beim Installieren ein vorhandenes Paket auf eine neuere Fassung gehoben hat (beobachtet bei einem Sicherheitsupdate von `liblzma5`; kein Eingriff nötig; der Installer nennt solche Pakete). Protokolle und Sicherungen unter `/var/log/khli-php56/` bleiben nach dem Rückbau; sie gehören root (Modus 750 und 600).

## Was sich am System ändert

| Änderung | Ort | Rückbau |
|---|---|---|
| KeyHelps Interpreterpaket, aus dem unveränderten Archiv entpackt | `/opt/keyhelp/php/5.6/` | `uninstall` über KeyHelps `uninstall.sh` |
| Ergänzungssatz mit privaten Bibliotheken | `/opt/keyhelp/php/5.6/lib/khli/` | mit dem Ordner |
| RUNPATH in sieben ELF-Dateien, in `ssh2.so` dazu `NEEDED libssh2-khli.so.1`; alte und neue SHA-256 im Zustand | im Interpreterordner, `/var/lib/khli-php56/elf-aenderungen.tsv` | mit dem Ordner |
| Laufzeitpakete aus Debian 13, nur wenn sie fehlen | Paketverwaltung | `uninstall`, mit den Ausnahmen oben |
| Prüfwerkzeug (Kopie des Installers) | `/usr/local/sbin/khli-php56` | `uninstall` |
| tägliche Prüfung | `/etc/cron.d/khli-php56` (7:40 Uhr, nur lesend) | `uninstall` |
| KeyHelps Schalter für das automatische Update von 5.6 aus | `/opt/keyhelp/php/5.6/keyhelp-setup/config.ini` | mit dem Ordner; die bisherige Datei steht in der Sicherung |
| Startskript, Befehl `keyhelp-php56`, Zeitzone | durch KeyHelps eigenes `install.sh` | KeyHelps `uninstall.sh`, danach Nachlese des Installers |
| Sicherungen vor `update` und `uninstall` | `/var/log/khli-php56/sicherung-*.tar.gz` (0600) | bleiben bewusst |
| Zustand mit Modulliste, festgehaltenem Release-Schlüssel und Generation der Freigabeliste; Protokolle, Protokoll von `install.sh` | `/var/lib/khli-php56/` (0700), `/var/log/khli-php56/` (0750) | Zustand mit `uninstall`, Protokolle bleiben |
| Sperrdatei | `/run/khli-php56.lock` | bis zum nächsten Neustart |

Nicht geändert werden Systembibliotheken, die Standard-PHP-Version, `/etc/ld.so.conf.d` sowie die Konfiguration von Apache und KeyHelp (die schreibt KeyHelp selbst).

## Exit-Codes

| Code | Bedeutung |
|---|---|
| 0 | Erfolg |
| 1 | Fehler: etwa ein Download, ein anderer Lauf aktiv, Prüfung nach Installation oder Update mit Befunden, Dienst ließ sich nicht anhalten, Rücknahme unvollständig, apt würde Pakete entfernen, Rückbau mit Paketen, die stehen blieben |
| 2 | falscher Aufruf, auch eine nicht erlaubte Option nach `--`; ausnahmsweise auch der Status eines Befehls, der im Installer unter `set -e` abbrach (`tar`, `sort`, `dpkg-query`, etwa bei voller Platte); dann steht seine Fehlermeldung im Protokoll |
| 3 | Signatur, Prüfsumme oder Aufbau eines Archivs falsch; Freigabeliste falsch signiert oder ohne Generation; anderer Release-Schlüssel als festgehalten, oder der festgehaltene ist nicht lesbar |
| 4 | Voraussetzung fehlt (nicht root, nicht Debian 13, kein KeyHelp, kein Schlüssel, Datei nicht gefunden, zu wenig Platz) |
| 5 | zum Schutz abgelehnt: 5.6 in Gebrauch, fremder Ordner, Nutzung nicht prüfbar, ältere Fassung über einer neueren; bei `install.sh` auch ein widerrufenes, nicht freigegebenes oder älteres Release und eine fehlende, abgelaufene oder ältere Freigabeliste oder eine nicht lesbare gespeicherte Generation |
| andere Werte unter 128 | Status eines Befehls, der im Installer unter `set -e` abbrach, etwa 100 von `apt-get` bei einer fehlerhaften Paketquelle; seine Fehlermeldung steht im Protokoll |
| 129, 130, 141, 143 | abgebrochen durch HUP, INT (Strg+C), PIPE oder TERM; kam das Signal während des Tauschs eines `update`, ist der bisherige Stand zurückgeholt; bei `uninstall` diesen wiederholen |

## Fehlersuche

| Meldung | Ursache | Abhilfe |
|---|---|---|
| `install.sh: FEHLER: die Signatur von SHA256SUMS ist ungültig` | Release verändert oder nicht von Retrowork | nichts installieren; Herkunft prüfen ([signatur.md](signatur.md)) |
| `install.sh: FEHLER: dieses install.sh enthält keinen öffentlichen Schlüssel` | `install.sh` aus dem Repository statt aus einem Release | das `install.sh` aus einem Release nehmen |
| `install.sh: FEHLER: Download gescheitert: …/SHA256SUMS (gibt es das Release?)` | kein Netz, GitHub nicht erreichbar oder das Release gibt es nicht | Netz prüfen, `--version` prüfen, sonst `--quelle` |
| `install.sh: FEHLER: zweiter Kanal … nicht erreichbar` | Domain des zweiten Kanals nicht erreichbar | später noch einmal; ohne Prüfung der Freigabe nur mit `--ohne-zweiten-kanal` |
| `install.sh: FEHLER: die Freigabeliste auf dem zweiten Kanal hat keine gültige Signatur` | Liste wird gerade erneuert oder ist verändert | später noch einmal; bleibt es, Retrowork melden |
| `install.sh: FEHLER: die Freigabeliste ist seit … abgelaufen` | Retrowork hat die Liste nicht rechtzeitig erneuert, oder die Uhr des Servers geht falsch | `date -u` prüfen; sonst Retrowork melden und bis dahin `--ohne-zweiten-kanal` |
| `install.sh: FEHLER: der festgehaltene Schlüssel … ist nicht lesbar` | die Datei `/var/lib/khli-php56/release-ed25519.pub` ist leer oder beschädigt, etwa nach einem vollen Datenträger | Fingerabdruck des Releases prüfen ([signatur.md](signatur.md)), dann `--neuer-schluessel` |
| `install.sh: FEHLER: die gespeicherte Generation … ist nicht lesbar` | die Datei `/var/lib/khli-php56/freigaben-generation` ist beschädigt | Inhalt prüfen; ohne die Datei gilt jede gültige Liste wieder als neu |
| `install.sh: FEHLER: … kannte schon die Generation …` | der zweite Kanal liefert eine ältere Liste, als der Server schon kannte | nichts installieren; Retrowork melden |
| `install.sh: FEHLER: Release … steht nicht in der Freigabeliste` | Release noch nicht freigegeben oder nicht von Retrowork | später noch einmal; ein anderes Release wählen |
| `install.sh: FEHLER: Release … ist widerrufen` | Retrowork hat das Release zurückgezogen | ein anderes Release wählen |
| `install.sh: FEHLER: dieser Server vertraut dem Release-Schlüssel …` | `install.sh` mit einem anderen Schlüssel, etwa aus einer Abspaltung | das `install.sh` von Retrowork nehmen; nach einem angekündigten Wechsel `--neuer-schluessel` |
| `install.sh: FEHLER: Option für den Installer nicht erlaubt` | nach `--` steht eine andere Option als die drei erlaubten | Aufruf prüfen |
| `SHA-256 von … ist …, erwartet …` | falsche oder beschädigte Datei | Datei neu laden; die Prüfung nie umgehen |
| `… existiert und stammt nicht von khli-php56` | 5.6 von anderer Stelle installiert | vorhandenen Stand selbst entfernen oder behalten |
| `es gibt schon einen Zustand …` | vorhandene oder abgebrochene Installation | `update` oder `uninstall` |
| `ein anderer Lauf von khli-php56 ist aktiv` | zweiter Lauf gleichzeitig | den ersten abwarten |
| `installiert ist khli-php56 …, diese Fassung … ist älter` | ältere Fassung über einer neueren | ein neueres Release nehmen; bewusst nur mit `--aelter-erlauben` |
| `apt würde für … diese Pakete entfernen` | ein Paketkonflikt auf dem Server | den Konflikt selbst lösen, dann erneut; nichts installiert, ein begonnener Zustand mit `uninstall` aufräumen |
| `Dienst keyhelp-php56-fpm ließ sich nicht anhalten; nichts getauscht` | der FPM-Dienst reagiert nicht auf `stop`, oder sein Startskript fehlt (dann steht davor „über das Startskript lässt er sich nicht anhalten") | Prozesse von `keyhelp-php56-fpm` prüfen; fehlt das Startskript, legt KeyHelps `install.sh` es an (`bash /opt/keyhelp/php/5.6/keyhelp-setup/install.sh`); dann erneut |
| `bisheriger Ordner zurückgelegt, aber nicht vollständig wiederhergestellt: …` | in der Rücknahme fehlte etwas (Anhalten, Zustand, ELF-Tabelle, Prüfwerkzeug, Cron-Datei oder Dienst) | `khli-php56 check`; dann `bash install.sh -- --neu-aufbauen` |
| `KeyHelp nutzt PHP 5.6: …` | Domains, Aufgaben oder Standard-Interpreter auf 5.6 | im Panel umstellen, dann erneut `uninstall` |
| `… systemd-Unit-Datei(en) rufen PHP 5.6 auf` | eigene Dienste oder Timer nutzen 5.6 | diese umstellen, dann erneut `uninstall` |
| `check: lib/khli fehlt (Interpreter von KeyHelp ersetzt?)` | der Ordner wurde von außen ersetzt | `bash install.sh -- --trotz-fremdem-ordner` stellt den Stand dieses Projekts wieder her |
| `check: … findet nicht: …` | Bibliothek fehlt | `bash install.sh -- --neu-aufbauen`; Laufzeitpakete prüfen |
| `check: ldd scheitert an …` | Datei beschädigt | `bash install.sh -- --neu-aufbauen` |
| `check: php -m endet mit Exit …` | PHP stürzt beim Start ab | Protokoll und `etc/conf.d` prüfen, dann `bash install.sh -- --neu-aufbauen` |
| `check: gegenüber dem letzten Aufbau fehlen Module: …` | eine ini unter `etc/conf.d` fehlt oder eine Erweiterung lädt nicht | gewollt: `khli-php56 check --module-merken`; sonst `bash install.sh -- --neu-aufbauen`. Meldet es ein `update` und nimmt zurück, fehlt das Modul im neu aufgebauten Ordner: das Protokoll zeigt, warum |
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
- Der Installer prüft, ob KeyHelp da ist, aber nicht dessen Fassung; geprüft ist er mit KeyHelp 26.2 (Build 3756).
