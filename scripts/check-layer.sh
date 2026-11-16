#!/bin/bash
# Run yocto-check-layer on this layer and accept exactly one known false positive.
#
# meta-rauc-qemux86 (a dependency) adds "wic" to core-image-minimal, and poky's WICVARS puts BBLAYERS in the
# signature of do_rootfs_wicenv. Adding *any* layer on top therefore changes that task's signature (and the tasks
# after it). The check passes only if test_signatures is the only failure and every root-cause difference it lists
# is do_rootfs_wicenv with "Variable BBLAYERS value changed". Anything else fails.
#
# Usage, inside `kas shell`: scripts/check-layer.sh <work-dir> <layer-dir>
set -eu

W=$1
LAYER=$2
M="$W/meta-openembedded"
LOG="$W/check-layer.log"

rm -rf "$W/ycl-build" "$LOG"
cd "$W"
set +u  # oe-init-build-env reads unset variables
# shellcheck disable=SC1091
. poky/oe-init-build-env "$W/ycl-build" >/dev/null
set -u

# meta-filesystems (and what it needs) only because meta-rauc's casync wants fuse for `bitbake world`
rc=0
yocto-check-layer --no-auto-dependency -o "$LOG" \
    --dependency "$M/meta-oe" "$M/meta-python" "$M/meta-networking" "$M/meta-filesystems" \
        "$W/meta-rauc" "$W/meta-rauc-community/meta-rauc-qemux86" \
    --additional-layers "$M/meta-python" "$M/meta-networking" "$M/meta-filesystems" \
    -- "$LAYER" || rc=$?

[ "$rc" -eq 0 ] && exit 0

fails=$(grep -oE '^INFO: FAIL: [a-z_]+' "$LOG" | sort -u | sed 's/INFO: FAIL: //')
roots=$(grep -E '^ +[^ ]+:do_[^ ]+: [0-9a-f]{64} -> [0-9a-f]{64}' "$LOG" | awk '{print $1}' | sort -u)
if [ "$fails" = "test_signatures" ] && [ "$roots" = "core-image-minimal:do_rootfs_wicenv:" ] \
   && grep -q 'Variable BBLAYERS value changed' "$LOG" && ! grep -qE '^INFO: ERROR: ' "$LOG"; then
    echo "check-layer: only the known BBLAYERS/do_rootfs_wicenv signature change (see scripts/check-layer.sh)"
    exit 0
fi
echo "check-layer failed: $fails" >&2
echo "root-cause signature changes: $roots" >&2
exit 1
