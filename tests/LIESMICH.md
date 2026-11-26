# Tests

| Test | Wo | Was |
|---|---|---|
| `werkzeuge-test.sh` | Linux oder Git Bash unter Windows, ohne root; Teil B nur als root unter Debian 13 ohne PHP 5.6 dieses Projekts (etwa in einer Chroot) | Schlüssel, Release bauen, signieren und prüfen, Freigabeliste; `install.sh` gegen gültige und veränderte Releases; Teil B: Start des Installers (Attrappe) mit install oder update, ältere und widerrufene Releases, Optionen, Exit-Code, Protokoll |
| `ende-zu-ende.sh --testserver <ergaenzungssatz> [--voll]` | nur auf einem Testserver mit Debian 13, KeyHelp und installiertem PHP 5.6 dieses Projekts, als root | Release mit Wegwerf-Schlüssel bauen, signieren, prüfen und mit seinem `install.sh` einspielen (`update`), danach `khli-php56 check` |

Beide erzeugen Wegwerf-Schlüssel in einem temporären Ordner und löschen sie am Ende. `werkzeuge-test.sh` braucht kein Netz und installiert nichts; `ende-zu-ende.sh` verändert den Server wie ein `update`.

Both tests create throwaway keys in a temporary directory and delete them at the end. `werkzeuge-test.sh` needs no network and installs nothing; `ende-zu-ende.sh` changes the server like an `update` and is meant for test servers only.
