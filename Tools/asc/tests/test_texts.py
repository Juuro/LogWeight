import unittest

from asc import texts, versions as ver
from asc.locales import STORE_LOCALES
from .fake_api import FakeApi


class ParseTests(unittest.TestCase):
    def test_real_documents_parse_for_all_locales_and_validate(self):
        loaded = texts.load_all()
        self.assertEqual(sorted(loaded), sorted(STORE_LOCALES))
        self.assertEqual(texts.validate(loaded), {})

    def test_english_base_applies_to_all_english_locales(self):
        loaded = texts.load_all()
        self.assertEqual(loaded["en-US"], loaded["en-GB"])
        self.assertEqual(loaded["en-US"], loaded["en-CA"])
        self.assertEqual(loaded["en-US"].subtitle, "Weight tracking quick and easy")

    def test_alias_and_bullet_indentation(self):
        loaded = texts.load_all()
        self.assertIn("it", loaded)
        self.assertNotIn("it-IT", loaded)
        self.assertNotIn("\n  •", loaded["de-DE"].description)
        self.assertTrue(loaded["de-DE"].description.startswith("LogWeight ist"))

    def test_limits_are_enforced(self):
        good = texts.load_all()["de-DE"]
        too_long = texts.TextSet("x" * 31, "y" * 171, "z" * 4001, "k" * 101)
        problems = texts.validate({"de-DE": too_long, "fr-FR": good}, ["de-DE", "fr-FR", "ja"])
        joined = " ".join(problems["de-DE"])
        for needle in ("subtitle has 31 characters (limit 30)", "promotionalText has 171", "description has 4001",
                       "keywords has 101"):
            self.assertIn(needle, joined)
        self.assertIn("ja", problems)  # no text defined

    def test_missing_field_is_an_error_not_an_empty_write(self):
        md = "## de-DE\n\n- **Subtitle:** `A`\n- **Promotional text:** `B`\n- **Keywords:** `k`\n"
        with self.assertRaises(Exception) as ctx:
            texts.parse_localized(md)
        self.assertIn("Description", str(ctx.exception))


class DiffTests(unittest.TestCase):
    def setUp(self):
        self.api = FakeApi()
        self.vid = self.api.add_version(locales=("de-DE",))
        self.local = texts.load_all()["de-DE"]
        self.version = ver.StoreVersion(self.vid, "1.1.0", "PREPARE_FOR_SUBMISSION")

    def plan(self):
        return ver.plan_texts(self.api, self.version, "app1", {"de-DE": self.local}, ["de-DE"])

    def sync_remote(self):
        loc = next(v for v in self.api.version_locs.values() if v["locale"] == "de-DE")
        loc.update(promotionalText=self.local.promotionalText, description=self.local.description + "  \n",
                   keywords=self.local.keywords)
        next(iter(self.api.info_locs.values()))["subtitle"] = self.local.subtitle

    def test_empty_store_updates_version_and_subtitle_targets(self):
        actions = self.plan()
        self.assertEqual(sorted(a.reason for a in actions), ["app info localization", "version localization"])
        for a in actions:
            a.run()
        paths = self.api.write_paths()
        self.assertTrue(any(p.startswith("/appInfoLocalizations/") for p in paths))
        self.assertTrue(any(p.startswith("/appStoreVersionLocalizations/") for p in paths))

    def test_identical_texts_are_skipped_even_with_trailing_whitespace(self):
        self.sync_remote()
        actions = self.plan()
        self.assertEqual([a.kind for a in actions], ["skip_unchanged"])
        self.assertEqual(self.api.writes, [])

    def test_one_changed_field_writes_only_that_field(self):
        self.sync_remote()
        next(iter(self.api.info_locs.values()))["subtitle"] = "Old subtitle"
        actions = self.plan()
        self.assertEqual([(a.kind, a.target) for a in actions], [("update_text", "subtitle")])
        actions[0].run()
        self.assertEqual(len(self.api.writes), 1)

    def test_locale_not_in_store_is_reported_not_created(self):
        actions = ver.plan_texts(self.api, self.version, "app1", {"fr-FR": self.local}, ["fr-FR"])
        self.assertIn("not enabled", actions[0].reason)
        self.assertEqual(self.api.writes, [])


if __name__ == "__main__":
    unittest.main()
