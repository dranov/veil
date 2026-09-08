import os
import json
import importlib.util
import sys
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

SCRIPTS = Path(__file__).resolve().parents[1]


class FolderExitStatus(unittest.TestCase):
    def test_failed_child_keeps_report_and_returns_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            shutil.copy(SCRIPTS / 'profile-folder.sh', root)
            child = root / 'profile-file.sh'
            child.write_text('#!/bin/sh\nexit 7\n')
            child.chmod(0o755)
            # The legacy shell runner depends on bc; its replacement must not.
            calculator = root / 'bc'
            calculator.write_text('#!/bin/sh\ncat >/dev/null\necho 0\n')
            calculator.chmod(0o755)
            source = root / 'source'
            source.mkdir()
            (source / 'Failure.lean').write_text('-- controlled compiler failure\n')
            output = root / 'output'
            result = subprocess.run(
                ['bash', str(root / 'profile-folder.sh'), str(source), str(output)],
                env={**os.environ, 'PATH': str(root) + os.pathsep + os.environ['PATH']},
                text=True, capture_output=True,
            )
            self.assertNotEqual(result.returncode, 0, result.stdout)
            self.assertIn('Failed: 1', (output / 'summary.txt').read_text())


def load_script(name):
    spec = importlib.util.spec_from_file_location(name.replace('-', '_'), SCRIPTS / f'{name}.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class StructuredTimings(unittest.TestCase):
    def test_long_identifiers_remain_distinct_through_plot_input(self):
        names = ['veil.' + 'x' * 70 + suffix for suffix in ['A', 'B']]
        profile = {'threads': [{
            'stringArray': names, 'funcTable': {'name': [0, 1]},
            'frameTable': {'func': [0, 1]}, 'stackTable': {'frame': [0, 1], 'prefix': [None, None]},
            'samples': {'stack': [0, 1], 'weight': [2, 3]},
        }]}
        with tempfile.TemporaryDirectory() as directory:
            raw = Path(directory) / 'profile.json'
            raw.write_text(json.dumps(profile))
            result = subprocess.run([sys.executable, str(SCRIPTS / 'parse-profile.py'), str(raw), '--json'],
                                    text=True, capture_output=True, check=True)
            report = Path(directory) / 'timing.json'
            report.write_text(result.stdout)
            stats = load_script('plot-profile-trend').parse_profile_output(str(report))
            self.assertEqual(set(stats), set(names))
            self.assertEqual(stats[names[0]]['total_time'], 2)
            self.assertEqual(stats[names[1]]['total_time'], 3)

    def test_truncated_legacy_identifiers_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'timing.txt'
            path.write_text('Function   Self (ms) Total (ms) Count\n' + 'long...  1.0 2.0 1\n')
            with self.assertRaisesRegex(ValueError, 'regenerate'):
                load_script('plot-profile-trend').parse_profile_output(str(path))

    def test_filtering_does_not_move_leaf_time_to_an_ancestor(self):
        thread = {'stringArray': ['veil.parent', 'other.leaf'],
                  'funcTable': {'name': [0, 1]}, 'frameTable': {'func': [0, 1]},
                  'stackTable': {'frame': [0, 1], 'prefix': [None, 0]},
                  'samples': {'stack': [1], 'weight': [7]}}
        stats = load_script('parse-profile').analyze_samples(thread, ['veil'])
        self.assertEqual(stats['veil.parent']['self_time'], 0)
        self.assertEqual(stats['veil.parent']['total_time'], 7)

    def test_invalid_structured_input_is_a_failure(self):
        result = subprocess.run([sys.executable, str(SCRIPTS / 'parse-profile.py'), '/missing/profile.json', '--json'],
                                text=True, capture_output=True)
        self.assertNotEqual(result.returncode, 0)


if __name__ == '__main__':
    unittest.main()
