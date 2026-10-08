import tempfile
import unittest
from pathlib import Path
from unittest import mock

from asc import build, versions as ver
from asc.config import Credentials
from asc.errors import StoreError
from asc.plan import Plan
from .fake_api import FakeApi


def creds():
    return Credentials("KID", "ISS", Path("/dev/null"))


class BuildTests(unittest.TestCase):
    def setUp(self):
        self.api = FakeApi()
        self.vid = self.api.add_version("1.1.0")
        self.ctx = ver.Context(ver.StoreVersion(self.vid, "1.1.0", "PREPARE_FOR_SUBMISSION"))
        self.cmds = []

    def runner(self, cmd):
        self.cmds.append(cmd)

    def plan(self, **kw):
        return build.plan_build(self.api, "app1", self.ctx, "1.1.0", "22", creds(), self.runner, lambda s: None, **kw)

    def test_new_build_archives_uploads_waits_and_attaches(self):
        actions = self.plan()
        self.assertEqual([a.kind for a in actions], ["archive", "upload_build", "wait_processing", "attach_build"])
        self.assertEqual(self.cmds, [])  # preview runs nothing
        with mock.patch.object(build, "verify_archive"):
            for a in actions[:2]:
                a.run()
        self.assertEqual(self.cmds[0], ["xcodegen", "generate"])
        self.assertIn("archive", self.cmds[1])
        self.assertIn("-exportArchive", self.cmds[2])
        bid = self.api.add_build("22")  # the store finished processing
        for a in actions[2:]:
            a.run()
        self.assertEqual(self.api.attached[self.vid], bid)

    def test_valid_build_already_in_store_skips_archive_and_upload(self):
        bid = self.api.add_build("22")
        actions = self.plan()
        self.assertEqual([a.kind for a in actions], ["skip_unchanged", "attach_build"])
        for a in actions:
            if a.run:
                a.run()
        self.assertEqual(self.api.attached[self.vid], bid)
        self.assertEqual(self.cmds, [])

    def test_already_attached_build_means_nothing_to_do(self):
        bid = self.api.add_build("22")
        self.api.attached[self.vid] = bid
        actions = self.plan()
        self.assertTrue(all(a.kind == "skip_unchanged" for a in actions))

    def test_processing_build_is_waited_for_not_uploaded_again(self):
        self.api.add_build("22", state="PROCESSING")
        kinds = [a.kind for a in self.plan()]
        self.assertEqual(kinds, ["skip_unchanged", "wait_processing", "attach_build"])

    def test_unusable_build_number_stops_without_touching_project_files(self):
        self.api.add_build("22", state="INVALID")
        with self.assertRaises(StoreError) as ctx:
            self.plan()
        self.assertIn("versioning process", str(ctx.exception))
        self.assertEqual(self.api.writes, [])

    def test_build_number_used_by_other_version_stops(self):
        self.api.add_build("22", version="1.0.0")
        with self.assertRaises(StoreError):
            self.plan()

    def test_wait_is_bounded_and_reports_rejection(self):
        with self.assertRaises(StoreError):
            build.wait_for_build(self.api, "app1", "22", "1.1.0", sleep=lambda s: None, timeout=60, interval=30)
        self.api.add_build("22", state="FAILED")
        with self.assertRaises(StoreError) as ctx:
            build.wait_for_build(self.api, "app1", "22", "1.1.0", sleep=lambda s: None)
        self.assertIn("rejected", str(ctx.exception))

    def test_wait_ignores_builds_for_another_marketing_version(self):
        self.api.add_build("22", version="1.2.0")
        with self.assertRaises(StoreError) as ctx:
            build.wait_for_build(self.api, "app1", "22", "1.1.0", sleep=lambda s: None, timeout=30, interval=30)
        self.assertIn("still processing", str(ctx.exception))
        self.assertEqual(self.api.attached, {})

    def test_build_1_1_0_counts_for_store_version_1_1(self):
        self.api.add_build("22", version="1.1.0")
        found = build.wait_for_build(self.api, "app1", "22", "1.1", sleep=lambda s: None)
        self.assertEqual(found.state, "VALID")

    def test_verify_archive_requires_watch_app_and_extensions(self):
        root = Path(tempfile.mkdtemp()) / "A.xcarchive"
        app = root / "Products/Applications/LogWeight.app"
        app.mkdir(parents=True)
        with self.assertRaisesRegex(StoreError, "Watch"):
            build.verify_archive(root)
        (app / "Watch/LogWeightWatch.app").mkdir(parents=True)
        with self.assertRaisesRegex(StoreError, "extensions"):
            build.verify_archive(root)
        (app / "PlugIns/W.appex").mkdir(parents=True)
        build.verify_archive(root)

    def test_auth_flags_do_not_land_in_preview_output(self):
        plan = Plan(self.plan())
        text = plan.render()
        self.assertNotIn("KID", text)
        self.assertNotIn("ISS", text)


if __name__ == "__main__":
    unittest.main()
