"""Small temporary fixtures only; no Flutter build or real artifact required."""

import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import shutil

from tool.prepare_pages import PROVENANCE_FILE, adapt_index, prepare_pages, validate_base_href


class PagesPreparationTests(unittest.TestCase):
    def test_adapts_only_real_base_href_preserving_crlf_and_script_text(self):
        original = b'''<!doctype html>\r\n<script>const example = '<base href="/">';</script>\r\n<BASE href = '/' />\r\n<script src="flutter_bootstrap.js"></script>'''
        actual = adapt_index(original, "/NumberNebula/")
        self.assertEqual(actual, original.replace(b"<BASE href = '/' />", b"<BASE href = '/NumberNebula/' />"))

    def test_rejects_unsafe_base_paths(self):
        for path in ["NumberNebula/", "/NumberNebula", "//external/", "/a//b/", "/../", "/a/../b/", "/./", "/a%2fb/", "/a\\b/", "/a?b/", "/a#b/", "/a b/", "/a\nb/"]:
            with self.subTest(path=path), self.assertRaises(ValueError):
                validate_base_href(path)
        for path in ["/", "/NumberNebula/", "/org/repo-name_1.2/"]:
            self.assertEqual(validate_base_href(path), path)

    def test_rejects_unexpected_base_elements(self):
        for html in [b"<html></html>", b'<base href="/other/">', b'<base href="https://external/">', b'<base href="/"><base href="/">', b'<base href="/" href="/other/">', b'<base href="/" target="_blank">', b'<base href="&#47;">']:
            with self.subTest(html=html), self.assertRaises(ValueError):
                adapt_index(html, "/NumberNebula/")

    def test_preserves_compiled_assets_and_records_public_provenance(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source, destination = root / "input", root / "pages"
            source.mkdir()
            files = {"index.html": b'<base href="/">\n<script src="flutter_bootstrap.js"></script>', "main.dart.wasm": b"\x00asm\x01\x00\x00\x00", "main.dart.js": b"const dart = 1;", "main.dart.mjs": b"export const dart = 1;", "flutter_bootstrap.js": b"load();", "flutter_service_worker.js": b"unregister();", "version.json": b'{"version":"fixture"}', "assets/nested/data.bin": b"\x00\xff\x01", "_underscore/part.js": b"deferred();"}
            for relative, data in files.items():
                file = source / relative
                file.parent.mkdir(parents=True, exist_ok=True)
                file.write_bytes(data)
            result = prepare_pages(source, destination, base_href="/NumberNebula/")
            self.assertEqual((destination / "index.html").read_bytes(), files["index.html"].replace(b'href="/"', b'href="/NumberNebula/"'))
            self.assertEqual((destination / ".nojekyll").read_bytes(), b"")
            for relative, data in files.items():
                self.assertEqual((source / relative).read_bytes(), data, "source was changed")
                if relative != "index.html":
                    self.assertEqual((destination / relative).read_bytes(), data)
                    self.assertEqual(result["preservedFiles"][relative], hashlib.sha256(data).hexdigest())
            provenance = json.loads((destination / PROVENANCE_FILE).read_text())
            self.assertEqual(provenance, result)
            self.assertEqual(provenance["sourceIndexSha256"], hashlib.sha256(files["index.html"]).hexdigest())
            self.assertEqual(provenance["pagesIndexSha256"], hashlib.sha256((destination / "index.html").read_bytes()).hexdigest())
            self.assertEqual(provenance["modifiedSourceFiles"], ["index.html"])
            self.assertNotIn(str(root), json.dumps(provenance))
            self.assertEqual(set(provenance), {"schemaVersion", "baseHref", "sourceIndexSha256", "pagesIndexSha256", "preservedFiles", "modifiedSourceFiles"})

    def test_preserves_existing_nojekyll_marker(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "input"
            source.mkdir()
            (source / "index.html").write_bytes(b'<base href="/">')
            (source / ".nojekyll").write_bytes(b"existing marker")
            prepare_pages(source, root / "output", base_href="/NumberNebula/")
            self.assertEqual((root / "output/.nojekyll").read_bytes(), b"existing marker")

    def test_rejects_nested_or_existing_destinations_and_symlinks(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "input"
            source.mkdir()
            (source / "index.html").write_bytes(b'<base href="/">')
            for destination in [source, source / "inside"]:
                with self.subTest(destination=destination), self.assertRaises(ValueError):
                    prepare_pages(source, destination, base_href="/NumberNebula/")
            existing = root / "existing"
            existing.mkdir()
            with self.assertRaises(ValueError):
                prepare_pages(source, existing, base_href="/NumberNebula/")
            outside = root / "private.txt"
            outside.write_text("private fixture")
            (source / "linked.txt").symlink_to(outside)
            with self.assertRaises(ValueError):
                prepare_pages(source, root / "output", base_href="/NumberNebula/")
            self.assertFalse((root / "output").exists())

    def test_preservation_failure_leaves_no_partial_package(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "input"
            source.mkdir()
            (source / "index.html").write_bytes(b'<base href="/">')
            (source / "main.dart.wasm").write_bytes(b"original compiled fixture")
            copytree = shutil.copytree

            def corrupted_copy(input_path, output_path):
                result = copytree(input_path, output_path)
                (Path(output_path) / "main.dart.wasm").write_bytes(b"corruption")
                return result

            with patch("tool.prepare_pages.shutil.copytree", side_effect=corrupted_copy):
                with self.assertRaisesRegex(ValueError, "changed files"):
                    prepare_pages(source, root / "output", base_href="/NumberNebula/")
            self.assertFalse((root / "output").exists())
            self.assertEqual((source / "main.dart.wasm").read_bytes(), b"original compiled fixture")
            self.assertEqual(sorted(path.name for path in root.iterdir()), ["input"])

    def test_bad_source_does_not_create_partial_destination(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "input"
            source.mkdir()
            destination = root / "output"
            with self.assertRaises(ValueError):
                prepare_pages(source, destination, base_href="/NumberNebula/")
            self.assertFalse(destination.exists())
            (source / "index.html").write_text('<base href="/already-adapted/">')
            with self.assertRaises(ValueError):
                prepare_pages(source, destination, base_href="/NumberNebula/")
            self.assertFalse(destination.exists())
            (source / "index.html").write_text('<base href="/">')
            (source / PROVENANCE_FILE).write_text('{}')
            with self.assertRaises(ValueError):
                prepare_pages(source, destination, base_href="/NumberNebula/")
            self.assertFalse(destination.exists())


if __name__ == "__main__":
    unittest.main()
