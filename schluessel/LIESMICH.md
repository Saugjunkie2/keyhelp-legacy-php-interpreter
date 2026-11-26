# Öffentlicher Schlüssel / Public key

`release-ed25519.pub` ist der öffentliche Ed25519-Schlüssel, mit dem `install.sh` die Releases prüft. Er entsteht einmalig mit `werkzeuge/schluessel-erzeugen.sh`; den privaten Schlüssel hat nur Retrowork, offline. Bis dahin fehlt die Datei, und `werkzeuge/release-bauen.sh` baut kein Release. Fingerabdruck und Prüfung: [docs/signatur.md](../docs/signatur.md).

`release-ed25519.pub` is the public Ed25519 key `install.sh` verifies releases with. It is created once with `werkzeuge/schluessel-erzeugen.sh`; only Retrowork holds the private key, offline. Until then the file is missing and `werkzeuge/release-bauen.sh` builds no release. Fingerprint and verification: [docs/en/signing.md](../docs/en/signing.md).
