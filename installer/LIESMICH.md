# Installer khli-php56.sh

`khli-php56.sh` 0.4.15 ist unverändert der freigegebene Stand des internen Projekts (SHA-256 `77f356fdca85fb9bb4bafa8137a33f2bdc109b614d2ef44b19044b02cca42559`). Er läuft normalerweise über `install.sh` aus einem Release, das ihn vorher gegen die signierte Liste prüft; nach der Installation steht er als Prüfwerkzeug `khli-php56` bereit.

```bash
khli-php56 check | status | uninstall
bash khli-php56.sh install | update   # direkt nur mit Ergänzungssatz: --ergaenzung <datei>
```

Befehle, Optionen und Exit-Codes: [docs/betrieb.md](../docs/betrieb.md). Der Kopf des Skripts enthält die Entwicklungsgeschichte mit Verweisen auf interne Prüfberichte (Kürzel wie `I-52`, `N31`, `E-0049`); diese Berichte sind nicht veröffentlicht.

`khli-php56.sh` 0.4.15 is unchanged from the approved state of the internal project. It normally runs via `install.sh` from a release, which verifies it against the signed list first. Its header contains the development history with references to internal review reports that are not published. Commands and exit codes: [docs/en/operation.md](../docs/en/operation.md).
