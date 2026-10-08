import tempfile
import unittest
from pathlib import Path
from unittest import mock

from asc import screenshots
from .helpers import write_png

SMALL = {"iphone-6.5": {"01-entry.png": (4, 6), "02-history.png": (4, 6), "03-settings.png": (4, 6)},
         "iphone-duo-outer": {"01-entry.png": (4, 6), "02-history.png": (4, 6), "03-settings.png": (4, 6)}}


class ValidationTests(unittest.TestCase):
    def setUp(self):
        self.root = Path(tempfile.mkdtemp())
        patcher = mock.patch.dict(screenshots.REQUIRED_SET, SMALL, clear=False)
        patcher.start()
        self.addCleanup(patcher.stop)

    def fill(self, device="iphone-6.5", names=("01-entry.png", "02-history.png", "03-settings.png"), size=(4, 6)):
        for i, n in enumerate(names):
            write_png(self.root / "de-DE" / device / n, size, seed=i)

    def test_exact_set_passes(self):
        self.fill()
        group = screenshots.scan_group(self.root, "de-DE", "iphone-6.5")
        self.assertTrue(group.valid, group.errors)
        self.assertEqual([f.file_name for f in group.files], ["01-entry.png", "02-history.png", "03-settings.png"])

    def test_missing_extra_size_alpha_are_reported(self):
        self.fill(names=("01-entry.png", "02-history.png"))
        write_png(self.root / "de-DE/iphone-6.5/09-extra.png", (4, 6))
        write_png(self.root / "de-DE/iphone-6.5/02-history.png", (5, 6))
        group = screenshots.scan_group(self.root, "de-DE", "iphone-6.5")
        text = " | ".join(group.errors)
        self.assertIn("missing file: 03-settings.png", text)
        self.assertIn("unexpected file: 09-extra.png", text)
        self.assertIn("02-history.png: 5x6 px, expected 4x6", text)
        write_png(self.root / "de-DE/iphone-6.5/01-entry.png", (4, 6), alpha=True)
        self.assertIn("transparency", " ".join(screenshots.scan_group(self.root, "de-DE", "iphone-6.5").errors))

    def test_more_than_ten_files_refused(self):
        self.fill()
        for i in range(10, 20):
            write_png(self.root / f"de-DE/iphone-6.5/{i}-x.png", (4, 6))
        self.assertTrue(any("store allows 10" in e for e in screenshots.scan_group(self.root, "de-DE", "iphone-6.5").errors))

    def test_duo_outer_rejects_landscape_files(self):
        self.fill(device="iphone-duo-outer")
        write_png(self.root / "de-DE/iphone-duo-outer/04-entry-landscape.png", (6, 4))
        errors = screenshots.scan_group(self.root, "de-DE", "iphone-duo-outer").errors
        self.assertIn("unexpected file: 04-entry-landscape.png", errors)

    def test_missing_folder_and_unknown_locale_folder(self):
        self.assertIn("folder missing", screenshots.scan_group(self.root, "fr-FR", "iphone-6.5").errors[0])
        (self.root / "de").mkdir()
        self.assertEqual(screenshots.unknown_locale_folders(self.root), ["de"])


class RealLayoutTests(unittest.TestCase):
    def test_real_repository_layout_is_valid(self):
        groups = screenshots.scan_all()
        bad = [(g.locale, g.device, g.errors[:2]) for g in groups if not g.valid]
        self.assertEqual(bad, [])
        self.assertEqual(screenshots.unknown_locale_folders(), [])


if __name__ == "__main__":
    unittest.main()
