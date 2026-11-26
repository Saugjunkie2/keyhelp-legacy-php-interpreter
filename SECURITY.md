# Sicherheit / Security

[Deutsch](#deutsch) | [English](#english)

## Deutsch

### Was dieses Projekt verspricht und was nicht

- PHP 5.6 erhält seit dem 31.12.2018 keine Sicherheitskorrekturen von php.net. KeyHelps Build 5.6.40 enthält einzelne zurückportierte Korrekturen, aber bei weitem nicht alle bekannten. Lücken in PHP 5.6 selbst behebt dieses Projekt derzeit nicht; ein eigener Bau mit Sicherheitskorrekturen ist geplant.
- Der Interpreter ist KeyHelps unveränderte Datei. Die Lösung hat damit dieselben Schwachstellen wie KeyHelps 5.6 unter Debian 12.
- Die Isolation je Website (eigener FPM-Pool und Unix-Benutzer, `open_basedir`, gesperrte Funktionen) kommt aus KeyHelps Vorlagen, nicht aus diesem Projekt.
- Systembibliotheken wie OpenSSL, libxml2, libcurl und glibc kommen aus Debian 13 und erhalten dessen Sicherheitsupdates. Die privaten Bibliotheken im Ergänzungssatz erhalten Sicherheitsstände nur über ein neues Release.
- Releases sind mit Ed25519 signiert; `install.sh` installiert nichts ohne gültige Signatur ([docs/signatur.md](docs/signatur.md)).

PHP 5.6 gehört nur auf Server, deren Betreiber dieses Risiko bewusst tragen, für Altanwendungen, die sich nicht umstellen lassen.

### Unterstützte Fassungen

Nur das jeweils neueste Release erhält Korrekturen.

### Eine Lücke melden

Bitte nicht als öffentliches Issue. Wege:

1. über GitHub: [Sicherheitslücke privat melden](https://github.com/Saugjunkie2/keyhelp-legacy-php-interpreter/security/advisories/new)
2. falls das nicht geht: ein Issue ohne Einzelheiten mit der Bitte um Kontakt

Gemeldet werden können Fehler in `install.sh`, im Installer, in den Werkzeugen, im Ergänzungssatz und in der Signaturprüfung. Bekannte Lücken von PHP 5.6 selbst sind bekannt; Hinweise, welche davon sich mit vertretbarem Aufwand beheben ließen, sind trotzdem willkommen.

## English

### What this project promises and what it does not

- PHP 5.6 has received no security fixes from php.net since 31 December 2018. KeyHelp's build 5.6.40 contains some backported fixes, but far from all known ones. This project currently does not fix vulnerabilities in PHP 5.6 itself; an own build with security fixes is planned.
- The interpreter is KeyHelp's unchanged file. The solution therefore has the same weaknesses as KeyHelp's 5.6 on Debian 12.
- Per-website isolation (separate FPM pool and Unix user, `open_basedir`, disabled functions) comes from KeyHelp's templates, not from this project.
- System libraries such as OpenSSL, libxml2, libcurl and glibc come from Debian 13 and receive its security updates. The private libraries in the supplement receive security updates only through a new release.
- Releases are signed with Ed25519; `install.sh` installs nothing without a valid signature ([docs/en/signing.md](docs/en/signing.md)).

PHP 5.6 belongs only on servers whose operators knowingly accept this risk, for legacy applications that cannot be migrated.

### Supported versions

Only the newest release receives fixes.

### Reporting a vulnerability

Please do not open a public issue. Use:

1. GitHub: [report a vulnerability privately](https://github.com/Saugjunkie2/keyhelp-legacy-php-interpreter/security/advisories/new)
2. if that does not work: an issue without details asking for contact

In scope: flaws in `install.sh`, the installer, the tools, the supplement and the signature verification. Known vulnerabilities of PHP 5.6 itself are known; hints which of them could be fixed with reasonable effort are still welcome.
