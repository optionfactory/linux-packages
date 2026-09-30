#!/bin/sh
# usage: build.sh <out-dir> <gpg-key> <base-url> <owner/repo>...
set -eu

[ $# -ge 4 ] || { sed -n '2p' "$0" >&2; exit 2; }
out=$(realpath -m "$1")
key=$2
base_url=$3
shift 3
cd "$(dirname "$0")"

die() { echo "build: $*" >&2; exit 1; }

for tool in gh nfpm apt-ftparchive createrepo_c rpmsign gpg; do
    command -v "$tool" >/dev/null || die "missing $tool"
done
gpg --list-secret-keys "$key" >/dev/null 2>&1 || die "no secret key $key in the keyring"

rm -rf "$out"
site=$out/site
mkdir -p "$out/src" "$site/deb/pool/main" "$site/deb/dists/stable/main/binary-amd64" "$site/rpm"

for repo; do
    src=$out/src/${repo#*/}
    info=$(gh release view --repo "$repo" --json tagName,publishedAt --jq '.tagName + " " + .publishedAt')
    tag=${info% *}
    gh release download "$tag" --repo "$repo" --dir "$src" --pattern '*-linux-amd64-musl' --pattern SHA256SUMS
    for bin in "$src"/*-linux-amd64-musl; do
        grep -q "  $(basename "$bin")\$" "$src/SHA256SUMS" || die "$repo $tag: $(basename "$bin") is not in SHA256SUMS"
    done
    (cd "$src" && sha256sum --quiet --check --ignore-missing SHA256SUMS) || die "$repo $tag: checksum mismatch"
    echo "${tag#v} $(date -d "${info#* }" +%s)" > "$src/release"
done

for dir in packages/*/; do
    name=$(basename "$dir")
    bin=$(ls "$out"/src/*/"$name-linux-amd64-musl" 2>/dev/null) || die "no $name-linux-amd64-musl in the releases of $*"
    read -r version epoch < "$(dirname "$bin")/release"
    stage=$out/stage/$name
    mkdir -p "$stage"
    cp -R "$dir". "$stage/"
    cp "$bin" "$stage/$name"
    (
        cd "$stage"
        export VERSION="$version" SOURCE_DATE_EPOCH="$epoch"
        nfpm package -p deb -t "$site/deb/pool/main/" >/dev/null
        nfpm package -p rpm -t "$site/rpm/" >/dev/null
    )
    echo "built $name $version"
done

(
    cd "$site/deb"
    apt-ftparchive packages pool > dists/stable/main/binary-amd64/Packages
    gzip -9nkf dists/stable/main/binary-amd64/Packages
    # Outside the suite, or Release would list itself.
    apt-ftparchive \
        -o APT::FTPArchive::Release::Origin=optionfactory \
        -o APT::FTPArchive::Release::Label=optionfactory \
        -o APT::FTPArchive::Release::Suite=stable \
        -o APT::FTPArchive::Release::Codename=stable \
        -o APT::FTPArchive::Release::Architectures=amd64 \
        -o APT::FTPArchive::Release::Components=main \
        release dists/stable > "$out/Release"
)
suite=$site/deb/dists/stable
mv "$out/Release" "$suite/Release"
gpg -q --yes --local-user "$key" --clearsign -o "$suite/InRelease" "$suite/Release"
gpg -q --yes --local-user "$key" --armor --detach-sign -o "$suite/Release.gpg" "$suite/Release"

for rpm in "$site"/rpm/*.rpm; do
    rpmsign --addsign --define "_gpg_name $key" --define "__gpg $(command -v gpg)" "$rpm" >/dev/null
done
createrepo_c -q "$site/rpm"
gpg -q --yes --local-user "$key" --armor --detach-sign -o "$site/rpm/repodata/repomd.xml.asc" "$site/rpm/repodata/repomd.xml"

gpg --armor --export "$key" > "$site/key.asc"
cat > "$site/optionfactory.repo" <<EOF
[optionfactory]
name=optionfactory
baseurl=$base_url/rpm
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=$base_url/key.asc
EOF
cat > "$site/index.html" <<'EOF'
<!doctype html>
<meta http-equiv="refresh" content="0; url=https://github.com/optionfactory/linux-packages#setup">
<title>optionfactory packages</title>
<a href="https://github.com/optionfactory/linux-packages#setup">Setup instructions</a>
EOF
touch "$site/.nojekyll"
