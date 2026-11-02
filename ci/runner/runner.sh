#!/usr/bin/env bash
# Build, register and run the autoware-localrepo self-hosted runner container.
#
#   ci/runner/runner.sh build        build the runner image for this machine
#   ci/runner/runner.sh register     register with GitHub and start (once per host)
#   ci/runner/runner.sh run          (re)start the container; no token needed
#   ci/runner/runner.sh stop         stop and remove the container
#   ci/runner/runner.sh status       container state and GitHub's view of it
#   ci/runner/runner.sh logs         follow the container log
#   ci/runner/runner.sh unregister   remove the registration from GitHub
#
# Environment (defaults in brackets):
#   LOCALREPO_RUNNER_ROOT   host directory for builds and registration
#                           [$HOME/autoware-localrepo-runner]
#   RUNNER_LABELS           [by architecture: x86_64 builds amd64, aarch64
#                           builds arm64 and jp62]
#   RUNNER_NAME             [<hostname>-localrepo]
#   GH_REPO                 [NEWSLabNTU/autoware-localrepo]
#
# register and unregister mint short-lived tokens with `gh api`, so they need a
# gh login with admin rights on GH_REPO. Nothing else does. See README.md.
set -euo pipefail

HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT="${LOCALREPO_RUNNER_ROOT:-$HOME/autoware-localrepo-runner}"
GH_REPO="${GH_REPO:-NEWSLabNTU/autoware-localrepo}"
IMAGE="${LOCALREPO_RUNNER_IMAGE:-autoware-localrepo-runner:latest}"
CONTAINER="${LOCALREPO_RUNNER_CONTAINER:-autoware-localrepo-runner}"
RUNNER_NAME="${RUNNER_NAME:-$(hostname)-localrepo}"
SOCK=/var/run/docker.sock

case "$(uname -m)" in
    x86_64)  default_labels="autoware-localrepo,localrepo-amd64" ;;
    aarch64) default_labels="autoware-localrepo,localrepo-arm64,localrepo-jp62" ;;
    *) echo "runner.sh: unsupported architecture $(uname -m)" >&2; exit 1 ;;
esac
RUNNER_LABELS="${RUNNER_LABELS:-$default_labels}"

case "$ROOT" in
    /*) ;;
    *) echo "runner.sh: LOCALREPO_RUNNER_ROOT must be absolute: $ROOT" >&2; exit 1 ;;
esac

token() {  # $1 = registration-token | remove-token
    gh api -X POST "repos/$GH_REPO/actions/runners/$1" --jq .token
}

start() {  # [token]
    mkdir -p "$ROOT"
    docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
    local extra=()
    [ -n "${1:-}" ] && extra=(-e "RUNNER_TOKEN=$1")
    # What each flag is for:
    #   docker.sock      colcon2deb and `just test` start containers on the
    #                    host daemon. This is root-equivalent on the host:
    #                    whoever can push a workflow to GH_REPO can use it.
    #                    The workflow therefore never runs on pull_request.
    #   $ROOT:$ROOT      same path on both sides; colcon2deb's bind mounts
    #                    are resolved by the host daemon
    #   TMPDIR           temporary files under $ROOT too, for the same reason
    #   --group-add      the socket's group, whatever its GID is on this host
    #   --cap-drop ALL   nothing in a build needs a capability in THIS
    #                    container; the builder containers are separate
    docker run -d --name "$CONTAINER" \
        --restart unless-stopped \
        --cap-drop ALL \
        --security-opt no-new-privileges \
        --pids-limit 8192 \
        --group-add "$(stat -c %g "$SOCK")" \
        -v "$SOCK:$SOCK" \
        -v "$ROOT:$ROOT" \
        -e LOCALREPO_RUNNER_ROOT="$ROOT" \
        -e LOCALREPO_RUNNER_IMAGE="$IMAGE" \
        -e TMPDIR="$ROOT/tmp" \
        -e GH_REPO="$GH_REPO" \
        -e RUNNER_LABELS="$RUNNER_LABELS" \
        -e RUNNER_NAME="$RUNNER_NAME" \
        "${extra[@]}" \
        "$IMAGE" >/dev/null
    mkdir -p "$ROOT/tmp"
}

cmd="${1:-}"
case "$cmd" in
    build)
        docker build \
            --build-arg RUNNER_UID="$(id -u)" \
            --build-arg RUNNER_GID="$(id -g)" \
            -t "$IMAGE" "$HERE"
        ;;
    register)
        if [ -f "$ROOT/runner-config/.runner" ]; then
            echo "runner.sh: already registered ($ROOT/runner-config); use run, or unregister first" >&2
            exit 1
        fi
        echo "Registering $RUNNER_NAME on $GH_REPO with labels $RUNNER_LABELS"
        start "$(token registration-token)"
        for _ in $(seq 120); do
            [ -f "$ROOT/runner-config/.runner" ] && break
            if [ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null)" != true ]; then
                break
            fi
            sleep 1
        done
        if [ ! -f "$ROOT/runner-config/.runner" ]; then
            echo "runner.sh: registration did not complete; container log:" >&2
            docker logs --tail 40 "$CONTAINER" >&2 || true
            exit 1
        fi
        # Recreate without the token, so `docker inspect` never shows it.
        start
        echo "Registered and running. Check: $0 status"
        ;;
    run)
        if [ ! -f "$ROOT/runner-config/.runner" ]; then
            echo "runner.sh: not registered yet; run: $0 register" >&2
            exit 1
        fi
        start
        echo "Started $CONTAINER. Logs: $0 logs"
        ;;
    stop)
        docker rm -f "$CONTAINER"
        ;;
    status)
        docker ps -a --filter "name=^${CONTAINER}$" --format '{{.Names}}  {{.Status}}  {{.Image}}'
        gh api "repos/$GH_REPO/actions/runners" \
            --jq '.runners[] | "\(.name)  \(.status)  busy=\(.busy)  \([.labels[].name] | join(","))"'
        ;;
    logs)
        docker logs -f "$CONTAINER"
        ;;
    unregister)
        docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
        if [ -f "$ROOT/runner-config/.runner" ]; then
            docker run --rm --entrypoint bash \
                -v "$ROOT/runner-config:/config:ro" \
                -e RUNNER_TOKEN="$(token remove-token)" \
                "$IMAGE" -c 'cp -a /config/.runner /config/.credentials /config/.credentials_rsaparams . && ./config.sh remove --token "$RUNNER_TOKEN"'
            rm -rf "$ROOT/runner-config"
        fi
        echo "Unregistered. Build trees under $ROOT/_work are kept."
        ;;
    *)
        sed -n '2,21p' "$0" | sed 's/^# \{0,1\}//'
        exit 2
        ;;
esac
