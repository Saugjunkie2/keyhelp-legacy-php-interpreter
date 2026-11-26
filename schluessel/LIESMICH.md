# Öffentlicher Schlüssel / Public key

`release-ed25519.pub` ist der öffentliche Ed25519-Schlüssel, mit dem `install.sh` die Releases prüft. `werkzeuge/release-bauen.sh` setzt ihn beim Bau jedes Releases in `install.sh` ein. Den privaten Schlüssel hat nur Retrowork; er liegt in keinem Repository.

Fingerabdruck (SHA-256 über den Schlüssel in DER-Form), auch im README und auf dem zweiten Kanal `https://lizenz.retrowork.de/keyhelp-legacy-php-interpreter/`:

```
SHA256:6db970b09f586927f6f216b317c831261b95b254e29219d2a402e4c30d4a6c41
```

Nachrechnen: `openssl pkey -pubin -in release-ed25519.pub -outform DER | sha256sum`. Einzelheiten: [docs/signatur.md](../docs/signatur.md).

`release-ed25519.pub` is the public Ed25519 key `install.sh` verifies releases with; `werkzeuge/release-bauen.sh` embeds it in `install.sh` for every release. Only Retrowork holds the private key; it is not stored in any repository. The fingerprint above is also published in the README and on the second channel. Details: [docs/en/signing.md](../docs/en/signing.md).
