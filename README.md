# linux-packages

Signed apt, dnf and zypper repositories for optionfactory's tools, served by
GitHub Pages from this repository.

## Setup

Every step below runs unattended, so the same commands work in a terminal, a
provisioning script or a Dockerfile (drop `sudo` where you are already root).

### Debian and Ubuntu (`amd64`)

```bash
sudo install -d -m 0755 /etc/apt/keyrings
sudo curl -fsSLo /etc/apt/keyrings/optionfactory.asc https://optionfactory.github.io/linux-packages/key.asc
sudo tee /etc/apt/sources.list.d/optionfactory.sources >/dev/null <<'EOF'
Types: deb
URIs: https://optionfactory.github.io/linux-packages/deb
Suites: stable
Components: main
Signed-By: /etc/apt/keyrings/optionfactory.asc
EOF
sudo apt update
sudo apt install -y docker-bluff
```

### Fedora, RHEL 9 and derivatives (`x86_64`)

```bash
sudo rpm --import https://optionfactory.github.io/linux-packages/key.asc
sudo curl -fsSLo /etc/yum.repos.d/optionfactory.repo https://optionfactory.github.io/linux-packages/optionfactory.repo
sudo dnf install -y docker-bluff
```

### openSUSE (`x86_64`)

```bash
sudo rpm --import https://optionfactory.github.io/linux-packages/key.asc
sudo zypper --non-interactive addrepo https://optionfactory.github.io/linux-packages/optionfactory.repo
sudo zypper --non-interactive install docker-bluff
```

Importing the key up front is what keeps dnf and zypper from asking to trust it
on the first install.

### Checking the key

The repository is signed with this key:

```console
$ curl -fsSL https://optionfactory.github.io/linux-packages/key.asc | gpg --show-keys
pub   ed25519 2026-09-30 [SC]
      9FE6CDC2B377ECF54D7E974580C79C8962B033BB
uid                      packages <roberto@optionfactory.net>
```

In a script, pin the fingerprint so that setup fails on any other key:

```bash
curl -fsSL https://optionfactory.github.io/linux-packages/key.asc \
    | gpg --show-keys --with-colons \
    | grep -q '^fpr:*9FE6CDC2B377ECF54D7E974580C79C8962B033BB:$' \
    || { echo "unexpected optionfactory repository key" >&2; exit 1; }
```

### In a Dockerfile

```dockerfile
FROM debian:trixie
ADD --chmod=644 https://optionfactory.github.io/linux-packages/key.asc /etc/apt/keyrings/optionfactory.asc
RUN apt update \
    && apt install -y --no-install-recommends ca-certificates \
    && printf '%s\n' 'Types: deb' \
        'URIs: https://optionfactory.github.io/linux-packages/deb' \
        'Suites: stable' 'Components: main' \
        'Signed-By: /etc/apt/keyrings/optionfactory.asc' \
        > /etc/apt/sources.list.d/optionfactory.sources \
    && apt update \
    && apt install -y --no-install-recommends docker-snitch \
    && rm -rf /var/lib/apt/lists/*
```

```dockerfile
FROM almalinux:9
RUN rpm --import https://optionfactory.github.io/linux-packages/key.asc \
    && curl -fsSLo /etc/yum.repos.d/optionfactory.repo https://optionfactory.github.io/linux-packages/optionfactory.repo \
    && dnf install -y docker-snitch \
    && dnf clean all
```

Updates arrive with the usual `apt upgrade`, `dnf upgrade` or `zypper update`.

## Packages

| Package | From |
| --- | --- |
| `docker-bluff`, `docker-intrude`, `docker-snitch` | [docker-heist](https://github.com/optionfactory/docker-heist) |
| `pinch` | [pinch](https://github.com/optionfactory/pinch) |
| `optionfactory-posture` (Debian and Ubuntu only) | [optionfactory-posture](https://github.com/optionfactory/optionfactory-posture) |
| `optionfactory-hooks` (Debian and Ubuntu only) | [optionfactory-hooks](https://github.com/optionfactory/optionfactory-hooks) |
| `elaine` | [elaine](https://github.com/optionfactory/elaine) |
| `rbw` | [doy/rbw](https://github.com/doy/rbw), upstream release binaries repackaged |
| `aws-cli` (Debian and Ubuntu only) | [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html), the official Linux build repackaged; replaces the distribution's `awscli` |

## Publishing

Packages are built from the latest GitHub release of each repository in
`SOURCES` (see the Makefile): each `packages/<name>/` becomes a `.deb` and an
`.rpm` of the release asset `<name>-linux-amd64-musl`, checked against the
release's `SHA256SUMS`; only a `.deb` when the directory has a `deb-only` file.
Packages of someone else's tools have an `upstream` file instead (`<owner/repo> <version> <asset> <sha256>`):
that release, pinned, so an update is a reviewed commit that changes the version and the hash. A zip served outside
GitHub has a `download` file (`<version> <url> <sha256>`) the same way. After releasing any of them, rebuild and publish
everything with:

```bash
make deps   # one-time: gh, apt-utils, createrepo-c, rpm, gnupg, curl, unzip and nfpm
make publish
```

`make build` does the same without pushing, into `target/site`. `publish`
signs with `GPG_KEY` and force-pushes the site to the `gh-pages` branch, which
GitHub Pages serves. When only the packaging changes, bump `release` in the
package's `nfpm.yaml` so that installed copies get upgraded.

### Updating aws-cli

By hand, when a newer version is needed (AWS releases almost daily): the latest `2.x` tag of
[aws/aws-cli](https://github.com/aws/aws-cli/tags), its zip checked against the signature with the key of the AWS CLI
team (fingerprint `FB5D B77F D5C1 18B8 0511 ADA8 A631 0ACC 4672 475C`, published in the
[install guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)), then its hash in
`packages/aws-cli/download`:

```bash
v=2.41.2
curl -fsSLO "https://awscli.amazonaws.com/awscli-exe-linux-x86_64-$v.zip"
curl -fsSLO "https://awscli.amazonaws.com/awscli-exe-linux-x86_64-$v.zip.sig"
gpg --verify "awscli-exe-linux-x86_64-$v.zip.sig" "awscli-exe-linux-x86_64-$v.zip"   # Good signature, that fingerprint
echo "$v https://awscli.amazonaws.com/awscli-exe-linux-x86_64-$v.zip $(sha256sum "awscli-exe-linux-x86_64-$v.zip" | cut -d' ' -f1)" \
    > packages/aws-cli/download
```
