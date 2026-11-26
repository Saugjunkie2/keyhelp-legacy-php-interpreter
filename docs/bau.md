# Bau des Ergänzungssatzes

Gilt für den Ergänzungssatz 1.1.0 und die Bauanleitungen unter `build/`. [English version](en/building.md)

## Was gebaut wird und warum

KeyHelps PHP-5.6-Erweiterungen für Debian 12 sind gegen Bibliotheken gelinkt, die Debian 13 nicht mehr liefert, und für intl fehlt der Suchpfad zur gebündelten ICU-Datenbibliothek. Gebaut werden nur diese Bibliotheken, aus denselben Quellständen wie auf dem Debian-12-Referenzserver:

| Bibliothek | Quelle | Stand | Herkunft der Quelle |
|---|---|---|---|
| `libvpx.so.7` | Debian-Quellpaket libvpx | 1.12.0-1+deb12u5 | deb.debian.org, bookworm-security, über apt (Signatur der Release-Datei) |
| `libtidy.so.5deb1` | tidy-html5 | 2:5.6.0-11 | deb.debian.org, bookworm |
| `libldap-2.5.so.0`, `liblber-2.5.so.0` | openldap | 2.5.13+dfsg-5 | deb.debian.org, bookworm |
| `libMagickCore-6.Q16.so.6`, `libMagickWand-6.Q16.so.6`, Module | imagemagick | 6.9.11-60+dfsg-1.6+deb12u15 | deb.debian.org, bookworm-security |
| Konfiguration von ImageMagick | imagemagick-6-common | derselbe Stand | deb.debian.org, bookworm-security, Binärpaket |
| `libc-client.so.2007e` | uw-imap | 2007f~dfsg-7.1 (Bau von Sury für Debian 13) | [`fremdquellen/sury/uw-imap/`](../fremdquellen/sury/uw-imap/HERKUNFT.md) |
| `libssh2-khli.so.1` | libssh2 | 1.10.0-3+deb12u1 | deb.debian.org, bookworm-security |

libssh2 1.10 aus Debian 12 bekommt einen eigenen Namen (soname `libssh2-khli.so.1`) und dient nur `ssh2.so`: Mit libssh2 1.11 aus Debian 13 bricht `ssh2_auth_pubkey_file()` bei ECDSA-Schlüsseln ab, und libcurl lädt im selben Prozess weiter das libssh2 von Debian 13.

## Umgebung

Gebaut wird als root in einer Chroot mit Debian 13 (trixie), damit gegen die Bibliotheken von Debian 13 gelinkt wird:

- angelegt mit `debootstrap --variant=buildd --include=ca-certificates,gnupg trixie <ordner> http://deb.debian.org/debian`; debootstrap prüft die Echtheit über `debian-archive-keyring`
- zusätzlich `deb-src`-Einträge für trixie, bookworm, bookworm-updates und bookworm-security, damit `apt-get source` die Debian-12-Quellen holt
- ohne empfohlene Pakete (`APT::Install-Recommends "false"`) und mit einer `policy-rc.d`, die keine Dienste startet (`exit 101`)
- der Baum dieses Repositorys schreibgeschützt unter `/khli/baum`, ein beschreibbarer Ordner `/khli/aus` für die Ergebnisse
- für Schritt 3 eine zweite Chroot mit Debian 12 (bookworm)

Die Bauanleitungen erwarten genau diese Pfade. Für den offiziellen Ergänzungssatz liefen sie so auf einem Testserver, mit eigenem Mount- und PID-Namensraum je Lauf (`unshare --mount --pid --fork`).

## Ablauf

1. In der Debian-13-Chroot nacheinander:
   - `bash /khli/baum/build/bibliotheken/bau-debianquelle.sh libvpx 1.12.0-1+deb12u5`
   - `bash /khli/baum/build/bibliotheken/bau-debianquelle.sh tidy-html5 2:5.6.0-11`
   - `bash /khli/baum/build/bibliotheken/bau-debianquelle.sh libssh2 1.10.0-3+deb12u1`
   - `bash /khli/baum/build/bibliotheken/bau-uwimap.sh`
   - `bash /khli/baum/build/bibliotheken/bau-openldap-bibliotheken.sh`
   - `bash /khli/baum/build/bibliotheken/bau-imagemagick6.sh`
2. Die Ergebnisse liegen unter `/khli/aus/ergebnis/<quelle>/` mit `SHA256SUMS`, `copyright` und `changelog`.
3. `imagemagick-6-common` im selben Stand in der Debian-12-Chroot mit `apt-get download` holen und nach `/khli/aus/ergebnis/imagemagick-6-common/` der Debian-13-Chroot legen.
4. Zusammenbau: `bash /khli/baum/build/zusammenbau/ergaenzung-bauen.sh <version>` ergibt `/khli/aus/ergaenzung/khli-php56-ergaenzung-<version>-debian13-amd64.tar.xz` mit `MANIFEST.sha256`, `HERKUNFT.tsv` (alle Quelldateien mit SHA-256), `BAU` (Compiler, Datum), `needed.tsv` und `laufzeit-pakete.txt` (Debian-13-Pakete, die die Bibliotheken brauchen).
5. Den SHA-256 des neuen Satzes im Installer eintragen (`ERGAENZUNG_SHA256`, `ERGAENZUNG_VERSION`), neue Versionsnummer, CHANGELOG.
6. Prüfen: Installation, Update und Rückbau in einer minimalen Debian-13-Chroot und auf einem Testserver, Funktionsvergleich mit KeyHelps 5.6 unter Debian 12, danach `tests/ende-zu-ende.sh`. Die bisherigen Funktions- und Installertests laufen in der internen Projektumgebung; sie werden nach und nach in dieses Repository übernommen.

Bauzeiten auf einem Testserver mit 2 CPU: libvpx, tidy und c-client je wenige Minuten, OpenLDAP unter 5 Minuten, ImageMagick rund 5 Minuten.

## Abweichungen vom Debian-12-Bau

- GCC 14 statt GCC 12. Die Fehlerklassen, die GCC 14 und dpkg-buildflags in Debian 13 neu als Fehler behandeln (implicit-int, int-conversion, incompatible-pointer-types, return-mismatch), sind dort, wo nötig, auf Warnungen zurückgestuft, damit derselbe Quelltext dasselbe Programm ergibt.
- Gelinkt gegen die Bibliotheken von Debian 13 (zum Beispiel libwebp 1.5, libtiff 4.7, OpenEXR 3.1, GnuTLS 3.8), nicht gegen die von Debian 12. Das ist gewollt: keine zweite, ungepflegte Kopie dieser Bibliotheken.
- ImageMagick mit privatem Präfix `/opt/keyhelp/php/5.6/lib/khli` statt `/usr`, ohne Magick++ und PerlMagick, nur Q16 ohne HDRI.
- OpenLDAP nur `libraries/`; der vollständige Paketbau scheitert an einem slapd-Modul, das PHP nicht nutzt.

## Wann neu gebaut wird

| Anlass | Was zu tun ist |
|---|---|
| Debian veröffentlicht für Debian 12 (LTS bis Mitte 2028) einen neuen Sicherheitsstand einer der Quellen | Bau mit der neuen Version, neuer Ergänzungssatz, neue Fassung des Installers, neues Release |
| KeyHelp veröffentlicht einen neuen 5.6-Build für Debian 12 | Prüfsumme und Build im Installer anpassen, Tests wiederholen; die privaten Bibliotheken bleiben, solange die Erweiterungen dieselben sonames brauchen |
| Debian 13 aktualisiert eine Systembibliothek | nichts; die privaten Bibliotheken nutzen die Systembibliotheken über ihre sonames |
| Debian 14 | neuer Abgleich; der Reserveweg ist ein eigener Bau von PHP 5.6 |

## Vorhandene Ergebnisse, Zeitstempel, Herkunft

- Jede Bauanleitung schreibt ab ihrer Fassung 1.1 bis 1.3 die Datei `QUELLE` (Quelle und Fassung) in ihr Ergebnis und nimmt sie in `SHA256SUMS` auf. Ein vorhandenes Ergebnis gilt nur für genau dieselbe Quelle und Fassung; gehört es zu einer anderen oder fehlt `QUELLE`, endet der Bau mit Exit 3 und der Bitte, den Ordner zu entfernen. Bis dahin hätte ein vorhandenes Ergebnis einen Bau mit neuer Fassung still übersprungen.
- `ergaenzung-bauen.sh` 1.2 nennt die Quelle jedes Ergebnisses und schreibt den Zeitpunkt in `BAU` nach `SOURCE_DATE_EPOCH`, wenn gesetzt. Das Archiv hat seit 1.0 feste Zeitstempel, Besitzer und Reihenfolge. Bit für Bit gleich sind zwei Bauten trotzdem nicht sicher: Compiler und Bibliotheken von Debian 13 sind nicht auf einen Snapshot festgelegt; `BAU`, `needed.tsv` und `HERKUNFT.tsv` halten fest, womit gebaut wurde.
- Die Echtheit des Quellpakets uw-imap prüft `bash werkzeuge/sury-echtheit-pruefen.sh` über Surys Signaturkette (Schlüssel, signierte `InRelease`, `Sources.xz`) mit den Nachweisen unter `fremdquellen/sury/echtheit/`. Die Debian-Quellen prüft `apt-get source` selbst über die signierte Release-Datei.

## Hinweis zu den Bauanleitungen

Die Bauanleitungen unter `build/` sind die Fassungen, mit denen der Ergänzungssatz 1.1.0 entstand, ergänzt nur um die Behandlung vorhandener Ergebnisse und den Zeitstempel oben; am Bau selbst ändert das nichts. Ihre Kommentare verweisen auf die interne Projektdokumentation (Kürzel wie `E-0040` oder `docs/45`), die nicht veröffentlicht ist; „PROD" steht dort für den Debian-12-Referenzserver.
