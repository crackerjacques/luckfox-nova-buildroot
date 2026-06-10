#!/bin/bash
# Build wrapper: runs buildroot inside a Debian container (host distro
# agnostic - Arch's bleeding-edge toolchain regularly breaks buildroot's
# host packages).
#
#   ./build.sh              -> full build
#   ./build.sh menuconfig   -> buildroot menuconfig
#   ./build.sh linux-rebuild uboot-rebuild all   -> any make targets
#   ./build.sh shell        -> shell in the build container
#
# buildroot itself is cloned into ./buildroot (gitignored); downloads are
# cached in ./buildroot/dl across builds.

set -e
cd "$(dirname "$0")"

BR_BRANCH=2025.02.x
IMAGE=luckfox-nova-br

# Parallelism: JOBS=N ./build.sh   (this host throws GCC ICEs at full -j;
# 24 is the proven-safe default, see the RG DS builds)
JOBS="${JOBS:-24}"

if [ ! -d buildroot ]; then
    echo "[INFO] cloning buildroot ($BR_BRANCH) ..."
    git clone --branch "$BR_BRANCH" https://gitlab.com/buildroot.org/buildroot.git buildroot
fi

# Cheap when cached; picks up Dockerfile changes automatically.
docker build -q -t "$IMAGE" docker/ >/dev/null

DOCKER_RUN=(docker run --rm -it \
    --user "$(id -u):$(id -g)" \
    -e HOME=/work \
    -v "$PWD:/work" \
    -w /work/buildroot \
    "$IMAGE")

if [ "${1:-}" = "shell" ]; then
    exec "${DOCKER_RUN[@]}" /bin/bash
fi

# First run: generate .config from the defconfig
if [ ! -f buildroot/.config ]; then
    "${DOCKER_RUN[@]}" make BR2_EXTERNAL=/work luckfox_nova_defconfig
fi

exec "${DOCKER_RUN[@]}" make BR2_EXTERNAL=/work BR2_JLEVEL="$JOBS" "$@"
