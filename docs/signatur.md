# Signaturen und Manipulationsschutz

Gilt für `install.sh` 1.0.0 und die Werkzeuge 1.0.0 unter `werkzeuge/`. [English version](en/signing.md)

Ziel: Wer dieses Projekt installiert, soll prüfen können, dass ein Release von Retrowork kommt und nicht verändert wurde. Dafür gibt es Signaturen, keine verschlüsselte Lizenzabfrage; der Code bleibt lesbar.

## Vertrauenskette

1. Der öffentliche Ed25519-Schlüssel steht fest im `install.sh` jedes Releases, dazu in `schluessel/release-ed25519.pub`, als Fingerabdruck im README und auf dem zweiten Kanal: `SHA256:6db970b09f586927f6f216b317c831261b95b254e29219d2a402e4c30d4a6c41`. Den privaten Schlüssel hat nur Retrowork; er liegt in keinem Repository.
2. `SHA256SUMS.sig` ist die Ed25519-Signatur über `SHA256SUMS`.
3. `SHA256SUMS` nennt den SHA-256 jeder Datei des Releases: `install.sh`, `khli-php56.sh`, `RELEASE` und den Ergänzungssatz.
4. `RELEASE` nennt Produkt, Version, System, Installer, Ergänzungssatz, KeyHelps Originalpaket mit SHA-256, den Commit und das Datum.
5. Der Installer trägt die SHA-256 von KeyHelps Originalpaket und vom Ergänzungssatz fest ein und prüft beide, bevor er etwas ändert.

So ist jede Datei, die auf den Server kommt, entweder selbst signiert oder über eine signierte Prüfsumme gebunden, KeyHelps Paket über die Prüfsumme im signierten Installer.

## Was install.sh prüft

| Prüfung | bei Abweichung |
|---|---|
| der eingetragene Schlüssel ist ein Ed25519-Schlüssel | Exit 3; ohne Schlüssel (Stand aus dem Repository) Exit 4 |
| `SHA256SUMS.sig` hat 64 Bytes und ist eine gültige Signatur über `SHA256SUMS` | Exit 3, nichts geändert |
| jede Zeile von `SHA256SUMS` hat die Form `<sha256>  <datei>`, Dateinamen ohne Pfad, keine doppelt, höchstens 20 | Exit 3 |
| jede Datei hat den SHA-256 aus `SHA256SUMS` | Exit 3 |
| `RELEASE`: jede Zeile `SCHLÜSSEL=wert`, Produkt `keyhelp-legacy-php-interpreter`, System `debian13-amd64`, gültige Version, Installer und Ergänzungssatz stehen in `SHA256SUMS`; mit `--version` dieselbe Version | Exit 3 |
| die Version im Installer ist die Version des Releases | Exit 3 |
| das Release verlangt kein neueres `install.sh` (`INSTALL_SH_MIN`) | Exit 4 |
| der zweite Kanal führt das Release nicht als widerrufen | Exit 5 |
| das Release ist nicht älter als die installierte Fassung (sonst nur mit `--aelter-erlauben`) | Exit 5 |

Beim neuesten Release lädt `install.sh` nach dem Prüfen von `RELEASE` alle weiteren Dateien unter dessen festem Namen `v<version>`, damit ein gleichzeitig erscheinendes neues Release nichts mischt.

## Selbst prüfen

Mit `install.sh`, ohne etwas zu installieren und ohne root:

```bash
bash install.sh --nur-pruefen
```

Von Hand mit OpenSSL ab 3.0, für ein Release `v<version>`:

```bash
basis=https://github.com/Saugjunkie2/keyhelp-legacy-php-interpreter/releases/download/v0.4.15
curl -fsSLO "$basis/SHA256SUMS"
curl -fsSLO "$basis/SHA256SUMS.sig"
curl -fsSLO https://raw.githubusercontent.com/Saugjunkie2/keyhelp-legacy-php-interpreter/main/schluessel/release-ed25519.pub
openssl pkey -pubin -in release-ed25519.pub -outform DER | sha256sum
# muss der Fingerabdruck aus dem README und vom zweiten Kanal sein
openssl pkeyutl -verify -pubin -inkey release-ed25519.pub -rawin -in SHA256SUMS -sigfile SHA256SUMS.sig
# Signature Verified Successfully
for f in $(awk '{print $2}' SHA256SUMS); do curl -fsSLO "$basis/$f"; done
sha256sum -c SHA256SUMS
```

Mit einer Kopie dieses Repositorys prüft `bash werkzeuge/release-pruefen.sh <ordner>` zusätzlich, dass `install.sh` und `khli-php56.sh` im Release genau den Dateien im Repository entsprechen.

## Zweiter Kanal

Adresse: `https://lizenz.retrowork.de/keyhelp-legacy-php-interpreter/`, unabhängig von GitHub. Dort liegen:

| Datei | Inhalt |
|---|---|
| `release-ed25519.pub` | der öffentliche Schlüssel, zum Vergleich mit dem Fingerabdruck |
| `freigaben.txt` | eine Zeile je Release: `<version> <sha256 von SHA256SUMS> <gueltig\|widerrufen> <datum> [grund]` |
| `freigaben.txt.sig` | Ed25519-Signatur über `freigaben.txt`, mit demselben Schlüssel |

`install.sh` lädt `freigaben.txt` und die Signatur vor jeder Installation (`--ohne-zweiten-kanal` lässt das aus):

| Fall | Verhalten |
|---|---|
| Release als `gueltig` geführt | Meldung, weiter |
| Release als `widerrufen` geführt | Abbruch mit Exit 5 und dem Grund; es gibt keinen Schalter dagegen |
| Release nicht in der Liste | Warnung, weiter |
| Liste nicht erreichbar oder Signatur ungültig | Warnung, weiter |

Warum nur Warnungen, wenn die Liste fehlt: Die Signatur des Releases ist der eigentliche Schutz. Der zweite Kanal ergänzt Widerrufe und einen zweiten, von GitHub getrennten Ort für den Fingerabdruck; ein Ausfall der Domain soll keine Installation verhindern.

## Was der Schutz nicht leistet

- Wer das GitHub-Konto übernähme, könnte ein `install.sh` mit einem anderen Schlüssel veröffentlichen. Dagegen hilft der Vergleich des Fingerabdrucks, den `install.sh` bei jedem Lauf anzeigt (`Schlüssel SHA256:…`), mit dem zweiten Kanal. Wer ganz sicher gehen will, lädt `install.sh` zuerst und prüft es wie oben von Hand.
- Eine Signatur sagt, von wem ein Release kommt, nicht, dass es fehlerfrei ist. PHP 5.6 selbst hat bekannte, nicht behobene Schwachstellen ([SECURITY.md](../SECURITY.md)).
- Ein Server prüft bisher nur bei einem Lauf von `install.sh`. Die geplanten automatischen Updates prüfen gegen den Schlüssel, der schon auf dem Server liegt, und die tägliche Prüfung soll die installierten Dateien mit dem signierten Manifest vergleichen.

## Ablauf eines Releases

Für die Betreuer des Projekts; den privaten Schlüssel braucht nur Schritt 4 und 6.

1. Tests: `bash tests/werkzeuge-test.sh` unter Linux oder Git Bash; als root in einer Debian-13-Chroot für Teil B; auf einem Testserver `bash tests/ende-zu-ende.sh --testserver <ergaenzungssatz> --voll`. Ändert sich der Installer oder der Ergänzungssatz, zusätzlich die Funktions- und Installertests aus [bau.md](bau.md).
2. Commit und Push auf `main`; der Arbeitsbaum ist sauber.
3. `bash werkzeuge/release-bauen.sh <ergaenzungssatz.tar.xz>` ergibt `dist/v<version>/` ohne Signatur. Es prüft den Ergänzungssatz gegen den Installer und setzt den Schlüssel aus `schluessel/release-ed25519.pub` in `install.sh` ein.
4. `bash werkzeuge/release-signieren.sh dist/v<version> <privater-schluessel>` signiert `SHA256SUMS` und prüft die Signatur sofort gegen den Schlüssel im Release.
5. `bash werkzeuge/release-pruefen.sh dist/v<version>` prüft alles unabhängig.
6. `bash werkzeuge/freigabe-eintragen.sh <freigaben.txt> dist/v<version> <privater-schluessel>` trägt das Release als gültig ein; `freigaben.txt`, `freigaben.txt.sig` und `schluessel/release-ed25519.pub` kommen auf den zweiten Kanal.
7. Release auf GitHub mit dem Tag `v<version>` und genau den Dateien aus `dist/v<version>/`, etwa `gh release create v0.4.15 dist/v0.4.15/* --title "0.4.15" --notes-file <notizen>`.
8. Nachprüfen auf einem Server: `bash install.sh --nur-pruefen` (lädt von GitHub).

Widerrufen: `bash werkzeuge/freigabe-eintragen.sh <freigaben.txt> <release-ordner> <privater-schluessel> widerrufen "<grund>"`, danach die Liste hochladen und einen Hinweis im Release auf GitHub ergänzen.

## Schlüssel erzeugen

Einmalig, am besten auf einem Rechner, dessen privaten Schlüssel danach ein Datenträger offline hält:

```bash
bash werkzeuge/schluessel-erzeugen.sh /pfad/zum/datentraeger
```

Das Skript fragt zweimal nach einer Passphrase (mindestens 12 Zeichen), schreibt den privaten Schlüssel verschlüsselt nach `/pfad/zum/datentraeger/khli-release-ed25519.key` (nie in das Repository, das Skript verweigert das) und den öffentlichen nach `schluessel/release-ed25519.pub`. Danach den privaten Schlüssel auf einem zweiten Datenträger sichern, die Passphrase getrennt davon aufbewahren, `schluessel/release-ed25519.pub` committen und den Fingerabdruck im README und auf dem zweiten Kanal veröffentlichen.

## Schlüssel verloren oder kompromittiert

- Verloren, aber nicht in fremden Händen: `bash werkzeuge/schluessel-erzeugen.sh --ersetzen <ordner>`, neuen Fingerabdruck im README und auf dem zweiten Kanal veröffentlichen, das nächste Release mit dem neuen Schlüssel signieren. Ein altes `install.sh` nimmt nur den alten Schlüssel an; Nutzer nehmen das `install.sh` aus dem neuen Release.
- Kompromittiert: ebenso einen neuen Schlüssel erzeugen und alle mit dem alten Schlüssel signierten Releases in einer neuen, mit dem neuen Schlüssel signierten Liste als widerrufen führen; dazu ein deutlicher Hinweis im README, auf dem zweiten Kanal und bei den Releases. Ein altes `install.sh` hält diese Liste für ungültig signiert und warnt nur. Einen kompromittierten Schlüssel kann dieses Verfahren also nicht nachträglich sperren; der Schutz liegt darin, ihn offline zu halten.
