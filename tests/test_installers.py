#!/usr/bin/env python3
"""Offline tests of the actual shell functions (no router changes or network)."""
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import tempfile
import unittest

SH = shlex.split(os.environ.get("TEST_SHELL", "sh"))
SH[0] = shutil.which(SH[0]) or SH[0]
ROOT = Path(__file__).resolve().parents[1]


def function(script, name):
    source = (ROOT / script).read_text()
    match = re.search(r'^' + re.escape(name) + r'\(\) \{\n.*?^\}', source, re.M | re.S)
    if not match:
        raise AssertionError(f'{script}: missing {name}')
    return match.group()


def shell(code, **env):
    return subprocess.run(SH + ['-c', 'set -eu\n' + code], text=True,
                          capture_output=True, env={**os.environ, **env})


class InstallerTests(unittest.TestCase):
    def test_openclash_partial_apk_index_failure_reaches_dependency_check(self):
        code = '''
log() { echo "$*"; }
warn() { echo "$*" >&2; }
die() { echo "$*" >&2; exit 1; }
apk() {
    case "$1" in
        update)
            echo 'wgetFailed to send request: Operation not permitted' >&2
            echo '0 unavailable, 2 stale; 11272 distinct packages available' >&2
            return 2 ;;
        info) return 0 ;;
        add) echo UNNECESSARY_DEPENDENCY_TRANSACTION ;;
    esac
}
'''
        code += (function('install.sh', 'maybe_update_index_apk') + '\n' +
                 function('install.sh', 'install_dependencies_apk') +
                 '\ninstall_dependencies_apk nft\necho DEPENDENCIES_READY')
        result = shell(code, FORCE_OPKG_UPDATE='1')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('DEPENDENCIES_READY', result.stdout)
        self.assertNotIn('UNNECESSARY_DEPENDENCY_TRANSACTION', result.stdout)
        self.assertIn('apk update 未完全成功', result.stderr)

    def test_openclash_apk_installs_only_missing_dependencies_and_stops_on_failure(self):
        code = '''
log() { :; }
warn() { :; }
die() { echo "$*" >&2; exit 1; }
apk() {
    case "$1" in
        info) [ "$3" != curl ] ;;
        add) echo "$*"; return "$ADD_STATUS" ;;
        *) return 99 ;;
    esac
}
'''
        code += (function('install.sh', 'maybe_update_index_apk') + '\n' +
                 function('install.sh', 'install_dependencies_apk') +
                 '\ninstall_dependencies_apk nft\necho DEPENDENCIES_READY')
        for status in (0, 4):
            with self.subTest(add_status=status):
                result = shell(code, FORCE_OPKG_UPDATE='0', ADD_STATUS=str(status))
                self.assertIn('add curl\n', result.stdout)
                self.assertEqual('DEPENDENCIES_READY' in result.stdout, status == 0)
                self.assertEqual(result.returncode, 0 if status == 0 else 1)
                if status:
                    self.assertIn('未执行插件更新', result.stderr)

    def test_openclash_main_partial_index_and_post_install_version(self):
        for behavior in ('upgrade', 'noop', 'missing', 'install-error', 'no-core', 'core-download-error'):
            with self.subTest(behavior=behavior), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                version = root / 'version'
                version.write_text('0.47.156')
                source = (ROOT / 'install.sh').read_text()
                source = source.replace('/tmp/openclash-auto-install', str(root / 'task'))
                overrides = '''
detect_pkg_mgr() { echo apk; }
detect_firewall_stack() { echo nft; }
get_distr_arch() { echo aarch64_generic; }
get_distr_release() { echo 25.12.5; }
jsonfilter() { :; }
detect_core_candidates() { [ "$BEHAVIOR" = no-core ] || echo clash-linux-arm64.tar.gz; }
download_core() { return 1; }
fetch_openclash_release_meta() { :; }
get_latest_tag() { echo v0.48.002; }
fetch_openclash_package_url() { echo https://example.invalid/openclash.apk; }
download_file() { echo fixture > "$2"; }
apk() {
    case "$1" in
        update)
            echo '0 unavailable, 2 stale; 11272 distinct packages available' >&2
            return 2 ;;
        info) return 0 ;;
        list) printf 'luci-app-openclash %s\\n' "$(cat "$VERSION_FILE")" ;;
        add)
            case "$BEHAVIOR" in
                upgrade|no-core|core-download-error) echo 0.48.002 > "$VERSION_FILE" ;;
                missing) : > "$VERSION_FILE" ;;
                install-error) return 4 ;;
                noop) : ;;
            esac ;;
        *) return 99 ;;
    esac
}
'''
                source = source.removesuffix('main "$@"\n') + overrides + '\nmain "$@"\n'
                script = root / 'installer.sh'
                script.write_text(source)
                args = SH + [str(script), '--skip-restart']
                if behavior not in ('no-core', 'core-download-error'):
                    args.append('--plugin-only')
                result = subprocess.run(args,
                                        text=True, capture_output=True, env={**os.environ,
                                        'VERSION_FILE': str(version), 'BEHAVIOR': behavior})
                self.assertEqual(result.returncode == 0, behavior == 'upgrade', result.stderr)
                self.assertEqual('==> 完成' in result.stdout, behavior == 'upgrade')
                if behavior == 'upgrade':
                    self.assertIn('0.48.002（已核验目标 v0.48.002）', result.stdout)
                elif behavior == 'noop':
                    self.assertIn('更新未生效', result.stderr)

    def test_interactive_menu_retains_failures_but_cli_propagates_them(self):
        code = ('download_and_run() { echo child-failed >&2; exit 23; }\n' +
                function('menu.sh', 'run_interactive_script') +
                '\nrun_interactive_script install.sh\necho MENU_ALIVE')
        result = shell(code)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('MENU_ALIVE', result.stdout)
        self.assertIn('退出码 23', result.stderr)
        self.assertIn('本次未确认完成', result.stderr)
        code = ('download_and_run() { return 23; }\n' +
                function('menu.sh', 'run_action') + '\nrun_action openclash\necho FALSE_SUCCESS')
        result = shell(code)
        self.assertEqual(result.returncode, 23)
        self.assertNotIn('FALSE_SUCCESS', result.stdout)

    def test_menu_rejects_empty_download_instead_of_executing_it(self):
        with tempfile.TemporaryDirectory() as tmp:
            code = ('log() { :; }\ndie() { echo "$*" >&2; exit 1; }\n'
                    'resolve_base_url() { echo https://example.invalid; }\n'
                    'download_file() { : > "$2"; }\n' +
                    function('menu.sh', 'download_and_run') +
                    '\ndownload_and_run fixture.sh\necho FALSE_SUCCESS')
            result = shell(code, TMP_SCRIPT=str(Path(tmp) / 'action.sh'))
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('下载的脚本为空', result.stderr)
            self.assertNotIn('FALSE_SUCCESS', result.stdout)

    def test_core_cpu_and_userspace_architecture(self):
        cases = {
            'aarch64_cortex-a53': 'arm64', 'aarch64_cortex-a72': 'arm64',
            'aarch64_cortex-a76': 'arm64', 'aarch64_generic': 'arm64',
            'arm_arm1176jzf-s_vfp': 'armv6', 'arm_arm926ej-s': 'armv5',
            'arm_cortex-a15_neon-vfpv4': 'armv7', 'arm_cortex-a5_vfpv4': 'armv7',
            'arm_cortex-a7': 'armv7', 'arm_cortex-a7_neon-vfpv4': 'armv7',
            'arm_cortex-a7_vfpv4': 'armv7', 'arm_cortex-a8_vfpv3': 'armv7',
            'arm_cortex-a9': 'armv7', 'arm_cortex-a9_neon': 'armv7',
            'arm_cortex-a9_vfpv3-d16': 'armv7', 'arm_xscale': 'armv5',
            'arm_fa526': '', 'armeb_xscale': '',
            'i386_pentium-mmx': '386', 'i386_pentium4': '386',
            'mips64_mips64r2': 'mips64', 'mips64_octeonplus': 'mips64',
            'mips64el_mips64r2': 'mips64le',
            'mips_24kc': 'mips-softfloat', 'mips_4kec': 'mips-softfloat',
            'mips_mips32': 'mips-softfloat', 'mipsel_24kc': 'mipsle-softfloat',
            'mipsel_24kc_24kf': 'mipsle-softfloat', 'mipsel_74kc': 'mipsle-softfloat',
            'mipsel_mips32': 'mipsle-softfloat',
            'riscv64_generic': 'riscv64', 'riscv64_riscv64': 'riscv64',
            'loongarch64_generic': 'loong64-abi2',
            'powerpc64_e5500': '', 'powerpc_464fp': '', 'powerpc_8548': '',
        }
        code = ('get_distr_arch() { printf "%s" "$ARCH_TEST"; }\n'
                'uname() { printf "%s" "$KERNEL_ARCH"; }\n'
                'detect_x86_level() { printf v1; }\n' +
                function('install.sh', 'detect_core_candidates') + '\ndetect_core_candidates')
        for arch, core in cases.items():
            with self.subTest(arch=arch):
                # A 64-bit kernel does not imply a 64-bit userspace.
                result = shell(code, ARCH_TEST=arch, KERNEL_ARCH='x86_64')
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout, f'clash-linux-{core}.tar.gz' if core else '')

    def test_smartdns_rejects_big_endian_arm_and_uses_distribution_arch(self):
        code = ('get_distr_arch() { printf "%s" "$ARCH_TEST"; }\n'
                'uname() { printf aarch64; }\n' +
                function('smartdns.sh', 'detect_smartdns_arch') + '\ndetect_smartdns_arch')
        for arch, expected in [('armeb_xscale', ''), ('arm_fa526', ''), ('arm_cortex-a7', 'arm'),
                               ('mipsel_24kc', 'mipsel'), ('mips64el_mips64r2', 'mipsel'),
                               ('mips64_octeonplus', 'mips'), ('i386_pentium4', 'x86')]:
            result = shell(code, ARCH_TEST=arch)
            self.assertEqual(result.stdout, expected)

    def test_smartdns_core_check_rejects_failed_or_empty_execution(self):
        for command, expected in [('return 126', 1), ('return 0', 1),
                                  ('printf "smartdns 48.4"', 0)]:
            result = shell('die() { exit 1; }\nsmartdns() { ' + command + '; }\n' +
                           function('smartdns.sh', 'verify_smartdns_core') +
                           '\nverify_smartdns_core')
            self.assertEqual(result.returncode, expected)
        source = (ROOT / 'smartdns.sh').read_text()
        self.assertLess(source.index('    verify_smartdns_core\n'),
                        source.index('    restart_smartdns\n'))

    def test_daed_generic_fallback_resolves_an_empty_apk_tag(self):
        code = ('log() { :; }\ndie() { exit 1; }\n'
                'find_latest_tag() { printf v2.1.1; }\n'
                'download_url() { printf "%s" "$1"; return 1; }\n' +
                function('daed.sh', 'install_daed') + '\ninstall_daed mips32 ""')
        result = shell(code, DAED_REPO='daeuniverse/daed', TMP_ROOT='/tmp/test-not-written')
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, 'https://github.com/daeuniverse/daed/releases/'
                         'download/v2.1.1/daed-linux-mips32.zip')

    def test_openclash_api_failure_ignores_html_route_templates(self):
        with tempfile.TemporaryDirectory() as tmp:
            fixture = Path(tmp) / 'fixture.html'
            fixture.write_text('<script>"/releases/tag/*name"</script>\n'
                               '<a href="/another/project/releases/tag/v9.9.9">wrong repo</a>\n'
                               '<a href="/vernesong/OpenClash/releases/tag/v0.47.156">release</a>')
            code = ('warn() { :; }\n'
                    'download_file() { if [ "$1" = "$API_URL" ]; then '
                    'printf partial > "$2"; return 22; fi; cp "$FIXTURE" "$2"; }\n' +
                    function('install.sh', 'fetch_openclash_release_meta') + '\n' +
                    function('install.sh', 'get_latest_tag') +
                    '\nfetch_openclash_release_meta || true\nget_latest_tag')
            result = shell(code, TMP_ROOT=tmp, API_URL='https://api.example.invalid',
                           FIXTURE=str(fixture))
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.strip(), 'v0.47.156')

    def test_unrunnable_core_does_not_replace_existing_binary(self):
        for behavior in ('exit 1', 'exit 0'):
            with self.subTest(behavior=behavior), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                old = root / 'installed'
                old.mkdir()
                (old / 'clash_meta').write_text('old core')
                binary = root / 'binary'
                binary.write_text('#!/bin/sh\n' + behavior + '\n')
                binary.chmod(0o755)
                import tarfile
                with tarfile.open(root / 'openclash-core.tar.gz', 'w:gz') as archive:
                    archive.add(binary, arcname='clash')
                code = ('die() { echo "$*" >&2; exit 1; }\nlog() { :; }\n' +
                        function('install.sh', 'extract_and_install_core').replace(
                            '/etc/openclash/core', str(old)) + '\nextract_and_install_core')
                result = shell(code, TMP_ROOT=tmp)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual((old / 'clash_meta').read_text(), 'old core')
                self.assertFalse((old / 'clash_meta.bak').exists())

    def test_apk_database_wins_over_leftover_opkg(self):
        scripts = ('install', 'smartdns', 'mosdns', 'daed', 'repair', 'uninstall',
                   'nikki', 'passwall', 'passwall2', 'check-updates')
        with tempfile.TemporaryDirectory() as tmp:
            db = Path(tmp) / 'installed'
            for populated in (False, True):
                db.write_text('installed packages' if populated else '')
                for script in scripts:
                    code = ('command() { case "$2" in opkg|apk) return 0;; *) return 1;; esac; }\n' +
                            function(script + '.sh', 'detect_pkg_mgr').replace(
                                '/lib/apk/db/installed', str(db)) + '\ndetect_pkg_mgr')
                    with self.subTest(script=script, apk_database=populated):
                        result = shell(code)
                        self.assertEqual(result.returncode, 0, result.stderr)
                        self.assertEqual(result.stdout, 'apk' if populated else 'opkg')

    def test_incompatible_daed_archive_preserves_existing_service_and_core(self):
        import zipfile
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            archive = root / 'fixture.zip'
            with zipfile.ZipFile(archive, 'w') as z:
                base = 'daed-linux-mips32/'
                z.writestr(base + 'daed-linux-mips32', '#!/bin/sh\nexit 127\n')
                z.writestr(base + 'geoip.dat', 'fixture')
                z.writestr(base + 'geosite.dat', 'fixture')
            old = root / 'old-daed'
            old.write_text('old core')
            init = root / 'init'
            stopped = root / 'stopped'
            init.write_text('#!/bin/sh\ntouch "' + str(stopped) + '"\n')
            init.chmod(0o755)
            code = ('log() { :; }\ndie() { echo "$*" >&2; exit 1; }\n'
                    'download_url() { cp "$FIXTURE" "$2"; }\nverify_archive() { :; }\n' +
                    function('daed.sh', 'install_daed') + '\ninstall_daed mips32 v2.1.1')
            result = shell(code, TMP_ROOT=tmp, FIXTURE=str(archive), DAED_BIN=str(old),
                           DAED_INIT=str(init), DAED_REPO='daeuniverse/daed')
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(old.read_text(), 'old core')
            self.assertFalse(stopped.exists())
            self.assertIn('保留原核心', result.stderr)

    def test_passwall_package_generation(self):
        for plugin in ('passwall', 'passwall2'):
            fn = 'normalize_release_for_' + plugin
            for release, manager, expected in (
                ('25.12.5', 'apk', '25.12'),
                ('24.10.8', 'opkg', '24.10'),
                ('25.12.2', 'opkg', '24.10'),  # KWRT issue #10
                ('23.05.6', 'opkg', '23.05'),
                ('22.03.7', 'opkg', '22.03'),
                ('SNAPSHOT', 'apk', 'snapshots'),
                ('GDQ', 'opkg', ''),
            ):
                with self.subTest(plugin=plugin, release=release, manager=manager):
                    result = shell(function(plugin + '.sh', fn) +
                                   f'\n{fn} "$REL" "$MGR"', REL=release, MGR=manager)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(result.stdout, expected)

    def test_nikki_supported_branches(self):
        for release, expected in [('25.12.5', 'openwrt-25.12'),
                                  ('24.10.8', 'openwrt-24.10'),
                                  ('SNAPSHOT', 'SNAPSHOT'), ('23.05-SNAPSHOT', '')]:
            result = shell(function('nikki.sh', 'detect_nikki_branch') +
                           '\ndetect_nikki_branch', REL_RAW=release)
            self.assertEqual(result.stdout, expected)

    def test_nikki_download_failures_do_not_execute(self):
        for behavior in ('exit 8', 'exit 0'):
            with tempfile.TemporaryDirectory() as tmp:
                downloader = Path(tmp) / 'wget'
                downloader.write_text('#!/bin/sh\n' + behavior + '\n')
                downloader.chmod(0o755)
                result = shell('die() { echo "$*" >&2; exit 1; }\n' +
                               'TMP_SCRIPT=""\ntrap \'[ -z "$TMP_SCRIPT" ] || rm -f "$TMP_SCRIPT"\' EXIT\n' +
                               function('nikki.sh', 'run_official_script') +
                               '\nrun_official_script https://example.invalid/feed.sh\necho FALSE_SUCCESS',
                               PATH=tmp + ':' + os.environ['PATH'])
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn('FALSE_SUCCESS', result.stdout)

    def test_passwall_asset_selection_json_and_html_fallback(self):
        for plugin in ('passwall', 'passwall2'):
            names = ([f'23.05-24.10_luci-app-{plugin}_26.10.4-r1_all.ipk',
                      f'25.12+_luci-app-{plugin}-26.10.4-r1.apk'] if plugin == 'passwall'
                     else [f'luci-app-{plugin}_26.10.1-r2_all.ipk',
                           f'luci-app-{plugin}-26.10.1-r2.apk'])
            urls = [f'https://github.com/Openwrt-Passwall/openwrt-{plugin}/releases/download/test/{n}'
                    for n in names]
            code = (function(plugin + '.sh', 'github_release_prefix') + '\n'
                    if plugin == 'passwall' else '')
            code += function(plugin + '.sh', 'find_github_pkg_url')
            code += '\nfind_github_pkg_url "$PKG" "$EXT"'
            for manager, ext, index in [('opkg', 'ipk', 0), ('apk', 'apk', 1)]:
                for fallback in (False, True):
                    result = shell(code, PKG='luci-app-' + plugin, EXT=ext,
                                   PKG_MGR=manager, SUPPORTED_RELEASE='24.10' if index == 0 else '25.12',
                                   GH_RELEASE_JSON='' if fallback else json.dumps({'assets': [
                                       {'browser_download_url': u} for u in urls]}),
                                   GH_RELEASE_ASSET_URLS='\n'.join(urls) if fallback else '')
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(result.stdout.strip(), urls[index])

    def test_revision_updates_and_unversioned_release_revision(self):
        code = (function('check-updates.sh', 'normalize_version') + '\n' +
                function('check-updates.sh', 'print_result') +
                '\nprint_result test "$INST" "$LATEST_TEST"')
        for installed, latest, expected in (
            ('26.10.1-r1', '26.10.1-2', '有新版本可更新'),
            ('26.10.1-r2', '26.10.1-2', '已是最新'),
            ('1.26.1-r1', 'v1.26.1', '已是最新'),
        ):
            result = shell(code, INST=installed, LATEST_TEST=latest)
            self.assertIn(expected, result.stdout)

    def test_daed_apk_compares_openwrt_build_not_generic_release(self):
        code = '''
PKG_MGR=apk
TMP_ROOT=/tmp
DAED_RELEASES_API=https://example.invalid/generic
DAED_RELEASES_PAGE=https://example.invalid/generic-page
daed() { echo daed-671e65d_wing-dc50308_core-caa6f5e; }
LUCI_DAED_API=https://example.invalid/openwrt-build
get_installed_apk_version() {
    case "$1" in daed) echo 2026.07.31-r1;; *) echo 1.4-r1;; esac
}
fetch_latest_tag_jsonfilter() { echo daed_2026.07.31-r1; }
fetch_url() { echo WRONG_GENERIC_SOURCE >&2; return 1; }
print_result() { printf '%s|%s|%s\\n' "$1" "$2" "$3"; }
print_result_no_compare() { :; }
'''
        result = shell(code + function('check-updates.sh', 'check_daed') + '\ncheck_daed')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('2026.07.31-r1|2026.07.31-r1', result.stdout)
        self.assertNotIn('WRONG_GENERIC_SOURCE', result.stderr)

    def test_wrong_signing_key_stops_before_install(self):
        for plugin in ('passwall', 'passwall2'):
            code = '''
need_cmd() { command -v "$1" >/dev/null; }
register_tmp() { :; }
download_file() { printf 'wrong key' > "$2"; }
die() { echo "$*" >&2; exit 1; }
trap '[ -z "${key_tmp:-}" ] || rm -f "$key_tmp"' EXIT
SF_BASE=https://example.invalid
'''
            result = shell(code + function(plugin + '.sh', 'install_signed_apk') +
                           '\ninstall_signed_apk\necho FALSE_SUCCESS')
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('公钥摘要不匹配', result.stderr)
            self.assertNotIn('FALSE_SUCCESS', result.stdout)


if __name__ == '__main__':
    unittest.main()
