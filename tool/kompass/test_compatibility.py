import copy
import hashlib
import json
import unittest

from content_compatibility import BASELINE, BASELINE_SHA256, compatibility_for, verify_compatibility


class ContentCompatibilityTests(unittest.TestCase):
    def setUp(self):
        self.previous = json.loads(BASELINE.read_text(encoding="utf-8"))

    def test_baseline_is_the_pinned_prior_release(self):
        self.assertEqual(hashlib.sha256(BASELINE.read_bytes()).hexdigest(), BASELINE_SHA256)
        self.assertEqual(self.previous["version"], "2.0.1")
        self.assertEqual(len(self.previous["tasks"]), 128)

    def test_appending_does_not_mark_new_tasks_as_historical(self):
        tasks = copy.deepcopy(self.previous["tasks"])
        added = copy.deepcopy(tasks[0])
        added["id"] = "new_task"
        tasks.append(added)
        compatible = compatibility_for(tasks)
        self.assertEqual(set(compatible["2.0.1"]), {t["id"] for t in self.previous["tasks"]})
        self.assertNotIn("new_task", compatible["2.0.1"])

    def test_changed_wording_scoring_and_figures_cannot_reuse_old_records(self):
        for field, value in [("prompt", {"de": "Andere Frage", "en": "Other question"}),
                             ("parts", []), ("figure", {"kind": "changed"})]:
            tasks = copy.deepcopy(self.previous["tasks"])
            tasks[0][field] = value
            with self.assertRaisesRegex(ValueError, "Historical task"):
                compatibility_for(tasks)

    def test_removal_and_duplicate_identity_are_rejected(self):
        tasks = self.previous["tasks"]
        with self.assertRaisesRegex(ValueError, "Historical task"):
            compatibility_for(tasks[1:])
        with self.assertRaisesRegex(ValueError, "Duplicate"):
            compatibility_for(tasks + [tasks[0]])

    def test_declared_compatibility_must_equal_the_comparison(self):
        package = copy.deepcopy(self.previous)
        package["compatibleTaskIds"] = compatibility_for(package["tasks"])
        verify_compatibility(package)
        package["compatibleTaskIds"]["2.0.1"].pop()
        with self.assertRaisesRegex(ValueError, "immutable historical"):
            verify_compatibility(package)


if __name__ == "__main__":
    unittest.main()
