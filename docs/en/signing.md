# Signatures and tamper protection

Applies to `install.sh` 1.1.0 and the tools 1.1.0 in `werkzeuge/`. [Deutsche Fassung](../signatur.md)

Goal: anyone installing this project can verify that a release comes from Retrowork and has not been modified. This is done with signatures, not with an encrypted license check; the code stays readable.

## Chain of trust

1. The public Ed25519 key is embedded in the `install.sh` of every release, and also published in `schluessel/release-ed25519.pub`, as a fingerprint in the README and on the second channel: `SHA256:6db970b09f586927f6f216b317c831261b95b254e29219d2a402e4c30d4a6c41`. Only Retrowork holds the private key; it is not stored in any repository.
2. `SHA256SUMS.sig` is the Ed25519 signature over `SHA256SUMS`.
3. `SHA256SUMS` lists the SHA-256 of every file of the release: `install.sh`, `khli-php56.sh`, `RELEASE` and the supplement.
4. `RELEASE` names product, version, system, installer, supplement, KeyHelp's original package with its SHA-256, the `install.sh` version, the commit and the date.
5. The installer pins the SHA-256 of KeyHelp's original package and of the supplement and verifies both before changing anything.
6. The second channel `https://lizenz.retrowork.de/keyhelp-legacy-php-interpreter/` lists the approved and the revoked releases, signed with the same key.

Every file that reaches the server is therefore either signed itself or bound by a signed checksum, KeyHelp's package by the checksum in the signed installer.

## The limit: the first script

A manipulated `install.sh` can skip every check and print any fingerprint. The signatures therefore only protect from the moment a genuine `install.sh` runs. Running the README command as a pipe means trusting GitHub and the encrypted connection to it. If you do not want that, verify `install.sh` before starting it, with the key from the second channel, independent of GitHub:

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

The steps: in a new empty directory, download the three release files from GitHub and the key from the second channel; the key must have the fingerprint `6db970b09f586927f6f216b317c831261b95b254e29219d2a402e4c30d4a6c41` (README, second channel); `SHA256SUMS` must carry a valid signature by it (output `Signature Verified Successfully`), and `install.sh` must have the SHA-256 listed in `SHA256SUMS` (output `install.sh: OK`). If a step fails, the chain stops and `install.sh` does not start.

`tests/veroeffentlichung-pruefen.sh` does exactly this with the key from this repository and runs daily in the public CI.

Once `install.sh` has run, the server pins the key (`/var/lib/khli-php56/release-ed25519.pub`). A later `install.sh` with a different key starts the installer only with `--neuer-schluessel`. This does not help against a manipulated script, but it does against a mix-up, for example with a fork; and the planned automatic updates verify against this key.

## What install.sh verifies

| Check | on failure |
|---|---|
| the embedded key is an Ed25519 key | exit 3; without a key (state from the repository) exit 4 |
| after `--` only `--neu-aufbauen`, `--trotz-fremdem-ordner` and `--original <file>` for the installer | exit 2 |
| `SHA256SUMS.sig` has 64 bytes and is a valid signature over `SHA256SUMS` | exit 3, nothing changed |
| every line of `SHA256SUMS` has the form `<sha256>  <file>`, file names without paths, none twice, at most 20 | exit 3 |
| every file has the SHA-256 from `SHA256SUMS` | exit 3 |
| `RELEASE`: all eleven fields exactly once and in a fixed format; product, system, version; with `--version` the same version | exit 3 |
| `RELEASE` matches the installer: version, original package with SHA-256, name and SHA-256 of the supplement | exit 3 |
| the release does not require a newer `install.sh` (`INSTALL_SH_MIN`) | exit 4 |
| the second channel: list reachable, validly signed, with generation and expiry date, not expired, not older than the list the server already knew, and the release listed as `gueltig` (valid) | exit 5, with a wrong signature or missing generation exit 3 |
| when installing: the server does not pin a different key (otherwise only with `--neuer-schluessel`) | exit 3 |
| the release is not older than the installed version (otherwise only with `--aelter-erlauben`; from installer 0.4.16 the installer checks this again under its lock) | exit 5 |

For the newest release, `install.sh` downloads all further files under the release's fixed name `v<version>` after checking `RELEASE`, so that a new release appearing at the same time mixes nothing.

Without installing and without root, `bash install.sh --nur-pruefen` performs the same checks. With a clone of this repository, `bash werkzeuge/release-pruefen.sh <dir>` additionally verifies that `install.sh` and `khli-php56.sh` in the release are exactly the files in the repository and that the commit from `RELEASE` exists here.

## Second channel

Address: `https://lizenz.retrowork.de/keyhelp-legacy-php-interpreter/`, independent of GitHub. It holds:

| File | Content |
|---|---|
| `release-ed25519.pub` | the public key, to compare with the fingerprint |
| `freigaben.txt` | a header with `# generation <n>` and `# gueltig-bis <YYYY-MM-DD>` (valid until), then one line per release: `<version> <sha256 of SHA256SUMS> <gueltig\|widerrufen> <date> [reason]` (`gueltig` = valid, `widerrufen` = revoked) |
| `freigaben.txt.sig` | Ed25519 signature over `freigaben.txt`, with the same key |
| `index.html` | a page for visitors with fingerprint and verification commands |

`install.sh` downloads `freigaben.txt` and its signature before every installation. From 1.1.0 it blocks when in doubt:

| Case | Behaviour |
|---|---|
| release listed as `gueltig`, list validly signed and not expired | continue |
| release listed as `widerrufen` | abort, exit 5, with the reason; there is no switch to override it |
| release not in the list, unknown status | abort, exit 5 |
| list expired (`gueltig-bis` before today) | abort, exit 5 |
| list with a lower generation than the server already knew (`/var/lib/khli-php56/freigaben-generation`) | abort, exit 5: an older list could hide a revocation |
| list without generation or expiry date, invalid signature | abort, exit 3 |
| list unreachable | abort, exit 5 |
| `--ohne-zweiten-kanal` | warning, continue; approval and revocation stay unchecked |

The `install.sh` 1.0.0 from release 0.4.15 only warned in these cases; releases from 0.4.16 require `install.sh` 1.1.0 or later.

## What the protection does not cover

- A manipulated `install.sh` can display anything; only the verification before starting it, above, protects against that.
- Releases and the release list carry the same key. If it is compromised, this procedure cannot block it retroactively; a separate root key kept offline that authorizes and revokes release keys is planned for a later version. Until then the protection lies in keeping the private key safe.
- A signature says who published a release, not that it is free of bugs. PHP 5.6 itself has known, unfixed vulnerabilities ([SECURITY.md](../../SECURITY.md)).
- So far a server only verifies during a run of `install.sh`. The planned automatic updates will verify against the pinned key, and the daily check is to compare the installed files with a signed manifest.

## Release procedure

For the project maintainers; only steps 4 and 6 need the private key.

1. Tests: the public CI (`.github/workflows/tests.yml`: `tests/werkzeuge-test.sh` on Ubuntu and as root in Debian 13, `werkzeuge/sury-echtheit-pruefen.sh`); on a test server `bash tests/ende-zu-ende.sh --testserver <supplement> --voll`. If the installer or the supplement changes, additionally the functional and installer tests from [building.md](building.md).
2. Commit and push to `main`; the working tree is clean.
3. `bash werkzeuge/release-bauen.sh <supplement.tar.xz>` produces `dist/v<version>/` without a signature. It checks the supplement against the installer and embeds the key from `schluessel/release-ed25519.pub` in `install.sh`.
4. `bash werkzeuge/release-signieren.sh dist/v<version> <private-key>` signs `SHA256SUMS` and immediately verifies the signature against the key in the release.
5. `bash werkzeuge/release-pruefen.sh dist/v<version>` verifies everything independently.
6. `bash werkzeuge/freigabe-eintragen.sh <freigaben.txt> dist/v<version> <private-key>` adds the release as valid, raises the generation and sets the expiry date (default 365 days, `--gueltig-tage <n>`). Upload `freigaben.txt` and `freigaben.txt.sig` together to the second channel, in binary mode; between the two uploads `install.sh` briefly refuses the list. **Only then** step 7, otherwise `install.sh` refuses the new release because it is not in the list.
7. GitHub release with the tag `v<version>` and exactly the files from `dist/v<version>/`, for example `gh release create v0.4.16 dist/v0.4.16/* --title "0.4.16" --notes-file <notes>`.
8. Verify: `bash tests/veroeffentlichung-pruefen.sh`.

Renewing: before the expiry date at the latest, `bash werkzeuge/freigabe-eintragen.sh --erneuern <freigaben.txt> <private-key>` and upload both files; the daily CI reports a list that expires in less than 30 days. Revoking: `bash werkzeuge/freigabe-eintragen.sh <freigaben.txt> <release-dir> <private-key> widerrufen "<reason>"`, then upload and add a note to the GitHub release.

## Creating the key

Once, preferably so that the private key is afterwards kept offline on a medium:

```bash
bash werkzeuge/schluessel-erzeugen.sh /path/to/medium
```

The script asks twice for a passphrase (at least 12 characters), writes the encrypted private key to `/path/to/medium/khli-release-ed25519.key` (never into the repository, the script refuses that) and the public key to `schluessel/release-ed25519.pub`. Afterwards back up the private key on a second medium, keep the passphrase separately, commit `schluessel/release-ed25519.pub` and publish the fingerprint in the README and on the second channel.

## Lost or compromised key

- Lost, but not in other hands: `bash werkzeuge/schluessel-erzeugen.sh --ersetzen <dir>`, publish the new fingerprint in the README and on the second channel, sign the next release and the release list with the new key. Servers with the old key accept the new `install.sh` only with `--neuer-schluessel`; the change is therefore announced in the README, on the second channel and with the release.
- Compromised: likewise create a new key and list the releases signed with the old key as revoked in a new list; add a clear notice to the README, the second channel and the releases. An old `install.sh` considers this list badly signed and aborts (from 1.1.0) or warns (1.0.0). This procedure cannot block a compromised key retroactively (see above).
