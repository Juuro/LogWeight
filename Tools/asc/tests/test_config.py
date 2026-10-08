import tempfile
import unittest
from pathlib import Path

from asc import config
from asc.errors import ConfigError


class ConfigTests(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.key = self.tmp / "AuthKey.p8"
        self.key.write_text("SECRET-KEY-BODY")

    def env(self, **values):
        path = self.tmp / ".env"
        path.write_text("\n".join(f"{k}={v}" for k, v in values.items()))
        return path

    def test_missing_variable_names_the_variable_not_a_value(self):
        path = self.env(ASC_KEY_ID="KID123", ASC_KEY_PATH=str(self.key))
        with self.assertRaises(ConfigError) as ctx:
            config.load_credentials(path, environ={})
        message = str(ctx.exception)
        self.assertIn("ASC_ISSUER_ID", message)
        self.assertNotIn("KID123", message)

    def test_tilde_is_expanded_and_repr_is_redacted(self):
        home = self.tmp / "home"
        home.mkdir()
        (home / "k.p8").write_text("x")
        path = self.env(ASC_KEY_ID="KID123", ASC_ISSUER_ID="ISS456", ASC_KEY_PATH="~/k.p8")
        import os
        old = os.environ.get("HOME")
        os.environ["HOME"] = str(home)
        try:
            creds = config.load_credentials(path, environ={})
        finally:
            os.environ["HOME"] = old
        self.assertEqual(creds.key_path, home / "k.p8")
        self.assertNotIn("KID123", repr(creds))
        self.assertNotIn("ISS456", str(creds))

    def test_unreadable_key_does_not_leak_path(self):
        path = self.env(ASC_KEY_ID="a", ASC_ISSUER_ID="b", ASC_KEY_PATH=str(self.tmp / "nope.p8"))
        with self.assertRaises(ConfigError) as ctx:
            config.load_credentials(path, environ={})
        self.assertNotIn("nope.p8", str(ctx.exception))

    def test_environment_wins_over_file(self):
        path = self.env(ASC_KEY_ID="file", ASC_ISSUER_ID="file", ASC_KEY_PATH=str(self.key))
        creds = config.load_credentials(path, environ={"ASC_KEY_ID": "env"})
        self.assertEqual(creds.key_id, "env")

    def test_version_and_build_parsing(self):
        yml = self.tmp / "project.yml"
        yml.write_text('settings:\n  base:\n    MARKETING_VERSION: "1.2.3" # x-release-please-version\n')
        xc = self.tmp / "Version.xcconfig"
        xc.write_text("// c\nCURRENT_PROJECT_VERSION = 42\n")
        self.assertEqual(config.read_marketing_version(yml), "1.2.3")
        self.assertEqual(config.read_build_number(xc), "42")
        self.assertEqual(config.resolve_version(None, yml), "1.2.3")
        self.assertEqual(config.resolve_version("9.9", yml), "9.9")

    def test_real_marketing_version_parses(self):
        self.assertRegex(config.read_marketing_version(), r"^\d+\.\d+")

    def test_build_number_env_override_wins(self):
        import os
        from unittest import mock
        with mock.patch.dict(os.environ, {"BUILD_NUMBER": "4242"}):
            self.assertEqual(config.read_build_number(), "4242")

    def test_invalid_build_number_override_is_rejected(self):
        import os
        from unittest import mock
        with mock.patch.dict(os.environ, {"BUILD_NUMBER": "12x"}):
            with self.assertRaises(ConfigError):
                config.read_build_number()

    def test_build_number_from_git_history_when_available(self):
        import os
        import subprocess
        from unittest import mock
        shallow = subprocess.run(["git", "-C", str(config.ROOT), "rev-parse", "--is-shallow-repository"],
                                 capture_output=True, text=True).stdout.strip()
        if shallow != "false":
            self.skipTest("shallow or non-git checkout cannot count commits")
        env = {k: v for k, v in os.environ.items() if k != "BUILD_NUMBER"}
        with mock.patch.dict(os.environ, env, clear=True):
            self.assertTrue(config.read_build_number().isdigit())

    def test_shallow_checkout_is_a_clear_config_error(self):
        import os
        import shutil
        import subprocess
        from unittest import mock
        repo = self.tmp / "clone"
        (repo / "Tools").mkdir(parents=True)
        shutil.copy(config.ROOT / "Tools" / "build-number.sh", repo / "Tools" / "build-number.sh")
        # a plain directory without git at all behaves like a shallow clone: no countable history
        result = subprocess.run([str(repo / "Tools" / "build-number.sh")], capture_output=True, text=True,
                                env={k: v for k, v in os.environ.items() if k != "BUILD_NUMBER"})
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout.strip(), "")


if __name__ == "__main__":
    unittest.main()
