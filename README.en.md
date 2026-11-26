# keyhelp-legacy-php-interpreter

PHP 5.6 for KeyHelp on Debian 13 (amd64). A Retrowork project.

[Deutsche Fassung](README.md)

KeyHelp offers PHP 5.6 only up to Debian 12. This project sets up KeyHelp's own PHP 5.6 interpreter for Debian 12 on a KeyHelp server running Debian 13. It then shows up in the panel like the official interpreters, can be selected per domain and keeps the features it has on Debian 12.

> **Status:** release [0.4.15](https://github.com/Saugjunkie2/keyhelp-legacy-php-interpreter/releases/tag/v0.4.15) of 26 November 2026 is the first public release. Version 0.4.17 with the fixes from a third-party review and a second, independent counter-review is being prepared; this repository already shows its state ([CHANGELOG.md](CHANGELOG.md)). Install with the `install.sh` from a release (command below); the `install.sh` in this repository deliberately contains no key.

## Read this first

- PHP 5.6 has received no security fixes from php.net since 31 December 2018. It is meant for legacy applications that cannot be migrated, not for new projects. See [SECURITY.md](SECURITY.md) and [known limitations](docs/en/operation.md#known-limitations).
- This is an independent Retrowork project. It is not published by Keyweb AG (KeyHelp) or by The PHP Group.
- The project does not redistribute any KeyHelp files. On your server, the installer downloads KeyHelp's package from KeyHelp's official source `repo.keyhelp.de` and verifies its SHA-256.

## What it does

- unpacks KeyHelp's PHP 5.6 package for Debian 12 (`php_5.6.40_20261103164601.tar.gz`) from the unchanged original archive into `/opt/keyhelp/php/5.6`
- adapts only what Debian 13 requires: six libraries built from the Debian 12 sources (the supplement, "Ergänzungssatz") in `/opt/keyhelp/php/5.6/lib/khli`, an adjusted library search path (RUNPATH) in seven files (six extensions and the bundled ICU), in `ssh2.so` also the name of the private libssh2, and missing runtime packages from Debian 13; the programs `php`, `php-cgi` and `php-fpm` stay KeyHelp's files
- then runs KeyHelp's own setup script, just like KeyHelp's maintenance job `php-update` does
- replaces no system library, removes no package during installation and does not change the default PHP version
- switches off KeyHelp's automatic update for 5.6, because KeyHelp has no 5.6 package for Debian 13; updates come from this project
- installs the check tool `khli-php56` and a daily check

## Requirements

- Debian 13 (amd64) with KeyHelp installed; tested with KeyHelp 26.2 (build 3756)
- root access, internet access to `github.com`, `lizenz.retrowork.de`, `repo.keyhelp.de` and the Debian mirrors
- about 400 MB free in `/opt`, about 700 MB for an update, plus 200 MB in `/var/tmp`
- `openssl` and `curl` or `wget` (present on KeyHelp servers)

## Installation

As root on the server:

```bash
curl -fsSL https://github.com/Saugjunkie2/keyhelp-legacy-php-interpreter/releases/latest/download/install.sh | bash
```

`install.sh` verifies the release signature and every file, asks the second channel for the approval and only then starts the installer. Without a valid signature or approval it changes nothing; only `--ohne-zweiten-kanal` leaves the approval, and with it a revocation, unchecked. Afterwards select PHP version 5.6 for the domain in the panel.

This command trusts GitHub and the encrypted connection to it: a manipulated `install.sh` could skip every check. If you do not want that, verify `install.sh` before starting it, with the key from the second channel. This is independent of GitHub only if you take the following block from the second channel's page (https://lizenz.retrowork.de/keyhelp-legacy-php-interpreter/), because this README itself is on GitHub; the same block is shown there:

```bash
cd "$(mktemp -d)"
basis=https://github.com/Saugjunkie2/keyhelp-legacy-php-interpreter/releases/latest/download
curl -fsSLO "$basis/install.sh" && curl -fsSLO "$basis/SHA256SUMS" && curl -fsSLO "$basis/SHA256SUMS.sig" &&
curl -fsSL -o release-ed25519.pub https://lizenz.retrowork.de/keyhelp-legacy-php-interpreter/release-ed25519.pub &&
openssl pkey -pubin -in release-ed25519.pub -outform DER | sha256sum | grep -q '^6db970b09f586927f6f216b317c831261b95b254e29219d2a402e4c30d4a6c41 ' &&
openssl pkeyutl -verify -pubin -inkey release-ed25519.pub -rawin -in SHA256SUMS -sigfile SHA256SUMS.sig &&
sha256sum --ignore-missing -c SHA256SUMS &&
bash install.sh
```

Every step must succeed, otherwise the chain stops and nothing starts: download, fingerprint of the key from the second channel, signature of `SHA256SUMS` (output `Signature Verified Successfully`), SHA-256 of `install.sh` (output `install.sh: OK`).

`bash install.sh --hilfe` lists all options (the scripts speak German). A server without internet access gets the release via `--nur-laden <dir>` on another machine and `--quelle <dir>` on the server; it then also needs KeyHelp's package as a file, the runtime packages from Debian 13 (already installed or through your own mirror) and `--ohne-zweiten-kanal` ([docs/en/operation.md](docs/en/operation.md#without-internet-access)).

KeyHelp might remove its 5.6 package for Debian 12 one day. To be prepared, keep a copy and pass it with `bash install.sh -- --original <file>` when needed; the installer verifies it against the pinned SHA-256 as well ([docs/en/operation.md](docs/en/operation.md#keep-a-copy-of-the-original-package)).

## Updating

Running the installation command again installs the newest release (`update`). `install.sh` installs an older release over a newer one only with `--aelter-erlauben`. The 5.6 websites are unreachable for a few seconds during the swap; if anything fails, the installer restores the previous state and says whether that succeeded completely. Automatic updates are planned, see [CHANGELOG.md](CHANGELOG.md).

## Check, status, removal

```bash
khli-php56 check      # files, libraries, modules, FPM configuration and service
khli-php56 status     # version, state and service
khli-php56 uninstall  # full removal; refuses as long as one of the checked places uses 5.6
```

`uninstall` detects use by KeyHelp (domains, scheduled tasks, default interpreter, pools), by crontabs and by systemd units, but not calls from your own scripts. Details, exit codes and troubleshooting: [docs/en/operation.md](docs/en/operation.md).

## Tamper protection

Every release contains `SHA256SUMS` with the SHA-256 of all files and `SHA256SUMS.sig`, an Ed25519 signature over it. Only Retrowork holds the private key; it is not stored in any repository. Only what is signed with this key is official.

Fingerprint of the public key [`schluessel/release-ed25519.pub`](schluessel/release-ed25519.pub) (SHA-256 over the key in DER form):

```
SHA256:6db970b09f586927f6f216b317c831261b95b254e29219d2a402e4c30d4a6c41
```

The same fingerprint and the key are published on the second channel `https://lizenz.retrowork.de/keyhelp-legacy-php-interpreter/`, together with the signed list of approved and revoked releases. From `install.sh` 1.1.0 the second channel blocks when in doubt: if the list is unreachable, badly signed, expired or older than one already known, or the release is not listed as approved, nothing starts. The server also pins the key of its first installation and accepts an `install.sh` with a different key only after an announced key change. Details and limits: [docs/en/signing.md](docs/en/signing.md).

## What has been tested

Status: version 0.4.17. Supplement 1.1.0 and KeyHelp's package are unchanged since release 0.4.15; the functional comparison, use with KeyHelp and the loaders therefore still apply. Installer, `install.sh` and tools are tested with 0.4.17.

| Test | Result | How |
|---|---|---|
| Functional comparison with KeyHelp's 5.6 on Debian 12 | 2,066 checks equal, 15 justified exceptions, none unjustified; the test across cli, cgi and fpm produces byte-identical output as on Debian 12 | on a test server with Debian 13 and KeyHelp, reference in a Debian 12 environment |
| Installer 0.4.17: installation, update, removal, errors and aborts in 78 cases | all as expected; after every removal the same package state as before | in a minimal Debian 13 environment (chroot) |
| Use with KeyHelp | 5.6 selectable in the panel, KeyHelp creates pool and vhost and starts the service; websites, reboot, KeyHelp's maintenance jobs; update with less than one second of downtime (measured with installer 0.4.14) | on the test server; visual check in the panel by Retrowork |
| ionCube and SourceGuardian loaders | load and work as on Debian 12, including an application file encoded for PHP 5 in 2010 | in chroots and on the test server |
| `install.sh` 1.1.1 and the release tools | signature, checksums, release list with generation and expiry date, revocation, key change, pinned key, older releases and installer start as expected in 149 cases; a signed test release with installer 0.4.17 applied as an update through its `install.sh`, in the light and the full branch, afterwards `check` and the website fine; the verify-before-start path literally with two counter-probes; release 0.4.15 applied from GitHub with the command from this README, signature and release list valid | on Windows (Git Bash) and as root in a Debian 13 chroot; end to end on the test server ([tests/](tests/)) |

The public CI (`.github/workflows/tests.yml`) runs the tests of `install.sh` and the tools on Ubuntu and as root on Debian 13, verifies the origin of the uw-imap source package and checks the published release with the second channel daily. The functional and installer tests so far run on a Retrowork test server; their results are shown here, the tests themselves are not published yet.

Not tested: a KeyHelp self-update to a new major version; whether KeyHelp's `php-update` honours the switched-off setting (only relevant if KeyHelp ever offered a 5.6 package for Debian 13); use on many different servers. A static third-party review of 26 November 2026 raised 25 points; what follows from it is in [CHANGELOG.md](CHANGELOG.md).

## Known limitations

Inherited from the original on Debian 12, with workarounds in [docs/en/operation.md](docs/en/operation.md#known-limitations): `openssl_encrypt()` with old ciphers (bf, cast5, rc4, des, seed) crashes the process; imagick cannot handle WebP while gd is loaded; `tls://` means TLS 1.0 in PHP 5.6, use `ssl://`; ssh2 authenticates with RSA keys only via `ssh-rsa` (SHA-1), ECDSA and Ed25519 keys work. The private libraries receive security updates only through a new release of this project.

## Layout

```
install.sh                one-command installation, verifies signature, files and approval
installer/khli-php56.sh   the installer: install, update, check, status, uninstall
build/                    build recipes of the supplement
fremdquellen/             uw-imap source package (Sury) and Sury's signed indexes for verification
werkzeuge/                build, sign and verify releases; key; release list; verify origin
schluessel/               public key for the signatures
tests/                    tests of install.sh, the tools and the published release
docs/                     operation, signatures and build (German), English in docs/en/
.github/workflows/        public CI
```

The supplement is not stored in the repository but attached as a file to every release.

## License and names

The project's own code is licensed under the [Apache License 2.0](LICENSE). The libraries in the supplement keep their own licenses ([NOTICE](NOTICE), [docs/en/licenses.md](docs/en/licenses.md)). KeyHelp's package is not included. The license grants no rights to the name Retrowork: modified versions must not present themselves as a Retrowork release. KeyHelp is a trademark of Keyweb AG, PHP a trademark of The PHP Group.

## Contributing

Issues and pull requests are welcome, in German or English: [CONTRIBUTING.md](CONTRIBUTING.md). Please do not report security issues publicly; see [SECURITY.md](SECURITY.md).
