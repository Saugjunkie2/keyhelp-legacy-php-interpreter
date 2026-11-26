# Operation: PHP 5.6 for KeyHelp on Debian 13

Applies to release 0.4.16: installer `khli-php56.sh` 0.4.16, supplement 1.1.0, `install.sh` 1.1.0. [Deutsche Fassung](../betrieb.md). The scripts print their messages in German; the German manual quotes them verbatim.

## Summary

```bash
bash install.sh            # install or update, as root (README)
khli-php56 check           # check, at any time
khli-php56 status          # version, state and service
khli-php56 uninstall       # full removal, as long as KeyHelp and the checked places do not use 5.6
```

Afterwards 5.6 shows up in KeyHelp like the official interpreters; it is assigned per domain in the panel.

## Installation

### What install.sh does

1. checks root, Debian 13, amd64, `openssl` and `curl` or `wget`; after `--` only `--neu-aufbauen`, `--trotz-fremdem-ordner` and `--original <file>` are allowed for the installer
2. downloads `SHA256SUMS` and `SHA256SUMS.sig` of the release and verifies the Ed25519 signature with its embedded key; without a valid signature it exits with code 3 and changes nothing
3. downloads every file of the release and verifies it against `SHA256SUMS`; checks `RELEASE` completely and against the installer's own values (version, original package, supplement)
4. asks the second channel for the approval ([signing.md](signing.md#second-channel)): without a valid, unexpired release list that lists the release as `gueltig` (valid), nothing starts (exit 5 or 3); `--ohne-zweiten-kanal` skips this with a warning
5. checks that the server does not pin a different release key (otherwise exit 3, `--neuer-schluessel` after an announced key change), checks free space and starts the installer: `install` if this project's PHP 5.6 is not set up yet, otherwise `update`
6. after a successful run pins the key and the generation of the release list in the state and appends a line to `/var/log/khli-php56/install-sh.log` (release, SHA-256 of `SHA256SUMS`, key, release list, exit code)

Options: `--version <v>` for a specific release, `--quelle <dir|https-url>` instead of GitHub, `--nur-pruefen` (verify only), `--nur-laden <dir>` (download and verify into a directory), `--ohne-zweiten-kanal` (skip the second channel), `--aelter-erlauben` (allow an older release), `--neuer-schluessel` (accept a different release key), `--hilfe`.

### What the installer does

`khli-php56.sh install`

- downloads KeyHelp's package `php_5.6.40_20261103164601.tar.gz` from `repo.keyhelp.de` and verifies the pinned SHA-256 (`4ee240d31be9f1cc5cba853728b3bc6fe4aceaa18a1a0a3dafd0d282dbf5b6c6`); with `--original <file>` it uses an existing file, first copies it into its own working directory (root only) and verifies and uses only that copy
- verifies the supplement the same way as a copy against its pinned SHA-256 and both archives for paths and links leaving their directory; if a check fails it changes nothing (exit 3 or 4)
- installs missing runtime packages from Debian 13 (on a KeyHelp server usually only `libmcrypt4` and `xz-utils`) and records which packages it installed itself; if apt would remove a package for that, it refuses before apt changes anything (exit 1), and the real run uses `--no-remove`; if apt upgrades existing packages, it names them
- unpacks KeyHelp's package from the unchanged archive into `/opt/keyhelp/php/5.6` and the supplement into `lib/khli`; it only changes the RUNPATH in gd, imagick, imap, ldap, tidy, ssh2 and the bundled ICU, and `ssh2.so` loads the private libssh2 1.10 from Debian 12 under the name `libssh2-khli.so.1` (libcurl keeps using Debian 13's libssh2)
- switches off KeyHelp's automatic update for 5.6 in `keyhelp-setup/config.ini` (`is_autoupdate_enabled = false`); only this line changes
- runs KeyHelp's own `keyhelp-setup/install.sh` (init script, command `keyhelp-php56`, time zone); packages that appear during this run do not count as its own (they may come from another run), but are listed in `/var/lib/khli-php56/pakete-waehrend-install-sh.txt`
- installs the check tool `/usr/local/sbin/khli-php56` and the daily check `/etc/cron.d/khli-php56`
- verifies the result with `check` and records the list of modules; state in `/var/lib/khli-php56/`, logs in `/var/log/khli-php56/`; if KeyHelp's `install.sh` fails or `check` reports findings, the installer exits with code 1

KeyHelp's master cron job kills an `apt-get` that runs too long for it. Preferably do not install during KeyHelp's nightly maintenance windows (2 to 7 am). If an installation is aborted anyway, `khli-php56 uninstall` undoes everything, including packages already installed; then install again. A lock (`/run/khli-php56.lock`, kept until the next reboot) prevents two runs at the same time. If another program holds the package manager, apt waits up to ten minutes.

### Keep a copy of the original package

KeyHelp might one day remove the 5.6 package for Debian 12 from `repo.keyhelp.de`. The download then fails, and a kept copy helps:

```bash
curl -fsSLO https://repo.keyhelp.de/live/amd64/debian_12/php/5.6/php_5.6.40_20261103164601.tar.gz
sha256sum php_5.6.40_20261103164601.tar.gz
# 4ee240d31be9f1cc5cba853728b3bc6fe4aceaa18a1a0a3dafd0d282dbf5b6c6
bash install.sh -- --original /root/php_5.6.40_20261103164601.tar.gz
```

The copy is for your own server only; this project does not distribute KeyHelp's package.

### Without internet access

`--nur-laden <dir>` only fetches and verifies the release itself. A server without internet access additionally needs:

- KeyHelp's package as a file (`-- --original <file>`, see above)
- the runtime packages from Debian 13: either already installed or reachable through your own Debian mirror; `apt-get` otherwise needs the network
- `--ohne-zweiten-kanal`, because the release list is online; check approval and revocation by hand on the second channel

A preflight that reports all of this before the first change is still missing. If the original package is missing, the installer aborts before changing anything; if apt fails, a started state remains that `khli-php56 uninstall` cleans up.

## Use

- Select PHP version 5.6 for the domain in the panel. KeyHelp then writes the pool `/opt/keyhelp/php/5.6/etc/php-fpm.d/<BENUTZER>_php56.conf` itself, switches the vhost to the socket `/run/php/keyhelp_<BENUTZER>_php56.socket` and starts `keyhelp-php56-fpm`.
- Command line: `keyhelp-php56` (link to `/opt/keyhelp/php/5.6/bin/php`).
- After a reboot KeyHelp starts the service itself as soon as a domain needs it (on the test server after about 40 seconds).
- Moving a website from a Debian 12 server: take the domain's PHP settings in the panel with you. Limits such as `memory_limit` or `upload_max_filesize`, disabled functions, `short_open_tag` and the session cookie switches belong to the domain in KeyHelp and live in its pool, not in the interpreter. With KeyHelp's defaults instead of the previous settings an old application may behave differently.
- Gettext: selecting the language with the environment variable `LANGUAGE` has no effect on Debian 13 in the C.UTF-8 locale (glibc 2.41); applications should set a language locale such as `de_DE.UTF-8`. This applies to every PHP version on Debian 13.

## Check

`khli-php56 check` reports:

- whether the state is complete, the supplement unchanged and the seven modified files at their installed state
- whether all programs, extensions and private libraries find their libraries; if `ldd` itself fails on a file, for example because it is damaged, that is a finding as well
- whether `php -m` ends with exit code 0 and without startup errors, lists the core modules (Core, date, pcre, Reflection, SPL, standard) and lacks no module that was present at the last successful check (list `/var/lib/khli-php56/module.txt`, valid for the same original package); an additional module is not a finding
- whether the FPM configuration is valid (without a domain there is no pool, same as on Debian 12)
- whether init script and command exist and the service runs when KeyHelp has created pools
- as a hint, not a finding: whether KeyHelp's automatic update for 5.6 was switched on again (for example in the panel) or `config.ini` is missing; `update` switches it off again

If you switch a module off on purpose (for example remove a file in `etc/conf.d`), record the new state with `khli-php56 check --module-merken`.

The daily check runs at 7:40 am, after KeyHelp's maintenance job `php-update`, as `khli-php56 check --cron`: no output without findings; with findings a mail to root (via cron) and an entry in the system log (`journalctl -t khli-php56`). Hints alone do not trigger a mail. Exit code 1 means findings.

If the FPM service is ended from outside, KeyHelp did not restart it by itself on the test server. The check then reports that the service is not running although KeyHelp created pools; fix: `systemctl restart keyhelp-php56-fpm` (not `start`, systemd still considers the service active).

## Updating

Run `bash install.sh` with the same command as for the installation; it starts `khli-php56.sh update` with the release's supplement.

- Older version: if a newer one is installed, `update` refuses (exit 5), also when the installer is called directly; this is checked under the lock. `--aelter-erlauben` installs it anyway.
- Light branch: if the original package and the supplement are unchanged and `check` is fine, `update` only renews the check tool, the state and the module list and switches off KeyHelp's automatic update if it is on again (after backing up `etc/`, `config.ini` and logs). Interpreter and service stay untouched. `bash install.sh -- --neu-aufbauen` rebuilds anyway.
- Full branch: `update` builds the new directory next to the old one, backs up `etc/`, `config.ini` and logs to `/var/log/khli-php56/sicherung-<time>-update.tar.gz` and stops the service. If it still runs afterwards (waiting up to ten seconds), `update` does not swap and exits with code 1; the previous interpreter keeps running. Otherwise it takes over pools, time zone, `config.ini` and logs, swaps the directories, restarts the service and runs KeyHelp's `install.sh`, like KeyHelp's `php-update`. The swap counts as confirmed only once `check` is fine and check tool, version and module list are written.
- Rollback: if `check` reports findings afterwards (including a missing module) or the service does not start, the old directory comes back (exit 1). The same happens if the run is aborted by a signal during the swap, including HUP to the whole process group, as when an SSH session with a terminal drops (exit 129, 130, 141 or 143). The installer reports "bisheriger Stand wiederhergestellt" (previous state restored) only if the state and the ELF table are written back and the service runs again; otherwise it says what is missing, sets the state to faulty and exits with code 1. Packages installed by the `update` and files that KeyHelp's `install.sh` writes outside the directory are not rolled back. If a session without a terminal drops, no signal arrives: the run completes and keeps writing to the log. After SIGKILL or a power failure, the next `update` restores the previous directory if the target is missing; otherwise it stays with a warning until `uninstall` removes it. `install.sh` waits for the installer to finish and passes on its exit code.
- The domains stay on 5.6; their websites are unreachable for a few seconds (measured on the test server: under one second, for example 3 of 599 requests with HTTP 503).
- Manual changes to `etc/php.ini` or `etc/conf.d` are not taken over by `update`, as with KeyHelp's own update; they are in the backup and `update` names the affected files.

KeyHelp does not offer 5.6 for Debian 13 and therefore does not update it; in addition its switch for the automatic update of 5.6 is off, and the panel shows it that way. Whether KeyHelp's `php-update` honours the switch has not been observed; it would only matter if KeyHelp ever offered a 5.6 package for Debian 13.

## Removal

`khli-php56 uninstall`

- first checks whether 5.6 is used at these places: in KeyHelp's database (domains, scheduled tasks, default interpreter), KeyHelp pools for 5.6, crontabs calling `keyhelp-php56` or `/opt/keyhelp/php/5.6/`, and systemd units in `/etc/systemd/system` and `/usr/local/lib/systemd/system`; if so it refuses with exit 5. If the check itself fails, for example without database access, it refuses as well. Other calls, for example from your own scripts or programs, are not detected. `--trotz-domains` skips the check; affected websites have no PHP afterwards.
- also refuses if `/opt/keyhelp/php/5.6` does not contain the supplement, that is, does not come from this installer (`--trotz-fremdem-ordner` removes it anyway)
- backs up `etc/`, `config.ini` and logs to `/var/log/khli-php56/sicherung-<time>-uninstall.tar.gz`
- first restores a previous directory from the leftovers of an aborted update if the target is missing
- records the started removal in the state: if it is aborted, the next `uninstall` continues it, and `update` refuses until then
- runs KeyHelp's `uninstall.sh` and cleans up init script, command, directory, check tool, daily check and leftovers of aborted runs
- removes the packages the installer installed itself with `dpkg --purge`, which never removes a package another one depends on. Packages installed manually in the meantime, held packages and everything they need, packages other packages need, those whose libraries KeyHelp's other interpreters load and those that appeared during KeyHelp's `install.sh` are kept. Packages that should have been removed but could not be are listed in `/var/log/khli-php56/pakete-nicht-entfernt-<time>.txt`, and `uninstall` exits with code 1. `--pakete-behalten` keeps all packages.

The only thing that cannot be undone is apt upgrading an existing package to a newer version during installation (observed with a security update of `liblzma5`; no action needed; the installer names such packages). Logs and backups in `/var/log/khli-php56/` remain after the removal; they belong to root (mode 750 and 600).

## What changes on the system

| Change | Location | Removal |
|---|---|---|
| KeyHelp's interpreter package, unpacked from the unchanged archive | `/opt/keyhelp/php/5.6/` | `uninstall` via KeyHelp's `uninstall.sh` |
| supplement with private libraries | `/opt/keyhelp/php/5.6/lib/khli/` | with the directory |
| RUNPATH in seven ELF files, plus `NEEDED libssh2-khli.so.1` in `ssh2.so`; old and new SHA-256 in the state | in the interpreter directory, `/var/lib/khli-php56/elf-aenderungen.tsv` | with the directory |
| runtime packages from Debian 13, only if missing | package management | `uninstall`, with the exceptions above |
| check tool (copy of the installer) | `/usr/local/sbin/khli-php56` | `uninstall` |
| daily check | `/etc/cron.d/khli-php56` (7:40 am, read only) | `uninstall` |
| KeyHelp's switch for the automatic update of 5.6 off | `/opt/keyhelp/php/5.6/keyhelp-setup/config.ini` | with the directory; the previous file is in the backup |
| init script, command `keyhelp-php56`, time zone | by KeyHelp's own `install.sh` | KeyHelp's `uninstall.sh`, then the installer's cleanup |
| backups before `update` and `uninstall` | `/var/log/khli-php56/sicherung-*.tar.gz` (0600) | kept on purpose |
| state with module list, pinned release key and generation of the release list; logs, log of `install.sh` | `/var/lib/khli-php56/` (0700), `/var/log/khli-php56/` (0750) | state with `uninstall`, logs are kept |
| lock file | `/run/khli-php56.lock` | until the next reboot |

Not changed: system libraries, the default PHP version, `/etc/ld.so.conf.d` and the configuration of Apache and KeyHelp (KeyHelp writes that itself).

## Exit codes

| Code | Meaning |
|---|---|
| 0 | success |
| 1 | error: for example a download, another run active, check after installation or update with findings, service could not be stopped, rollback incomplete, apt would remove packages, removal with packages left behind |
| 2 | wrong usage, including an option after `--` that is not allowed; exceptionally also the status of a command that aborted under `set -e` in the installer (`tar`, `sort`, `dpkg-query`, for example with a full disk); its error message is then in the log |
| 3 | signature, checksum or archive layout wrong; release list badly signed or without generation; release key differs from the pinned one |
| 4 | requirement missing (not root, not Debian 13, no KeyHelp, no key, file not found, not enough space) |
| 5 | refused for protection: 5.6 in use, foreign directory, usage not verifiable, older version over a newer one; with `install.sh` also a revoked, unapproved or older release and a missing, expired or older release list |
| other values below 128 | status of a command that aborted under `set -e` in the installer, for example 100 from `apt-get` with a broken package source; its error message is in the log |
| 129, 130, 141, 143 | aborted by HUP, INT (Ctrl+C), PIPE or TERM; if the signal arrived during the swap of an `update`, the previous state is restored; with `uninstall` repeat it |

## Troubleshooting

| Message (German) | Cause | Fix |
|---|---|---|
| `die Signatur von SHA256SUMS ist ungültig` | release modified or not from Retrowork | install nothing; check the origin ([signing.md](signing.md)) |
| `dieses install.sh enthält keinen öffentlichen Schlüssel` | `install.sh` from the repository instead of a release | use the `install.sh` from a release |
| `Download gescheitert: …/SHA256SUMS (gibt es das Release?)` | no network, GitHub unreachable or the release does not exist | check network and `--version`, otherwise `--quelle` |
| `zweiter Kanal … nicht erreichbar` | domain of the second channel unreachable | try again later; without checking the approval only with `--ohne-zweiten-kanal` |
| `die Freigabeliste auf dem zweiten Kanal hat keine gültige Signatur` | the list is being renewed or was modified | try again later; if it persists, tell Retrowork |
| `die Freigabeliste ist seit … abgelaufen` | Retrowork did not renew the list in time | tell Retrowork; meanwhile `--ohne-zweiten-kanal` |
| `… kannte schon die Generation …` | the second channel serves an older list than the server already knew | install nothing; tell Retrowork |
| `Release … steht nicht in der Freigabeliste` | release not approved yet or not from Retrowork | try again later; choose another release |
| `Release … ist widerrufen` | Retrowork withdrew the release | choose another release |
| `dieser Server vertraut dem Release-Schlüssel …` | `install.sh` with a different key, for example from a fork | use Retrowork's `install.sh`; after an announced key change `--neuer-schluessel` |
| `Option für den Installer nicht erlaubt` | after `--` there is an option other than the three allowed ones | check the command |
| `SHA-256 von … ist …, erwartet …` | wrong or damaged file | download again; never bypass the check |
| `… existiert und stammt nicht von khli-php56` | 5.6 installed from elsewhere | remove or keep the existing state yourself |
| `es gibt schon einen Zustand …` | existing or aborted installation | `update` or `uninstall` |
| `ein anderer Lauf von khli-php56 ist aktiv` | second run at the same time | wait for the first |
| `installiert ist khli-php56 …, diese Fassung … ist älter` | older version over a newer one | use a newer release; deliberately only with `--aelter-erlauben` |
| `apt würde für … diese Pakete entfernen` | a package conflict on the server | resolve the conflict yourself, then try again; nothing installed, clean up a started state with `uninstall` |
| `Dienst keyhelp-php56-fpm ließ sich nicht anhalten; nichts getauscht` | the FPM service does not react to `stop` | check the `keyhelp-php56-fpm` processes, then try again |
| `bisheriger Ordner zurückgelegt, aber nicht vollständig wiederhergestellt: …` | something was missing in the rollback (state, ELF table or service) | `khli-php56 check`; then `bash install.sh -- --neu-aufbauen` |
| `KeyHelp nutzt PHP 5.6: …` | domains, tasks or default interpreter on 5.6 | switch them in the panel, then `uninstall` again |
| `… systemd-Unit-Datei(en) rufen PHP 5.6 auf` | your own services or timers use 5.6 | switch them, then `uninstall` again |
| `check: lib/khli fehlt (Interpreter von KeyHelp ersetzt?)` | the directory was replaced from outside | `bash install.sh -- --trotz-fremdem-ordner` restores this project's state |
| `check: … findet nicht: …` | library missing | `bash install.sh -- --neu-aufbauen`; check runtime packages |
| `check: ldd scheitert an …` | damaged file | `bash install.sh -- --neu-aufbauen` |
| `check: php -m endet mit Exit …` | PHP crashes on startup | check the log and `etc/conf.d`, then `bash install.sh -- --neu-aufbauen` |
| `check: gegenüber der letzten erfolgreichen Prüfung fehlen Module: …` | an ini in `etc/conf.d` is missing or an extension does not load | intended: `khli-php56 check --module-merken`; otherwise `bash install.sh -- --neu-aufbauen` |
| `check: Dienst … läuft nicht, obwohl KeyHelp Pools angelegt hat` | FPM master process ended | `systemctl restart keyhelp-php56-fpm`, `/opt/keyhelp/php/5.6/var/log/php-fpm.log` |
| domain shows error 503 | service not started | as in the row above |
| `ein früherer uninstall wurde abgebrochen (RUECKBAU=begonnen)` | an `uninstall` aborted after its first change | repeat `uninstall` |
| `deinstalliert bis auf Pakete, die stehen blieben (Liste: …)` | apt could not remove a package without removing foreign ones, or the package manager was locked | check list and log, remove the packages by hand with `apt-get purge` as far as nothing else needs them |
| `ssh2_auth_pubkey_file(): Authentication failed …` with an RSA key | the server refuses `ssh-rsa` (SHA-1), as with PHP 5.6 on Debian 12 | use ECDSA or Ed25519 keys |

## Known limitations

Inherited from the original on Debian 12, so the same there:

- PHP 5.6 receives no security fixes any more ([SECURITY.md](../../SECURITY.md)).
- `openssl_encrypt()` with ciphers that OpenSSL 3 does not offer without the legacy provider (bf, cast5, rc4, des, seed) crashes the process; FPM starts a new child.
- imagick can neither write nor read WebP while gd is loaded (gd shadows functions of libwebp); writing the MAT format fails because of a bug in Debian's ImageMagick 6 source.
- imap: local mailboxes other than INBOX are locked (Debian's c-client), and c-client finds no `mlock`; with KeyHelp, mailboxes are Maildir in Dovecot, not in the spool.
- `tls://` means TLS 1.0 in PHP 5.6 and fails against current servers; use `ssl://`.
- ssh2 authenticates with RSA keys only via `ssh-rsa` (SHA-1), which OpenSSH 8.8 and later refuses; ECDSA and Ed25519 keys work.

New with this project:

- The private libraries in the supplement receive no automatic updates. Debian maintains Debian 12 as LTS until mid 2028; new security levels of these source packages arrive as a new supplement in a new release ([building.md](building.md)).
- System libraries (OpenSSL 3.5, libxml2, libcurl, glibc and others) come from Debian 13 and receive its security updates; TLS and certificate verification are therefore at Debian 13's level.
- The installer checks that KeyHelp is present, but not its version; it is tested with KeyHelp 26.2 (build 3756).
