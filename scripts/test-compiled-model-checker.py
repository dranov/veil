#!/usr/bin/env python3
"""Compiled-run integration regressions. Run after `lake build Veil`.

Only the child `lake build` is stubbed: each test elaborates a real Veil source.
This tests orchestration without depending on a platform's native solver linker.
"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


class CompiledModelChecker(unittest.TestCase):
    def test_compiler_failure_is_a_command_error(self):
        lake = shutil.which("lake")
        self.assertIsNotNone(lake)
        with tempfile.TemporaryDirectory(prefix="veil-compiled-test-") as directory:
            root = Path(directory)
            stub = root / "lake"
            stub.write_text('#!/bin/sh\necho "Injected compiler failure" >&2\nexit 17\n')
            stub.chmod(0o755)
            source = root / "CompilerFailure.lean"
            source.write_text("""import Veil
set_option veil.violationIsError false
veil module CompilerFailure
individual x : Bool
#gen_state
after_init { x := false }
action idle { pure () }
invariant [safe] x = false
#gen_spec
#model_check compiled {} {}
end CompilerFailure
""")
            env = json.loads(subprocess.check_output(
                [lake, "env", "python3", "-c", "import json, os; print(json.dumps(dict(os.environ)))"],
                text=True))
            lean = shutil.which("lean", path=env["PATH"])
            env["PATH"] = str(root) + os.pathsep + env["PATH"]
            result = subprocess.run([lean, str(source)], env=env,
                                    capture_output=True, text=True, timeout=120)
            output = result.stdout + result.stderr
            self.assertNotEqual(result.returncode, 0, output)
            self.assertIn("Compilation failed (exit code 17)", output)
            self.assertIn("Injected compiler failure", output)

    def test_generated_source_replays_declarations_and_suppresses_prior_checks(self):
        lake = shutil.which("lake")
        with tempfile.TemporaryDirectory(prefix="veil-compiled-prefix-") as directory:
            root = Path(directory)
            env = json.loads(subprocess.check_output(
                [lake, "env", "python3", "-c", "import json, os; print(json.dumps(dict(os.environ)))"],
                text=True))
            lean = shutil.which("lean", path=env["PATH"])
            stub = root / "lake"
            stub.write_text("#!/bin/sh\ncp Model.lean \"$VEIL_TEST_SOURCE\"\n"
                            "\"$VEIL_TEST_LEAN\" Model.lean > \"$VEIL_TEST_LOG\" 2>&1\n"
                            "echo PrefixCheckExit:$? >&2\nexit 17\n")
            stub.chmod(0o755)
            source = root / "Prefix.lean"
            source.write_text('''/- Header comment:
import ThisIsNotAnImport
-/
import Veil
veil module Prefix
individual x : Bool
#gen_state
after_init { x := false }
action idle { pure () }
invariant [safe] x = false
#gen_spec
#model_check interpreted {} {}
namespace Config
def localSize : Nat := 2
end Config
open Config
local instance : Inhabited (Fin localSize) := ⟨⟨0, by decide⟩⟩
def importLookingString := "import NotAModule"
#model_check compiled {} {} (maxDepth := localSize)
end Prefix
''')
            captured = root / "Generated.lean"
            log = root / "generated.log"
            env.update(PATH=str(root) + os.pathsep + env["PATH"],
                       VEIL_TEST_SOURCE=str(captured), VEIL_TEST_LOG=str(log), VEIL_TEST_LEAN=lean)
            result = subprocess.run([lean, str(source)], env=env,
                                    capture_output=True, text=True, timeout=120)
            output = result.stdout + result.stderr
            self.assertIn("PrefixCheckExit:0", output + (log.read_text() if log.exists() else ""))
            self.assertIn("def localSize", captured.read_text())
            self.assertIn("local instance", captured.read_text())
            self.assertNotIn("No violation", log.read_text())


if __name__ == "__main__":
    unittest.main()
