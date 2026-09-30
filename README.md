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

## Publishing

Packages are built from the latest GitHub release of each repository in
`SOURCES` (see the Makefile): each `packages/<name>/` becomes a `.deb` and an
`.rpm` of the release asset `<name>-linux-amd64-musl`, checked against the
release's `SHA256SUMS`. After releasing any of them, rebuild and publish
everything with:

```bash
make deps   # one-time: gh, apt-utils, createrepo-c, rpm, gnupg and nfpm
make publish
```

`make build` does the same without pushing, into `target/site`. `publish`
signs with `GPG_KEY` and force-pushes the site to the `gh-pages` branch, which
GitHub Pages serves. When only the packaging changes, bump `release` in the
package's `nfpm.yaml` so that installed copies get upgraded.
