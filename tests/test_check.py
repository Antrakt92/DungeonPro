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
    gates = []

    def run(*args):
        if args[0] == COMPILER:
            assert args[1] == "-p" and 1 <= len(args[2:]) <= 32
            calls.append(tuple(args[2:]))
            subprocess.run(args, cwd=root, capture_output=True, text=True, check=True)
        elif args[1:] in (("scripts/catalog.py", "--check"), ("scripts/casefold.py", "--check"),
                          ("scripts/names.py", "--check"), ("scripts/check_toc.py",),
                          ("scripts/check_version.py",)):
            gates.append(tuple(args[1:]))
            return
        else:
            raise SyntaxFinished()

    module.run = run
    return module, calls, gates


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
            module, calls, gates = exercise(root)
            with self.assertRaises(SyntaxFinished):
                module.main()
            self.assertEqual(gates, [("scripts/catalog.py", "--check"), ("scripts/casefold.py", "--check"),
                                     ("scripts/names.py", "--check"), ("scripts/check_toc.py",),
                                     ("scripts/check_version.py",)])
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
                module, calls, gates = exercise(root)
                with self.assertRaises(subprocess.CalledProcessError) as caught:
                    module.main()
                self.assertNotEqual(caught.exception.returncode, 0)
                self.assertIn(Path(expected[bad]).name, caught.exception.stderr)
                self.assertEqual(len(calls), 1 if bad < 32 else 2)
                self.assertFalse((root / "luac.out").exists())
                self.assertTrue(all(path in expected for call in calls for path in call))


class RunnerGateWiringTests(unittest.TestCase):
    # This module already pins the check.py python-gate order (see above), so it
    # also owns the companion wiring pin: every tests/*.lua file must be
    # registered in scripts/check.py. Presence, not order, is asserted so that
    # multi-invocation files (large_dungeon_performance.lua, detail_visual.lua)
    # satisfy the pin with any one of their invocations.
    def test_every_lua_test_is_registered_in_check_runner(self):
        runner_source = RUNNER.read_text(encoding="utf-8")
        root = RUNNER.resolve().parents[1]
        missing = sorted(path.name for path in sorted((root / "tests").glob("*.lua"))
                         if f"tests/{path.name}" not in runner_source)
        self.assertEqual(missing, [])


class TocParityTests(unittest.TestCase):
    def fixture(self, root, toc_lines, tracked=()):
        subprocess.run(["git", "init", "-q"], cwd=root, check=True, capture_output=True)
        for name in tracked:
            path = root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("-- fixture\n", encoding="utf-8")
        subprocess.run(["git", "add", "-A"], cwd=root, check=True, capture_output=True)
        (root / "DungeonPro.toc").write_text(
            "## Interface: 16001\n## Title: DungeonPro\n## Version: 0.3.0\n"
            + "".join(line + "\n" for line in toc_lines),
            encoding="utf-8")
        spec = importlib.util.spec_from_file_location(
            "check_toc_under_test", RUNNER.parent / "check_toc.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        module.ROOT = root
        return module

    def test_matching_membership_passes(self):
        with tempfile.TemporaryDirectory(prefix="quest toc parity ") as folder:
            module = self.fixture(Path(folder), ["Core/A.lua"], ["Core/A.lua"])
            self.assertIsNone(module.main())

    def test_stale_toc_entry_fails(self):
        with tempfile.TemporaryDirectory(prefix="quest toc stale ") as folder:
            module = self.fixture(Path(folder), ["Core/A.lua", "Core/Gone.lua"], ["Core/A.lua"])
            with self.assertRaisesRegex(SystemExit, "no tracked file"):
                module.main()

    def test_duplicate_toc_entry_fails(self):
        with tempfile.TemporaryDirectory(prefix="quest toc duplicate ") as folder:
            module = self.fixture(Path(folder), ["Core/A.lua", "Core/A.lua"], ["Core/A.lua"])
            with self.assertRaisesRegex(SystemExit, "Duplicate"):
                module.main()

    def test_missing_runtime_file_fails(self):
        with tempfile.TemporaryDirectory(prefix="quest toc missing ") as folder:
            module = self.fixture(Path(folder), ["Core/A.lua"], ["Core/A.lua", "UI/B.lua"])
            with self.assertRaisesRegex(SystemExit, "missing"):
                module.main()


class VersionSyncTests(unittest.TestCase):
    def fixture(self, root, toc="0.3.0", namespace="0.3.0", changelog="0.3.0"):
        (root / "DungeonPro.toc").write_text(
            f"## Interface: 16001\n## Version: {toc}\nCore/Namespace.lua\n", encoding="utf-8")
        core = root / "Core"
        core.mkdir(exist_ok=True)
        (core / "Namespace.lua").write_text(
            f'local name, addon = ...\naddon.version = "{namespace}"\n', encoding="utf-8")
        (root / "CHANGELOG.md").write_text(
            f"# Changelog\n\n## {changelog} - 20-Oct-2026 — Fixture\n", encoding="utf-8")
        spec = importlib.util.spec_from_file_location(
            "check_version_under_test", RUNNER.parent / "check_version.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        module.ROOT = root
        return module

    def test_matching_versions_pass(self):
        with tempfile.TemporaryDirectory(prefix="quest version sync ") as folder:
            self.assertIsNone(self.fixture(Path(folder)).main())

    def test_each_source_can_report_drift(self):
        for field in ("toc", "namespace", "changelog"):
            with self.subTest(field=field), tempfile.TemporaryDirectory(prefix="quest version drift ") as folder:
                module = self.fixture(Path(folder), **{field: "9.9.9"})
                with self.assertRaisesRegex(SystemExit, "drift"):
                    module.main()

    def test_real_tree_versions_are_synchronized(self):
        spec = importlib.util.spec_from_file_location(
            "check_version_real_tree", RUNNER.parent / "check_version.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        self.assertIsNone(module.main())


if __name__ == "__main__":
    unittest.main(verbosity=2)
