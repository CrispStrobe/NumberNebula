#!/usr/bin/env python3
"""Import a reviewed kompass4 metadata export or compare it without writing.

Run kompass.export_math_mapping in the source checkout first. Pass the immutable
commit that contains the reviewed export. This offline tool does not claim to
authenticate remote history; reviewers verify that commit and its source pin.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

from source_mapping import LOCK, MAPPING, SourceMappingError, make_lock


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, type=Path,
                        help="Reviewed kompass4 data/numbernebula_math_mapping_v1.json.")
    parser.add_argument("--source-commit", required=True,
                        help="Exact 40-character commit containing that reviewed export.")
    parser.add_argument("--check", action="store_true", help="Compare without writing files.")
    args = parser.parse_args(argv)
    try:
        raw = args.source.read_bytes()
        lock = make_lock(raw, args.source_commit)
        encoded_lock = json.dumps(lock, ensure_ascii=False, indent=2) + "\n"
        if args.check:
            if (not MAPPING.is_file() or MAPPING.read_bytes() != raw or
                    not LOCK.is_file() or LOCK.read_text(encoding="utf-8") != encoded_lock):
                raise SourceMappingError("local competency mapping differs from the reviewed source export")
        else:
            # Fully parse/validate both products before changing either file.
            MAPPING.write_bytes(raw)
            LOCK.write_text(encoded_lock, encoding="utf-8")
    except (OSError, json.JSONDecodeError, SourceMappingError) as error:
        parser.exit(1, f"Source mapping: {error}\n")
    print(f"32 competency mappings {'checked' if args.check else 'imported'} from {args.source_commit}.")


if __name__ == "__main__":
    main()
