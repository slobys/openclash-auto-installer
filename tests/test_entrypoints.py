"""Lifecycle regressions: run real entrypoints with isolated paths and fake downloads."""
import os
from pathlib import Path
import re
import shlex
import signal
import shutil
import sys
import subprocess
import time
import tempfile
import unittest

from test_installers import function

SH = shlex.split(os.environ.get("TEST_SHELL", "sh"))
SH[0] = shutil.which(SH[0]) or SH[0]
ROOT = Path(__file__).resolve().parents[1]
INSTALLERS = ('install', 'passwall', 'passwall2', 'nikki', 'smartdns', 'mosdns', 'daed')


class EntrypointTests(unittest.TestCase):
    def prepare(self, root, name):
        source = (ROOT / (name + '.sh')).read_text()
        source = re.sub(r'^LOCKDIR=.*$', 'LOCKDIR="' + str(root / 'lock') + '"', source, flags=re.M)
        source = re.sub(r'^TMP_ROOT=.*$', 'TMP_ROOT="' + str(root / 'work') + '"', source, flags=re.M)
        # daed checks root before taking its lock; never require root for this test.
        source = source.replace('$(id -u)', '0')
        script = root / 'entry.sh'
        script.write_text(source)
        return script

    def test_contender_never_removes_owner_files_or_empty_lock(self):
        for name in INSTALLERS:
            for occupied in (False, True):
                with self.subTest(name=name, occupied=occupied), tempfile.TemporaryDirectory() as tmp:
                    root = Path(tmp)
                    script = self.prepare(root, name)
                    lock = root / 'lock'
                    lock.mkdir()
                    if occupied:
                        (lock / 'owner').write_text('owner')
                    work = root / 'work'
                    work.mkdir()
                    marker = work / 'owner-download'
                    marker.write_text('keep me')
                    for _ in range(2):
                        result = subprocess.run(SH + [str(script)], text=True, capture_output=True, timeout=3)
                        self.assertNotEqual(result.returncode, 0)
                        self.assertIn('任务正在运行', result.stderr)
                        self.assertTrue(lock.is_dir(), result.stderr)
                        self.assertEqual(marker.read_text(), 'keep me')

    def test_help_does_not_touch_running_installer(self):
        for name in ('install', 'smartdns', 'mosdns', 'daed'):
            with self.subTest(name=name), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                script = self.prepare(root, name)
                (root / 'lock').mkdir()
                (root / 'work').mkdir()
                (root / 'work' / 'owner-download').write_text('keep me')
                result = subprocess.run(SH + [str(script), '--help'], text=True, capture_output=True, timeout=3)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertTrue((root / 'lock').is_dir())
                self.assertEqual((root / 'work' / 'owner-download').read_text(), 'keep me')

    def test_owner_exit_and_signals_release_only_owned_lock(self):
        acquisition = r'(if ! mkdir "\$LOCKDIR" 2>/dev/null; then\n.*?\n\s*fi\n(?:\s*LOCK_ACQUIRED="1"\n)?)'
        for name in INSTALLERS:
            for outcome in (0, 23, signal.SIGINT, signal.SIGTERM):
                with self.subTest(name=name, outcome=outcome), tempfile.TemporaryDirectory() as tmp:
                    root = Path(tmp)
                    script = self.prepare(root, name)
                    if outcome in (0, 23):
                        action = f'\nexit {outcome}\n'
                    else:
                        action = '''
printf 'READY\\n'
while [ ! -f "$RELEASE_TEST" ]; do sleep 0.01; done
printf 'CONTINUED_AFTER_SIGNAL\\n'
exit 0
'''
                    if name in ('install', 'smartdns', 'mosdns', 'daed', 'passwall', 'passwall2'):
                        action = '\nmkdir -p "$TMP_ROOT"\necho owned > "$TMP_ROOT/download"\n' + action
                    source, count = re.subn(acquisition, lambda m: m[0] + action,
                                             script.read_text(), count=1, flags=re.S)
                    self.assertEqual(count, 1, 'test gate must precede all installer side effects')
                    script.write_text(source)
                    with subprocess.Popen(SH + [str(script)], text=True, stdout=subprocess.PIPE,
                                          stderr=subprocess.PIPE, env={**os.environ,
                                          'RELEASE_TEST': str(root / 'release')}) as process:
                        if outcome not in (0, 23):
                            self.assertEqual(process.stdout.readline(), 'READY\n')
                            process.send_signal(outcome)
                            (root / 'release').touch()
                        stdout, stderr = process.communicate(timeout=3)
                        expected = outcome if outcome in (0, 23) else 128 + outcome
                        self.assertEqual(process.returncode, expected, stdout + stderr)
                        self.assertNotIn('CONTINUED_AFTER_SIGNAL', stdout)
                    self.assertFalse((root / 'lock').exists())
                    if name in ('install', 'smartdns', 'mosdns', 'daed', 'passwall', 'passwall2'):
                        self.assertFalse((root / 'work').exists())

    def test_concurrent_menu_and_update_checks_keep_separate_workspaces(self):
        for name in ('menu', 'check-updates', 'update', 'auto-download-pro', 'test-auto-download'):
            with self.subTest(name=name), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                bindir = root / 'bin'
                bindir.mkdir()
                # Pause two downloads after writing their different scripts, then release together.
                client = bindir / 'curl'
                client.write_text('#!' + sys.executable + '\n' + """
import os, pathlib, sys, time
out = pathlib.Path(sys.argv[sys.argv.index('-o') + 1])
root = pathlib.Path(os.environ['TEST_ROOT'])
out.write_text('echo CHILD_' + os.environ['TASK_ID'] + '\\n')
(root / (os.environ['TASK_ID'] + '.ready')).touch()
while not (root / 'release').exists():
    time.sleep(0.01)
""")
                client.chmod(0o755)
                source = (ROOT / (name + '.sh')).read_text().replace('/tmp/', str(root) + '/')
                if name == 'check-updates':
                    overrides = """
detect_pkg_mgr() { echo opkg; }
check_openclash() {
    echo "CHILD_$TASK_ID" > "$TMP_ROOT/version"
    touch "$TEST_ROOT/$TASK_ID.ready"
    while [ ! -f "$TEST_ROOT/release" ]; do sleep 0.01; done
    cat "$TMP_ROOT/version"
}
"""
                    source = source.removesuffix('main "$@"\n') + overrides + '\nmain "$@"\n'
                script = root / 'entry.sh'
                script.write_text(source)
                args = SH + [str(script)]
                if name == 'menu':
                    args.append('--check-update-openclash')
                elif name == 'check-updates':
                    args.append('--openclash')
                processes = []
                try:
                    for task in ('A', 'B'):
                        processes.append(subprocess.Popen(args, cwd=root, text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                            env={**os.environ, 'PATH': str(bindir) + ':' + os.environ['PATH'],
                                 'TEST_ROOT': str(root), 'TASK_ID': task,
                                 'OPENCLASH_AUTO_BASE_URL': 'https://example.invalid/mirror'}))
                        deadline = time.monotonic() + 3
                        while not (root / (task + '.ready')).exists() and time.monotonic() < deadline:
                            time.sleep(0.01)
                        self.assertTrue((root / (task + '.ready')).exists(), name)
                    (root / 'release').touch()
                    for task, process in zip(('A', 'B'), processes):
                        stdout, stderr = process.communicate(timeout=3)
                        self.assertEqual(process.returncode, 0, stdout + stderr)
                        self.assertIn('CHILD_' + task, stdout)
                        self.assertNotIn('CHILD_' + ('B' if task == 'A' else 'A'), stdout)
                    self.assertEqual(sorted(p.name for p in root.iterdir()),
                                     ['A.ready', 'B.ready', 'bin', 'entry.sh', 'release'])
                finally:
                    (root / 'release').touch()
                    for process in processes:
                        if process.poll() is None:
                            process.kill()
                        process.communicate()

    def test_passwall_subshell_downloads_are_cleaned_with_owned_workspace(self):
        for name in ('passwall', 'passwall2'):
            with self.subTest(name=name), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                lock = root / 'lock'
                lock.mkdir()
                work = root / 'work'
                work.mkdir()
                code = """
set -eu
TMPFILES=''
LOCK_ACQUIRED=1
log() { :; }
warn() { :; }
fetch_text() { echo fixture; }
find_pkg_link() { echo /projects/test/files/fixture.ipk; }
download_file() { echo fixture > "$2"; }
"""
                code += '\n'.join(function(name + '.sh', fn) for fn in (
                    'register_tmp', 'cleanup', 'download_pkg_from_dir'))
                # Never let the baseline reproduction write to shared /tmp.
                code = code.replace('output="/tmp/$filename"', 'output="$TEST_ROOT/$filename"')
                code += '\nPKG="$(download_pkg_from_dir fixture packages ipk)"\ncleanup\n[ ! -e "$PKG" ]\n'
                result = subprocess.run(SH + ['-c', code], text=True, capture_output=True,
                    env={**os.environ, 'LOCKDIR': str(lock), 'TMP_ROOT': str(work),
                         'TEST_ROOT': str(root), 'SF_BASE': 'https://example.invalid', 'PACKAGE_DIR': 'test'})
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertFalse(lock.exists())
                self.assertFalse(work.exists())

    def test_wrappers_reject_failed_and_empty_downloads_and_preserve_child_status(self):
        for name in ('update', 'auto-download-pro', 'test-auto-download'):
            for downloader in ('curl', 'wget', 'fallback'):
                cases = [('failed', 1), ('empty', 1), ('child-error', 23), ('ok', 0)]
                if name == 'update':
                    cases.append(('check', 0))
                for behavior, expected in cases:
                    with self.subTest(name=name, downloader=downloader, behavior=behavior), tempfile.TemporaryDirectory() as tmp:
                        root = Path(tmp)
                        bindir = root / 'bin'
                        bindir.mkdir()
                        # Both clients share this implementation; failed output is still executable.
                        fake = '''#!/bin/sh
out=''
url=''
while [ "$#" -gt 0 ]; do
 case "$1" in -o|-qO) shift; out="$1";; https://*) url="$1";; esac
 shift
done
[ "$url" = "$EXPECTED_URL" ] || exit 9
case "$BEHAVIOR" in
 failed) echo 'echo EXECUTED_PARTIAL' > "$out"; exit 8;;
 empty) : > "$out";;
 *) printf 'echo CHILD_RAN\\nprintf "ARG:%%s\\\\n" "$@"\\nexit %s\\n' "$CHILD_STATUS" > "$out";;
esac
'''
                        client = 'wget' if downloader == 'fallback' else downloader
                        (bindir / client).write_text(fake)
                        (bindir / client).chmod(0o755)
                        if downloader == 'fallback':
                            (bindir / 'curl').write_text('#!/bin/sh\nexit 8\n')
                            (bindir / 'curl').chmod(0o755)
                        for command in ('sh', 'mktemp', 'rm', 'chmod'):
                            target = SH[0] if command == 'sh' else command
                            (bindir / command).symlink_to(shutil.which(target))
                        script = root / 'entry.sh'
                        source = (ROOT / (name + '.sh')).read_text()
                        # Keep all temporary artifacts inside this test.
                        source = source.replace('/tmp/', str(root) + '/')
                        script.write_text(source)
                        args = SH + [str(script)] + (['--check'] if behavior == 'check' else []) + ['--skip-restart']
                        result = subprocess.run(args, cwd=root,
                                                text=True, capture_output=True, timeout=3,
                                                env={**os.environ, 'PATH': str(bindir), 'BEHAVIOR': behavior,
                                                     'CHILD_STATUS': '23' if behavior == 'child-error' else '0',
                                                     'OPENCLASH_AUTO_BASE_URL': 'https://example.invalid/mirror',
                                                     'EXPECTED_URL': 'https://example.invalid/mirror/' + (
                                                         'install.sh' if name == 'update' else 'passwall.sh')})
                        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
                        self.assertNotIn('EXECUTED_PARTIAL', result.stdout)
                        if behavior in ('child-error', 'ok', 'check'):
                            self.assertIn('CHILD_RAN', result.stdout)
                            self.assertIn('ARG:--skip-restart', result.stdout)
                            if behavior == 'check':
                                self.assertIn('ARG:--check-update', result.stdout)
                                self.assertIn('ARG:--skip-pkg-update', result.stdout)
                        self.assertEqual(sorted(p.name for p in root.iterdir()), ['bin', 'entry.sh'])


if __name__ == '__main__':
    unittest.main()
