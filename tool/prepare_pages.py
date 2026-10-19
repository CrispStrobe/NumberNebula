#!/usr/bin/env python3
"""Package an existing Flutter web artifact for a GitHub Pages project path.

No compiler is invoked. Only index.html, a new .nojekyll marker, and public
provenance metadata may differ from the input artifact.
"""

from __future__ import annotations

import argparse
import hashlib
from html.parser import HTMLParser
import json
from pathlib import Path
import re
import shutil
import tempfile

PROVENANCE_FILE = "pages-provenance.json"


def validate_base_href(value: str) -> str:
    """Accept a local absolute directory URL without encoded/ambiguous segments."""
    if not value.startswith("/") or not value.endswith("/"):
        raise ValueError("base href must start and end with '/'")
    if "//" in value:
        raise ValueError("base href must not contain '//'")
    if value == "/":
        return value
    for segment in value[1:-1].split("/"):
        if segment in {"", ".", ".."} or not re.fullmatch(r"[A-Za-z0-9_.-]+", segment):
            raise ValueError("base href contains an unsafe or unsupported path segment")
    return value


class _BaseParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.tags: list[tuple[list[tuple[str, str | None]], str, tuple[int, int]]] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag.lower() == "base":
            self.tags.append((attrs, self.get_starttag_text(), self.getpos()))

    def handle_startendtag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        self.handle_starttag(tag, attrs)


def adapt_index(original: bytes, base_href: str) -> bytes:
    """Replace exactly the href value of the one expected Flutter base element."""
    validate_base_href(base_href)
    text = original.decode("utf-8")
    parser = _BaseParser()
    parser.feed(text)
    parser.close()
    if len(parser.tags) != 1:
        raise ValueError("index.html must contain exactly one base element")
    attrs, raw, (line, column) = parser.tags[0]
    if attrs != [("href", "/")]:
        raise ValueError("expected an unmodified Flutter base element with href='/'")
    match = re.fullmatch(r"<base\s+href\s*=\s*(['\"])(/)\1\s*/?>", raw, re.IGNORECASE)
    if match is None:
        raise ValueError("unexpected base element syntax")
    # HTMLParser reports one-based lines and zero-based columns. Counting LF
    # explicitly preserves CRLF and avoids normalizing the rest of the HTML.
    offset = sum(len(part) + 1 for part in text.split("\n")[: line - 1]) + column
    if text[offset : offset + len(raw)] != raw:
        raise ValueError("could not locate the parsed base element exactly")
    start = offset + match.start(2)
    end = offset + match.end(2)
    return (text[:start] + base_href + text[end:]).encode("utf-8")


def _sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _file_sha(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _inventory(directory: Path) -> dict[str, str]:
    inventory: dict[str, str] = {}
    for entry in sorted(directory.rglob("*")):
        if entry.is_symlink():
            raise ValueError("artifact must not contain symbolic links")
        if entry.is_dir():
            continue
        if not entry.is_file():
            raise ValueError("artifact contains a non-regular file")
        inventory[entry.relative_to(directory).as_posix()] = _file_sha(entry)
    return inventory


def prepare_pages(source: Path, destination: Path, *, base_href: str) -> dict[str, object]:
    validate_base_href(base_href)
    source = source.resolve(strict=True)
    destination = destination.resolve()
    if not source.is_dir():
        raise ValueError("source must be a web artifact directory")
    if destination == source or source in destination.parents:
        raise ValueError("destination must not be inside the source artifact")
    if destination.exists():
        raise ValueError("destination must not already exist")
    source_files = _inventory(source)
    if "index.html" not in source_files:
        raise ValueError("source artifact has no index.html")
    if PROVENANCE_FILE in source_files:
        raise ValueError("source is already a Pages package")
    index = source.joinpath("index.html").read_bytes()
    if _sha(index) != source_files["index.html"]:
        raise ValueError("source index changed during preparation")
    adapted = adapt_index(index, base_href)
    provenance: dict[str, object] = {
        "schemaVersion": 1,
        "baseHref": base_href,
        "sourceIndexSha256": source_files["index.html"],
        "pagesIndexSha256": _sha(adapted),
        "preservedFiles": {
            name: digest for name, digest in source_files.items() if name != "index.html"
        },
        "modifiedSourceFiles": ["index.html"] if adapted != index else [],
    }
    # Build in a sibling temporary directory, then publish the complete package
    # atomically. A failed preservation check leaves no partial destination.
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".pages-package-", dir=destination.parent) as temporary:
        package = Path(temporary) / "site"
        shutil.copytree(source, package)
        package.joinpath("index.html").write_bytes(adapted)
        package.joinpath(".nojekyll").touch(exist_ok=True)
        output_files = _inventory(package)
        expected = {**source_files, "index.html": _sha(adapted)}
        expected.setdefault(".nojekyll", _sha(b""))
        if output_files != expected:
            raise ValueError("prepared package changed files other than index.html/.nojekyll")
        package.joinpath(PROVENANCE_FILE).write_text(
            json.dumps(provenance, indent=2, sort_keys=True) + "\n", encoding="utf-8"
        )
        package.rename(destination)
    return provenance


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="existing validated Flutter web directory")
    parser.add_argument("destination", type=Path, help="new Pages package directory")
    parser.add_argument("--base-href", required=True, type=validate_base_href)
    args = parser.parse_args()
    try:
        result = prepare_pages(args.source, args.destination, base_href=args.base_href)
    except (OSError, ValueError) as error:
        parser.exit(1, f"Pages preparation failed: {error}\n")
    print(json.dumps({"baseHref": result["baseHref"], "preservedFileCount": len(result["preservedFiles"])}))


if __name__ == "__main__":
    main()
