#!/usr/bin/env bash
# Attach locally built release files to a DRAFT GitHub release.
#
#   scripts/publish-release.sh [--dry-run] [--replace] TAG DIR...
#
#   TAG    release tag, <version>-<revision>, e.g. 1.9.0-1
#   DIR    one or more <version>/<platform> directories whose `just release`
#          has run, e.g. 1.9.0/arm64 1.9.0/jp62
#
# Each build host runs this for the platforms it built; the x86 machine for
# <version>/amd64, the arm64 server for <version>/arm64 and <version>/jp62.
# The script:
#
#   1. checks each DIR/packages/release/ against its SHA256SUMS.txt;
#   2. creates the draft release if it does not exist, at the commit HEAD
#      points to (which must already be on origin), with the notes in
#      release-notes/TAG.md. An existing draft gets that file's notes too,
#      so the committed file is what the release says;
#   3. uploads the autoware-localrepo deb of every DIR. An asset of the same
#      name with different content is refused unless --replace is given;
#   4. uploads the optional autoware-data debs only if no platform has yet.
#      They are architecture-independent and built from the same downloads,
#      so the first host to publish provides them;
#   5. rewrites SHA256SUMS.txt from the sha256 digests GitHub records for the
#      attached debs, so it covers every platform's uploads so far.
#
# It never publishes the release. Check the draft on GitHub, then publish it
# there or with: gh release edit TAG --draft=false
#
# Needs gh logged in with write access to the repository.
set -euo pipefail

usage() { sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }

DRY=0
REPLACE=0
while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY=1; shift ;;
        --replace) REPLACE=1; shift ;;
        -h|--help) usage ;;
        --*) echo "unknown option: $1" >&2; exit 2 ;;
        *) break ;;
    esac
done
[ $# -ge 2 ] || usage
TAG="$1"; shift

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"
REPO="${GH_REPO:-NEWSLabNTU/autoware-localrepo}"

[[ "$TAG" =~ ^([0-9]+\.[0-9]+\.[0-9]+)-[0-9]+$ ]] || { echo "error: tag must look like 1.9.0-1, not $TAG" >&2; exit 2; }
VERSION="${BASH_REMATCH[1]}"

run() {
    if [ "$DRY" -eq 1 ]; then echo "  would run: $*"; else "$@"; fi
}

# 1. Local files are what `just release` staged.
for dir in "$@"; do
    dir="${dir%/}"
    [ "${dir%%/*}" = "$VERSION" ] || { echo "error: $dir is not a $VERSION directory (tag $TAG)" >&2; exit 2; }
    rel="$dir/packages/release"
    [ -f "$rel/SHA256SUMS.txt" ] || { echo "error: $rel/SHA256SUMS.txt missing; run 'just release' in $dir" >&2; exit 1; }
    (cd "$rel" && sha256sum --quiet -c SHA256SUMS.txt) || { echo "error: $rel does not match its SHA256SUMS.txt" >&2; exit 1; }
    ls "$rel"/autoware-localrepo-*.deb >/dev/null 2>&1 || { echo "error: no localrepo deb in $rel" >&2; exit 1; }
done

# 2. The draft release.
NOTES="release-notes/$TAG.md"
[ -f "$NOTES" ] || { echo "error: $NOTES missing; write the release notes first" >&2; exit 1; }
git ls-files --error-unmatch "$NOTES" >/dev/null 2>&1 && git diff --quiet HEAD -- "$NOTES" \
    || { echo "error: commit $NOTES first, so the release notes are on origin with the code" >&2; exit 1; }
head=$(git rev-parse HEAD)
if ! git branch -r --contains "$head" | grep -q 'origin/'; then
    echo "error: HEAD $head is not on origin; push it first so the release points at a published commit" >&2
    exit 1
fi
release_json() {
    # releases/tags/<tag> does not return drafts, so search the list.
    gh api --paginate "repos/$REPO/releases" --jq ".[] | select(.tag_name == \"$TAG\")"
}
info=$(release_json)
if [ -z "$info" ]; then
    echo "Creating draft release $TAG at $head"
    run gh release create "$TAG" -R "$REPO" --draft --target "$head" --title "Autoware $TAG" \
        --notes-file "$NOTES"
    [ "$DRY" -eq 1 ] || info=$(release_json)
elif [ "$(jq -r .draft <<<"$info")" != true ]; then
    echo "error: release $TAG is already published; this script only fills drafts" >&2
    exit 1
else
    echo "Using existing draft release $TAG; setting its notes from $NOTES"
    run gh release edit "$TAG" -R "$REPO" --notes-file "$NOTES"
fi

# name -> sha256 of what is attached now
declare -A attached
if [ -n "$info" ]; then
    while read -r name digest; do
        attached["$name"]="${digest#sha256:}"
    done < <(jq -r '.assets[] | "\(.name) \(.digest // "")"' <<<"$info")
fi

# 3 and 4. Upload.
for dir in "$@"; do
    rel="${dir%/}/packages/release"
    for f in "$rel"/*.deb; do
        name=$(basename "$f")
        sum=$(grep -F "  $name" "$rel/SHA256SUMS.txt" | cut -d' ' -f1)
        have="${attached[$name]:-}"
        case "$name" in
            autoware-localrepo-*)
                if [ "$have" = "$sum" ]; then
                    echo "  $name: already attached"
                elif [ -n "$have" ] && [ "$REPLACE" -eq 0 ]; then
                    echo "error: $name is attached with different content; rerun with --replace to overwrite it" >&2
                    exit 1
                else
                    echo "  $name: uploading ($(du -h "$f" | cut -f1))"
                    run gh release upload "$TAG" -R "$REPO" "$f" --clobber
                    attached["$name"]="$sum"
                fi ;;
            *)
                if [ -n "$have" ]; then
                    echo "  $name: already attached by another platform, kept"
                else
                    echo "  $name: uploading ($(du -h "$f" | cut -f1))"
                    run gh release upload "$TAG" -R "$REPO" "$f"
                    attached["$name"]="$sum"
                fi ;;
        esac
    done
done

# 5. Checksums for everything attached.
[ "$DRY" -eq 1 ] && { echo "Dry run: nothing uploaded."; exit 0; }
sums=$(mktemp -d)
trap 'rm -rf "$sums"' EXIT
release_json | jq -r '.assets[] | select(.name | endswith(".deb")) | "\(.digest // "" | ltrimstr("sha256:"))  \(.name)"' \
    | sort -k2 > "$sums/SHA256SUMS.txt"
if grep -qv '^[0-9a-f]\{64\}  ' "$sums/SHA256SUMS.txt"; then
    echo "error: GitHub has no digest for an asset yet; rerun in a minute" >&2
    exit 1
fi
gh release upload "$TAG" -R "$REPO" "$sums/SHA256SUMS.txt" --clobber
echo
cat "$sums/SHA256SUMS.txt"
echo
echo "Draft: $(gh release view "$TAG" -R "$REPO" --json url --jq .url)"
echo "Review it, then publish on GitHub or with: gh release edit $TAG -R $REPO --draft=false"
