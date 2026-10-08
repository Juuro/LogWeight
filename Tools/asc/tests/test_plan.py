import unittest

from asc.plan import Action, Plan
from .fake_api import FakeApi


class PlanTests(unittest.TestCase):
    def test_empty_plan_makes_no_writes(self):
        api = FakeApi()
        plan = Plan([Action("skip_unchanged", "x", "de-DE")])
        self.assertTrue(plan.execute())
        self.assertEqual(api.writes, [])

    def test_execute_runs_actions_in_order_and_continues_after_failure(self):
        calls = []

        def boom():
            raise RuntimeError("store said no")

        plan = Plan([
            Action("upload", "a", "de-DE", run=lambda: calls.append("a")),
            Action("upload", "b", "de-DE", run=boom),
            Action("upload", "c", "de-DE", run=lambda: calls.append("c")),
        ])
        self.assertFalse(plan.execute())
        self.assertEqual(calls, ["a", "c"])
        self.assertEqual([a.result for a in plan.actions], ["done", "failed", "done"])
        self.assertIn("store said no", plan.render(applying=True))

    def test_render_summarizes_per_locale(self):
        plan = Plan([Action("upload", "a", "de-DE"), Action("skip_unchanged", "b", "de-DE"), Action("replace", "c", "fr-FR")])
        text = plan.render()
        self.assertIn("de-DE: skipped=1, uploaded=1", text)
        self.assertIn("fr-FR: replaced=1", text)

    def test_unknown_kind_rejected(self):
        with self.assertRaises(ValueError):
            Action("submit_for_review", "x")


if __name__ == "__main__":
    unittest.main()
