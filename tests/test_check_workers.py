"""Subprocess isolation and bounded scheduling, using tiny real Python children."""
import contextlib
from concurrent.futures import ThreadPoolExecutor
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import time
import unittest
from unittest import mock

RUNNER = Path(__file__).resolve().parents[1] / "scripts/check.py"


def runner(root):
    spec = importlib.util.spec_from_file_location("isolated_worker_runner", RUNNER)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.ROOT = root
    return module


def until(predicate, seconds=10):
    deadline = time.monotonic() + seconds
    while not predicate():
        if time.monotonic() >= deadline:
            raise AssertionError("child synchronization did not complete")
        time.sleep(.01)


BLOCKING_CHILD = r"""
from pathlib import Path
import sys,time
root=Path(sys.argv[1]); identity=sys.argv[2]
(root/('start-'+identity)).write_text(str(time.monotonic()),encoding='utf-8')
deadline=time.monotonic()+12
while not (root/'release').exists():
    if time.monotonic()>deadline:raise SystemExit('release marker missing')
    time.sleep(.01)
(root/('done-'+identity)).write_text(str(time.monotonic()),encoding='utf-8')
print('complete '+identity)
"""


class IsolatedWorkerTests(unittest.TestCase):
    def test_real_children_overlap_only_within_worker_bound_and_all_finish(self):
        for jobs in (2, 4):
            with self.subTest(jobs=jobs), tempfile.TemporaryDirectory(prefix="quest worker overlap ") as folder:
                root = Path(folder)
                module = runner(root)
                commands = [(sys.executable, "-c", BLOCKING_CHILD, str(root), str(i)) for i in range(jobs + 2)]
                output = io.StringIO()
                with contextlib.redirect_stdout(output), ThreadPoolExecutor(max_workers=1) as caller:
                    task = caller.submit(module.run_lua_checks, commands, jobs)
                    try:
                        until(lambda: len(list(root.glob("start-*"))) == jobs)
                        self.assertFalse(task.done(), "active children must be joined")
                        self.assertEqual(len(list(root.glob("start-*"))), jobs, "later commands cannot start before a worker is free")
                    finally:
                        (root / "release").touch()
                    task.result(timeout=15)
                self.assertEqual(len(list(root.glob("done-*"))), len(commands))
                intervals = [(float((root / ("start-" + str(i))).read_text()),
                              float((root / ("done-" + str(i))).read_text())) for i in range(len(commands))]
                events = sorted([(start, 1) for start, _ in intervals] + [(end, -1) for _, end in intervals])
                active = peak = 0
                for _, delta in events:
                    active += delta
                    peak = max(peak, active)
                self.assertEqual(active, 0)
                self.assertEqual(peak, jobs, "barrier proves overlap without asserting machine speed")
                for i in range(len(commands)):
                    self.assertIn("complete " + str(i), output.getvalue())

    def test_exact_argv_cwd_and_independent_process_globals_in_serial_and_parallel(self):
        with tempfile.TemporaryDirectory(prefix="quest argv spaces ") as folder:
            root = Path(folder)
            child = root / "child with spaces.py"
            child.write_text("import builtins,json,os,sys\n"
                             "assert not hasattr(builtins, 'fixture_owner')\n"
                             "builtins.fixture_owner=sys.argv[1]\n"
                             "print(json.dumps({'args':sys.argv[2:],'cwd':os.getcwd()},ensure_ascii=True))\n",
                             encoding="utf-8")
            args = ("", "two words", "кириллица 中文", 'quote\"inside', "", "last")
            for jobs in (1, 2):
                with self.subTest(jobs=jobs):
                    module = runner(root)
                    output = io.StringIO()
                    commands = [(sys.executable, str(child), str(i), *args) for i in range(3)]
                    with contextlib.redirect_stdout(output):
                        module.run_lua_checks(commands, jobs)
                    records = [json.loads(line) for line in output.getvalue().splitlines() if line.startswith('{"args":')]
                    self.assertEqual(len(records), 3)
                    self.assertTrue(all(record["args"] == list(args) for record in records))
                    self.assertTrue(all(Path(record["cwd"]).resolve() == root.resolve() for record in records))
                    self.assertEqual(len(module.TIMINGS), 3)
                    self.assertCountEqual([entry["argv"] for entry in module.TIMINGS], [list(command) for command in commands])

    def test_nonzero_child_printing_pass_fails_and_retains_stdout_and_stderr(self):
        with tempfile.TemporaryDirectory(prefix="quest failing child ") as folder:
            module = runner(Path(folder))
            output = io.StringIO()
            command = (sys.executable, "-c", "import sys;print('PASS marker');print('actual stderr',file=sys.stderr);sys.exit(7)")
            with contextlib.redirect_stdout(output), self.assertRaises(subprocess.CalledProcessError) as caught:
                module.run_lua_checks([command], 2)
            self.assertEqual(caught.exception.returncode, 7)
            self.assertEqual(tuple(caught.exception.cmd), command)
            self.assertIn("PASS marker", output.getvalue())
            self.assertIn("actual stderr", output.getvalue())
            self.assertEqual(module.TIMINGS[0]["returncode"], 7)

    def test_spawn_error_is_not_success_and_serial_queue_does_not_advance(self):
        with tempfile.TemporaryDirectory(prefix="quest spawn failure ") as folder:
            root = Path(folder)
            module = runner(root)
            next_marker = root / "must-not-start"
            commands = [(str(root / "absent executable.exe"),),
                        (sys.executable, "-c", "from pathlib import Path;import sys;Path(sys.argv[1]).touch()", str(next_marker))]
            with contextlib.redirect_stdout(io.StringIO()), self.assertRaises(OSError):
                module.run_lua_checks(commands, 1)
            self.assertFalse(next_marker.exists())

    def test_first_failure_stops_new_work_and_waits_for_already_running_peer(self):
        with tempfile.TemporaryDirectory(prefix="quest failure drain ") as folder:
            root = Path(folder)
            module = runner(root)
            fail = "from pathlib import Path;import sys,time;r=Path(sys.argv[1]);d=time.monotonic()+10\nwhile not (r/'start-peer').exists():\n if time.monotonic()>d:raise SystemExit(9)\n time.sleep(.01)\nprint('PASS but failed');sys.exit(7)"
            commands = [(sys.executable, "-c", fail, str(root)),
                        (sys.executable, "-c", BLOCKING_CHILD, str(root), "peer"),
                        (sys.executable, "-c", "from pathlib import Path;import sys;Path(sys.argv[1]).touch()", str(root / "must-not-start"))]
            output = io.StringIO()
            with contextlib.redirect_stdout(output), ThreadPoolExecutor(max_workers=1) as caller:
                task = caller.submit(module.run_lua_checks, commands, 2)
                try:
                    until(lambda: "exit 7" in output.getvalue())
                    self.assertFalse(task.done(), "failure must drain the owned active peer")
                    self.assertFalse((root / "must-not-start").exists())
                finally:
                    (root / "release").touch()
                with self.assertRaises(subprocess.CalledProcessError) as caught:
                    task.result(timeout=15)
            self.assertEqual(caught.exception.returncode, 7)
            self.assertTrue((root / "done-peer").exists())
            self.assertFalse((root / "must-not-start").exists())

    def test_keyboard_interrupt_drains_owned_children_without_starting_later_commands(self):
        with tempfile.TemporaryDirectory(prefix="quest interrupted workers ") as folder:
            root = Path(folder)
            module = runner(root)
            interrupted = threading.Event()
            commands = [(sys.executable, "-c", BLOCKING_CHILD, str(root), str(i)) for i in range(3)]
            def interrupt_wait(*args, **kwargs):
                until(lambda: len(list(root.glob("start-*"))) == 2)
                interrupted.set()
                raise KeyboardInterrupt()
            with mock.patch.object(module, "wait", side_effect=interrupt_wait), \
                    contextlib.redirect_stdout(io.StringIO()), ThreadPoolExecutor(max_workers=1) as caller:
                task = caller.submit(module.run_lua_checks, commands, 2)
                try:
                    until(interrupted.is_set)
                    self.assertFalse(task.done(), "interrupt must join already running children")
                    self.assertFalse((root / "start-2").exists())
                finally:
                    (root / "release").touch()
                with self.assertRaises(KeyboardInterrupt):
                    task.result(timeout=15)
            self.assertTrue((root / "done-0").exists())
            self.assertTrue((root / "done-1").exists())
            self.assertFalse((root / "start-2").exists())

    def test_invalid_worker_bounds_and_empty_roster_never_spawn(self):
        with tempfile.TemporaryDirectory(prefix="quest worker bounds ") as folder:
            module = runner(Path(folder))
            with mock.patch.object(module.subprocess, "run") as child:
                for jobs in (0, -1, 5):
                    with self.subTest(jobs=jobs), self.assertRaises(ValueError):
                        module.run_lua_checks([], jobs)
                module.run_lua_checks([], 2)
                child.assert_not_called()


class GateBarrierTests(unittest.TestCase):
    def test_lua_failure_prevents_python_package_diff_and_success_message(self):
        with tempfile.TemporaryDirectory(prefix="quest phase failure ") as folder:
            root = Path(folder)
            module = runner(root)
            phases = []
            failure = subprocess.CalledProcessError(11, ["lua", "failed.lua"])
            report = root / "timings.json"
            module.TIMINGS.append({"argv": ["old run"], "seconds": 99, "returncode": 0})
            def completed(*args):
                phases.append(args)
                module.TIMINGS.append({"argv": list(args), "seconds": .01, "returncode": 0})
            def failed_workers(commands, jobs):
                module.TIMINGS.append({"argv": ["lua", "failed.lua"], "seconds": .02, "returncode": 11})
                raise failure
            with mock.patch.object(module.shutil, "which", side_effect=lambda name: name), \
                    mock.patch.object(module, "run", side_effect=completed), \
                    mock.patch.object(module, "run_lua_checks", side_effect=failed_workers) as workers, \
                    contextlib.redirect_stdout(io.StringIO()) as output:
                with self.assertRaises(subprocess.CalledProcessError) as caught:
                    module.main(["--jobs", "3", "--timings", str(report)])
            self.assertIs(caught.exception, failure)
            self.assertEqual(workers.call_args.args[1], 3)
            self.assertFalse(any("unittest" in command or "scripts/package.py" in command or command[:1] == ("git",) for command in phases))
            self.assertNotIn("Local checks passed", output.getvalue())
            timing = json.loads(report.read_text(encoding="utf-8"))
            self.assertFalse(timing["passed"])
            self.assertEqual(timing["jobs"], 3)
            self.assertGreaterEqual(timing["lua_elapsed_seconds"], 0)
            self.assertEqual([entry["argv"] for entry in timing["commands"][:-1]], [list(args) for args in phases])
            self.assertEqual(timing["commands"][-1]["returncode"], 11)
            self.assertNotIn(["old run"], [entry["argv"] for entry in timing["commands"]])
            self.assertLess(len(timing["commands"]), len(workers.call_args.args[0]), "failure report records an incomplete run, not fabricated completions")

    def test_interrupted_gate_writes_failed_partial_timing_report(self):
        with tempfile.TemporaryDirectory(prefix="quest interrupted timing ") as folder:
            root = Path(folder)
            module = runner(root)
            report = root / "interrupted.json"
            def partial(options):
                module.TIMINGS.append({"argv": ["completed child", ""], "seconds": .01, "returncode": 0})
                options.lua_elapsed_seconds = .02
                raise KeyboardInterrupt()
            with mock.patch.object(module, "check", side_effect=partial), \
                    contextlib.redirect_stdout(io.StringIO()) as output, self.assertRaises(KeyboardInterrupt):
                module.main(["--timings", str(report)])
            timing = json.loads(report.read_text(encoding="utf-8"))
            self.assertFalse(timing["passed"])
            self.assertEqual(timing["commands"][0]["argv"], ["completed child", ""])
            self.assertEqual(timing["lua_elapsed_seconds"], .02)
            self.assertNotIn("Local checks passed", output.getvalue())

    def test_success_barrier_and_default_jobs_keep_every_tail_gate(self):
        with tempfile.TemporaryDirectory(prefix="quest phase success ") as folder:
            module = runner(Path(folder))
            events = []
            with mock.patch.object(module.os, "cpu_count", return_value=16), \
                    mock.patch.object(module.shutil, "which", side_effect=lambda name: name), \
                    mock.patch.object(module, "run", side_effect=lambda *args: events.append(args)), \
                    mock.patch.object(module, "run_lua_checks", side_effect=lambda commands, jobs: events.append(("LUA_BARRIER", jobs))), \
                    contextlib.redirect_stdout(io.StringIO()):
                module.main()
            barrier = events.index(("LUA_BARRIER", 4))
            self.assertEqual(events[barrier + 1:], [
                (sys.executable, "-m", "unittest", "discover", "-s", "tests", "-p", "test_*.py", "-v"),
                (sys.executable, "scripts/package.py"), ("git", "diff", "--check")])

    def test_cpu_aware_default_clamps_and_explicit_jobs_override(self):
        with tempfile.TemporaryDirectory(prefix="quest CPU default ") as folder:
            module = runner(Path(folder))
            for cpus, expected in ((None, 1), (1, 1), (2, 1), (3, 1), (4, 2), (6, 3), (8, 4), (16, 4)):
                with self.subTest(cpus=cpus), mock.patch.object(module.os, "cpu_count", return_value=cpus), \
                        mock.patch.object(module, "check") as checks:
                    module.main()
                    self.assertEqual(checks.call_count, 1)
                    self.assertEqual(checks.call_args.args[0].jobs, expected)
            for cpus in (None, 1, 16):
                for jobs in (1, 2, 3, 4):
                    with self.subTest(cpus=cpus, explicit=jobs), \
                            mock.patch.object(module.os, "cpu_count", return_value=cpus), \
                            mock.patch.object(module, "check") as checks:
                        module.main(["--jobs", str(jobs)])
                        self.assertEqual(checks.call_args.args[0].jobs, jobs)

    def test_cli_rejects_invalid_jobs_before_any_gate(self):
        with tempfile.TemporaryDirectory(prefix="quest invalid CLI ") as folder:
            module = runner(Path(folder))
            for value in ("0", "5", "-1", "two", "1.5"):
                with self.subTest(value=value), mock.patch.object(module, "check") as checks, \
                        contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as caught:
                    module.main(["--jobs", value])
                self.assertNotEqual(caught.exception.code, 0)
                checks.assert_not_called()


if __name__ == "__main__":
    unittest.main(verbosity=2)
