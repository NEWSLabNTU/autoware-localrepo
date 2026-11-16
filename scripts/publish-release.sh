#!/usr/bin/env bash
# Attach locally built release files to DRAFT GitHub releases.
#
#   scripts/publish-release.sh [--dry-run] [--replace] [--add-platform] TAG DIR...
#
#   TAG    localrepo release tag, <version>-<distro>-<revision>, e.g.
#          2.1.0-jazzy-1 or 2.1.0-humble-2. The ROS distro is part of every
#          new tag. The older <version>-<revision> form (1.9.0-2, 2.1.0-1)
#          names a Humble release and is accepted only for a release that
#          already exists, draft or published, so its drafts can be refilled
#          and --add-platform still reaches it; no new tag is made in it.
#   DIR    one or more directories of that version and distro whose
#          `just release` has run: <version>/<platform> for Humble
#          (2.1.0/arm64 2.1.0/jp62), <version>-<distro>/<platform> for any
#          other distro (2.1.0-jazzy/amd64 2.1.0-jazzy/jp72)
#
# Each build host runs this for the platforms it built; the x86 machine for
# <version>/amd64, the arm64 server for <version>/arm64 and <version>/jp62.
#
# Two kinds of release, so visitors do not mistake the offline model packages
# for something they need to install Autoware:
#
#   TAG              the autoware-localrepo debs, one per platform.
#                    Notes: release-notes/TAG.md
#   data-<dataver>   the optional autoware-data debs, for offline installs.
#                    The models do not depend on the ROS distro, so Humble
#                    and Jazzy releases of a version share one data release.
#                    <dataver> is their own Debian version (1.9.0-1), which
#                    changes only when the models do, so several localrepo
#                    revisions can share one data release.
#                    Notes: release-notes/data-<dataver>.md
#
# For each, the script:
#
#   1. checks each DIR/packages/release/ against its SHA256SUMS.txt;
#   2. creates the draft release if it does not exist, at the commit HEAD
#      points to (which must already be on origin), with the committed notes;
#      an existing draft gets those notes too;
#   3. uploads the localrepo deb of every DIR. An asset of the same name with
#      different content is refused unless --replace is given;
#   4. uploads the data debs only if no platform has yet. They are
#      architecture-independent and built from the same downloads, so the
#      first host provides them. If the data release is already published
#      with identical debs, it is left alone;
#   5. rewrites each release's SHA256SUMS.txt from the sha256 digests GitHub
#      records for its debs.
#
# --add-platform adds a platform to a localrepo release that is already
# published (e.g. the GPU-free ubuntu2204cpu debs). It uploads only localrepo
# debs the release does not have yet, never replaces one (--replace is refused
# with it), then rewrites SHA256SUMS.txt and the notes from release-notes/TAG.md.
# The data release is handled as before.
#
# It never publishes a release. Check the drafts on GitHub, then publish them
# there or with: gh release edit TAG --draft=false
#
# Needs gh logged in with write access to the repository.
set -euo pipefail

usage() { sed -n '2,57p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }

DRY=0
REPLACE=0
ADD=0
while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY=1; shift ;;
        --replace) REPLACE=1; shift ;;
        --add-platform) ADD=1; shift ;;
        -h|--help) usage ;;
        --*) echo "unknown option: $1" >&2; exit 2 ;;
        *) break ;;
    esac
done
[ $# -ge 2 ] || usage
[ "$ADD" -eq 1 ] && [ "$REPLACE" -eq 1 ] && { echo "error: --add-platform never replaces an asset; drop --replace" >&2; exit 2; }
TAG="$1"; shift

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"
REPO="${GH_REPO:-NEWSLabNTU/autoware-localrepo}"

LEGACY=0
if [[ "$TAG" =~ ^([0-9]+\.[0-9]+\.[0-9]+)-(humble|jazzy)-[0-9]+$ ]]; then
    VERSION="${BASH_REMATCH[1]}"
    DISTRO="${BASH_REMATCH[2]}"
elif [[ "$TAG" =~ ^([0-9]+\.[0-9]+\.[0-9]+)-[0-9]+$ ]]; then
    VERSION="${BASH_REMATCH[1]}"
    DISTRO=humble   # every release tagged before the distro joined the tag
    LEGACY=1
else
    echo "error: tag must look like 2.1.0-jazzy-1 or 2.1.0-humble-1, not $TAG" >&2
    exit 2
fi
# Humble builds live in <version>/, other distros in <version>-<distro>/.
if [ "$DISTRO" = humble ]; then DIRVER="$VERSION"; else DIRVER="$VERSION-$DISTRO"; fi

run() {
    if [ "$DRY" -eq 1 ]; then echo "  would run: $*"; else "$@"; fi
}

# 1. Local files are what `just release` staged.
DIRS=()
for dir in "$@"; do
    dir="${dir%/}"
    [ "${dir%%/*}" = "$DIRVER" ] || { echo "error: $dir is not a $DIRVER directory (tag $TAG is $VERSION for $DISTRO)" >&2; exit 2; }
    rel="$dir/packages/release"
    [ -f "$rel/SHA256SUMS.txt" ] || { echo "error: $rel/SHA256SUMS.txt missing; run 'just release' in $dir" >&2; exit 1; }
    (cd "$rel" && sha256sum --quiet -c SHA256SUMS.txt) || { echo "error: $rel does not match its SHA256SUMS.txt" >&2; exit 1; }
    ls "$rel"/autoware-localrepo-*.deb >/dev/null 2>&1 || { echo "error: no localrepo deb in $rel" >&2; exit 1; }
    DIRS+=("$dir")
done

# The data release's version: every data deb of this Autoware version has the
# same one, e.g. autoware-data-perception3d-1-9-0_1.9.0-1_all.deb -> 1.9.0-1.
DATAVER=$(for dir in "${DIRS[@]}"; do ls "$dir/packages/release/"; done \
    | sed -n -E 's/^autoware-data(-[a-z0-9]+)?-[0-9]+-[0-9]+-[0-9]+_([^_]+)_all\.deb$/\2/p' | sort -u)
[ "$(echo "$DATAVER" | grep -c .)" -le 1 ] || { echo "error: data debs of several versions staged: $DATAVER" >&2; exit 1; }
DTAG=${DATAVER:+data-$DATAVER}

head=$(git rev-parse HEAD)
if ! git branch -r --contains "$head" | grep -q 'origin/'; then
    echo "error: HEAD $head is not on origin; push it first so the release points at a published commit" >&2
    exit 1
fi
for t in "$TAG" $DTAG; do
    notes="release-notes/$t.md"
    [ -f "$notes" ] || { echo "error: $notes missing; write the release notes first" >&2; exit 1; }
    git ls-files --error-unmatch "$notes" >/dev/null 2>&1 && git diff --quiet HEAD -- "$notes" \
        || { echo "error: commit $notes first, so the release notes are on origin with the code" >&2; exit 1; }
done

release_json() {  # $1 = tag. releases/tags/<tag> does not return drafts, so search the list.
    gh api --paginate "repos/$REPO/releases" --jq ".[] | select(.tag_name == \"$1\")"
}

declare -A attached   # asset name -> sha256 of what the current release holds
INFO=""
PUBLISHED=0
ADDING=0   # 1 while filling a published localrepo release under --add-platform

# 2. Find or create the draft; fills INFO, PUBLISHED and attached.
open_release() {  # $1 = tag, $2 = title, $3 = 1 if a published release may be reused, 2 to add platforms to it
    local tag=$1 title=$2 reuse=$3 notes="release-notes/$1.md" name digest
    INFO=$(release_json "$tag")
    PUBLISHED=0
    ADDING=0
    attached=()
    echo "== $tag"
    if [ -z "$INFO" ] && [ "$LEGACY" -eq 1 ] && [ "$tag" = "$TAG" ]; then
        echo "error: no release $tag exists, and a new tag names its distro: use $VERSION-$DISTRO-${TAG##*-}" >&2
        exit 2
    elif [ -z "$INFO" ]; then
        echo "Creating draft release $tag at $head"
        run gh release create "$tag" -R "$REPO" --draft --target "$head" --title "$title" --notes-file "$notes"
        [ "$DRY" -eq 1 ] || INFO=$(release_json "$tag")
    elif [ "$(jq -r .draft <<<"$INFO")" != true ] && [ "$reuse" -eq 2 ]; then
        echo "Release $tag is already published; adding the platforms it lacks"
        PUBLISHED=1
        ADDING=1
    elif [ "$(jq -r .draft <<<"$INFO")" != true ]; then
        [ "$reuse" -eq 1 ] || { echo "error: release $tag is already published; this script only fills drafts" >&2; exit 1; }
        echo "Release $tag is already published; checking that it holds the same files"
        PUBLISHED=1
    else
        echo "Using existing draft release $tag; setting its notes from $notes"
        run gh release edit "$tag" -R "$REPO" --title "$title" --notes-file "$notes"
    fi
    if [ -n "$INFO" ]; then
        while read -r name digest; do
            attached["$name"]="${digest#sha256:}"
        done < <(jq -r '.assets[] | "\(.name) \(.digest // "")"' <<<"$INFO")
    fi
}

# 3 and 4. Upload the debs matching $2 from every DIR.
upload() {  # $1 = tag, $2 = glob, $3 = "replace" for per-platform debs, "first" for shared ones
    local tag=$1 glob=$2 mode=$3 dir rel f name sum have
    for dir in "${DIRS[@]}"; do
        rel="$dir/packages/release"
        for f in "$rel"/$glob; do
            [ -e "$f" ] || continue
            name=$(basename "$f")
            sum=$(grep -F "  $name" "$rel/SHA256SUMS.txt" | cut -d' ' -f1)
            have="${attached[$name]:-}"
            if [ "$have" = "$sum" ]; then
                echo "  $name: already attached"
            elif [ "$ADDING" -eq 1 ] && [ -z "$have" ]; then
                echo "  $name: new platform, uploading ($(du -h "$f" | cut -f1))"
                run gh release upload "$tag" -R "$REPO" "$f"
                attached["$name"]="$sum"
            elif [ "$ADDING" -eq 1 ]; then
                echo "error: published release $tag has $name with different content; it is never replaced" >&2
                exit 1
            elif [ "$PUBLISHED" -eq 1 ]; then
                [ -n "$have" ] && [ "$mode" = first ] && { echo "  $name: published by another platform, kept"; continue; }
                echo "error: published release $tag lacks $name; make a new data revision instead" >&2
                exit 1
            elif [ -n "$have" ] && [ "$mode" = first ]; then
                echo "  $name: already attached by another platform, kept"
            elif [ -n "$have" ] && [ "$REPLACE" -eq 0 ]; then
                echo "error: $name is attached to $tag with different content; rerun with --replace to overwrite it" >&2
                exit 1
            else
                echo "  $name: uploading ($(du -h "$f" | cut -f1))"
                run gh release upload "$tag" -R "$REPO" "$f" --clobber
                attached["$name"]="$sum"
            fi
        done
    done
}

# 5. Checksums for every deb attached.
finish() {  # $1 = tag
    local tag=$1 sums
    [ "$DRY" -eq 1 ] && return 0
    [ "$PUBLISHED" -eq 1 ] && [ "$ADDING" -eq 0 ] && return 0
    sums=$(mktemp -d)
    release_json "$tag" | jq -r '.assets[] | select(.name | endswith(".deb")) | "\(.digest // "" | ltrimstr("sha256:"))  \(.name)"' \
        | sort -k2 > "$sums/SHA256SUMS.txt"
    if grep -qv '^[0-9a-f]\{64\}  ' "$sums/SHA256SUMS.txt"; then
        rm -rf "$sums"
        echo "error: GitHub has no digest for an asset of $tag yet; rerun in a minute" >&2
        exit 1
    fi
    gh release upload "$tag" -R "$REPO" "$sums/SHA256SUMS.txt" --clobber
    echo
    cat "$sums/SHA256SUMS.txt"
    rm -rf "$sums"
    echo
    if [ "$ADDING" -eq 1 ]; then
        gh release edit "$tag" -R "$REPO" --notes-file "release-notes/$tag.md"
        echo "Published: $(gh release view "$tag" -R "$REPO" --json url --jq .url) (notes updated)"
        echo
        return 0
    fi
    echo "Draft: $(gh release view "$tag" -R "$REPO" --json url --jq .url)"
    echo "Review it, then publish on GitHub or with: gh release edit $tag -R $REPO --draft=false"
    echo
}

open_release "$TAG" "Autoware $TAG" $((ADD * 2))
upload "$TAG" 'autoware-localrepo-*.deb' replace
finish "$TAG"

if [ -n "$DTAG" ]; then
    open_release "$DTAG" "Autoware $VERSION ML models $DATAVER (offline)" 1
    upload "$DTAG" 'autoware-data-*.deb' first
    finish "$DTAG"
fi
[ "$DRY" -eq 1 ] && echo "Dry run: nothing uploaded."
exit 0
