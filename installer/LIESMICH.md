# Installer khli-php56.sh

`khli-php56.sh` ist der Installer. Er läuft normalerweise über `install.sh` aus einem Release, das ihn vorher gegen die signierte Liste prüft; nach der Installation steht er als Prüfwerkzeug `khli-php56` bereit. Retrowork entwickelt ihn in einer internen Projektumgebung; Änderungen hier übernimmt Retrowork dorthin.

```bash
khli-php56 check [--module-merken] | status | uninstall
bash khli-php56.sh install | update   # direkt nur mit Ergänzungssatz: --ergaenzung <datei>
```

Befehle, Optionen und Exit-Codes: [docs/betrieb.md](../docs/betrieb.md); was sich je Fassung geändert hat: [CHANGELOG.md](../CHANGELOG.md). Der Kopf des Skripts enthält die Entwicklungsgeschichte; ältere Einträge verweisen auf interne Prüfberichte (Kürzel wie `I-52`, `N31`, `E-0049`), die nicht veröffentlicht sind, die Einträge ab 0.4.16 auf die Befunde der Drittprüfung vom 26.11.2026 (`F-004` bis `F-016`).

`khli-php56.sh` is the installer. It normally runs via `install.sh` from a release, which verifies it against the signed list first. Retrowork develops it in an internal project environment. Its header contains the development history; older entries refer to unpublished internal review reports, entries from 0.4.16 to the findings of the third-party review of 26 November 2026. Commands and exit codes: [docs/en/operation.md](../docs/en/operation.md).
