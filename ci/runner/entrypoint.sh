#!/usr/bin/env bash
# Entrypoint of the autoware-localrepo runner container. Started by
# ci/runner/runner.sh; see ci/runner/README.md.
#
# Checks that this container can actually do a build BEFORE it becomes visible
# on GitHub. A runner that registers and then cannot reach Docker, or whose
# directory the host daemon sees under another path, wins a job and fails it
# hours later inside colcon2deb. Better absent than broken: such a container
# waits, then exits 78 (EX_CONFIG). Docker's restart policy starts it again,
# so a transient cause (the daemon still starting after a reboot, a full disk
# being cleaned) clears by itself, at most once per retry interval.
set -euo pipefail

: "${LOCALREPO_RUNNER_ROOT:?LOCALREPO_RUNNER_ROOT is required}"
: "${LOCALREPO_RUNNER_IMAGE:?LOCALREPO_RUNNER_IMAGE is required}"
: "${GH_REPO:?GH_REPO is required, e.g. NEWSLabNTU/autoware-localrepo}"
: "${RUNNER_LABELS:?RUNNER_LABELS is required}"

ROOT="$LOCALREPO_RUNNER_ROOT"
CONFIG="$ROOT/runner-config"
INSTALL=/opt/actions-runner

fail() {
    echo "entrypoint: $*" >&2
    echo "entrypoint: not registering; retrying in ${LOCALREPO_RUNNER_RETRY_SECONDS:-900} s" >&2
    sleep "${LOCALREPO_RUNNER_RETRY_SECONDS:-900}"
    exit 78
}

{ [ -d "$ROOT" ] && [ -w "$ROOT" ]; } || fail "$ROOT is not a writable directory (is it mounted?)"
docker info >/dev/null 2>&1 || fail "cannot reach the Docker daemon at /var/run/docker.sock"

# colcon2deb passes paths under $ROOT to `docker run -v`. The host daemon
# resolves them on the HOST, so $ROOT must be the same directory on both sides.
probe="$ROOT/.path-probe-$$"
echo "$HOSTNAME" > "$probe"
if ! seen=$(docker run --rm --entrypoint cat -v "$ROOT:$ROOT:ro" "$LOCALREPO_RUNNER_IMAGE" "$probe" 2>/dev/null) \
        || [ "$seen" != "$HOSTNAME" ]; then
    rm -f "$probe"
    fail "the Docker host does not see $ROOT as this container does; mount it at the same path"
fi
rm -f "$probe"

free_gb=$(df -P -BG "$ROOT" | awk 'NR == 2 { sub("G", "", $4); print $4 }')
if [ "$free_gb" -lt "${LOCALREPO_RUNNER_MIN_FREE_GB:-100}" ]; then
    fail "only ${free_gb} GB free under $ROOT; a build needs about 100 GB"
fi

# The registration lives in $ROOT, not in the container's writable layer, so a
# rebuilt image keeps it and needs no new token.
mkdir -p "$CONFIG" "$ROOT/_work"
cd "$INSTALL"
if [ -f "$CONFIG/.runner" ]; then
    cp -a "$CONFIG/.runner" "$CONFIG/.credentials" "$CONFIG/.credentials_rsaparams" "$INSTALL/"
else
    [ -n "${RUNNER_TOKEN:-}" ] || fail "not registered yet and RUNNER_TOKEN is unset; run ci/runner/runner.sh register"
    ./config.sh \
        --url "https://github.com/${GH_REPO}" \
        --token "$RUNNER_TOKEN" \
        --name "${RUNNER_NAME:-$(hostname)}" \
        --labels "$RUNNER_LABELS" \
        --work "$ROOT/_work" \
        --unattended --replace
    cp -a .runner .credentials .credentials_rsaparams "$CONFIG/"
    chmod 600 "$CONFIG/.credentials" "$CONFIG/.credentials_rsaparams"
fi
unset RUNNER_TOKEN

# Jobs inherit this environment from run.sh.
export PATH="$HOME/.local/bin:$PATH"
exec ./run.sh
