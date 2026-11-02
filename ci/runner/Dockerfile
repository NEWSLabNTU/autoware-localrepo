# Self-hosted GitHub Actions runner for building autoware-localrepo.
#
# One image, two architectures: built natively on the x86 host (amd64
# builds) and on the arm64 server (arm64 SBSA and Jetson jp62 builds).
# ci/runner/runner.sh builds and starts it; see ci/runner/README.md.
#
# The image carries the tools the build recipes call and nothing else. The
# Autoware source, colcon2deb, the build trees and the runner registration all
# live in a host directory mounted at the SAME path inside the container,
# because colcon2deb starts its builder containers through the host's Docker
# daemon and hands it bind-mount paths that the daemon resolves on the host.
FROM ubuntu:22.04

ARG TARGETARCH
# Pinned for reproducibility; bump deliberately. GitHub refuses to register
# runners older than a moving minimum, so expect to bump RUNNER_VERSION when a
# fresh registration fails.
ARG RUNNER_VERSION=2.338.2
ARG JUST_VERSION=1.58.0
# The runner runs as the host user who owns the runner directory, so files the
# builds leave there (and those colcon2deb's builder writes with --uid) stay
# owned by that user.
ARG RUNNER_UID=1000
ARG RUNNER_GID=1000

ENV DEBIAN_FRONTEND=noninteractive

# Build tools the justfiles call: dpkg-buildpackage and its Build-Depends
# (debhelper, aria2, cmake, git, build-essential, unzip), dpkg-scanpackages,
# GNU parallel, aria2c, rsync, and python3 with PyYAML for genpkg.py.
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl gnupg git git-lfs jq sudo \
        python3 python3-pip python3-venv python3-yaml \
        build-essential cmake debhelper devscripts dpkg-dev fakeroot \
        aria2 parallel rsync unzip xz-utils zstd file \
    && rm -rf /var/lib/apt/lists/*

# Docker CLI and buildx only. The daemon is the host's, reached through the
# mounted socket; there is no Docker daemon in this image.
RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc \
    && echo "deb [arch=${TARGETARCH} signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu jammy stable" \
        > /etc/apt/sources.list.d/docker.list \
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /etc/apt/keyrings/githubcli.gpg \
    && echo "deb [arch=${TARGETARCH} signed-by=/etc/apt/keyrings/githubcli.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y --no-install-recommends \
        docker-ce-cli docker-buildx-plugin gh \
    && rm -rf /var/lib/apt/lists/*

# vcstool imports the Autoware repos into source/src.
RUN pip3 install --no-cache-dir vcstool

RUN case "${TARGETARCH}" in \
        amd64) just_arch=x86_64 ;; arm64) just_arch=aarch64 ;; \
        *) echo "unsupported TARGETARCH ${TARGETARCH}" >&2; exit 1 ;; esac \
    && curl -fsSL "https://github.com/casey/just/releases/download/${JUST_VERSION}/just-${JUST_VERSION}-${just_arch}-unknown-linux-musl.tar.gz" \
        | tar -xz -C /usr/local/bin just

RUN groupadd -g "${RUNNER_GID}" runner \
    && useradd -m -u "${RUNNER_UID}" -g "${RUNNER_GID}" -s /bin/bash runner

WORKDIR /opt/actions-runner
RUN case "${TARGETARCH}" in \
        amd64) runner_arch=x64 ;; arm64) runner_arch=arm64 ;; esac \
    && curl -fsSL "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-${runner_arch}-${RUNNER_VERSION}.tar.gz" \
        | tar -xz \
    && ./bin/installdependencies.sh \
    && rm -rf /var/lib/apt/lists/* \
    && chown -R runner:runner /opt/actions-runner

COPY --chmod=0755 entrypoint.sh /usr/local/bin/entrypoint.sh
USER runner
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
