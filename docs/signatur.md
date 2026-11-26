# Signaturen und Manipulationsschutz

Gilt für `install.sh` 1.1.0 und die Werkzeuge 1.1.0 unter `werkzeuge/`. [English version](en/signing.md)

Ziel: Wer dieses Projekt installiert, soll prüfen können, dass ein Release von Retrowork kommt und nicht verändert wurde. Dafür gibt es Signaturen, keine verschlüsselte Lizenzabfrage; der Code bleibt lesbar.

## Vertrauenskette

1. Der öffentliche Ed25519-Schlüssel steht fest im `install.sh` jedes Releases, dazu in `schluessel/release-ed25519.pub`, als Fingerabdruck im README und auf dem zweiten Kanal: `SHA256:6db970b09f586927f6f216b317c831261b95b254e29219d2a402e4c30d4a6c41`. Den privaten Schlüssel hat nur Retrowork; er liegt in keinem Repository.
2. `SHA256SUMS.sig` ist die Ed25519-Signatur über `SHA256SUMS`.
3. `SHA256SUMS` nennt den SHA-256 jeder Datei des Releases: `install.sh`, `khli-php56.sh`, `RELEASE` und den Ergänzungssatz.
4. `RELEASE` nennt Produkt, Version, System, Installer, Ergänzungssatz, KeyHelps Originalpaket mit SHA-256, die Fassung von `install.sh`, den Commit und das Datum.
5. Der Installer trägt die SHA-256 von KeyHelps Originalpaket und vom Ergänzungssatz fest ein und prüft beide, bevor er etwas ändert.
6. Der zweite Kanal `https://lizenz.retrowork.de/keyhelp-legacy-php-interpreter/` führt die freigegebenen und die widerrufenen Releases, signiert mit demselben Schlüssel.

So ist jede Datei, die auf den Server kommt, entweder selbst signiert oder über eine signierte Prüfsumme gebunden, KeyHelps Paket über die Prüfsumme im signierten Installer.

## Die Grenze: das erste Skript

Ein manipuliertes `install.sh` kann jede Prüfung weglassen und jeden Fingerabdruck anzeigen. Die Signaturen schützen deshalb erst ab dem Moment, in dem ein echtes `install.sh` läuft. Wer den Befehl aus dem README als Pipe ausführt, vertraut GitHub und der verschlüsselten Verbindung dorthin. Wer das nicht will, prüft `install.sh` vor dem Start mit dem Schlüssel vom zweiten Kanal. Unabhängig von GitHub ist das nur, wenn der Block von der Seite des zweiten Kanals stammt (https://lizenz.retrowork.de/keyhelp-legacy-php-interpreter/); diese Datei liegt selbst auf GitHub, und ein Angreifer mit Zugriff darauf könnte hier auch Adresse und Fingerabdruck ändern:

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

Die Schritte: in einem neuen leeren Ordner die drei Dateien des Releases von GitHub laden und den Schlüssel vom zweiten Kanal; der Schlüssel muss den Fingerabdruck `6db970b09f586927f6f216b317c831261b95b254e29219d2a402e4c30d4a6c41` haben (README, zweiter Kanal); `SHA256SUMS` muss mit ihm gültig signiert sein (Ausgabe `Signature Verified Successfully`), und `install.sh` muss den SHA-256 aus `SHA256SUMS` haben (Ausgabe `install.sh: OK`). Scheitert ein Schritt, bricht die Kette ab und `install.sh` startet nicht.

`tests/veroeffentlichung-pruefen.sh` prüft das veröffentlichte Release auf dieselbe Weise, aber mit dem Schlüssel aus diesem Repository; es vergleicht den Schlüssel auf dem zweiten Kanal damit und prüft die Signatur der Freigabeliste. Die öffentliche CI führt es täglich aus.

Nach einer erfolgreichen Installation oder einem erfolgreichen Update über `install.sh` hält der Server den Schlüssel fest (`/var/lib/khli-php56/release-ed25519.pub`); nicht bei `--nur-pruefen` und nicht nach einem Fehler, und `khli-php56 uninstall` entfernt ihn mit dem Zustand. Ein späteres `install.sh` mit einem anderen Schlüssel startet den Installer nur mit `--neuer-schluessel`. Gegen ein manipuliertes Skript hilft das nicht, gegen eine Verwechslung, etwa mit einer Abspaltung, schon; und die geplanten automatischen Updates prüfen gegen diesen Schlüssel.

## Was install.sh prüft

| Prüfung | bei Abweichung |
|---|---|
| der eingetragene Schlüssel ist ein Ed25519-Schlüssel | Exit 3; ohne Schlüssel (Stand aus dem Repository) Exit 4 |
| nach `--` nur `--neu-aufbauen`, `--trotz-fremdem-ordner` und `--original <datei>` für den Installer | Exit 2 |
| `SHA256SUMS.sig` hat 64 Bytes und ist eine gültige Signatur über `SHA256SUMS` | Exit 3, nichts geändert |
| jede Zeile von `SHA256SUMS` hat die Form `<sha256>  <datei>`, Dateinamen ohne Pfad, keine doppelt, höchstens 20 | Exit 3 |
| jede Datei hat den SHA-256 aus `SHA256SUMS` | Exit 3 |
| `RELEASE`: alle elf Felder genau einmal und im festen Format; Produkt, System, Version; mit `--version` dieselbe Version | Exit 3 |
| `RELEASE` passt zum Installer: Version, Originalpaket mit SHA-256, Name und SHA-256 des Ergänzungssatzes | Exit 3 |
| das Release verlangt kein neueres `install.sh` (`INSTALL_SH_MIN`) | Exit 4 |
| der zweite Kanal: Liste erreichbar, gültig signiert, mit Generation und Ablaufdatum, nicht abgelaufen, nicht älter als die Liste, die der Server schon kannte, und das Release darin als `gueltig` | Exit 5, bei falscher Signatur oder fehlender Generation Exit 3 |
| beim Installieren: der Server hält keinen anderen Schlüssel fest (sonst nur mit `--neuer-schluessel`) | Exit 3 |
| das Release ist nicht älter als die installierte Fassung (sonst nur mit `--aelter-erlauben`; ab Installer 0.4.17 prüft der Installer das unter seiner Sperre noch einmal) | Exit 5 |

Beim neuesten Release lädt `install.sh` nach dem Prüfen von `RELEASE` alle weiteren Dateien unter dessen festem Namen `v<version>`, damit ein gleichzeitig erscheinendes neues Release nichts mischt.

Ohne Installation und ohne root prüft `bash install.sh --nur-pruefen` dasselbe. Mit einer Kopie dieses Repositorys prüft `bash werkzeuge/release-pruefen.sh <ordner>` zusätzlich, dass `install.sh` und `khli-php56.sh` im Release genau den Dateien im Repository entsprechen und der Commit aus `RELEASE` hier vorkommt.

## Zweiter Kanal

Adresse: `https://lizenz.retrowork.de/keyhelp-legacy-php-interpreter/`, unabhängig von GitHub. Dort liegen:

| Datei | Inhalt |
|---|---|
| `release-ed25519.pub` | der öffentliche Schlüssel, zum Vergleich mit dem Fingerabdruck |
| `freigaben.txt` | Kopf mit `# generation <n>` und `# gueltig-bis <JJJJ-MM-TT>`, dann eine Zeile je Release: `<version> <sha256 von SHA256SUMS> <gueltig\|widerrufen> <datum> [grund]` |
| `freigaben.txt.sig` | Ed25519-Signatur über `freigaben.txt`, mit demselben Schlüssel |
| `index.html` | eine Seite für Besucher mit Fingerabdruck und Prüfbefehlen |

`install.sh` lädt `freigaben.txt` und die Signatur vor jeder Installation. Ab 1.1.0 sperrt es im Zweifel:

| Fall | Verhalten |
|---|---|
| Release als `gueltig` geführt, Liste gültig signiert und nicht abgelaufen | weiter |
| Release als `widerrufen` geführt | Abbruch, Exit 5, mit dem Grund; nur `--ohne-zweiten-kanal` überspringt die ganze Abfrage und damit auch den Widerruf |
| Release nicht in der Liste, unbekannter Status | Abbruch, Exit 5 |
| Liste abgelaufen (`gueltig-bis` vor heute) | Abbruch, Exit 5 |
| Liste mit kleinerer Generation, als der Server schon kannte (`/var/lib/khli-php56/freigaben-generation`) | Abbruch, Exit 5: eine ältere Liste könnte einen Widerruf verbergen |
| Liste ohne Generation oder Ablaufdatum, Signatur ungültig | Abbruch, Exit 3 |
| Liste nicht erreichbar | Abbruch, Exit 5 |
| `--ohne-zweiten-kanal` | Warnung, weiter; Freigabe und Widerruf bleiben ungeprüft |

Das `install.sh` 1.0.0 aus Release 0.4.15 warnt in diesen Fällen nur und startet trotzdem; wer es direkt aufruft, umgeht diese Sperre. Es beachtet aber einen Widerruf. Releases ab 0.4.17 verlangen `install.sh` ab 1.1.0.

## Was der Schutz nicht leistet

- Ein manipuliertes `install.sh` kann alles anzeigen; dagegen hilft nur die Prüfung vor dem Start oben.
- Die Generation schützt nur Server, die eine neuere Liste schon kannten. Ein neuer Server, einer nach `uninstall` und einer, auf dem nur `--nur-pruefen` lief, nehmen eine ältere, gültig signierte Liste an, solange sie nicht abgelaufen ist. Wer die Antworten des zweiten Kanals bestimmen kann, könnte so einen Widerruf vor solchen Servern bis zum Ablaufdatum der älteren Liste verbergen. Die Laufzeit ist 365 Tage, wenn nichts anderes angegeben ist; eine kürzere (`--gueltig-tage <n>`) verkleinert dieses Fenster und verlangt häufigeres Erneuern.
- Releases und Freigabeliste tragen denselben Schlüssel. Wird er kompromittiert, kann dieses Verfahren ihn nicht nachträglich sperren; ein getrennter, offline verwahrter Wurzelschlüssel, der Release-Schlüssel freigibt und widerruft, ist für eine spätere Fassung vorgesehen. Der Schutz liegt bis dahin darin, den privaten Schlüssel gut zu verwahren.
- Eine Signatur sagt, von wem ein Release kommt, nicht, dass es fehlerfrei ist. PHP 5.6 selbst hat bekannte, nicht behobene Schwachstellen ([SECURITY.md](../SECURITY.md)).
- Ein Server prüft bisher nur bei einem Lauf von `install.sh`. Die geplanten automatischen Updates prüfen gegen den festgehaltenen Schlüssel, und die tägliche Prüfung soll die installierten Dateien mit einem signierten Manifest vergleichen.

## Ablauf eines Releases

Für die Betreuer des Projekts; den privaten Schlüssel brauchen nur Schritt 4 und 6.

1. Tests: die öffentliche CI (`.github/workflows/tests.yml`: `tests/werkzeuge-test.sh` unter Ubuntu und als root in Debian 13, `werkzeuge/sury-echtheit-pruefen.sh`); auf einem Testserver `bash tests/ende-zu-ende.sh --testserver <ergaenzungssatz> --voll`. Ändert sich der Installer oder der Ergänzungssatz, zusätzlich die Funktions- und Installertests aus [bau.md](bau.md).
2. Commit und Push auf `main`; der Arbeitsbaum ist sauber.
3. `bash werkzeuge/release-bauen.sh <ergaenzungssatz.tar.xz>` ergibt `dist/v<version>/` ohne Signatur. Es prüft den Ergänzungssatz gegen den Installer und setzt den Schlüssel aus `schluessel/release-ed25519.pub` in `install.sh` ein.
4. `bash werkzeuge/release-signieren.sh dist/v<version> <privater-schluessel>` signiert `SHA256SUMS` und prüft die Signatur sofort gegen den Schlüssel im Release.
5. `bash werkzeuge/release-pruefen.sh dist/v<version>` prüft alles unabhängig.
6. `bash werkzeuge/freigabe-eintragen.sh <freigaben.txt> dist/v<version> <privater-schluessel>` trägt das Release als gültig ein, erhöht die Generation und setzt das Ablaufdatum (Vorgabe 365 Tage, `--gueltig-tage <n>`). `freigaben.txt` und `freigaben.txt.sig` kommen zusammen auf den zweiten Kanal, im Binärmodus; zwischen den beiden Uploads lehnt `install.sh` die Liste kurz ab. **Erst danach** Schritt 7, sonst lehnt `install.sh` das neue Release ab, weil es nicht in der Liste steht.
7. Release auf GitHub mit dem Tag `v<version>` und genau den Dateien aus `dist/v<version>/`, etwa `gh release create v0.4.17 dist/v0.4.17/* --title "0.4.17" --notes-file <notizen>`.
8. Nachprüfen: `bash tests/veroeffentlichung-pruefen.sh`.

Erneuern: Spätestens vor dem Ablaufdatum `bash werkzeuge/freigabe-eintragen.sh --erneuern <freigaben.txt> <privater-schluessel>` und beide Dateien hochladen; die tägliche CI meldet eine Liste, die in weniger als 30 Tagen abläuft. Widerrufen: `bash werkzeuge/freigabe-eintragen.sh <freigaben.txt> <release-ordner> <privater-schluessel> widerrufen "<grund>"`, danach hochladen und einen Hinweis im Release auf GitHub ergänzen.

## Schlüssel erzeugen

Einmalig, am besten so, dass der private Schlüssel danach auf einem Datenträger offline liegt:

```bash
bash werkzeuge/schluessel-erzeugen.sh /pfad/zum/datentraeger
```

Das Skript fragt zweimal nach einer Passphrase (mindestens 12 Zeichen), schreibt den privaten Schlüssel verschlüsselt nach `/pfad/zum/datentraeger/khli-release-ed25519.key` (nie in das Repository, das Skript verweigert das) und den öffentlichen nach `schluessel/release-ed25519.pub`. Danach den privaten Schlüssel auf einem zweiten Datenträger sichern, die Passphrase getrennt davon aufbewahren, `schluessel/release-ed25519.pub` committen und den Fingerabdruck im README und auf dem zweiten Kanal veröffentlichen.

## Schlüssel verloren oder kompromittiert

- Verloren, aber nicht in fremden Händen: den bisherigen öffentlichen Schlüssel sichern (`cp schluessel/release-ed25519.pub <ordner>/bisher.pub`), dann `bash werkzeuge/schluessel-erzeugen.sh --ersetzen <ordner>` und den neuen Fingerabdruck im README und auf dem zweiten Kanal veröffentlichen. Das nächste Release mit dem neuen Schlüssel signieren und in die Liste eintragen mit `bash werkzeuge/freigabe-eintragen.sh --bisheriger-schluessel <ordner>/bisher.pub <freigaben.txt> dist/v<version> <neuer-privater-schluessel>`: das prüft die vorhandene Liste mit dem bisherigen Schlüssel und führt ihre Generation fort, sonst lehnten Server, die schon eine höhere Generation kennen, die neue Liste ab. Server mit dem alten Schlüssel nehmen das neue `install.sh` nur mit `--neuer-schluessel` an; der Wechsel wird deshalb im README, auf dem zweiten Kanal und beim Release angekündigt. Ab dann halten die `install.sh` ab 1.1.0 aus den alten Releases die neue Liste für falsch signiert und starten nicht mehr; die alten Releases lassen sich damit nur noch mit `--ohne-zweiten-kanal` installieren.
- Kompromittiert: ebenso, dazu ein deutlicher Hinweis im README, auf dem zweiten Kanal und bei den Releases. Einträge zum Widerruf alter Releases in der neuen Liste bewirken nichts: die alten `install.sh` können die neue Liste nicht prüfen, und ein neues `install.sh` nimmt alte Releases ohnehin nicht an, weil ihre Signatur nicht zum neuen Schlüssel passt. Wer den alten Schlüssel hat, kann weiter Releases und Listen mit ihm signieren; `install.sh` 1.0.0 und jedes `install.sh` mit `--ohne-zweiten-kanal` nähmen sie an. Nachträglich sperren lässt sich ein kompromittierter Schlüssel mit diesem Verfahren nicht (siehe oben).
