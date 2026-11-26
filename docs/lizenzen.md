# Lizenzen und Weitergabe

[English version](en/licenses.md). Keine Rechtsberatung; die Einordnung folgt den Lizenztexten in den Quellpaketen.

## Grundsatz

Dieses Projekt gibt keine Dateien von KeyHelp weiter. Der Installer lädt KeyHelps Paket `php_5.6.40_20261103164601.tar.gz` auf dem Server des Nutzers von KeyHelps Originalquelle `repo.keyhelp.de` und prüft dessen SHA-256. Weitergegeben werden nur eigene Skripte und Dokumente, das Quellpaket uw-imap für den Bau und der Ergänzungssatz mit frei lizenzierten Bibliotheken.

## Bestandteile

| Bestandteil | Herkunft | Lizenz | weitergegeben |
|---|---|---|---|
| Skripte, Tests und Dokumente dieses Projekts | Retrowork | Apache License 2.0 ([LICENSE](../LICENSE)) | ja, im Repository und in den Releases |
| KeyHelps PHP-5.6-Paket (PHP, PEAR, Composer, gebündelte ICU, Erweiterungen) | repo.keyhelp.de | PHP-Lizenz 3.01, Unicode-Lizenz und weitere | nein, Download beim Nutzer |
| ionCube- und SourceGuardian-Loader | von KeyHelp auf dem Server abgelegt | proprietär | nein, unberührt |
| libvpx 1.12.0 | Debian-Quellpaket | BSD-3-Clause mit Patentlizenz von Google | ja, im Ergänzungssatz |
| tidy-html5 5.6.0 | Debian-Quellpaket | HTML-Tidy-Lizenz (W3C-artig, frei) | ja, im Ergänzungssatz |
| OpenLDAP 2.5.13 (libldap, liblber) | Debian-Quellpaket | OpenLDAP Public License 2.8 | ja, im Ergänzungssatz |
| ImageMagick 6.9.11-60 | Debian-Quellpaket, Konfiguration aus `imagemagick-6-common` | ImageMagick-Lizenz (an Apache 2.0 angelehnt) | ja, im Ergänzungssatz |
| UW IMAP c-client 2007f | Surys Quellpaket für Debian 13 | Apache-2.0; Debians Paketierung GPL-2+ | ja, im Ergänzungssatz; das Quellpaket unter `fremdquellen/` |
| libssh2 1.10.0 (als `libssh2-khli.so.1`) | Debian-Quellpaket 1.10.0-3+deb12u1 | BSD-3-Clause | ja, im Ergänzungssatz |
| Debians Patches und Paketierung dieser Quellen | Debian, Sury | wie in den jeweiligen `copyright`-Dateien | als Teil der gebauten Bibliotheken |
| Surys Schlüssel, signierte `InRelease` und `Sources.xz` | deb.sury.org | öffentliche Paketquellen-Metadaten ohne eigene Lizenzangabe | ja, unverändert unter `fremdquellen/sury/echtheit/` als Nachweis der Echtheit |

Der Ergänzungssatz enthält je Quelle `copyright` und `changelog.gz` unter `lib/khli/share/doc/<quelle>/`, dazu die `LICENSE` von ImageMagick und `HERKUNFT.tsv` mit den SHA-256 aller Quelldateien. Die Bauanleitungen unter `build/` und [bau.md](bau.md) zeigen, wie er entsteht.

Quelltexte: Von den gebauten Quellen steht nur Debians Paketierung von uw-imap unter einer Copyleft-Lizenz (GPL-2+, laut `copyright` im Ergänzungssatz; bei den übrigen sind es ImageMagick-, BSD-, OpenLDAP- und Tidy-Lizenzen). Ihr vollständiges Quellpaket liegt deshalb in diesem Repository unter [`fremdquellen/sury/uw-imap/`](../fremdquellen/sury/uw-imap/HERKUNFT.md), am selben Ort wie die Releases. Die übrigen Quellpakete nennt `HERKUNFT.tsv` mit Fassung und SHA-256; sie liegen im Debian-Archiv (`snapshot.debian.org`).

## Namen

Die Apache License 2.0 gibt kein Recht an Namen und Marken (Abschnitt 6). Veränderte Fassungen dürfen sich nicht als Release von Retrowork ausgeben; offiziell ist nur, was mit dem Schlüssel von Retrowork signiert ist ([signatur.md](signatur.md)). KeyHelp ist eine Marke der Keyweb AG, PHP eine Marke der PHP Group; dieses Projekt wird von keiner der beiden herausgegeben.
