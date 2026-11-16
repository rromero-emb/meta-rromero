# meta-rromero

A Yocto Project layer (scarthgap 5.0 LTS) for a small field device. It provides:

- **its own distro** (`rromero`): systemd, hardening flags, a SPDX SBOM per image, licence manifest, no graphics or
  radios we do not use;
- **A/B updates with RAUC**: GRUB on EFI, two root slots plus rescue and data partitions, dm-verity bundles signed by a
  development CA, unsigned or plain bundles refused;
- **recipes for two of my own projects**: [j1939-edge-logger](https://github.com/rromero-emb/j1939-edge-logger) (CMake,
  C++20) and [edge-voice-notes](https://github.com/rromero-emb/edge-voice-notes) (Python, stdlib only);
- **a kernel config fragment** for SocketCAN (`vcan`, `can-raw`, `can-j1939`);
- **runtime tests** (`testimage`) that boot the image in QEMU and check RAUC, the CAN stack and both applications.

The point of the layer is the integration work around a product image: pinned upstream layers, a reproducible `kas`
build, bbappends scoped to the distro so the layer does not change other builds, update signing kept out of the layer,
and tests that run on the booted image instead of on the build host.

## What I reused, and what is mine

| Part | Source |
|---|---|
| GRUB/EFI boot image, partition layout, RAUC slot types | [meta-rauc-community/meta-rauc-qemux86](https://github.com/rauc/meta-rauc-community) (MIT), used as a dependency layer; the `.wks` is a copy with bigger root slots |
| RAUC bundle class, `rauc` recipe | [meta-rauc](https://github.com/rauc/meta-rauc) (MIT) |
| Distro, image, bundle, `system.conf`, kernel fragment, application recipes, runtime tests, key script, kas files, CI | this layer |

## Layout

```
conf/distro/rromero.conf                 distro: systemd, SBOM, licence manifest, trimmed DISTRO_FEATURES
recipes-core/images/rromero-image.bb     image: RAUC, CAN tools, both applications, size limit per slot
recipes-core/bundles/rromero-bundle.bb   signed dm-verity RAUC bundle (rootfs slot, adaptive updates)
recipes-core/rauc/                       system.conf: compatible string, slots, bundle-formats=-plain
recipes-kernel/linux/                    SocketCAN fragment (distro-scoped bbappend)
recipes-apps/                            j1939-edge-logger (cmake), edge-voice-notes (python_setuptools_build_meta)
wic/rromero-qemux86-64.wks               boot | grubenv | rescue | root A | root B | data
lib/oeqa/runtime/cases/rromero.py        testimage cases
scripts/create-dev-keys.sh               development CA + signer, writes site.conf (keys never in the layer)
kas/rromero-qemux86-64.yml               pinned layers, machine, targets
kas/dev.yml                              development overlay (root login for testimage)
```

## Build

Host: Debian 12 or Ubuntu 22.04/24.04 with the
[Yocto host packages](https://docs.yoctoproject.org/5.0/ref-manual/system-requirements.html), ~80 GB free disk.

```sh
pip install kas==5.5
git clone https://github.com/rromero-emb/meta-rromero && cd meta-rromero
export KAS_WORK_DIR=$HOME/yocto/work DL_DIR=$HOME/yocto/downloads SSTATE_DIR=$HOME/yocto/sstate
scripts/create-dev-keys.sh $KAS_WORK_DIR/build      # development signing keys + site.conf
kas build kas/dev.yml                                # rromero-image + rromero-bundle
kas shell kas/dev.yml -c "bitbake rromero-image -c testimage"
kas shell kas/dev.yml -c "runqemu rromero-image wic ovmf nographic slirp"
```

Outputs in `$KAS_WORK_DIR/build/tmp/deploy/images/qemux86-64/`: the `.wic` disk image, the `.raucb` bundle and the
SPDX SBOM (`rromero-image-qemux86-64.spdx.tar.zst`).

## Results

Measured on a laptop (Intel i7-1355U, 12 threads, 16 GB RAM, NVMe), scarthgap at the commits pinned in `kas/`:

| | |
|---|---|
| First build, empty sstate and downloads (5159 tasks) | 1 h 59 min |
| Disk used: downloads / sstate / build dir (`rm_work` on) | 8.9 GB / 4.3 GB / 16 GB |
| Root filesystem (ext4), slot size 400 MiB | 258 MiB |
| `.wic` disk image (sparse) | 1.4 GB |
| Signed dm-verity bundle (`.raucb`) | 65 MiB |
| SPDX SBOM archive | 1.8 MB |
| Packages in the image manifest | 688 |
| Kernel | linux-yocto 6.6 |

`bitbake rromero-image -c testimage` (QEMU + KVM, OVMF, boots the `.wic`), 9/9 passed in 10 s:

| Test | Checks |
|---|---|
| `ping`, `ssh` | target up (poky's own cases) |
| `test_no_failed_units` | `systemctl --failed` is empty |
| `test_rauc_status` | RAUC sees `rootfs.0`/`rootfs.1` and compatible `rromero-qemux86-64` |
| `test_rauc_rejects_unsigned_bundle` | random data given as a bundle is refused |
| `test_rauc_install_bundle` | the signed bundle from this build installs into the inactive slot, which becomes the next boot target |
| `test_j1939_replay` | `j1939log` replays the sample truck trace and decodes the VIN |
| `test_vcan_available` | `vcan0` comes up and `cansend` works (kernel fragment applied) |
| `test_voice_notes_fake_pipeline` | edge-voice-notes runs end to end with fake engines on the target Python |

Problems found on the way (and fixed): a wrong package name (`arecord` is shipped by
`alsa-utils-aplay`, there is no `alsa-utils-arecord`), the upstream j1939 project had no CMake `install()` rules,
BusyBox `head` has no `-c`, and oeqa's `copyTo()` recreates symlinks on the target instead of copying them.

Not measured: a reboot into slot B after the install (the test checks the boot target only), and anything on real
hardware.

## Production notes (not done here)

- **Signing keys**: `create-dev-keys.sh` writes unencrypted keys for development. A product signs bundles on a separate
  machine or with an HSM/PKCS#11 token (RAUC supports `pkcs11:` URIs) and ships only the CA certificate.
- **Secure boot**: GRUB and the kernel are not verified here. On real hardware this goes with UEFI Secure Boot or the
  SoC's ROM verification; my [cra-embedded-linux-demo](https://github.com/rromero-emb/cra-embedded-linux-demo) shows
  verified boot with signed FIT images and dm-verity on the root filesystem.
- **Read-only root and CVE tracking**: next steps are `read-only-rootfs` with state on `/data`, and `cve-check` (or the
  newer `vex` class) as a CI gate; the NVD database download is too slow for every CI run.
- **Upgrade path**: scarthgap is the current LTS on most products; moving to wrynose (6.0 LTS) is a separate branch.

## Licence

MIT, see [COPYING.MIT](COPYING.MIT). Upstream layers keep their own licences.
