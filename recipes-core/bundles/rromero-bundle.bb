SUMMARY = "Signed RAUC bundle that updates the rootfs slot (A/B) with rromero-image"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

inherit bundle

# must match [system] compatible in recipes-core/rauc/files/system.conf
RAUC_BUNDLE_COMPATIBLE = "rromero-qemux86-64"
RAUC_BUNDLE_VERSION = "${DISTRO_VERSION}"
RAUC_BUNDLE_DESCRIPTION = "rromero-image rootfs update"
# dm-verity bundle: the payload is authenticated block by block while it is installed
RAUC_BUNDLE_FORMAT = "verity"

RAUC_BUNDLE_SLOTS = "rootfs"
RAUC_SLOT_rootfs = "rromero-image"
RAUC_SLOT_rootfs[fstype] = "ext4"
RAUC_SLOT_rootfs[adaptive] = "block-hash-index"

# RAUC_KEY_FILE / RAUC_CERT_FILE / RAUC_KEYRING_FILE come from the build's site.conf,
# written by scripts/create-dev-keys.sh. Production keys never live in the layer.
