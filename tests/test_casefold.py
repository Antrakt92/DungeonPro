import copy
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unicodedata
import unittest


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("casefold", ROOT / "scripts/casefold.py")
casefold = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(casefold)
LUA = shutil.which("lua5.1")


class CaseFoldTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = json.loads((ROOT / "data/search_casefold.json").read_text(encoding="utf-8"))

    def run_lua(self, source, payload=b""):
        self.assertIsNotNone(LUA, "Lua 5.1 is required; no automatic install is performed")
        setup = """
local addon={}
assert(loadfile('Core/Namespace.lua'))('DungeonPro',addon)
assert(loadfile('Database/SearchCaseFold.lua'))('DungeonPro',addon)
assert(loadfile('Core/Search.lua'))('DungeonPro',addon)
"""
        result = subprocess.run([LUA, "-e", setup + source], cwd=ROOT, input=payload,
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=60)
        self.assertEqual(result.returncode, 0, result.stderr.decode("utf-8", errors="replace"))
        return result.stdout

    def test_generator_is_deterministic_and_does_not_mutate_facts(self):
        original = copy.deepcopy(self.data)
        generated = casefold.generate(self.data)
        self.assertEqual(self.data, original)
        reversed_data = copy.deepcopy(self.data)
        reversed_data["mappings"] = dict(reversed(list(self.data["mappings"].items())))
        self.assertEqual(generated.encode("utf-8"), casefold.generate(reversed_data).encode("utf-8"))
        self.assertEqual(generated, (ROOT / "Database/SearchCaseFold.lua").read_text(encoding="utf-8"))
        self.assertIn("UNICODE LICENSE V3", generated)
        self.assertIn(self.data["source"], generated)
        result = subprocess.run([sys.executable, "scripts/casefold.py", "--check"], cwd=ROOT,
                                capture_output=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stderr.decode(errors="replace"))

    def test_check_with_missing_output_fails_closed_without_traceback(self):
        # Missing Database/SearchCaseFold.lua must fail as a clean SystemExit
        # ("Generated case-fold table differs"), never a FileNotFoundError
        # traceback. Mirrors catalog.py/names.py exists-guarded --check.
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            for directory in ("scripts", "data", "Database"):
                (root / directory).mkdir()
            shutil.copy2(ROOT / "scripts/casefold.py", root / "scripts/casefold.py")
            shutil.copy2(ROOT / "data/search_casefold.json", root / "data/search_casefold.json")
            self.assertFalse((root / "Database/SearchCaseFold.lua").exists())
            result = subprocess.run([sys.executable, "scripts/casefold.py", "--check"], cwd=root,
                                    capture_output=True, timeout=30)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn(b"Generated case-fold table differs", result.stderr)
            self.assertNotIn(b"Traceback", result.stderr)

    def test_generate_creates_missing_database_directory(self):
        # Generate mode must create Database/ when absent, mirroring
        # catalog.py target.parent.mkdir(exist_ok=True).
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            for directory in ("scripts", "data"):
                (root / directory).mkdir()
            shutil.copy2(ROOT / "scripts/casefold.py", root / "scripts/casefold.py")
            shutil.copy2(ROOT / "data/search_casefold.json", root / "data/search_casefold.json")
            result = subprocess.run([sys.executable, "scripts/casefold.py"], cwd=root,
                                    capture_output=True, timeout=30)
            self.assertEqual(result.returncode, 0, result.stderr.decode(errors="replace"))
            self.assertEqual((root / "Database/SearchCaseFold.lua").read_text(encoding="utf-8"),
                             casefold.generate(self.data))

    def test_generator_rejects_invalid_sources_and_unsafe_license(self):
        for key, value in [("unicodeVersion", "15.0.0"), ("source", "https://example.org/CaseFolding.txt"),
                           ("license", None), ("license", "UNICODE LICENSE V3 Copyright ]] malicious")]:
            with self.subTest(key=key, value=value):
                data = copy.deepcopy(self.data)
                data[key] = value
                with self.assertRaises(ValueError):
                    casefold.generate(data)

    def test_generator_rejects_non_dict_documents_fail_closed(self):
        for hostile in ([], None, "x", 123):
            with self.subTest(hostile=repr(hostile)), self.assertRaises(ValueError):
                casefold.generate(hostile)
        self.assertIsInstance(casefold.generate(copy.deepcopy(self.data)), str)

    def test_cli_rejects_duplicate_root_and_mapping_keys_before_writing(self):
        data = copy.deepcopy(self.data)
        data["mappings"] = {"65": "a"}
        original = json.dumps(data)
        duplicates = [original.replace('"unicodeVersion": "16.0.0"',
                                       '"unicodeVersion": "16.0.0", "unicodeVersion": "16.0.0"'),
                      original.replace('"65": "a"', '"65": "z", "65": "a"'),
                      original.replace('"65": "a"', '"6\\u0035": "z", "65": "a"')]
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            for directory in ("scripts", "data", "Database"):
                (root / directory).mkdir()
            shutil.copy2(ROOT / "scripts/casefold.py", root / "scripts/casefold.py")
            source = root / "data/search_casefold.json"
            output = root / "Database/SearchCaseFold.lua"
            expected = casefold.generate(data).encode("utf-8")
            for index, content in enumerate(duplicates):
                for args in (["--check"], []):
                    with self.subTest(case=index, args=args):
                        self.assertNotEqual(content, original)
                        source.write_text(content, encoding="utf-8")
                        output.write_bytes(expected)
                        result = subprocess.run([sys.executable, "scripts/casefold.py", *args], cwd=root,
                                                capture_output=True, timeout=30)
                        self.assertNotEqual(result.returncode, 0)
                        self.assertIn(b"Duplicate", result.stderr)
                        self.assertEqual(output.read_bytes(), expected)

    def test_generator_rejects_noncanonical_points_and_invalid_mapping_values(self):
        for mappings in [None, False, [], {}]:
            data = copy.deepcopy(self.data)
            data["mappings"] = mappings
            with self.subTest(mappings=mappings), self.assertRaises(ValueError):
                casefold.generate(data)
        for key in ["-1", "01", " 65", "65.0", "1114112", "55296", "56319", "６５", 65, True]:
            with self.subTest(key=key):
                data = copy.deepcopy(self.data)
                data["mappings"] = {key: "a"}
                with self.assertRaises(ValueError):
                    casefold.generate(data)
        for value in [None, False, 1, [], "", "A", "abcd", "\ud800"]:
            with self.subTest(value=repr(value)):
                data = copy.deepcopy(self.data)
                data["mappings"] = {"65": value}
                with self.assertRaises(ValueError):
                    casefold.generate(data)

    def test_lua_generation_escapes_quotes_slashes_nul_and_non_ascii(self):
        data = copy.deepcopy(self.data)
        data["mappings"] = {"65": '\x00"\\', "66": "é", "67": "𐐨"}
        # Execute only the generated source, not an on-disk replacement of the table.
        generated = casefold.generate(data)
        code = "local function generated(...)\n" + generated + "\nend\ngenerated('DungeonPro',addon)\n"
        code += "assert(addon.searchCaseFold[65]==string.char(0,34,92))\n"
        code += "assert(addon.searchCaseFold[66]==string.char(195,169))\n"
        code += "assert(addon.searchCaseFold[67]==string.char(240,144,144,168))\n"
        self.run_lua(code)

    @unittest.skipUnless(unicodedata.unidata_version == "16.0.0", "independent Python Unicode16 oracle unavailable")
    def test_all_default_mappings_match_independent_python_unicode16(self):
        expected = {}
        for point in range(0x110000):
            if 0xD800 <= point <= 0xDFFF:
                continue
            value = chr(point)
            if value.casefold() != value:
                expected[str(point)] = value.casefold()
        self.assertEqual(self.data["mappings"], expected)

    def test_every_unicode_scalar_round_trips_through_lua_utf8_and_is_idempotent(self):
        mappings = self.data["mappings"]
        records = bytearray()
        source, expected, chunks, scalars = [], [], 0, 0

        def flush():
            nonlocal chunks
            raw, folded = "".join(source).encode("utf-8"), "".join(expected).encode("utf-8")
            self.assertLessEqual(len(raw), 16384)
            self.assertLessEqual(len(folded), 16384)
            # Hex framing avoids Windows Lua's text-mode stdin CRLF/EOF translation.
            records.extend(raw.hex().encode("ascii"))
            records.extend(b"\t")
            records.extend(folded.hex().encode("ascii"))
            records.extend(b"\n")
            source.clear()
            expected.clear()
            chunks += 1

        for point in range(0x110000):
            if 0xD800 <= point <= 0xDFFF:
                continue
            source.append(chr(point))
            expected.append(mappings.get(str(point), chr(point)))
            scalars += 1
            if len(source) == 2000:
                flush()
        if source:
            flush()
        result = self.run_lua("""
local bytes = {}
for value = 0, 255 do bytes[string.format('%02x',value)] = string.char(value) end
local function decode(hex)
    return (hex:gsub('..',bytes))
end
local count=0
for record in io.lines() do
    local left,right=record:match('^([%da-f]+)\t([%da-f]+)$')
    assert(left and right)
    local input,expected=decode(left),decode(right)
    local actual=addon.SearchFold(input)
    assert(actual==expected,'Unicode scalar decoding/folding chunk '..(count+1))
    assert(addon.SearchFold(actual)==actual,'Idempotence chunk '..(count+1))
    count=count+1
end
print(count)
""", bytes(records))
        self.assertEqual(int(result.strip()), chunks)
        self.assertEqual(scalars, 0x110000 - 2048)

    def test_invalid_utf8_and_input_output_boundaries_fail_without_partial_keys(self):
        self.run_lua("""
for byte=128,255 do assert(addon.SearchFold(string.char(byte))==nil) end
for _,value in ipairs({string.char(192,128),string.char(224,159,191),string.char(237,160,128),
    string.char(240,143,191,191),string.char(244,144,128,128),string.char(226,65,172)}) do
    assert(addon.SearchFold(value)==nil)
end
assert(addon.SearchFold(string.rep('A',16384))==string.rep('a',16384))
assert(addon.SearchFold(string.rep('A',16385))==nil)
local expanding=string.char(196,176)
local safe=addon.SearchFold(string.rep(expanding,4096))
assert(#safe==12288 and addon.SearchFold(safe)==safe)
assert(addon.SearchFold(string.rep(expanding,8192))==nil,'output budget must reject the whole key')
assert(addon.SearchFold('')=='')
""")

    def test_cjk_accents_default_turkic_and_normalization_boundaries(self):
        pairs = [("死亡礦坑", "死亡礦坑"), ("죽음의 폐광", "죽음의 폐광"), ("ÉCOLE", "école"),
                 ("Straße", "strasse"), ("I", "i"), ("İ", "i\u0307"), ("é", "é"), ("e\u0301", "e\u0301")]
        def escaped(text):
            return '"' + "".join(f"\\{byte:03d}" for byte in text.encode("utf-8")) + '"'
        self.run_lua("\n".join(f"assert(addon.SearchFold({escaped(left)})=={escaped(right)})" for left, right in pairs))
        self.assertNotEqual(pairs[-2][1], pairs[-1][1], "no accent stripping or normalization promise")


    def test_cli_rejects_missing_and_corrupt_input_without_traceback(self):
        # Missing/corrupt data/search_casefold.json must fail as a clean
        # SystemExit naming the input, never an OSError/UnicodeDecodeError/
        # JSONDecodeError traceback. Mirrors check_version.py _read.
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            for directory in ("scripts", "data", "Database"):
                (root / directory).mkdir()
            shutil.copy2(ROOT / "scripts/casefold.py", root / "scripts/casefold.py")
            shutil.copy2(ROOT / "data/search_casefold.json", root / "data/search_casefold.json")
            shutil.copy2(ROOT / "Database/SearchCaseFold.lua", root / "Database/SearchCaseFold.lua")
            source = root / "data/search_casefold.json"
            output = root / "Database/SearchCaseFold.lua"
            expected = output.read_bytes()
            for content in ("{", "not json at all", '{"mappings": {"65": "a",}}'):
                for args in ([], ["--check"]):
                    with self.subTest(content=content[:12], args=args):
                        source.write_text(content, encoding="utf-8")
                        output.write_bytes(expected)
                        result = subprocess.run([sys.executable, "scripts/casefold.py", *args],
                                                cwd=root, capture_output=True, timeout=30)
                        self.assertNotEqual(result.returncode, 0)
                        self.assertNotIn(b"Traceback", result.stderr)
                        self.assertIn(b"search_casefold.json", result.stderr)
                        self.assertEqual(output.read_bytes(), expected)
            with self.subTest(content="undecodable bytes"):
                source.write_bytes(b"\xff\xfe invalid \x00 bytes")
                result = subprocess.run([sys.executable, "scripts/casefold.py"],
                                        cwd=root, capture_output=True, timeout=30)
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn(b"Traceback", result.stderr)
                self.assertIn(b"search_casefold.json", result.stderr)
                self.assertEqual(output.read_bytes(), expected)
            source.unlink()
            for args in ([], ["--check"]):
                with self.subTest(missing=True, args=args):
                    output.write_bytes(expected)
                    result = subprocess.run([sys.executable, "scripts/casefold.py", *args],
                                            cwd=root, capture_output=True, timeout=30)
                    self.assertNotEqual(result.returncode, 0)
                    self.assertNotIn(b"Traceback", result.stderr)
                    self.assertIn(b"search_casefold.json", result.stderr)
                    self.assertEqual(output.read_bytes(), expected)

    def test_deeply_nested_json_fails_as_system_exit_without_traceback(self):
        # 20k-nested JSON input must fail as a clean SystemExit naming the
        # input file: RecursionError is a RuntimeError, not a ValueError, so
        # _load must map it explicitly. Never a bare traceback, and never
        # touch the output.
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            for directory in ("scripts", "data", "Database"):
                (root / directory).mkdir()
            shutil.copy2(ROOT / "scripts/casefold.py", root / "scripts/casefold.py")
            source = root / "data/search_casefold.json"
            output = root / "Database/SearchCaseFold.lua"
            expected = casefold.generate({**copy.deepcopy(self.data), "mappings": {"65": "a"}}).encode("utf-8")
            for payload in ("[" * 20000 + "]" * 20000, '{"x":' * 20000):
                with self.subTest(payload=payload[:5]):
                    source.write_text(payload, encoding="utf-8")
                    with self.assertRaisesRegex(SystemExit, "search_casefold.json is invalid"):
                        casefold._load("data/search_casefold.json", source)
                    for args in (["--check"], []):
                        output.write_bytes(expected)
                        result = subprocess.run([sys.executable, "scripts/casefold.py", *args],
                                                cwd=root, capture_output=True, timeout=30)
                        self.assertNotEqual(result.returncode, 0)
                        self.assertNotIn(b"Traceback", result.stderr)
                        self.assertIn(b"search_casefold.json is invalid", result.stderr)
                        self.assertEqual(output.read_bytes(), expected)

    def test_check_with_unreadable_output_fails_closed_without_traceback(self):
        # An unreadable/undecodable Database/SearchCaseFold.lua in --check
        # mode must fail as a clean SystemExit ("Generated case-fold table
        # differs"), never a raw OSError/UnicodeDecodeError traceback (no
        # exists()/read TOCTOU).
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            for directory in ("scripts", "data", "Database"):
                (root / directory).mkdir()
            shutil.copy2(ROOT / "scripts/casefold.py", root / "scripts/casefold.py")
            shutil.copy2(ROOT / "data/search_casefold.json", root / "data/search_casefold.json")
            output = root / "Database/SearchCaseFold.lua"
            output.write_bytes(b"\xff\xfe invalid \x00 bytes")
            result = subprocess.run([sys.executable, "scripts/casefold.py", "--check"],
                                    cwd=root, capture_output=True, timeout=30)
            self.assertNotEqual(result.returncode, 0)
            self.assertNotIn(b"Traceback", result.stderr)
            self.assertIn(b"Generated case-fold table differs", result.stderr)
            self.assertEqual(output.read_bytes(), b"\xff\xfe invalid \x00 bytes")


if __name__ == "__main__":
    unittest.main()
