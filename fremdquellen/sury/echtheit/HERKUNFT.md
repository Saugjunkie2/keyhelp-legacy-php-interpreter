# Nachweise zur Echtheit des Quellpakets uw-imap

Surys Paketquelle signiert die einzelnen `.dsc`-Dateien nicht. Die Echtheit der Dateien unter [`../uw-imap/`](../uw-imap/HERKUNFT.md) ergibt sich deshalb über Surys Signaturkette, und die Glieder dieser Kette liegen hier. Die drei Dateien sind unverändert.

| Datei | Inhalt | SHA-256 |
|---|---|---|
| `apt.gpg` | Surys öffentlicher Schlüssel, Fingerabdruck `15058500A0235D97F5D10063B188E2B695BD4743` | `b486fd5488185c4c46467960fa69c53d5085fec492cf76b9eaf3db33561c9d7c` |
| `InRelease` | signierte Release-Datei der Paketquelle für Debian 13 (trixie) vom 13.11.2026 | `6bd32f320115e9d5faa08915650e8d966c9c5d4be1e7e1546547b03d8f5504de` |
| `Sources.xz` | Index der Quellpakete (`main/source/Sources.xz`) aus derselben Paketquelle | `53c0260a74cfb0fdc238faa979299c20bb111d142ab9b41f27fe6eb1f233be22` |

Geladen am 18.11.2026 vom Spiegel `https://ftp.mpi-inf.mpg.de/pub/linux/mirror/deb.sury.org/repositories/php/`, zusammen mit dem Quellpaket.

## Nachprüfen

```bash
bash werkzeuge/sury-echtheit-pruefen.sh
```

Das Werkzeug prüft vier Stufen: den Fingerabdruck des Schlüssels, die Signatur der `InRelease` mit diesem Schlüssel, Prüfsumme und Größe von `Sources.xz` gegen die signierte `InRelease` und die drei Dateien von uw-imap gegen ihren Eintrag in `Sources`. Es braucht gpg, gpgv und xz und ändert nichts. Die öffentliche CI führt es bei jedem Push aus.

Grenze: Der Nachweis zeigt, dass die Dateien die sind, die Sury am 13.11.2026 mit diesem Schlüssel veröffentlicht hat. Ob der Schlüssel Sury gehört, bestätigt er nicht; dafür ist der Fingerabdruck mit Surys eigenen Angaben zu vergleichen.

## Evidence for the uw-imap source package

Sury does not sign individual `.dsc` files. The authenticity of the files in `../uw-imap/` therefore follows from Sury's signature chain, whose links are kept here unchanged: Sury's key `apt.gpg`, the signed `InRelease` for Debian 13 of 13 November 2026, and the source index `Sources.xz`. `bash werkzeuge/sury-echtheit-pruefen.sh` checks the key fingerprint, the signature, `Sources.xz` against `InRelease` and the uw-imap files against `Sources`. It does not prove that the key belongs to Sury; for that, compare the fingerprint with Sury's own statements.
