# Signatures and tamper protection

Applies to `install.sh` 1.0.0 and the tools 1.0.0 in `werkzeuge/`. [Deutsche Fassung](../signatur.md)

Goal: anyone installing this project can verify that a release comes from Retrowork and has not been modified. This is done with signatures, not with an encrypted license check; the code stays readable.

## Chain of trust

1. The public Ed25519 key is embedded in the `install.sh` of every release, and also published in `schluessel/release-ed25519.pub`, as a fingerprint in the README and on the second channel: `SHA256:6db970b09f586927f6f216b317c831261b95b254e29219d2a402e4c30d4a6c41`. Only Retrowork holds the private key; it is not stored in any repository.
2. `SHA256SUMS.sig` is the Ed25519 signature over `SHA256SUMS`.
3. `SHA256SUMS` lists the SHA-256 of every file of the release: `install.sh`, `khli-php56.sh`, `RELEASE` and the supplement.
4. `RELEASE` names product, version, system, installer, supplement, KeyHelp's original package with its SHA-256, the commit and the date.
5. The installer pins the SHA-256 of KeyHelp's original package and of the supplement and verifies both before changing anything.

Every file that reaches the server is therefore either signed itself or bound by a signed checksum, KeyHelp's package by the checksum in the signed installer.

## What install.sh verifies

| Check | on failure |
|---|---|
| the embedded key is an Ed25519 key | exit 3; without a key (state from the repository) exit 4 |
| `SHA256SUMS.sig` has 64 bytes and is a valid signature over `SHA256SUMS` | exit 3, nothing changed |
| every line of `SHA256SUMS` has the form `<sha256>  <file>`, file names without paths, none twice, at most 20 | exit 3 |
| every file has the SHA-256 from `SHA256SUMS` | exit 3 |
| `RELEASE`: every line `KEY=value`, product `keyhelp-legacy-php-interpreter`, system `debian13-amd64`, valid version, installer and supplement listed in `SHA256SUMS`; with `--version` the same version | exit 3 |
| the version in the installer is the release version | exit 3 |
| the release does not require a newer `install.sh` (`INSTALL_SH_MIN`) | exit 4 |
| the second channel does not list the release as revoked | exit 5 |
| the release is not older than the installed version (otherwise only with `--aelter-erlauben`) | exit 5 |

For the newest release, `install.sh` downloads all further files under the release's fixed name `v<version>` after checking `RELEASE`, so that a new release appearing at the same time mixes nothing.

## Verify yourself

With `install.sh`, without installing anything and without root:

```bash
bash install.sh --nur-pruefen
```

By hand with OpenSSL 3.0 or later, for a release `v<version>`:

```bash
basis=https://github.com/Saugjunkie2/keyhelp-legacy-php-interpreter/releases/download/v0.4.15
curl -fsSLO "$basis/SHA256SUMS"
curl -fsSLO "$basis/SHA256SUMS.sig"
curl -fsSLO https://raw.githubusercontent.com/Saugjunkie2/keyhelp-legacy-php-interpreter/main/schluessel/release-ed25519.pub
openssl pkey -pubin -in release-ed25519.pub -outform DER | sha256sum
# must be the fingerprint from the README and the second channel
openssl pkeyutl -verify -pubin -inkey release-ed25519.pub -rawin -in SHA256SUMS -sigfile SHA256SUMS.sig
# Signature Verified Successfully
for f in $(awk '{print $2}' SHA256SUMS); do curl -fsSLO "$basis/$f"; done
sha256sum -c SHA256SUMS
```

With a clone of this repository, `bash werkzeuge/release-pruefen.sh <dir>` additionally verifies that `install.sh` and `khli-php56.sh` in the release are exactly the files in the repository.

## Second channel

Address: `https://lizenz.retrowork.de/keyhelp-legacy-php-interpreter/`, independent of GitHub. It holds:

| File | Content |
|---|---|
| `release-ed25519.pub` | the public key, to compare with the fingerprint |
| `freigaben.txt` | one line per release: `<version> <sha256 of SHA256SUMS> <gueltig\|widerrufen> <date> [reason]` (`gueltig` = valid, `widerrufen` = revoked) |
| `freigaben.txt.sig` | Ed25519 signature over `freigaben.txt`, with the same key |

`install.sh` downloads `freigaben.txt` and its signature before every installation (`--ohne-zweiten-kanal` skips this):

| Case | Behaviour |
|---|---|
| release listed as `gueltig` | message, continue |
| release listed as `widerrufen` | abort with exit 5 and the reason; there is no switch to override it |
| release not in the list | warning, continue |
| list unreachable or signature invalid | warning, continue |

Why only warnings when the list is missing: the release signature is the actual protection. The second channel adds revocations and a second place for the fingerprint, separate from GitHub; an outage of the domain should not prevent installations.

## What the protection does not cover

- Someone who took over the GitHub account could publish an `install.sh` with a different key. Comparing the fingerprint that `install.sh` prints on every run (`Schlüssel SHA256:…`) with the second channel protects against this. To be completely sure, download `install.sh` first and verify it by hand as above.
- A signature says who published a release, not that it is free of bugs. PHP 5.6 itself has known, unfixed vulnerabilities ([SECURITY.md](../../SECURITY.md)).
- So far a server only verifies during a run of `install.sh`. The planned automatic updates will verify against the key already on the server, and the daily check is to compare the installed files with the signed manifest.

## Release procedure

For the project maintainers; only steps 4 and 6 need the private key.

1. Tests: `bash tests/werkzeuge-test.sh` on Linux or Git Bash; as root in a Debian 13 chroot for part B; on a test server `bash tests/ende-zu-ende.sh --testserver <supplement> --voll`. If the installer or the supplement changes, additionally the functional and installer tests from [building.md](building.md).
2. Commit and push to `main`; the working tree is clean.
3. `bash werkzeuge/release-bauen.sh <supplement.tar.xz>` produces `dist/v<version>/` without a signature. It checks the supplement against the installer and embeds the key from `schluessel/release-ed25519.pub` in `install.sh`.
4. `bash werkzeuge/release-signieren.sh dist/v<version> <private-key>` signs `SHA256SUMS` and immediately verifies the signature against the key in the release.
5. `bash werkzeuge/release-pruefen.sh dist/v<version>` verifies everything independently.
6. `bash werkzeuge/freigabe-eintragen.sh <freigaben.txt> dist/v<version> <private-key>` adds the release as valid; `freigaben.txt`, `freigaben.txt.sig` and `schluessel/release-ed25519.pub` go to the second channel.
7. GitHub release with the tag `v<version>` and exactly the files from `dist/v<version>/`, for example `gh release create v0.4.15 dist/v0.4.15/* --title "0.4.15" --notes-file <notes>`.
8. Verify on a server: `bash install.sh --nur-pruefen` (downloads from GitHub).

Revoking: `bash werkzeuge/freigabe-eintragen.sh <freigaben.txt> <release-dir> <private-key> widerrufen "<reason>"`, then upload the list and add a note to the GitHub release.

## Creating the key

Once, preferably on a machine whose private key is afterwards kept offline on a separate medium:

```bash
bash werkzeuge/schluessel-erzeugen.sh /path/to/medium
```

The script asks twice for a passphrase (at least 12 characters), writes the encrypted private key to `/path/to/medium/khli-release-ed25519.key` (never into the repository, the script refuses that) and the public key to `schluessel/release-ed25519.pub`. Afterwards back up the private key on a second medium, keep the passphrase separately, commit `schluessel/release-ed25519.pub` and publish the fingerprint in the README and on the second channel.

## Lost or compromised key

- Lost, but not in other hands: `bash werkzeuge/schluessel-erzeugen.sh --ersetzen <dir>`, publish the new fingerprint in the README and on the second channel, sign the next release with the new key. An old `install.sh` accepts only the old key; users take the `install.sh` from the new release.
- Compromised: likewise create a new key and list all releases signed with the old key as revoked in a new list signed with the new key; add a clear notice to the README, the second channel and the releases. An old `install.sh` considers this list badly signed and only warns. This procedure therefore cannot block a compromised key retroactively; the protection lies in keeping it offline.
