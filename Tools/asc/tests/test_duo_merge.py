import tempfile
import unittest
from pathlib import Path
from unittest import mock

from asc import screenshots
from asc.plan import Plan
from .fake_api import FakeApi
from .helpers import write_png

OUTER = {"01-entry.png": (4, 6), "02-history.png": (4, 6)}
INNER = {"01-entry.png": (6, 8), "02-history.png": (6, 8), "04-entry-landscape.png": (8, 6)}


class DuoMergeTests(unittest.TestCase):
    def setUp(self):
        self.root = Path(tempfile.mkdtemp())
        p = mock.patch.dict(screenshots.REQUIRED_SET, {"iphone-duo-outer": OUTER, "iphone-duo-inner": INNER}, clear=False)
        p.start()
        self.addCleanup(p.stop)
        for i, (n, size) in enumerate(OUTER.items()):
            write_png(self.root / "de-DE/iphone-duo-outer" / n, size, seed=i)
        for i, (n, size) in enumerate(INNER.items()):
            write_png(self.root / "de-DE/iphone-duo-inner" / n, size, seed=10 + i)

    def merged(self):
        groups = screenshots.scan_all(self.root, ["de-DE"], ["iphone-duo-outer", "iphone-duo-inner"])
        return screenshots.merge_groups(groups)

    def test_outer_and_inner_become_one_set_with_unique_ordered_names(self):
        (group,) = self.merged()
        self.assertEqual(group.device, "iphone-duo")
        self.assertTrue(group.valid, group.errors)
        names = [f.file_name for f in sorted(group.files, key=lambda f: f.file_name)]
        self.assertEqual(names, ["1-outer-01-entry.png", "1-outer-02-history.png",
                                "2-inner-01-entry.png", "2-inner-02-history.png", "2-inner-04-entry-landscape.png"])

    def test_one_invalid_folder_refuses_the_whole_set(self):
        (self.root / "de-DE/iphone-duo-inner/04-entry-landscape.png").unlink()
        (group,) = self.merged()
        self.assertFalse(group.valid)

    def test_single_folder_alone_is_refused_not_half_synced(self):
        groups = screenshots.scan_all(self.root, ["de-DE"], ["iphone-duo-outer"])
        (group,) = screenshots.merge_groups(groups)
        self.assertFalse(group.valid)

    def test_sync_of_merged_set_is_stable_and_never_removes_the_other_display(self):
        api = FakeApi()
        api.add_version(locales=("de-DE",))
        loc = api.loc_id("de-DE")
        (group,) = self.merged()
        Plan(screenshots.plan_group(api, group, loc, sleep=lambda s: None)).execute()
        set_id = next(iter(api.sets))
        order = [api.shots[i]["fileName"] for i in api.sets[set_id]["shots"]]
        self.assertEqual(order, sorted(order))
        self.assertEqual(len(order), 5)
        api.writes.clear()
        plan = Plan(screenshots.plan_group(api, group, loc, sleep=lambda s: None))
        plan.execute()
        self.assertEqual(api.writes, [])


if __name__ == "__main__":
    unittest.main()
