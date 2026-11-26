# Mitmachen / Contributing

[Deutsch](#deutsch) | [English](#english)

## Deutsch

Issues und Pull Requests sind willkommen, auf Deutsch oder Englisch.

### Issues

- Bitte angeben: Debian-Fassung (`cat /etc/debian_version`), KeyHelp-Version und Build, Ausgabe von `khli-php56 status` und `khli-php56 check`, bei einem Abbruch die letzten Zeilen des Protokolls unter `/var/log/khli-php56/`.
- Keine Kundendaten, Domains, IP-Adressen, Kennwörter oder Schlüssel in Issues. Platzhalter wie `<DOMAIN>`, `<BENUTZER>` und `<IP>` nutzen.
- Sicherheitslücken nicht als Issue, sondern wie in [SECURITY.md](SECURITY.md).

### Grundsätze für Änderungen

- PHP 5.6 bleibt in seinem Verhalten, wie es unter Debian 12 war. Erlaubt sind Sicherheits- und Absturzkorrekturen und die Anpassung an Bibliotheken; Änderungen im Verhalten nur als begründete, dokumentierte Ausnahme.
- Keine Dateien von KeyHelp in diesem Repository oder in einem Release. Der Installer lädt KeyHelps Paket beim Nutzer von KeyHelps Originalquelle.
- Fremde Quellen nur mit Herkunft, Lizenz und SHA-256.
- Jede geänderte Fassung eines Skripts bekommt eine neue Versionsnummer in ihrem Kopf und einen Eintrag in [CHANGELOG.md](CHANGELOG.md).
- Aussagen in Dokumenten nennen, wie sie geprüft sind (etwa „auf einem Testserver real getestet", „in einer Chroot", „abgeleitet").

### Technisches

- Bash mit `set -euo pipefail`, Meldungen auf Deutsch; Dateien mit LF-Zeilenenden (`.gitattributes` erzwingt das).
- Vor einem Pull Request: `bash tests/werkzeuge-test.sh` (unter Linux oder Git Bash; Teil B läuft nur als root unter Debian 13, etwa in einer Chroot). Wer einen Testserver mit KeyHelp hat: `bash tests/ende-zu-ende.sh --testserver <ergaenzungssatz>`.
- Änderungen am Installer oder am Ergänzungssatz brauchen zusätzlich die Installations-, Rückbau- und Funktionstests aus [docs/bau.md](docs/bau.md). Sie laufen bisher in der internen Projektumgebung von Retrowork; ein Pull Request dazu wird vor dem Release dort geprüft.
- Offiziell wird eine Änderung erst mit einem von Retrowork signierten Release.

### Lizenz der Beiträge

Mit einem Pull Request gilt der Beitrag unter der Apache License 2.0 dieses Repositorys (Abschnitt 5 der Lizenz).

## English

Issues and pull requests are welcome, in German or English.

### Issues

- Please include: Debian version (`cat /etc/debian_version`), KeyHelp version and build, output of `khli-php56 status` and `khli-php56 check`, and after an abort the last lines of the log under `/var/log/khli-php56/`.
- No customer data, domains, IP addresses, passwords or keys in issues. Use placeholders such as `<DOMAIN>`, `<BENUTZER>` and `<IP>`.
- Security issues not as an issue but as described in [SECURITY.md](SECURITY.md).

### Principles for changes

- PHP 5.6 keeps behaving as it did on Debian 12. Allowed are security and crash fixes and adaptations to libraries; changes in behaviour only as a justified, documented exception.
- No KeyHelp files in this repository or in a release. The installer downloads KeyHelp's package on the user's server from KeyHelp's official source.
- Third-party sources only with origin, license and SHA-256.
- Every changed version of a script gets a new version number in its header and an entry in [CHANGELOG.md](CHANGELOG.md).
- Statements in documents say how they were verified (for example "tested on a real test server", "in a chroot", "derived").

### Technical notes

- Bash with `set -euo pipefail`, messages in German; files with LF line endings (enforced by `.gitattributes`).
- Before a pull request: `bash tests/werkzeuge-test.sh` (on Linux or Git Bash; part B only runs as root on Debian 13, for example in a chroot). With a KeyHelp test server: `bash tests/ende-zu-ende.sh --testserver <supplement>`.
- Changes to the installer or the supplement additionally need the installation, removal and functional tests described in [docs/en/building.md](docs/en/building.md). So far they run in Retrowork's internal project environment; a pull request touching them is checked there before a release.
- A change becomes official only with a release signed by Retrowork.

### License of contributions

By opening a pull request, the contribution is licensed under this repository's Apache License 2.0 (section 5 of the license).
