# Changelog

Ein Release trägt die Version seines Installers. Neue Einträge oben. / A release carries the version of its installer. Newest entries first.

## 0.4.17 (in Vorbereitung / in preparation)

Korrekturen aus einer statischen Drittprüfung vom 26.11.2026 (25 Punkte, Kürzel F-001 bis F-025) und aus einer unabhängigen Gegenprüfung dieser Korrekturen am selben Tag (Kürzel G-01 bis G-08). Die Zwischenfassung 0.4.16 wurde nicht veröffentlicht. / Fixes from a static third-party review of 26 November 2026 and from an independent counter-review of these fixes on the same day; the interim version 0.4.16 was not published.

Installer `khli-php56.sh` 0.4.17:

- `check` wertet den Exit-Code von `php -m` und von `ldd` aus, verlangt die Grundmodule und meldet Module, die gegenüber dem letzten Aufbau aus dem Originalarchiv fehlen. Die Liste entsteht nur bei `install` und im vollen Zweig von `update`; `check --module-merken` hält fehlende Module als gewollt abgeschaltet fest und nimmt nie eines auf, so halten Module aus eigenen ini-Dateien kein `update` auf (F-006, G-01). / `check` evaluates exit codes, required modules and modules missing compared with the last build.
- Eine Rücknahme gilt nur als gelungen, wenn auch Zustand, ELF-Tabelle, Prüfwerkzeug, Cron-Datei und Dienst zurück sind, sonst Zustand fehlerhaft und Exit 1; wirkt `stop` in der Rücknahme nicht, beendet sie den Hauptprozess aus der PID-Datei, sonst bleibt der Arbeitsordner zur Untersuchung (F-007, F-014, G-08). / A rollback only counts as successful when everything is restored.
- `update` tauscht nur, wenn der Dienst wirklich angehalten ist, auch wenn sein Startskript fehlt (F-008, G-07). / No swap while the old service still runs.
- Die Installation entfernt nie ein Paket: ein Plan von apt mit Entfernungen wird abgelehnt, der echte Lauf hat `--no-remove`, angehobene Pakete werden genannt (F-009). / apt never removes packages.
- Eine ältere Fassung über einer neueren nur mit `--aelter-erlauben`, geprüft unter der Sperre des Installers (F-004). / Downgrade protection inside the installer, under its lock.
- Originalpaket und Ergänzungssatz werden vor der Prüfung in den eigenen Arbeitsordner kopiert und nur von dort benutzt (F-013). / Inputs are copied before verification and used only from the copy.
- Werkzeug, Fassung und Modulliste stehen vor der Bestätigung des Tauschs (F-014). / The swap is confirmed last.
- `uninstall` entfernt nur Pakete, die die Installation geplant hat; Pakete aus dem Lauf von KeyHelps `install.sh` gelten nicht als eigene, auch in Zuständen aus 0.4.15 (F-015, G-06). / Only planned packages are removed.
- `uninstall` erkennt auch systemd-Units, die PHP 5.6 aufrufen; die Doku nennt genau, welche Nutzung geprüft wird (F-016). / systemd units are checked before removal.
- Beschreibung genauer: das Originalarchiv ist unverändert, nicht jede Datei darin; SECURITY.md nennt alle Änderungen (F-023). / More precise wording on what is changed.

`install.sh` 1.1.1:

- Der zweite Kanal sperrt im Zweifel: ohne gültige, nicht abgelaufene Freigabeliste mindestens der schon bekannten Generation, in der das Release als gültig steht, startet nichts (`--ohne-zweiten-kanal` mit Warnung) (F-002). / The second channel blocks when in doubt.
- Der Server hält nach einer erfolgreichen Installation den Release-Schlüssel fest; ein anderer nur mit `--neuer-schluessel`. Das hilft gegen eine Verwechslung, nicht gegen ein manipuliertes `install.sh`; dagegen hilft nur der Prüfweg vor dem Start (F-001). / The release key is pinned on the server; this does not protect against a manipulated install.sh.
- Ein unlesbarer festgehaltener Schlüssel endet mit Meldung und Exit 3, eine unlesbare Generation mit Exit 5; beide werden über eine temporäre Datei geschrieben (G-04). / Unreadable pinned key or generation are reported.
- Nach `--` nur `--neu-aufbauen`, `--trotz-fremdem-ordner` und `--original` (F-005). / Only allowed options are passed to the installer.
- `RELEASE` wird ganz und gegen die Angaben des Installers geprüft (F-019). / `RELEASE` is fully validated.
- Hilfe und Meldung von `--nur-laden` nennen, was ein Server ohne Internet zusätzlich braucht (G-05). / Offline hints corrected.
- Releases ab 0.4.17 verlangen `install.sh` ab 1.1.0. / Releases from 0.4.17 require install.sh 1.1.0.

Werkzeuge, Tests und Doku / tools, tests and documentation:

- `freigabe-eintragen.sh` 1.2.0: Generation und Ablaufdatum in der Freigabeliste, `--erneuern`, Kopf in ASCII (F-002, F-017); `--bisheriger-schluessel` für einen Schlüsselwechsel, bei dem die Generation weiterläuft (G-03). / Release list with generation and expiry date; key change keeps the generation.
- `release-pruefen.sh` 1.1.0 prüft `RELEASE` ganz, auch den Commit (F-019); `release-bauen.sh` 1.1.0 setzt `INSTALL_SH_MIN=1.1.0`.
- Neu: `werkzeuge/sury-echtheit-pruefen.sh` und Surys signierte Indexe unter `fremdquellen/sury/echtheit/` (F-022). / New: provenance check of the uw-imap source package.
- `tests/werkzeuge-test.sh` 1.2.0, `tests/ende-zu-ende.sh` 1.1.0 (stellt den festgehaltenen Schlüssel des Testservers wieder her; erwartet die Ablehnung der fremd signierten Liste), neu `tests/veroeffentlichung-pruefen.sh` 1.1.0, das auch den Schlüssel auf dem zweiten Kanal vergleicht (F-020). / Updated and new tests.
- Neu: öffentliche CI unter `.github/workflows/tests.yml` (F-021). / New: public CI.
- Der Prüfweg vor dem Start bricht bei jedem Fehler ab; unabhängig von GitHub ist er nur mit dem Block von der Seite des zweiten Kanals. `docs/signatur.md` nennt die Grenzen der Generation und beschreibt den Schlüsselwechsel neu (F-001, G-02, G-03). / Verify-before-start path stops at any failure; limits documented.

Bauanleitungen / build recipes: ein vorhandenes Ergebnis gilt nur für genau dieselbe Quelle und Fassung (Datei `QUELLE`), sonst Exit 3 statt eines stillen Erfolgs (F-010); der Zeitpunkt in `BAU` folgt `SOURCE_DATE_EPOCH` (F-018). Der Ergänzungssatz 1.1.0 bleibt unverändert. / Build results are bound to source and version; the supplement 1.1.0 is unchanged.

Bewusst offen / deliberately open: ein getrennter Wurzelschlüssel für Schlüsselwechsel (F-003), ein vollständiges signiertes Installationsmanifest (F-011), eine Vorabprüfung und die Mitnahme der Freigabeliste für Server ohne Internet (F-012, G-05), ein Transaktionsjournal über Pakete und Dateien außerhalb des Ordners (F-014, Rest), vollständig reproduzierbare Bauten (F-018, Rest), die Veröffentlichung der Funktions- und Installertests (F-021, Rest), eine SBOM (F-022, Rest), englische Meldungen (F-025), eine kürzere Laufzeit der Freigabeliste mit eigenem Schlüssel dafür (G-02).

### Fassungen / versions

| Datei | Fassung |
|---|---|
| `installer/khli-php56.sh` | 0.4.17 |
| `install.sh` | 1.1.1 |
| `werkzeuge/gemeinsam.sh`, `release-signieren.sh`, `schluessel-erzeugen.sh` | 1.0.0 |
| `werkzeuge/release-bauen.sh`, `release-pruefen.sh` | 1.1.0 |
| `werkzeuge/freigabe-eintragen.sh` | 1.2.0 |
| `werkzeuge/sury-echtheit-pruefen.sh` | 1.0.0 |
| `tests/werkzeuge-test.sh` | 1.2.0 |
| `tests/ende-zu-ende.sh`, `tests/veroeffentlichung-pruefen.sh` | 1.1.0 |
| `build/bibliotheken/bau-debianquelle.sh` | 1.3 |
| `build/bibliotheken/bau-imagemagick6.sh` | 1.3 |
| `build/bibliotheken/bau-openldap-bibliotheken.sh` | 1.2 |
| `build/bibliotheken/bau-uwimap.sh` | 1.1 |
| `build/zusammenbau/ergaenzung-bauen.sh` | 1.2 |
| Ergänzungssatz | 1.1.0 |

## 0.4.15 (2026-11-26)

Erstes öffentliches Release. / First public release.

- Installer `khli-php56.sh` 0.4.15, unverändert der freigegebene Stand des internen Projekts (SHA-256 `77f356fdca85fb9bb4bafa8137a33f2bdc109b614d2ef44b19044b02cca42559`). Sein Kopf enthält die Entwicklungsgeschichte mit Verweisen auf interne Prüfberichte (Kürzel wie `I-52`, `N31`, `E-0049`); diese Berichte sind nicht veröffentlicht. / Installer 0.4.15, unchanged from the approved state of the internal project; its header refers to internal review reports that are not published.
- Ergänzungssatz 1.1.0 als Datei im Release (SHA-256 `530f1a948e5b3e6f1472d91ee24b69d4240bcc57bf9abef09ffd3f589f656502`), Bauanleitungen unverändert unter `build/`, Quellpaket uw-imap unter `fremdquellen/`. / Supplement 1.1.0 as a release file, build recipes unchanged in `build/`, uw-imap source package in `fremdquellen/`.
- KeyHelps Paket `php_5.6.40_20261103164601.tar.gz` (SHA-256 `4ee240d31be9f1cc5cba853728b3bc6fe4aceaa18a1a0a3dafd0d282dbf5b6c6`) wird beim Nutzer von `repo.keyhelp.de` geladen. / KeyHelp's package is downloaded on the user's server.
- Neu: `install.sh` 1.0.0, Installation und Update mit einem Befehl, prüft die Ed25519-Signatur, jede Datei, Widerrufe auf dem zweiten Kanal und ältere Releases. / New: one-command installation and update with signature, checksum, revocation and downgrade checks.
- Neu: Werkzeuge 1.0.0 unter `werkzeuge/` (Schlüssel erzeugen, Release bauen, signieren und prüfen, Freigabeliste) und Tests unter `tests/`; die Tests 1.0.1 korrigieren nur ihre eigenen Reste und eine Meldung. / New: release tools and tests; tests 1.0.1 only fix their own leftovers and a message.
- Öffentlicher Schlüssel `schluessel/release-ed25519.pub`, Fingerabdruck `SHA256:6db970b09f586927f6f216b317c831261b95b254e29219d2a402e4c30d4a6c41`. / Public key and its fingerprint.

## Geplant / Planned

- Automatische Updates: Prüfen und Einspielen neuer signierter Releases auf dem Server, im Zeitfenster der Zeile „PHP-Interpreter aktualisieren" in KeyHelps Wartungsaufgaben, gegen den auf dem Server festgehaltenen Schlüssel. / Automatic updates within KeyHelp's maintenance window, verified against the pinned key.
- Die tägliche Prüfung vergleicht die installierten Dateien mit einem signierten Manifest. / The daily check compares installed files with a signed manifest.
- Ein getrennter Wurzelschlüssel, der Release-Schlüssel freigibt und widerruft. / A separate root key that authorizes and revokes release keys.
- Eigener Bau von PHP 5.6 mit Sicherheitskorrekturen als `5.6.40-<N>+retrowork`, ohne Abhängigkeit von fremden Paketquellen zur Laufzeit. / Own PHP 5.6 build with security fixes as `5.6.40-<N>+retrowork`.
