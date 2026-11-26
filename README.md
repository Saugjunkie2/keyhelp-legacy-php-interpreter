# keyhelp-legacy-php-interpreter

PHP 5.6 für KeyHelp unter Debian 13 (amd64). Ein Projekt von Retrowork.

[English version](README.en.md)

KeyHelp bietet PHP 5.6 nur bis Debian 12 an. Dieses Projekt richtet KeyHelps eigenen PHP-5.6-Interpreter für Debian 12 auf einem KeyHelp-Server mit Debian 13 ein. Er erscheint danach im Panel wie die offiziellen Interpreter, lässt sich je Domain wählen und behält die Funktionen, die er unter Debian 12 hat.

> **Stand:** Release [0.4.15](https://github.com/Saugjunkie2/keyhelp-legacy-php-interpreter/releases/tag/v0.4.15) vom 26.11.2026 ist das erste öffentliche Release. Die Fassung 0.4.17 mit den Korrekturen aus einer Drittprüfung und einer zweiten, unabhängigen Gegenprüfung ist in Vorbereitung; dieses Repository zeigt schon ihren Stand ([CHANGELOG.md](CHANGELOG.md)). Installiert wird mit dem `install.sh` aus einem Release (Befehl unten); das `install.sh` in diesem Repository enthält absichtlich keinen Schlüssel.

## Wichtig vorab

- PHP 5.6 erhält seit dem 31.12.2018 keine Sicherheitskorrekturen von php.net. Es ist für Altanwendungen gedacht, die sich nicht umstellen lassen, nicht für neue Projekte. Siehe [SECURITY.md](SECURITY.md) und [Bekannte Grenzen](docs/betrieb.md#bekannte-grenzen).
- Dies ist ein unabhängiges Projekt von Retrowork. Es wird nicht von der Keyweb AG (KeyHelp) oder von der PHP Group herausgegeben.
- Das Projekt gibt keine Dateien von KeyHelp weiter. Der Installer lädt KeyHelps Paket auf dem Server von KeyHelps Originalquelle `repo.keyhelp.de` und prüft dessen SHA-256.

## Was es macht

- entpackt KeyHelps PHP-5.6-Paket für Debian 12 (`php_5.6.40_20261103164601.tar.gz`) aus dem unveränderten Originalarchiv nach `/opt/keyhelp/php/5.6`
- passt nur an, was Debian 13 verlangt: sechs Bibliotheken aus den Quellständen von Debian 12 (der Ergänzungssatz) unter `/opt/keyhelp/php/5.6/lib/khli`, ein angepasster Suchpfad (RUNPATH) in sieben Dateien (sechs Erweiterungen und die gebündelte ICU), in `ssh2.so` dazu der Name der privaten libssh2, und fehlende Laufzeitpakete aus Debian 13; die Programme `php`, `php-cgi` und `php-fpm` bleiben KeyHelps Dateien
- führt danach KeyHelps eigenes Einrichtungsskript aus, wie es KeyHelps Wartungsjob `php-update` tut
- ersetzt keine Systembibliothek, entfernt bei der Installation kein Paket und ändert die Standard-PHP-Version nicht
- schaltet KeyHelps automatisches Update für 5.6 aus, weil KeyHelp für Debian 13 kein 5.6-Paket hat; Aktualisierungen kommen aus diesem Projekt
- richtet das Prüfwerkzeug `khli-php56` und eine tägliche Prüfung ein

## Voraussetzungen

- Debian 13 (amd64) mit installiertem KeyHelp; geprüft mit KeyHelp 26.2 (Build 3756)
- Zugang als root, Internetzugang zu `github.com`, `lizenz.retrowork.de`, `repo.keyhelp.de` und den Debian-Spiegeln
- rund 400 MB frei unter `/opt`, für ein Update rund 700 MB, dazu 200 MB unter `/var/tmp`
- `openssl` und `curl` oder `wget` (auf KeyHelp-Servern vorhanden)

## Installation

Als root auf dem Server:

```bash
curl -fsSL https://github.com/Saugjunkie2/keyhelp-legacy-php-interpreter/releases/latest/download/install.sh | bash
```

`install.sh` prüft die Signatur des Releases und jede Datei, fragt den zweiten Kanal nach der Freigabe und startet erst dann den Installer. Ohne gültige Signatur oder Freigabe ändert es nichts; nur `--ohne-zweiten-kanal` lässt die Freigabe und damit auch einen Widerruf ungeprüft. Danach im Panel bei der Domain die PHP-Version 5.6 wählen.

Dieser Befehl vertraut GitHub und der verschlüsselten Verbindung dorthin: Ein manipuliertes `install.sh` könnte jede Prüfung weglassen. Wer das nicht will, prüft `install.sh` vor dem Start mit dem Schlüssel vom zweiten Kanal. Unabhängig von GitHub ist das nur, wenn der folgende Block von der Seite des zweiten Kanals stammt (https://lizenz.retrowork.de/keyhelp-legacy-php-interpreter/), denn dieses README liegt selbst auf GitHub; dort steht derselbe Block:

```bash
cd "$(mktemp -d)"
basis=https://github.com/Saugjunkie2/keyhelp-legacy-php-interpreter/releases/latest/download
curl -fsSLO "$basis/install.sh" && curl -fsSLO "$basis/SHA256SUMS" && curl -fsSLO "$basis/SHA256SUMS.sig" &&
curl -fsSL -o release-ed25519.pub https://lizenz.retrowork.de/keyhelp-legacy-php-interpreter/release-ed25519.pub &&
openssl pkey -pubin -in release-ed25519.pub -outform DER | sha256sum | grep -q '^6db970b09f586927f6f216b317c831261b95b254e29219d2a402e4c30d4a6c41 ' &&
openssl pkeyutl -verify -pubin -inkey release-ed25519.pub -rawin -in SHA256SUMS -sigfile SHA256SUMS.sig &&
sha256sum --ignore-missing -c SHA256SUMS &&
bash install.sh
```

Jeder Schritt muss gelingen, sonst bricht die Kette ab und nichts startet: Download, Fingerabdruck des Schlüssels vom zweiten Kanal, Signatur von `SHA256SUMS` (Ausgabe `Signature Verified Successfully`), SHA-256 von `install.sh` (Ausgabe `install.sh: OK`).

Weitere Optionen zeigt `bash install.sh --hilfe`. Ein Server ohne Internet bekommt das Release mit `--nur-laden <ordner>` auf einem anderen Rechner und `--quelle <ordner>` auf dem Server; er braucht dann außerdem KeyHelps Paket als Datei, die Laufzeitpakete aus Debian 13 (schon installiert oder über einen eigenen Spiegel) und `--ohne-zweiten-kanal` ([docs/betrieb.md](docs/betrieb.md#ohne-internet)).

KeyHelp könnte sein 5.6-Paket für Debian 12 eines Tages entfernen. Wer vorsorgen möchte, bewahrt eine Kopie auf und gibt sie bei Bedarf mit `bash install.sh -- --original <datei>` an; der Installer prüft auch sie gegen den eingetragenen SHA-256 ([docs/betrieb.md](docs/betrieb.md#originalpaket-aufbewahren)).

## Aktualisieren

Derselbe Befehl wie bei der Installation spielt das neueste Release ein (`update`). Ein älteres Release über ein neueres spielt `install.sh` nur mit `--aelter-erlauben` ein. Die 5.6-Websites sind beim Tausch einige Sekunden nicht erreichbar; misslingt etwas, holt der Installer den bisherigen Stand zurück und sagt, ob das vollständig gelang. Automatische Updates sind geplant, siehe [CHANGELOG.md](CHANGELOG.md).

## Prüfen, Status, Entfernen

```bash
khli-php56 check      # Dateien, Bibliotheken, Module, FPM-Konfiguration und Dienst
khli-php56 status     # Version, Zustand und Dienst
khli-php56 uninstall  # vollständiger Rückbau; verweigert, solange eine der geprüften Stellen 5.6 nutzt
```

`uninstall` erkennt die Nutzung durch KeyHelp (Domains, geplante Aufgaben, Standard-Interpreter, Pools), durch Crontabs und durch systemd-Units, nicht aber Aufrufe aus eigenen Skripten. Einzelheiten, Exit-Codes und Fehlersuche: [docs/betrieb.md](docs/betrieb.md).

## Manipulationsschutz

Jedes Release enthält `SHA256SUMS` mit den SHA-256 aller Dateien und `SHA256SUMS.sig`, eine Ed25519-Signatur darüber. Den privaten Schlüssel hat nur Retrowork; er liegt in keinem Repository. Offiziell ist nur, was mit diesem Schlüssel signiert ist.

Fingerabdruck des öffentlichen Schlüssels [`schluessel/release-ed25519.pub`](schluessel/release-ed25519.pub) (SHA-256 über den Schlüssel in DER-Form):

```
SHA256:6db970b09f586927f6f216b317c831261b95b254e29219d2a402e4c30d4a6c41
```

Derselbe Fingerabdruck und der Schlüssel stehen auf dem zweiten Kanal `https://lizenz.retrowork.de/keyhelp-legacy-php-interpreter/`, zusammen mit der signierten Liste der freigegebenen und der widerrufenen Releases. Ab `install.sh` 1.1.0 sperrt der zweite Kanal im Zweifel: Ist die Liste nicht erreichbar, falsch signiert, abgelaufen oder älter als eine schon bekannte, oder steht das Release nicht als freigegeben darin, startet nichts. Der Server hält außerdem den Schlüssel seiner ersten Installation fest und nimmt ein `install.sh` mit anderem Schlüssel nur nach einem angekündigten Wechsel an. Einzelheiten und Grenzen: [docs/signatur.md](docs/signatur.md).

## Was geprüft ist

Die Zahlen gelten für Release 0.4.15 (Installer 0.4.15, `install.sh` 1.0.0). Die Tests der Fassung 0.4.17 laufen; ihre Zahlen stehen hier mit dem Release.

| Prüfung | Ergebnis | Wie geprüft |
|---|---|---|
| Funktionsvergleich mit KeyHelps 5.6 unter Debian 12 | 2.066 Prüfpunkte gleich, 15 begründete Ausnahmen, keine unbegründete; der Test über cli, cgi und fpm liefert byte-gleiche Ausgaben wie unter Debian 12 | auf einem Testserver mit Debian 13 und KeyHelp, Referenz in einer Debian-12-Umgebung |
| Installer: Installation, Update, Rückbau und 58 Fehler- und Abbruchfälle | alle wie erwartet; nach dem Rückbau gleicher Paketstand wie vorher | in einer minimalen Debian-13-Umgebung (Chroot) |
| Einsatz unter KeyHelp | 5.6 im Panel wählbar, KeyHelp legt Pool und VHost an und startet den Dienst; Websites, Neustart, KeyHelps Wartungsjobs; Update mit unter einer Sekunde Ausfall | auf dem Testserver; Sichtprüfung im Panel durch Retrowork |
| ionCube- und SourceGuardian-Loader | laden und arbeiten wie unter Debian 12, auch mit einer 2010 für PHP 5 verschlüsselten Anwendungsdatei | in Chroots und auf dem Testserver |
| `install.sh` und die Werkzeuge für Releases | Signatur, Prüfsummen, Widerruf, ältere Releases und Start des Installers in 90 Fällen wie erwartet; ein signiertes Test-Release über sein `install.sh` als Update eingespielt, im leichten und im vollen Zweig, danach `check` und die Website in Ordnung; das veröffentlichte Release 0.4.15 mit dem Befehl aus diesem README von GitHub eingespielt, Signatur und Freigabeliste gültig | unter Windows (Git Bash) und als root in einer Debian-13-Chroot; Ende-zu-Ende auf dem Testserver ([tests/](tests/)) |

Die öffentliche CI (`.github/workflows/tests.yml`) führt die Tests von `install.sh` und den Werkzeugen unter Ubuntu und als root unter Debian 13 aus, prüft die Herkunft des Quellpakets uw-imap und täglich das veröffentlichte Release mit dem zweiten Kanal. Die Funktions- und Installertests laufen bisher auf einem Testserver von Retrowork; ihre Ergebnisse stehen hier, die Tests selbst noch nicht.

Nicht geprüft: ein Selbst-Update von KeyHelp auf eine neue Hauptversion; ob KeyHelps `php-update` den ausgeschalteten Schalter beachtet (nur wichtig, falls KeyHelp für Debian 13 je ein 5.6-Paket anböte); der Einsatz auf vielen verschiedenen Servern. Eine statische Drittprüfung vom 26.11.2026 nannte 25 Punkte; was daraus folgt, steht im [CHANGELOG.md](CHANGELOG.md).

## Bekannte Grenzen

Aus dem Original unter Debian 12 übernommen, mit Abhilfen in [docs/betrieb.md](docs/betrieb.md#bekannte-grenzen): `openssl_encrypt()` mit alten Verfahren (bf, cast5, rc4, des, seed) bringt den Prozess zum Absturz; imagick kann kein WebP, solange gd geladen ist; `tls://` heißt in PHP 5.6 TLS 1.0, besser `ssl://`; ssh2 meldet sich mit RSA-Schlüsseln nur über `ssh-rsa` (SHA-1) an, ECDSA- und Ed25519-Schlüssel gehen. Die privaten Bibliotheken bekommen Sicherheitsstände nur über ein neues Release dieses Projekts.

## Aufbau

```
install.sh                Installation mit einem Befehl, prüft Signatur, Dateien und Freigabe
installer/khli-php56.sh   der Installer: install, update, check, status, uninstall
build/                    Bauanleitungen des Ergänzungssatzes
fremdquellen/             Quellpaket uw-imap (Sury) und Surys signierte Indexe zum Nachprüfen
werkzeuge/                Release bauen, signieren und prüfen; Schlüssel; Freigabeliste; Herkunft prüfen
schluessel/               öffentlicher Schlüssel für die Signaturen
tests/                    Tests von install.sh, den Werkzeugen und dem veröffentlichten Release
docs/                     Betrieb, Signaturen und Bau, englisch unter docs/en/
.github/workflows/        öffentliche CI
```

Der Ergänzungssatz liegt nicht im Repository, sondern als Datei in jedem Release.

## Lizenz und Namen

Der eigene Code steht unter der [Apache License 2.0](LICENSE). Die Bibliotheken im Ergänzungssatz behalten ihre eigenen Lizenzen ([NOTICE](NOTICE), [docs/lizenzen.md](docs/lizenzen.md)). KeyHelps Paket ist nicht enthalten. Die Lizenz gibt kein Recht am Namen Retrowork: Veränderte Fassungen dürfen sich nicht als Release von Retrowork ausgeben. KeyHelp ist eine Marke der Keyweb AG, PHP eine Marke der PHP Group.

## Mitmachen

Issues und Pull Requests sind willkommen, auf Deutsch oder Englisch: [CONTRIBUTING.md](CONTRIBUTING.md). Sicherheitslücken bitte nicht öffentlich melden, sondern wie in [SECURITY.md](SECURITY.md) beschrieben.
