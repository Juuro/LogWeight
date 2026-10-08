import tempfile
import unittest
from pathlib import Path

from asc import screenshots
from asc.plan import Plan
from .fake_api import FakeApi
from .helpers import write_png


def local_files(root: Path, count=3, size=(4, 6)):
    files = []
    for i, name in enumerate(["01-entry.png", "02-history.png", "03-settings.png"][:count]):
        path = write_png(root / name, size, seed=i)
        files.append(screenshots.LocalScreenshot(path, name, screenshots.md5_of(path), path.stat().st_size, size))
    return files


class SyncTests(unittest.TestCase):
    def setUp(self):
        self.root = Path(tempfile.mkdtemp())
        self.api = FakeApi()
        self.api.add_version(locales=("de-DE",))
        self.loc = self.api.loc_id("de-DE")
        self.files = local_files(self.root)
        self.group = screenshots.ScreenshotGroup("de-DE", "iphone-6.5", "APP_IPHONE_65", self.files)

    def plan(self):
        return Plan(screenshots.plan_group(self.api, self.group, self.loc, sleep=lambda s: None))

    def kinds(self, plan):
        return sorted(a.kind for a in plan.actions)

    def remote_names(self, set_id):
        return [self.api.shots[i]["fileName"] for i in self.api.sets[set_id]["shots"]]

    def test_empty_store_uploads_everything_in_order(self):
        plan = self.plan()
        self.assertEqual(self.kinds(plan), ["reorder", "upload", "upload", "upload"])
        self.assertEqual(self.api.writes, [])  # planning is read-only
        self.assertTrue(plan.execute())
        set_id = next(iter(self.api.sets))
        self.assertEqual(self.remote_names(set_id), ["01-entry.png", "02-history.png", "03-settings.png"])
        self.assertEqual(len(self.api.uploaded_parts), 3)
        self.assertEqual({s["sourceFileChecksum"] for s in self.api.shots.values()}, {f.md5 for f in self.files})

    def test_second_run_with_no_changes_writes_nothing(self):
        self.plan().execute()
        self.api.writes.clear()
        plan = self.plan()
        self.assertEqual(self.kinds(plan), ["skip_unchanged"] * 3)
        plan.execute()
        self.assertEqual(self.api.writes, [])

    def test_one_changed_file_is_replaced_in_its_position(self):
        self.plan().execute()
        write_png(self.files[1].path, (4, 6), seed=99)
        self.files[1] = screenshots.LocalScreenshot(self.files[1].path, "02-history.png",
                                                    screenshots.md5_of(self.files[1].path), 1, (4, 6))
        self.group.files = self.files
        self.api.writes.clear()
        plan = self.plan()
        self.assertEqual(self.kinds(plan), ["reorder", "replace", "skip_unchanged", "skip_unchanged"])
        plan.execute()
        set_id = next(iter(self.api.sets))
        self.assertEqual(self.remote_names(set_id), ["01-entry.png", "02-history.png", "03-settings.png"])
        self.assertEqual(len(self.api.uploaded_parts), 4)  # 3 initial + 1 replacement

    def test_removed_local_file_deletes_remote(self):
        self.plan().execute()
        self.group.files = self.files[:2]
        plan = self.plan()
        self.assertIn("delete", self.kinds(plan))
        plan.execute()
        self.assertEqual(self.remote_names(next(iter(self.api.sets))), ["01-entry.png", "02-history.png"])

    def test_renamed_file_with_same_content_is_not_uploaded_again(self):
        self.plan().execute()
        set_id = next(iter(self.api.sets))
        first = self.api.sets[set_id]["shots"][0]
        self.api.shots[first]["fileName"] = "old-name.png"
        self.api.writes.clear()
        plan = self.plan()
        self.assertNotIn("upload", self.kinds(plan))
        self.assertNotIn("replace", self.kinds(plan))

    def test_wrong_remote_order_is_fixed_with_a_single_patch(self):
        self.plan().execute()
        set_id = next(iter(self.api.sets))
        self.api.sets[set_id]["shots"].reverse()
        self.api.writes.clear()
        plan = self.plan()
        self.assertEqual(self.kinds(plan), ["reorder", "skip_unchanged", "skip_unchanged", "skip_unchanged"])
        plan.execute()
        self.assertEqual(self.remote_names(set_id), ["01-entry.png", "02-history.png", "03-settings.png"])
        self.assertEqual(sum(1 for m, p in self.api.writes if p.endswith("/relationships/appScreenshots")), 1)

    def test_failed_remote_reservation_is_redone(self):
        self.plan().execute()
        set_id = next(iter(self.api.sets))
        self.api.shots[self.api.sets[set_id]["shots"][0]]["state"] = "FAILED"
        plan = self.plan()
        self.assertIn("replace", self.kinds(plan))
        plan.execute()
        self.assertEqual(self.remote_names(set_id), ["01-entry.png", "02-history.png", "03-settings.png"])

    def test_processing_failure_cleans_up_and_reports(self):
        self.api.fail_processing = True
        plan = self.plan()
        self.assertFalse(plan.execute())
        self.assertEqual(self.api.shots, {})  # reservations deleted, nothing half-uploaded

    def test_diff_matching_is_pure(self):
        remote = [screenshots.RemoteScreenshot("r1", "01-entry.png", self.files[0].md5, "COMPLETE")]
        diff = screenshots.diff_group(self.files, remote)
        self.assertEqual(diff.keep, ["01-entry.png"])
        self.assertEqual(diff.upload, ["02-history.png", "03-settings.png"])


if __name__ == "__main__":
    unittest.main()
