import copy
import json
import tempfile
import unittest
from pathlib import Path

from source_mapping import (
    LOCK, MAPPING, SourceMappingError, load_source_mapping, make_lock, validate_mapping,
)


class SourceMappingTests(unittest.TestCase):
    def test_exact_pin_and_metadata_match_source(self):
        mapping = load_source_mapping()
        rows = {row["id"]: row for row in mapping["competencies"]}
        self.assertEqual(len(rows), 32)
        self.assertEqual(sum(row["evidence"] == "published2025" for row in rows.values()), 24)
        self.assertEqual(rows["M-Z01"]["estimatedSeconds"], {"min": 75, "max": 150})
        expected = {"M-Z08": "01_02", "M-R02": "02_01", "M-R03": "02_04",
                    "M-R04": "02_01", "M-R07": "02_02", "M-R08": "02_04"}
        for key, chapter in expected.items():
            with self.subTest(key=key):
                self.assertTrue(rows[key]["curriculumUrl"].endswith(chapter))

    def test_course_authoring_uses_all_source_metadata(self):
        from competencies import competencies
        rows = {row["id"]: row for row in competencies()}
        for source in load_source_mapping()["competencies"]:
            for field, value in source.items():
                self.assertEqual(rows[source["id"]][field], value)

    def test_changed_mapping_or_lock_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            mapping = Path(directory) / "mapping.json"
            lock = Path(directory) / "lock.json"
            mapping.write_bytes(MAPPING.read_bytes())
            lock.write_bytes(LOCK.read_bytes())
            load_source_mapping(mapping, lock)
            mapping.write_bytes(MAPPING.read_bytes() + b" ")
            with self.assertRaises(SourceMappingError):
                load_source_mapping(mapping, lock)
            mapping.write_bytes(MAPPING.read_bytes())
            changed = json.loads(lock.read_text())
            changed["matrixCommit"] = "0" * 40
            lock.write_text(json.dumps(changed))
            with self.assertRaises(SourceMappingError):
                load_source_mapping(mapping, lock)

    def test_no_unreviewed_prose_or_time_unit_is_imported(self):
        source = load_source_mapping()
        changes = (
            lambda value: value.update(solution="private answer"),
            lambda value: value["source"].update(rubric="private answer"),
            lambda value: value["competencies"][0].update(solution="private answer"),
            lambda value: value["source"].update(timeUnit="minutes"),
            lambda value: value["source"].update(prerequisitesAuthored=True),
            lambda value: value["competencies"][0].update(estimatedSeconds={"min": True, "max": 10}),
            lambda value: value["competencies"].append(copy.deepcopy(value["competencies"][0])),
        )
        for change in changes:
            candidate = copy.deepcopy(source)
            change(candidate)
            with self.assertRaises(SourceMappingError):
                validate_mapping(candidate)

    def test_import_requires_immutable_export_commit(self):
        for ref in ("main", "f57dddd", "", None):
            with self.subTest(ref=ref), self.assertRaises(SourceMappingError):
                make_lock(MAPPING.read_bytes(), ref)


if __name__ == "__main__":
    unittest.main()
