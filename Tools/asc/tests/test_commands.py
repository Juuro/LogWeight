"""Preview-by-default, exit codes, strict mode and secret hygiene at command level."""
import io
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from unittest import mock

from asc import commands, screenshots
from asc.config import Credentials
from asc.errors import EXIT_NOT_EDITABLE, EXIT_OK, EXIT_STORE, EXIT_VALIDATION
from .fake_api import FakeApi
from .helpers import write_png

SMALL = {"iphone-6.5": {"01-entry.png": (4, 6), "02-history.png": (4, 6), "03-settings.png": (4, 6)}}
SECRETS = ("KID-SECRET-1", "ISSUER-SECRET-2", "/secret/path/Key.p8")


class CommandTests(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        for n in ("project.yml", "Version.xcconfig"):
            pass
        (self.tmp / "project.yml").write_text('    MARKETING_VERSION: "1.1.0"\n')
        (self.tmp / "Version.xcconfig").write_text("CURRENT_PROJECT_VERSION = 22\n")
        self.shots = self.tmp / "shots"
        for i, n in enumerate(SMALL["iphone-6.5"]):
            write_png(self.shots / "de-DE/iphone-6.5" / n, (4, 6), seed=i)
        p = mock.patch.dict(screenshots.REQUIRED_SET, {"iphone-6.5": SMALL["iphone-6.5"]}, clear=False)
        p.start()
        self.addCleanup(p.stop)
        self.api = FakeApi()
        self.api.add_version("1.1.0", locales=("de-DE",))
        self.creds = Credentials(*SECRETS[:2], Path(SECRETS[2]))

    def opts(self, **kw):
        base = dict(screenshot_root=self.shots, project_yml=self.tmp / "project.yml",
                    xcconfig=self.tmp / "Version.xcconfig", locales=["de-DE"], device="iphone-6.5")
        base.update(kw)
        return commands.Options(**base)

    def run_cmd(self, command, **kw):
        buf = io.StringIO()
        with redirect_stdout(buf):
            code = commands.run(command, self.api, self.creds, self.opts(**kw), out=lambda t: print(t),
                                sleep=lambda s: None)
        return code, buf.getvalue()

    def test_preview_is_default_and_writes_nothing(self):
        code, out = self.run_cmd("screenshots")
        self.assertEqual(code, EXIT_OK)
        self.assertIn("PREVIEW", out)
        self.assertEqual(self.api.writes, [])

    def test_apply_runs_exactly_the_previewed_actions(self):
        _, preview = self.run_cmd("screenshots")
        planned = preview.count("[PLAN] upload")
        code, out = self.run_cmd("screenshots", apply=True)
        self.assertEqual(code, EXIT_OK)
        self.assertEqual(out.count("[DONE] upload"), planned)
        self.assertEqual(planned, 3)

    def test_second_apply_is_a_no_op(self):
        self.run_cmd("screenshots", apply=True)
        self.api.writes.clear()
        code, _ = self.run_cmd("screenshots", apply=True)
        self.assertEqual((code, self.api.writes), (EXIT_OK, []))

    def test_invalid_group_exit_3_but_strict_exit_2_without_writes(self):
        (self.shots / "de-DE/iphone-6.5/03-settings.png").unlink()
        code, out = self.run_cmd("screenshots", apply=True)
        self.assertEqual(code, EXIT_STORE)
        self.assertIn("missing file: 03-settings.png", out)
        self.api.writes.clear()
        code, out = self.run_cmd("screenshots", apply=True, strict=True)
        self.assertEqual(code, EXIT_VALIDATION)
        self.assertEqual(self.api.writes, [])

    def test_non_editable_version_exit_4_without_writes(self):
        self.api.versions[next(iter(self.api.versions))]["appStoreState"] = "READY_FOR_SALE"
        code, _ = self.run_cmd("screenshots", apply=True)
        self.assertEqual((code, self.api.writes), (EXIT_NOT_EDITABLE, []))

    def test_missing_version_is_created_first_when_applied(self):
        (self.tmp / "project.yml").write_text('    MARKETING_VERSION: "1.2.0"\n')
        code, out = self.run_cmd("screenshots")
        self.assertIn("create_version: 1.2.0", out)
        self.assertEqual(self.api.writes, [])
        self.assertEqual(code, EXIT_OK)

    def test_review_submission_is_never_called(self):
        self.run_cmd("screenshots", apply=True)
        self.run_cmd("texts", apply=True, locales=[])
        for _, path in self.api.writes:
            self.assertNotIn("reviewSubmission", path)
            self.assertNotIn("appStoreVersionSubmissions", path)

    def test_unknown_locale_folder_is_reported(self):
        (self.shots / "de").mkdir()
        code, out = self.run_cmd("screenshots")
        self.assertIn("unknown locale folder", out)
        self.assertEqual(code, EXIT_STORE)

    def test_stale_whats_new_text_is_refused_with_exit_2_and_no_writes(self):
        (self.tmp / "project.yml").write_text('    MARKETING_VERSION: "1.2.0"\n')
        self.api.add_version("1.2.0", locales=("de-DE",))
        code, out = self.run_cmd("texts", apply=True, locales=[])
        self.assertEqual(code, EXIT_VALIDATION)
        self.assertIn("rewrite the release notes", out)
        self.assertEqual(self.api.writes, [])

    def test_status_is_read_only_and_flags_problems(self):
        (self.shots / "de-DE/iphone-6.5/03-settings.png").unlink()
        code, out = self.run_cmd("status")
        self.assertEqual(code, EXIT_VALIDATION)
        self.assertIn("missing file", out)
        self.assertEqual(self.api.writes, [])

    def test_no_secret_value_appears_in_any_output(self):
        outputs = []
        for cmd, kw in (("status", {}), ("screenshots", {}), ("screenshots", {"apply": True}), ("texts", {"locales": []})):
            outputs.append(self.run_cmd(cmd, **kw)[1])
        text = "\n".join(outputs)
        for secret in SECRETS:
            self.assertNotIn(secret, text)


if __name__ == "__main__":
    unittest.main()
