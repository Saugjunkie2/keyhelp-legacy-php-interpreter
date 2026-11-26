# Quellpaket uw-imap 2007f~dfsg-7.1 für Debian 13

Quelle für den Bau von c-client (`libc-client.so.2007e`) im Ergänzungssatz, über `build/bibliotheken/bau-uwimap.sh`. Die drei Dateien sind unverändert.

| Datei | SHA-256 |
|---|---|
| `uw-imap_2007f~dfsg-7.1+0~20260622.6+debian13~1.gbpe1afca.dsc` | `b52578601c6c1b63235e137095b45aba67e6d2cb51f7078e4f4093753df28d81` |
| `uw-imap_2007f~dfsg-7.1+0~20260622.6+debian13~1.gbpe1afca.debian.tar.xz` | `36d7750b1f346c564af3c83f0448872b1bb60e6fc4c7869a448dfc26ef1ebb46` |
| `uw-imap_2007f~dfsg.orig.tar.gz` | `4fdec0b5a085a7269db87214276e14ce79afdf7efec2ca8d431ab176b9062a8a` |

## Herkunft

Aus der Paketquelle deb.sury.org von Ondřej Surý für Debian 13, geladen am 18.11.2026 vom Spiegel `https://ftp.mpi-inf.mpg.de/pub/linux/mirror/deb.sury.org/repositories/php/pool/main/u/uw-imap/`. Surys `.dsc`-Dateien sind nicht signiert; die Echtheit wurde stattdessen über Surys Signaturkette geprüft: Schlüssel mit dem Fingerabdruck `15058500A0235D97F5D10063B188E2B695BD4743`, signierte `InRelease` vom 13.11.2026, daraus der Index `Sources` und daraus die Prüfsummen dieser Dateien. `uw-imap_2007f~dfsg.orig.tar.gz` ist byte-gleich mit Debians eigener Datei.

Gegenüber Debians 2007f~dfsg-7, dessen Bibliothek unter Debian 12 läuft, enthält -7.1 nur Baukorrekturen (GCC 14, Abbruch bei Baufehlern, chown-Syntax; siehe `debian/changelog` im Paket).

## Lizenz

Laut `debian/copyright`: UW IMAP unter der Apache License 2.0, Debians Paketierung unter GPL-2+. Das vollständige Quellpaket liegt hier, weil die daraus gebaute Bibliothek mit den Releases weitergegeben wird ([docs/lizenzen.md](../../../docs/lizenzen.md)).
