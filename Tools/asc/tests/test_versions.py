import unittest

from asc import versions as ver
from asc.errors import AscError, NotEditableError
from .fake_api import FakeApi


class VersionTests(unittest.TestCase):
    def test_existing_editable_version_is_found(self):
        api = FakeApi()
        api.add_version("1.1.0")
        ctx = ver.Context()
        actions = ver.plan_version(api, "app1", "1.1.0", ctx)
        self.assertEqual(actions, [])
        self.assertEqual(ctx.version.version_string, "1.1.0")

    def test_missing_version_is_planned_and_created_on_run(self):
        api = FakeApi()
        api.add_version("1.0", state="READY_FOR_SALE")
        ctx = ver.Context()
        actions = ver.plan_version(api, "app1", "1.1.0", ctx)
        self.assertEqual([a.kind for a in actions], ["create_version"])
        self.assertIn("store has: 1.0", actions[0].reason)
        self.assertEqual(api.writes, [])
        actions[0].run()
        self.assertEqual(ctx.version.state, "PREPARE_FOR_SUBMISSION")
        self.assertEqual(api.write_paths(), ["/appStoreVersions"])

    def test_non_editable_version_stops_without_writes(self):
        api = FakeApi()
        api.add_version("1.1.0", state="IN_REVIEW")
        with self.assertRaises(NotEditableError) as ctx:
            ver.plan_version(api, "app1", "1.1.0", ver.Context())
        self.assertEqual(ctx.exception.exit_code, 4)
        self.assertEqual(api.writes, [])

    def test_lookalike_version_is_not_duplicated(self):
        api = FakeApi()
        api.add_version("1.1")
        with self.assertRaises(AscError) as ctx:
            ver.plan_version(api, "app1", "1.1.0", ver.Context())
        self.assertIn("--version 1.1", str(ctx.exception))
        self.assertEqual(api.writes, [])

    def test_explicit_store_spelling_is_accepted(self):
        api = FakeApi()
        api.add_version("1.1")
        ctx = ver.Context()
        self.assertEqual(ver.plan_version(api, "app1", "1.1", ctx), [])
        self.assertEqual(ctx.version.version_string, "1.1")


if __name__ == "__main__":
    unittest.main()
