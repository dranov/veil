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
/-- info: ✅ No violation (explored 1 states) -/
#guard_msgs in
#model_check interpreted {} {}
namespace Config
def localSize : Nat := 2
end Config
open Config
local instance : Inhabited (Fin localSize) := ⟨⟨0, by decide⟩⟩
def importLookingString := "import NotAModule"
#guard_msgs (drop error) in
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
            self.assertEqual(result.returncode, 0, output)
            self.assertTrue(log.exists(), output)
            self.assertEqual(log.read_text(), "")
            self.assertIn("def localSize", captured.read_text())
            self.assertIn("local instance", captured.read_text())
            self.assertNotIn("No violation", log.read_text())

    def test_native_result_is_complete_and_build_directory_is_released(self):
        lake = shutil.which("lake")
        with tempfile.TemporaryDirectory(prefix="veil-compiled-result-") as directory:
            root = Path(directory)
            env = json.loads(subprocess.check_output(
                [lake, "env", "python3", "-c", "import json, os; print(json.dumps(dict(os.environ)))"],
                text=True))
            lean = shutil.which("lean", path=env["PATH"])
            python = shutil.which("python3", path=env["PATH"])
            binary = ("#!" + python + "\nimport json, os, sys\n"
                      "from pathlib import Path\n"
                      "Path(os.environ['VEIL_TEST_ARGS']).write_text(json.dumps(sys.argv[1:]))\n"
                      "print(json.dumps({'result': 'no_violation_found', 'explored_states': 7, "
                      "'padding': 'x' * 70000}))\n")
            stub = root / "lake"
            stub.write_text("#!" + python + "\nimport os\nfrom pathlib import Path\n"
                            "Path(os.environ['VEIL_TEST_BUILD']).write_text(str(Path.cwd()))\n"
                            "p = Path('.lake/build/bin/ModelCheckerMain')\n"
                            "p.parent.mkdir(parents=True, exist_ok=True)\n"
                            "p.write_text(" + repr(binary) + ")\np.chmod(0o755)\n")
            stub.chmod(0o755)
            source = root / "NativeResult.lean"
            source.write_text("""import Veil
veil module NativeResult
individual x : Bool
#gen_state
after_init { x := false }
action idle { pure () }
invariant [safe] x = false
#gen_spec
#model_check compiled {} {}
end NativeResult
""")
            build_path = root / "build-path"
            args_path = root / "args.json"
            env.update(PATH=str(root) + os.pathsep + env["PATH"],
                       VEIL_TEST_BUILD=str(build_path), VEIL_TEST_ARGS=str(args_path))
            result = subprocess.run([lean, str(source)], env=env,
                                    capture_output=True, text=True, timeout=120)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("No violation (explored 7 states)", result.stdout)
            self.assertFalse(Path(build_path.read_text()).exists())
            args = json.loads(args_path.read_text())
            self.assertEqual(len(args), 3)
            self.assertEqual(args[2], "1")


if __name__ == "__main__":
    unittest.main()
