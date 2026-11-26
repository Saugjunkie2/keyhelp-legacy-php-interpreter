# Changelog

Ein Release trägt die Version seines Installers. Neue Einträge oben. / A release carries the version of its installer. Newest entries first.

## 0.4.15 (2026-11-26)

Erstes öffentliches Release. / First public release.

- Installer `khli-php56.sh` 0.4.15, unverändert der freigegebene Stand des internen Projekts (SHA-256 `77f356fdca85fb9bb4bafa8137a33f2bdc109b614d2ef44b19044b02cca42559`). Sein Kopf enthält die Entwicklungsgeschichte mit Verweisen auf interne Prüfberichte (Kürzel wie `I-52`, `N31`, `E-0049`); diese Berichte sind nicht veröffentlicht. / Installer 0.4.15, unchanged from the approved state of the internal project; its header refers to internal review reports that are not published.
- Ergänzungssatz 1.1.0 als Datei im Release (SHA-256 `530f1a948e5b3e6f1472d91ee24b69d4240bcc57bf9abef09ffd3f589f656502`), Bauanleitungen unverändert unter `build/`, Quellpaket uw-imap unter `fremdquellen/`. / Supplement 1.1.0 as a release file, build recipes unchanged in `build/`, uw-imap source package in `fremdquellen/`.
- KeyHelps Paket `php_5.6.40_20261103164601.tar.gz` (SHA-256 `4ee240d31be9f1cc5cba853728b3bc6fe4aceaa18a1a0a3dafd0d282dbf5b6c6`) wird beim Nutzer von `repo.keyhelp.de` geladen. / KeyHelp's package is downloaded on the user's server.
- Neu: `install.sh` 1.0.0, Installation und Update mit einem Befehl, prüft die Ed25519-Signatur, jede Datei, Widerrufe auf dem zweiten Kanal und ältere Releases. / New: one-command installation and update with signature, checksum, revocation and downgrade checks.
- Neu: Werkzeuge 1.0.0 unter `werkzeuge/` (Schlüssel erzeugen, Release bauen, signieren und prüfen, Freigabeliste) und Tests unter `tests/`. / New: release tools and tests.
- Öffentlicher Schlüssel `schluessel/release-ed25519.pub`, Fingerabdruck `SHA256:6db970b09f586927f6f216b317c831261b95b254e29219d2a402e4c30d4a6c41`. / Public key and its fingerprint.

## Geplant / Planned

- Automatische Updates: Prüfen und Einspielen neuer signierter Releases auf dem Server, im Zeitfenster der Zeile „PHP-Interpreter aktualisieren" in KeyHelps Wartungsaufgaben, gegen den auf dem Server liegenden Schlüssel. / Automatic updates within KeyHelp's maintenance window, verified against the key on the server.
- Die tägliche Prüfung vergleicht die installierten Dateien mit dem signierten Manifest. / The daily check compares installed files with the signed manifest.
- Eigener Bau von PHP 5.6 mit Sicherheitskorrekturen als `5.6.40-<N>+retrowork`, ohne Abhängigkeit von fremden Paketquellen zur Laufzeit. / Own PHP 5.6 build with security fixes as `5.6.40-<N>+retrowork`.
