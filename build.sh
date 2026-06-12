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

# RT=1 ./build.sh ...  -> PREEMPT_RT kernel (mainline RT, extra fragment).
# Switching RT on/off needs: RT=1 ./build.sh linux-dirclean all
# EDGE=1 ./build.sh ... -> mainline 7.0.y kernel (Armbian edge config base).
# Default is the 6.18 longterm series.
KVER="${KVER:-6.18.35}"
KPATCHES=/work/board/luckfox/nova/patches/linux
KCONF=/work/board/luckfox/nova/linux.config
if [ "${EDGE:-0}" = 1 ]; then
    KVER="${KVER_EDGE:-7.0.12}"
    KPATCHES=/work/board/luckfox/nova/patches/linux-edge
    KCONF=/work/board/luckfox/nova/linux-edge.config
    echo "[INFO] edge kernel build enabled ($KVER)"
fi

KCFG_FRAGS="/work/board/luckfox/nova/linux.fragment"
if [ "${RT:-0}" = 1 ]; then
    KCFG_FRAGS="$KCFG_FRAGS /work/board/luckfox/nova/linux-rt.fragment"
    echo "[INFO] PREEMPT_RT kernel build enabled"
fi
# DBG=1 -> debugobjects kernel: reports use-after-free timers with the
# function that armed them (for the boot-time timer panic hunt)
if [ "${DBG:-0}" = 1 ]; then
    KCFG_FRAGS="$KCFG_FRAGS /work/board/luckfox/nova/linux-debug.fragment"
    echo "[INFO] debugobjects kernel build enabled"
fi

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

# Force a clean kernel rebuild whenever the kernel flavor changes (version,
# patches, config or fragments): incremental builds across config swaps have
# produced subtly corrupted kernels (bogus timer callbacks at boot).
SIG="$KVER $KPATCHES $KCONF $KCFG_FRAGS"
STAMP=buildroot/output/.nova-kernel-sig
if [ -d buildroot/output/build ] && [ "$(cat "$STAMP" 2>/dev/null)" != "$SIG" ]; then
    echo "[INFO] kernel flavor changed -> linux-dirclean"
    "${DOCKER_RUN[@]}" make BR2_EXTERNAL=/work linux-dirclean || true
fi
mkdir -p buildroot/output
printf '%s' "$SIG" > "$STAMP"

exec "${DOCKER_RUN[@]}" make BR2_EXTERNAL=/work BR2_JLEVEL="$JOBS" \
    BR2_LINUX_KERNEL_CUSTOM_VERSION_VALUE="$KVER" \
    BR2_LINUX_KERNEL_PATCH="$KPATCHES" \
    BR2_LINUX_KERNEL_CUSTOM_CONFIG_FILE="$KCONF" \
    BR2_LINUX_KERNEL_CONFIG_FRAGMENT_FILES="$KCFG_FRAGS" "$@"
