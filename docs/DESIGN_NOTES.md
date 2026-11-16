# Design notes

Decisions taken while building this layer, and why.

**Distro, not local.conf.** Everything a product depends on (init system, features, SBOM, licence manifest) is in
`conf/distro/rromero.conf`, so it is versioned and reviewed. `local.conf` (here, the kas `local_conf_header`) only
holds what changes per build host or per developer: machine boot quirks, `rm_work`, disk monitor, test access.

**bbappends scoped to the distro.** `linux-yocto_%.bbappend` and `rauc-conf.bbappend` use the `:rromero` override.
Adding the layer to someone else's build (another distro) changes nothing, which is what the Yocto Project
Compatible signature check (`yocto-check-layer`) verifies in CI.

**Pinned upstream.** kas pins poky, meta-openembedded, meta-rauc and meta-rauc-community to exact commits on the
scarthgap branch. Moving them is a reviewed change, not something that happens on the next build.

**Slot size is a build error, not a field failure.** `IMAGE_ROOTFS_MAXSIZE` matches the 400 MiB root slots in the
`.wks`: an image that would not fit a slot fails at build time instead of during an update.

**Bundles.** `verity` format: RAUC checks the payload block by block with dm-verity while it installs, so a bundle
modified after signing is rejected even on partial reads. `system.conf` sets `bundle-formats=-plain` so old-style
plain bundles are refused. `block-hash-index` adaptive mode lets RAUC copy only changed blocks when the old slot
already has them (the ext4 options in the image keep consecutive builds similar).

**Keys outside the layer.** `scripts/create-dev-keys.sh` writes a development CA and signer into the build
directory and points `site.conf` at them. CI checks that no private key is ever committed. The device only gets the
CA certificate (`rauc-conf` installs it as the keyring).

**Application recipes.**
- `j1939-edge-logger`: `inherit cmake`, tests off (`BUILD_TESTING=OFF`, they run in the project's own CI and
  FetchContent cannot download inside a bitbake task). The upstream CMake got proper `install()` rules for this
  instead of a hand-written `do_install`.
- `edge-voice-notes`: `python_setuptools_build_meta` (PEP 517). `RDEPENDS` lists the exact `python3-*` packages for the
  stdlib modules it imports (mapped with `python3-manifest.json`) instead of pulling in all of `python3-modules`.

**Kernel fragment, not a defconfig copy.** `can.cfg` only adds the SocketCAN options on top of the linux-yocto
configuration, so kernel updates keep working. `do_kernel_configcheck` warns if an option does not end up in the
final `.config`.

**Tests run on the image.** `testimage` boots the `.wic` with OVMF in QEMU and runs the cases over SSH: no failed
systemd units, RAUC sees both slots and the right compatible, a random file is refused as a bundle, the signed bundle from the build installs into the
inactive slot and becomes the boot target, the J1939 replay
decodes the sample trace, `vcan` and `cansend` work, and the voice-notes pipeline completes with its fake engines on
the target's Python.
