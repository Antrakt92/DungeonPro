"""Exercise the verification runner syntax phase; other gates are mocked."""
import importlib.util
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


RUNNER = Path(__file__).resolve().parents[1] / "scripts" / "check.py"
COMPILER = shutil.which("luac5.1")


class SyntaxFinished(Exception):
    pass


def exercise(root):
    spec = importlib.util.spec_from_file_location("check_runner_under_test", RUNNER)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.ROOT = root
    calls = []

    def run(*args):
        if args[0] == COMPILER:
            assert args[1] == "-p" and 1 <= len(args[2:]) <= 32
            calls.append(tuple(args[2:]))
            subprocess.run(args, cwd=root, capture_output=True, text=True, check=True)
        elif args[1:] in (("scripts/catalog.py", "--check"), ("scripts/casefold.py", "--check"),
                          ("scripts/names.py", "--check"), ("scripts/check_toc.py",)):
            return
        else:
            raise SyntaxFinished()

    module.run = run
    return module, calls


class RunnerSyntaxBatchTests(unittest.TestCase):
    def fixture(self, root, bad=None):
        for index in range(53):
            text = "local x=1; error('Parsing must not execute Lua'); return x\n"
            if index == bad:
                text = "local invalid = )\n"
            (root / f"{index:02d} source with spaces.lua").write_text(text, encoding="utf-8")
        (root / "dist").mkdir()
        (root / "dist" / "excluded.lua").write_text("not syntax at all )", encoding="utf-8")
        return [str(path) for path in sorted(root.rglob("*.lua")) if "dist" not in path.parts]

    def test_valid_same53_inputs_parse_only_in_two_chunks_without_outputs(self):
        with tempfile.TemporaryDirectory(prefix="quest runner syntax ") as folder:
            root = Path(folder)
            expected = self.fixture(root)
            before = {path.relative_to(root): path.read_bytes() for path in root.rglob("*") if path.is_file()}
            module, calls = exercise(root)
            with self.assertRaises(SyntaxFinished):
                module.main()
            self.assertEqual([len(call) for call in calls], [32, 21])
            self.assertEqual([path for call in calls for path in call], expected)
            self.assertEqual(
                {path.relative_to(root): path.read_bytes() for path in root.rglob("*") if path.is_file()},
                before,
            )
            self.assertFalse((root / "luac.out").exists())

    def test_first_middle_and_later_chunk_failures_are_nonzero_and_name_first_bad_input(self):
        for bad in (0, 16, 40):
            with self.subTest(bad=bad), tempfile.TemporaryDirectory(prefix="quest runner syntax ") as folder:
                root = Path(folder)
                expected = self.fixture(root, bad)
                module, calls = exercise(root)
                with self.assertRaises(subprocess.CalledProcessError) as caught:
                    module.main()
                self.assertNotEqual(caught.exception.returncode, 0)
                self.assertIn(Path(expected[bad]).name, caught.exception.stderr)
                self.assertEqual(len(calls), 1 if bad < 32 else 2)
                self.assertFalse((root / "luac.out").exists())
                self.assertTrue(all(path in expected for call in calls for path in call))


if __name__ == "__main__":
    unittest.main(verbosity=2)
