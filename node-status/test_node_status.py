#!/usr/bin/env python3
"""Offline regression tests for node-status (requires Bash and jq).

Run: python3 node-status/test_node_status.py [path/to/node-status.sh]
"""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).with_name('node-status.sh')
if len(sys.argv) == 2 and not sys.argv[1].startswith('-'):
    SCRIPT = Path(sys.argv.pop(1))
SCRIPT = SCRIPT.resolve()


def ledgers(core, ingest):
    return json.dumps({'core_latest_ledger': core, 'ingest_latest_ledger': ingest})


class NodeStatusTests(unittest.TestCase):
    def setUp(self):
        self.assertTrue(SCRIPT.is_file(), f'Script not found: {SCRIPT}')
        self.assertIsNotNone(shutil.which('jq'), 'jq is required')
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.tmp = Path(tmp.name)
        curl = self.tmp / 'curl'
        curl.write_text(
            '#!/bin/bash\n'
            'case "${@: -1}" in\n'
            '  http://localhost:8000/|http://localhost:11626/info|'
            'http://localhost:11626/peers) ;;\n'
            '  *) exit 22 ;;\n'
            'esac\n'
            '[[ -n "$MOCK_RESPONSE" ]] || exit 22\n'
            'printf "%s\\n" "$MOCK_RESPONSE"\n'
        )
        curl.chmod(0o755)
        # Prevent the Horizon progress section from reading host log files.
        ls = self.tmp / 'ls'
        ls.write_text('#!/bin/bash\nexit 1\n')
        ls.chmod(0o755)

    def run_section(self, flag, response):
        env = dict(os.environ, PATH=str(self.tmp) + os.pathsep + os.environ['PATH'],
                   MOCK_RESPONSE=response, LC_ALL='C')
        result = subprocess.run(['bash', str(SCRIPT), flag], env=env,
                                text=True, capture_output=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stderr, '')
        return result.stdout

    def assert_field(self, output, label, expected):
        match = re.search(r'^\s*' + re.escape(label) + r':[ \t]*(.*)$',
                          output, re.MULTILINE)
        self.assertIsNotNone(match, output)
        self.assertEqual(match.group(1).strip(), expected, output)

    def test_horizon(self):
        cases = [
            ('API unavailable', '', 'Not Running'),
            ('empty JSON object', '{}', 'Not Running'),
            ('null ledgers', ledgers(None, None), 'Not Running'),
            ('both zero', ledgers(0, 0), 'Catching Up'),
            ('ingest zero', ledgers(100, 0), 'Not Running'),
            ('equal ledgers', ledgers(100, 100), 'Synced'),
            ('gap two', ledgers(100, 98), 'Synced'),
            ('gap five', ledgers(100, 95), 'Synced'),
            ('gap six', ledgers(100, 94), 'Syncing'),
            ('reverse gap', ledgers(100, 106), 'Syncing'),
            ('missing ingest', '{"core_latest_ledger":100}', 'Not Running'),
            ('missing core, ingest 2', '{"ingest_latest_ledger":2}', 'Not Running'),
            ('missing core, ingest 100', '{"ingest_latest_ledger":100}', 'Not Running'),
            ('malformed JSON', '{', 'Not Running'),
            ('empty core', ledgers('', 2), 'Not Running'),
            ('empty ingest', ledgers(100, ''), 'Not Running'),
            ('both empty', ledgers('', ''), 'Not Running'),
            ('numeric strings', ledgers('100', '98'), 'Synced'),
            ('invalid text', ledgers('unknown', 100), 'Not Running'),
            ('negative core', ledgers(-1, 2), 'Not Running'),
            ('decimal', ledgers(100, 98.5), 'Not Running'),
            ('false', ledgers(False, 2), 'Not Running'),
        ]
        for name, response, expected in cases:
            with self.subTest(case=name):
                output = self.run_section('--horizon', response)
                label = 'Status' if not response else 'State'
                self.assert_field(output, label, expected)

    def test_horizon_missing_field_display(self):
        output = self.run_section('--horizon', '{"ingest_latest_ledger":2}')
        self.assert_field(output, 'Core Latest Block', 'N/A')
        self.assert_field(output, 'Ingest Block', '2')

    def test_protocol_valid(self):
        data = {'info': {'state': 'Synced!', 'ledger': {'num': 100, 'version': 23},
                         'network': 'Test network', 'build': 'test-build'}}
        output = self.run_section('--protocol', json.dumps(data))
        for label, value in [('State', 'Synced!'), ('Block', '100'),
                             ('Quorum Block', '100'), ('Protocol', '23'),
                             ('Network', 'Test network'), ('Version', 'test-build')]:
            self.assert_field(output, label, value)

    def test_protocol_missing(self):
        output = self.run_section('--protocol', '{}')
        for label in ('State', 'Block', 'Quorum Block', 'Protocol', 'Network', 'Version'):
            self.assert_field(output, label, 'N/A')

    def test_protocol_zero(self):
        output = self.run_section('--protocol', '{"info":{"ledger":{"num":0,"version":0}}}')
        self.assert_field(output, 'Block', '0')
        self.assert_field(output, 'Protocol', '0  (ledger not established — catching up)')

    def test_peers_valid_and_zero(self):
        data = {'authenticated_peers': {'inbound': [{}], 'outbound': [{}, {}]},
                'pending_peers': {'inbound': [], 'outbound': []}}
        output = self.run_section('--peers', json.dumps(data))
        for label, value in [('Authenticated In', '1'), ('Authenticated Out', '2'),
                             ('Pending In', '0'), ('Pending Out', '0')]:
            self.assert_field(output, label, value)


if __name__ == '__main__':
    unittest.main(verbosity=2)
