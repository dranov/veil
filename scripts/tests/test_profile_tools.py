import os
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


if __name__ == '__main__':
    unittest.main()
