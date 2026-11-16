# Runtime tests for rromero-image: bitbake rromero-image -c testimage
# They boot the image in QEMU and run over SSH.

import json
import os

from oeqa.runtime.case import OERuntimeTestCase
from oeqa.core.decorator.depends import OETestDepends


class RromeroImageTest(OERuntimeTestCase):

    def run_ok(self, cmd, timeout=120):
        status, out = self.target.run(cmd, timeout)
        self.assertEqual(status, 0, msg=f"{cmd}\n{out}")
        return out

    @OETestDepends(['ssh.SSHTest.test_ssh'])
    def test_no_failed_units(self):
        out = self.run_ok('systemctl --failed --no-legend --plain')
        self.assertEqual(out.strip(), '', msg=out)

    @OETestDepends(['ssh.SSHTest.test_ssh'])
    def test_rauc_status(self):
        out = self.run_ok('rauc status --output-format=json')
        self.assertIn('"compatible":"rromero-qemux86-64"', out.replace(' ', ''))
        self.assertIn('rootfs.0', out)
        self.assertIn('rootfs.1', out)

    @OETestDepends(['ssh.SSHTest.test_ssh'])
    def test_rauc_rejects_unsigned_bundle(self):
        # a file that is not a bundle signed by our CA must never be installed
        self.run_ok('dd if=/dev/urandom of=/tmp/bad.raucb bs=1024 count=64')
        status, out = self.target.run('rauc install /tmp/bad.raucb', 120)
        self.assertNotEqual(status, 0, msg=out)

    @OETestDepends(['rromero.RromeroImageTest.test_rauc_status'])
    def test_rauc_install_bundle(self):
        # the signed bundle from this build installs into the inactive slot and becomes the next boot target
        bundle = os.path.join(self.td['DEPLOY_DIR_IMAGE'], 'rromero-bundle-%s.raucb' % self.td['MACHINE'])
        if not os.path.exists(bundle):
            self.skipTest('build rromero-bundle first')
        # copyTo() recreates symlinks on the target instead of copying, and the deploy name is a symlink
        self.target.copyTo(os.path.realpath(bundle), '/data/update.raucb')
        try:
            self.run_ok('rauc install /data/update.raucb', 600)
        finally:
            self.target.run('rm -f /data/update.raucb')
        st = json.loads(self.run_ok('rauc status --output-format=json'))
        booted = next(n for s in st['slots'] for n, v in s.items() if v.get('state') == 'booted')
        self.assertTrue(booted.startswith('rootfs.'), msg=booted)
        self.assertNotEqual(st['boot_primary'], booted, msg=json.dumps(st))

    @OETestDepends(['ssh.SSHTest.test_ssh'])
    def test_j1939_replay(self):
        out = self.run_ok('rm -rf /tmp/j && j1939log replay '
                          '/usr/share/j1939-edge-logger/traces/truck_pull_away.log --journal /tmp/j')
        self.assertIn('1XKAD49X0DJ123456', out)

    @OETestDepends(['ssh.SSHTest.test_ssh'])
    def test_vcan_available(self):
        self.run_ok('modprobe vcan && modprobe can-raw && ip link add dev vcan0 type vcan '
                    '&& ip link set up vcan0 && ip -details link show vcan0')
        self.run_ok('cansend vcan0 18FEF100#FFFFFF5800FFFFFF')
        self.run_ok('ip link del vcan0')

    @OETestDepends(['ssh.SSHTest.test_ssh'])
    def test_voice_notes_fake_pipeline(self):
        # same smoke test as the project's CI, with the fake engines, on the target's Python
        script = (
            'set -e; d=$(mktemp -d); '
            'printf \'data_dir = "%s"\\nchunk_seconds = 20\\n\' "$d" > "$d/config.toml"; '
            'python3 -c "from edge_voice_notes import audio; audio.write_tone_bursts(\'$d/in.wav\', 45)"; '
            'evn -c "$d/config.toml" enqueue "$d/in.wav"; '
            'evn -c "$d/config.toml" run --once; '
            'evn -c "$d/config.toml" status'
        )
        out = self.run_ok(script, timeout=300)
        self.assertIn(' done ', out)
