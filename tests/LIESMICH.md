# Tests

| Test | Wo | Was |
|---|---|---|
| `werkzeuge-test.sh` | Linux oder Git Bash unter Windows, ohne root; Teil B nur als root unter Debian 13 ohne PHP 5.6 dieses Projekts (etwa in einer Chroot oder einem Container) | Schlüssel, Release bauen, signieren und prüfen, Freigabeliste mit Generation und Ablaufdatum; `install.sh` gegen gültige und veränderte Releases und Freigabelisten; Teil B: Start des Installers (Attrappe) mit install oder update, ältere und widerrufene Releases, ältere Freigabeliste, festgehaltener Schlüssel, Optionen, Exit-Code, Protokoll |
| `ende-zu-ende.sh --testserver <ergaenzungssatz> [--voll]` | nur auf einem Testserver mit Debian 13, KeyHelp und installiertem PHP 5.6 dieses Projekts, als root | Release mit Wegwerf-Schlüssel bauen, signieren, prüfen und mit seinem `install.sh` einspielen (`update`), danach `khli-php56 check`; stellt den festgehaltenen Schlüssel des Servers am Ende wieder her |
| `veroeffentlichung-pruefen.sh [--version <v>]` | überall mit Netz, ohne root | das veröffentlichte Release auf GitHub: Signatur mit dem Schlüssel dieses Repositorys, `install.sh` gegen `SHA256SUMS` und Schlüssel, dann `install.sh --nur-pruefen` mit dem echten zweiten Kanal; meldet eine Freigabeliste, die in weniger als 30 Tagen abläuft |

Die öffentliche CI (`.github/workflows/tests.yml`) führt `werkzeuge-test.sh` unter Ubuntu und als root in einem Debian-13-Container aus, dazu `werkzeuge/sury-echtheit-pruefen.sh`, und täglich `veroeffentlichung-pruefen.sh`.

Die Tests erzeugen Wegwerf-Schlüssel in einem temporären Ordner und löschen sie am Ende. `werkzeuge-test.sh` braucht kein Netz und installiert nichts; `ende-zu-ende.sh` verändert den Server wie ein `update`.

The tests create throwaway keys in a temporary directory and delete them at the end. `werkzeuge-test.sh` needs no network and installs nothing; `ende-zu-ende.sh` changes the server like an `update` and is meant for test servers only; `veroeffentlichung-pruefen.sh` checks the published release with the key from this repository before running its `install.sh`. The public CI runs them on every push and daily.
