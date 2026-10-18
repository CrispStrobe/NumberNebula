#!/usr/bin/env python3
"""Small build-wrapper regressions; no Flutter SDK or real build is used."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().with_name("build_web.sh")
COMMIT = "0123456789abcdef0123456789abcdef01234567"
PIN = "3.44.1"


class BuildWebTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="build-web-test-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        (self.root / ".flutter-version").write_text(PIN + "\n")
        self.output = self.root / "version-output.txt"
        self.output.write_text(json.dumps({"frameworkVersion": PIN}))
        self.log = self.root / "flutter-calls.jsonl"
        self.flutter = self.root / "fake-flutter"
        self.flutter.write_text(
            "#!/usr/bin/env python3\n"
            "import json, os, pathlib, sys\n"
            "if sys.argv[1:] == ['--version', '--machine']:\n"
            "    sys.stdout.write(pathlib.Path(os.environ['VERSION_OUTPUT']).read_text())\n"
            "    sys.exit(int(os.environ.get('VERSION_EXIT', '0')))\n"
            "with open(os.environ['FLUTTER_CALLS'], 'a') as output:\n"
            "    output.write(json.dumps(sys.argv[1:]) + '\\n')\n"
        )
        self.flutter.chmod(0o755)
        self.env = os.environ.copy()
        # Git must describe this fixture, independently of the caller's checkout.
        for key in list(self.env):
            if key.startswith("GIT_") or key == "SOURCE_COMMIT":
                self.env.pop(key)
        self.env.update(
            FLUTTER_BIN=str(self.flutter),
            VERSION_OUTPUT=str(self.output),
            FLUTTER_CALLS=str(self.log),
            SOURCE_COMMIT=COMMIT,
        )

    def run_wrapper(self, *arguments):
        return subprocess.run(
            ["bash", str(SCRIPT), *arguments],
            cwd=self.root,
            env=self.env,
            capture_output=True,
            text=True,
            timeout=10,
        )

    def calls(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []

    def assert_rejected(self):
        result = self.run_wrapper()
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.calls(), [], result.stdout + result.stderr)

    def test_clean_machine_json(self):
        result = self.run_wrapper()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls()[0], ["pub", "get"])
        self.assertIn("--dart-define=GIT_HASH=0123456", self.calls()[1])

    def test_bootstrap_prefix_and_arguments(self):
        self.output.write_text(
            "Downloading Dart SDK...\nBuilding flutter tool...\n"
            + json.dumps({"frameworkVersion": PIN})
            + "\n"
        )
        arguments = ["--source-maps", "--dart-define=LABEL=two words"]
        result = self.run_wrapper(*arguments)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            self.calls(),
            [
                ["pub", "get"],
                ["build", "web", "--wasm", "--release", "--dart-define=GIT_HASH=0123456", *arguments],
            ],
        )

    def test_sdk_mismatch(self):
        self.output.write_text(json.dumps({"frameworkVersion": "0.0.0"}))
        self.assert_rejected()

    def test_bad_machine_output(self):
        for output in [
            "bootstrap without JSON", "{broken", "{}", '{"frameworkVersion":3}',
            '{"frameworkVersion":""}',
            json.dumps({"frameworkVersion": PIN}) + " trailing error",
            json.dumps({"frameworkVersion": PIN}) + "\n{}",
        ]:
            with self.subTest(output=output):
                self.output.write_text(output)
                self.assert_rejected()

    def test_flutter_error_even_with_valid_json(self):
        self.env["VERSION_EXIT"] = "7"
        self.assert_rejected()

    def test_invalid_explicit_source_commit(self):
        for commit in ["", "0123456", "A" * 40, "g" * 40, COMMIT + "\n", "x; echo bad"]:
            with self.subTest(commit=commit):
                self.env["SOURCE_COMMIT"] = commit
                self.assert_rejected()

    def test_missing_git_source(self):
        self.env.pop("SOURCE_COMMIT")
        # An empty ceiling prevents discovery of any surrounding Git repository.
        self.env["GIT_CEILING_DIRECTORIES"] = str(self.root.parent)
        self.assert_rejected()

    def create_git_fixture(self):
        git_env = dict(self.env, GIT_AUTHOR_NAME="Build Wrapper Test",
                       GIT_AUTHOR_EMAIL="build-test@example.invalid",
                       GIT_COMMITTER_NAME="Build Wrapper Test",
                       GIT_COMMITTER_EMAIL="build-test@example.invalid")
        for arguments in [["init", "--quiet"], ["-c", "commit.gpgsign=false", "commit", "--quiet", "--allow-empty", "-m", "fixture"]]:
            subprocess.run(["git", *arguments], cwd=self.root, env=git_env,
                           capture_output=True, check=True, timeout=10)
        return subprocess.check_output(["git", "rev-parse", "--verify", "HEAD"],
                                       cwd=self.root, env=git_env, text=True).strip()

    @unittest.skipUnless(shutil.which("git"), "Git is needed for the fallback fixture")
    def test_real_git_source_fallback(self):
        self.env.pop("SOURCE_COMMIT")
        commit = self.create_git_fixture()
        result = self.run_wrapper()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("--dart-define=GIT_HASH=" + commit[:7], self.calls()[1])

    @unittest.skipUnless(shutil.which("git"), "Git is needed for the parent fixture")
    def test_archive_does_not_inherit_surrounding_git_source(self):
        self.create_git_fixture()
        archive_root = self.root / "archive"
        archive_root.mkdir()
        (archive_root / ".flutter-version").write_text(PIN + "\n")
        self.root = archive_root
        self.env.pop("SOURCE_COMMIT")
        self.assert_rejected()
        # An explicit, validated archive identity intentionally bypasses Git.
        self.env["SOURCE_COMMIT"] = COMMIT
        result = self.run_wrapper()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("--dart-define=GIT_HASH=0123456", self.calls()[1])


if __name__ == "__main__":
    unittest.main()
