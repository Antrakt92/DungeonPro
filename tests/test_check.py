"""Exercise the verification runner syntax phase; other gates are mocked."""
import contextlib
import importlib.util
import io
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import unittest
from unittest import mock


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

    def finished(commands, jobs):
        raise SyntaxFinished()

    module.run = run
    module.run_lua_checks = finished
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
            # Membership, not order: these five gates are independent, so their
            # relative order is brittle to pin. The current sequence
            # (catalog, casefold, names, toc, version) is still the intentional
            # convention — cheapest static gates first, cross-file version sync
            # last — but only the set is load-bearing here.
            self.assertCountEqual(gates, [("scripts/catalog.py", "--check"), ("scripts/casefold.py", "--check"),
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
    # This module already pins the check.py python-gate membership (see above),
    # so it also owns the companion wiring pin: every tests/*.lua file must be
    # registered in scripts/check.py as an explicit run(lua, "tests/<name>")
    # call. Presence, not order, is asserted so that multi-invocation files
    # (large_dungeon_performance.lua, detail_visual.lua) satisfy the pin only
    # when each of their argument sets is present (pinned separately below).
    def test_every_lua_test_is_registered_as_a_runner_call(self):
        runner_source = RUNNER.read_text(encoding="utf-8")
        root = RUNNER.resolve().parents[1]
        missing = sorted(path.name for path in sorted((root / "tests").glob("*.lua"))
                         if f'run(lua, "tests/{path.name}"' not in runner_source)
        self.assertEqual(missing, [])

    def test_multi_invocation_argument_sets_are_pinned(self):
        runner_source = RUNNER.read_text(encoding="utf-8")
        for args in ('"missing"', '"items"', '"chain"'):
            self.assertIn(f'run(lua, "tests/large_dungeon_performance.lua", {args})', runner_source)
        self.assertIn('run(lua, "tests/detail_visual.lua", "check")', runner_source)
        self.assertIn('run(lua, "tests/detail_visual.lua", "overview:dm", "enUS", "", "", "", "155", "check")',
                      runner_source)
        self.assertIn('run(lua, "tests/detail_visual.lua", "overview:dm", "ruRU", "", "collapsed", "", "155", "check")',
                      runner_source)

    def test_tail_wires_are_present_in_check_runner(self):
        # scripts/check.py tail. The syntax-phase mock above raises
        # SyntaxFinished before the tail runs, so deleting any of these lines
        # passes every other test in this module: pin them here by source
        # presence. This test never executes the tail itself.
        runner_source = RUNNER.read_text(encoding="utf-8")
        self.assertIn('run(sys.executable, "-m", "unittest", "discover", "-s", "tests", "-p", "test_*.py", "-v")',
                      runner_source)
        self.assertIn('run(sys.executable, "scripts/package.py")', runner_source)
        self.assertIn('run("git", "diff", "--check")', runner_source)

    def test_registered_lua_runner_count_has_a_floor(self):
        # Live count on 2026-10-21 is 198 run(lua, ...) invocations (194 unique
        # files; large_dungeon_performance.lua and detail_visual.lua run three
        # times each). Growth is allowed; shrinkage fails. An intentional mass
        # removal must lower this floor deliberately, in the same change.
        runner_source = RUNNER.read_text(encoding="utf-8")
        self.assertGreaterEqual(runner_source.count("run(lua,"), 198)


class LuaRosterGateTests(unittest.TestCase):
    # scripts/check.py owns a runtime completeness gate (not just the source
    # pins above): every top-level tests/*.lua file must be registered in
    # lua_checks, unless documented in LUA_CHECK_FIXTURE_EXCEPTIONS. A new
    # test file without a runner call must fail check.py, not silently skip.
    def load_gate(self, root):
        spec = importlib.util.spec_from_file_location("check_roster_under_test", RUNNER)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        module.ROOT = root
        return module

    def test_forgotten_file_fails(self):
        with tempfile.TemporaryDirectory(prefix="quest roster forgotten ") as folder:
            root = Path(folder)
            (root / "tests").mkdir()
            (root / "tests" / "kept.lua").write_text("-- fixture\n", encoding="utf-8")
            (root / "tests" / "forgotten.lua").write_text("-- fixture\n", encoding="utf-8")
            module = self.load_gate(root)
            commands = [("lua", "tests/kept.lua")]
            with self.assertRaisesRegex(SystemExit, "forgotten.lua"):
                module.check_lua_roster_completeness(commands)

    def test_allow_listed_fixture_passes(self):
        with tempfile.TemporaryDirectory(prefix="quest roster allowlist ") as folder:
            root = Path(folder)
            (root / "tests").mkdir()
            (root / "tests" / "kept.lua").write_text("-- fixture\n", encoding="utf-8")
            (root / "tests" / "helper_fixture.lua").write_text("-- fixture\n", encoding="utf-8")
            module = self.load_gate(root)
            commands = [("lua", "tests/kept.lua")]
            self.assertIsNone(module.check_lua_roster_completeness(
                commands, exceptions=frozenset({"helper_fixture.lua"})))

    def test_real_tree_roster_is_complete(self):
        module = self.load_gate(RUNNER.parents[1])
        commands = []
        module.lua_checks("lua", lambda *args: commands.append(args))
        self.assertIsNone(module.check_lua_roster_completeness(commands))


class CollectedLuaRosterTests(unittest.TestCase):
    def test_collected_roster_keeps_every_file_and_exact_multi_invocation_arguments(self):
        module, _, _ = exercise(RUNNER.parents[1])
        commands = []
        lua = "C:/Lua tools/lua5.1.exe"
        module.lua_checks(lua, lambda *args: commands.append(args))
        self.assertGreaterEqual(len(commands), 198)
        self.assertTrue(all(command[0] == lua for command in commands))
        expected_files = {"tests/" + path.name for path in (RUNNER.parents[1] / "tests").glob("*.lua")}
        self.assertEqual({command[1] for command in commands}, expected_files)
        self.assertEqual(len(commands), len(set(commands)), "distinct invocations must not be lost or duplicated")
        for mode in ("missing", "items", "chain"):
            self.assertIn((lua, "tests/large_dungeon_performance.lua", mode), commands)
        self.assertIn((lua, "tests/detail_visual.lua", "check"), commands)
        self.assertIn((lua, "tests/detail_visual.lua", "overview:dm", "enUS", "", "", "", "155", "check"), commands)
        self.assertIn((lua, "tests/detail_visual.lua", "overview:dm", "ruRU", "", "collapsed", "", "155", "check"), commands)


class TocParityTests(unittest.TestCase):
    def fixture(self, root, toc_lines, tracked=(), untracked=()):
        subprocess.run(["git", "init", "-q"], cwd=root, check=True, capture_output=True)
        for name in tracked:
            path = root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("-- fixture\n", encoding="utf-8")
        subprocess.run(["git", "add", "-A"], cwd=root, check=True, capture_output=True)
        for name in untracked:
            path = root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("-- untracked fixture\n", encoding="utf-8")
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

    def test_database_file_missing_fails(self):
        with tempfile.TemporaryDirectory(prefix="quest toc database ") as folder:
            module = self.fixture(Path(folder), ["Core/A.lua"], ["Core/A.lua", "Database/Catalog.lua"])
            with self.assertRaisesRegex(SystemExit, "Database/Catalog.lua"):
                module.main()

    def test_locales_file_missing_fails(self):
        with tempfile.TemporaryDirectory(prefix="quest toc locales ") as folder:
            module = self.fixture(Path(folder), ["Core/A.lua"], ["Core/A.lua", "Locales/Strings.lua"])
            with self.assertRaisesRegex(SystemExit, "Locales/Strings.lua"):
                module.main()

    def test_untracked_runtime_file_missing_fails(self):
        with tempfile.TemporaryDirectory(prefix="quest toc untracked ") as folder:
            module = self.fixture(Path(folder), ["Core/A.lua"], ["Core/A.lua"],
                                  untracked=["Database/Catalog.lua"])
            with self.assertRaisesRegex(SystemExit, "Database/Catalog.lua"):
                module.main()

    def test_untracked_files_outside_runtime_scope_are_ignored(self):
        # The untracked sweep is scoped to the runtime directories, so
        # unrelated WIP elsewhere never fails this gate.
        with tempfile.TemporaryDirectory(prefix="quest toc wip ") as folder:
            module = self.fixture(Path(folder), ["Core/A.lua"], ["Core/A.lua"],
                                  untracked=["notes/scratch.lua", "data/x.lua"])
            self.assertIsNone(module.main())

    def test_case_only_difference_still_matches(self):
        with tempfile.TemporaryDirectory(prefix="quest toc case ") as folder:
            module = self.fixture(Path(folder), ["core/a.lua"], ["Core/A.lua"])
            self.assertIsNone(module.main())

    def test_case_variant_duplicate_fails(self):
        with tempfile.TemporaryDirectory(prefix="quest toc casedup ") as folder:
            module = self.fixture(Path(folder), ["Core/A.lua", "core/a.lua"], ["Core/A.lua"])
            with self.assertRaisesRegex(SystemExit, "Duplicate"):
                module.main()

    def test_lowercase_dir_prefix_still_counts_as_runtime(self):
        # Case-fold gate: a runtime path with the wrong directory case
        # (core/x.lua) must still be treated as runtime and fail as missing
        # from the TOC. The membership sets are injected directly because a
        # case-insensitive Windows checkout cannot hold a real core/ sibling
        # of Core/ on disk; this simulates the git index of a case-sensitive
        # checkout carrying the wrong-case entry.
        with tempfile.TemporaryDirectory(prefix="quest toc dircase ") as folder:
            module = self.fixture(Path(folder), ["Core/A.lua"], ["Core/A.lua"])
            module._tracked = lambda root: {"Core/A.lua", "core/x.lua"}
            module._untracked = lambda root: set()
            with self.assertRaisesRegex(SystemExit, "core/x.lua"):
                module.main()

    # Load-order pin: Language must load before Window, and
    # QuestNavigation/QuestHistory/PreparationOverview must load before
    # Window, in the canonical UI sequence. Membership alone cannot catch a
    # reorder, so relative order among the present UI entries is asserted.
    # The check only constrains entries present in the TOC, so minimal
    # fixtures above keep passing.
    CANONICAL_UI = ["UI/TooltipLease.lua", "UI/Theme.lua", "UI/Language.lua",
                    "UI/QuestStatus.lua", "UI/QuestListRewards.lua", "UI/RewardCache.lua",
                    "UI/QuestNavigation.lua", "UI/QuestHistory.lua", "UI/DungeonMap.lua",
                    "UI/PreparationOverview.lua", "UI/Window.lua",
                    "UI/Navigation.lua", "UI/Minimap.lua"]

    def test_canonical_ui_order_passes(self):
        with tempfile.TemporaryDirectory(prefix="quest toc order ") as folder:
            module = self.fixture(Path(folder), list(self.CANONICAL_UI), self.CANONICAL_UI)
            self.assertIsNone(module.main())

    def test_window_above_quest_navigation_fails(self):
        with tempfile.TemporaryDirectory(prefix="quest toc reorder ") as folder:
            moved = list(self.CANONICAL_UI)
            moved.remove("UI/Window.lua")
            moved.insert(moved.index("UI/QuestNavigation.lua"), "UI/Window.lua")
            module = self.fixture(Path(folder), moved, moved)
            with self.assertRaisesRegex(SystemExit, "(?i)order"):
                module.main()

    def test_language_below_window_fails(self):
        with tempfile.TemporaryDirectory(prefix="quest toc langorder ") as folder:
            moved = list(self.CANONICAL_UI)
            moved.remove("UI/Language.lua")
            moved.insert(moved.index("UI/Window.lua") + 1, "UI/Language.lua")
            module = self.fixture(Path(folder), moved, moved)
            with self.assertRaisesRegex(SystemExit, "(?i)order"):
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

    def test_malformed_versions_fail_closed_in_each_source(self):
        for field in ("toc", "namespace", "changelog"):
            for bad in ("v0.3.0", "0.3", ""):
                with self.subTest(field=field, bad=bad), tempfile.TemporaryDirectory(
                        prefix="quest version malformed ") as folder:
                    module = self.fixture(Path(folder), **{field: bad})
                    with self.assertRaisesRegex(SystemExit, "not found"):
                        module.main()

    def test_missing_version_lines_fail_closed(self):
        with tempfile.TemporaryDirectory(prefix="quest version absent ") as folder:
            root = Path(folder)
            module = self.fixture(root)
            (root / "DungeonPro.toc").write_text("## Interface: 16001\nCore/Namespace.lua\n", encoding="utf-8")
            with self.assertRaisesRegex(SystemExit, "not found"):
                module.main()
        with tempfile.TemporaryDirectory(prefix="quest version absent ") as folder:
            root = Path(folder)
            module = self.fixture(root)
            (root / "Core" / "Namespace.lua").write_text("local name, addon = ...\n", encoding="utf-8")
            with self.assertRaisesRegex(SystemExit, "not found"):
                module.main()
        with tempfile.TemporaryDirectory(prefix="quest version absent ") as folder:
            root = Path(folder)
            module = self.fixture(root)
            (root / "CHANGELOG.md").write_text("# Changelog\n\nNo headings yet.\n", encoding="utf-8")
            with self.assertRaisesRegex(SystemExit, "not found"):
                module.main()

    def test_duplicate_toc_version_with_drift_fails(self):
        for extra in ("## Version: 9.9.9\n", "## Version: 0.3.0\n"):
            with self.subTest(extra=extra.strip()), tempfile.TemporaryDirectory(
                    prefix="quest version dup ") as folder:
                root = Path(folder)
                module = self.fixture(root)
                with (root / "DungeonPro.toc").open("a", encoding="utf-8") as handle:
                    handle.write(extra)
                with self.assertRaisesRegex(SystemExit, "[Aa]mbiguous"):
                    module.main()

    def test_duplicate_namespace_version_with_drift_fails(self):
        for extra in ('addon.version = "9.9.9"\n', 'addon.version = "0.3.0"\n'):
            with self.subTest(extra=extra.strip()), tempfile.TemporaryDirectory(
                    prefix="quest version dup ") as folder:
                root = Path(folder)
                module = self.fixture(root)
                with (root / "Core" / "Namespace.lua").open("a", encoding="utf-8") as handle:
                    handle.write(extra)
                with self.assertRaisesRegex(SystemExit, "[Aa]mbiguous"):
                    module.main()

    def test_changelog_history_below_top_heading_still_passes(self):
        # Older release headings are history, not ambiguity: only the top
        # heading drives the sync. TOC and Namespace.lua stay strict (above).
        with tempfile.TemporaryDirectory(prefix="quest version history ") as folder:
            root = Path(folder)
            module = self.fixture(root)
            with (root / "CHANGELOG.md").open("a", encoding="utf-8") as handle:
                handle.write("\n## 0.2.0 - 19-Oct-2026 — Fixture history\n")
            self.assertIsNone(module.main())

    def test_real_tree_versions_are_synchronized(self):
        spec = importlib.util.spec_from_file_location(
            "check_version_real_tree", RUNNER.parent / "check_version.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        self.assertIsNone(module.main())


LUA = shutil.which("lua5.1")


@unittest.skipUnless(LUA, "lua5.1 is required to drive the baseline shim")
class BaselineShimTests(unittest.TestCase):
    # tests/large_dungeon_performance.lua:3-28 replaces loadfile only when a
    # second (baseline) argument is present. The gate never passes one, so this
    # class drives both baseline shapes directly against minimal fixture trees:
    # a legacy tree where the artwork and diagnostics modules are absent (the
    # stub branches) and a current tree where they load from the baseline (the
    # redirect branches). Either tree would fail if the shim stopped working:
    # a missing passthrough file breaks originalLoad, and a legacy tree without
    # the legacy artwork APIs trips the DungeonArt stub assert.
    PASSTHROUGH = ("UI/Window.lua", "UI/RewardCache.lua", "Core/Client.lua",
                   "Core/DungeonStatus.lua", "Core/Events.lua", "Core/Namespace.lua")

    def _baseline(self, folder, legacy):
        repo = RUNNER.resolve().parents[1]
        base = Path(folder) / ("legacy" if legacy else "current")
        for name in self.PASSTHROUGH:
            target = base / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes((repo / name).read_bytes())
        if legacy:
            with (base / "Core/Client.lua").open("a", encoding="utf-8") as handle:
                handle.write('\nfunction addon.DungeonArt(d) return "legacy-art" end\n'
                             'function addon.PaintDungeonArt(texture, dungeon, mode, showOwned) return true end\n')
            with (base / "Core/Events.lua").open("r+", encoding="utf-8") as handle:
                original = handle.read()
                handle.seek(0)
                handle.write('local name0, addon0 = ...\naddon0.Diagnostics = addon0.Diagnostics or '
                             '{ Navigation = function() end, Minimap = function() end }\n' + original)
        else:
            for name in ("Core/DungeonArt.lua", "Core/Diagnostics.lua"):
                target = base / name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes((repo / name).read_bytes())
        return base

    def _run_baseline(self, base):
        repo = RUNNER.resolve().parents[1]
        proc = subprocess.run([LUA, "tests/large_dungeon_performance.lua", "missing", str(base)],
                              cwd=repo, capture_output=True, text=True, timeout=300)
        self.assertEqual(proc.returncode, 0, msg=(proc.stdout or "")[-2000:] + (proc.stderr or "")[-2000:])
        self.assertIn("Large dungeon workload: PASS", proc.stdout)

    def test_legacy_baseline_without_art_or_diagnostics_uses_stubs(self):
        with tempfile.TemporaryDirectory(prefix="quest baseline legacy ") as folder:
            self._run_baseline(self._baseline(folder, legacy=True))

    def test_current_baseline_loads_art_and_diagnostics_from_baseline(self):
        with tempfile.TemporaryDirectory(prefix="quest baseline current ") as folder:
            self._run_baseline(self._baseline(folder, legacy=False))


class SubprocessTimeoutTests(unittest.TestCase):
    # A hung tests/*.lua child must fail the gate instead of hanging it
    # forever. The timeout itself is never waited out here: subprocess.run is
    # mocked to raise TimeoutExpired immediately.
    def load(self, root):
        spec = importlib.util.spec_from_file_location("check_timeout_under_test", RUNNER)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        module.ROOT = root
        return module

    def test_execute_passes_bounded_timeout_to_subprocess(self):
        with tempfile.TemporaryDirectory(prefix="quest runner timeout kwarg ") as folder:
            module = self.load(Path(folder))
            seen = {}

            def fake_run(args, **kwargs):
                seen.update(kwargs)
                return subprocess.CompletedProcess(args, 0, b"ok")

            with mock.patch.object(module.subprocess, "run", side_effect=fake_run):
                module.execute(("lua", "tests/hung.lua"))
            self.assertEqual(seen.get("timeout"), module.COMMAND_TIMEOUT_SECONDS)

    def test_execute_timeout_fails_closed_naming_the_file(self):
        with tempfile.TemporaryDirectory(prefix="quest runner timeout ") as folder:
            module = self.load(Path(folder))
            args = ("lua", "tests/hung.lua")
            expired = subprocess.TimeoutExpired(args, module.COMMAND_TIMEOUT_SECONDS)
            started = time.monotonic()
            with mock.patch.object(module.subprocess, "run", side_effect=expired):
                with self.assertRaisesRegex(RuntimeError, "hung\\.lua"):
                    module.execute(args)
            self.assertLess(time.monotonic() - started, 30,
                            "mocked expiry must not wait out the real timeout")

    def test_run_lua_checks_timeout_fails_cleanly_without_hang(self):
        with tempfile.TemporaryDirectory(prefix="quest worker timeout ") as folder:
            module = self.load(Path(folder))
            args = ("lua", "tests/hung.lua")
            expired = subprocess.TimeoutExpired(list(args), module.COMMAND_TIMEOUT_SECONDS)
            output = io.StringIO()
            started = time.monotonic()
            with mock.patch.object(module.subprocess, "run", side_effect=expired), \
                    contextlib.redirect_stdout(output):
                with self.assertRaisesRegex(RuntimeError, "hung\\.lua"):
                    module.run_lua_checks([args], 1)
            self.assertLess(time.monotonic() - started, 30,
                            "mocked expiry must not wait out the real timeout")
            self.assertIn("hung.lua", output.getvalue())


if __name__ == "__main__":
    unittest.main(verbosity=2)
