SUMMARY = "Reference image: RAUC A/B updates, J1939 logger and offline voice-notes pipeline"
LICENSE = "MIT"

inherit core-image

IMAGE_FEATURES += "ssh-server-dropbear"

IMAGE_INSTALL = "\
    packagegroup-core-boot \
    kernel-image kernel-modules \
    rauc \
    iproute2 can-utils \
    j1939-edge-logger \
    edge-voice-notes \
    ${CORE_IMAGE_EXTRA_INSTALL} \
"

# Disk layout and the RAUC-friendly ext4 options follow meta-rauc-qemux86
# (core-image-minimal.bbappend there), with bigger root slots for Python.
IMAGE_FSTYPES += "wic ext4 tar.bz2"
WKS_FILE = "rromero-qemux86-64.wks"
do_image_wic[depends] += "boot-image:do_deploy"
IMAGE_ROOTFS_ALIGNMENT = "4"
EXTRA_IMAGECMD:ext4 = "-i 4096 -b 4096 -E hash_seed=86ca73ff-7379-40bd-a098-fcb03a6e719d"

# fail the build if the root filesystem would not fit a slot (400 MiB, see the .wks)
IMAGE_ROOTFS_MAXSIZE = "409600"

# runtime tests: bitbake rromero-image -c testimage
TEST_SUITES = "ping ssh rromero"
